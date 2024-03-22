// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

contract CommonUpgradeableStorageVars {
    mapping(address => bool) internal isInitialized;
    address internal addressManagerAddress;
    address internal eternalStorageAddress;
    //gap
    uint256[24] private __gap;
}
