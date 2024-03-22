// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

enum CurrencyStatus {
    DISABLED,
    ENABLED
}

enum AccountType {
    DEFAULT, // == 0
    SINGLE1,
    SINGLE2,
    SINGLE3,
    SINGLE4,
    SINGLE5,
    SINGLE6,
    SINGLE7,
    SINGLE8,
    SINGLE9,
    SINGLE10, //int8==10
    MULTI1, //11 and up: multi
    MULTI2,
    MULTI3,
    MULTI4,
    MULTI5,
    MULTI6,
    MULTI7,
    MULTI8,
    MULTI9,
    MULTI10, //20
    ENTERPRISE1, // 21and up: enterprise
    ENTERPRISE2,
    ENTERPRISE3,
    ENTERPRISE4,
    ENTERPRISE5,
    ENTERPRISE6,
    ENTERPRISE7,
    ENTERPRISE8,
    ENTERPRISE9,
    ENTERPRISE10, //30
    CUSTOM1, //31 and up: custom
    CUSTOM2,
    CUSTOM3,
    CUSTOM4,
    CUSTOM5,
    CUSTOM6,
    CUSTOM7,
    CUSTOM8,
    CUSTOM9,
    CUSTOM10, //40
    OTHER1, //41 and up: other
    OTHER2,
    OTHER3,
    OTHER4,
    OTHER5,
    OTHER6,
    OTHER7,
    OTHER8,
    OTHER9,
    OTHER10 //50

}

struct PaymentBatchInfo {
    uint256 id;
    uint256 blockNumber;
    address registry;
    address target;
    address payer;
    address currency;
    string memo;
    uint256 totalAmount;
    uint256 fee;
    uint256 left;
    bool paid;
}

struct PaymentInfo4 {
    uint256 paymentBatchId;
    uint256 id;
    uint256 blockNumber;
    uint256 amount;
    address currency;
    address blueprint;
    address royaltyToken;
    bool paid;
    uint256 left;
    address payer;
    uint256 totalAmount;
    uint256 fee;
    string memo;
}

struct PaymentInfo3 {
    uint256 paymentBatchId;
    uint256 id;
    uint256 blockNumber;
    uint256 amount;
    address currency;
    address blueprint;
    address royaltyToken;
    bool paid;
    uint256 left;
    address payer;
    uint256 totalAmount;
    uint256 fee;
}

struct PaymentInfo {
    uint256 paymentBatchId;
    uint256 id;
    uint256 blockNumber;
    uint256 amount;
    address currency;
    address blueprint;
    address royaltyToken;
    bool paid;
    uint256 left;
}

struct ClaimInfo {
    uint256 paymentBatchId;
    uint256 paymentId;
    uint256 id;
    address target;
    bool paid;
    uint256 left;
    address currency;
    address royaltyToken;
    uint256 amount;
}

struct Balance {
    address holder;
    uint256 amount;
}

struct SplitTarget {
    address holderAddress;
    uint256 amount;
    string memo;
}

struct SplitInfo {
    SplitTarget[] compSplits;
    SplitTarget[] recSplits;
}

struct RoyaltyTokenData {
    string kind;
    string name;
    string symbol;
    address tokenAddress;
    string memo;
    SplitTarget[] targets;
}

struct IPInfo {
    string kind;
    address contractAddress;
    address[] tokens;
    string metadataURI;
    string fileHash;
}

struct BlueprintMintingParams {
    string shortName;
    string fileHash;
    string symbol;
    string metadataURI;
    string kind;
    RoyaltyTokenData[] tokens;
}

//see also BlanketLicenseOptIn
//in infra/contracts/interfaces/BlanketStructs.sol
struct LicenseOptIn {
    string name;
    address registry;
    uint256 licenseId;
    uint256 optInId;
    uint256 minAmount;
    address currency;
    bool active;
}

struct LicenseField {
    uint256 id;
    string name;
    string val;
    string dataType;
    string info;
}
// LicenseFieldType fieldType;

struct FeeInfo {
    address blueprint;
    address currency;
    uint256 amount;
    uint256 minAmount;
    address onBehalfOf;
    string memo;
}

struct ExternalPaymentRequest {
    address payer;
    address target;
    address currency;
    uint256 amount;
    string memo;
}

struct MintLicenseRequest {
    uint256 licenseBlueprintId;
    uint256 optInId;
    address to;
    address target;
    address currency;
    uint256 amount;
    // LicenseField[] sellerFields;
    LicenseField[] buyerFields;
    string encryptedBuyerInfo;
    string memo;
}
//also see BlanketLicenseBlueprint
//in infra/contracts/interfaces/BlanketStructs.sol for struct

struct LicenseBlueprintInfo {
    address contractAddress;
    address owner;
    address controller;
    string uri;
    bool canExpire;
    bool active;
    string name;
    uint256 fee;
    LicenseField[] sellerFields;
    LicenseField[] buyerFields;
}
//also see BlanketPurchaseLicense
//in infra/contracts/interfaces/BlanketStructs.sol for struct

struct PurchasedLicense {
    uint256 licenseBlueprintId;
    address basedOnLicenseBlueprint;
    address regardingIPBlueprint;
    string kind;
    string fileHash;
    string uri;
    address licenseOwner;
    bool canExpire;
    uint256 expiryDate;
    address auto_minter;
    uint256 auto_blockNumber;
    uint256 auto_chainId;
    uint256 auto_paymentId;
}

struct SongMintingParams {
    string shortName;
    string fileHash;
    string symbol;
    string metadataUri;
    SplitInfo splits;
}
