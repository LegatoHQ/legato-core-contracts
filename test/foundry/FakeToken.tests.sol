// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.7;

import "forge-std/Test.sol";

import "contracts/interfaces/IFeeDistributor.sol";
import "contracts/RegistryToken.sol";
import "./util/HelperContract.sol";
import "contracts/interfaces/IRoyaltyPortionToken.sol";
import "contracts/eip5553/IIPRepresentation.sol";
import "contracts/interfaces/Structs.sol";
import "forge-std/console.sol";
import "openzeppelin-contracts/token/ERC20/IERC20.sol";

interface IFakeToken {
    function drip() external;
    function balanceOf(address account) external view returns (uint256);
}

contract FakeTokenTests is HelperContract {
// function setUp() public {}

// function test_dripToken() external {
//     IFakeToken token = IFakeToken(USDC_ADDRESS);
//     assertEq(token.balanceOf(BOB), 0);

//     vm.startPrank(BOB, BOB);
//     token.drip();
//     vm.stopPrank();

//     assertEq(token.balanceOf(BOB), 100e18);
// }
}
