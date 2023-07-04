// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "forge-std/Test.sol";
import "../../src/FundModule.sol";
import "../../test/utils/BaseUtils.sol";
import "../../src/ERC20Decimal.sol";
import "../../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "../../src/MockSafe.sol";
import "../../src/IGnosisSafe.sol";
import "../../src/IGnosisSafeL2.sol";
import "../../src/IGnosisSafeProxyFactory.sol";
import "../../src/IRoles.sol";
import "../../src/IModuleProxyFactory.sol";
import "../../lib/openzeppelin-contracts/contracts/utils/Strings.sol";

//forge script script/roles/enableModAndSetMS.s.sol:enableModAndSetMS --rpc-url $LOCAL_HOST --broadcast -vvvv
contract enableModAndSetMS is Script, Test {
    //@note this script is chain specific!!!
    function setUp() public {}

    function run() public {
        address manager = vm.addr(vm.envUint("FUNDMODULE_MANAGER"));

        vm.startBroadcast(vm.envUint("FUNDMODULE_MANAGER"));
        address existingSafe = 0xcb5631eC7A42edB1830a8BDE52d77123B21eBDB8;

        IGnosisSafe safe = IGnosisSafe(existingSafe);
        uint256 zero = 0;
        bytes memory prevalidatedSignature = abi.encode(manager, zero);
        bytes memory paddedData = new bytes(65);
        for (uint256 i = 0; i < 63; i++) {
            paddedData[i] = prevalidatedSignature[i];
        }
        paddedData[63] = 0x00;
        paddedData[64] = 0x01;

        address yourRolesDeployment = 0xe6aE52e0D66fD0fAb3983eB6150a18b388D06654; //not master!
        bytes memory enableData = abi.encodeWithSelector(IGnosisSafe.enableModule.selector, yourRolesDeployment);
        safe.execTransaction(existingSafe, 0, enableData, 0, 0, 0, 0, address(0), address(0), paddedData);
        vm.stopBroadcast();
        address arbMultisend = 0xA238CBeb142c10Ef7Ad8442C6D1f9E89e07e7761;
        IRoles roles = IRoles(yourRolesDeployment);
        vm.broadcast(vm.envUint("FUNDMODULE_ACCOUNTANT"));
        roles.setMultisend(arbMultisend);

        // bytes memory setMsData = abi.encodeWithSelector(IRoles.setMultisend.selector, arbMultisend);
        // safe.execTransaction(yourRolesDeployment, 0, setMsData, 0, 0, 0, 0, address(0), address(0), paddedData);
    }
}
