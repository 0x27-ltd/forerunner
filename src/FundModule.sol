// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "../lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "../lib/zodiac/contracts/core/Module.sol";
import "@gnosis.pm/safe-contracts/contracts/common/Enum.sol";
import "forge-std/console.sol";

contract FundModule is Module, ERC20 {
    mapping(address => bool) public whitelist;
    address public manager;
    address public fundSafe;
    address public accountant;
    uint256 public totalAssets;
    uint256 public sharePrice;
    uint256 public lastClaimTime;
    uint256 public highWaterMark;
    uint256 public feeRate;
    uint256 public performanceFee;
    uint256 public lastValuationTime;
    IERC20Metadata public baseAsset;
    
    constructor(
            string memory name,
            string memory symbol,
            address _manager,
            address _accountant,
            address _fundSafe,
            address _baseAsset,
            uint256 _feeRate,
            uint256 _performanceFee
        ) ERC20(name, symbol){

        bytes memory initializeParams = abi.encode(
            _manager,
            _accountant,
            _fundSafe,
            _baseAsset,
            _feeRate,
            _performanceFee
        );
        setUp(initializeParams);
    }

    /// @dev Initialize function, will be triggered when a new proxy is deployed
    /// @param initializeParams Parameters of initialization encoded
    function setUp(bytes memory initializeParams) public override initializer {
        __Ownable_init();
        (address _manager, address _accountant, address _fundSafe, address _baseAsset, uint256 _feeRate, uint256 _performanceFee) = abi.decode(initializeParams, (address, address, address, address, uint256, uint256));
        manager = _manager;
        accountant = _accountant;
        fundSafe = _fundSafe;
        totalAssets = 0;
        sharePrice = 1;
        lastClaimTime = block.timestamp;
        highWaterMark = 1;
        feeRate = _feeRate;
        performanceFee = _performanceFee;
        lastValuationTime = block.timestamp;
        baseAsset = IERC20Metadata(_baseAsset);
        //DOUBLE CHECK THESE
        setAvatar(fundSafe);
        setTarget(fundSafe);
        transferOwnership(fundSafe);
    }
    
    //Module inherits from ContextUpgradable.sol and ERC20 inherits from Context.sol, and both have an implementation for _msgSender & _msgData.
    //Hence the need to override them here.
    //@audit No clue on how exactly to set this param - come back to this
    function _msgSender() internal view virtual override(ContextUpgradeable, Context) returns (address) {
        return ContextUpgradeable._msgSender();
    }

    function _msgData() internal view virtual override(ContextUpgradeable, Context) returns(bytes calldata) {
        return ContextUpgradeable._msgData();
    }

    //Add an address from the whitelist
    function addToWhitelist(address _address) public onlyAccountant {
        whitelist[_address] = true;
    }
    
    // Remove an address from the whitelist
    function removeFromWhitelist(address _address) public onlyAccountant {
        whitelist[_address] = false;
    }

    modifier onlyManager() {
        require(msg.sender == manager, "Only the manager can call this function.");
        _;
    }

    modifier onlyWhitelisted() {
        require(whitelist[msg.sender] == true, "Caller is not whitelisted.");
        _;
    }

    modifier onlyAccountant() {
        require(msg.sender == accountant, "Only the accountant can call this function.");
        _;
    }

    //note _amount is in wei even if the baseCurrency has 6 decimals (all calcs done in wei)
    function invest(uint256 _amount) public onlyWhitelisted {
        require(_amount > 0, "Invest > 0");
        require(block.timestamp - lastValuationTime <= 1 hours, "stale_valuation");
        // Transfer the base tokens to the Safe
        baseAsset.transferFrom(msg.sender, fundSafe, _amount);
        // s = i/(i+a) * (t + s) simplifies to s = it/a (formula excludes the mul div nonsense)
        uint256 newShares = _amount; //first shares are issued at 1
        console.log(newShares);
        if (totalSupply() != 0) {
            newShares = (_amount*totalSupply()/(1 ether))*(1 ether)/totalAssets;
        }
        _mint(msg.sender, newShares);
        totalAssets += _amount;
        sharePrice = totalAssets*(1 ether)/totalSupply();
    }

    function withdraw(uint256 _shares) public onlyWhitelisted {
        require(block.timestamp - lastValuationTime <= 1 hours, "Withdrawals can only be made within 1 hour of the last valuation.");
        _claimPerformanceFee();
        require(balanceOf(msg.sender) >= _shares, "Insufficient shares.");
        uint256 payout = _shares*sharePrice/(1 ether);
        //in place of transfer send usdc from safe itself
        exec(address(baseAsset), 0, abi.encodeWithSelector(baseAsset.transfer.selector, msg.sender,  payout), Enum.Operation.Call); //not sure if you can say usdc.address and what call this is
        _burn(msg.sender, _shares);
        totalAssets = totalAssets - payout;
        sharePrice = 1 ether; 
        //if total supply is 0 because of a full withdrawal we will get div 0 error without this
        if (totalSupply() != 0) {
            sharePrice = totalAssets*(1 ether)/totalSupply();
        }
    }

    function _claimBaseFee() internal {
        if (block.timestamp - lastClaimTime > 30 days) {
            uint256 feeAmount = totalAssets*(feeRate)/1 ether;
            totalAssets = totalAssets - feeAmount;
            lastClaimTime = block.timestamp;
            exec(address(baseAsset), 0, abi.encodeWithSelector(baseAsset.transfer.selector, manager, feeAmount), Enum.Operation.Call);
        }
    }

    function _claimPerformanceFee() internal {
        if (block.timestamp - lastClaimTime > 30 days) {
            if (sharePrice > highWaterMark) {
                uint256 performanceFeeAmount = (sharePrice - highWaterMark)*totalSupply()*performanceFee/1e18;
                highWaterMark = sharePrice;
                totalAssets = totalAssets - performanceFeeAmount;
                lastClaimTime = block.timestamp;
                exec(address(baseAsset), 0, abi.encodeWithSelector(baseAsset.transfer.selector, manager, performanceFeeAmount), Enum.Operation.Call);
            }
        }
    }

    function claimFees() public onlyManager{
        _claimPerformanceFee();
        _claimBaseFee();
    }

    //Can price the whole fund manually
    function customValuation(uint256 netAssetValue) public onlyAccountant {
        lastValuationTime = block.timestamp;
        totalAssets = netAssetValue;
        sharePrice = totalAssets*(1 ether)/totalSupply();
    }

    //If all of Safe's assets are held in the baseAsset in the safe, we can use a simple balanceOf call to value the fund
    function baseAssetValuation() public onlyAccountant{
        lastValuationTime = block.timestamp;
        uint256 balance = baseAsset.balanceOf(fundSafe);
        totalAssets = balance*1e18/baseAsset.decimals();
        sharePrice = totalAssets*(1 ether)/totalSupply();
    }

    //Only here in case of emergency where baseAsset has some issue and needs to be changed for redemption purposes
    function changeBaseAsset(address newBaseAsset) public onlyOwner {
        require(newBaseAsset != address(0), "!address");
        baseAsset = IERC20Metadata(newBaseAsset);
    }

}