// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.7;

import "forge-std/Test.sol";

import "contracts/interfaces/IFeeDistributor.sol";
import "./dummies/FakeToken.sol";
import "./util/HelperContract.sol";
import "contracts/interfaces/IRoyaltyPortionToken.sol";
import "contracts/eip5553/IIPRepresentation.sol";
import "contracts/interfaces/Structs.sol";
import "forge-std/console.sol";
import "openzeppelin-contracts/token/ERC20/IERC20.sol";
import "contracts/dataBound/FeeDistributor/FeeDistributorV2.sol";

contract FeeDistributorV2Tests is HelperContract {
    function setUp() public {}

    function test_removeCurrency_WillNotShowUpInAllowedLis() external {
        vm.startPrank(DEPLOYER);
        assertEq(feeDistributor.getAllowedCurrencies().length, 1);
        feeDistributor.addCurrency(address(addressManager));
        assertEq(feeDistributor.getAllowedCurrencies().length, 2);

        vm.stopPrank();
    }

    function test_addCurrency_SameTwice_Reverts() external {
        vm.startPrank(DEPLOYER);
        feeDistributor.addCurrency(address(this));
        vm.stopPrank();
    }
}
