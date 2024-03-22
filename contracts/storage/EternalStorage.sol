// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

// Inheritance
import "./Owned.sol";
import "./State.sol";
import "./IEternalStorage.sol";
import "lib/openzeppelin-contracts/contracts/access/AccessControl.sol";
import "lib/openzeppelin-contracts/contracts/security/Pausable.sol";
import "./AddressManager.sol";
import "lib/forge-std/src/console.sol";

/**
 * @notice  This contract is based on the code available from this blog
 * https://blog.colony.io/writing-upgradeable-contracts-in-solidity-6743f0eecc88/
 * Implements support for storing a keccak256 key and value pairs. It is a more flexible
 * and extensible option. This ensures data schema changes can be implemented without
 * requiring upgrades to the storage contract.
 */
contract EternalStorage is Owned, StorageState, AccessControl, Pausable {
    //renounced event
    event Renounced(address indexed admin);
    event RenounceRequest(address indexed admin);

    error StorageRenounced();
    error NotAdmin();

    /* ========== DATA TYPES ========== */
    mapping(bytes32 => uint256) internal UIntStorage;
    mapping(bytes32 => int8) internal Int8Storage;
    mapping(bytes32 => string) internal StringStorage;
    mapping(bytes32 => address) internal AddressStorage;
    mapping(bytes32 => bytes) internal BytesStorage;
    mapping(bytes32 => bytes32) internal Bytes32Storage;
    mapping(bytes32 => bool) internal BooleanStorage;
    mapping(bytes32 => int256) internal IntStorage;
    mapping(bytes32 => address[]) internal AddressListStorage;
    mapping(bytes32 => uint256[]) internal UintListStorage;

    bool public renounced = false;
    uint8 public renounceCount = 0;
    bytes32 public constant ADMIN_ROLE = keccak256("legato.storage.ADMIN_ROLE");
    bytes32 public constant ADDRESS_MANAGER = keccak256(abi.encodePacked("contracts.addressManager"));
    bytes32 public constant ALLOWER_ROLE = keccak256("legato.storage.ALLOWER_ROLE");
    bytes32 public constant READER_ROLE = keccak256("legato.storage.READER_ROLE");

    function pause() external onlyAdmin notRenounced {
        _pause();
    }

    function unpause() external onlyAdmin notRenounced {
        _unpause();
    }

    constructor(address _owner, address _associatedContract) Owned(_owner) StorageState(_associatedContract) {
        _grantRole(ADMIN_ROLE, _owner);
        _grantRole(ADMIN_ROLE, msg.sender);
    }

    modifier notRenounced() {
        if (renounced) revert StorageRenounced();
        _;
    }

    modifier onlyAdmin() {
        if (!hasRole(ADMIN_ROLE, msg.sender)) revert NotAdmin();
        _;
    }

    function grantAllower(address _address) public notRenounced {
        require(hasRole(ALLOWER_ROLE, msg.sender) || hasRole(ADMIN_ROLE, msg.sender), "Not allower");
        _grantRole(ALLOWER_ROLE, _address);
    }

    function grantReader(address _address) public onlyAdmin notRenounced {
        _grantRole(READER_ROLE, _address);
    }

    function grantAdmin(address _newAdmin) public onlyAdmin notRenounced {
        _grantRole(ADMIN_ROLE, _newAdmin);
    }

    function renounceAdmin() public onlyAdmin notRenounced {
        renounceCount++;
        emit RenounceRequest(msg.sender);
        if (renounceCount >= 3) {
            renounced = true;
            //event
            emit Renounced(msg.sender);
        }
    }

    function getAddressManager() public view returns (address) {
        return AddressStorage[ADDRESS_MANAGER];
    }

    // function getAddressManagerAddress() public view returns (address) {
    //     return AddressStorage[ADDRESS_MANAGER];
    // }

    function getAddressListValue(bytes32 record) external view returns (address[] memory) {
        return AddressListStorage[record];
    }

    function getUIntListValue(bytes32 record) external view returns (uint256[] memory) {
        return UintListStorage[record];
    }

    function getInt8Value(bytes32 record) external view returns (uint8) {
        return uint8(UIntStorage[record]);
    }

    function getUIntValue(bytes32 record) external view returns (uint256) {
        return UIntStorage[record];
    }

    function getStringValue(bytes32 record) external view returns (string memory) {
        return StringStorage[record];
    }

    function getAddressValue(bytes32 record) external view returns (address) {
        return AddressStorage[record];
    }

    function getBytesValue(bytes32 record) external view returns (bytes memory) {
        return BytesStorage[record];
    }

    function getBytes32Value(bytes32 record) external view returns (bytes32) {
        return Bytes32Storage[record];
    }

    function getBooleanValue(bytes32 record) public view returns (bool) {
        return BooleanStorage[record];
    }

    function getIntValue(bytes32 record) external view returns (int256) {
        return IntStorage[record];
    }

    ////SETTERS
    //set addres list item value
    function pushToAddressList(bytes32 record, address value) external onlyAssociatedContract {
        AddressListStorage[record].push(value);
    }

    function setAddressListValue(bytes32 record, address[] memory value) external onlyAssociatedContract {
        AddressListStorage[record] = value;
    }

    function updateAddressListValue(bytes32 record, uint256 index, address value) public onlyAssociatedContract {
        address[] memory list = AddressListStorage[record];
        list[index] = value;
        AddressListStorage[record] = list;
    }

    function pushUintListValue(bytes32 record, uint256 value) external onlyAssociatedContract {
        UintListStorage[record].push(value);
    }

    function setUIntListValue(bytes32 record, uint256[] memory value) external onlyAssociatedContract {
        UintListStorage[record] = value;
    }

    function setInt8Value(bytes32 record, uint8 value) external onlyAssociatedContract {
        UIntStorage[record] = uint256(value);
    }

    function setBytes32Value(bytes32 record, bytes32 value) external onlyAssociatedContract {
        Bytes32Storage[record] = value;
    }

    function setAddressValue(bytes32 record, address value) external onlyAssociatedContract {
        AddressStorage[record] = value;
    }

    function setBytesValue(bytes32 record, bytes memory value) external onlyAssociatedContract {
        BytesStorage[record] = value;
    }

    function setUIntValue(bytes32 record, uint256 value) external onlyAssociatedContract {
        UIntStorage[record] = value;
    }

    function incUIntValue(bytes32 record, uint256 value) external onlyAssociatedContract {
        UIntStorage[record] += value;
    }

    function setStringValue(bytes32 record, string memory value) external onlyAssociatedContract {
        StringStorage[record] = value;
    }

    function setBooleanValue(bytes32 record, bool value) external onlyAssociatedContract {
        BooleanStorage[record] = value;
    }

    function setIntValue(bytes32 record, int256 value) external onlyAssociatedContract {
        IntStorage[record] = value;
    }

    ////DELETE
    function deleteAddressListValue(bytes32 record) external onlyAssociatedContract {
        delete AddressListStorage[record];
    }

    function deleteAddressListItem(bytes32 record, uint256 index) public onlyAssociatedContract {
        address[] memory list = AddressListStorage[record];
        delete list[index];
        AddressListStorage[record] = list;
    }

    function deleteUIntListValue(bytes32 record) external onlyAssociatedContract {
        delete UIntStorage[record];
    }

    function deleteInt8Value(bytes32 record) external onlyAssociatedContract {
        delete UIntStorage[record];
    }

    function deleteBytes32Value(bytes32 record) external onlyAssociatedContract {
        delete Bytes32Storage[record];
    }

    function deleteUIntValue(bytes32 record) external onlyAssociatedContract {
        delete UIntStorage[record];
    }

    function deleteBytesValue(bytes32 record) external onlyAssociatedContract {
        delete BytesStorage[record];
    }

    function deleteAddressValue(bytes32 record) external onlyAssociatedContract {
        delete AddressStorage[record];
    }

    function deleteBooleanValue(bytes32 record) external onlyAssociatedContract {
        delete BooleanStorage[record];
    }

    function deleteIntValue(bytes32 record) external onlyAssociatedContract {
        delete IntStorage[record];
    }

    function deleteStringValue(bytes32 record) external onlyAssociatedContract {
        delete StringStorage[record];
    }

    /**
     * @notice  This function is used to get the number of times a function has been called
     * @return  uint256 representing the number of times the function has been called
     * @dev use this to get  a unique nonce for function calls
     */
    function nonce() external onlyAssociatedContract returns (uint256) {
        UIntStorage[keccak256(abi.encodePacked("eternalCounter"))]++;
        return UIntStorage[keccak256(abi.encodePacked("eternalCounter"))];
    }

    function allowContract(address _address) public notRenounced {
        require(hasRole(ALLOWER_ROLE, msg.sender) || hasRole(ADMIN_ROLE, msg.sender), "Not allower");
        allow(_address, true);
    }
}
