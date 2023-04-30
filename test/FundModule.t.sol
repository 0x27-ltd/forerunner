// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import {Test} from "../lib/forge-std/src/Test.sol";
import {MockSafe} from "../src/MockSafe.sol";
import {FundModule} from "../src/FundModule.sol";
import {BaseUtils} from "test/utils/BaseUtils.sol";
import "forge-std/console.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "../src/ERC20Decimal.sol";
import "../lib/solmate/src/utils/FixedPointMathLib.sol";

contract BaseHelper is BaseUtils {
    MockSafe safe;
    ERC20Decimal mockUsdc;
    FundModule fundModule;
    address manager;
    address accountant;
    address investor;
    uint256 constant MAX_UINT = 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;
    uint8 decimals = 6;

    function setUp() public virtual {
        safe = new MockSafe();
        mockUsdc = new ERC20Decimal("USD Coin", "USDC", decimals);
        manager = vm.addr(1);
        accountant = vm.addr(2);
        investor = vm.addr(3);
        fundModule = new FundModule("SHARES", "SHR", manager, accountant, address(safe), address(mockUsdc));
        safe.enableModule(address(fundModule));
    }

    function whitelistAndInvest(address _investor, uint256 _amount) public {
        vm.prank(accountant); //prank lasts one call into the future
        fundModule.addToWhitelist(_investor);
        assertTrue(fundModule.whitelist(_investor));
        modifyBalance(address(mockUsdc), _investor, 100 * 10 ** decimals);
        uint256 balance = mockUsdc.balanceOf(_investor);
        assertEq(balance, toWei(100, decimals));
        vm.startPrank(_investor);
        mockUsdc.approve(address(fundModule), MAX_UINT);
        fundModule.invest(_amount);
        vm.stopPrank();
    }

    function valueAndReprice(uint256 valuation) public {
        modifyBalance(
            address(fundModule.baseAsset()), address(safe), changeWei(valuation, 18, fundModule.baseAsset().decimals())
        );
        vm.prank(accountant);
        fundModule.customValuation(valuation);
    }
}

contract ModuleTest is BaseHelper {
    function setUp() public virtual override {
        BaseHelper.setUp();
    }

    // function test_correctAssetsAndPricePostInvest() public {

    // }

    // function test_correctShareIssuanceLogic() public {

    // }

    function test_canInvestViaModule() public {
        uint256 investAmount = toWei(1, decimals);
        whitelistAndInvest(investor, investAmount);
        assertEq(fundModule.balanceOf(investor), investAmount * 1 ether / 10 ** fundModule.baseAsset().decimals());
        assertEq(mockUsdc.balanceOf(address(safe)), investAmount);
    }

    function test_canInvestAndWithdrawViaModule() public {
        //test is written with assumption of first share being issued at 1
        uint256 investAmount = toWei(1, decimals);
        whitelistAndInvest(investor, investAmount);
        uint256 postInvestBalance = mockUsdc.balanceOf(address(investor));
        assertEq(fundModule.balanceOf(investor), changeWei(investAmount, decimals, 18));
        assertGt(mockUsdc.balanceOf(address(safe)), 0);
        //withdraw half
        uint256 sharesWithdrawn = changeWei(investAmount, decimals, 18) / 2;
        vm.prank(investor);
        fundModule.withdraw(sharesWithdrawn);
        uint256 expectedBalance = postInvestBalance + investAmount / 2;
        assertEq(mockUsdc.balanceOf(address(investor)), expectedBalance);
        assertEq(fundModule.balanceOf(investor), changeWei(investAmount, decimals, 18) / 2);
    }

    function test_canReuseStaleFundAfterFullWithdrawal() public {
        uint256 investAmount = toWei(11, decimals);
        whitelistAndInvest(investor, investAmount);
        uint256 sharesWithdrawn = changeWei(investAmount, decimals, 18);
        vm.prank(investor);
        fundModule.withdraw(sharesWithdrawn);
        vm.warp(block.timestamp + 40 days);
        assertEq(fundModule.totalAssets(), 0);
        assertEq(fundModule.sharePrice(), 1 ether);
        vm.prank(accountant);
        fundModule.baseAssetValuation();
        whitelistAndInvest(investor, toWei(9, decimals));
        assertEq(fundModule.totalAssets(), toWei(9, 18));
        assertEq(fundModule.sharePrice(), 1 ether);
    }

    function test_customValuation() public {
        uint256 investAmount = toWei(1, decimals);
        whitelistAndInvest(investor, investAmount);
        //simulating some return that would require repricing
        uint256 newNav = fundModule.totalAssets() * 2;
        // modifyBalance(address(mockUsdc), address(safe), newNav);
        vm.prank(accountant);
        fundModule.customValuation(newNav);
        assertEq(fundModule.totalAssets(), newNav);
        assertEq(fundModule.sharePrice(), 2 ether);
    }

    //@audit something wrong here
    function test_baseAssetValuation() public {
        uint256 investAmount = toWei(1, decimals);
        whitelistAndInvest(investor, investAmount);
        //simulating some return that would require repricing
        uint256 newNav = fundModule.totalAssets() * 2;
        modifyBalance(address(mockUsdc), address(safe), investAmount * 2);
        vm.prank(accountant);
        fundModule.baseAssetValuation();
        assertEq(fundModule.totalAssets(), newNav);
        assertEq(fundModule.sharePrice(), 2 ether);
    }

    function test_baseAssetValuationAtZero() public {
        assertEq(fundModule.lastValuationTime(), 1);
        vm.warp(block.timestamp + 40 days);
        vm.prank(accountant);
        fundModule.baseAssetValuation();
        assertEq(fundModule.lastValuationTime(), 1 + 40 days);
        assertEq(fundModule.totalAssets(), 0);
        assertEq(fundModule.sharePrice(), 1 ether);
    }

    function test_customValuationAtZero() public {
        assertEq(fundModule.lastValuationTime(), 1);
        vm.warp(block.timestamp + 40 days);
        vm.prank(accountant);
        fundModule.customValuation(0);
        assertEq(fundModule.lastValuationTime(), 1 + 40 days);
        assertEq(fundModule.totalAssets(), 0);
        assertEq(fundModule.sharePrice(), 1 ether);
    }

    function test_changeBaseAsset() public {
        //This test simulates a realistic scenario, a fund wishes to change base asset after setup
        ERC20Decimal mockDai = new ERC20Decimal("DAI Token", "DAI", 18);
        uint256 investAmount = toWei(1, decimals);
        whitelistAndInvest(investor, investAmount);
        //Simulate swapping one coin for another by balance rewriting
        modifyBalance(address(mockUsdc), address(safe), 0);
        modifyBalance(address(mockDai), address(safe), investAmount);
        vm.prank(manager);
        fundModule.changeBaseAsset(address(mockDai));
        assertEq(address(fundModule.baseAsset()), address(mockDai));
        vm.prank(investor);
        fundModule.withdraw(investAmount);
        assertEq(mockDai.balanceOf(investor), investAmount);
    }

    //Charlie clean this sh#t up
    function test_realLifeScenario() public {
        //multiple invests, repricings and withdraws
        //day one invest and reprice profitable day
        uint256 investAmount = toWei(100, decimals);
        whitelistAndInvest(investor, investAmount);
        valueAndReprice(changeWei(investAmount, 6, 18) * 1.1 ether / 1 ether);
        assertEq(fundModule.totalAssets(), toWei(110, 18));
        assertEq(fundModule.sharePrice(), toWei(11, 17));
        assertEq(fundModule.balanceOf(investor), toWei(100, 18));
        // day 2 invest more and reprice unprofitable day, withdraw half
        uint256 secondInvestAmount = toWei(10, decimals);
        whitelistAndInvest(investor, secondInvestAmount);
        assertEq(fundModule.totalSupply(), 109090909090909090909); //manually calculated with issuance formula
        assertEq(fundModule.totalAssets(), toWei(120, 18));
        valueAndReprice(fundModule.totalAssets() * 0.95 ether / 1 ether);
        assertEq(fundModule.totalAssets(), 114 ether);
        assertEq(fundModule.sharePrice(), 1.045 ether); //prev share price 1.1 * 0.95 = 1.045
        uint256 investorShares = fundModule.balanceOf(investor);
        assertEq(investorShares, 109090909090909090909);
        // uint256 assetsBeforeWithdraw = fundModule.totalAssets();
        vm.prank(investor);
        fundModule.withdraw(investorShares * 1 ether / 2 ether); //fundModule.balanceOf(investor)/2
        // console.log(mockUsdc.balanceOf(investor));
        assertEq(fundModule.balanceOf(investor), 54545454545454545455);
        // console.log(mockUsdc.balanceOf(address(safe)));
        assertEq(mockUsdc.balanceOf(address(safe)), (114 * 1e6 * 1 ether / 2 ether + 1)); //assetsBeforeWithdraw*1 ether/2 ether);
    }

    // function test_fixedMath() public view {
    //     // uint256 a = FixedPointMathLib.mulDivDown(x, y, denominator);
    //     uint256 a = 109090909090909090909*toWei(1, 6)/1 ether;
    //     uint256 b = FixedPointMathLib.mulWadDown(109090909090909090909, 1e6);
    //     console.log(a);
    //     console.log(b);
    // }

    //Things to double check -> ContextUpgradeable._msgSender() issue &Fix public variables

    //@todo
    //fundSafe variable can likely be replaced with the module's target or avatar (constructor still needs it but storage unnecessary)
    //use FixedPointMath from solmate so make FundModule.sol more readable

    //Left off:
    //Create new test file: FundModuleExtended and move the current test in there
    //Change FundModule to have one owner - the manager as a prop fund (extended keeps the roles)

    //* have a think of the conseq of the owner p-key being comprimised
}
