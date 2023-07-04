// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../src/FundModule.sol";
import "../test/utils/BaseUtils.sol";
import "../src/ERC20Decimal.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "../src/MockSafe.sol";
import "../src/IGnosisSafe.sol";
import "../src/IGnosisSafeL2.sol";
import "../src/IGnosisSafeProxyFactory.sol";
import "forge-std/Test.sol";
import "../lib/openzeppelin-contracts/contracts/utils/Strings.sol";

//Next time try using:
//https://github.com/colinnielsen/safe-tools

//This also had some safe stuff that may be useful down the line:
//https://github.com/emo-eth/create2-helpers

//Safe deployments
//https://github.com/safe-global/safe-deployments/blob/bf35d97bfbc63ad98b4f70fcb9d44aebfe6d3804/src/assets/v1.3.0/gnosis_safe_l2.json

//forge script script/BulkDeploy.s.sol:BulkDeployScript --rpc-url $LOCAL_HOST --broadcast -vvvv
contract existingSafeDeployFundMod is Script, Test {
    //@note this script is chain specific!!!
    function setUp() public {}

    address[] public owners; //keep this! read why in initData

    function run() public {
        address arbUSDC = 0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8;
        address manager = vm.addr(vm.envUint("FUNDMODULE_MANAGER"));
        address accountant = vm.addr(vm.envUint("FUNDMODULE_ACCOUNTANT"));

        //2.) Deploy Module on existing safe
        vm.startBroadcast(vm.envUint("FUNDMODULE_MANAGER")); //another option is --private-key $PRIVATE_KEY in cmd line when the script only needs one pk
        address existingSafe = 0xcb5631eC7A42edB1830a8BDE52d77123B21eBDB8;
        IERC20 usdc = IERC20(arbUSDC);

        FundModule fundModule = new FundModule(
            "VAULT",
            "VLT",
            manager, //@audit
            //can set accountant below as manager too for easier testing
            accountant,
            existingSafe,
            address(usdc)
        );

        //3.) enable the module
        //Worlds most janky way of getting the prevalidatedSignature :laughing-crying:
        //Problem is we need 0x...0xsomeAddress...001 and we only get 0x...0xsomeAddress...1 from the encoding
        uint256 zero = 0;
        bytes memory prevalidatedSignature = abi.encode(manager, zero);
        // emit log_bytes(prevalidatedSignature);
        //add one more byte than the original
        bytes memory paddedData = new bytes(65);

        // copy the original data into the new array right up until we stop to manually add 63 and 64
        for (uint256 i = 0; i < 63; i++) {
            paddedData[i] = prevalidatedSignature[i];
        }
        // add the two extra zeros
        paddedData[63] = 0x00;
        paddedData[64] = 0x01;
        // paddedData[31] = 0x00;
        // emit log_bytes(paddedData);
        // paddedData[61] = 0x00;

        IGnosisSafe safe = IGnosisSafe(existingSafe);
        bytes memory enableData = abi.encodeWithSelector(IGnosisSafe.enableModule.selector, address(fundModule));
        safe.execTransaction(existingSafe, 0, enableData, 0, 0, 0, 0, address(0), address(0), paddedData);

        // //4.) WL investor
        // fundModule.addToWhitelist(investor);
        // vm.stopBroadcast();

        // //5.) send manager some gas
        // vm.startBroadcast(vm.envUint("INVESTOR_PRIVATE_KEY")); //0x...A233
        // fundModule.sendStartingGas{value: 0.1 ether}();

        // //6.) approve & invest
        // uint256 amount = 1 * 10 ** 6;
        // usdc.approve(address(fundModule), amount);
        // fundModule.invest(amount);
        // vm.stopBroadcast();
    }
}
