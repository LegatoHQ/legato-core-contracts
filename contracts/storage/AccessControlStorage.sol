// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.7;

import "contracts/storage/IEternalStorage.sol";

abstract contract AccessControlStorageBAD {
    bytes32 public constant DEFAULT_ADMIN_ROLE = keccak256("DEFAULT_ADMIN_ROLE");

    function getPrefix() internal view virtual returns (string memory);
    function getStorage() internal view virtual returns (address);

    modifier hasStorageAddress() {
        require(getStorage() != address(0), "AccessControlStorage:Storage address not set in derived contract");
        _;
    }

    modifier hasPrefix() {
        require(bytes(getPrefix()).length != 0, "AccessControlStorage:Prefix not set in derived contract");
        _;
    }

    modifier onlyRole(bytes32 role) {
        require(_hasRole(role, msg.sender), "AccessControlStorage: sender must be an admin to grant");
        _;
    }

    function _hasRole(bytes32 role, address account) internal view hasPrefix hasStorageAddress returns (bool) {
        return IEternalStorage(getStorage()).getBooleanValue(
            keccak256(abi.encodePacked(getPrefix(), "roles", role, account))
        );
    }

    function _grantRole(bytes32 role, address account) internal hasPrefix hasStorageAddress {
        IEternalStorage(getStorage()).setBooleanValue(
            keccak256(abi.encodePacked(getPrefix(), "roles", role, account)), true
        );
    }

    function _revokeRole(bytes32 role, address account) internal hasPrefix hasStorageAddress {
        IEternalStorage(getStorage()).setBooleanValue(
            keccak256(abi.encodePacked(getPrefix(), "roles", role, account)), false
        );
    }

    function _renounceRole(bytes32 role, address account) internal hasPrefix hasStorageAddress {
        IEternalStorage(getStorage()).setBooleanValue(
            keccak256(abi.encodePacked(getPrefix(), "roles", role, account)), false
        );
    }

    uint256[49] private __gap;
}
