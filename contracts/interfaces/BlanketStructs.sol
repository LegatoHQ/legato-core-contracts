// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import "./Structs.sol";

enum LicenseScope {
    SINGLE,
    STORE,
    ARTIST,
    ROOT
}

enum StoreStatus {
    ACTIVE,
    INACTIVE,
    PAUSED
}

enum DenounceReason {
    ILLEGAL_ACTIVITY,
    TAKEDOWN_REQUEST,
    BY_OWNER,
    OTHER
}

struct LicenseOptInV2 {
    LicenseScope scope;
    string name;
    address registry;
    uint256 licenseBlueprintId;
    uint256 optInId;
    uint256 minAmount;
    uint256 createDate;
    address currency;
    bool active;
    string encryptedInfo;
}

struct LicenseBlueprintInfoV2 {
    address contractAddress;
    address owner;
    address controller;
    string uri;
    string ipfsFileHash;
    bool canExpire;
    bool active;
    string name;
    uint256 fee;
    LicenseField[] sellerFields;
    LicenseField[] buyerFields;
    LicenseField[] autoFields;
    uint8 scope;
}

struct PurchasedLicenseV2 {
    LicenseScope scope;
    uint256 licenseBlueprintId;
    address basedOnLicenseBlueprint;
    address target;
    string kind;
    string fileHash;
    string uri;
    address licenseOwner;
    bool canExpire;
    uint256 expiryDate;
    address auto_minter;
    uint256 auto_blockNumber;
    uint256 auto_timestamp;
    uint256 auto_chainId;
    uint256 auto_paymentId;
    uint256 auto_tokenId;
    string encryptedSellerInfo;
    string encryptedBuyerInfo;
}

struct tempLicenseMIntParamsV2 {
    LicenseBlueprintInfoV2 licenseBlueprint;
    PurchasedLicenseV3 newInfo;
    uint256 pendingLicRegId;
}

struct PurchasedLicenseV3 {
    LicenseScope scope;
    uint256 licenseBlueprintId;
    address basedOnLicenseBlueprint;
    address target;
    string kind;
    string fileHash;
    string uri;
    address licenseOwner;
    bool canExpire;
    uint256 expiryDate;
    address auto_minter;
    uint256 auto_blockNumber;
    uint256 auto_timestamp;
    uint256 auto_chainId;
    uint256 auto_paymentId;
    uint256 auto_tokenId; //NFT license token id
    uint256 auto_optinId;
    uint256 auto_batchPaymentId;
    uint256 auto_purchasedLicenseId;
    uint8 auto_licenseContractVersion;
    address auto_licenseContract; //address of the license contract
    string encryptedSellerInfo;
    string encryptedBuyerInfo;
}
