// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../src/FundModule.sol";

// run source .env in terminal so you have access to the .env file vars
//To dry run this script, deploying to forked SEPOLIA
//In new terminal: anvil --rpc-url $SEPOLIA_RPC_URL
//In another terminal: forge script script/FundModule.s.sol:FundModuleScript --rpc-url $LOCAL_HOST --private-key $PRIVATE_KEY --broadcast -vvvv

//To run this working script, deploying to SEPOLIA use this command below
//forge script script/FundModule.s.sol:FundModuleScript --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY --broadcast -vvvv
contract FundModuleScript is Script {
    function setUp() public {}

    function run() public {
        address safe = vm.addr(1);
        address dummyManager = vm.addr(2);
        address dummyAccountant = vm.addr(3);
        address dummyUsdc = vm.addr(3);
        vm.broadcast(); //don't need to pass a private-key in here as we pass --private-key $PRIVATE_KEY in cmd line
        FundModule fundModule = new FundModule(
            "TEST",
            "TST",
            dummyManager,
            dummyAccountant,
            safe,
            dummyUsdc,
            0.02 ether,
            0.2 ether
        );
    }
}
