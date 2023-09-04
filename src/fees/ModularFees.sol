// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "./FeesStorage.sol";

contract ModularCompliance is OwnableUpgradeable, FeesStorage {}
