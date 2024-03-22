// SPDX-License-Identifier:  BUSL-1.1

pragma solidity ^0.8.7;

import "./EternalStorage.sol";
// import "../storage/IEternalStorage.sol";
import "./IStorageUtilsInheritor.sol";

/**
 * @dev Contract module which allows children to implement an emergency stop
 * mechanism that can be triggered by an authorized account.
 *
 * This module is used through inheritance. It will make available the
 * modifiers `whenNotPaused` and `whenPaused`, which can be applied to
 * the functions of your contract. Note that they will not be pausable by
 * simply including this module, only once the modifiers are put in place.
 */
abstract contract PausableStorage {
    function getStorage() internal view virtual returns (address);
    function getPrefix() internal view virtual returns (string memory);
    /**
     * @dev Emitted when the pause is triggered by `account`.
     */

    event Paused(address account);

    /**
     * @dev Emitted when the pause is lifted by `account`.
     */
    event Unpaused(address account);

    /**
     * @dev Modifier to make a function callable only when the contract is not paused.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    modifier whenNotPaused() {
        _requireNotPaused();
        _;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is paused.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    modifier whenPaused() {
        _requirePaused();
        _;
    }

    /**
     * @dev Returns true if the contract is paused, and false otherwise.
     */
    function paused() public view virtual returns (bool) {
        return IEternalStorage(getStorage()).getBooleanValue(
            keccak256(abi.encodePacked(getPrefix(), "pausable", "paused"))
        );
    }

    /**
     * @dev Throws if the contract is paused.
     */
    function _requireNotPaused() internal view virtual {
        bool isPaused = IEternalStorage(getStorage()).getBooleanValue(
            keccak256(abi.encodePacked(getPrefix(), "pausable", "paused"))
        );
        require(!isPaused, "Pausable: paused");
    }

    /**
     * @dev Throws if the contract is not paused.
     */
    function _requirePaused() internal view virtual {
        bool isPaused = IEternalStorage(getStorage()).getBooleanValue(
            keccak256(abi.encodePacked(getPrefix(), "pausable", "paused"))
        );
        require(isPaused, "Pausable: not paused");
    }

    /**
     * @dev Triggers stopped state.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    function _pause() internal virtual whenNotPaused {
        IEternalStorage(getStorage()).setBooleanValue(
            keccak256(abi.encodePacked(getPrefix(), "pausable", "paused")), true
        );
        emit Paused(msg.sender);
    }

    /**
     * @dev Returns to normal state.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    function _unpause() internal virtual whenPaused {
        IEternalStorage(getStorage()).setBooleanValue(
            keccak256(abi.encodePacked(getPrefix(), "pausable", "paused")), false
        );
        emit Unpaused(msg.sender);
    }

    uint256[50] private __gap;
}
