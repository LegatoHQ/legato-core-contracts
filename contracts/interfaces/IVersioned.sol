// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

interface IVersioned {
    function getVersion() external pure returns (uint8);
}
