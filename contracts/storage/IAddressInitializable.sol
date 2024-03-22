// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

interface IAddressInitiailizable {
    function initializeAddresses(string memory _pointToName, address _ownerWallet, address _addressManager) external;
}
