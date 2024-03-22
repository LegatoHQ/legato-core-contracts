// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.7;

import "forge-std/Test.sol";
import "./util/HelperContract.sol";
import "forge-std/console.sol";
import "contracts/testContracts/FeeDistributorV2Dummy.sol";
import "contracts/interfaces/IVersioned.sol";

contract UpgradeabilityTest is HelperContract {
    function setUp() public {
        // newFeeDistributor = new FeeDistributorV2Dummy();
        // vm.prank(DEPLOYER);
        // addressManager.changeContractAddressVersioned("contracts.feeDistributor", address(newFeeDistributor));
    }

    function test_canReplaceFeeDistWithV2() public {
        assertEq(
            addressManager.getUnderlyingFeeDistributor(),
            address(addressManager.getContractAddress("contracts.feeDistributor"))
        );
        // vm.stopPrank();
    }

    function test_feeDistributorUpgraded() public {
        bool isUpgraded = FeeDistributorV2(addressManager.getFeeDistributor()).getVersion() > 3;
        assertTrue(isUpgraded);
    }

    function test_v2_canWorkSameAsV1() external {
        FeeDistributor fdV1 = new FeeDistributor();
        vm.prank(DEPLOYER);
        addressManager.changeContractAddressDangerous("contracts.feeDistributor", address(fdV1));

        FeeDistributor feeDistPointer = FeeDistributor(addressManager.getFeeDistributor());
        uint256[] memory pending1 = feeDistPointer.getPendingClaimIdsFor(BOB);
        uint256[] memory allClaims = feeDistPointer.getAllClaimIdsFor(BOB);
        assertEq(pending1.length, 0);
        assertEq(allClaims.length, 0);

        uint256 lic_id = addFakeLicenseBlueprint(licenseRegistry);

        vm.startPrank(BOB);
        address song = mintSongBlueprintAs();
        uint256 optinId =
            registry.optIntoLicense(LicenseScope.SINGLE, lic_id, address(usdc), 0, "FREE LICENSE", SELLER_FIELDS, "");
        vm.stopPrank();

        _fundAndApproveUSDC(MARY, address(addressManager.getFeeDistributor()), 100e6, 100e6);

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

        uint256[] memory pending2 = feeDistPointer.getPendingClaimIdsFor(BOB);
        assertEq(pending2.length, 0);

        uint256[] memory allClaims2 = feeDistPointer.getAllClaimIdsFor(BOB);
        assertEq(allClaims2.length, 0);
    }
}
