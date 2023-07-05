// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "zodiac/core/Module.sol";
import "@gnosis.pm/safe-contracts/contracts/common/Enum.sol";
import "forge-std/console.sol";

contract FundModule is Module, ERC20 {
    struct FundState {
        uint256 totalAssets;
        uint256 sharePrice;
        uint256 highWaterMark;
        uint256 lastValuationTime;
        uint256 lastAumFeeCalcTime;
        uint256 pendingAumFees;
        uint256 pendingPerfFees;
        uint256 aumFeeRatePerSecond;
        uint256 perfFeeRate;
        uint256 lastCrystalised;
        uint256 crystalisationPeriod;
    }

    struct PendingTransaction {
        address investor;
        uint256 valueOrShares; //this is either a value or shares amount :/
        bool isInflow;
    }

    // PendingTransaction[] private transactionQueue;
    mapping(address => PendingTransaction) private transactionQueue;

    mapping(address => bool) public whitelist;
    address[] private whitelistAddresses;
    address public manager;
    address public accountant;
    FundState public fundState;
    IERC20Metadata public baseAsset;

    event ModifiedWhitelist(address indexed investor, uint256 timestamp, bool isWhitelisted);
    event Invested(
        address indexed baseAsset, address indexed investor, uint256 timestamp, uint256 amount, uint256 shares
    );
    event Withdrawn(
        address indexed baseAsset, address indexed investor, uint256 timestamp, uint256 amount, uint256 shares
    );
    event Priced(uint256 totalAssets, uint256 sharePrice, uint256 timestamp);

    constructor(
        string memory _name,
        string memory _symbol,
        address _manager,
        address _accountant,
        address _fundSafe,
        address _baseAsset,
        uint256 _aumFeeRatePerSecond,
        uint256 _perfFeeRate,
        uint256 _crystalisationPeriod
    ) ERC20(_name, _symbol) {
        bytes memory initializeParams = abi.encode(
            _manager, _accountant, _fundSafe, _baseAsset, _aumFeeRatePerSecond, _perfFeeRate, _crystalisationPeriod
        );
        setUp(initializeParams);
    }

    /// @dev Initialize function, will be triggered when a new proxy is deployed
    /// @param initializeParams Parameters of initialization encoded
    function setUp(bytes memory initializeParams) public virtual override initializer {
        __Ownable_init();
        (
            address _manager,
            address _accountant,
            address _fundSafe,
            address _baseAsset,
            uint256 _aumFeeRatePerSecond,
            uint256 _perfFeeRate,
            uint256 _crystalisationPeriod
        ) = abi.decode(initializeParams, (address, address, address, address, uint256, uint256, uint256));
        manager = _manager;
        accountant = _accountant;
        fundState = FundState({
            totalAssets: 0,
            sharePrice: 1 ether,
            highWaterMark: 1 ether,
            lastValuationTime: block.timestamp,
            lastAumFeeCalcTime: block.timestamp,
            pendingAumFees: 0,
            pendingPerfFees: 0,
            aumFeeRatePerSecond: _aumFeeRatePerSecond,
            perfFeeRate: _perfFeeRate,
            lastCrystalised: block.timestamp,
            crystalisationPeriod: _crystalisationPeriod
        });
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
        require(!whitelist[_address], "address already in the whitelist");
        whitelist[_address] = true;
        whitelistAddresses.push(_address);
        emit ModifiedWhitelist(_address, block.timestamp, true);
    }

    // Remove an address from the whitelist
    function removeFromWhitelist(address _address) public onlyAccountant {
        require(_address != address(0), "!address");
        whitelist[_address] = false;
        //Need to remove addy from whitelistAddresses array too
        uint256 indexToRemove = 0;
        for (uint256 i = 0; i < whitelistAddresses.length; i++) {
            if (whitelistAddresses[i] == _address) {
                indexToRemove = i;
                break;
            }
        }
        //If the address is found in the array, remove it by swapping with the last element and then reducing the array length
        if (indexToRemove < whitelistAddresses.length - 1) {
            whitelistAddresses[indexToRemove] = whitelistAddresses[whitelistAddresses.length - 1];
        }
        whitelistAddresses.pop();
        emit ModifiedWhitelist(_address, block.timestamp, false);
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

    function queueInvestment(uint256 _amount) public onlyWhitelisted {
        require(_amount > 0, "invest <= 0");
        require(baseAsset.balanceOf(msg.sender) >= _amount, "Insufficient baseAsset");
        require(transactionQueue[msg.sender].investor == address(0), "investor already in queue");
        transactionQueue[msg.sender] = PendingTransaction(msg.sender, _amount, true);
    }

    function queueWithdrawal(uint256 _shares) public onlyWhitelisted {
        require(_shares > 0, "shares <= 0");
        require(balanceOf(msg.sender) >= _shares, "insufficient shares");
        require(transactionQueue[msg.sender].investor == address(0), "investor already in queue");
        transactionQueue[msg.sender] = PendingTransaction(msg.sender, _shares, false);
    }

    function cancelQueuedAction() public onlyWhitelisted {
        PendingTransaction memory transaction = transactionQueue[msg.sender];
        if (transaction.investor != address(0)) {
            delete transactionQueue[msg.sender];
        }
    }

    function updateStateWithPrice(uint256 netAssetValue) public onlyAccountant {
        //value fund so shares can be accurately issued and burnt
        _customValuation(netAssetValue);
        _calculatePendingAumFee();
        _calculatePendingPerfFee();
        //ensure crystalistaion period has been met before paying out perf fees
        //if an investor withdraws while perf fees not crystalised yet it makes sense to crystalise their portion
        if (fundState.lastCrystalised >= fundState.crystalisationPeriod) {
            //payout both aum and performance fees as performance fees have crystalised
            _payoutPerfFees();
            _payoutAumFees();
        } else {
            //payout only aum fees as performance has not yet crystalised
            _payoutAumFees();
        }
        //@todo Do we need to process withdrawals first before we process investments? worried about inaccurate share issuance if we don't do it seperatley [verify this!]
        for (uint256 i = 0; i < whitelistAddresses.length; i++) {
            address investor = whitelistAddresses[i];
            PendingTransaction memory transaction = transactionQueue[investor];
            //empty struct default value is the zero for that type so here we are basically checking transaction is not empty
            if (transaction.investor != address(0)) {
                if (!transaction.isInflow) {
                    //if pending fees are zero then isPendingUncrystalised will false
                    if (fundState.pendingPerfFees != 0) {
                        _withdraw(transaction.valueOrShares, true);
                    } else {
                        _withdraw(transaction.valueOrShares, false);
                    }
                } else {
                    _invest(transaction.valueOrShares);
                }
                delete transactionQueue[investor];
            }
        }
    }

    //@audit potentially make this and other internal functions nonreentrant
    function _invest(uint256 _amount) internal {
        require(_amount > 0, "Invest <= 0");
        // require(block.timestamp - fundState.lastValuationTime <= 1 hours, "stale valuation");
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
        emit Invested(address(baseAsset), msg.sender, block.timestamp, _amount, newShares);
    }

    //@audit left off here. This withdraw func assumes pending perf fees are due which may not be the case as they could be zero from meeting crystalisation period.
    //add a bool isPendingUncrystalised that is caught in an if that gives correct netPayout etc in both cases
    function _withdraw(uint256 _shares, bool isPendingUncrystalised) internal {
        require(balanceOf(msg.sender) >= _shares, "insufficient shares");
        uint256 grossPayout = _shares * fundState.sharePrice * 10 ** (baseAsset.decimals()) / 1 ether / 1 ether;

        //we need to deduct perfomance fees that may not have been crystalised yet before an investor leaves the fund
        uint256 netPayout;
        if (isPendingUncrystalised) {
            uint256 crystalisedShareOfFees = _shares * fundState.pendingPerfFees / totalSupply() / 1 ether; //@todo fix weimath here - also could there be a case of zero total supply?
            netPayout = grossPayout - crystalisedShareOfFees;
            fundState.pendingPerfFees -= crystalisedShareOfFees;
            _pay(manager, crystalisedShareOfFees);
        } else {
            //here no perf fee is due
            netPayout = grossPayout;
        }
        //burn shares first before exec for reentrancy safety
        _burn(msg.sender, _shares);
        fundState.totalAssets = fundState.totalAssets - (grossPayout * 1 ether / 10 ** (baseAsset.decimals())); //note that we use grossPayout here as this is the investor assets and fees that leave the fund
        //if total supply is 0 because of a full withdrawal we will get div 0 error without this
        if (totalSupply() != 0) {
            fundState.sharePrice = fundState.totalAssets * (1 ether) / totalSupply();
        } else {
            fundState.sharePrice = 1 ether;
        }
        _pay(msg.sender, netPayout);
        emit Withdrawn(address(baseAsset), msg.sender, block.timestamp, netPayout, _shares);
    }

    function _calculatePendingAumFee() internal {
        uint256 aumFeeAmount = fundState.totalAssets
            * (fundState.aumFeeRatePerSecond * (block.timestamp - fundState.lastAumFeeCalcTime)) / 1 ether;
        fundState.pendingAumFees += aumFeeAmount;
        fundState.lastAumFeeCalcTime = block.timestamp;
    }

    function _calculatePendingPerfFee() internal {
        //True implies perf fee and aum fee due, false means only aum fee due
        if (fundState.sharePrice > fundState.highWaterMark) {
            uint256 perfFeeAmount =
                (fundState.sharePrice - fundState.highWaterMark) * totalSupply() * fundState.perfFeeRate / 1e18;
            fundState.highWaterMark = fundState.sharePrice;
            fundState.lastAumFeeCalcTime = block.timestamp; //this may be useful for crystalisation down the line
            fundState.pendingPerfFees += perfFeeAmount;
        } else {
            //@audit add logic for where the performance has been lost and shareprice has fallen below hwm
        }
    }

    function _pay(address to, uint256 amount) internal {
        exec(
            address(baseAsset), 0, abi.encodeWithSelector(baseAsset.transfer.selector, to, amount), Enum.Operation.Call
        );
    }

    function _payoutAumFees() internal {
        uint256 feesDue = fundState.pendingAumFees;
        fundState.totalAssets -= feesDue;
        fundState.pendingAumFees = 0;
        _pay(manager, feesDue);
    }

    function _payoutPerfFees() internal {
        uint256 feesDue = fundState.pendingPerfFees;
        fundState.totalAssets -= feesDue;
        fundState.pendingPerfFees = 0;
        _pay(manager, feesDue);
    }

    //Can price the whole fund manually
    function _customValuation(uint256 netAssetValue) internal {
        fundState.lastValuationTime = block.timestamp;
        fundState.totalAssets = netAssetValue;
        if (fundState.totalAssets == 0) {
            fundState.sharePrice = 1 ether;
        } else {
            fundState.sharePrice = fundState.totalAssets * (1 ether) / totalSupply();
        }
        emit Priced(fundState.totalAssets, fundState.sharePrice, block.timestamp);
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
        emit Priced(fundState.totalAssets, fundState.sharePrice, block.timestamp);
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
