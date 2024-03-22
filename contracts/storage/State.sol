// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import "./Owned.sol";

abstract contract StorageState is Owned {
    // the address of the contract that can modify variables
    // this can only be changed by the owner of this contract
    // address public associatedContract;
    //multiple allowed contracts
    mapping(address => bool) public allowedContracts;

    constructor(address _associatedContract) {
        // This contract is abstract, and thus cannot be instantiated directly
        require(owner != address(0), "Owner must be set");

        allow(_associatedContract, true);
    }

    function isAllowed(address _associatedContract) public view returns (bool) {
        return allowedContracts[_associatedContract];
    }

    /* ========== SETTERS ========== */

    // Change the associated contract to a new address
    function allow(address _associatedContract, bool _allowed) internal {
        // associatedContract = _associatedContract;
        allowedContracts[_associatedContract] = _allowed;
        emit AssociatedContractUpdated(_associatedContract);
    }

    /* ========== MODIFIERS ========== */

    modifier onlyAssociatedContract() {
        require(allowedContracts[msg.sender], "Only associated contracts can use storage");
        _;
    }

    /* ========== EVENTS ========== */

    event AssociatedContractUpdated(address associatedContract);
}
