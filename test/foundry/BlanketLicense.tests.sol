// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.7;

import "forge-std/Test.sol";

import "contracts/eip5553/IIPRepresentation.sol";
import "contracts/interfaces/ILicenseBlueprint.sol";
import "contracts/interfaces/IRoyaltyPortionToken.sol";
import "contracts/interfaces/Structs.sol";
import "contracts/interfaces/BlanketStructs.sol";
import "./dummies/FakeToken.sol";
import "./util/HelperContract.sol";
import "contracts/dataBound/LicenseRegistry/LicenseRegistry.sol";
import "contracts/LicenseBlueprint.sol";
import "contracts/registries/RegistryImplV1.sol";
import "contracts/interfaces/IFeeDistributor.sol";
import "contracts/LegatoLicense/LegatoLicense.sol";
import "openzeppelin-contracts/token/ERC20/IERC20.sol";
import "forge-std/console.sol";

contract BlanketLicenseTests is HelperContract {
    function setUp() public {}

    function test_blanketLicense_CanCheckForChild_a() external {
        assertEq(IVersioned(address(registry)).getVersion(), 5);
        uint256 lic_id = addFakeBLANKETLicenseBlueprint(licenseRegistry, LicenseScope.STORE);
        LicenseBlueprintInfoV2 memory info = licenseRegistry.getLicenseBlueprintbyId(lic_id);

        // assertEq(info.scope, uint8(LicenseScope.STORE));
        vm.prank(BOB);
        address song = mintSongBlueprintAs();
        MintLicenseRequest memory MLR_REQ = MintLicenseRequest({
            optInId: 1,
            licenseBlueprintId: lic_id,
            to: MARY,
            target: song, //THIS IS BAD since we need to give a store address
            currency: USDC_ADDRESS,
            amount: 10e18,
            buyerFields: BUYER_FIELDS,
            encryptedBuyerInfo: "",
            memo: ""
        });

        vm.prank(BOB);
        vm.expectRevert();
        //this will fail since we are giving a SINGLE scope for a blueperint that support s a STORE scope
        registry.optIntoLicense(
            LicenseScope.SINGLE, lic_id, address(usdc), 100 * 1e18, "test license", SELLER_FIELDS, ""
        );

        vm.prank(BOB);
        //should work since target is a store and scope is a store on the request and the blueprint
        uint256 newOptinId =
            registry.optIntoLicense(LicenseScope.STORE, lic_id, address(usdc), 10e18, "test license", SELLER_FIELDS, "");

        assertEq(licenseRegistry.getAllLicenseTypeIds().length, 1);
        assertEq(licenseRegistry.getOptinIdsForLicenseBlueprintId(address(registry), lic_id).length, 1);

        MLR_REQ.optInId = newOptinId;
        MLR_REQ.target = song;
        vm.prank(MARY);
        vm.expectRevert(); //should fail since target is song but scope is store
        registry.mintLicense(MLR_REQ);

        MLR_REQ.target = address(registry);
        _fundAndApproveUSDC(MARY, address(feeDistributor), 100e18, 100e18);
        vm.prank(MARY); //should work since we are not targeting a store
        registry.mintLicense(MLR_REQ);

        assertEq(IUSDC(USDC_ADDRESS).balanceOf(address(registry)), 9e18, "store should have 9 usdc");
        assertEq(IUSDC(USDC_ADDRESS).balanceOf(address(feeDistributor)), 1e18);

        vm.startPrank(BOB);
        vm.expectRevert();
        registry.withdraw(address(usdc), BOB, 19e18); //should fail since we only have 9 usdc

        registry.withdraw(address(usdc), BOB, 9e18); //should work since we have 9 usdc
        vm.stopPrank();
        assertEq(IUSDC(USDC_ADDRESS).balanceOf(address(feeDistributor)), 1e18);
        assertEq(IUSDC(USDC_ADDRESS).balanceOf(address(registry)), 0, "store should have 9 usdc");
        assertEq(IUSDC(USDC_ADDRESS).balanceOf(address(BOB)), 9e18);
    }
}
