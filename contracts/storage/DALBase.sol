// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import "./EternalStorage.sol";
import "./AddressManager.sol";
import "contracts/dataBound/CommonUpgradeableStorageVars.sol";

abstract contract DALBase is CommonUpgradeableStorageVars {
    EternalStorage public __DATA__;

    function PREFIX() public pure virtual returns (string memory);

    function getAddressManager() public view returns (AddressManager) {
        //Address manager might have been upgraded so we always get its latest version
        return AddressManager(AddressManager(__DATA__.getAddressManager()).getAddressManager());
    }

    ///PACK
    function PACK(string memory _key1) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(PREFIX(), _key1));
    }

    function PACK_NO_PREFIX(string memory _key1) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(_key1));
    }

    function PACK(string memory _key1, uint256 _key2) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(PREFIX(), _key1, _key2));
    }

    function PACK(string memory _key1, address _key2) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(PREFIX(), _key1, _key2));
    }

    function PACK(string memory _key1, address _key2, uint256 _key3) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(PREFIX(), _key1, _key2, _key3));
    }
}
