pragma solidity ^0.8.10;

interface IRoles {
    event AssignRoles(address module, uint16[] roles, bool[] memberOf);
    event AvatarSet(address indexed previousAvatar, address indexed newAvatar);
    event ChangedGuard(address guard);
    event DisabledModule(address module);
    event EnabledModule(address module);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event RolesModSetup(address indexed initiator, address indexed owner, address indexed avatar, address target);
    event SetDefaultRole(address module, uint16 defaultRole);
    event SetMultisendAddress(address multisendAddress);
    event TargetSet(address indexed previousTarget, address indexed newTarget);

    function allowTarget(uint16 role, address targetAddress, uint8 options) external;
    function assignRoles(address module, uint16[] memory _roles, bool[] memory memberOf) external;
    function avatar() external view returns (address);
    function defaultRoles(address) external view returns (uint16);
    function disableModule(address prevModule, address module) external;
    function enableModule(address module) external;
    function execTransactionFromModule(address to, uint256 value, bytes memory data, uint8 operation)
        external
        returns (bool success);
    function execTransactionFromModuleReturnData(address to, uint256 value, bytes memory data, uint8 operation)
        external
        returns (bool, bytes memory);
    function execTransactionWithRole(
        address to,
        uint256 value,
        bytes memory data,
        uint8 operation,
        uint16 role,
        bool shouldRevert
    ) external returns (bool success);
    function execTransactionWithRoleReturnData(
        address to,
        uint256 value,
        bytes memory data,
        uint8 operation,
        uint16 role,
        bool shouldRevert
    ) external returns (bool success, bytes memory returnData);
    function getGuard() external view returns (address _guard);
    function getModulesPaginated(address start, uint256 pageSize)
        external
        view
        returns (address[] memory array, address next);
    function guard() external view returns (address);
    function isModuleEnabled(address _module) external view returns (bool);
    function multisend() external view returns (address);
    function owner() external view returns (address);
    function renounceOwnership() external;
    function revokeTarget(uint16 role, address targetAddress) external;
    function scopeAllowFunction(uint16 role, address targetAddress, bytes4 functionSig, uint8 options) external;
    function scopeFunction(
        uint16 role,
        address targetAddress,
        bytes4 functionSig,
        bool[] memory isParamScoped,
        uint8[] memory paramType,
        uint8[] memory paramComp,
        bytes[] memory compValue,
        uint8 options
    ) external;
    function scopeFunctionExecutionOptions(uint16 role, address targetAddress, bytes4 functionSig, uint8 options)
        external;
    function scopeParameter(
        uint16 role,
        address targetAddress,
        bytes4 functionSig,
        uint256 paramIndex,
        uint8 paramType,
        uint8 paramComp,
        bytes memory compValue
    ) external;
    function scopeParameterAsOneOf(
        uint16 role,
        address targetAddress,
        bytes4 functionSig,
        uint256 paramIndex,
        uint8 paramType,
        bytes[] memory compValues
    ) external;
    function scopeRevokeFunction(uint16 role, address targetAddress, bytes4 functionSig) external;
    function scopeTarget(uint16 role, address targetAddress) external;
    function setAvatar(address _avatar) external;
    function setDefaultRole(address module, uint16 role) external;
    function setGuard(address _guard) external;
    function setMultisend(address _multisend) external;
    function setTarget(address _target) external;
    function setUp(bytes memory initParams) external;
    function target() external view returns (address);
    function transferOwnership(address newOwner) external;
    function unscopeParameter(uint16 role, address targetAddress, bytes4 functionSig, uint8 paramIndex) external;
    function check(address to, uint256 value, bytes memory data, uint8 operation, uint16 role)
        external
        returns (bool success);
}
