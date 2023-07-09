pragma solidity ^0.8.19;

contract WhitelistManager {
    
    mapping(address => bool) public whitelist;
    address[] internal _whitelistAddresses;
    address internal _whitelistController;

    event ModifiedWhitelist(address indexed investor, uint256 timestamp, bool isWhitelisted);

    constructor(
        address _controller
    ){
        _whitelistController = _controller;
    }

    // only the accountant is the controller
    modifier whitelistController() {
        require(msg.sender == _whitelistController, "You are not the whitelist controller.");
        _;
    }

    modifier onlyWhitelisted() {
        require(whitelist[msg.sender] == true, "Caller is not whitelisted.");
        _;
    }

    //Add a kyc'd investors address to the investor whitelist. The fund admin does this only after off-chain kyc completed
    function addToWhitelist(address _address) public whitelistController {
        require(_address != address(0), "!address");
        require(!whitelist[_address], "address already in the whitelist");
        whitelist[_address] = true;
        _whitelistAddresses.push(_address);
        emit ModifiedWhitelist(_address, block.timestamp, true);
    }

    // Remove an address from the kyc whitelist
    function removeFromWhitelist(address _address) public whitelistController {
        require(_address != address(0), "!address");
        whitelist[_address] = false;
        //Need to remove addy from _whitelistAddresses array too
        uint256 indexToRemove = 0;
        for (uint256 i = 0; i < _whitelistAddresses.length; i++) {
            if (_whitelistAddresses[i] == _address) {
                indexToRemove = i;
                break;
            }
        }
        //If the address is found in the array, remove it by swapping with the last element and then reducing the array length
        if (indexToRemove < _whitelistAddresses.length - 1) {
            _whitelistAddresses[indexToRemove] = _whitelistAddresses[_whitelistAddresses.length - 1];
        }
        _whitelistAddresses.pop();
        emit ModifiedWhitelist(_address, block.timestamp, false);
    }
}