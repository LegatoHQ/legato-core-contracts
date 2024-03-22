// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import "contracts/dataBound/LicenseRegistry/LicenseRegistry.sol";
import "contracts/LegatoLicense/LegatoLicense.sol";
import "contracts/interfaces/BlanketStructs.sol";
import "contracts/interfaces/Structs.sol";

struct tempLicenseMIntParams {
    LicenseRegistry licReg;
    LicenseBlueprintInfoV2 licenseBlueprint;
    LegatoLicense licenseNFT;
    PurchasedLicenseV2 newInfo;
}

interface IRegistryV2 {
    event NewIP(address songAddress, string shortName, string symbol, address registry);
    event NewStoreToken(address _token, address _registry);
    event RegistryDetached(address indexed registry);
    event OwnerUpdated(address indexed newOwner);
    event StatusUpdated(StoreStatus status);

    function getName() external view returns (string memory);
    function addPayer(address _payer) external;
    function removePayer(address _payer) external;
    function isOwner(address _address) external view returns (bool);
    function isAdmin(address _address) external view returns (bool);
    function isChild(address _addr) external view returns (bool);
    function initialize(string memory _name, address _ownerWallet, address _eternalStoragem, uint256 nonce) external;
    function setName(string memory _name) external;
    function pause() external;
    function unpause() external;
    function optOutofLicense(uint256 _licenseId, uint256 _preConditionId) external;
    function optIntoLicense(
        LicenseScope _scope,
        uint256 _licenseId,
        address _currency,
        uint256 _minCost,
        string memory _name,
        LicenseField[] memory _sellerFields,
        string memory _encryptedInfo
    ) external returns (uint256);

    function mintIP(BlueprintMintingParams memory _params) external returns (address);

    function mintLicense(MintLicenseRequest memory req) external returns (uint256);

    function getAllIps() external view returns (address[] memory);
    function getIpsPaged(uint256 startIndex) external view returns (address[] memory);
    function getIpCount() external view returns (uint256);
    function detachStore() external;
    function updateOwnerWallet(address _newWallet) external;
    function updateStoreStatus(uint8 _newStatus) external;
    function getOwnerWallet() external view returns (address);
    function getSettingsUri() external view returns (string memory);
    function setSettingsUri(string memory _uri) external;
}
