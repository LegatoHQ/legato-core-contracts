// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import "lib/openzeppelin-contracts/contracts/access/AccessControl.sol";
import "lib/openzeppelin-contracts/contracts/utils/Counters.sol";
import "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "lib/openzeppelin-contracts/contracts/security/Pausable.sol";
import "contracts/interfaces/Structs.sol";
import "contracts/interfaces/BlanketStructs.sol";
import "contracts/interfaces/ILicenseBlueprint.sol";
import "lib/forge-std/src/console.sol";
import "contracts/storage/EternalStorage.sol";
import "contracts/storage/DALBase.sol";

contract LicenseRegistryDAL is DALBase {
    string internal constant OWNER = "owner";
    string internal constant CONTROLLER = "controller";
    string internal constant LICENSE_BLUEPRINT_IDS = "licenseBlueprintIds";
    string internal constant ID_TO_BLUEPRINT = "idToBlueprint";
    string internal constant ID_TO_ADDRESS = "idToAddress";
    string internal constant ADDRESS_TO_ID = "addressToId";
    string internal constant REGISTRY_TO_LICENSE_BLUEPRINT_TO_OPTINS = "registryToLicenseBlueprintToOptIns";
    string internal constant REGISTRY_ADDRESS_TO_ACTIVE_OPTINS_COUNT = "registryAddressToActiveOptInsCount";
    string internal constant OPTIN_ID_TO_OPTIN_INFO = "OptInIdToOptInInfo";
    string internal constant OPTIN_ID_TO_SELLER_FIELDS = "OptInToSellerFields";
    string internal constant LICENSE_ID_COUNTER = "licenseIdCounter";
    string internal constant OPTIN_COUNTER = "OptInCounter";
    string internal constant LICENSE_ID_TO_LICENSE_INFO = "licenseIdToLicenseInfo";
    string internal constant PURCHASED_LICENSEINFO_COUNTER = "purchasedLicenseInfoCounter";
    string internal constant LICENSE_IDS_TO_OWNERS = "licenseIdToOwners";

    function PREFIX() public pure override returns (string memory) {
        return "licReg.";
    }

    //set owner
    function _data_setOwner(address _owner) internal {
        __DATA__.setAddressValue(PACK("owner"), _owner);
    }
    //controller

    function _data_addLicenseIdToOwner(address _owner, uint256 _id) internal {
        __DATA__.pushUintListValue(PACK(LICENSE_IDS_TO_OWNERS, _owner), _id);
    }

    function _data_getLicenseIdsForOwner(address _owner) internal view returns (uint256[] memory) {
        return __DATA__.getUIntListValue(PACK(LICENSE_IDS_TO_OWNERS, _owner));
    }

    function _data_setController(address _controller) internal {
        __DATA__.setAddressValue(PACK(CONTROLLER), _controller);
    }

    function _data_setLicenseIdToLicenseInfo(uint256 _id, PurchasedLicenseV3 memory _info) internal {
        __DATA__.setBytesValue(PACK(LICENSE_ID_TO_LICENSE_INFO, _id), abi.encode(_info));
    }

    function _data_isEmptyLicenseIdToLicenseInfo(uint256 _id) internal view returns (bool) {
        return __DATA__.getBytesValue(PACK(LICENSE_ID_TO_LICENSE_INFO, _id)).length == 0;
    }

    function _data_getLicenseIdToLicenseInfo(uint256 _id) internal view returns (PurchasedLicenseV3 memory) {
        return abi.decode(__DATA__.getBytesValue(PACK(LICENSE_ID_TO_LICENSE_INFO, _id)), (PurchasedLicenseV3));
    }

    function _data_incrementPurchasedLicenseInfoCounter() internal {
        __DATA__.incUIntValue(PACK(PURCHASED_LICENSEINFO_COUNTER), 1);
    }

    function _data_getPurchasedLicenseInfoCounter() internal view returns (uint256) {
        return __DATA__.getUIntValue(PACK(PURCHASED_LICENSEINFO_COUNTER));
    }

    function _data_addLicenseBlueprintId(uint256 _id) internal {
        __DATA__.pushUintListValue(PACK(LICENSE_BLUEPRINT_IDS), _id);
    }

    function _data_getLicenseBlueprintIds() internal view returns (uint256[] memory) {
        return __DATA__.getUIntListValue(PACK(LICENSE_BLUEPRINT_IDS));
    }

    function _data_setLicenseBlueprintInfo(uint256 _id, LicenseBlueprintInfoV2 memory _info) internal {
        __DATA__.setBytesValue(PACK(ID_TO_BLUEPRINT, _id), abi.encode(_info));
    }

    function _data_getLicenseBlueprintInfo(uint256 _id) internal view returns (LicenseBlueprintInfoV2 memory) {
        return abi.decode(__DATA__.getBytesValue(PACK(ID_TO_BLUEPRINT, _id)), (LicenseBlueprintInfoV2));
    }

    function _data_setLicenseBlueprintActive(uint256 _licenseBlueprintId, bool _newStatus) internal {
        LicenseBlueprintInfoV2 memory info = _data_getLicenseBlueprintInfo(_licenseBlueprintId);
        info.active = _newStatus;
        _data_setLicenseBlueprintInfo(_licenseBlueprintId, info);
    }

    function _data_setIdToAddress(uint256 _id, address _address) internal {
        __DATA__.setAddressValue(PACK(ID_TO_ADDRESS, _id), _address);
    }

    function _data_getIdToAddress(uint256 _id) internal view returns (address) {
        return __DATA__.getAddressValue(PACK(ID_TO_ADDRESS, _id));
    }

    function _data_setAddressToId(address _address, uint256 _id) internal {
        __DATA__.setUIntValue(PACK(ADDRESS_TO_ID, _address), _id);
    }

    function _data_getAddressToId(address _address) internal view returns (uint256) {
        return __DATA__.getUIntValue(PACK(ADDRESS_TO_ID, _address));
    }

    function _data_addOptInIdToRegistry(address _registry, uint256 _licenseBlueprintId, uint256 _optInId) internal {
        __DATA__.pushUintListValue(
            PACK(REGISTRY_TO_LICENSE_BLUEPRINT_TO_OPTINS, _registry, _licenseBlueprintId), _optInId
        );
    }

    function _data_getOptInIdsForRegistryAndLicenseBlueprint(address _registry, uint256 _licenseBlueprintId)
        internal
        view
        returns (uint256[] memory)
    {
        return __DATA__.getUIntListValue(PACK(REGISTRY_TO_LICENSE_BLUEPRINT_TO_OPTINS, _registry, _licenseBlueprintId));
    }

    function _data_setRegistryAddressToActiveOptInCount(address _registry, uint256 _licenseBlueprintId, uint256 _count)
        internal
    {
        __DATA__.setUIntValue(PACK(REGISTRY_ADDRESS_TO_ACTIVE_OPTINS_COUNT, _registry, _licenseBlueprintId), _count);
    }

    function _data_incrementRegistryAddressToActiveOptInCount(address _registry, uint256 _licenseBlueprintId)
        internal
    {
        uint256 currentValue = _data_getRegistryAddressToActiveOptInCount(_registry, _licenseBlueprintId);
        __DATA__.setUIntValue(
            PACK(REGISTRY_ADDRESS_TO_ACTIVE_OPTINS_COUNT, _registry, _licenseBlueprintId), currentValue + 1
        );
    }

    function _data_decrementRegistryAddressToActiveOptInCount(address _registry, uint256 _licenseBlueprintId)
        internal
    {
        uint256 currentValue = _data_getRegistryAddressToActiveOptInCount(_registry, _licenseBlueprintId);
        __DATA__.setUIntValue(
            PACK(REGISTRY_ADDRESS_TO_ACTIVE_OPTINS_COUNT, _registry, _licenseBlueprintId), currentValue - 1
        );
    }

    function _data_getRegistryAddressToActiveOptInCount(address _registry, uint256 _licenseBlueprintId)
        internal
        view
        returns (uint256)
    {
        return __DATA__.getUIntValue(PACK(REGISTRY_ADDRESS_TO_ACTIVE_OPTINS_COUNT, _registry, _licenseBlueprintId));
    }

    function _data_setOptInIdToOptInInfo(uint256 _optInId, LicenseOptInV2 memory _info) internal {
        __DATA__.setBytesValue(PACK(OPTIN_ID_TO_OPTIN_INFO, _optInId), abi.encode(_info));
    }

    function _data_getOptInIdToOptInInfo(uint256 _optInId) internal view returns (LicenseOptInV2 memory) {
        return abi.decode(__DATA__.getBytesValue(PACK(OPTIN_ID_TO_OPTIN_INFO, _optInId)), (LicenseOptInV2));
    }

    function _data_setOptInIdToSellerFields(uint256 _optInId, LicenseField[] memory _fields) internal {
        __DATA__.setBytesValue(PACK(OPTIN_ID_TO_SELLER_FIELDS, _optInId), abi.encode(_fields));
    }

    function _data_getOptInIdToSellerFields(uint256 _optInId) internal view returns (LicenseField[] memory) {
        return abi.decode(__DATA__.getBytesValue(PACK(OPTIN_ID_TO_SELLER_FIELDS, _optInId)), (LicenseField[]));
    }

    function _data_setLicenseIdCounter(uint256 _value) internal {
        __DATA__.setUIntValue(PACK(LICENSE_ID_COUNTER), _value);
    }

    function _data_getLicenseIdCounter() internal view returns (uint256) {
        return __DATA__.getUIntValue(PACK(LICENSE_ID_COUNTER));
    }

    // function _data_setOptInCounter(uint256 _value) internal {
    //     __DATA__.setUIntValue(PACK(OPTIN_COUNTER), _value);
    // }
    //increment optin counter
    function _data_incrementOptInCounter() internal {
        __DATA__.incUIntValue(PACK(OPTIN_COUNTER), 1);
    }
    //increment license id counter

    function _data_incrementLicenseIdCounter() internal {
        __DATA__.incUIntValue(PACK(LICENSE_ID_COUNTER), 1);
    }

    function _data_getOptInCounter() internal view returns (uint256) {
        return __DATA__.getUIntValue(PACK(OPTIN_COUNTER));
    }
}
