// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "forge-std/Test.sol";
import "../../src/FundModule.sol";
import "../../src/ERC20Decimal.sol";
import "../../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "../../src/MockSafe.sol";
import "../../src/IGnosisSafe.sol";
import "../../src/IGnosisSafeL2.sol";
import "../../src/IGnosisSafeProxyFactory.sol";
import "../../src/IRoles.sol";
import "../../src/IModuleProxyFactory.sol";
import "../../lib/openzeppelin-contracts/contracts/utils/Strings.sol";

//forge script script/roles/allowTarget.s.sol:allowTarget --rpc-url $LOCAL_HOST --broadcast -vvvv
contract allowTarget is Script, Test {
    //@note this script is chain specific!!!
    function setUp() public {}

    function run() public {
        address manager = vm.addr(vm.envUint("FUNDMODULE_MANAGER"));
        vm.startBroadcast(vm.envUint("FUNDMODULE_ACCOUNTANT"));
        address yourRolesDeployment = 0xe6aE52e0D66fD0fAb3983eB6150a18b388D06654;
        IRoles roles = IRoles(yourRolesDeployment);

        //assign new roles
        uint16[] memory rolesAssigned = new uint16[](1); //dynamic array so its not storage
        rolesAssigned[0] = 1;
        bool[] memory memberOf = new bool[](1);
        memberOf[0] = true;
        roles.assignRoles(manager, rolesAssigned, memberOf);

        //Allow target
        address arbUSDC = 0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8;
        roles.allowTarget(1, arbUSDC, 3);
        vm.stopBroadcast();

        //Test manager's role works
        // IERC20 usdc = IERC20(arbUSDC);
        // address randomAddress = address(uint160(uint256(keccak256(abi.encodePacked(uint256(27))))));
        // bytes memory approveData = abi.encodeWithSelector(usdc.approve.selector, randomAddress, uint256(1000000));
        // vm.broadcast(vm.envUint("FUNDMODULE_MANAGER"));
        // roles.execTransactionWithRole(arbUSDC, 0, approveData, 0, 1, true);
    }
}
