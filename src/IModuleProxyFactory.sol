pragma solidity ^0.8.10;

interface IModuleProxyFactory {
    event ModuleProxyCreation(address indexed proxy, address indexed masterCopy);

    function deployModule(address masterCopy, bytes memory initializer, uint256 saltNonce)
        external
        returns (address proxy);
}
