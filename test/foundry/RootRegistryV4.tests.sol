// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.7;

import "./util/HelperContract.sol";
import "contracts/interfaces/Structs.sol";
import "contracts/registries/RegistryImplV1.sol";
import "contracts/dataBound/RootRegistry/RootRegistryV4.sol";
import "contracts/dataBound/RootRegistry/RootRegistry.sol";
import "contracts/interfaces/BlanketStructs.sol";
import "contracts/registries/RegistryImplV4.sol";

contract RootRegistryV4Test is HelperContract {
    error NotAdminRole();
    error CallerIsNotListed();

    event StoreDenounced(address indexed _registry, DenounceReason reason);

    function setUp() public {
        RootRegistryV4 v4 = new RootRegistryV4();
        console.log("v4 address: %s", address(v4));
        vm.label(address(v4), "Root-v4");

        vm.prank(DEPLOYER);
        addressManager.changeContractAddressDangerous("contracts.rootRegistry", address(v4));
        // rootRegistry = RootRegistryV3(address(addressManager.getRootRegistry()));
        // RootRegistryV4 reg4 = RootRegistryV4(address(addressManager.getRootRegistry()));
        // vm.prank(DEPLOYER);
        // reg4.setAccountType(BOB, uint8(AccountType.SINGLE1));

        // vm.prank(DEPLOYER);
        // reg4.setStoreMaxForAccountTypes(makeUInt8ArrayWithValue(uint8(AccountType.SINGLE1)), makeUint256ArrayWithValue(1000));
    }

    function test_setStoreMaxForAccountTypes_TwoTypes_AreSetCorrectly() public {
        RootRegistryV4 reg4 = RootRegistryV4(address(addressManager.getRootRegistry()));
        assertEq(reg4.getAccountType(BOB), uint8(AccountType.DEFAULT)); //default
        assertEq(reg4.getStoreMaxForAccountType(uint8(AccountType.SINGLE1)), 1); //default
        assertEq(reg4.getStoreMaxForAccount(BOB), 1); //default

        assertEq(reg4.getStoreMaxForAccountType(uint8(AccountType.DEFAULT)), 1); //was set in the HelperContract.sol , line 200
        assertEq(reg4.getStoreMaxForAccount(MARY), 1);
        assertEq(reg4.getAccountType(MARY), uint8(AccountType.DEFAULT)); //default

        uint8[] memory accountTypes = makeUInt8ArrayWith2Values(uint8(AccountType.DEFAULT), uint8(AccountType.SINGLE1));
        uint256[] memory max2Stores = makeUint256ArrayWith2Values(100, 200);

        vm.prank(DEPLOYER);
        reg4.setStoreMaxForAccountTypes(accountTypes, max2Stores);

        assertEq(reg4.getStoreMaxForAccountType(uint8(AccountType.DEFAULT)), 100);
        assertEq(reg4.getStoreMaxForAccountType(uint8(AccountType.SINGLE1)), 200);

        vm.prank(DEPLOYER);
        reg4.setAccountType(MARY, uint8(AccountType.SINGLE1));
        assertEq(reg4.getStoreMaxForAccount(MARY), 200);
        assertEq(reg4.getAccountType(MARY), uint8(AccountType.SINGLE1)); //default

        vm.prank(DEPLOYER);
        reg4.setAccountType(MARY, uint8(AccountType.DEFAULT));
        assertEq(reg4.getStoreMaxForAccount(MARY), 100);
        assertEq(reg4.getAccountType(MARY), uint8(AccountType.DEFAULT)); //default
    }

    function test_setStoreMaxForAccountType_OneType_setCorrectly() public {
        RootRegistryV4 reg4 = RootRegistryV4(address(addressManager.getRootRegistry()));
        assertEq(reg4.getAccountType(BOB), uint8(AccountType.DEFAULT)); //default
        assertEq(reg4.getStoreMaxForAccountType(uint8(AccountType.DEFAULT)), 1); //default
        assertEq(reg4.getStoreMaxForAccount(BOB), 1); //default

        // assertEq(reg4.getStoreMaxForAccountType(uint8(AccountType.DEFAULT)), 1); //was set in the HelperContract.sol , line 200
        // assertEq(reg4.getStoreMaxForAccount(MARY), 1);
        // assertEq(reg4.getAccountType(MARY), uint8(AccountType.DEFAULT)); //default

        // vm.prank(DEPLOYER);
        // reg4.setStoreMaxForAccountType(uint8(AccountType.SINGLE1), 100);
        // vm.prank(DEPLOYER);
        // reg4.setAccountType(BOB, uint8(AccountType.SINGLE1));

        // assertEq(reg4.getStoreMaxForAccountType(uint8(AccountType.SINGLE1)), 100);
        // assertEq(reg4.getStoreMaxForAccount(BOB), 100);

        // vm.prank(DEPLOYER);
        // reg4.setAccountType(MARY, uint8(AccountType.SINGLE1));
        // assertEq(reg4.getStoreMaxForAccount(MARY), 100);
        // assertEq(reg4.getAccountType(MARY), uint8(AccountType.SINGLE1)); //default

        // vm.prank(DEPLOYER);
        // reg4.setAccountType(MARY, uint8(AccountType.DEFAULT));
        // assertEq(reg4.getStoreMaxForAccount(MARY), 1);
        // assertEq(reg4.getAccountType(MARY), uint8(AccountType.DEFAULT)); //default
    }

    function test_mintRegistryFor_maxStoresForAccountTypeReached_Reverts() public {
        RootRegistryV4 reg4 = RootRegistryV4(address(addressManager.getRootRegistry()));
        vm.prank(DEPLOYER);
        reg4.setAccountType(MARY, uint8(AccountType.SINGLE2));

        uint8[] memory accountTypes = makeUInt8ArrayWithValue(uint8(AccountType.SINGLE2));
        uint256[] memory max2Stores = makeUint256ArrayWithValue(2);

        vm.prank(DEPLOYER);
        reg4.setStoreMaxForAccountTypes(accountTypes, max2Stores);

        reg4.mintRegistryFor(MARY, "maryRegistry", false);
        reg4.mintRegistryFor(MARY, "maryRegistry", false);
        vm.expectRevert("max stores reached");
        reg4.mintRegistryFor(MARY, "maryRegistry", false);
    }

    function test_createFromRootv4() external {
        allow100StoresForDefaultAccounts();
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
        allow100StoresForDefaultAccounts();

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
        allow100StoresForDefaultAccounts();
        address reg1 = rootRegistry.mintRegistryFor(BOB, "bobRegistry", false);
        vm.prank(BOB);
        rootRegistry.delistStoreByOwner(address(reg1));
    }

    function test_detachStore_CanBeDoneByStoreItself() external {
        allow100StoresForDefaultAccounts();
        address reg1 = rootRegistry.mintRegistryFor(BOB, "bobRegistry", false);
        vm.prank(reg1);
        rootRegistry.delistStoreByOwner(address(reg1));
    }

    function test_detachStore_CannotBeDoneByNonAdminsOrOwners() external {
        allow100StoresForDefaultAccounts();
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
