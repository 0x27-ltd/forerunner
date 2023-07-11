pragma solidity 0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "./compliance/IModularCompliance.sol";

contract FundToken is ERC20 {

    IModularCompliance internal _tokenCompliance;
    constructor(
        string memory _name,
        string memory _symbol
    ) ERC20(_name, _symbol) {}

    /**
         *  @dev See {IToken-mint}.
     */
    function mint(address _to, uint256 _amount) internal {
        // require(_tokenIdentityRegistry.isVerified(_to), "Identity is not verified.");
        require(_tokenCompliance.canTransfer(address(0), _to, _amount), "Compliance not followed");
        _mint(_to, _amount);
        _tokenCompliance.created(_to, _amount);
        // _tokenCompliance.transferred(address(0), _to, _amount);
    }

    /**
        *  @dev See {IToken-burn}.
     */
    function burn(address _userAddress, uint256 _amount) internal {
        require(balanceOf(_userAddress) >= _amount, "cannot burn more than balance");
        // uint256 freeBalance = balanceOf(_userAddress) - _frozenTokens[_userAddress];
        // if (_amount > freeBalance) {
        //     uint256 tokensToUnfreeze = _amount - (freeBalance);
        //     _frozenTokens[_userAddress] = _frozenTokens[_userAddress] - (tokensToUnfreeze);
        //     emit TokensUnfrozen(_userAddress, tokensToUnfreeze);
        // }
        _burn(_userAddress, _amount);
        _tokenCompliance.destroyed(_userAddress, _amount);
        // _tokenCompliance.transferred(_userAddress, address(0), _amount);
    }

    /**
     *  @notice ERC-20 overridden function that include logic to check for trade validity.
     *  Require that the from and to addresses are not frozen.
     *  Require that the value should not exceed available balance .
     *  Require that the to address is a verified address
     *  @param _from The address of the sender
     *  @param _to The address of the receiver
     *  @param _amount The number of tokens to transfer
     *  @return `true` if successful and revert if unsuccessful
     */
    function transferFrom(
        address _from,
        address _to,
        uint256 _amount
    ) public override returns (bool) {
        // require(!_frozen[_to] && !_frozen[_from], "wallet is frozen");
        // require(_amount <= balanceOf(_from) - (_frozenTokens[_from]), "Insufficient Balance");
        uint256 currentAllowance = allowance(_from, msg.sender);
        require(currentAllowance >= _amount, "Insufficient Allowance");
        if (_tokenCompliance.canTransfer(_from, _to, _amount)) {
            _approve(_from, msg.sender, currentAllowance - _amount);
            _transfer(_from, _to, _amount);
            _tokenCompliance.transferred(_from, _to, _amount);
            return true;
        }
        revert("Transfer not possible");
    }

    /**
     *  @notice ERC-20 overridden function that include logic to check for trade validity.
     *  Require that the msg.sender and to addresses are not frozen.
     *  Require that the value should not exceed available balance .
     *  Require that the to address is a verified address
     *  @param _to The address of the receiver
     *  @param _amount The number of tokens to transfer
     *  @return `true` if successful and revert if unsuccessful
     */
    function transfer(address _to, uint256 _amount) public override returns (bool) {
        // require(!_frozen[_to] && !_frozen[msg.sender], "wallet is frozen");
        // require(_amount <= balanceOf(msg.sender) - (_frozenTokens[msg.sender]), "Insufficient Balance");
        // if (_tokenIdentityRegistry.isVerified(_to) && _tokenCompliance.canTransfer(msg.sender, _to, _amount)) {
        address owner = _msgSender();
        if (_tokenCompliance.canTransfer(msg.sender, _to, _amount)) {
            _transfer(owner, _to, _amount);
            _tokenCompliance.transferred(msg.sender, _to, _amount);
            return true;
        }
        revert("Transfer not possible");
    }
}