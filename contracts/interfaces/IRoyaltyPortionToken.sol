// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import "./Structs.sol";

/// @notice  an ERC20 that acts as a royalty interest token
/// i.e we can use the holders of this token as a representation of who shoudl get how much % of any future money distribution in a licensing deal, for example
interface IRoyaltyPortionToken {
    /// @notice returns a string representing what kind of ROyalty interest this is.
    /// i.e in the music business this might be "Recording" or "Composition" royalty interests
    function kind() external view returns (string memory);

    /// @notice returns a fixed amoutn of tokens that cannot be changed and represent 100% of the royalty interest for this token.
    /// i.e ideally you'd just return '100' here , where each token represents 1% of a royalty interest.
    function max() external view returns (uint256);

    /// @return the address of the contract or EOA that initialized the work registration that is the parent of this royalty interest
    /// @dev i.e a registery or registrar, to be implemented in the future
    function ledger() external view returns (address);

    /// @return the address of the parent work that this royalty interest is bound to
    /// @dev there is a 1-many relationship between a work and royalty interest tokens
    /// for example, 1 song work, might have two royualty interest tokens, one representing the writing side,and another token representing a recording side
    /// a royalty interest token can only belong to a single work, and once bound, can never change a parent
    function parentIP() external view returns (address);

    /// @return an array of Balance structs : Balance {address holder, uint256 amount}
    /// @dev this array represt ALL past and current holders of the ERC20 underlying token,
    /// with current active balance
    /// this takes some work but it helps discover all holders of a royalty interest in a single logical place.
    /// see example implementation of this in SongRegistration.sol
    function getHolders() external view returns (Balance[] memory);
}
