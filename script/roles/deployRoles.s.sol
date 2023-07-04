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

//forge script script/roles/deployRoles.s.sol:deployRoles --rpc-url $LOCAL_HOST --broadcast -vvvv
contract deployRoles is Script, Test {
    //@note this script is chain specific!!!
    function setUp() public {}

    function run() public {
        address manager = vm.addr(vm.envUint("FUNDMODULE_MANAGER"));
        address accountant = vm.addr(vm.envUint("FUNDMODULE_ACCOUNTANT"));

        vm.startBroadcast(vm.envUint("FUNDMODULE_MANAGER")); //another option is --private-key $PRIVATE_KEY in cmd line when the script only needs one pk
        address existingSafe = 0xcb5631eC7A42edB1830a8BDE52d77123B21eBDB8;

        address arbRolesMasterCopy = 0xD8DfC1d938D7D163C5231688341e9635E9011889;
        address arbModuleProxyFactory = 0x000000000000aDdB49795b0f9bA5BC298cDda236;
        bytes memory encodeAddresses = abi.encode(accountant, existingSafe, existingSafe); //_owner, _avatar, _target
        // IRoles roles = IRoles(arbRolesMasterCopy);
        bytes memory setupParams = abi.encodeWithSelector(IRoles.setUp.selector, encodeAddresses);
        uint256 tsSalt = block.timestamp * 10 ** 3; //safe ui uses milliseconds not seconds
        // IModuleProxyFactory moduleFactory = IModuleProxyFactory(arbModuleProxyFactory);
        bytes memory deployData =
            abi.encodeWithSelector(IModuleProxyFactory.deployModule.selector, arbRolesMasterCopy, setupParams, tsSalt);

        IGnosisSafe safe = IGnosisSafe(existingSafe);
        uint256 zero = 0;
        bytes memory prevalidatedSignature = abi.encode(manager, zero);
        bytes memory paddedData = new bytes(65);
        for (uint256 i = 0; i < 63; i++) {
            paddedData[i] = prevalidatedSignature[i];
        }
        paddedData[63] = 0x00;
        paddedData[64] = 0x01;
        safe.execTransaction(arbModuleProxyFactory, 0, deployData, 0, 0, 0, 0, address(0), address(0), paddedData);
    }
}
