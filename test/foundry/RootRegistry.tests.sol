// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.7;

import "./util/HelperContract.sol";
import "contracts/registries/RegistryImplV1.sol";
import "contracts/interfaces/BlanketStructs.sol";
import "contracts/registries/RegistryImplV4.sol";

contract RootRegistryTest is HelperContract {
    error NotAdminRole();
    error CallerIsNotListed();

    event StoreDenounced(address indexed _registry, DenounceReason reason);

    function setUp() public {
        allow100StoresForDefaultAccounts();
        // RootRegistry v1 = new RootRegistry();
        // console.log("v4 address: %s", address(v1));
        // vm.label(address(v1), "Root-v4");

        // vm.prank(DEPLOYER);
        // addressManager.changeContractAddressDangerous("contracts.rootRegistry", address(v1));
        // rootRegistry = RootRegistryV3(address(addressManager.getRootRegistry()));
    }

    function test_createFromRoot() external {
        assertEq(rootRegistry.getRegistriesByWallet(BOB).length, 1);

        address bobsRegistryAddress = rootRegistry.mintRegistryFor(BOB, "bobRegistry", false);
        uint256 count = rootRegistry.getAllRegistries().length;
        uint256 registryIndex = count - 1;

        vm.label(bobsRegistryAddress, "bobsRegistry");

        assertEq(rootRegistry.getRegistriesByWallet(BOB).length, 2);
        assertEq(rootRegistry.getAllRegistries()[registryIndex], bobsRegistryAddress);

        RegistryImplV1 bobsRegistry = RegistryImplV1(bobsRegistryAddress);
        assertEq(address(addressManager.getRootRegistry()), address(rootRegistry));

        uint256 licenseId = addFakeNonActiveLicense();
        // vm.prank(BOB);
        //seller fields
        LicenseField[] memory sellerFields = new LicenseField[](2);
        sellerFields[0] = LicenseField({id: 1, name: "licensor", val: "sam", dataType: "string", info: "Licensor name"});
        sellerFields[1] =
            LicenseField({id: 2, name: "address", val: "mary", dataType: "address", info: "seller address"});

        vm.expectRevert(); //only bob can do this
        bobsRegistry.optIntoLicense(LicenseScope.SINGLE, licenseId, USDC_ADDRESS, 10e6, "", sellerFields, "");

        vm.expectRevert(); // should fail due to license not active
        vm.prank(BOB); //even if it is BOB
        bobsRegistry.optIntoLicense(LicenseScope.SINGLE, licenseId, USDC_ADDRESS, 10e6, "", sellerFields, "");

        licenseRegistry.setActive(licenseId, true);
        vm.prank(BOB); //now it should work
        bobsRegistry.optIntoLicense(LicenseScope.SINGLE, licenseId, USDC_ADDRESS, 10e6, "", sellerFields, "");
    }

    /// delistStore()

    function testCannotDelistStoreNotRegistry() public {
        vm.expectRevert("registry not found");
        vm.prank(BOB);
        rootRegistry.delistStoreByOwner(address(89));
    }

    /// denounceStore()

    function test_detachStore_CanNOTBeDoneByDeployer() external {
        vm.prank(DEPLOYER);
        vm.expectRevert();
        rootRegistry.delistStoreByOwner(address(registry));
    }

    function test_getOnlyActive_IgnoresInActive() public {
        // we already have one active registry
        vm.prank(BOB);
        address reg2 = rootRegistry.mintRegistryFor(BOB, "bobRegistry", false);
        assertEq(rootRegistry.getActiveRegistries(true).length, 2);
        assertEq(rootRegistry.getActiveRegistries(false).length, 0);

        vm.prank(BOB);
        RegistryImplV4(reg2).updateStoreStatus(uint8(StoreStatus.INACTIVE));
        assertEq(rootRegistry.getActiveRegistries(true).length, 1);
        assertEq(rootRegistry.getActiveRegistries(false).length, 1);

        vm.prank(BOB);
        RegistryImplV4(reg2).updateStoreStatus(uint8(StoreStatus.ACTIVE));
        assertEq(rootRegistry.getActiveRegistries(true).length, 2);
        assertEq(rootRegistry.getActiveRegistries(false).length, 0);

        vm.prank(BOB);
        rootRegistry.mintRegistryFor(BOB, "bobRegistry", false);
        assertEq(rootRegistry.getActiveRegistries(true).length, 3);
        assertEq(rootRegistry.getActiveRegistries(false).length, 0);

        vm.prank(BOB);
        RegistryImplV4(reg2).updateStoreStatus(uint8(StoreStatus.INACTIVE));
        assertEq(rootRegistry.getActiveRegistries(true).length, 2);
        assertEq(rootRegistry.getActiveRegistries(false).length, 1);
    }

    function test_banStore_CanBeDoneByDeployer() external {
        vm.prank(DEPLOYER);
        rootRegistry.denounceStore(address(registry), DenounceReason.ILLEGAL_ACTIVITY);
    }

    function test_detachStore_CanBeDoneByStoreOwner() external {
        address reg1 = rootRegistry.mintRegistryFor(BOB, "bobRegistry", false);
        vm.prank(BOB);
        rootRegistry.delistStoreByOwner(address(reg1));
    }

    function test_detachStore_CanBeDoneByStoreItself() external {
        address reg1 = rootRegistry.mintRegistryFor(BOB, "bobRegistry", false);
        vm.prank(reg1);
        rootRegistry.delistStoreByOwner(address(reg1));
    }

    function test_detachStore_CannotBeDoneByNonAdminsOrOwners() external {
        address reg1 = rootRegistry.mintRegistryFor(BOB, "bobRegistry", false);
        vm.expectRevert();
        vm.prank(MARY);
        rootRegistry.delistStoreByOwner(address(reg1));
    }

    function test_detach_DenounceStore() public {
        assertTrue(rootRegistry.isValidRegistry(address(registry)));
        uint256 userRegistryCountBefore = (rootRegistry.getAllRegistriesByWallet(BOB)).length;
        uint256 denouncedRegistriesBefore = (rootRegistry.getDenouncedRegistries()).length;

        vm.expectEmit(true, false, false, true);
        emit StoreDenounced(address(registry), DenounceReason.ILLEGAL_ACTIVITY);
        vm.prank(DEPLOYER);
        rootRegistry.denounceStore(address(registry), DenounceReason.ILLEGAL_ACTIVITY);

        assertFalse(rootRegistry.isValidRegistry(address(registry)));

        uint256 userRegistryCountAfter = (rootRegistry.getAllRegistriesByWallet(BOB)).length;
        uint256 denouncedRegistriesAfter = (rootRegistry.getDenouncedRegistries()).length;

        assertEq(userRegistryCountAfter, userRegistryCountBefore);
        assertEq(denouncedRegistriesAfter, denouncedRegistriesBefore + 1);
    }

    function testCannotDenounceNotAdmin() public {
        vm.expectRevert("Not admin");
        vm.prank(BOB);
        rootRegistry.denounceStore(address(registry), DenounceReason.ILLEGAL_ACTIVITY);
    }
}
