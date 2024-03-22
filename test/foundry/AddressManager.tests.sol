// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.7;

import "forge-std/Test.sol";
import "./util/HelperContract.sol";
import "forge-std/console.sol";
import "contracts/storage/AccessControlStorage.sol";
import "contracts/testContracts/AddressManagerV2Dummy.sol";

contract AddressManagerTest is HelperContract {
    event ContractRegistered(address indexed contractAddress, string record);
    event ContractUnregistered(address indexed contractAddress, string record);
    event ContractAddressChanged(address indexed newAddress, address indexed oldAddress, string record);

    string constant NEW_CONTRACT_NAME = "NEW_CONTRACT_NAME";

    function setUp() public {}

    function PACK_NO_PREFIX(string memory _key1) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(_key1));
    }

    function test_getContractAddress() public {
        address feeDistributerAddress = addressManager.getPointerForContractName("contracts.feeDistributor");
        assertEq(address(feeDistributor), feeDistributerAddress);
    }

    function helper_registerAndAsseerNewContract() public {
        DummyV1 dummyV1 = new DummyV1();
        address contractAddress = address(dummyV1);

        vm.expectEmit(true, false, false, true);
        emit ContractRegistered(contractAddress, NEW_CONTRACT_NAME);
        vm.prank(DEPLOYER);
        addressManager.registerNewContract(NEW_CONTRACT_NAME, contractAddress);

        assertTrue(eternalStorage.getBooleanValue(PACK_NO_PREFIX(NEW_CONTRACT_NAME)));
    }

    function test_cannotRegisterNewContract_ZeroAddress() public {
        vm.expectRevert();
        vm.prank(DEPLOYER);
        addressManager.registerNewContract(NEW_CONTRACT_NAME, address(0));
    }

    function test_cannotRegisterNewContract_AlreadyRegistered() public {
        helper_registerAndAsseerNewContract();

        vm.expectRevert();
        vm.prank(DEPLOYER);
        addressManager.registerNewContract(NEW_CONTRACT_NAME, address(100));
    }

    function test_cannotRegisterNewContract_NotAdmin() public {
        vm.expectRevert();
        vm.prank(BOB);
        addressManager.registerNewContract(NEW_CONTRACT_NAME, address(100));
    }

    function test_unregisterContract() public {
        DummyV1 dummyV1 = new DummyV1();
        vm.prank(DEPLOYER);
        addressManager.registerNewContract(NEW_CONTRACT_NAME, address(dummyV1));

        vm.expectEmit(true, false, false, true);
        emit ContractUnregistered(address(dummyV1), NEW_CONTRACT_NAME);
        vm.prank(DEPLOYER);
        addressManager.unregisterContract(NEW_CONTRACT_NAME);

        assertFalse(eternalStorage.getBooleanValue(PACK_NO_PREFIX(NEW_CONTRACT_NAME)));
        assertEq(addressManager.getContractAddress(NEW_CONTRACT_NAME), address(0));
    }

    function test_cannotUnregisterContract_NotAdmin() public {
        helper_registerAndAsseerNewContract();

        vm.expectRevert();
        vm.prank(BOB);
        addressManager.unregisterContract(NEW_CONTRACT_NAME);
    }

    function test_cannotUnregisterContract_NotRegistered() public {
        vm.expectRevert();
        vm.prank(DEPLOYER);
        addressManager.unregisterContract(NEW_CONTRACT_NAME);
    }

    function test_changeContractAddress_versionsGoUp_OK() public {
        DummyV1 dummyV1 = new DummyV1();
        DummyV2 dummyV2 = new DummyV2();

        vm.prank(DEPLOYER);
        addressManager.registerNewContract(NEW_CONTRACT_NAME, address(dummyV1));

        vm.expectEmit(true, true, false, true);
        emit ContractAddressChanged(address(dummyV2), address(dummyV1), NEW_CONTRACT_NAME);
        vm.prank(DEPLOYER);
        addressManager.changeContractAddressVersioned(NEW_CONTRACT_NAME, address(dummyV2));

        assertEq(eternalStorage.getAddressValue(PACK_NO_PREFIX(NEW_CONTRACT_NAME)), address(dummyV2));
    }

    function test_changeContractAddress_versionsGoDown_fails() public {
        DummyV2 dummyV2 = new DummyV2();
        DummyV1 dummyV1 = new DummyV1();

        vm.prank(DEPLOYER);
        addressManager.registerNewContract(NEW_CONTRACT_NAME, address(dummyV2));

        vm.expectRevert();
        vm.prank(DEPLOYER);
        addressManager.changeContractAddressVersioned(NEW_CONTRACT_NAME, address(dummyV1));
    }

    function test_cannotChangeContractAddress_NotAdmin() public {
        helper_registerAndAsseerNewContract();

        vm.expectRevert();
        vm.prank(BOB);
        addressManager.changeContractAddressVersioned(NEW_CONTRACT_NAME, address(101));
    }

    function test_cannotChangeContractAddress_NotRegistered() public {
        vm.expectRevert();
        vm.prank(DEPLOYER);
        addressManager.changeContractAddressVersioned(NEW_CONTRACT_NAME, address(101));
    }

    function test_setters() public {
        DummyV4 dummyV4 = new DummyV4();
        vm.expectEmit(true, true, true, false);
        // console.log("old address: ", addressManager.getFeeDistributor());
        emit ContractAddressChanged(
            address(dummyV4), addressManager.getUnderlyingFeeDistributor(), "contracts.feeDistributor"
        );
        vm.prank(DEPLOYER);
        addressManager.setFeeDistributor(address(dummyV4));
    }

    function test_Admin_withStorageAccessControl_KeepsAccessContol() public {
        DummyUpgradeableV1 v1_Dummy = new DummyUpgradeableV1();
        DummyUpgradeableV2 v2_Dummy = new DummyUpgradeableV2();
        vm.prank(DEPLOYER);
        addressManager.registerNewContractWithPointer("v1_Dummy", address(v1_Dummy), DEPLOYER);
        DummyUpgradeableV1 pointer = DummyUpgradeableV1(addressManager.getPointerForContractName("v1_Dummy"));

        vm.startPrank(DEPLOYER);
        eternalStorage.allowContract(address(pointer));
        pointer.initialize(address(eternalStorage));
        pointer.makeMeAdmin(); //should make us admin
        vm.stopPrank();
        assertEq(pointer.getVersion(), 1);
        assertEq(pointer.isAdmin(DEPLOYER), true);

        vm.prank(DEPLOYER);
        addressManager.changeContractAddressDangerous("v1_Dummy", address(v2_Dummy));

        assertEq(pointer.getVersion(), 2);
        assertEq(pointer.isAdmin(DEPLOYER), true); //since usiung the same storage
    }

    function test_upgradeAddressManager_ToV2_canBeDone() public {
        AddressManagerV2Dummy dummy = new AddressManagerV2Dummy();

        AddressManager pointer1 = AddressManager(addressManager.getAddressManager());
        assertEq(pointer1.getVersion(), 1);
        assertEq(addressManager.getVersion(), 1);
        assertEq(address(pointer1), address(addressManager));

        vm.prank(DEPLOYER);
        addressManager.changeContractAddressVersioned("contracts.addressManager", address(dummy));

        AddressManager pointer2 = AddressManager(addressManager.getAddressManager());
        AddressManager pointer3 = AddressManager(addressManager.getContractAddress("contracts.addressManager"));
        assertEq(pointer2.getVersion(), 2);
        assertEq(pointer3.getVersion(), 2);
        assertEq(address(pointer2), address(pointer3));
    }
}

contract DummyV1 is IVersioned {
    function getVersion() external pure override returns (uint8) {
        return 1;
    }
}

contract DummyV4 is IVersioned {
    function getVersion() external pure override returns (uint8) {
        return 255;
    }
}

contract DummyV3 is IVersioned {
    function getVersion() external pure override returns (uint8) {
        return 3;
    }
}

contract DummyV2 is IVersioned {
    function getVersion() external pure override returns (uint8) {
        return 2;
    }
}

contract DummyUpgradeableV1 is HelperContract, IVersioned, AccessControlUpgradeable {
    EternalStorage __DATA__;

    function initialize(address _eternalStorage) public {
        __DATA__ = EternalStorage(_eternalStorage);
    }

    function getVersion() external pure override returns (uint8) {
        return 1;
    }

    function makeMeAdmin() public {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function isAdmin(address _address) public view returns (bool) {
        return hasRole(DEFAULT_ADMIN_ROLE, _address);
    }
}

contract DummyUpgradeableV2 is HelperContract, IVersioned, AccessControlUpgradeable {
    EternalStorage __DATA__;

    function initialize(address _eternalStorage) public {
        __DATA__ = EternalStorage(_eternalStorage);
    }

    function getVersion() external pure override returns (uint8) {
        return 2;
    }

    function isAdmin(address _address) public view returns (bool) {
        return hasRole(DEFAULT_ADMIN_ROLE, _address);
    }
}
