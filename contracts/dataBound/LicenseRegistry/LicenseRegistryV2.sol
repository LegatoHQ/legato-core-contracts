// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "lib/openzeppelin-contracts-upgradeable/contracts/access/AccessControlUpgradeable.sol";
import "lib/openzeppelin-contracts-upgradeable/contracts/proxy/utils/Initializable.sol";
import "contracts/dataBound/CommonUpgradeableStorageVars.sol";
import "lib/openzeppelin-contracts-upgradeable/contracts/security/PausableUpgradeable.sol";
import "contracts/interfaces/Structs.sol";
import "contracts/interfaces/BlanketStructs.sol";
import "contracts/interfaces/ILicenseBlueprint.sol";
import "lib/forge-std/src/console.sol";
import "./LicenseRegistryDAL.sol";
import "contracts/interfaces/IVersioned.sol";
import "contracts/dataBound/RootRegistry/RootRegistryV2.sol";

contract LicenseRegistryV2 is AccessControlUpgradeable, PausableUpgradeable, LicenseRegistryDAL, IVersioned {
    event LicensedAdded(uint256 indexed _id, address indexed _creator);

    function getVersion() external pure override returns (uint8) {
        return 2; //Increment at every new cotract version
    }

    modifier onlyAdmin() {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Not admin");
        _;
    }

    function getPurchasedLicenseIdsByOwner(address _owner) public view returns (uint256[] memory) {
        return _data_getLicenseIdsForOwner(_owner);
    }

    function getPurchasedLicenseInfosByOwner(address _owner) public view returns (PurchasedLicenseV3[] memory) {
        uint256[] memory ids = _data_getLicenseIdsForOwner(_owner);
        PurchasedLicenseV3[] memory infos = new PurchasedLicenseV3[](ids.length);
        for (uint256 i = 0; i < ids.length; i++) {
            infos[i] = _data_getLicenseIdToLicenseInfo(ids[i]);
        }
        return infos;
    }

    function dispensePurchasedLicenseRunningId() public returns (uint256) {
        RootRegistryV2 rootReg = RootRegistryV2(getAddressManager().getRootRegistry());
        require(
            rootReg.isValidRegistry(_msgSender()),
            "dispensePurchasedLicenseRunningId: sender is not a valid or active registry"
        );
        _data_incrementPurchasedLicenseInfoCounter();
        return _data_getPurchasedLicenseInfoCounter();
    }

    function registerPurchase(uint256 _dispensedId, PurchasedLicenseV3 memory _licenseInfo) public {
        RootRegistryV2 rootReg = RootRegistryV2(getAddressManager().getRootRegistry());
        require(_data_isEmptyLicenseIdToLicenseInfo(_dispensedId), "registerPurchase: license id already set");
        require(rootReg.isValidRegistry(_msgSender()), "registerPurchase: sender not valid or active registry");
        _data_setLicenseIdToLicenseInfo(_dispensedId, _licenseInfo);
        _data_addLicenseIdToOwner(_licenseInfo.licenseOwner, _dispensedId);
    }

    function getLicenseInfoFromId(uint256 _licenseId) public view returns (PurchasedLicenseV3 memory) {
        return _data_getLicenseIdToLicenseInfo(_licenseId);
    }

    function initialize(address _storage, address _controller) public initializer {
        __Pausable_init();
        __AccessControl_init();
        __DATA__ = EternalStorage(_storage);
        _grantRole(DEFAULT_ADMIN_ROLE, _controller);
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);

        _data_setOwner(msg.sender);
        _data_setController(_controller);
    }

    //paused
    function pause() public onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    function getAllLicenseTypeIds() public view returns (uint256[] memory) {
        return _data_getLicenseBlueprintIds();
    }

    function getOptinIdsForLicenseBlueprintId(address _registry, uint256 _licenseBlueprintId)
        public
        view
        returns (uint256[] memory)
    {
        return _data_getOptInIdsForRegistryAndLicenseBlueprint(_registry, _licenseBlueprintId);
    }

    function getLicenseBlueprintbyAddress(address licenseAddress) public view returns (LicenseBlueprintInfoV2 memory) {
        return _data_getLicenseBlueprintInfo(_data_getAddressToId(licenseAddress));
    }

    function getLicenseBlueprintbyId(uint256 _blueprintId) public view returns (LicenseBlueprintInfoV2 memory) {
        return _data_getLicenseBlueprintInfo(_blueprintId);
    }

    function getSellerFieldsForOptInId(uint256 _optInId) public view returns (LicenseField[] memory) {
        return _data_getOptInIdToSellerFields(_optInId);
    }

    function getOptInById(uint256 _optInId) public view returns (LicenseOptInV2 memory) {
        return _data_getOptInIdToOptInInfo(_optInId);
    }

    function getOptInStatus(address _ipRegistry, uint256 _optInId) public view returns (bool) {
        return _data_getRegistryAddressToActiveOptInCount(_ipRegistry, _optInId) > 0;
    }

    function addOptInToLicense(
        LicenseScope _scope,
        address _ipRegistry,
        uint256 _licenseBlueprintId,
        address _currency,
        uint256 _minAmount,
        string memory _name,
        LicenseField[] memory _sellerFields,
        string memory _encryptedInfo
    ) public returns (uint256) {
        require(msg.sender == _ipRegistry);
        _data_incrementOptInCounter();
        uint256 currentOptInCounter = _data_getOptInCounter();
        _data_setOptInIdToOptInInfo(
            currentOptInCounter,
            LicenseOptInV2(
                _scope,
                _name,
                _ipRegistry,
                _licenseBlueprintId,
                currentOptInCounter,
                _minAmount,
                block.timestamp,
                _currency,
                true,
                _encryptedInfo
            )
        );
        _data_addOptInIdToRegistry(_ipRegistry, _licenseBlueprintId, currentOptInCounter);
        LicenseField[] memory optInSellerFields = new LicenseField[](_sellerFields.length);
        for (uint256 i = 0; i < _sellerFields.length; i++) {
            optInSellerFields[i] = (
                LicenseField({
                    name: _sellerFields[i].name,
                    val: _sellerFields[i].val,
                    id: _sellerFields[i].id,
                    dataType: _sellerFields[i].dataType,
                    info: _sellerFields[i].info
                })
            );
        }
        _data_setOptInIdToSellerFields(currentOptInCounter, optInSellerFields);
        _data_incrementRegistryAddressToActiveOptInCount(_ipRegistry, _licenseBlueprintId);
        return currentOptInCounter;
    }

    function optOutOfLicensePrecondition(address _ipRegistry, uint256 _licenseId, uint256 _preConditionId) public {
        require(msg.sender == _ipRegistry, "only original registry can opt out");
        LicenseOptInV2 memory optInInfo = _data_getOptInIdToOptInInfo(_preConditionId);
        require(optInInfo.registry == _ipRegistry, "Precondition not owned by this registry");
        require(optInInfo.licenseBlueprintId == _licenseId, "Precondition license id does not match");
        require(
            _data_getRegistryAddressToActiveOptInCount(_ipRegistry, _licenseId) > 0, "No matching active preconditions"
        );
        optInInfo.active = false;
        _data_setOptInIdToOptInInfo(_preConditionId, optInInfo);
        _data_decrementRegistryAddressToActiveOptInCount(_ipRegistry, _licenseId);
    }

    function addLicenseBlueprintFromAddress(address licenseAddress) public returns (uint256) {
        _data_incrementLicenseIdCounter();
        uint256 current = _data_getLicenseIdCounter();
        _data_setIdToAddress(current, licenseAddress);
        _data_setAddressToId(licenseAddress, current);

        ILicenseBlueprint lbp = ILicenseBlueprint(licenseAddress);
        LicenseBlueprintInfoV2 memory bpi = lbp.getBlueprintInfo();
        require(bpi.sellerFields.length < 1000, "Too many seller fields. Max 1000");
        _data_setLicenseBlueprintInfo(current, bpi);
        _data_addLicenseBlueprintId(current);
        emit LicensedAdded(current, msg.sender);
        return current;
    }

    function setActive(uint256 _licenseBlueprintId, bool _newStatus) public {
        require(
            _data_getLicenseBlueprintInfo(_licenseBlueprintId).controller == msg.sender, "not allowed to change status"
        );
        _data_setLicenseBlueprintActive(_licenseBlueprintId, _newStatus);
    }
}
