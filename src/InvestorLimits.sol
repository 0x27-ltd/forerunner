pragma solidity ^0.8.19;

contract InvestorLimits {
    uint256 public _investors;
    uint8 public maxInvestors;

    constructor(uint8 _maxInvestors) 
    // address _accountant,
    {
        maxInvestors = _maxInvestors;
    }

    //@audit add modifier here so only fund can call this
    function addInvestor() external returns (bool) {
        //@todo what if the maxInvestors is 0?
        require(_investors < maxInvestors, "Too Many Investors");
        _investors++;
        return true;
    }

    function removeInvestor() external returns (bool) {
        _investors--;
        return true;
    }
}
