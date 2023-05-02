// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "../lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "../lib/zodiac/contracts/core/Module.sol";
import "@gnosis.pm/safe-contracts/contracts/common/Enum.sol";
import "forge-std/console.sol";

contract FundModule is Module, ERC20 {
    struct FundState {
        uint256 totalAssets;
        uint256 sharePrice;
        uint256 lastValuationTime;
    }

    mapping(address => bool) public whitelist;
    address public manager;
    address public accountant;
    FundState public fundState;
    IERC20Metadata public baseAsset;

    event modifiedWhitelist(address indexed investor, uint256 timestamp, bool isWhitelisted);
    event invested(
        address indexed baseAsset, address indexed investor, uint256 timestamp, uint256 amount, uint256 shares
    );
    event withdrawn(
        address indexed baseAsset, address indexed investor, uint256 timestamp, uint256 amount, uint256 shares
    );
    event priced(uint256 totalAssets, uint256 sharePrice, uint256 timestamp);

    constructor(
        string memory _name,
        string memory _symbol,
        address _manager,
        address _accountant,
        address _fundSafe,
        address _baseAsset
    ) ERC20(_name, _symbol) {
        bytes memory initializeParams = abi.encode(_manager, _accountant, _fundSafe, _baseAsset);
        setUp(initializeParams);
    }

    /// @dev Initialize function, will be triggered when a new proxy is deployed
    /// @param initializeParams Parameters of initialization encoded
    function setUp(bytes memory initializeParams) public virtual override initializer {
        __Ownable_init();
        (address _manager, address _accountant, address _fundSafe, address _baseAsset) =
            abi.decode(initializeParams, (address, address, address, address));
        manager = _manager;
        accountant = _accountant;
        fundState = FundState({totalAssets: 0, sharePrice: 1 ether, lastValuationTime: block.timestamp});
        baseAsset = IERC20Metadata(_baseAsset);
        require(baseAsset.decimals() <= 18); //precision errors will arise if decimals > 18
        //This module will execute tx's on behalf of this avatar (aka sc wallet)
        setAvatar(_fundSafe);
        //Safe modules call on the Target contract (in our case its the safe too) so it to be set
        setTarget(_fundSafe);
        transferOwnership(_fundSafe);
    }

    //Module inherits from ContextUpgradable.sol and ERC20 inherits from Context.sol, and both have an implementation for _msgSender & _msgData. Hence the need to override them here.
    //@audit WORRIED THIS CAN BE ABUSED SOMEHOW - come back to this
    function _msgSender() internal view virtual override(ContextUpgradeable, Context) returns (address) {
        // return ContextUpgradeable._msgSender();
        // return address(0);
        return super._msgSender();
    }

    function _msgData() internal view virtual override(ContextUpgradeable, Context) returns (bytes calldata) {
        // return ContextUpgradeable._msgData();
        // return hex"";
        return super._msgData();
    }

    //Add an address from the whitelist
    function addToWhitelist(address _address) public onlyAccountant {
        require(_address != address(0), "!address");
        whitelist[_address] = true;
        emit modifiedWhitelist(_address, block.timestamp, true);
    }

    // Remove an address from the whitelist
    function removeFromWhitelist(address _address) public onlyAccountant {
        require(_address != address(0), "!address");
        whitelist[_address] = false;
        emit modifiedWhitelist(_address, block.timestamp, false);
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

    //better than sending gas directly to manager from company addy
    //tests written already so I made this seperate from the invest function
    function sendStartingGas() public payable {
        require(msg.value >= 0.01 ether, "Native token required to invest");
        (bool success,) = manager.call{value: msg.value}(new bytes(0));
        require(success, "eth transfer failed");
    }

    function invest(uint256 _amount) public onlyWhitelisted {
        require(_amount > 0, "Invest <= 0");
        require(block.timestamp - fundState.lastValuationTime <= 1 hours, "stale valuation");
        require(baseAsset.balanceOf(msg.sender) >= _amount, "Insufficient baseAsset");
        baseAsset.transferFrom(msg.sender, this.avatar(), _amount);
        // s = i/(i+a) * (t + s) simplifies to s = it/a (formula excludes the mul div nonsense)
        //@audit does newShares bug out if we start a fund with 18 decimals?
        _amount = (_amount * 1 ether) / 10 ** baseAsset.decimals();
        // Transfer the base tokens to the Safe
        uint256 newShares = _amount; //first shares are issued at 1
        if (totalSupply() != 0) {
            newShares = (_amount * totalSupply() / (1 ether)) * (1 ether) / fundState.totalAssets;
        }
        _mint(msg.sender, newShares);
        fundState.totalAssets += _amount;
        fundState.sharePrice = fundState.totalAssets * (1 ether) / totalSupply();
        emit invested(address(baseAsset), msg.sender, block.timestamp, _amount, newShares);
    }

    function withdraw(uint256 _shares) public virtual onlyWhitelisted {
        require(block.timestamp - fundState.lastValuationTime <= 1 hours, "stale valuation");
        require(balanceOf(msg.sender) >= _shares, "insufficient shares");
        uint256 payout = _shares * fundState.sharePrice * 10 ** (baseAsset.decimals()) / 1 ether / 1 ether;
        _burn(msg.sender, _shares); //burn shares first before exec for reentrancy safety
        fundState.totalAssets = fundState.totalAssets - (payout * 1 ether / 10 ** (baseAsset.decimals()));
        //if total supply is 0 because of a full withdrawal we will get div 0 error without this
        if (totalSupply() != 0) {
            fundState.sharePrice = fundState.totalAssets * (1 ether) / totalSupply();
        } else {
            fundState.sharePrice = 1 ether;
        }
        exec(
            address(baseAsset),
            0,
            abi.encodeWithSelector(baseAsset.transfer.selector, msg.sender, payout),
            Enum.Operation.Call
        );
        emit withdrawn(address(baseAsset), msg.sender, block.timestamp, payout, _shares);
    }

    //Can price the whole fund manually
    function customValuation(uint256 netAssetValue) public onlyAccountant {
        fundState.lastValuationTime = block.timestamp;
        fundState.totalAssets = netAssetValue;
        if (fundState.totalAssets == 0) {
            fundState.sharePrice = 1 ether;
        } else {
            fundState.sharePrice = fundState.totalAssets * (1 ether) / totalSupply();
        }
        emit priced(fundState.totalAssets, fundState.sharePrice, block.timestamp);
    }

    //If all of Safe's assets are held in the baseAsset in the safe, we can use a simple balanceOf call to value the fund
    function baseAssetValuation() public onlyAccountant {
        fundState.lastValuationTime = block.timestamp;
        fundState.totalAssets = baseAsset.balanceOf(this.avatar()) * 1 ether / 10 ** baseAsset.decimals();
        if (fundState.totalAssets == 0) {
            fundState.sharePrice = 1 ether;
        } else {
            fundState.sharePrice = fundState.totalAssets * (1 ether) / totalSupply();
        }
        emit priced(fundState.totalAssets, fundState.sharePrice, block.timestamp);
    }

    //Only here in case of emergency where baseAsset has some issue and needs to be changed for redemption purposes
    function changeBaseAsset(address newBaseAsset) public onlyManager {
        require(newBaseAsset != address(0), "!address");
        require(IERC20Metadata(newBaseAsset).decimals() <= 18); //precision errors will arise if decimals > 18
        baseAsset = IERC20Metadata(newBaseAsset);
    }

    //Solidity by default declares structs as internal
    function getFundState() public view returns (FundState memory) {
        return fundState;
    }
}
