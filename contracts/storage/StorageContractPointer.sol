// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import "contracts/storage/AddressManager.sol";
import "contracts/storage/IAddressInitializable.sol";
import "contracts/dataBound/CommonUpgradeableStorageVars.sol";

contract StorageContractPointer is IAddressInitiailizable, CommonUpgradeableStorageVars {
    address immutable self;
    address public owner;
    string public alwaysPointsTo;

    constructor() {
        self = address(this);
        owner = msg.sender;
    }

    /// @dev Prevent direct calls
    modifier notSelf() {
        require(address(this) != self);
        _;
    }

    modifier onlyOwner() {
        // Only the node operator can upgrade
        require(msg.sender == owner, "Only owner can upgrade");
        _;
    }

    uint256 depth;

    /// @notice Sets up starting delegate contract and then delegates initialisation to it
    function initializeAddresses(string memory _pointToName, address _ownerWallet, address _addressManager)
        external
        override
    {
        require(!isInitialized[address(this)], "Pointer Already initialised");
        isInitialized[address(this)] = true;
        // console.log("StoragePointer.initialize depth: %s", depth);
        owner = _ownerWallet;
        addressManagerAddress = _addressManager;
        eternalStorageAddress = AddressManager(address(addressManagerAddress)).getStorageAddress();
        // console.log("StoragePointer.initialize addressmgr:: %s", _addressManager);
        alwaysPointsTo = _pointToName;
        // console.log("StoragePointer.initialize: point to %s", _pointToName);
    }

    function getUnderlyingAddress() private view returns (address) {
        AddressManager am = AddressManager(addressManagerAddress);
        address result = am.getContractAddress(alwaysPointsTo);
        return result;
    }

    receive() external payable notSelf {}

    ///----DELEGATE CALL HELPERS--------------

    /**
     * @dev Delegate call to the actual implementation
     * @param _input - call data
     * @return - call result
     * @notice - this function is called when no other function matches the call
     * @notice - resoves the correct underlying contract address dynamically by address manager
     */
    fallback(bytes calldata _input) external payable returns (bytes memory) {
        // console.log("StoragePointer.fallback: input: %s", string(_input));
        // console.log("StoragePointer.fallback: addressManager: %s", addressManager);
        // console.log("StoragePointer.fallback: delegate to %s", delegateContract);
        AddressManager am = AddressManager(addressManagerAddress);
        address delegateContract = am.getContractAddress(alwaysPointsTo);
        require(contractExists(delegateContract), "Impl contract does not exist");

        ///----------------- Delegate call to the actual implementation -----------------
        (bool success, bytes memory data) = delegateContract.delegatecall(_input);
        ///----------------- End delegate call to the actual implementation -----------------
        if (!success) revert(getRevertMessage(data));
        // --depth;
        return data;
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

    uint256[45] private __gap;
}
