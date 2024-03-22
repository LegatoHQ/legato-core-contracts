// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import {DenounceReason} from "./BlanketStructs.sol";

interface IRootRegistryV2 {
    error NotAdminRole();
    error CallerIsNotListed();

    event RegistryCreated(address indexed _regAddress, address indexed _for, address indexed _by);
    event RegistryDelisted(address indexed _registry);
    event StoreOwnershipTransferred(address indexed _registry, address indexed ownerOut, address indexed ownerIn);
    event StoreDenounced(address indexed _registry, DenounceReason reason);

    function getBlueprintImplementation() external view returns (address);
    function getRegistryCount() external view returns (uint256);
    function getAllRegistries() external view returns (address[] memory);
    function getRegistriesByWallet(address _for) external view returns (address[] memory);
    function getAllRegistriesByWallet(address _for) external view returns (address[] memory);
    function getDenouncedRegistries() external view returns (address[] memory);
    function mintRegistryFor(address _for, string memory _name, bool _autoUpgrade) external returns (address);
    function transferStoreOwnership(address _registry, address currentOwner, address newOwner) external;
    function delistStoreByOwner(address _registry) external;
    function isValidRegistry(address _registry) external view returns (bool);
}
