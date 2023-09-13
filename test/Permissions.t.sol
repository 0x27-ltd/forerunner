// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import {Test} from "../lib/forge-std/src/Test.sol";
import {MockSafe} from "../src/MockSafe.sol";
import {FundModule} from "../src/FundModule.sol";
import "forge-std/console.sol";
import "forge-std/console2.sol";
// import "forge-std/StdInvariant.sol";
import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../src/ERC20Decimal.sol";
import "./utils/FundModuleBase.sol";

contract PermissionsTest is FundModuleBase {
    /// Sender is allowed to make this call, but the internal transaction failed
    error ModuleTransactionFailed();

    function setUp() public virtual override returns (FundModule, MockSafe) {
        (fundModule, safe) = FundModuleBase.setUp();
    }

    function easyAllow() internal {
        FundModuleBase.getMockUsdc(address(safe), 1000000);
        // safe.enableModule(address(roles)); // needs to be enabled to allow execTxFromRole()
        easyAllowTargets(address(mockUsdc));
    }

    function testPermissions() public {
        easyAllow();
        vm.startPrank(manager);
        uint256 amount = 10000;
        address to = address(mockUsdc);
        bytes memory data = abi.encodeWithSelector(mockUsdc.transfer.selector, guardian, amount);
        Enum.Operation operation = Enum.Operation.Call;
        // start execTransactionWithRole
        bool success = fundModule.execWithPermission(to, 0, data, operation);
        // IRoles(fundModule.fundRoles()).check(to, 0, data, uint8(operation), 1);
        vm.stopPrank();
        // safe.exec(payable(to), 0, data);
        // end
        assertEq(mockUsdc.balanceOf(guardian), amount);
    }
}
