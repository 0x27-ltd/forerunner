// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

contract WeiHelper {
    function compareStrings(string memory a_, string memory b_) public pure returns (bool) {
        return (keccak256(abi.encodePacked((a_))) == keccak256(abi.encodePacked((b_))));
    }

    function toWei(uint256 amount, uint8 decimals) public pure returns (uint256) {
        return amount * 10 ** decimals;
    }

    function changeWei(uint256 amount, uint8 fromDecimals, uint8 toDecimals) public pure returns (uint256) {
        return amount * 10 ** toDecimals / 10 ** fromDecimals;
    }
}
