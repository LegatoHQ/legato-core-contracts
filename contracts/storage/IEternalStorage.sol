// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

interface IEternalStorage {
    //GET

    function getAddressListValue(bytes32 record) external view returns (address[] memory);

    function getUIntListValue(bytes32 record) external view returns (uint256[] memory);

    function getInt8Value(bytes32 record) external view returns (uint8);

    function getUIntValue(bytes32 record) external view returns (uint256);

    function getStringValue(bytes32 record) external view returns (string memory);

    function getAddressValue(bytes32 record) external view returns (address);

    function getBytesValue(bytes32 record) external view returns (bytes memory);

    function getBytes32Value(bytes32 record) external view returns (bytes32);

    function getBooleanValue(bytes32 record) external view returns (bool);

    function getIntValue(bytes32 record) external view returns (int256);

    ///SETTERS
    function setAddressListValue(bytes32 record, address[] memory value) external;

    function setUIntListValue(bytes32 record, uint256[] memory value) external;

    function setInt8Value(bytes32 record, uint8 value) external;

    function setBytes32Value(bytes32 record, bytes32 value) external;

    function setAddressValue(bytes32 record, address value) external;

    function setBytesValue(bytes32 record, bytes memory value) external;

    function setUIntValue(bytes32 record, uint256 value) external;

    function setStringValue(bytes32 record, string memory value) external;

    function setBooleanValue(bytes32 record, bool value) external;

    function setIntValue(bytes32 record, int256 value) external;

    ///DELETE
    function deleteAddressListValue(bytes32 record) external;

    function deleteUintListValue(bytes32 record) external;

    function deleteInt8Value(bytes32 record) external;

    function deleteBytes32Value(bytes32 record) external;

    function deleteUIntValue(bytes32 record) external;

    function deleteBytesValue(bytes32 record) external;

    function deleteAddressValue(bytes32 record) external;

    function deleteBooleanValue(bytes32 record) external;

    function deleteIntValue(bytes32 record) external;

    function deleteStringValue(bytes32 record) external;

    //UTIL
    function allowContract(bytes32 record, address _contract) external;
}
