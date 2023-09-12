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
// import "@solmate/utils/FixedPointMathLib.sol"; //PRBMath also an option

//run with verbosity (-v -> -vvvvv): forge test -vv
//run specific test contract: forge test -vv --match-contract ModuleTest

contract LimitInvestorTest is FundModuleBase {
    function setUp() public virtual override returns (FundModule, MockSafe) {
        (fundModule, safe) = FundModuleBase.setUp();
    }

    function testTransfer() public {
        FundModuleBase.getMockUsdc(address(safe), 1000000);
        // safe.enableModule(address(roles)); // needs to be enabled to allow execTxFromRole()
        easyAllowTargets(address(mockUsdc));
        vm.startPrank(manager);
        uint256 amount = 10000;
        bool success = fundModule.execWithPermission(
            address(mockUsdc),
            0,
            abi.encodeWithSelector(mockUsdc.transfer.selector, guardian, amount),
            Enum.Operation.Call,
            1,
            true
        );
        vm.stopPrank();
        assertEq(mockUsdc.balanceOf(guardian), amount);
    }

    function testInvest() public {
        // FundModuleBase.whitelistInvestor(investor);
        // FundModuleBase.getMockUsdc(investor, 1000000);
        // vm.prank(accountant);
        // FundModuleBase.fundModule._customValuation(0);

        // FundModuleBase.quickInvest(investor, 1000000, 0);
    }
}
