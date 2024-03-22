// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import "./RegistryStorageLayout.sol";
import "./IRegistryProxyPointer.sol";
import "./RegistryStorageLayout.sol";
import "./IRegistryV2.sol";
import "../Cloner.sol";

/// @notice Contains the initialization and Impl upgrade logic
contract RegistryProxyPointer is IRegistryProxyPointer, RegistryStorageLayout {
    // Events
    // event EtherReceived(address indexed from, uint256 amount, uint256 time);
    event Upgraded(address oldImpl, address newImpl, uint256 time);

    function pointerVersion() external pure override returns (uint8) {
        return 1;
    }

    address immutable self;
    uint256 pointerNonce;
    address public storeOwner;

    constructor() {
        self = address(this);
    }

    /// @dev Prevent direct calls
    modifier notSelf() {
        require(address(this) != self);
        _;
    }

    modifier onlyOwner() {
        // Only the node operator can upgrade
        require(msg.sender == storeOwner, "Only owner can upgrade");
        _;
    }

    /// @notice Sets up starting delegate contract and then delegates initialisation to it
    function initialize(string memory _name, address _ownerWallet, address _eternalStorage, bool _autoUpgrade)
        external
        override
        notSelf
    {
        // Check input
        require(storageState == StorageState.Undefined, "Already initialised");
        storageState = StorageState.Uninitialised;
        storeOwner = _ownerWallet;
        useLatest = _autoUpgrade;

        __DATA__ = EternalStorage(_eternalStorage);

        actualImpl = getRegistryImplAddress();
        require(contractExists(actualImpl), "Registry Impl contract does not exist");

        pointerNonce = __DATA__.nonce();
        (bool success, bytes memory data) = actualImpl.delegatecall(
            abi.encodeWithSignature(
                "initialize(string,address,address,uint256)", _name, _ownerWallet, _eternalStorage, pointerNonce
            )
        );
        if (!success) revert(getRevertMessage(data));
    }

    function upgradeProxy() external override onlyOwner notSelf {
        require(storageState == StorageState.Initialised, "Not initialised");
        require(!useLatest, "Already defaulting to latest version");
        require(contractExists(getRegistryImplAddress()), "New impl contract does not exist");
        require(getRegistryImplAddress() != actualImpl, "New implementation is the same as the existing one");
        require(
            IVersioned(getRegistryImplAddress()).getVersion() > IVersioned(actualImpl).getVersion(),
            "New implementation is not newer than the existing one"
        );
        address prevImpl = actualImpl;
        actualImpl = getRegistryImplAddress();
        require(actualImpl != prevImpl, "New implementation is the same as the existing one");
        emit Upgraded(prevImpl, actualImpl, block.timestamp);
    }

    /// @notice Sets the flag to automatically use the latest impl address
    /// @param _setting If true, will always use the latest impl contract
    function setUseLatestProxy(bool _setting) external override onlyOwner notSelf {
        useLatest = _setting;
    }

    function IsDefaultingToLatestVersion() external view override returns (bool) {
        return useLatest;
    }

    function resolveProxyVersion() public view override returns (uint256) {
        return IVersioned(resolveProxy()).getVersion();
    }

    function resolveProxy() public view override returns (address) {
        return useLatest ? getRegistryImplAddress() : actualImpl;
    }

    fallback(bytes calldata _input) external payable notSelf returns (bytes memory) {
        // If useLatest is set, use the latest delegate contract
        address delegateContract = useLatest ? getRegistryImplAddress() : actualImpl;
        // Check for contract existence
        require(contractExists(delegateContract), "Impl contract does not exist");
        // Execute delegatecall
        (bool success, bytes memory data) = delegateContract.delegatecall(_input);
        if (!success) revert(getRevertMessage(data));
        return data;
    }

    receive() external payable notSelf {
        // Emit ether received event
        // emit EtherReceived(msg.sender, msg.value, block.timestamp);
    }
    /// @dev Get the address of the global registry proxy

    function getRegistryImplAddress() private view returns (address) {
        return AddressManager(__DATA__.getAddressManager()).getRegistryImpl();
    }

    function getPendingProxy() external view override returns (address) {
        return getRegistryImplAddress();
    }

    function getPendingProxyVersion() external view override returns (uint256) {
        return (IVersioned(getRegistryImplAddress())).getVersion();
    }

    /// @dev Get a revert message from delegatecall return data
    function getRevertMessage(bytes memory _returnData) private pure returns (string memory) {
        if (_returnData.length < 68) return "Transaction reverted silently";
        assembly {
            _returnData := add(_returnData, 0x04)
        }
        return abi.decode(_returnData, (string));
    }

    /// @dev Returns true if contract exists at _contractAddress (if called during that contract's construction it will return a false negative)
    function contractExists(address _contractAddress) private view returns (bool) {
        uint32 codeSize;
        assembly {
            codeSize := extcodesize(_contractAddress)
        }
        return codeSize > 0;
    }
}
