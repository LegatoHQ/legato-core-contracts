// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;
//@follow-up change compiler version for all

import "contracts/interfaces/IRootRegistryV2.sol";
import "contracts/interfaces/IActivated.sol";
import "contracts/registries/IRegistryV2.sol";
import "contracts/registries/RegistryImplV4.sol";
import "contracts/dataBound/TokenDistributor.sol";
import "contracts/interfaces/IFeeDistributor.sol";
import "contracts/interfaces/Structs.sol";
import "contracts/LegatoLicense/LegatoLicense.sol";
import "../../Cloner.sol";
import "./RootRegistryV2DAL.sol";
import "contracts/registries/IRegistryProxyPointer.sol";
import "contracts/interfaces/IVersioned.sol";
import "lib/openzeppelin-contracts-upgradeable/contracts/access/AccessControlUpgradeable.sol";
import "lib/openzeppelin-contracts-upgradeable/contracts/proxy/utils/Initializable.sol";
import "contracts/dataBound/CommonUpgradeableStorageVars.sol";
import "lib/openzeppelin-contracts-upgradeable/contracts/security/PausableUpgradeable.sol";

contract RootRegistryV4 is
    IRootRegistryV2,
    RootRegistryV2DAL,
    AccessControlUpgradeable,
    PausableUpgradeable,
    IVersioned
{
    function getVersion() external pure override returns (uint8) {
        return 4; //Increment at every new contract version
    }

    modifier onlyAdmin() {
        if (!hasRole(DEFAULT_ADMIN_ROLE, msg.sender)) require(false, "Not admin");
        _;
    }

    //notDenied modifier
    modifier notDenied(address _address) {
        require(!_data_getIsDenied(_address), "denied");
        _;
    }

    //pause
    function pause() public onlyAdmin {
        _pause();
    }

    function unpause() public onlyAdmin {
        _unpause();
    }

    //deny
    function deny(address _address) public onlyAdmin {
        //cannot deny an admin
        if (hasRole(DEFAULT_ADMIN_ROLE, _address)) revert("Cannot deny admin");
        _data_setIsDenied(_address, true);
    }

    //undeny
    function undeny(address _address) public onlyAdmin {
        _data_setIsDenied(_address, false);
    }

    function setAccountType(address _address, uint8 _type) public onlyAdmin {
        require(_address != address(0), "invalid address");
        require(_type != getAccountType(_address), "already same account type");
        _data_setAccountType(_address, _type);
    }

    function getAccountType(address _address) public view returns (uint8) {
        return uint8(_data_getAccountType(_address));
    }

    function initialize(address _storage) public initializer {
        __AccessControl_init();
        __Pausable_init();
        __DATA__ = EternalStorage(_storage);
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        /// Keep first element as address(0) for deleted stores
        // _data_addRegistry(address(0));
    }

    function getRegistryCount() public view override returns (uint256) {
        address[] memory registries = _data_getRegistries();
        uint256 count = 0;
        for (uint256 i = 0; i < registries.length; i++) {
            if (isValidRegistry(registries[i])) {
                count++;
            }
        }
        return count;
    }

    function isDelisted(address _registry) public view returns (bool) {
        require(_registry != address(0), "invalid registry");
        require(_data_getIsRegistry(_registry), "registry not found");
        return _data_get_isRemovedRegistry(_registry);
    }

    function isValidRegistry(address _registry) public view override returns (bool) {
        uint256 NEEDED_VERSION = 3;
        return _registry != address(0) && _data_getIsRegistry(_registry) && !_data_getIsBannedRegistry(_registry)
            && !_data_get_isRemovedRegistry(_registry) && IVersioned(_registry).getVersion() >= NEEDED_VERSION;
    }

    function getActiveRegistries(bool _active) external view returns (address[] memory) {
        address[] memory registries = _data_getRegistries();
        uint256 countValidAndFits = 0;
        StoreStatus expectedStatus = _active ? StoreStatus.ACTIVE : StoreStatus.INACTIVE;
        for (uint256 i = 0; i < registries.length; i++) {
            if (isValidRegistry(registries[i])) {
                if (RegistryImplV4(registries[i]).storeStatus() == expectedStatus) {
                    countValidAndFits++;
                }
            }
        }

        address[] memory result = new address[](countValidAndFits);
        uint256 index = 0;
        for (uint256 i = 0; i < registries.length; i++) {
            if (isValidRegistry(registries[i])) {
                if (RegistryImplV4(registries[i]).storeStatus() == expectedStatus) {
                    result[index] = registries[i];
                    index++;
                }
            }
        }
        return result;
    }

    function getAllRegistries() external view override returns (address[] memory) {
        uint256 count = getRegistryCount();
        address[] memory result = new address[](count);
        address[] memory registries = _data_getRegistries();
        uint256 index = 0;
        for (uint256 i = 0; i < registries.length; i++) {
            if (isValidRegistry(registries[i])) {
                result[index] = registries[i];
                index++;
            }
        }
        return result;
    }

    function getAllRegistriesByWallet(address _for) public view override returns (address[] memory) {
        address[] memory registries = _data_getRegistriesForWallet(_for);
        uint256 count = 0;
        for (uint256 i = 0; i < registries.length; i++) {
            count++;
        }
        address[] memory result = new address[](count);
        uint256 index = 0;
        for (uint256 i = 0; i < registries.length; i++) {
            result[index] = registries[i];
            index++;
        }
        return result;
    }

    function getRegistriesByWallet(address _for) public view override returns (address[] memory) {
        address[] memory registries = _data_getRegistriesForWallet(_for);
        // filter out invalid registries
        uint256 count = 0;
        for (uint256 i = 0; i < registries.length; i++) {
            if (isValidRegistry(registries[i])) {
                count++;
            }
        }
        address[] memory result = new address[](count);
        uint256 index = 0;
        for (uint256 i = 0; i < registries.length; i++) {
            if (isValidRegistry(registries[i])) {
                result[index] = registries[i];
                index++;
            }
        }
        return result;
    }

    function getDenouncedRegistries() public view override returns (address[] memory) {
        return _data_getDenouncedRegistries();
    }

    function getBlueprintImplementation() public view override returns (address) {
        return getAddressManager().getBlueprintCloneImpl();
    }

    function setStoreMaxForAccountType(uint8 _accountType, uint256 _storesMax) public onlyAdmin {
        require(_storesMax > 0, "invalid input:storesMax must be > 0");
        require(
            _accountType >= uint8(AccountType.DEFAULT) && _accountType <= uint8(AccountType.OTHER10),
            "invalid input:accountType"
        );
        _data_setStoreMaxForAccountType(_accountType, _storesMax);
    }

    function setStoreMaxForAccountTypes(uint8[] memory _accountTypes, uint256[] memory _storesMax) public onlyAdmin {
        require(_accountTypes.length == _storesMax.length, "invalid input:lengths not equal");
        for (uint256 i = 0; i < _accountTypes.length; i++) {
            _data_setStoreMaxForAccountType(_accountTypes[i], _storesMax[i]);
        }
    }

    function getStoreMaxForAccountType(uint8 _accountType) public view returns (uint256) {
        uint256 result = _data_getStoreMaxForAccountType(_accountType);
        // console.log("getStoreMaxForAccountType", _accountType, result);
        if (result == 0) {
            return 1;
        }
        return result;
    }

    function getStoreMaxForAccount(address _account) public view returns (uint256) {
        uint8 accountType = getAccountType(_account);
        return getStoreMaxForAccountType(accountType);
    }

    function mintRegistryFor(address _for, string memory _name, bool _autoUpgrade)
        public
        override
        whenNotPaused
        notDenied(msg.sender)
        returns (address)
    {
        // require account type to be AccountType.MULTI (11-20)
        // if already has a store, require account type to be AccountType.MULTI1 (11-20)
        uint256 existingStores = getRegistriesByWallet(_for).length;
        if (existingStores > 0) {
            //always allow one store
            uint256 maxAllowed = getStoreMaxForAccount(_for);
            // console.log("mintRegistryFor", _for, existingStores, maxAllowed);
            require(existingStores < maxAllowed, "max stores reached");
        }
        IFeeDistributor feeDistributor = IFeeDistributor(getAddressManager().getFeeDistributor());
        TokenDistributor tokenDistributor = TokenDistributor(getAddressManager().getTokenDistributor());
        LegatoLicense legLic = LegatoLicense(getAddressManager().getLicenseContract());

        address instanceAddress = Cloner.createClone(getAddressManager().getRegistryProxyPointerImpl());
        IRegistryProxyPointer pointer = IRegistryProxyPointer(instanceAddress);
        // allow in storage
        __DATA__.allowContract(instanceAddress);

        pointer.initialize(_name, _for, address(__DATA__), _autoUpgrade);

        feeDistributor.grantPayer(instanceAddress);
        tokenDistributor.grantTokener(instanceAddress);
        legLic.grantMinter(instanceAddress);

        _data_addRegistryToWallet(_for, instanceAddress);
        _data_addRegistry(instanceAddress);
        // _data_setRegistryToIndex(instanceAddress, getRegistryCount() - 1);
        _data_setIsRegistry(instanceAddress, true);
        emit RegistryCreated(instanceAddress, _for, msg.sender);
        return instanceAddress;
    }

    function denounceStore(address _registry, DenounceReason reason) public onlyAdmin {
        require(isValidRegistry(_registry), "registry not found or already banned");
        _data_banRegistry(_registry);
        _data_addDenouncedRegistry(_registry);
        emit StoreDenounced(_registry, reason);
    }

    function delistStoreByOwner(address _storeToRemove) public override whenNotPaused {
        require(isValidRegistry(_storeToRemove), "registry not found");
        //sender can be the store itself
        require(
            msg.sender == _storeToRemove || msg.sender == IRegistryV2(_storeToRemove).getOwnerWallet(),
            "Not owner or store"
        );
        return _removeStore(_storeToRemove, msg.sender);
    }

    /// @notice delist the store from the accounting in this contract
    /// @dev The process makes sure that the array of registries remains without holes.
    /// @dev It also takes care of the case where the store is the last in the array
    /// @param _registry The registry to be removed
    function _removeStore(address _registry, address _ownerWallet) private {
        require(_data_getIsRegistry(_registry), "registry not found");
        _data_removeRegistry(_registry);
        _data_setIsRegistry(_registry, false);
        _removeStoreFromOwner(_registry, _ownerWallet);
        emit RegistryDelisted(_registry);
    }

    function _banStore(address _registry) private onlyAdmin {
        require(isValidRegistry(_registry), "registry not found");
        _data_banRegistry(_registry);
        emit RegistryDelisted(_registry);
    }

    ///  @notice transfer ownership of a store to a new owner
    ///  @dev Requires being called by sthe store itself so that the store will update its own ownerWallet field
    ///  @param _registry The registry to be removed
    ///  @param currentOwner The current owner of the store
    ///  @param newOwner The new owner of the store
    function transferStoreOwnership(address _registry, address currentOwner, address newOwner)
        external
        override
        notDenied(msg.sender)
        whenNotPaused
    {
        require(newOwner != address(0), "invalid new owner");
        require(msg.sender == _registry, "Only Stores can transfer ownership");
        require(isValidRegistry(_registry), "registry not found or not active");
        address _foundOwner = IRegistryV2(_registry).getOwnerWallet();
        _removeStoreFromOwner(_registry, _foundOwner);
        _data_addRegistryToWallet(newOwner, _registry);

        emit StoreOwnershipTransferred(_registry, _foundOwner, newOwner);
    }

    function _removeStoreFromOwner(address _registry, address _ownerWallet) private {
        // get current list
        address[] memory WALLET_SPECIFIC_REGISTRIES = _data_getRegistriesForWallet(_ownerWallet);
        //delete list
        _data_deleteRegistriesToWallet(_ownerWallet);

        //refill list without the removed registry
        if (WALLET_SPECIFIC_REGISTRIES.length > 1) {
            for (uint256 i = 0; i < WALLET_SPECIFIC_REGISTRIES.length; i++) {
                if (WALLET_SPECIFIC_REGISTRIES[i] != _registry) {
                    _data_addRegistryToWallet(_ownerWallet, WALLET_SPECIFIC_REGISTRIES[i]);
                }
            }
        }
    }
}
