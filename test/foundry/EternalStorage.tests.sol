// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.7;

import "forge-std/Test.sol";
import "./util/HelperContract.sol";
import "forge-std/console.sol";

contract EternalStorageTest is HelperContract {
    event Renounced(address indexed admin);
    event RenounceRequest(address indexed admin);

    error StorageRenounced();
    error NotAdmin();

    bytes32 recordHashed = keccak256(abi.encodePacked("testRecord"));

    function setUp() public {}

    function test_renounceAdmin() public {
        assertFalse(eternalStorage.renounced());
        uint8 renounceCountBefore = eternalStorage.renounceCount();

        vm.expectEmit(true, false, false, true);
        emit RenounceRequest(DEPLOYER);
        vm.prank(DEPLOYER);
        eternalStorage.renounceAdmin();

        assertEq(eternalStorage.renounceCount(), renounceCountBefore + 1);
        assertFalse(eternalStorage.renounced());
    }

    function test_renounced() public {
        assertFalse(eternalStorage.renounced());
        test_renounceAdmin();
        test_renounceAdmin();

        vm.expectEmit(true, false, false, true);
        emit Renounced(DEPLOYER);
        vm.prank(DEPLOYER);
        eternalStorage.renounceAdmin();

        assertTrue(eternalStorage.renounced());
        assertEq(eternalStorage.renounceCount(), 3);
    }

    function test_cannotRenounce_StorageRenounced() public {
        test_renounced();

        vm.expectRevert(abi.encodeWithSelector(StorageRenounced.selector));
        vm.prank(DEPLOYER);
        eternalStorage.renounceAdmin();
    }

    function test_cannotRenounceAdmin_NotAdmin() public {
        vm.expectRevert(abi.encodeWithSelector(NotAdmin.selector));
        vm.prank(BOB);
        eternalStorage.renounceAdmin();
    }

    function test_addressManager() public {
        assertEq(address(addressManager), address(eternalStorage.getAddressManager()));
    }

    function test_setAddressList() public {
        address[] memory addressList = new address[](1);
        addressList[0] = address(100);
        eternalStorage.setAddressListValue(recordHashed, addressList);
        assertEq(eternalStorage.getAddressListValue(recordHashed)[0], address(100));
    }

    function test_cannotSetAddressList_NotAssociated() public {
        address[] memory addressList = new address[](1);
        addressList[0] = address(100);

        vm.expectRevert("Only associated contracts can use storage");
        vm.prank(BOB);
        eternalStorage.setAddressListValue(recordHashed, addressList);
    }

    function test_pushToAddressList() public {
        test_setAddressList();
        eternalStorage.pushToAddressList(recordHashed, address(101));
        assertEq(eternalStorage.getAddressListValue(recordHashed)[1], address(101));
    }

    function test_cannotPushAddressList_NotAssociated() public {
        test_setAddressList();

        vm.expectRevert("Only associated contracts can use storage");
        vm.prank(BOB);
        eternalStorage.pushToAddressList(recordHashed, address(101));
    }

    function test_updateAddressListValue() public {
        test_setAddressList();

        eternalStorage.updateAddressListValue(recordHashed, 0, address(103));
        assertEq(eternalStorage.getAddressListValue(recordHashed)[0], address(103));
    }

    function test_cannotUpdateAddressList_NotAssociated() public {
        test_setAddressList();

        vm.expectRevert("Only associated contracts can use storage");
        vm.prank(BOB);
        eternalStorage.updateAddressListValue(recordHashed, 0, address(103));
    }

    function test_deleteAddressListValue() public {
        test_pushToAddressList();

        eternalStorage.deleteAddressListValue(recordHashed);
        assertEq(eternalStorage.getAddressListValue(recordHashed), new address[](0));
    }

    function test_cannotDeleteAddressListValue_NotAssociated() public {
        vm.expectRevert("Only associated contracts can use storage");
        vm.prank(BOB);
        eternalStorage.deleteAddressListValue(recordHashed);
    }

    function test_deleteAddressListItem() public {
        test_pushToAddressList();

        eternalStorage.deleteAddressListItem(recordHashed, 1);
        assertEq(eternalStorage.getAddressListValue(recordHashed)[1], address(0));
    }

    function test_cannotDeleteAddressListItem_NotAssociated() public {
        vm.expectRevert("Only associated contracts can use storage");
        vm.prank(BOB);
        eternalStorage.deleteAddressListItem(recordHashed, 0);
    }

    function test_setUintList() public {
        uint256[] memory uintList = new uint256[](1);
        uintList[0] = 100;
        eternalStorage.setUIntListValue(recordHashed, uintList);
        assertEq(eternalStorage.getUIntListValue(recordHashed)[0], 100);
    }

    function test_cannotSetUintList_NotAssociated() public {
        uint256[] memory uintList = new uint256[](1);
        uintList[0] = 100;

        vm.expectRevert("Only associated contracts can use storage");
        vm.prank(BOB);
        eternalStorage.setUIntListValue(recordHashed, uintList);
    }

    function test_pushUintListValue() public {
        test_setUintList();
        eternalStorage.pushUintListValue(recordHashed, 101);
        assertEq(eternalStorage.getUIntListValue(recordHashed)[1], 101);
    }

    function test_cannotPushUintList_NotAssociated() public {
        test_setUintList();

        vm.expectRevert("Only associated contracts can use storage");
        vm.prank(BOB);
        eternalStorage.pushUintListValue(recordHashed, 101);
    }

    function test_deleteUIntListValue() public {
        test_pushToAddressList();

        eternalStorage.deleteUIntListValue(recordHashed);
        assertEq(eternalStorage.getUIntListValue(recordHashed), new uint256[](0));
    }

    function test_cannotDeleteUIntListValue_NotAssociated() public {
        vm.expectRevert("Only associated contracts can use storage");
        vm.prank(BOB);
        eternalStorage.deleteUIntListValue(recordHashed);
    }

    function test_setUint8Value() public {
        assertEq(eternalStorage.getInt8Value(recordHashed), 0);

        eternalStorage.setInt8Value(recordHashed, 1);
        assertEq(eternalStorage.getInt8Value(recordHashed), 1);
    }

    function test_cannotSetUint8Value_onlyAssociatedContracts() public {
        vm.expectRevert("Only associated contracts can use storage");
        vm.prank(BOB);
        eternalStorage.setInt8Value(recordHashed, 1);
    }

    function test_deleteInt8Value() public {
        test_setUint8Value();

        eternalStorage.deleteInt8Value(recordHashed);
        assertEq(eternalStorage.getInt8Value(recordHashed), 0);
    }

    function test_cannotDeleteUint8Value_onlyAssociatedContracts() public {
        vm.expectRevert("Only associated contracts can use storage");
        vm.prank(BOB);
        eternalStorage.deleteInt8Value(recordHashed);
    }

    function test_setBytes32Value() public {
        eternalStorage.setBytes32Value(recordHashed, recordHashed);
        assertEq(eternalStorage.getBytes32Value(recordHashed), recordHashed);
    }

    function test_cannotSetBytes32Value_onlyAssociatedContracts() public {
        vm.expectRevert("Only associated contracts can use storage");
        vm.prank(BOB);
        eternalStorage.setBytes32Value(recordHashed, recordHashed);
    }

    function test_deleteBytes32Value() public {
        test_setBytes32Value();

        eternalStorage.deleteBytes32Value(recordHashed);
        assertEq(eternalStorage.getBytes32Value(recordHashed), bytes32(""));
    }

    function test_cannotDeleteBytes32Value_onlyAssociatedContracts() public {
        vm.expectRevert("Only associated contracts can use storage");
        vm.prank(BOB);
        eternalStorage.deleteBytes32Value(recordHashed);
    }

    function test_setAddressValue() public {
        eternalStorage.setAddressValue(recordHashed, address(100));
        assertEq(eternalStorage.getAddressValue(recordHashed), address(100));
    }

    function test_cannotSetAddressValue_onlyAssociatedContracts() public {
        vm.expectRevert("Only associated contracts can use storage");
        vm.prank(BOB);
        eternalStorage.setAddressValue(recordHashed, address(100));
    }

    function test_deleteAddressValue() public {
        test_setAddressValue();

        eternalStorage.deleteAddressValue(recordHashed);
        assertEq(eternalStorage.getAddressValue(recordHashed), address(0));
    }

    function test_cannotDeleteAddressValue_onlyAssociatedContracts() public {
        vm.expectRevert("Only associated contracts can use storage");
        vm.prank(BOB);
        eternalStorage.deleteAddressValue(recordHashed);
    }

    function test_setBytesValue() public {
        bytes memory test = bytes("test");
        eternalStorage.setBytesValue(recordHashed, test);
        bytes memory value = eternalStorage.getBytesValue(recordHashed);
        if (keccak256(abi.encodePacked(test)) == keccak256(abi.encodePacked(value))) {
            assertTrue(true);
            return;
        }
        assertTrue(false);
    }

    function test_cannotSetBytesValue_onlyAssociatedContracts() public {
        vm.expectRevert("Only associated contracts can use storage");
        vm.prank(BOB);
        eternalStorage.setBytesValue(recordHashed, bytes("test"));
    }

    function test_deleteBytesValue() public {
        test_setBytesValue();

        eternalStorage.deleteBytesValue(recordHashed);
        assertEq(eternalStorage.getBytesValue(recordHashed), bytes(""));
    }

    function test_cannotDeleteBytesValue_onlyAssociatedContracts() public {
        vm.expectRevert("Only associated contracts can use storage");
        vm.prank(BOB);
        eternalStorage.deleteBytesValue(recordHashed);
    }

    function test_setUIntValue() public {
        assertEq(eternalStorage.getUIntValue(recordHashed), 0);

        eternalStorage.setUIntValue(recordHashed, 1);
        assertEq(eternalStorage.getUIntValue(recordHashed), 1);
    }

    function test_cannotSetUIntValue_onlyAssociatedContracts() public {
        vm.expectRevert("Only associated contracts can use storage");
        vm.prank(BOB);
        eternalStorage.setUIntValue(recordHashed, 1);
    }

    function test_deleteUIntValue() public {
        test_setUIntValue();

        eternalStorage.deleteUIntValue(recordHashed);
        assertEq(eternalStorage.getUIntValue(recordHashed), 0);
    }

    function test_cannotDeleteUIntValue_onlyAssociatedContracts() public {
        vm.expectRevert("Only associated contracts can use storage");
        vm.prank(BOB);
        eternalStorage.deleteUIntValue(recordHashed);
    }

    function test_setStringValue() public {
        string memory stringValue = "someString";
        assertEq(eternalStorage.getStringValue(recordHashed), "");

        eternalStorage.setStringValue(recordHashed, "someString");
        string memory stringValueAfter = eternalStorage.getStringValue(recordHashed);
        assertEq(stringValue, stringValueAfter);
    }

    function test_cannotSetStringValue_onlyAssociatedContracts() public {
        vm.expectRevert("Only associated contracts can use storage");
        vm.prank(BOB);
        eternalStorage.setStringValue(recordHashed, "someString");
    }

    function test_deleteStringValue() public {
        test_setStringValue();

        eternalStorage.deleteStringValue(recordHashed);
        assertEq(eternalStorage.getStringValue(recordHashed), "");
    }

    function test_cannotDeleteStringValue_onlyAssociatedContracts() public {
        vm.expectRevert("Only associated contracts can use storage");
        vm.prank(BOB);
        eternalStorage.deleteStringValue(recordHashed);
    }

    function test_setBooleanValue() public {
        assertEq(eternalStorage.getBooleanValue(recordHashed), false);

        eternalStorage.setBooleanValue(recordHashed, true);
        assertEq(eternalStorage.getBooleanValue(recordHashed), true);
    }

    function test_cannotSetBooleanValue_onlyAssociatedContracts() public {
        vm.expectRevert("Only associated contracts can use storage");
        vm.prank(BOB);
        eternalStorage.setBooleanValue(recordHashed, true);
    }

    function test_deleteBooleanValue() public {
        test_setBooleanValue();

        eternalStorage.deleteBooleanValue(recordHashed);
        assertEq(eternalStorage.getBooleanValue(recordHashed), false);
    }

    function test_cannotDeleteBooleanValue_onlyAssociatedContracts() public {
        vm.expectRevert("Only associated contracts can use storage");
        vm.prank(BOB);
        eternalStorage.deleteBooleanValue(recordHashed);
    }

    function test_setIntValue() public {
        assertEq(eternalStorage.getIntValue(recordHashed), 0);

        eternalStorage.setIntValue(recordHashed, 1);
        assertEq(eternalStorage.getIntValue(recordHashed), 1);
    }

    function test_cannotSetIntValue_onlyAssociatedContracts() public {
        vm.expectRevert("Only associated contracts can use storage");
        vm.prank(BOB);
        eternalStorage.setIntValue(recordHashed, 1);
    }

    function test_deleteIntValue() public {
        test_setIntValue();

        eternalStorage.deleteIntValue(recordHashed);
        assertEq(eternalStorage.getIntValue(recordHashed), 0);
    }

    function test_cannotDeleteIntValue_onlyAssociatedContracts() public {
        vm.expectRevert("Only associated contracts can use storage");
        vm.prank(BOB);
        eternalStorage.deleteIntValue(recordHashed);
    }
}
