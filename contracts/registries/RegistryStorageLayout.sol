// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

//storage iporti
import "contracts/storage/EternalStorage.sol";
import "lib/openzeppelin-contracts/contracts/utils/Counters.sol";
import "contracts/interfaces/BlanketStructs.sol";

// ******************************************************
// @dev:do NOT NOT UPDATE after launch.
// used by RegistryImplVxxx and RegistryProxyPointer
// ******************************************************

abstract contract RegistryStorageLayout {
    enum StorageState {
        Undefined,
        Uninitialised,
        Initialised
    }

    uint256 nonce;
    bool internal useLatest = false;
    address internal actualImpl;

    EternalStorage public __DATA__ = EternalStorage(address(0));

    uint256 internal statusTime;
    // Used to prevent direct access to delegate and prevent calling initialize more than once
    StorageState internal storageState = StorageState.Undefined;

    Counters.Counter internal ipIds;
    mapping(uint256 => address) internal minterBySongId;
    mapping(uint256 => address) internal songAddressBySongId;
    mapping(address => bool) public isChildBlueprint;
    StoreStatus public storeStatus;
    bool initialized;
    address[] ipList;
    address public ownerWallet;
    address public owner;
    address public token;
    string public ledgerName;
    string public settingsUri;

    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant BINDER_ROLE = keccak256("BINDER_ROLE");
    bytes32 public constant STORE_OWNER_ROLE = keccak256("STORE_OWNER_ROLE");
    bytes32 public constant STORE_PAYER_ROLE = keccak256("STORE_PAYER_ROLE");
}
