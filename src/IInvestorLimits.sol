pragma solidity ^0.8.19;

interface IInvestorLimits {

    function addInvestor() external returns (bool);
    function removeInvestor() external returns (bool);
}
