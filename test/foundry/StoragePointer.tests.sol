// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.7;

import "forge-std/Test.sol";
import "./util/HelperContract.sol";
import "forge-std/console.sol";
import "contracts/testContracts/FeeDistributorV2Dummy.sol";
import "contracts/interfaces/IVersioned.sol";
import "contracts/Cloner.sol";
import "contracts/storage/AccessControlStorage.sol";
import "contracts/storage/PausableStorage.sol";
import "contracts/storage/StorageContractPointer.sol";

contract CommonDummyContractStorage {
    EternalStorage __DATA__;
    bool storageInitialized;
}

contract DummyStoragePointer is StorageContractPointer, CommonDummyContractStorage {
    constructor() {
        __DATA__ = EternalStorage(address(this));
    }
}

contract StoragePointerTest is HelperContract {
    function setUp() public {}

    function test_givenContract_A_WithPointer_A_whenUpgradedToContract_B_thenPointer_A_IsContractB() public {
        ContractA contractA = new ContractA();
        vm.label(address(contractA), "contractA");
        ContractB contractB = new ContractB();
        vm.label(address(contractB), "contractB");
        DummyStoragePointer pointer = new DummyStoragePointer();

        vm.startPrank(DEPLOYER);
        addressManager.registerNewContract("A", address(contractA));
        pointer.initializeAddresses("A", DEPLOYER, address(addressManager));
        assertEq(IVersioned(address(pointer)).getVersion(), 1);
        assertEq(ContractA(address(pointer)).saySomething(), "I am A");

        addressManager.changeContractAddressVersioned("A", address(contractB));
        assertEq(IVersioned(address(pointer)).getVersion(), 2);
        assertEq(ContractA(address(pointer)).saySomething(), "I am B");
        vm.stopPrank();
    }

    function test_withClonesAndFunding_givenContract_A_WithPointer_A_whenUpgradedToContract_B_thenPointer_A_IsContractB(
    ) public {
        ContractA contractA = new ContractA();
        vm.label(address(contractA), "contractA");
        ContractB contractB = new ContractB();
        vm.label(address(contractB), "contractB");
        DummyStoragePointer pointerImpl = new DummyStoragePointer();
        address pointerCloneAddress = Cloner.createClone(address(pointerImpl));
        vm.label(address(pointerCloneAddress), "pointerClone");
        DummyStoragePointer pointer = DummyStoragePointer(payable(pointerCloneAddress));

        vm.startPrank(DEPLOYER);
        addressManager.registerNewContract("A", address(contractA));
        pointer.initializeAddresses("A", DEPLOYER, address(addressManager));
        vm.stopPrank();
        assertEq(ContractA(address(pointer)).saySomething(), "I am A");
        assertEq(IVersioned(address(pointer)).getVersion(), 1);

        // //try funding
        // _getUSDC(address(pointer), 100e18);
        // assertEq(IUSDC(USDC_ADDRESS).balanceOf(address(pointer)), 100e18);

        // vm.startPrank(DEPLOYER);
        //     addressManager.changeContractAddressVersioned("A", address(contractB));
        // vm.stopPrank();
        // assertEq(IVersioned(address(pointer)).getVersion(), 2);
        // assertEq(ContractA(address(pointer)).saySomething(), "I am B");
        // assertEq(IUSDC(USDC_ADDRESS).balanceOf(address(pointer)), 100e18);
    }

    function test_withClonesAndAccessControlFunding_givenContract_A_WithPointer_A_whenUpgradedToContract_B_thenPointer_A_IsContractB(
    ) public {
        ContractAWithStorage contractA = new ContractAWithStorage();
        ContractBWithStorage contractB = new ContractBWithStorage();

        DummyStoragePointer pointerImpl = new DummyStoragePointer();
        address pointerAddress = Cloner.createClone(address(pointerImpl));
        vm.label(pointerAddress, "pointerClone");
        // StoragePointer pointer = StoragePointer(payable(pointerCloneAddress)) ;
        vm.startPrank(DEPLOYER);
        addressManager.registerNewContract("AAA", address(contractA));
        DummyStoragePointer(payable(pointerAddress)).initializeAddresses("AAA", DEPLOYER, address(addressManager));
        eternalStorage.allowContract(pointerAddress);
        assertTrue(address(eternalStorage) != address(addressManager), "eternalStorage should not be addressManager");
        vm.stopPrank();

        //should work on the underlyig ContractA
        //BOB shoud be the admin
        StorageInitializable(pointerAddress).initializeStorageAndAdmin(address(eternalStorage), BOB);

        assertEq(ContractAWithStorage(pointerAddress).saySomething(), "I am A");
        assertEq(IVersioned(pointerAddress).getVersion(), 1);

        vm.expectRevert(); //not owner
        ContractAWithStorage(pointerAddress).onlyOwnersCanCallMe();
        vm.prank(BOB); //no error now
        ContractAWithStorage(pointerAddress).onlyOwnersCanCallMe();
        // contractA.initializeStorageAndAdmin(address(eternalStorage),BOB);

        //try funding
        _getUSDC(pointerAddress, 100e18);
        assertEq(IUSDC(USDC_ADDRESS).balanceOf(pointerAddress), 100e18);

        vm.startPrank(DEPLOYER);
        addressManager.changeContractAddressVersioned("AAA", address(contractB));
        vm.stopPrank();
        assertEq(IVersioned(pointerAddress).getVersion(), 2);
        assertEq(ContractA(pointerAddress).saySomething(), "I am B");
        assertEq(IUSDC(USDC_ADDRESS).balanceOf(pointerAddress), 100e18);

        vm.expectRevert(); //not owner
        ContractAWithStorage(pointerAddress).onlyOwnersCanCallMe();
        vm.prank(BOB); //no error now
        ContractAWithStorage(pointerAddress).onlyOwnersCanCallMe();
    }
}

interface StorageInitializable {
    function initializeStorageAndAdmin(address _eternalStorage, address _owner) external;
}

contract ContractA {
    function getVersion() public pure returns (uint256) {
        return 1;
    }

    function saySomething() public pure returns (string memory) {
        return "I am A";
    }
}

contract ContractB {
    function getVersion() public pure returns (uint256) {
        return 2;
    }

    function saySomething() public pure returns (string memory) {
        return "I am B";
    }
}

contract ContractAWithStorage is
    AccessControlUpgradeable,
    PausableUpgradeable,
    IVersioned,
    StorageInitializable,
    CommonDummyContractStorage
{
    function initializeStorageAndAdmin(address _eternalStorage, address _owner) external override {
        require(!storageInitialized, "Already initialised");
        storageInitialized = true;
        __DATA__ = EternalStorage(_eternalStorage);
        _grantRole(DEFAULT_ADMIN_ROLE, _owner); //creator is owner
    }

    function getFromGlobalData() public view returns (uint8) {
        return __DATA__.getInt8Value(keccak256(abi.encodePacked("XXX")));
    }

    function onlyOwnersCanCallMe() public {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Only owner can call");
        __DATA__.setInt8Value(keccak256(abi.encodePacked("XXX")), 1);
    }

    // function "YYY" internal pure override(PausableStorage, AccessControlStorage) returns (string memory) {
    //     return "AAA";
    // }

    // function getStorage() internal view override(PausableStorage, AccessControlStorage) returns (address) {
    //     return address(__DATA__);
    // }

    function getVersion() public pure override returns (uint8) {
        return 1;
    }

    function saySomething() public pure returns (string memory) {
        return "I am A";
    }
}

contract ContractBWithStorage is
    AccessControlUpgradeable,
    PausableUpgradeable,
    IVersioned,
    StorageInitializable,
    CommonDummyContractStorage
{
    // address immutable self;
    ///no need for initialized since we are are version 2 and will use the same storage as ContractAWithStorage

    function initializeStorageAndAdmin(address _eternalStorage, address _owner) external override {
        require(!storageInitialized, "Already initialised");
        storageInitialized = true;
        __DATA__ = EternalStorage(_eternalStorage);
        _grantRole(DEFAULT_ADMIN_ROLE, _owner); //creator is owner
    }

    function getFromGlobalData() public view returns (uint8) {
        return __DATA__.getInt8Value(keccak256(abi.encodePacked("YYY")));
    }

    function onlyOwnersCanCallMe() public {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Only owner can call");
        __DATA__.setInt8Value(keccak256(abi.encodePacked("YYY")), 2);
    }

    // function "YYY" internal pure override(PausableStorage, AccessControlStorage) returns (string memory) {
    //     return "AAA";
    //     ///this is on purpose. needs to be the same as ContractAWithStorage so they can share storage
    // }

    // function getStorage() internal view override(PausableStorage, AccessControlStorage) returns (address) {
    //     return address(__DATA__);
    // }

    function getVersion() public pure override returns (uint8) {
        return 2;
    }

    function saySomething() public pure returns (string memory) {
        return "I am B";
    }
}
