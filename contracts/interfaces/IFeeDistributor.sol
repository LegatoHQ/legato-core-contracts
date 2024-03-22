// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import "contracts/interfaces/Structs.sol";

interface IFeeDistributor {
    // function addCurrency(address currency) external;

    // function claim(uint256 claimId) external;

    // function getClaim(uint256 claimId) external view returns (ClaimInfo memory);

    // function getClaimsByAddress(address account) external view returns (uint256[] memory);

    // function getClaimsByPaymentId(uint256 paymentId) external view returns (uint256[] memory);

    // function getPayment(uint256 paymentId) external view returns (PaymentInfo memory);

    // function getPaymentsLength() external view returns (uint256);

    // function initialize(address _admin, address _allowedCurrency) external;

    // function isCurrencyAllowed(address currency) external view returns (bool);

    function payStoreWithToken(FeeInfo memory _feeInfo, address _target) external returns (uint256);
    function pay(FeeInfo memory _feeInfo, address _target) external returns (uint256);
    function payStoreDirect(FeeInfo memory _feeInfo) external returns (uint256);
    function grantPayer(address _address) external;
    function grantAdmin(address _address) external;

    // function removeCurrency(address currency) external;

    // function setProtocolFee(uint256 _protocolFee) external;

    // function updateClaim(uint256 claimId, uint256 amount) external;

    // function updatePayment(uint256 paymentId, uint256 amount) external;

    // function withdrawErcFeeBalance(address token, uint256 amount) external;

    // function withdrawNativeFeeBalance(uint256 amount) external;

    // function withdrawProtocolFee() external;
}
