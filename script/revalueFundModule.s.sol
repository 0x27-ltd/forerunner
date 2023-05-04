// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../src/FundModule.sol";
import "../test/utils/BaseUtils.sol";
import "../src/ERC20Decimal.sol";
import "../src/MockSafe.sol";
import "../src/IFundModule.sol";

//To run this working script, deploying to SEPOLIA use this command below
//forge script script/revalueFundModule.s.sol:RevalueScript --rpc-url $MATIC_RPC_URL --broadcast -vvvv

contract RevalueScript is Script, Test {
    function setUp() public {}

    function run() public {
        IFundModule fundModule = IFundModule(0x4F057c87b1cB4705CAC8a580272dA772D85C169b);
        vm.startBroadcast(vm.envUint("FOX_PRIVATE_KEY"));
        fundModule.customValuation(0.96 ether);
    }
}
