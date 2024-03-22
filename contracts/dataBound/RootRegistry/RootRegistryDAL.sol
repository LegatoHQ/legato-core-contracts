// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import "contracts/storage/EternalStorage.sol";
import "contracts/storage/DALBase.sol";

contract RootRegistryDAL is DALBase {
    string internal constant WALLET_TO_REGISTRIES = "walletToRegistries";
    string internal constant IS_REGISTRY = "isRegistry";
    string internal constant IS_DENIED = "isDenied";
    string internal constant REGISTRY_TO_INDEX = "registryToIndex";
    string internal constant REGISTRIES = "registries";
    string internal constant DENOUNCED_REGISTRIES = "denouncedRegistries";

    function PREFIX() public pure override returns (string memory) {
        return "rootReg";
    }

    function _data_setRegistriesToWallet(address _wallet, address[] memory _registries) internal {
        __DATA__.setAddressListValue(PACK(WALLET_TO_REGISTRIES, _wallet), _registries);
    }

    function _data_deleteRegistriesToWallet(address _wallet) internal {
        __DATA__.deleteAddressListValue(PACK(WALLET_TO_REGISTRIES, _wallet));
    }

    function _data_addRegistryToWallet(address _wallet, address _registry) internal {
        __DATA__.pushToAddressList(PACK(WALLET_TO_REGISTRIES, _wallet), _registry);
    }

    function _data_getRegistriesForWallet(address _wallet) public view returns (address[] memory) {
        return __DATA__.getAddressListValue(PACK(WALLET_TO_REGISTRIES, _wallet));
    }

    function _data_setIsRegistry(address _registry, bool _value) internal {
        __DATA__.setBooleanValue(PACK(IS_REGISTRY, _registry), _value);
    }

    function _data_getIsRegistry(address _registry) public view returns (bool) {
        return __DATA__.getBooleanValue(PACK(IS_REGISTRY, _registry));
    }

    function _data_setIsDenied(address _registry, bool _value) internal {
        __DATA__.setBooleanValue(PACK(IS_DENIED, _registry), _value);
    }

    function _data_getIsDenied(address _registry) public view returns (bool) {
        return __DATA__.getBooleanValue(PACK(IS_DENIED, _registry));
    }

    function _data_setRegistryToIndex(address _registry, uint256 _index) internal {
        __DATA__.setUIntValue(PACK(REGISTRY_TO_INDEX, _registry), _index);
    }

    function _data_getRegistryToIndex(address _registry) public view returns (uint256) {
        return __DATA__.getUIntValue(PACK(REGISTRY_TO_INDEX, _registry));
    }

    function _data_deleteRegistryToIndex(address _registry) internal {
        __DATA__.deleteUIntValue(PACK(REGISTRY_TO_INDEX, _registry));
    }

    function _data_addRegistry(address _registry) internal {
        __DATA__.pushToAddressList(PACK(REGISTRIES), _registry);
    }

    function _data_getRegistries() public view returns (address[] memory) {
        return __DATA__.getAddressListValue(PACK(REGISTRIES));
    }

    function _data_setRegistries(address[] memory _registries) internal {
        __DATA__.setAddressListValue(PACK(REGISTRIES), _registries);
    }

    function _data_updateRegistry(uint256 _index, address _registry) internal {
        __DATA__.updateAddressListValue(PACK(REGISTRIES), _index, _registry);
    }

    function _data_deleteRegistry(uint256 _index) internal {
        __DATA__.deleteAddressListItem(PACK(REGISTRIES), _index);
    }

    function _data_addDenouncedRegistry(address _registry) internal {
        __DATA__.pushToAddressList(PACK(DENOUNCED_REGISTRIES), _registry);
    }

    function _data_getDenouncedRegistries() public view returns (address[] memory) {
        return __DATA__.getAddressListValue(PACK(DENOUNCED_REGISTRIES));
    }
}
