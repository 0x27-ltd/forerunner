pragma solidity ^0.8.10;

interface IFundModule {
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event AvatarSet(address indexed previousAvatar, address indexed newAvatar);
    event ChangedGuard(address guard);
    event Initialized(uint8 version);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event TargetSet(address indexed previousTarget, address indexed newTarget);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event invested(
        address indexed baseAsset, address indexed investor, uint256 timestamp, uint256 amount, uint256 shares
    );
    event modifiedWhitelist(address indexed investor, uint256 timestamp, bool isWhitelisted);
    event priced(uint256 totalAssets, uint256 sharePrice, uint256 timestamp);
    event withdrawn(
        address indexed baseAsset, address indexed investor, uint256 timestamp, uint256 amount, uint256 shares
    );

    struct FundState {
        uint256 totalAssets;
        uint256 sharePrice;
        uint256 lastValuationTime;
    }

    function accountant() external view returns (address);
    function addToWhitelist(address _address) external;
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function avatar() external view returns (address);
    function balanceOf(address account) external view returns (uint256);
    function baseAsset() external view returns (address);
    function baseAssetValuation() external;
    function changeBaseAsset(address newBaseAsset) external;
    function customValuation(uint256 netAssetValue) external;
    function decimals() external view returns (uint8);
    function decreaseAllowance(address spender, uint256 subtractedValue) external returns (bool);
    function fundState() external view returns (uint256 totalAssets, uint256 sharePrice, uint256 lastValuationTime);
    function getFundState() external view returns (FundState memory);
    function getGuard() external view returns (address _guard);
    function guard() external view returns (address);
    function increaseAllowance(address spender, uint256 addedValue) external returns (bool);
    function invest(uint256 _amount) external;
    function manager() external view returns (address);
    function name() external view returns (string memory);
    function owner() external view returns (address);
    function removeFromWhitelist(address _address) external;
    function renounceOwnership() external;
    function sendStartingGas() external payable;
    function setAvatar(address _avatar) external;
    function setGuard(address _guard) external;
    function setTarget(address _target) external;
    function setUp(bytes memory initializeParams) external;
    function symbol() external view returns (string memory);
    function target() external view returns (address);
    function totalSupply() external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function transferOwnership(address newOwner) external;
    function whitelist(address) external view returns (bool);
    function withdraw(uint256 _shares) external;


    /**
     *  this event is emitted when the Compliance has been set for the token
     *  the event is emitted by the token constructor and by the setCompliance function
     *  `_compliance` is the address of the Compliance contract of the token
     */
    event ComplianceAdded(address indexed _compliance);
    /**
     *  @dev sets the compliance contract of the token
     *  @param _compliance the address of the compliance contract to set
     *  Only the owner of the token smart contract can call this function
     *  calls bindToken on the compliance contract
     *  emits a `ComplianceAdded` event
     */
    function setCompliance(address _compliance) external;
}
