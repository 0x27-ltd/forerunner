// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import "../IModularCompliance.sol";
import "./AbstractModule.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 *  this module allows to require the pre-validation of a transfer before allowing it to be executed
 */
contract LimitInvestorsModule is AbstractModule {
    /// Mapping between transfer details and their approval status (amount of transfers approved) per compliance
    // mapping(address => mapping(bytes32 => uint)) private _transfersApproved;
    mapping(address => uint256) private _investors;
    mapping(address => uint8) private _maxInvestors;
    // uint256 public _investors;
    // uint8 public maxInvestors;

    /**
     *  @dev See {IModule-moduleTransferAction}.
     *  transfer approval is removed post-transfer if it was pre-approved
     *  the check on whether the transfer was pre-approved or not here is to allow forced transfers to bypass the module
     */
    function moduleTransferAction(address _from, address _to, uint256 _value) external override onlyComplianceCall {
        uint256 toBalance = IERC20(IModularCompliance(msg.sender).getTokenBound()).balanceOf(_to);
        uint256 fromBalance = IERC20(IModularCompliance(msg.sender).getTokenBound()).balanceOf(_from);
        // if (toBalance > 0){
        //     _investor
        // }
    }

    /**
     *  @dev See {IModule-moduleMintAction}.
     *  no mint action required in this module
     */
    // solhint-disable-next-line no-empty-blocks
    function moduleMintAction(address _to, uint256 _value) external override onlyComplianceCall {
        // _investors[msg.sender]++;
        // _maxInvestors[msg.sender];
        // emit InvestorAdded(_from, _to, _value, IModularCompliance(msg.sender).getTokenBound());
    }

    /**
     *  @dev See {IModule-moduleBurnAction}.
     *  no burn action required in this module
     */
    // solhint-disable-next-line no-empty-blocks
    function moduleBurnAction(address _from, uint256 _value) external override onlyComplianceCall {}

    /**
     *  @dev See {IModule-moduleCheck}.
     *  checks if the transfer is approved or not
     */
    function moduleCheck(address, /*_from*/ address, /*_to*/ uint256, /*_value*/ address _compliance)
        external
        view
        override
        returns (bool)
    {
        return isLimitReached(_compliance);
    }

    /**
     *  @dev Returns true if transfer is approved
     *  @param _compliance the modular compliance address
     *  requires `_compliance` to be bound to this module
     */
    function isLimitReached(address _compliance) public view returns (bool) {
        if (_investors[_compliance] >= _maxInvestors[_compliance]) {
            return true;
        }
        return false;
    }

    /**
     *  @dev Calculates the hash of a transfer approval
     *  @param _from the address of the transfer sender
     *  @param _to the address of the transfer receiver
     *  @param _amount the amount of tokens that `_from` would send to `_to`
     *  @param _token the address of the token that would be transferred
     *  returns the transferId of the transfer
     */
    function calculateTransferHash(address _from, address _to, uint256 _amount, address _token)
        public
        pure
        returns (bytes32)
    {
        bytes32 transferHash = keccak256(abi.encode(_from, _to, _amount, _token));
        return transferHash;
    }

    //@audit add modifier here so only fund can call this
    function addInvestor(address _compliance) external onlyComplianceCall {
        //@todo what if the maxInvestors is 0?
        require(_investors[_compliance] < _maxInvestors[_compliance], "Too Many Investors");
        _investors[_compliance]++;
    }

    function removeInvestor(address _compliance) external onlyComplianceCall {
        _investors[_compliance]--;
    }

    function setMaxInvestors(address _compliance, uint8 _max) external onlyComplianceCall {
        _maxInvestors[_compliance] = _max;
    }
}
