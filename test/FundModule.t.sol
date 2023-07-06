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
import "../src/InvestorLimits.sol";
import "./utils/FundModuleBase.sol";
// import "@solmate/utils/FixedPointMathLib.sol"; //PRBMath also an option

//run with verbosity (-v -> -vvvvv): forge test -vv
//run specific test contract: forge test -vv --match-contract ModuleTest

contract FundModuleTest is FundModuleBase {
    function setUp() public virtual override {
        FundModuleBase.setUp();
    }

    function testInvest() public {
        // FundModuleBase.whitelistInvestor(investor);
        // FundModuleBase.getMockUsdc(investor, 1000000);
        // vm.prank(accountant);
        // FundModuleBase.fundModule._customValuation(0);

        FundModuleBase.quickInvest(investor, 1000000, 0);
    }
}
