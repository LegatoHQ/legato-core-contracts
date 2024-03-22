// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;
//@follow-up change compiler version for all

import "contracts/interfaces/IRootRegistry.sol";
import "../../Cloner.sol";
import "contracts/registries/IRegistryV2.sol";
import "contracts/dataBound/TokenDistributor.sol";
import "contracts/interfaces/IFeeDistributor.sol";
import "contracts/interfaces/Structs.sol";
import "contracts/LegatoLicense/LegatoLicense.sol";
import "contracts/registries/RegistryImplV1.sol";
import "./RootRegistryDAL.sol";
import "contracts/registries/IRegistryProxyPointer.sol";
import "contracts/interfaces/IVersioned.sol";
import "lib/openzeppelin-contracts-upgradeable/contracts/access/AccessControlUpgradeable.sol";
import "lib/openzeppelin-contracts-upgradeable/contracts/proxy/utils/Initializable.sol";
import "contracts/dataBound/CommonUpgradeableStorageVars.sol";
import "lib/openzeppelin-contracts-upgradeable/contracts/security/PausableUpgradeable.sol";

contract RootRegistry is IRootRegistry, RootRegistryDAL, AccessControlUpgradeable, PausableUpgradeable, IVersioned {
    function getVersion() external pure override returns (uint8) {
        return 1; //Increment at every new cotract version
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

    function initialize(address _storage) public initializer {
        __AccessControl_init();
        __Pausable_init();
        __DATA__ = EternalStorage(_storage);
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        /// Keep first element as address(0) for deleted stores
        // _data_addRegistry(address(0));
    }

    function getRegistryCount() public view override returns (uint256) {
        return _data_getRegistries().length;
    }

    function getAllRegistries() external view override returns (address[] memory) {
        return _data_getRegistries();
    }

    function getRegistriesByWallet(address _for) public view override returns (address[] memory) {
        return _data_getRegistriesForWallet(_for);
    }

    function getDenouncedRegistries() public view override returns (address[] memory) {
        return _data_getDenouncedRegistries();
    }

    function getBlueprintImplementation() public view override returns (address) {
        return getAddressManager().getBlueprintCloneImpl();
    }

    function mintRegistryFor(address _for, string memory _name, bool _autoUpgrade)
        public
        override
        whenNotPaused
        notDenied(msg.sender)
        returns (address)
    {
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
        _data_setRegistryToIndex(instanceAddress, getRegistryCount() - 1);
        _data_setIsRegistry(instanceAddress, true);
        emit RegistryCreated(instanceAddress, _for, msg.sender);
        return instanceAddress;
    }

    function denounceStore(address _registry, DenounceReason reason) public override onlyAdmin {
        address _ownerWallet = IRegistryV2(_registry).getOwnerWallet();
        _delistStore(_registry, _ownerWallet);
        _data_addDenouncedRegistry(_registry);
        emit StoreDenounced(_registry, reason);
    }

    function delistStore(address _registry, address _ownerWallet) public override whenNotPaused {
        if (!_data_getIsRegistry(_registry)) require(false, "registry not found");
        //require admin or store owner or store itself
        if (msg.sender != _registry && msg.sender != _ownerWallet && !hasRole(DEFAULT_ADMIN_ROLE, msg.sender)) {
            require(false, "not admin or owner");
        }
        return _delistStore(_registry, _ownerWallet);
    }

    /// @notice delist the store from the accounting in this contract
    /// @dev The process makes sure that the array of registries remains without holes.
    /// @dev It also takes care of the case where the store is the last in the array
    /// @param _registry The registry to be removed
    function _delistStore(address _registry, address _ownerWallet) private {
        /// Get the needed data to swap between last entry the the entry to be deleted
        address lastRegistry = _data_getRegistries()[getRegistryCount() - 1];
        uint256 registryIndex = _data_getRegistryToIndex(_registry);
        /// Only runs if the registry to be deleted is not the in the registries array
        if (lastRegistry != _registry) {
            /// swap the array entry for the last registry address
            _data_updateRegistry(registryIndex, lastRegistry);
            /// swap the index of the last registry with the new one
            _data_setRegistryToIndex(lastRegistry, registryIndex);
        }
        /// Clear the mappings
        _data_deleteRegistryToIndex(_registry);
        _data_deleteRegistry(getRegistryCount() - 1);
        _data_setIsRegistry(_registry, false);

        _removeStoreFromOwner(_registry, _ownerWallet);

        emit RegistryDelisted(_registry);
    }

    function transferStoreOwnership(address _registry, address currentOwner, address newOwner)
        external
        override
        notDenied(msg.sender)
        whenNotPaused
    {
        if (!_data_getIsRegistry(_registry)) require(false, "registry not found");
        _removeStoreFromOwner(_registry, currentOwner);
        _data_addRegistryToWallet(newOwner, _registry);

        emit StoreOwnershipTransferred(_registry, currentOwner, newOwner);
    }

    function _removeStoreFromOwner(address _registry, address _ownerWallet) private {
        address[] memory walletRegistries = _data_getRegistriesForWallet(_ownerWallet);

        _data_deleteRegistriesToWallet(_ownerWallet);

        if (walletRegistries.length > 1) {
            for (uint256 i = 0; i < walletRegistries.length; i++) {
                if (walletRegistries[i] != _registry) {
                    _data_addRegistryToWallet(_ownerWallet, walletRegistries[i]);
                }
            }
        }
    }
}
