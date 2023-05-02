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
import "../src/IGnosisSafeProxyFactory.sol";
import "forge-std/Test.sol";
import "../lib/openzeppelin-contracts/contracts/utils/Strings.sol";

//Next time try using:
//https://github.com/colinnielsen/safe-tools
//forge script script/BulkDeploy.s.sol:BulkDeployScript --rpc-url $LOCAL_HOST --broadcast -vvvv
contract BulkDeployScript is Script, Test {
    //@note this is for MATIC!!!
    function setUp() public {}

    address[] public owners; //keep this! read why in initData

    function run() public {
        address manager = vm.addr(vm.envUint("FOX_PRIVATE_KEY"));
        address investor = vm.addr(vm.envUint("INVESTOR_PRIVATE_KEY"));
        vm.startBroadcast(vm.envUint("FOX_PRIVATE_KEY")); //don't need to pass a private-key in here as we pass --private-key $PRIVATE_KEY in cmd line

        //1.) Deploy Safe (or can use ui)
        //mastercopy @audit I am creating an L1 style gnosis safe here - might want to change this later
        //Gnosis safe UI for polygon uses the L2 one from what I can tell so the ui doesn't work perfectly with L1 style apparently
        IGnosisSafe masterSafe = IGnosisSafe(0xd9Db270c1B5E3Bd161E8c8503c55cEABeE709552);
        address DEFAULT_FALLBACK_HANDLER_ADDRESS = 0xf48f2B2d2a534e402487b3ee7C18c33Aec0Fe5e4;

        owners.push(manager);
        bytes memory initData = abi.encodeWithSelector(
            IGnosisSafe.setup.selector,
            owners, //weird quirk - if you use [manager] the encoding doesn't work as the array becomes static and not dynamic
            1, //threshold
            address(0),
            new bytes(0),
            DEFAULT_FALLBACK_HANDLER_ADDRESS,
            address(0),
            0,
            payable(address(0))
        );
        IGnosisSafeProxyFactory proxyFactory = IGnosisSafeProxyFactory(0xa6B71E26C5e0845f74c812102Ca7114b6a896AB2);
        address safeProxy = proxyFactory.createProxyWithNonce(address(masterSafe), initData, block.timestamp);
        // emit log_bytes(initData);
        //get correct calldata: cast calldata "setup(address[],uint256,address,bytes,address,address,uint256,address)" "[0xED2955881557A1951A9D1BDb346443657103a2a4]" 1 0x0000000000000000000000000000000000000000 0x 0xf48f2B2d2a534e402487b3ee7C18c33Aec0Fe5e4 0x0000000000000000000000000000000000000000 0 0x0000000000000000000000000000000000000000
        //cast --calldata-decode "setup(address[],uint256,address,bytes,address,address,uint256,address)"

        //2.) Deploy Module
        address accountant = vm.addr(vm.envUint("FOX_PRIVATE_KEY"));
        IERC20 usdc = IERC20(0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174);

        FundModule fundModule = new FundModule(
            "VAULT Token",
            "VLT",
            manager,
            //intentionally setting accountant below as manager just for easier testing
            manager,
            safeProxy,
            address(usdc)
        );

        //3.) enable the module
        //Worlds most janky way of getting the prevalidatedSignature :laughing-crying:
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

        IGnosisSafe safe = IGnosisSafe(safeProxy);
        bytes memory enableData = abi.encodeWithSelector(IGnosisSafe.enableModule.selector, address(fundModule));
        safe.execTransaction(address(safeProxy), 0, enableData, 0, 0, 0, 0, address(0), address(0), paddedData);

        //4.) WL investor
        fundModule.addToWhitelist(investor);
        vm.stopBroadcast();

        //5.) send manager some gas
        vm.startBroadcast(vm.envUint("INVESTOR_PRIVATE_KEY")); //0x...A233
        fundModule.sendStartingGas{value: 0.1 ether}();

        //6.) approve & invest
        uint256 amount = 1 * 10 ** 6;
        usdc.approve(address(fundModule), amount);
        fundModule.invest(amount);
        vm.stopBroadcast();
    }
}
