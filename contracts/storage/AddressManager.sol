// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import "lib/openzeppelin-contracts-upgradeable/contracts/access/AccessControlUpgradeable.sol";
import "./EternalStorage.sol";
import "contracts/interfaces/IVersioned.sol";
import "contracts/storage/StorageContractPointer.sol";
import "contracts/storage/IAddressInitializable.sol";
//cloner
import "contracts/Cloner.sol";
import "lib/forge-std/src/console.sol";

contract AddressManager is IVersioned, AccessControlUpgradeable {
    EternalStorage public __DATA__;

    function getVersion() external pure override returns (uint8) {
        return 1;
    }

    // function getStorage() internal view override returns (address) {
    //     return address(__DATA__);
    // }

    // function getPrefix() internal pure override returns (string memory) {
    //     return "addressManager";
    // }

    event ContractRegistered(address indexed contractAddress, string record);
    event ContractUnregistered(address indexed contractAddress, string record);
    event ContractAddressChanged(address indexed newAddress, address indexed oldAddress, string record);

    string public constant ADDRESS_MANAGER = "contracts.addressManager";
    string public constant ROOT_REGISTRY = "contracts.rootRegistry";
    string public constant FEE_DISTRIBUTOR = "contracts.feeDistributor";
    string public constant TOKEN_DISTRIBUTOR = "contracts.tokenDistributor";
    string public constant LICENSE_REGISTRY = "contracts.licenseRegistry";
    string public constant LICENSE_CONTRACT = "contracts.licenseContract";
    string public constant USDC_ADDRESS = "contracts.usdcAddress";
    string public constant VERIFY_HELPER = "contracts.verifyHelper";

    //IMPLEMENTATIONS
    string public constant REGISTRY_IMPLEMENTATION = "contracts.registryImplementation";
    string public constant BLUEPRINT_IMPLEMENTATION = "contracts.blueprintImplementation";
    string public constant BASE_IP_PORTION_TOKEN_IMPLEMENTATION = "contracts.baseIPPortionTokenImpl";
    string public constant REGISTRY_PROXY_POINTER_IMPLEMENTATION = "contracts.registryProxyPointerImpl";
    string public STORAGE_CONTRACT_POINTER_IMPLEMENTATION = "contracts.storageContractPointerImpl";

    bool initialized;
    address private _creator;

    constructor() {
        _creator = msg.sender;
    }

    function initialize(address _owner, address _storage) public initializer {
        __AccessControl_init();
        __DATA__ = EternalStorage(_storage);
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(DEFAULT_ADMIN_ROLE, _owner);
    }

    function grantAdmin(address _newAdmin) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _grantRole(DEFAULT_ADMIN_ROLE, _newAdmin);
    }

    function getPointerForContractName(string memory record) public view returns (address) {
        // console.log("AddressManager:getContractAddress:record", record);
        return verifyAddress(getContractAddress(string(abi.encodePacked(record, "Pointer"))));
    }

    function getContractAddress(string memory record) public view returns (address) {
        // console.log("AddressManager:getContractAddress:record", record);
        return __DATA__.getAddressValue(keccak256(abi.encodePacked(record)));
    }

    function getStorageContractPointerImplAddress() public view returns (address) {
        return verifyAddress(getContractAddress(STORAGE_CONTRACT_POINTER_IMPLEMENTATION));
    }

    function registerNewContractWithPointer(
        string memory _newContractName,
        address _newContractImplAddress,
        address _pointerOwner
    ) public onlyRole(DEFAULT_ADMIN_ROLE) {
        // console.log("registerNewContractWithPointer", _newContractName, _newContractImplAddress, _pointerOwner);
        address pointerAddress = Cloner.createClone(getStorageContractPointerImplAddress());
        IAddressInitiailizable(pointerAddress).initializeAddresses(_newContractName, _pointerOwner, address(this));
        //the actual contract
        registerNewContract(_newContractName, _newContractImplAddress);
        //the pointer to the contract (this is what we want eveeyone to use)
        registerNewContract(string(abi.encodePacked(_newContractName, "Pointer")), pointerAddress);
    }

    bool selfRegistered;

    function selfRegister(address _owner, address _storageAddress) public {
        require(msg.sender == _creator, "Only creator can self-register");
        require(!selfRegistered, "Already self-registered");
        selfRegistered = true;

        initialize(_owner, _storageAddress);
        registerNewContract(ADDRESS_MANAGER, address(this));
    }

    function getAddressManager() public view returns (address) {
        return getContractAddress(ADDRESS_MANAGER);
    }

    function registerNewContract(string memory record, address _address) public onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_address == address(0)) require(false, "Zero address cannot be registered");
        bytes32 recordHashed = keccak256(abi.encodePacked(record));
        if (__DATA__.getBooleanValue(recordHashed)) require(false, "Already registered");
        __DATA__.setBooleanValue(recordHashed, true);
        changeContractAddressVersioned(record, _address);
        emit ContractRegistered(_address, record);
    }

    function unregisterContract(string memory record) external onlyRole(DEFAULT_ADMIN_ROLE) {
        bytes32 recordHashed = keccak256(abi.encodePacked(record));
        if (!__DATA__.getBooleanValue(recordHashed)) require(false, "Not registered");
        address oldVal = getContractAddress(record);
        __DATA__.setAddressValue(recordHashed, address(0));
        __DATA__.setBooleanValue(recordHashed, false);
        emit ContractUnregistered(oldVal, record);
    }

    /**
     * @dev Change contract address (Always Prefer to call changeContractAddressVersioned instead)
     *
     * @param record  - record name
     * @param value  - new contract address
     *
     */
    function changeContractAddressDangerous(string memory record, address value) public onlyRole(DEFAULT_ADMIN_ROLE) {
        bytes32 recordHashed = keccak256(abi.encodePacked(record));
        if (!__DATA__.getBooleanValue(recordHashed)) require(false, "Not registered");
        address oldVal = getContractAddress(record);
        __DATA__.setAddressValue(recordHashed, value);
        emit ContractAddressChanged(value, oldVal, record);
    }
    /**
     * @dev Change contract address only if the new implementation is newer than the existing one
     *
     * @param record  - record name
     * @param value  - new contract address
     *
     */

    function changeContractAddressVersioned(string memory record, address value) public onlyRole(DEFAULT_ADMIN_ROLE) {
        address oldVal = getContractAddress(record);
        //if old val is not empty
        if (oldVal != address(0)) {
            require(
                IVersioned(value).getVersion() > IVersioned(oldVal).getVersion(),
                "New implementation is not newer than the existing one"
            );
        }
        changeContractAddressDangerous(record, value);
    }

    function verifyAddress(address _address) public pure returns (address) {
        require(_address != address(0), "Zero address will be returned from address manager");
        return _address;
    }

    /// getters

    function getVerifyHelper() public view returns (address) {
        return verifyAddress(getPointerForContractName(VERIFY_HELPER));
    }

    function getLicenseRegistry() public view returns (address) {
        return verifyAddress(getPointerForContractName(LICENSE_REGISTRY));
    }

    function getTokenDistributor() public view returns (address) {
        return verifyAddress(getPointerForContractName(TOKEN_DISTRIBUTOR));
    }

    function getRootRegistry() public view returns (address) {
        return verifyAddress(getPointerForContractName(ROOT_REGISTRY));
    }

    function getFeeDistributor() public view returns (address) {
        return getPointerForContractName(FEE_DISTRIBUTOR);
    }

    function getUnderlyingRootRegistry() public view returns (address) {
        return verifyAddress(getContractAddress(ROOT_REGISTRY));
    }

    function getUnderlyingFeeDistributor() public view returns (address) {
        return verifyAddress(getContractAddress(FEE_DISTRIBUTOR));
    }

    function getBaseIPPortionTokenImpl() public view returns (address) {
        return verifyAddress(getContractAddress(BASE_IP_PORTION_TOKEN_IMPLEMENTATION));
    }

    function getUnderlyingTokenDistributor() public view returns (address) {
        return verifyAddress(getContractAddress(TOKEN_DISTRIBUTOR));
    }

    function getUnderlyingVerifyHelper() public view returns (address) {
        return verifyAddress(getContractAddress(VERIFY_HELPER));
    }

    function getUnderlyingLicenseRegistry() public view returns (address) {
        return verifyAddress(getContractAddress(LICENSE_REGISTRY));
    }

    function getLicenseContract() public view returns (address) {
        return verifyAddress(getContractAddress(LICENSE_CONTRACT));
    }

    function getUSDCContract() public view returns (address) {
        return verifyAddress(getContractAddress(USDC_ADDRESS));
    }

    function getRegistryImpl() public view returns (address) {
        return verifyAddress(getContractAddress(REGISTRY_IMPLEMENTATION));
    }

    function getRegistryProxyPointerImpl() public view returns (address) {
        return verifyAddress(getContractAddress(REGISTRY_PROXY_POINTER_IMPLEMENTATION));
    }

    function getBlueprintCloneImpl() public view returns (address) {
        return verifyAddress(getContractAddress(BLUEPRINT_IMPLEMENTATION));
    }

    function setFeeDistributor(address _feeDistributor) public onlyRole(DEFAULT_ADMIN_ROLE) {
        changeContractAddressVersioned(FEE_DISTRIBUTOR, _feeDistributor);
    }

    function setTokenDistributor(address _tokenDistributor) public onlyRole(DEFAULT_ADMIN_ROLE) {
        changeContractAddressVersioned(TOKEN_DISTRIBUTOR, _tokenDistributor);
    }

    function setLicenseRegistry(address _licenseRegistry) public onlyRole(DEFAULT_ADMIN_ROLE) {
        changeContractAddressVersioned(LICENSE_REGISTRY, _licenseRegistry);
    }

    function setLicenseContract(address _legatoLicense) public onlyRole(DEFAULT_ADMIN_ROLE) {
        changeContractAddressVersioned(LICENSE_CONTRACT, _legatoLicense);
    }

    function setUsdcAddressValue(address _usdcAddress) public onlyRole(DEFAULT_ADMIN_ROLE) {
        changeContractAddressVersioned(USDC_ADDRESS, _usdcAddress);
    }

    function setVerifyHelper(address _verifyHelper) public onlyRole(DEFAULT_ADMIN_ROLE) {
        changeContractAddressVersioned(VERIFY_HELPER, _verifyHelper);
    }

    function setRegistryImplAddress(address _registryCloneImpl) public onlyRole(DEFAULT_ADMIN_ROLE) {
        changeContractAddressVersioned(REGISTRY_IMPLEMENTATION, _registryCloneImpl);
    }

    function setBlueprintCloneImpl(address _blueprintCloneImpl) public onlyRole(DEFAULT_ADMIN_ROLE) {
        changeContractAddressVersioned(BLUEPRINT_IMPLEMENTATION, _blueprintCloneImpl);
    }

    function getStorageAddress() public view returns (address) {
        return address(__DATA__);
    }
}
