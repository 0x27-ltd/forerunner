// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "../lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "../lib/zodiac/contracts/core/Module.sol";
import "@gnosis.pm/safe-contracts/contracts/common/Enum.sol";
import "forge-std/console.sol";
import "./FundModule.sol";

contract FundModuleExtended is FundModule {
    uint256 public feeRate;
    uint256 public performanceFee;
    uint256 public highWaterMark;
    uint256 public lastClaimTime;

    constructor(
        string memory _name,
        string memory _symbol,
        address _manager,
        address _accountant,
        address _fundSafe,
        address _baseAsset,
        uint256 _feeRate,
        uint256 _performanceFee
    ) FundModule(_name, _symbol, _manager, _accountant, _fundSafe, _baseAsset) {
        bytes memory initializeParams =
            abi.encode(_manager, _accountant, _fundSafe, _baseAsset, _feeRate, _performanceFee);

        setUp(initializeParams);
    }

    /// @dev Initialize function, will be triggered when a new proxy is deployed
    /// @param initializeParams Parameters of initialization encoded
    function setUp(bytes memory initializeParams) public override initializer {
        __Ownable_init();
        (
            address _manager,
            address _accountant,
            address _fundSafe,
            address _baseAsset,
            uint256 _feeRate,
            uint256 _performanceFee
        ) = abi.decode(initializeParams, (address, address, address, address, uint256, uint256));
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

    function withdraw(uint256 _shares) public override onlyWhitelisted {
        //only difference with this withdraw is the claiming of fees - need to ensure investor can't exit without paying fees
        require(block.timestamp - lastValuationTime <= 1 hours, "stale valuation");
        _claimPerformanceFee();
        require(balanceOf(msg.sender) >= _shares, "Insufficient shares.");
        uint256 payout = _shares * sharePrice * 10 ** (this.baseAsset().decimals()) / 1 ether / 1 ether;
        //in place of transfer send usdc from safe itself
        exec(
            address(baseAsset),
            0,
            abi.encodeWithSelector(baseAsset.transfer.selector, msg.sender, payout),
            Enum.Operation.Call
        ); //not sure if you can say usdc.address and what call this is
        _burn(msg.sender, _shares);
        totalAssets = totalAssets - (payout * 1 ether / 10 ** (this.baseAsset().decimals()));
        //if total supply is 0 because of a full withdrawal we will get div 0 error without this
        if (totalSupply() != 0) {
            sharePrice = totalAssets * (1 ether) / totalSupply();
        } else {
            sharePrice = 1 ether;
        }
        emit withdrawn(address(this.baseAsset()), msg.sender, block.timestamp, payout, _shares);
    }

    function _claimBaseFee() internal {
        if (block.timestamp - lastClaimTime > 30 days) {
            uint256 feeAmount = totalAssets * (feeRate) / 1 ether;
            totalAssets = totalAssets - feeAmount;
            lastClaimTime = block.timestamp;
            exec(
                address(baseAsset),
                0,
                abi.encodeWithSelector(baseAsset.transfer.selector, manager, feeAmount),
                Enum.Operation.Call
            );
        }
    }

    function _claimPerformanceFee() internal {
        if (block.timestamp - lastClaimTime > 30 days) {
            if (sharePrice > highWaterMark) {
                uint256 performanceFeeAmount = (sharePrice - highWaterMark) * totalSupply() * performanceFee / 1e18;
                highWaterMark = sharePrice;
                totalAssets = totalAssets - performanceFeeAmount;
                lastClaimTime = block.timestamp;
                exec(
                    address(baseAsset),
                    0,
                    abi.encodeWithSelector(baseAsset.transfer.selector, manager, performanceFeeAmount),
                    Enum.Operation.Call
                );
            }
        }
    }

    function claimFees() public onlyManager {
        _claimPerformanceFee();
        _claimBaseFee();
    }
}
