// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import "contracts/interfaces/Structs.sol";
import "contracts/interfaces/BaseIPPortionToken.sol";
import "contracts/interfaces/IFeeDistributor.sol";
import "contracts/registries/IRegistryV2.sol";
import "contracts/interfaces/ITokenized.sol";
import "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "lib/openzeppelin-contracts/contracts/utils/math/SafeMath.sol";
import "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol"; // Import the SafeERC20 library
// import "lib/forge-std/src/console.sol";
import "contracts/storage/EternalStorage.sol";
import "contracts/storage/DALBase.sol";

/// @title FeeDistributorDAL
/// @notice Data Layer for the FeeDistributor contract
/// @dev has direct access to the storage contract

abstract contract FeeDistributorDAL is DALBase {
    string internal constant ALLOWED_CURRENCIES = "allowedCurrencies";
    string internal constant PROTOCOL_FEES = "protocolFees";
    string internal constant PROTOCOL_FEE = "protocolFee";
    string internal constant USER_PROTOCOL_FEE = "user.protocolFee";
    string internal constant USER_HAS_PROTOCOL_FEE = "user.has.protocolFee";
    string internal constant RUNNING_PAYMENT_ID = "runningPaymentId";
    string internal constant RUNNING_CLAIM_ID = "runningClaimId";
    string internal constant RUNNING_PAYMENT_BATCH_ID = "runningPaymentBatchId";
    string internal constant PAYMENTS = "payments";
    string internal constant PAYMENT_BATCHES = "paymentBatches";
    string internal constant PAYMENT_BATCH_TO_PAYMENTS = "paymentBatchesToPayments";
    string internal constant CLAIMS = "claims";
    string internal constant CLAIMS_BY_ADDRESS = "claimsByAddress";
    string internal constant CLAIMS_BY_PAYMENT_ID = "claimsByPaymentId";
    string internal constant ROOT_ADDRESS = "rootAddress";

    //override prefix
    function PREFIX() public pure override returns (string memory) {
        return "feeDist";
    }

    ///Claim IDs

    function _data_getClaimIdsByAddress(address _target) internal view returns (uint256[] memory) {
        return __DATA__.getUIntListValue(PACK(CLAIMS_BY_ADDRESS, _target));
    }

    function _data_pushClaimIdToListByAddress(address _target, uint256 _claimId) internal {
        __DATA__.pushUintListValue(PACK(CLAIMS_BY_ADDRESS, _target), _claimId);
    }

    function _data_getClaimIdsByPaymentId(uint256 _paymentId) internal view returns (uint256[] memory) {
        return __DATA__.getUIntListValue(PACK(CLAIMS_BY_PAYMENT_ID, _paymentId));
    }

    function _data_pushClaimIdToListByPaymentId(uint256 _paymentId, uint256 _claimId) internal {
        __DATA__.pushUintListValue(PACK(CLAIMS_BY_PAYMENT_ID, _paymentId), _claimId);
    }

    ///payment info
    function _data_getClaimByClaimId(uint256 _claimId) internal view returns (ClaimInfo memory) {
        return abi.decode(__DATA__.getBytesValue(PACK(CLAIMS, _claimId)), (ClaimInfo));
    }

    function _data_getPaymentBatchInfo(uint256 _paymentBatchId) internal view returns (PaymentBatchInfo memory) {
        return abi.decode(__DATA__.getBytesValue(PACK(PAYMENT_BATCHES, _paymentBatchId)), (PaymentBatchInfo));
    }

    function _data_setPaymentBatchInfo(PaymentBatchInfo memory _paymentBatch) internal {
        __DATA__.setBytesValue(PACK(PAYMENT_BATCHES, _paymentBatch.id), abi.encode(_paymentBatch));
    }

    function _data_addSubPaymentToPaymentBatch(uint256 _paymentBatchId, uint256 _paymentId) internal {
        __DATA__.pushUintListValue(PACK(PAYMENT_BATCH_TO_PAYMENTS, _paymentBatchId), _paymentId);
    }

    function _data_getSubPaymentsFromPaymentBatch(uint256 _paymentBatchId) internal view returns (uint256[] memory) {
        return __DATA__.getUIntListValue(PACK(PAYMENT_BATCH_TO_PAYMENTS, _paymentBatchId));
    }

    function _data_setClaimByClaimId(uint256 _claimId, ClaimInfo memory _claim) internal {
        __DATA__.setBytesValue(PACK(CLAIMS, _claimId), abi.encode(_claim));
    }

    ///payment info
    function _data_addOrSetPaymentInfo4(PaymentInfo4 memory _payment) internal {
        __DATA__.setBytesValue(PACK(PAYMENTS, _payment.id), abi.encode(_payment));
    }

    function _data_addPaymentInfo3(PaymentInfo3 memory _payment) internal {
        __DATA__.setBytesValue(PACK(PAYMENTS, _payment.id), abi.encode(_payment));
    }

    function _data_getPaymentInfo4(uint256 _paymentId) internal view returns (PaymentInfo4 memory) {
        return abi.decode(__DATA__.getBytesValue(PACK(PAYMENTS, _paymentId)), (PaymentInfo4));
    }

    function _data_getPaymentInfo3(uint256 _paymentId) internal view returns (PaymentInfo3 memory) {
        return abi.decode(__DATA__.getBytesValue(PACK(PAYMENTS, _paymentId)), (PaymentInfo3));
    }

    function _data_addPaymentInfo(PaymentInfo memory _payment) internal {
        __DATA__.setBytesValue(PACK(PAYMENTS, _payment.id), abi.encode(_payment));
    }

    function _data_getPaymentInfo(uint256 _paymentId) internal view returns (PaymentInfo memory) {
        return abi.decode(__DATA__.getBytesValue(PACK(PAYMENTS, _paymentId)), (PaymentInfo));
    }

    ///protocol fee
    function _data_getProtocolFee() internal view returns (uint256) {
        return __DATA__.getUIntValue(PACK(PROTOCOL_FEE));
    }

    function _data_setProtocolFeeForUser(uint256 _protocolFee, address _user) internal {
        __DATA__.setUIntValue(PACK(USER_PROTOCOL_FEE, _user), _protocolFee);
        __DATA__.setBooleanValue(PACK(USER_HAS_PROTOCOL_FEE, _user), true);
    }

    function _data_getDoesUserHaveProtocolFee(address _user) internal view returns (bool) {
        return __DATA__.getBooleanValue(PACK(USER_HAS_PROTOCOL_FEE, _user));
    }

    function _data_getProtocolFeeForUser(address _user) internal view returns (uint256) {
        return __DATA__.getUIntValue(PACK(USER_PROTOCOL_FEE, _user));
    }

    function _data_setProtocolFee(uint256 _protocolFee) internal {
        __DATA__.setUIntValue(PACK(PROTOCOL_FEE), _protocolFee);
    }

    ///payment batch id
    function _data_getRunningPaymentBatchId() internal view returns (uint256) {
        return __DATA__.getUIntValue(PACK(RUNNING_PAYMENT_BATCH_ID));
    }

    function _data_incRunningPaymentBatchId() internal {
        __DATA__.incUIntValue(PACK(RUNNING_PAYMENT_BATCH_ID), 1);
    }

    ///claim id
    function _data_getRunningClaimId() internal view returns (uint256) {
        return __DATA__.getUIntValue(PACK(RUNNING_CLAIM_ID));
    }

    function _data_incRunningClaimId() internal {
        __DATA__.incUIntValue(PACK(RUNNING_CLAIM_ID), 1);
    }

    ///payment id
    function _data_getRunningPaymentId() internal view returns (uint256) {
        return __DATA__.getUIntValue(PACK(RUNNING_PAYMENT_ID));
    }

    function _data_incRunningPaymentId() internal {
        __DATA__.incUIntValue(PACK(RUNNING_PAYMENT_ID), 1);
    }

    /// allowed currencies
    function _data_addToAllowedCurrenciesList(address _currency) internal {
        __DATA__.pushToAddressList(PACK(ALLOWED_CURRENCIES), _currency);
        _data_setCurrencyStatus(_currency, CurrencyStatus.ENABLED);
    }

    function _data_getAllowedCurrenciesList() internal view returns (address[] memory) {
        return __DATA__.getAddressListValue(PACK(ALLOWED_CURRENCIES));
    }

    ///Currency Status
    function _data_getCurrencyStatus(address _currency) internal view returns (CurrencyStatus) {
        return CurrencyStatus(__DATA__.getInt8Value(PACK(ALLOWED_CURRENCIES, _currency)));
    }

    function _data_setCurrencyStatus(address _currency, CurrencyStatus _status) internal {
        __DATA__.setInt8Value(PACK(ALLOWED_CURRENCIES, _currency), uint8(_status));
    }

    ///Protocol Fees
    function _data_setProtocolFees(address _currency, uint256 _protocolFee) internal {
        __DATA__.setUIntValue(PACK(PROTOCOL_FEES, _currency), _protocolFee);
    }

    function _data_getProtocolFees(address _currency) internal view returns (uint256) {
        return __DATA__.getUIntValue(PACK(PROTOCOL_FEES, _currency));
    }
}
