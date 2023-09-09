// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity >=0.8.0;

contract MockSafe {
    address public module;

    error NotAuthorized(address unacceptedAddress);

    receive() external payable {}

    function enableModule(address _module) external {
        module = _module;
    }

    function exec(address payable to, uint256 value, bytes calldata data) external {
        bool success;
        bytes memory response;
        (success, response) = to.call{value: value}(data);
        if (!success) {
            assembly {
                revert(add(response, 0x20), mload(response))
            }
        }
    }

    function execTransactionFromModule(address payable to, uint256 value, bytes calldata data, uint8 operation)
        public
        returns (bool success)
    {
        if (msg.sender != module) revert NotAuthorized(msg.sender);
        if (operation == 1) (success,) = to.delegatecall(data);
        else (success,) = to.call{value: value}(data);
    }
    /// @dev Allows a Module to execute a Safe transaction without any further confirmations and return data
    /// @param to Destination address of module transaction.
    /// @param value Ether value of module transaction.
    /// @param data Data payload of module transaction.
    /// @param operation Operation type of module transaction.

    function execTransactionFromModuleReturnData(
        address payable to,
        uint256 value,
        bytes calldata data,
        uint8 operation
    ) public returns (bool success, bytes memory returnData) {
        success = execTransactionFromModule(to, value, data, operation);
        // solhint-disable-next-line no-inline-assembly
        assembly {
            // Load free memory location
            let ptr := mload(0x40)
            // We allocate memory for the return data by setting the free memory location to
            // current free memory location + data size + 32 bytes for data size value
            mstore(0x40, add(ptr, add(returndatasize(), 0x20)))
            // Store the size
            mstore(ptr, returndatasize())
            // Store the data
            returndatacopy(add(ptr, 0x20), 0, returndatasize())
            // Point the return data to the correct memory location
            returnData := ptr
        }
    }
}
