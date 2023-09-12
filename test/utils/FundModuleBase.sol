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
import "zodiac-modifier-roles-v1/Roles.sol";
// import "zodiac-modifier-roles-v1/Permissions.sol";
import "../../src/ERC20Decimal.sol";
import "../../src/IRoles.sol";
import "./WeiHelper.sol";
// import "forge-std/StdInvariant.sol";
// import "@solmate/utils/FixedPointMathLib.sol"; //PRBMath also an option

//run with verbosity (-v -> -vvvvv): forge test -vv
//run specific test contract: forge test -vv --match-contract ModuleTest
//run specific test:
contract FundModuleBase is Test, WeiHelper {
    MockSafe public safe;
    Roles public roles;
    ERC20Decimal public mockUsdc;
    FundModule public fundModule;
    address public manager;
    address public accountant;
    address public investor;
    address public guardian;
    uint256 public constant MAX_UINT = 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;
    uint8 public decimals = 6;

    function setUp() public virtual returns (FundModule, MockSafe) {
        safe = new MockSafe();
        mockUsdc = new ERC20Decimal("USD Coin", "USDC", decimals);
        manager = vm.addr(1);
        accountant = vm.addr(2);
        investor = vm.addr(3);
        vm.label(manager, "manager"); //label addresses so the label appears in call traces not address
        vm.label(accountant, "accountant");
        vm.label(address(safe), "safe");
        vm.label(investor, "investor");
        guardian = vm.addr(4);
        vm.label(guardian, "guardian");
        fundModule = new FundModule(
            "FORERUNNER",
            "4RUNR",
            manager,
            accountant,
            address(safe),
            address(mockUsdc),
            0.02 ether,
            0.2 ether,
            90 days
            );
        roles = _deployRoles();
        fundModule.configAccessControl(address(roles), address(guardian));
        vm.label(address(roles), "roles");
        vm.label(address(fundModule), "fundModule");
        //enable module on Safe
        safe.enableModule(address(fundModule));
        safe.enableModule(address(roles));
        //when StdInvariant is in use for stateful fuzz testing we need to define the target contract that will have its functions called
        // targetContract(address(fundModule));
        return (fundModule, safe);
    }

    function _deployRoles() internal returns (Roles deployed) {
        deployed = new Roles(guardian, address(safe), address(safe)); //@todo replace owner as fundModule
        uint16[] memory assignRoles = new uint16[](1);
        assignRoles[0] = uint16(1);
        bool[] memory memberOf = new bool[](1);
        memberOf[0] = true;
        vm.startPrank(guardian);
        deployed.assignRoles(address(fundModule), assignRoles, memberOf);
        deployed.setDefaultRole(address(fundModule), 1);
        vm.stopPrank();
    }

    function easyAllowTargets(address target) public {
        //Although role whitelisting can be much more granular, doing contract wide allows is a nice simplification for initial testing
        vm.prank(guardian);
        roles.allowTarget(1, target, ExecutionOptions(3));
    }

    function getMockUsdc(address _investor, uint256 _amount) public {
        //vm.deal with 4 params not working here so importing StdCheats as a work around
        StdCheats.deal(address(mockUsdc), _investor, _amount, true);
        assertEq(mockUsdc.balanceOf(_investor), _amount);
    }

    function getMockUsdcMultiple(address[] memory _investors, uint256 _amount) public {
        for (uint256 i = 0; i < _investors.length; i++) {
            StdCheats.deal(address(mockUsdc), _investors[i], _amount, true);
            assertEq(mockUsdc.balanceOf(_investors[i]), _amount);
        }
    }

    function whitelistInvestor(address _investor) public {
        vm.prank(accountant);
        fundModule.addToWhitelist(_investor);
        assertTrue(fundModule.whitelist(_investor));
    }

    function unwhitelistInvestor(address _investor) public {
        vm.prank(accountant);
        fundModule.removeFromWhitelist(_investor);
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

    function quickWithdraw(address _investor, uint256 _shares, uint256 _valuation) public {
        assertTrue(FundModuleBase.fundModule.balanceOf(_investor) > 0);
        vm.prank(investor);
        fundModule.queueWithdrawal(_shares);
        vm.prank(accountant);
        fundModule.updateStateWithPrice(_valuation);
    }
}
