// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../src/FundModule.sol";
import "../test/utils/BaseUtils.sol";
import "../src/ERC20Decimal.sol";
import "../src/MockSafe.sol";

// run source .env in terminal so you have access to the .env file vars
//To dry run this script, deploying to forked SEPOLIA
//In new terminal: anvil --rpc-url $SEPOLIA_RPC_URL
//In another terminal: forge script script/FundModule.s.sol:FundModuleScript --rpc-url $LOCAL_HOST --private-key $PRIVATE_KEY --broadcast -vvvv

//To run this working script, deploying to SEPOLIA use this command below
//forge script script/FundModule.s.sol:FundModuleScript --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY --broadcast -vvvv
contract FundModuleScript is Script, BaseUtils {
    function setUp() public {}

    // function run() public {
    //     address safe = vm.addr(1);
    //     address dummyManager = vm.addr(2);
    //     address dummyAccountant = vm.addr(3);
    //     address dummyUsdc = vm.addr(3);
    //     vm.broadcast(); //don't need to pass a private-key in here as we pass --private-key $PRIVATE_KEY in cmd line
    //     FundModule fundModule = new FundModule(
    //         "TEST",
    //         "TST",
    //         dummyManager,
    //         dummyAccountant,
    //         safe,
    //         dummyUsdc
    //     );
    // }

    //sending eth via cast:
    //cast send 0x44b1f90EF392a310e94A6Ece5D301Ecf69d1bd09 --value 1000000000000000000 --from 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
    function run() public {
        address safe = 0x64D74963Abb7F76858eA38A77f15fDC36d9e8d25; //polygon safe
        address manager = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266; //0xe425c866Fd781064c394e1250730A2067F30f394; //vault manager alpha
        address accountant = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8; //using monoshared add here
        //can use this as investor: 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC
        // address usdc = 0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174; //polygon usdc
        vm.startBroadcast();
        //@audit left of here trying to change real usdc which is hard to get for testing to mockUsdc
        //might need to use a erc20 version that lets me mint
        MockSafe mockSafe = new MockSafe();
        ERC20Decimal mockUsdc = new ERC20Decimal("USD Coin", "USDC", 6);
        // address vaultDepositorAlpha = 0xF89f224eF382f6C3D9D43876E16a04A8dDF4c861;
        // modifyBalance(0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174, vaultDepositorAlpha, 100000000);
        // vm.deal(vaultDepositorAlpha, 101 ether); //load address for PRIVATE_KEY in .env
        FundModule fundModule = new FundModule(
            "VAULT Token",
            "VLT",
            manager,
            accountant,
            address(mockSafe),
            address(mockUsdc)
        );
        mockSafe.enableModule(address(fundModule));
        vm.stopBroadcast();
    }

    // function run() public view {
    //     address frank = vm.addr(vm.envUint("PRIVATE_KEY"));
    //     console.log(frank);
    // }
}
