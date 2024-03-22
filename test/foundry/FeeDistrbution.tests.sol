// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.7;

import "forge-std/Test.sol";

import "contracts/interfaces/IFeeDistributor.sol";
import "./dummies/FakeToken.sol";
import "./util/HelperContract.sol";
import "contracts/interfaces/IRoyaltyPortionToken.sol";
import "contracts/eip5553/IIPRepresentation.sol";
import "contracts/interfaces/Structs.sol";
import "forge-std/console.sol";
import "openzeppelin-contracts/token/ERC20/IERC20.sol";

contract FeeDistributionTest is HelperContract {
    event ProtocolFeeUpdated(uint256 protocolFee);

    function test_freeLicense_TryingtoPay_Reverts() external {
        uint256[] memory pending1 = feeDistributor.getPendingClaimIdsFor(BOB);
        uint256[] memory allClaims = feeDistributor.getAllClaimIdsFor(BOB);
        assertEq(pending1.length, 0);
        assertEq(allClaims.length, 0);

        uint256 lic_id = addFakeLicenseBlueprint(licenseRegistry);

        vm.startPrank(BOB);
        address song = mintSongBlueprintAs();
        uint256 optinId =
            registry.optIntoLicense(LicenseScope.SINGLE, lic_id, address(usdc), 0, "FREE LICENSE", SELLER_FIELDS, "");
        vm.stopPrank();

        FeeDistributor payer = FeeDistributor(addressManager.getFeeDistributor());
        _fundAndApproveUSDC(MARY, address(payer), 100e6, 100e6);

        vm.startPrank(MARY);
        MintLicenseRequest memory MLR_REQ = MintLicenseRequest({
            optInId: optinId, //free license optin
            licenseBlueprintId: lic_id,
            to: MARY,
            target: song,
            currency: USDC_ADDRESS,
            amount: 1e6, //not allowed to pay for free license
            buyerFields: BUYER_FIELDS,
            encryptedBuyerInfo: "",
            memo: ""
        });

        vm.expectRevert();
        registry.mintLicense(MLR_REQ);

        vm.stopPrank();

        uint256[] memory pending2 = feeDistributor.getPendingClaimIdsFor(BOB);
        assertEq(pending2.length, 0);

        uint256[] memory allClaims2 = feeDistributor.getAllClaimIdsFor(BOB);
        assertEq(allClaims2.length, 0);
    }

    // test addCurrency
    function test_addCurrencyNotLegatoAdmin_Reverts() external {
        vm.expectRevert(); //access contorl
        vm.prank(BOB);
        feeDistributor.addCurrency(address(999));
    }

    function test_changeCurrencyStatusWithoutAddingFirst_reverts() external {
        vm.expectRevert("must add currency first");
        vm.prank(DEPLOYER);
        feeDistributor.changeCurrencyStatus(address(999), CurrencyStatus.ENABLED);
    }

    function test_addCurrencyByLegatoAdmin_ok() external {
        assertEq(feeDistributor.getAllowedCurrencies().length, 1);

        vm.prank(DEPLOYER);
        feeDistributor.addCurrency(address(999));

        assertEq(feeDistributor.getAllowedCurrencies().length, 2);
        address[] memory allowed = feeDistributor.getAllowedCurrencies();
        assertEq(allowed[0], address(usdc));
        assertEq(allowed[1], address(999));
    }

    function test_addCurrencyWhenPaused_Reverts() external {
        vm.prank(DEPLOYER);
        feeDistributor.pause();

        vm.expectRevert("Pausable: paused");
        vm.prank(DEPLOYER);
        feeDistributor.addCurrency(address(999));
    }

    function test_NonfreeLicensePurchase() external {
        uint256[] memory pending1 = feeDistributor.getPendingClaimIdsFor(BOB);
        uint256[] memory allClaims = feeDistributor.getAllClaimIdsFor(BOB);
        assertEq(pending1.length, 0);
        assertEq(allClaims.length, 0);

        uint256 lic_id = addFakeLicenseBlueprint(licenseRegistry);

        vm.startPrank(BOB);
        address song = mintSongBlueprintAs();
        uint256 optinId = registry.optIntoLicense(
            LicenseScope.SINGLE, lic_id, address(usdc), 1e18, "NON free license", SELLER_FIELDS, ""
        );
        vm.stopPrank();

        FeeDistributor payer = FeeDistributor(addressManager.getFeeDistributor());
        _fundAndApproveUSDC(MARY, address(payer), 10e18, 100e18);

        vm.startPrank(MARY);

        MintLicenseRequest memory MLR_REQ = MintLicenseRequest({
            optInId: optinId,
            licenseBlueprintId: lic_id,
            to: MARY,
            target: song,
            currency: USDC_ADDRESS,
            amount: 1e18,
            buyerFields: BUYER_FIELDS,
            encryptedBuyerInfo: "",
            memo: ""
        });

        // usdc.approve(address(registry),100e18);
        // FakeToken(address(usdc)).drip();
        registry.mintLicense(MLR_REQ);
        vm.stopPrank();

        uint256[] memory pending2 = feeDistributor.getPendingClaimIdsFor(BOB);
        assertEq(pending2.length, 2);

        uint256[] memory allClaims2 = feeDistributor.getAllClaimIdsFor(BOB);
        assertEq(allClaims2.length, 2);
    }

    function test_freeLicensePurchase() external {
        uint256[] memory pending1 = feeDistributor.getPendingClaimIdsFor(BOB);
        uint256[] memory allClaims = feeDistributor.getAllClaimIdsFor(BOB);
        assertEq(pending1.length, 0);
        assertEq(allClaims.length, 0);

        uint256 lic_id = addFakeLicenseBlueprint(licenseRegistry);

        vm.prank(BOB);
        address song = mintSongBlueprintAs();
        vm.startPrank(BOB);
        uint256 optinId =
            registry.optIntoLicense(LicenseScope.SINGLE, lic_id, address(usdc), 0, "free license", SELLER_FIELDS, "");
        vm.stopPrank();
        vm.startPrank(MARY);

        MintLicenseRequest memory MLR_REQ = MintLicenseRequest({
            optInId: optinId,
            licenseBlueprintId: lic_id,
            to: MARY,
            target: song,
            currency: USDC_ADDRESS,
            amount: 0, // free license
            buyerFields: BUYER_FIELDS,
            encryptedBuyerInfo: "",
            memo: ""
        });
        registry.mintLicense(MLR_REQ);

        vm.stopPrank();

        uint256[] memory pending2 = feeDistributor.getPendingClaimIdsFor(BOB);
        uint256[] memory allClaims2 = feeDistributor.getAllClaimIdsFor(BOB);
        assertEq(pending2.length, 0); //all paid since price was zero
        assertEq(allClaims2.length, 2);
    }

    function test_claimById_2() external {
        vm.prank(BOB);
        address newSongAddress = mintSongBlueprintAs();
        vm.label(newSongAddress, "newSongAddress");

        BlueprintV2 song = BlueprintV2(newSongAddress);

        FeeDistributor payer = FeeDistributor(addressManager.getFeeDistributor());
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

        //TODO:
        //1. check it throws on second try if already paid
        //2. Check that parent payment id is set to paid once all claims were gotten
    }

    function test_protocolFeeCollected() public {
        vm.prank(BOB);
        /// Bob - 25%
        /// Mary - 75%
        address newSongAddress = mintSongBlueprintAs();
        vm.label(newSongAddress, "newSongAddress");

        FeeDistributor payer = FeeDistributor(addressManager.getFeeDistributor());
        _fundAndApproveUSDC(address(this), address(payer), 100e6, 100e6);

        vm.prank(DEPLOYER);
        feeDistributor.setProtocolFee(10000); //10%
        assertEq(usdc.balanceOf(address(feeDistributor)), 0);

        vm.startPrank(address(registry));
        payer.pay(
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

        uint256[] memory bobPendingClaims = payer.getPendingClaimIdsFor(BOB);
        uint256[] memory maryPendingClaims = payer.getPendingClaimIdsFor(MARY);

        assertEq(bobPendingClaims.length, 2);
        assertEq(maryPendingClaims.length, 2);

        assertEq(usdc.balanceOf(address(feeDistributor)), 100e6);
        vm.startPrank(BOB);
        payer.claimByID(bobPendingClaims[0]);
        payer.claimByID(bobPendingClaims[1]);
        vm.stopPrank();

        vm.startPrank(MARY);
        payer.claimByID(maryPendingClaims[0]);
        payer.claimByID(maryPendingClaims[1]);
        vm.stopPrank();

        assertEq(usdc.balanceOf(address(feeDistributor)), 10e6);
    }

    function test_updateProtocolFee() public {
        uint256 newPf = 5000;
        /// 5%
        vm.expectEmit(true, false, false, true);
        emit ProtocolFeeUpdated(newPf);
        vm.prank(DEPLOYER);
        feeDistributor.setProtocolFee(newPf);

        assertEq(feeDistributor.getProtocolFee(), newPf);
    }

    function test_updateProtocolFeeOverQuote_Reverts() public {
        vm.prank(DEPLOYER);
        vm.expectRevert(bytes("Protocol fee cannot exceed 10%"));
        feeDistributor.setProtocolFee(20 * 1000);
    }

    function test_setFee_changesFee() external {
        uint256 storeLicenseId = addFakeBLANKET_STORELicenseBlueprint(licenseRegistry);

        // address songAddress = mintSongBlueprintAs();
        LicenseField[] memory sellerFields = new LicenseField[](2);
        sellerFields[0] = LicenseField({id: 1, name: "licensor", val: "sam", dataType: "string", info: "Licensor name"});
        sellerFields[1] =
            LicenseField({id: 2, name: "address", val: "mary", dataType: "address", info: "seller address"});

        vm.prank(BOB);
        registry.optIntoLicense(
            LicenseScope.STORE, storeLicenseId, USDC_ADDRESS, 10e6, "test license", sellerFields, ""
        ); // min 10USDC

        _fundAndApproveUSDC(MARY, address(feeDistributor), 100e6, 100e6);

        LicenseField[] memory buyerFields = getFieldsAsMemory(BUYER_FIELDS);
        buyerFields[0].val = "bob";
        buyerFields[1].val = "mary";
        //seller

        //check balance is 0
        vm.prank(DEPLOYER);
        feeDistributor.setProtocolFee(5 * 1000);
        assertEq(usdc.balanceOf(address(registry)), 0);
        vm.prank(MARY);
        registry.mintLicense(
            MintLicenseRequest({
                optInId: 1,
                licenseBlueprintId: storeLicenseId,
                to: MARY,
                target: address(registry),
                currency: USDC_ADDRESS,
                amount: 10e6,
                buyerFields: buyerFields,
                encryptedBuyerInfo: "",
                memo: ""
            })
        );
        assertEq(usdc.balanceOf(address(registry)), 9.5e6);
    }

    function test_WithrawFees_WhileThereAreClaimsToPay_DoesNotRug() public {
        vm.prank(BOB);
        address newSongAddress = mintSongBlueprintAs();
        vm.label(newSongAddress, "newSongAddress");

        FeeDistributor payer = FeeDistributor(addressManager.getFeeDistributor());
        _fundAndApproveUSDC(address(this), address(payer), 100e6, 100e6);

        vm.prank(DEPLOYER);

        assertEq(usdc.balanceOf(address(feeDistributor)), 0);

        vm.startPrank(address(registry));
        payer.pay(
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

        //this should work
        assertEq(usdc.balanceOf(address(feeDistributor)), 100e6);
        assertEq(feeDistributor.getFeesFor(USDC_ADDRESS), 10e6);

        vm.expectRevert("Insufficient fee balance for withdrawal");
        vm.prank(DEPLOYER);
        feeDistributor.withdrawFees(USDC_ADDRESS, address(DEPLOYER), 100e6);

        assertEq(usdc.balanceOf(address(feeDistributor)), 100e6);
        vm.prank(DEPLOYER);
        feeDistributor.withdrawFees(USDC_ADDRESS, address(SAM), 10e6);
        assertEq(usdc.balanceOf(SAM), 10e6);

        uint256[] memory bobPendingClaims = payer.getPendingClaimIdsFor(BOB);
        uint256[] memory maryPendingClaims = payer.getPendingClaimIdsFor(MARY);

        assertEq(bobPendingClaims.length, 2);
        assertEq(maryPendingClaims.length, 2);

        assertEq(usdc.balanceOf(address(feeDistributor)), 90e6);
        vm.startPrank(BOB);
        payer.claimByID(bobPendingClaims[0]);
        payer.claimByID(bobPendingClaims[1]);
        vm.stopPrank();

        vm.startPrank(MARY);
        payer.claimByID(maryPendingClaims[0]);
        payer.claimByID(maryPendingClaims[1]);
        vm.stopPrank();

        assertEq(usdc.balanceOf(address(feeDistributor)), 0);
    }

    function test_WithrawFees_AfterStorePaymentNoToken_WhileThereAreClaimsToPay_DoesNotRug() public {
        vm.prank(BOB);
        registry.addPayer(MARY);
        _fundAndApproveUSDC(MARY, address(feeDistributor), 100e6, 100e6);

        vm.prank(MARY);
        registry.externalPayment(
            ExternalPaymentRequest({
                payer: MARY,
                target: address(registry),
                currency: USDC_ADDRESS,
                amount: 50e6,
                memo: ""
            })
        );
        //this should work
        assertEq(usdc.balanceOf(address(registry)), 45e6);
        assertEq(usdc.balanceOf(address(feeDistributor)), 5e6);
        assertEq(feeDistributor.getFeesFor(USDC_ADDRESS), 5e6);

        vm.expectRevert("Insufficient fee balance for withdrawal");
        vm.prank(DEPLOYER);
        feeDistributor.withdrawFees(USDC_ADDRESS, address(DEPLOYER), 10e6);

        vm.prank(DEPLOYER);
        feeDistributor.withdrawFees(USDC_ADDRESS, address(SAM), 1e6);
        assertEq(usdc.balanceOf(address(feeDistributor)), 4e6);
        assertEq(feeDistributor.getFeesFor(USDC_ADDRESS), 4e6);
        assertEq(usdc.balanceOf(SAM), 1e6);

        vm.prank(DEPLOYER);
        feeDistributor.withdrawFees(USDC_ADDRESS, address(SAM), 4e6);
        assertEq(usdc.balanceOf(address(feeDistributor)), 0);
        assertEq(feeDistributor.getFeesFor(USDC_ADDRESS), 0);
        assertEq(usdc.balanceOf(SAM), 5e6);
    }

    function test_WithrawFees_AfterStorePaymentWithStoreToken_WhileThereAreClaimsToPay_DoesNotRug() public {
        RoyaltyTokenData memory token = RoyaltyTokenData({
            name: "test",
            symbol: "test",
            kind: "test",
            tokenAddress: address(0),
            memo: "",
            targets: new SplitTarget[](2)
        });
        token.targets[0] = SplitTarget({holderAddress: address(BOB), amount: 50e18, memo: ""});
        token.targets[1] = SplitTarget({holderAddress: address(SAM), amount: 50e18, memo: ""});

        vm.startPrank(BOB);
        registry.mintStoreToken(token);
        registry.addPayer(MARY);
        vm.stopPrank();

        _fundAndApproveUSDC(MARY, address(feeDistributor), 100e6, 100e6);
        vm.prank(MARY);
        registry.externalPayment(
            ExternalPaymentRequest({
                payer: MARY,
                target: address(registry),
                currency: USDC_ADDRESS,
                amount: 50e6,
                memo: ""
            })
        );
        //this should work
        assertEq(usdc.balanceOf(address(registry)), 0);
        assertEq(usdc.balanceOf(address(feeDistributor)), 50e6);
        assertEq(feeDistributor.getFeesFor(USDC_ADDRESS), 5e6);

        vm.expectRevert("Insufficient fee balance for withdrawal");
        vm.prank(DEPLOYER);
        feeDistributor.withdrawFees(USDC_ADDRESS, address(DEPLOYER), 10e6);

        vm.prank(DEPLOYER);
        feeDistributor.withdrawFees(USDC_ADDRESS, address(DEPLOYER), 1e6);
        assertEq(usdc.balanceOf(address(feeDistributor)), 49e6);
        assertEq(feeDistributor.getFeesFor(USDC_ADDRESS), 4e6);
        assertEq(usdc.balanceOf(DEPLOYER), 1e6);

        vm.prank(DEPLOYER);
        feeDistributor.withdrawFees(USDC_ADDRESS, address(DEPLOYER), 4e6);
        assertEq(usdc.balanceOf(address(feeDistributor)), 45e6);
        assertEq(feeDistributor.getFeesFor(USDC_ADDRESS), 0);
        assertEq(usdc.balanceOf(DEPLOYER), 5e6);

        //claims for sam
        uint256[] memory claimsForSam = feeDistributor.getPendingClaimIdsFor(SAM);
        assertEq(claimsForSam.length, 1);
        vm.prank(SAM);
        feeDistributor.claimByID(claimsForSam[0]);
        assertEq(usdc.balanceOf(address(feeDistributor)), 22.5e6);
        assertEq(usdc.balanceOf(SAM), 22.5e6);
    }
}
