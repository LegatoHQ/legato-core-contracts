// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

interface IRegistryProxyPointer {
    function pointerVersion() external pure returns (uint8);
    function initialize(string memory _name, address _ownerWallet, address _eternalStorage, bool _autoUpgrade)
        external;

    function upgradeProxy() external;

    function IsDefaultingToLatestVersion() external view returns (bool);
    function setUseLatestProxy(bool _setting) external;

    function resolveProxy() external view returns (address);
    function resolveProxyVersion() external view returns (uint256);

    function getPendingProxy() external view returns (address);
    function getPendingProxyVersion() external view returns (uint256);
}
