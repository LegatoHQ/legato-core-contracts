// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.7;

import "./util/HelperContract.sol";
import "contracts/registries/IRegistryV2.sol";
import "contracts/registries/IRegistryProxyPointer.sol";
import "contracts/interfaces/BlanketStructs.sol";
import "contracts/interfaces/IVersioned.sol";

contract RegistryProxyPointerUpgrade_Tests is HelperContract {
    event NewStoreToken(address tokenAddress, address registry);
    event NewIP(address songAddress, string shortName, string symbol, address registry);
    event RegistryDetached(address indexed registry);
    event OwnerUpdated(address indexed newOwner);
    event StatusUpdated(StoreStatus status);
    event StoreOwnershipTransferred(address indexed _registry, address indexed ownerOut, address indexed ownerIn);
    event RegistryDelisted(address indexed _registry);

    function setUp() public {
        // registry = IRegistryV2(rootRegistry.mintRegistryFor(BOB, "Test registry"));
        //all tests are done with version 2 of the store contract
    }

    function test_proxyUpgrade_defaultToLatest_WorksAutomatically() public {
        allow100StoresForDefaultAccounts();
        IRegistryV2 newReg = IRegistryV2(rootRegistry.mintRegistryFor(BOB, "Test registry", true));
        uint256 ORIGINAL_VERSION = IVersioned(address(newReg)).getVersion();
        uint256 NEXT_VERSION = IVersioned(address(registryV2DummyImplementation)).getVersion();
        assertTrue(address(newReg) != address(registryV2DummyImplementation), "impl2 and impl1 should be different");
        vm.label(address(newReg), "newReg");

        IRegistryProxyPointer pointer = IRegistryProxyPointer(address(newReg));
        assertTrue(pointer.IsDefaultingToLatestVersion(), "should not be using latest proxy as default");
        assertEq(pointer.resolveProxyVersion(), ORIGINAL_VERSION);
        assertEq(registryV2DummyImplementation.getVersion(), NEXT_VERSION);
        //check store namr
        assertEq(newReg.getName(), "Test registry");

        //we shoudl be able to add a payer as store owners
        vm.prank(BOB);
        newReg.addPayer(MARY);

        vm.prank(DEPLOYER);
        addressManager.setRegistryImplAddress(address(registryV2DummyImplementation));

        assertEq(newReg.getName(), "Test registry"); //new proxy shoudl take on old data
        assertEq(pointer.resolveProxyVersion(), NEXT_VERSION); //default should be the new proxy
        assertEq(pointer.resolveProxy(), address(registryV2DummyImplementation));

        assertEq(pointer.getPendingProxy(), address(registryV2DummyImplementation));
        assertEq(pointer.getPendingProxyVersion(), NEXT_VERSION);

        vm.startPrank(BOB);
        vm.expectRevert();
        pointer.upgradeProxy(); //already at latest
        //we shoudl STILL be able to add a payer as store owners

        newReg.addPayer(SAM); //should work as 're calling the pointer's address

        // IRegistryV2(pointer.resolveProxy()).addPayer(DAVID);  //<-- this is the wrong way to call it. Data is not initialized directly on the proxy impl. but shared by pointer

        IRegistryV2(address(pointer)).addPayer(DAVID); //<-- this is the correct way to call it
        vm.stopPrank();
    }

    function test_proxyUpgrade_notDefaultToLatest_toVersion3_works() public {
        allow100StoresForDefaultAccounts();
        IRegistryV2 newReg = IRegistryV2(rootRegistry.mintRegistryFor(BOB, "Test registry", false));
        uint256 ORIGINAL_VERSION = IVersioned(address(newReg)).getVersion();
        uint256 NEXT_VERSION = IVersioned(address(registryV2DummyImplementation)).getVersion();
        assertTrue(address(newReg) != address(registryV2DummyImplementation), "impl2 and impl1 should be different");
        vm.label(address(newReg), "newReg");

        IRegistryProxyPointer pointer = IRegistryProxyPointer(address(newReg));
        assertFalse(pointer.IsDefaultingToLatestVersion(), "should not be using latest proxy as default");
        assertEq(pointer.resolveProxyVersion(), ORIGINAL_VERSION);
        assertEq(IVersioned(address(newReg)).getVersion(), ORIGINAL_VERSION);
        assertEq(registryV2DummyImplementation.getVersion(), NEXT_VERSION);
        assertEq(newReg.getName(), "Test registry"); //new proxy shoudl take on old data

        vm.prank(DEPLOYER);
        addressManager.setRegistryImplAddress(address(registryV2DummyImplementation));

        assertEq(newReg.getName(), "Test registry"); //new proxy shoudl take on old data
        assertEq(pointer.resolveProxyVersion(), ORIGINAL_VERSION); //default shuld still be to the ol proxy
        assertEq(pointer.resolveProxy(), address(registry_implementation)); //still not upgraded since not usling default as ltest

        assertEq(pointer.getPendingProxy(), address(registryV2DummyImplementation)); //still not upgraded since not usling default as ltest
        assertEq(pointer.getPendingProxyVersion(), NEXT_VERSION);

        vm.startPrank(BOB);
        pointer.upgradeProxy();
        vm.stopPrank();
        assertEq(newReg.getName(), "Test registry"); //new proxy shoudl take on old data
        assertEq(pointer.resolveProxy(), address(registryV2DummyImplementation));
        assertEq(pointer.resolveProxyVersion(), NEXT_VERSION); // should be using the new proxy now
        assertEq(IVersioned(address(newReg)).getVersion(), NEXT_VERSION); //underlying version is 2
        assertEq(pointer.pointerVersion(), 1); //pointer version is still 1
    }
}
