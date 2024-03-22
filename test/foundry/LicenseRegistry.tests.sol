// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.7;

import "forge-std/Test.sol";

import "contracts/eip5553/IIPRepresentation.sol";
import "contracts/interfaces/ILicenseBlueprint.sol";
import "contracts/interfaces/IRoyaltyPortionToken.sol";
import "contracts/interfaces/Structs.sol";
import "./dummies/FakeToken.sol";
import "./util/HelperContract.sol";
import "contracts/dataBound/LicenseRegistry/LicenseRegistry.sol";
import "contracts/LicenseBlueprint.sol";
import "contracts/registries/RegistryImplV1.sol";
import "contracts/interfaces/IFeeDistributor.sol";
import "contracts/LegatoLicense/LegatoLicense.sol";
import "openzeppelin-contracts/token/ERC20/IERC20.sol";
import "forge-std/console.sol";

contract LicenseRegistryTest is HelperContract {
    function setUp() public {}

    //test pause
    function test_pause_canOnlyBeDoneByAdmin() external {
        vm.expectRevert();
        licenseRegistry.pause();

        vm.startPrank(DEPLOYER);
        licenseRegistry.pause();
        assertTrue(licenseRegistry.paused());
        licenseRegistry.unpause();
        assertFalse(licenseRegistry.paused());
        vm.stopPrank();
    }

    function test_pause_CannotIssueLicenses() external {
        vm.prank(DEPLOYER);
        licenseRegistry.pause();

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
        vm.expectRevert();
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
    }

    function test_blanketLicense_CanCheckForChild() external {
        uint256 lic_id = addFakeLicenseBlueprint(licenseRegistry);
        LicenseBlueprintInfoV2 memory info = licenseRegistry.getLicenseBlueprintbyId(lic_id);

        assertEq(info.owner, address(this));
        assertEq(info.controller, address(this));
        assertEq(info.active, true);
        assertEq(info.name, "name");
        assertEq(info.uri, "uri");
        assertEq(info.ipfsFileHash, "ipfsFileHash");
        assertEq(info.canExpire, false);
        assertEq(info.sellerFields.length, 2);

        licenseRegistry.setActive(lic_id, false);
        assertEq(licenseRegistry.getLicenseBlueprintbyId(lic_id).active, false);

        licenseRegistry.setActive(lic_id, true);
        assertEq(licenseRegistry.getLicenseBlueprintbyId(lic_id).active, true);

        vm.prank(BOB);
        mintSongBlueprintAs();

        _fundAndApproveUSDC(BOB, address(feeDistributor), 100e6, 100e6);

        assertEq(licenseRegistry.getAllLicenseTypeIds().length, 1);
        assertEq(licenseRegistry.getOptinIdsForLicenseBlueprintId(address(registry), lic_id).length, 0);
        assertEq(licenseRegistry.getOptInStatus(address(registry), lic_id), false);

        vm.prank(BOB);
        registry.optIntoLicense(
            LicenseScope.SINGLE, lic_id, address(usdc), 100 * 1e18, "test license", SELLER_FIELDS, ""
        );

        assertEq(licenseRegistry.getAllLicenseTypeIds().length, 1);
        assertEq(licenseRegistry.getOptinIdsForLicenseBlueprintId(address(registry), lic_id).length, 1);
    }

    function test_registerLicense() external {
        verifyHelper.checkRootConfiguration();
        uint256 lic_id = addFakeLicenseBlueprint(licenseRegistry);
        LicenseBlueprintInfoV2 memory info = licenseRegistry.getLicenseBlueprintbyId(lic_id);

        assertEq(info.owner, address(this));
        assertEq(info.controller, address(this));
        assertEq(info.active, true);
        assertEq(info.name, "name");
        assertEq(info.uri, "uri");
        assertEq(info.ipfsFileHash, "ipfsFileHash");
        // assertEq(info.fee,address(registry)
        assertEq(info.canExpire, false);
        assertEq(info.sellerFields.length, 2);

        licenseRegistry.setActive(lic_id, false);
        assertEq(licenseRegistry.getLicenseBlueprintbyId(lic_id).active, false);

        licenseRegistry.setActive(lic_id, true);
        assertEq(licenseRegistry.getLicenseBlueprintbyId(lic_id).active, true);

        vm.prank(BOB);
        mintSongBlueprintAs();

        _fundAndApproveUSDC(BOB, address(feeDistributor), 100e6, 100e6);

        assertEq(licenseRegistry.getAllLicenseTypeIds().length, 1);
        assertEq(licenseRegistry.getOptinIdsForLicenseBlueprintId(address(registry), lic_id).length, 0);
        assertEq(licenseRegistry.getOptInStatus(address(registry), lic_id), false);

        vm.prank(BOB);
        registry.optIntoLicense(
            LicenseScope.SINGLE, lic_id, address(usdc), 100 * 1e18, "test license", SELLER_FIELDS, ""
        );

        assertEq(licenseRegistry.getAllLicenseTypeIds().length, 1);
        assertEq(licenseRegistry.getOptinIdsForLicenseBlueprintId(address(registry), lic_id).length, 1);
    }
}
