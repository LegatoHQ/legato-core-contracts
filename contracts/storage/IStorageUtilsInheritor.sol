// SPDX-License-Identifier:  BUSL-1.1

pragma solidity ^0.8.7;

interface IStorageUtilInheritor {
    function getStorage() external view returns (address);
    function getPrefix() external view returns (string memory);
}
