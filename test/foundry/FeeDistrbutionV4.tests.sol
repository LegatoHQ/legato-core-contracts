// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.7;

import "forge-std/Test.sol";

// import "contracts/dataBound/FeeDistributor/FeeDistributorV3.sol";
// structs
import "contracts/interfaces/Structs.sol";
import "contracts/dataBound/FeeDistributor/FeeDistributorV4.sol";
import "contracts/interfaces/IFeeDistributor.sol";
import "./dummies/FakeToken.sol";
import "./util/HelperContract.sol";
import "contracts/interfaces/IRoyaltyPortionToken.sol";
import "contracts/eip5553/IIPRepresentation.sol";
import "contracts/interfaces/Structs.sol";
import "forge-std/console.sol";
import "openzeppelin-contracts/token/ERC20/IERC20.sol";
import "contracts/dataBound/FeeDistributor/FeeDistributorV2.sol";

contract FeeDistributorV4Tests is HelperContract {
    function setUp() public {
        FeeDistributorV4 v4 = new FeeDistributorV4();
        vm.prank(DEPLOYER);
        addressManager.changeContractAddressDangerous("contracts.feeDistributor", address(v4));
    }

    function test_removeCurrency_WillNotShowUpInAllowedList() external {
        vm.startPrank(DEPLOYER);

        assertEq(feeDistributor.getAllowedCurrencies().length, 1);
        feeDistributor.addCurrency(address(addressManager));
        assertEq(feeDistributor.getAllowedCurrencies().length, 2);

        vm.stopPrank();
    }

    function test_addCurrency_SameTwice_Reverts() external {
        vm.startPrank(DEPLOYER);
        feeDistributor.addCurrency(address(this));
        vm.stopPrank();
    }

    function test_claimById_4_usesPaymentInfo4() external {
        vm.prank(BOB);
        address newSongAddress = mintSongBlueprintAs();
        vm.label(newSongAddress, "newSongAddress");

        BlueprintV2 song = BlueprintV2(newSongAddress);

        FeeDistributorV4 payer = FeeDistributorV4(addressManager.getFeeDistributor());
        _fundAndApproveUSDC(address(this), address(payer), 100e6, 100e6);

        vm.startPrank(address(registry));
        uint256 paymentId = payer.pay(
            FeeInfo({
                minAmount: 100e18,
                blueprint: newSongAddress,
                currency: USDC_ADDRESS,
                amount: 100e6,
                onBehalfOf: address(this),
                memo: "test"
            }),
            newSongAddress
        );
        vm.stopPrank();
        assertEq(paymentId, 1);

        uint256[] memory pending1 = payer.getPendingClaimIdsFor(BOB);
        uint256[] memory allClaims = payer.getAllClaimIdsFor(BOB);
        assertEq(pending1.length, 2);
        assertEq(allClaims.length, 2);

        ClaimInfo memory firstClaim1 = payer.getClaimByClaimId(pending1[0]);

        uint256 expectedAmount = 12.5e6 * (100000 - feeDistributor.getProtocolFee()) / 100000;

        assertEq(firstClaim1.id, 1);
        assertEq(firstClaim1.target, BOB);
        assertEq(firstClaim1.currency, USDC_ADDRESS);
        assertEq(firstClaim1.royaltyToken, song.royaltyPortionTokens()[0]);
        assertEq(firstClaim1.amount, expectedAmount);
        assertEq(firstClaim1.left, expectedAmount);
        assertEq(firstClaim1.paymentId, 1);
        assertEq(firstClaim1.paid, false);
        vm.startPrank(BOB);
        payer.claimByID(1);
        vm.expectRevert();
        payer.claimByID(1);
        vm.stopPrank();

        uint256[] memory pending2 = payer.getPendingClaimIdsFor(BOB);
        uint256[] memory allClaims2 = payer.getAllClaimIdsFor(BOB);
        assertEq(pending2.length, 2);
        assertEq(allClaims2.length, 2);
        //check first claim marked as paid
        ClaimInfo memory firstClaim2 = payer.getClaimByClaimId(allClaims2[0]);
        assertEq(firstClaim2.id, 1);
        assertEq(firstClaim2.target, BOB);
        assertEq(firstClaim2.currency, USDC_ADDRESS);
        assertEq(firstClaim2.royaltyToken, song.royaltyPortionTokens()[0]);
        assertEq(firstClaim2.amount, expectedAmount);
        assertEq(firstClaim2.left, 0);
        assertEq(firstClaim2.paymentId, 1);
        assertTrue(firstClaim2.paid);

        //check first pending claim is different than before
        ClaimInfo memory firstClaim3 = payer.getClaimByClaimId(pending2[0]);
        assertEq(firstClaim3.id, 3);
        assertEq(firstClaim3.target, BOB);
        assertEq(firstClaim3.currency, USDC_ADDRESS);
        assertTrue(firstClaim3.left > 0);
        assertEq(firstClaim3.paymentId, 2);
        assertFalse(firstClaim3.paid);

        PaymentInfo4 memory pi = payer.getPaymentInfo4(paymentId);
        assertEq(pi.paymentBatchId, 1);
        assertEq(pi.id, 1);
        assertEq(pi.blockNumber, block.number);
        assertEq(pi.totalAmount, 100e6);
        assertEq(pi.currency, USDC_ADDRESS);
        assertEq(pi.blueprint, newSongAddress);
        assertEq(pi.royaltyToken, song.royaltyPortionTokens()[0]);
        assertEq(pi.paid, false); //only if fee is 0
        assertEq(pi.left, 33750000); //only bob has claimed. Mary did not.
        assertEq(pi.payer, address(this));
        assertEq(pi.fee, 1e7);
    }

    function test_claimById_4_usesPaymentInfo4_fullClaims() external {
        vm.prank(BOB);
        address newSongAddress = mintSongBlueprintAs();
        vm.label(newSongAddress, "newSongAddress");

        BlueprintV2 song = BlueprintV2(newSongAddress);

        FeeDistributorV4 payer = FeeDistributorV4(addressManager.getFeeDistributor());
        _fundAndApproveUSDC(address(this), address(payer), 100e6, 100e6);

        vm.startPrank(address(registry));
        uint256 paymentId = payer.pay(
            FeeInfo({
                minAmount: 100e18,
                blueprint: newSongAddress,
                currency: USDC_ADDRESS,
                amount: 100e6,
                onBehalfOf: address(this),
                memo: "test"
            }),
            newSongAddress
        );
        vm.stopPrank();
        assertEq(paymentId, 1);

        uint256[] memory pending2 = payer.getPendingClaimIdsFor(BOB);
        uint256[] memory allClaims2 = payer.getAllClaimIdsFor(BOB);
        assertEq(pending2.length, 2);
        assertEq(allClaims2.length, 2);

        vm.startPrank(BOB);
        uint256[] memory claimIds = payer.getPendingClaimIdsFor(BOB);
        for (uint256 i = 0; i < claimIds.length; i++) {
            // console.log("claimIds[i]", claimIds[i]);
            if (claimIds[i] == 0) continue;
            payer.claimByID(claimIds[i]);
        }
        vm.stopPrank();
        vm.startPrank(MARY);
        uint256[] memory claimIds2 = payer.getPendingClaimIdsFor(MARY);
        for (uint256 i = 0; i < claimIds2.length; i++) {
            // console.log("claimIds2[i]", claimIds2[i]);
            if (claimIds2[i] == 0) continue;
            payer.claimByID(claimIds2[i]);
        }
        vm.stopPrank();

        PaymentInfo4 memory pi2 = payer.getPaymentInfo4(paymentId);
        assertEq(pi2.left, 0); //only bob has claimed. Mary did not.
        assertEq(pi2.paymentBatchId, 1);
        assertEq(pi2.id, 1);
        assertEq(pi2.blockNumber, block.number);
        assertEq(pi2.totalAmount, 100e6);
        assertEq(pi2.currency, USDC_ADDRESS);
        assertEq(pi2.blueprint, newSongAddress);
        assertEq(pi2.royaltyToken, song.royaltyPortionTokens()[0]);
        assertEq(pi2.paid, true); //only if fee is 0
        assertEq(pi2.payer, address(this));
        assertEq(pi2.fee, 1e7);
        assertEq(pi2.memo, "test");

        //TODO:
        //1. check it throws on second try if already paid
        //2. Check that parent payment id is set to paid once all claims were gotten
    }

    function test_claimById_4_withCustomFee() external {
        FeeDistributorV4 payer = FeeDistributorV4(addressManager.getFeeDistributor());
        assertFalse(payer.userHasCustomProtocolFee(SAM));
        assertFalse(payer.userHasCustomProtocolFee(BOB));
        assertEq(payer.getProtocolFeeForUser(BOB), 1e4);
        assertFalse(payer.userHasCustomProtocolFee(MARY));
        assertEq(payer.getProtocolFeeForUser(MARY), 1e4);

        vm.prank(DEPLOYER);
        payer.setProtocolFeeForUser(0, BOB); //0 fees for BOB's store sales, yay!

        assertTrue(payer.userHasCustomProtocolFee(BOB));
        assertEq(payer.getProtocolFeeForUser(BOB), 0);

        assertFalse(payer.userHasCustomProtocolFee(MARY));
        assertEq(payer.getProtocolFeeForUser(MARY), 1e4);
        vm.prank(BOB);
        address newSongAddress = mintSongBlueprintAs(); //will be minted under BOB's registry/store
        vm.label(newSongAddress, "newSongAddress");

        _fundAndApproveUSDC(address(this), address(payer), 100e6, 100e6);

        vm.startPrank(address(registry));
        uint256 paymentId = payer.pay(
            FeeInfo({
                minAmount: 100e18,
                blueprint: newSongAddress,
                currency: USDC_ADDRESS,
                amount: 100e6,
                onBehalfOf: address(this),
                memo: "test"
            }),
            newSongAddress
        );
        vm.stopPrank();
        assertEq(paymentId, 1);

        uint256[] memory pending2 = payer.getPendingClaimIdsFor(BOB);
        uint256[] memory allClaims2 = payer.getAllClaimIdsFor(BOB);
        assertEq(pending2.length, 2);
        assertEq(allClaims2.length, 2);

        vm.startPrank(BOB);
        uint256[] memory claimIds = payer.getPendingClaimIdsFor(BOB);
        for (uint256 i = 0; i < claimIds.length; i++) {
            // console.log("claimIds[i]", claimIds[i]);
            if (claimIds[i] == 0) continue;
            payer.claimByID(claimIds[i]);
        }
        vm.stopPrank();
        vm.startPrank(MARY);
        uint256[] memory claimIds2 = payer.getPendingClaimIdsFor(MARY);
        for (uint256 i = 0; i < claimIds2.length; i++) {
            // console.log("claimIds2[i]", claimIds2[i]);
            if (claimIds2[i] == 0) continue;
            payer.claimByID(claimIds2[i]);
        }
        vm.stopPrank();

        // assertEq(payer.getProtocolFee(), 1e4);
        assertEq(usdc.balanceOf(address(BOB)), 25e6);
        assertEq(usdc.balanceOf(address(MARY)), 75e6);
        assertEq(usdc.balanceOf(address(feeDistributor)), 0);
        PaymentInfo4 memory pi2 = payer.getPaymentInfo4(paymentId);
        assertEq(pi2.left, 0); //only bob has claimed. Mary did not.
        assertEq(pi2.totalAmount, 100e6);
        assertEq(pi2.paid, true); //only if fee is 0
        assertEq(pi2.payer, address(this));
        assertEq(pi2.fee, 0);
        assertEq(pi2.memo, "test");
    }

    function test_getPaymentBatchInfo_afterClaims_ShowsAsPaid() external {
        vm.prank(BOB);
        address newSongAddress = mintSongBlueprintAs();
        vm.label(newSongAddress, "NEW-SONG-ADDRESS");

        FeeDistributorV4 payer = FeeDistributorV4(addressManager.getFeeDistributor());
        _fundAndApproveUSDC(address(this), address(payer), 100e6, 100e6);

        vm.startPrank(address(registry));
        uint256 batchID = payer.pay(
            FeeInfo({
                minAmount: 100e18,
                blueprint: newSongAddress,
                currency: USDC_ADDRESS,
                amount: 100e6,
                onBehalfOf: address(this),
                memo: "test"
            }),
            newSongAddress
        );
        vm.stopPrank();
        assertEq(batchID, 1);

        PaymentBatchInfo memory batchInfo = payer.getPaymentBatch(batchID);
        assertEq(batchInfo.id, 1);
        assertEq(batchInfo.left, 90e6); //after the fee
        assertEq(batchInfo.paid, false);

        //claim all:
        vm.startPrank(BOB);
        uint256[] memory claimIds = payer.getPendingClaimIdsFor(BOB);
        for (uint256 i = 0; i < claimIds.length; i++) {
            // console.log("claimIds[i]", claimIds[i]);
            if (claimIds[i] == 0) continue;
            payer.claimByID(claimIds[i]);
        }
        vm.stopPrank();
        //CHECK BATCH MID WAY IN PAYMENT
        PaymentBatchInfo memory batchInfo3 = payer.getPaymentBatch(batchID);
        assertEq(batchInfo3.id, 1);
        assertEq(batchInfo3.left, 675e5); //after paying bob, this is what is left for mary
        assertEq(batchInfo3.paid, false);

        vm.startPrank(MARY);
        uint256[] memory claimIds2 = payer.getPendingClaimIdsFor(MARY);
        for (uint256 i = 0; i < claimIds2.length; i++) {
            // console.log("claimIds2[i]", claimIds2[i]);
            if (claimIds2[i] == 0) continue;
            payer.claimByID(claimIds2[i]);
        }
        vm.stopPrank();

        PaymentBatchInfo memory batchInfo2 = payer.getPaymentBatch(batchID);
        assertEq(batchInfo2.id, 1);
        assertEq(batchInfo2.left, 0);
        assertEq(batchInfo2.paid, true);
    }

    function test_externalPayWithAddedPayer_NoErrorWithBatchId() external {
        vm.prank(BOB);
        registry.addPayer(MARY);
        _fundAndApproveUSDC(MARY, address(feeDistributor), 100e6, 100e6);
        vm.prank(BOB);
        address newSongAddress = mintSongBlueprintAs();
        vm.label(newSongAddress, "NEW-SONG-ADDRESS");

        vm.prank(MARY);
        uint256 batchId = registry.externalPayment(
            ExternalPaymentRequest({
                payer: MARY,
                target: newSongAddress,
                currency: USDC_ADDRESS,
                amount: 100e6,
                memo: "testExternal"
            })
        );

        FeeDistributorV4 payer = FeeDistributorV4(addressManager.getFeeDistributor());
        PaymentBatchInfo memory batchInfo = payer.getPaymentBatch(batchId);
        assertEq(batchInfo.id, 1);
        assertEq(batchInfo.blockNumber, block.number);
        assertEq(batchInfo.memo, "testExternal");
        assertEq(batchInfo.totalAmount, 100e6);
        assertEq(batchInfo.fee, 10e6);
        assertEq(batchInfo.left, 90e6);
        assertEq(batchInfo.paid, false);
        assertEq(batchInfo.registry, address(registry));
        assertEq(batchInfo.currency, USDC_ADDRESS);
        assertEq(batchInfo.target, newSongAddress);
        assertEq(batchInfo.payer, MARY);

        PaymentInfo4[] memory subPayments = payer.getSubPaymentInfosByPaymentBatchId(batchId);
        assertEq(subPayments.length, 2); //bob and mary
        assertEq(subPayments[0].id, 1);
        assertEq(subPayments[0].blockNumber, block.number);
        assertEq(subPayments[0].blueprint, newSongAddress);
        assertEq(subPayments[0].paid, false); //only if fee is 0
        assertEq(subPayments[0].left, 45e6);
        assertEq(subPayments[0].fee, 1e7);
        assertEq(subPayments[0].memo, "testExternal");
        assertEq(subPayments[0].totalAmount, 100e6);
        assertEq(subPayments[0].currency, USDC_ADDRESS);
        assertEq(subPayments[0].payer, MARY);
        assertEq(subPayments[0].royaltyToken, BlueprintV2(newSongAddress).royaltyPortionTokens()[0]);

        assertEq(subPayments[1].id, 2);
        assertEq(subPayments[1].blockNumber, block.number);
        assertEq(subPayments[1].totalAmount, 100e6);
        assertEq(subPayments[1].currency, USDC_ADDRESS);
        assertEq(subPayments[1].blueprint, newSongAddress);
        assertEq(subPayments[1].royaltyToken, BlueprintV2(newSongAddress).royaltyPortionTokens()[1]);
        assertEq(subPayments[1].paid, false); //only if fee is 0
        assertEq(subPayments[1].left, 45e6);
        assertEq(subPayments[1].payer, MARY);
        assertEq(subPayments[1].fee, 1e7);
        assertEq(subPayments[1].memo, "testExternal");
    }

    function test_getPaymentBatchInfo_WorksAfterPayment() external {
        vm.prank(BOB);
        address newSongAddress = mintSongBlueprintAs();
        vm.label(newSongAddress, "NEW-SONG-ADDRESS");

        FeeDistributorV4 payer = FeeDistributorV4(addressManager.getFeeDistributor());
        _fundAndApproveUSDC(address(this), address(payer), 100e6, 100e6);

        vm.startPrank(address(registry));
        uint256 paymentId = payer.pay(
            FeeInfo({
                minAmount: 100e18,
                blueprint: newSongAddress,
                currency: USDC_ADDRESS,
                amount: 100e6,
                onBehalfOf: address(this),
                memo: "test"
            }),
            newSongAddress
        );
        vm.stopPrank();
        assertEq(paymentId, 1);

        PaymentInfo4 memory subPaymentInfo = payer.getPaymentInfo4(paymentId);
        assertEq(subPaymentInfo.id, 1);

        PaymentBatchInfo memory batchInfo = payer.getPaymentBatch(subPaymentInfo.paymentBatchId);
        assertEq(batchInfo.id, 1);
        assertEq(batchInfo.blockNumber, block.number);
        assertEq(batchInfo.registry, address(registry));
        assertEq(batchInfo.target, newSongAddress);
        assertEq(batchInfo.payer, address(this));
        assertEq(batchInfo.currency, USDC_ADDRESS);
        assertEq(batchInfo.memo, "test");
        assertEq(batchInfo.totalAmount, 100e6);
        assertEq(batchInfo.fee, 10e6);
        assertEq(batchInfo.left, 90e6);
        assertEq(batchInfo.paid, false);

        PaymentInfo4[] memory subPayments = payer.getSubPaymentInfosByPaymentBatchId(subPaymentInfo.paymentBatchId);
        assertEq(subPayments.length, 2); //bob and mary
        assertEq(subPayments[0].id, 1);
        assertEq(subPayments[0].blockNumber, block.number);
        assertEq(subPayments[0].totalAmount, 100e6);
        assertEq(subPayments[0].currency, USDC_ADDRESS);
        assertEq(subPayments[0].blueprint, newSongAddress);
        assertEq(subPayments[0].royaltyToken, BlueprintV2(newSongAddress).royaltyPortionTokens()[0]);
        assertEq(subPayments[0].paid, false); //only if fee is 0
        assertEq(subPayments[0].left, 45e6);
        assertEq(subPayments[0].payer, address(this));
        assertEq(subPayments[0].fee, 1e7);
        assertEq(subPayments[0].memo, "test");

        assertEq(subPayments[1].id, 2);
        assertEq(subPayments[1].blockNumber, block.number);
        assertEq(subPayments[1].totalAmount, 100e6);
        assertEq(subPayments[1].currency, USDC_ADDRESS);
        assertEq(subPayments[1].blueprint, newSongAddress);
        assertEq(subPayments[1].royaltyToken, BlueprintV2(newSongAddress).royaltyPortionTokens()[1]);
        assertEq(subPayments[1].paid, false); //only if fee is 0
        assertEq(subPayments[1].left, 45e6);
        assertEq(subPayments[1].payer, address(this));
        assertEq(subPayments[1].fee, 1e7);
        assertEq(subPayments[1].memo, "test");
    }
}
