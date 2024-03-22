// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.7;

import "./util/HelperContract.sol";
import "contracts/registries/IRegistryV2.sol";
import "contracts/interfaces/BlanketStructs.sol";

contract RegistryV2_Test is HelperContract {
    event NewStoreToken(address tokenAddress, address registry);
    event NewIP(address songAddress, string shortName, string symbol, address registry);
    event RegistryDetached(address indexed registry);
    event OwnerUpdated(address indexed newOwner);
    event StatusUpdated(StoreStatus status);
    event StoreOwnershipTransferred(address indexed _registry, address indexed ownerOut, address indexed ownerIn);
    event RegistryDelisted(address indexed _registry);

    // IRegistryV2 public registry;

    function setUp() public {
        // registry = IRegistryV2(rootRegistry.mintRegistryFor(BOB, "Test registry"));
        allow100StoresForDefaultAccounts();
    }

    function test_mintStoreTokenFirstTime_ok() public {
        RoyaltyTokenData memory token;

        token.kind = "some generic type";
        token.name = "token name";
        token.symbol = "token symbol";
        token.memo = "memo";
        token.targets = new SplitTarget[](2);
        token.targets[0] = SplitTarget({holderAddress: BOB, amount: 25e18, memo: ""});
        token.targets[1] = SplitTarget({holderAddress: MARY, amount: 75e18, memo: ""});

        assertEq(registry.token(), address(0));
        vm.prank(BOB);
        registry.mintStoreToken(token);
        assertTrue(registry.token() != address(0));
    }

    function test_mintStoreTokenTwice_Reverts() public {
        RoyaltyTokenData memory token;

        token.kind = "some generic type";
        token.name = "token name";
        token.symbol = "token symbol";
        token.memo = "memo";
        token.targets = new SplitTarget[](2);
        token.targets[0] = SplitTarget({holderAddress: BOB, amount: 25e18, memo: ""});
        token.targets[1] = SplitTarget({holderAddress: MARY, amount: 75e18, memo: ""});

        vm.prank(BOB);
        registry.mintStoreToken(token);

        //second time
        vm.expectRevert("token already set");
        vm.prank(BOB);
        registry.mintStoreToken(token);
    }

    function test_mintStoreTokenByNonOwner_Reverts() public {
        RoyaltyTokenData memory token;

        vm.expectRevert("Not store owner or admin");
        vm.prank(MARY); //not owner, BOB is
        registry.mintStoreToken(token);
    }

    function test_withdrawOver0_admin_Revetrs() external {
        vm.prank(BOB);
        vm.expectRevert(bytes("ERC20: transfer amount exceeds balance"));
        registry.withdraw(address(usdc), BOB, 100);
    }

    function test_withdrawWithBalance_admin_ok() external {
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
        assertEq(usdc.balanceOf(address(registry)), 9e6);

        vm.prank(BOB);
        registry.withdraw(address(usdc), BOB, 9e6);
    }

    function test_externalPayment_WorksWithoutLicense() external {
        vm.prank(BOB);
        address songAddress = mintSongBlueprintAs();

        ExternalPaymentRequest memory REQ =
            ExternalPaymentRequest({payer: MARY, target: songAddress, currency: USDC_ADDRESS, amount: 10e6, memo: ""});
        _fundAndApproveUSDC(MARY, address(feeDistributor), 100e6, 100e6);
        //before
        assertEq(usdc.balanceOf(MARY), 100e6);
        uint256[] memory claims = feeDistributor.getPendingClaimIdsFor(BOB);
        assertEq(claims.length, 0);

        vm.prank(BOB);
        registry.addPayer(MARY);
        vm.prank(MARY);
        uint256 paymentId = registry.externalPayment(REQ);

        //after
        assertEq(usdc.balanceOf(MARY), 90e6);
        assertEq(usdc.balanceOf(address(registry)), 0);
        uint256[] memory claimsAfter = feeDistributor.getPendingClaimIdsFor(BOB);
        assertEq(claimsAfter.length, 2); // BOB has two types of song tokesn from this song, sotwo claims

        vm.prank(BOB);
        feeDistributor.claimByID(claimsAfter[0]);

        FeeDistributorV4 fd4 = FeeDistributorV4(address(feeDistributor));
        PaymentInfo4 memory paymentInfo = fd4.getPaymentInfo4(paymentId);
        assertEq(paymentInfo.totalAmount, 10e6);
        assertEq(paymentInfo.currency, USDC_ADDRESS);
        assertEq(paymentInfo.blueprint, songAddress);
        assertEq(paymentInfo.royaltyToken, IIPRepresentation(songAddress).royaltyPortionTokens()[0]);
        assertEq(paymentInfo.left, 3375000);
        assertEq(paymentInfo.paid, false);

        assertEq(usdc.balanceOf(BOB), 1.125e6); //after first claim

        vm.prank(BOB);
        feeDistributor.claimByID(claimsAfter[1]);
        assertEq(usdc.balanceOf(BOB), 2.25e6); //after second claim
    }

    function test_deactivateSongDirectly_markedCorrectly() external {
        vm.prank(BOB);
        address songAddress = mintSongBlueprintAs();
        assertEq(registry.getIpCount(), 1);
        BlueprintV3 song = BlueprintV3(songAddress);

        assertTrue(song.activated());
        vm.prank(MARY);
        vm.expectRevert();
        song.setActive(false);

        vm.prank(BOB);
        vm.expectRevert();
        song.setActive(false);

        vm.prank(address(registry));
        song.setActive(false);
        assertFalse(song.activated());
    }

    function test_getInActiveIps_IgnoresActivated() external {
        vm.prank(BOB);
        address songAddress = mintSongBlueprintAs();
        assertEq(registry.getIpCount(), 1);
        assertEq(registry.getAllIps().length, 1);
        assertEq(registry.getInactiveIps().length, 0);

        vm.prank(BOB);
        registry.setIpStatus(songAddress, false);

        assertEq(registry.getIpCount(), 1);
        assertEq(registry.getAllIps().length, 1);
        assertEq(registry.getActiveIps().length, 0);

        assertEq(registry.getInactiveIps().length, 1);
    }

    function test_getActiveIps_IgnoresDeactivated() external {
        vm.prank(BOB);
        address songAddress = mintSongBlueprintAs();
        assertEq(registry.getIpCount(), 1);
        assertEq(registry.getAllIps().length, 1);
        assertEq(registry.getActiveIps().length, 1);

        vm.prank(BOB);
        registry.setIpStatus(songAddress, false);

        assertEq(registry.getIpCount(), 1);
        assertEq(registry.getAllIps().length, 1);
        assertEq(registry.getInactiveIps().length, 1);

        assertEq(registry.getActiveIps().length, 0);
    }

    function test_deactivateSongByStore_markedCorrectly() external {
        vm.prank(BOB);
        address songAddress = mintSongBlueprintAs();
        assertEq(registry.getIpCount(), 1);
        BlueprintV3 song = BlueprintV3(songAddress);

        assertTrue(song.activated());
        vm.prank(BOB);
        RegistryImplV3(address(registry)).setIpStatus(songAddress, false);
        assertFalse(song.activated());
    }

    function test_deactivatedSong_cannotMintLicense() external {
        vm.prank(BOB);
        address songAddress = mintSongBlueprintAs();
        BlueprintV3 song = BlueprintV3(songAddress);

        vm.prank(BOB);
        RegistryImplV3(address(registry)).setIpStatus(songAddress, false);
        assertFalse(song.activated());

        _fundAndApproveUSDC(BOB, address(feeDistributor), 100e6, 100e6);
        vm.prank(BOB);
        vm.expectRevert();
        registry.mintLicense(
            MintLicenseRequest({
                optInId: 1,
                licenseBlueprintId: 1,
                to: MARY,
                target: songAddress,
                currency: USDC_ADDRESS,
                amount: 10e6,
                buyerFields: new LicenseField[](0),
                encryptedBuyerInfo: "",
                memo: ""
            })
        );
    }

    function test_deactivatedSong_cannotDoExternalPayment() external {
        vm.prank(BOB);
        address songAddress = mintSongBlueprintAs();
        BlueprintV3 song = BlueprintV3(songAddress);

        vm.prank(BOB);
        RegistryImplV3(address(registry)).setIpStatus(songAddress, false);
        assertFalse(song.activated());

        _fundAndApproveUSDC(BOB, address(feeDistributor), 100e6, 100e6);
        vm.prank(BOB);
        vm.expectRevert();
        registry.externalPayment(
            ExternalPaymentRequest({payer: BOB, target: songAddress, currency: USDC_ADDRESS, amount: 10e6, memo: ""})
        );

        // with activated should work
        vm.prank(BOB);
        RegistryImplV3(address(registry)).setIpStatus(songAddress, true);
        assertTrue(song.activated());

        vm.prank(BOB);
        registry.externalPayment(
            ExternalPaymentRequest({payer: BOB, target: songAddress, currency: USDC_ADDRESS, amount: 10e6, memo: ""})
        );
    }

    function test_deactivatedStore_CannotDoexternalPayment() external {
        vm.prank(BOB);
        address songAddress = mintSongBlueprintAs();

        vm.prank(BOB);
        // convert to uint
        uint8 INACTIVE = uint8(StoreStatus.INACTIVE);
        RegistryImplV3(address(registry)).updateStoreStatus(INACTIVE);

        _fundAndApproveUSDC(BOB, address(feeDistributor), 100e6, 100e6);
        vm.prank(BOB);
        vm.expectRevert();
        registry.externalPayment(
            ExternalPaymentRequest({payer: BOB, target: songAddress, currency: USDC_ADDRESS, amount: 10e6, memo: ""})
        );
    }

    function test_disabled_defaultsToFalse() external {
        assertEq(registry.isDisabled(), false);
    }

    function test_disabled_setToTrue_returnsTrue() external {
        vm.prank(BOB);
        registry.setDisabled(true);
        assertEq(registry.isDisabled(), true);
    }

    function test_disabled_setToFalse_returnsFalse() external {
        vm.startPrank(BOB);
        registry.setDisabled(true);
        assertEq(registry.isDisabled(), true);

        registry.setDisabled(false);
        assertEq(registry.isDisabled(), false);
        vm.stopPrank();
    }

    function test_withdraw0_adminWithoutBalance_OK() external {
        vm.prank(BOB);
        registry.withdraw(address(usdc), BOB, 0);
    }

    function test_withdraw_notOwner_reverts() external {
        vm.expectRevert("Not store owner or admin");
        registry.withdraw(address(usdc), BOB, 0);
    }

    function test_externalPay_notPayer_reverts() external {
        vm.expectRevert("Not store payer");
        vm.prank(SAM);
        registry.externalPayment(
            ExternalPaymentRequest({
                payer: MARY,
                target: address(registry),
                currency: USDC_ADDRESS,
                amount: 10e6,
                memo: ""
            })
        );
    }

    function test_externalPayWithAddedPayer_NoError() external {
        vm.prank(BOB);
        registry.addPayer(MARY);
        _fundAndApproveUSDC(MARY, address(feeDistributor), 100e6, 100e6);

        vm.prank(MARY);
        registry.externalPayment(
            ExternalPaymentRequest({
                payer: MARY,
                target: address(registry),
                currency: USDC_ADDRESS,
                amount: 10e6,
                memo: ""
            })
        );
    }

    function test_externalPayerWithWrongPayerParameter_Reverts() external {
        vm.prank(BOB);
        registry.addPayer(MARY);

        _fundAndApproveUSDC(SAM, address(feeDistributor), 100e6, 100e6);

        vm.expectRevert("req.payer not a payer");
        vm.prank(MARY);
        registry.externalPayment(
            ExternalPaymentRequest({
                payer: SAM,
                target: address(registry),
                currency: USDC_ADDRESS,
                amount: 10e6,
                memo: ""
            })
        );
    }

    function test_externalPayCalledByAllowedWalletOnBahalfOfOtherAllowedWallet_NoError() external {
        vm.startPrank(BOB);
        registry.addPayer(MARY);
        registry.addPayer(SAM);
        vm.stopPrank();

        _fundAndApproveUSDC(SAM, address(feeDistributor), 100e6, 100e6);

        vm.prank(MARY);
        registry.externalPayment(
            ExternalPaymentRequest({
                payer: SAM,
                target: address(registry),
                currency: USDC_ADDRESS,
                amount: 10e6,
                memo: ""
            })
        );
    }

    function test_mintSongv2_1token() external {
        vm.prank(BOB);
        address newSongAddress = mintSongBlueprintAs();
        IIPRepresentation song = IIPRepresentation(newSongAddress);
        assertEq(song.kind(), "song");
        assertEq(song.ledger(), address(registry));
        assertEq(song.metadataURI(), "meta");

        BaseIPPortionToken token1 = BaseIPPortionToken(song.royaltyPortionTokens()[0]);
        assertEq(token1.getHolders().length, 3);
        assertEq(token1.getHolders()[0].amount, 0);
        assertEq(token1.getHolders()[1].amount, 25e18);
        assertEq(token1.getHolders()[2].amount, 75e18);
        assertEq(token1.balanceOf(BOB), 25 ether);
        assertEq(token1.balanceOf(MARY), 75 ether);
        assertEq(token1.balanceOf(address(registry)), 0);
        assertEq(token1.balanceOf(SAM), 0);
    }

    function test_mintSongWithLicense_getNftLicense_v3() external {
        vm.prank(BOB);
        address songAddress = mintSongBlueprintAs();

        assertEq(registry.getAllIps().length, 1);
        assertEq(registry.getAllIps()[0], songAddress);
        assertEq(registry.getIpCount(), 1);
        string[] memory bpfields = new string[](2);
        bpfields[0] = "licensee";
        bpfields[1] = "licensor";
        uint256 id = addFakeNonActiveLicense();
        licenseRegistry.setActive(id, true);

        LicenseField[] memory sellerFields = new LicenseField[](2);
        sellerFields[0] = LicenseField({id: 1, name: "licensor", val: "sam", dataType: "string", info: "Licensor name"});
        sellerFields[1] =
            LicenseField({id: 2, name: "address", val: "mary", dataType: "address", info: "seller address"});

        vm.prank(BOB);
        registry.optIntoLicense(LicenseScope.SINGLE, id, USDC_ADDRESS, 10e6, "test license", sellerFields, ""); // min 10USDC

        _fundAndApproveUSDC(MARY, address(feeDistributor), 100e6, 100e6);

        LicenseField[] memory buyerFields = getFieldsAsMemory(BUYER_FIELDS);
        buyerFields[0].val = "bob";
        buyerFields[1].val = "mary";
        //seller

        vm.prank(MARY);
        uint256 licenseId = registry.mintLicense(
            MintLicenseRequest({
                optInId: 1,
                licenseBlueprintId: id,
                to: MARY,
                target: songAddress,
                currency: USDC_ADDRESS,
                amount: 10e6,
                buyerFields: buyerFields,
                encryptedBuyerInfo: "",
                memo: ""
            })
        );

        PurchasedLicenseV3 memory licenseInfo = legatoLicenseV3.getLicenseInfo(licenseId);

        assertEq(licenseInfo.auto_minter, MARY);
        assertEq(licenseInfo.auto_blockNumber, block.number);
        assertEq(licenseInfo.auto_timestamp, block.timestamp);
        assertEq(licenseInfo.auto_chainId, block.chainid);
        assertEq(licenseInfo.auto_tokenId, licenseId);

        LicenseField[] memory seller = legatoLicenseV3.getLicenseFieldsSeller(licenseId);
        assertEq(seller.length, 2);
        LicenseField[] memory buyer = legatoLicenseV3.getLicenseFieldsBuyer(licenseId);
        assertEq(buyer.length, 2);
        LicenseField[] memory autoFields = legatoLicenseV3.getLicenseFieldsAuto(licenseId);
        assertEq(autoFields.length, 0);
        //check usdc balance in registry
    }

    function test_mintSongv2_2tokens() external {
        BlueprintMintingParams memory bmp = BlueprintMintingParams({
            shortName: "abc",
            fileHash: "",
            symbol: "SONG",
            metadataURI: "meta",
            kind: "song",
            tokens: new RoyaltyTokenData[](2)
        });

        bmp.tokens[0].kind = "some generic type";
        bmp.tokens[0].name = "token name";
        bmp.tokens[0].symbol = "token symbol";
        bmp.tokens[0].memo = "memo";
        bmp.tokens[0].targets = new SplitTarget[](2);
        bmp.tokens[0].targets[0] = SplitTarget({holderAddress: BOB, amount: 25e18, memo: ""});
        bmp.tokens[0].targets[1] = SplitTarget({holderAddress: MARY, amount: 75e18, memo: ""});
        bmp.tokens[1].kind = "some generic type 2";
        bmp.tokens[1].name = "token name 2";
        bmp.tokens[1].symbol = "token symbol 2";
        bmp.tokens[1].memo = "memo 2";
        bmp.tokens[1].targets = new SplitTarget[](2);
        bmp.tokens[1].targets[0] = SplitTarget({holderAddress: BOB, amount: 30e18, memo: ""});
        bmp.tokens[1].targets[1] = SplitTarget({holderAddress: MARY, amount: 70e18, memo: ""});

        vm.prank(BOB);
        registry.mintIP(bmp);
    }

    function test_mintSongv2_CheckLicenseNFT() external {
        BlueprintMintingParams memory bmp = BlueprintMintingParams({
            shortName: "abc",
            fileHash: "",
            symbol: "SONG",
            metadataURI: "meta",
            kind: "song",
            tokens: new RoyaltyTokenData[](2)
        });

        bmp.tokens[0].kind = "some generic type";
        bmp.tokens[0].name = "token name";
        bmp.tokens[0].symbol = "token symbol";
        bmp.tokens[0].memo = "memo";
        bmp.tokens[0].targets = new SplitTarget[](2);
        bmp.tokens[0].targets[0] = SplitTarget({holderAddress: BOB, amount: 25e18, memo: ""});
        bmp.tokens[0].targets[1] = SplitTarget({holderAddress: MARY, amount: 75e18, memo: ""});
        bmp.tokens[1].kind = "some generic type 2";
        bmp.tokens[1].name = "token name 2";
        bmp.tokens[1].symbol = "token symbol 2";
        bmp.tokens[1].memo = "memo 2";
        bmp.tokens[1].targets = new SplitTarget[](2);
        bmp.tokens[1].targets[0] = SplitTarget({holderAddress: BOB, amount: 30e18, memo: ""});
        bmp.tokens[1].targets[1] = SplitTarget({holderAddress: MARY, amount: 70e18, memo: ""});

        vm.prank(BOB);
        registry.mintIP(bmp);
    }

    /// detachStore()

    function test_storeSettings() public {
        address newStoreAddress = rootRegistry.mintRegistryFor(BOB, "Test registry", false);
        IRegistryV2 newStore = IRegistryV2(newStoreAddress);
        assertEq(newStore.getOwnerWallet(), BOB);
        assertEq(newStore.getSettingsUri(), "");
        vm.startPrank(BOB);
        newStore.setSettingsUri("new settings");
        vm.stopPrank();
        assertEq(newStore.getSettingsUri(), "new settings");
    }

    function test_detachStoreNotLast() public {
        /// create dummy stores after the tested store
        address reg1 = rootRegistry.mintRegistryFor(BOB, "Dummy registry 1", false);
        vm.label(reg1, "reg1");
        address reg2 = rootRegistry.mintRegistryFor(BOB, "Dummy registry 1", false);
        vm.label(reg2, "reg2");
        uint256 countAll = rootRegistry.getAllRegistries().length;
        address[] memory registriesForWalletBefore = rootRegistry.getRegistriesByWallet(BOB);
        address lastRegistryAddress = rootRegistry.getAllRegistries()[countAll - 1];
        vm.label(address(registry), "registry");
        uint256 storeIndexBefore = countAll - 1;

        vm.expectEmit(true, false, false, true);
        emit RegistryDelisted(address(registry));
        vm.prank(BOB);
        registry.detachStore();

        address[] memory registriesForWalletAfter = rootRegistry.getRegistriesByWallet(BOB);

        assertEq(rootRegistry.getAllRegistries().length, countAll - 1);
        assertEq(rootRegistry.getAllRegistries()[storeIndexBefore - 1], lastRegistryAddress);
        assertEq(registriesForWalletBefore.length, registriesForWalletAfter.length + 1);

        assertFalse(rootRegistry._data_getIsRegistry(address(registry)));
        assertEq(registry.ownerWallet(), address(0));
    }

    function test_detachStoreLast() public {
        /// This test checks the use case of when the store is the last store registered
        uint256 count = rootRegistry.getRegistryCount();
        address[] memory registriesForWalletBefore = rootRegistry.getRegistriesByWallet(BOB);
        rootRegistry.getAllRegistries()[count - 1];

        vm.expectEmit(true, false, false, true);
        emit RegistryDelisted(address(registry));
        vm.prank(BOB);
        registry.detachStore();

        address[] memory registriesForWalletAfter = rootRegistry.getRegistriesByWallet(BOB);

        assertEq(rootRegistry.getAllRegistries().length, count - 1);
        assertFalse(rootRegistry._data_getIsRegistry(address(registry)));
        assertEq(registry.ownerWallet(), address(0));
        assertEq(registriesForWalletBefore.length, registriesForWalletAfter.length + 1);
    }

    function testCannotDetachStoreNotAuthorized() public {
        vm.expectRevert("Not store owner or admin");
        vm.prank(MARY);
        registry.detachStore();
    }

    /// updateOwnerWallet()

    function testUpdateOwnerWallet_newOwnerCanChangeStoreStatus() public {
        address currentOwner = registry.ownerWallet();
        uint256 bobRegistriesBefore = (rootRegistry.getRegistriesByWallet(BOB)).length;
        uint256 maryRegistriesBefore = (rootRegistry.getRegistriesByWallet(MARY)).length;

        vm.expectEmit(true, true, true, true);
        emit StoreOwnershipTransferred(address(registry), BOB, MARY);
        vm.prank(BOB);
        registry.updateOwnerWallet(MARY);

        vm.prank(MARY);
        registry.updateStoreStatus(uint8(StoreStatus.INACTIVE));

        uint256 bobRegistriesAfter = (rootRegistry.getRegistriesByWallet(BOB)).length;
        uint256 maryRegistriesAfter = (rootRegistry.getRegistriesByWallet(MARY)).length;

        assertEq(registry.ownerWallet(), MARY);
        assertFalse(currentOwner != BOB);
        assertEq(bobRegistriesBefore, bobRegistriesAfter + 1);
        assertEq(maryRegistriesBefore, maryRegistriesAfter - 1);
        assertEq(registry.ownerWallet(), MARY);
    }

    function test_UpdateOwnerWallet_WithNonZero_Works() public {
        address currentOwner = registry.ownerWallet();
        address currentStore = address(registry);

        vm.prank(currentStore);
        rootRegistry.transferStoreOwnership(currentStore, currentOwner, MARY);
    }

    function test_UpdateOwnerWallet_WithZeroAddress_Fails() public {
        address currentOwner = registry.ownerWallet();
        address currentStore = address(registry);

        vm.expectRevert();
        vm.prank(currentStore);
        rootRegistry.transferStoreOwnership(currentStore, currentOwner, address(0));
    }

    function test_UpdateOwnerWallet_directlyOnRootReg_AllowedOnlyByStore() public {
        address currentOwner = registry.ownerWallet();
        address currentStore = address(registry);

        vm.expectRevert();
        rootRegistry.transferStoreOwnership(currentStore, currentOwner, MARY);
    }

    function testCannotUpdateOwnerWalletUnauthorized() public {
        vm.expectRevert("Not store owner or admin");
        vm.prank(MARY);
        registry.updateOwnerWallet(MARY);
    }

    function testCannotUpdateOwnerWalletZeroAddress() public {
        vm.expectRevert("Cannot set owner to 0");
        vm.prank(BOB);
        registry.updateOwnerWallet(address(0));
    }

    function test_asset_changeMetadataUri_byStore_isAllowed() public {
        vm.prank(BOB);
        address songAddress = mintSongBlueprintAs();
        vm.prank(BOB);
        registry.updateAssetMetadataUri(songAddress, "new uri", "new hash");
    }

    function test_asset_changeMetadataUri_directly_forbidden() public {
        vm.prank(BOB);
        address songAddress = mintSongBlueprintAs();

        vm.expectRevert();
        vm.prank(BOB); //even if they are the store owner
        IIPRepresentation(songAddress).changeMetadataURI("new uri", "new hash");

        vm.expectRevert();
        vm.prank(MARY);
        IIPRepresentation(songAddress).changeMetadataURI("new uri", "new hash");
    }

    /// updateStoreStatus()

    function testUpdateStoreStatus() public {
        vm.expectEmit(false, false, false, true);
        emit StatusUpdated(StoreStatus.INACTIVE);
        vm.prank(BOB);
        registry.updateStoreStatus(1);

        assertEq(uint8(registry.storeStatus()), 1);
    }

    function testCannotUpdatedStoreStatusNotAuthorized() public {
        vm.expectRevert("Not store owner or admin");
        vm.prank(MARY);
        registry.updateStoreStatus(1);
    }

    function testCannotUpdatedStoreStatusBadValue() public {
        vm.expectRevert("Invalid store status");
        vm.prank(BOB);
        registry.updateStoreStatus(4);
    }

    function test_storeWithAToken_TokenOwnersGetPaidAndExternalPayment() public {
        RoyaltyTokenData memory token;
        token.kind = "some generic type";
        token.name = "token name";
        token.symbol = "token symbol";
        token.memo = "memo";
        token.targets = new SplitTarget[](2);

        token.targets[0] = SplitTarget({holderAddress: BOB, amount: 25e18, memo: ""});
        token.targets[1] = SplitTarget({holderAddress: MARY, amount: 75e18, memo: ""});

        vm.prank(BOB);
        registry.mintStoreToken(token);

        _fundAndApproveUSDC(BOB, address(feeDistributor), 100e6, 100e6);
        vm.prank(BOB);
        registry.externalPayment(
            ExternalPaymentRequest({
                payer: BOB,
                target: address(registry),
                currency: USDC_ADDRESS,
                amount: 10e6,
                memo: ""
            })
        );

        //check claims for BOB and MARY
        uint256[] memory claims = feeDistributor.getPendingClaimIdsFor(BOB);
        assertEq(claims.length, 1);
        uint256[] memory claims2 = feeDistributor.getPendingClaimIdsFor(MARY);
        assertEq(claims2.length, 1);
    }

    function test_storeWithoutAToken_StoreOwnerGetsPayment() public {
        _fundAndApproveUSDC(BOB, address(feeDistributor), 100e6, 100e6);
        vm.prank(BOB);
        registry.externalPayment(
            ExternalPaymentRequest({
                payer: BOB,
                target: address(registry),
                currency: USDC_ADDRESS,
                amount: 10e6,
                memo: ""
            })
        );

        //check claims for BOB and MARY
        //check usdcbalance in store
        assertEq(usdc.balanceOf(address(registry)), 9e6);

        uint256[] memory claimsForStore = feeDistributor.getPendingClaimIdsFor(address(registry));
        assertEq(claimsForStore.length, 0);
        uint256[] memory claims = feeDistributor.getPendingClaimIdsFor(BOB);
        assertEq(claims.length, 0);
        uint256[] memory claims2 = feeDistributor.getPendingClaimIdsFor(MARY);
        assertEq(claims2.length, 0);
    }
}
