// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import {Test} from "../../lib/forge-std/src/Test.sol";
import {MockSafe} from "../../src/MockSafe.sol";
import {FundModule} from "../../src/FundModule.sol";
import "forge-std/StdCheats.sol";
import "forge-std/console.sol";
import "forge-std/console2.sol";
import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../../src/ERC20Decimal.sol";
import "../../src/InvestorLimits.sol";
// import "forge-std/StdInvariant.sol";
// import "@solmate/utils/FixedPointMathLib.sol"; //PRBMath also an option

//run with verbosity (-v -> -vvvvv): forge test -vv
//run specific test contract: forge test -vv --match-contract ModuleTest
//run specific test:
contract FundModuleBase is Test {
    MockSafe public safe;
    ERC20Decimal public mockUsdc;
    FundModule public fundModule;
    address public manager;
    address public accountant;
    address public investor;
    uint256 public constant MAX_UINT = 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;
    uint8 public decimals = 6;

    function setUp() public virtual {
        safe = new MockSafe();
        mockUsdc = new ERC20Decimal("USD Coin", "USDC", decimals);
        InvestorLimits investorLimits;
        investorLimits = new InvestorLimits(50);
        manager = vm.addr(1);
        accountant = vm.addr(2);
        investor = vm.addr(3);
        vm.label(manager, "manager"); //label addresses so the label appears in call traces not address
        vm.label(accountant, "accountant");
        vm.label(investor, "investor");
        fundModule = new FundModule(
            "FORERUNNER",
            "4RUNR",
            manager,
            accountant,
            address(safe),
            address(mockUsdc),
            0.02 ether,
            0.2 ether,
            90 days,
            address(investorLimits)
            );
        //enable module on Safe
        safe.enableModule(address(fundModule));
        //when StdInvariant is in use for stateful fuzz testing we need to define the target contract that will have its functions called
        // targetContract(address(fundModule));
    }

    function getMockUsdc(address _investor, uint256 _amount) public {
        //vm.deal with 4 params not working here so importing StdCheats as a work around
        StdCheats.deal(address(mockUsdc), _investor, _amount, true);
        assertEq(mockUsdc.balanceOf(_investor), _amount);
    }

    function whitelistInvestor(address _investor) public {
        vm.prank(accountant);
        fundModule.addToWhitelist(_investor);
        assertTrue(fundModule.whitelist(_investor));
    }

    function quickInvest(address _investor, uint256 _amount, uint256 _valuation) public {
        whitelistInvestor(_investor);
        getMockUsdc(_investor, _amount);
        vm.prank(_investor);
        fundModule.queueInvestment(_amount);
        vm.prank(accountant);
        // fundModule.updateStateWithPrice(_valuation);
        // assertTrue(fundModule.balanceOf(_investor) > 0);
    }
}
