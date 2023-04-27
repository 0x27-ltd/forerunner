// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import {Test} from "../lib/forge-std/src/Test.sol";
import {MockSafe} from "../src/MockSafe.sol";
import {FundModule} from "../src/FundModule.sol";
import {BaseHelper} from "test/utils/BaseHelper.sol";
import "forge-std/console.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract ModuleTest is BaseHelper {
    MockSafe safe;
    ERC20 mockUsdc;
    FundModule fundModule;
    address accountant;
    address dummy;

    function setUp() public {
        safe = new MockSafe();
        mockUsdc = new ERC20("USD Coin", "USDC");
        address manager = vm.addr(1);
        accountant = vm.addr(2);
        dummy = vm.addr(3);
        fundModule = new FundModule("SHARES", "SHR", manager, accountant, address(safe), address(mockUsdc), 0.02 ether, 0.2 ether);
        safe.enableModule(address(fundModule));
    }

    function test_canInvestAndWithdrawViaModule() public {
        vm.prank(accountant); //prank lasts one call into the future
        fundModule.addToWhitelist(dummy);
        assertTrue(fundModule.whitelist(dummy));
        modifyBalance(address(mockUsdc), dummy, 1 ether);
        uint balance = mockUsdc.balanceOf(dummy);
        assertGt(balance, 0);
        vm.startPrank(dummy); //lasts until turned off
        mockUsdc.approve(address(fundModule), 100 ether);
        fundModule.invest(1 ether);
        assertGt(fundModule.balanceOf(dummy), 0);
        assertGt(mockUsdc.balanceOf(address(safe)), 0);
        fundModule.withdraw(0.1 ether);
        assertEq(fundModule.balanceOf(dummy), 0.9 ether);
        assertEq(mockUsdc.balanceOf(dummy), 0.1 ether);
        vm.stopPrank();
    }
}