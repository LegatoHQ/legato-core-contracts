// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

///
/// @dev Interface for Intellectual Property Representation
///
interface ITokenized {
    function bindToken(address token) external;
    function addBinder(address _binder) external;
    function tokens() external returns (address[] memory);
}
