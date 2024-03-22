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

contract TokenDistributorTest is HelperContract {
    function setUp() public {}

    function test_WhenTransferringTokens_ToNewWallet_YouCanFindAllTokensForThatWallet() external {
        assertEq(tokenDistributor.getAssociatedTokens(JANE).length, 0);
        assertEq(tokenDistributor.getAssociatedTokens(BOB).length, 0);
        assertEq(tokenDistributor.getAssociatedTokens(MARY).length, 0);
        assertEq(tokenDistributor.getAssociatedTokens(DAVID).length, 0);

        addFakeLicenseBlueprint(licenseRegistry);

        vm.prank(BOB);
        address song = mintSongBlueprintAs();
        BlueprintV2 songBP = BlueprintV2(song);

        assertEq(tokenDistributor.getAssociatedTokens(BOB).length, 2);
        assertEq(tokenDistributor.getAssociatedTokens(BOB)[0], address(songBP.royaltyPortionTokens()[0]));
        assertEq(tokenDistributor.getAssociatedTokens(BOB)[1], address(songBP.royaltyPortionTokens()[1]));

        //get tokens of song
        BaseIPPortionToken token1 = BaseIPPortionToken(address(songBP.royaltyPortionTokens()[0]));
        assertEq(tokenDistributor.getAssociatedTokens(DAVID).length, 0);
        vm.startPrank(BOB);
        token1.transfer(DAVID, 10);
        vm.stopPrank();
        assertEq(tokenDistributor.getAssociatedTokens(DAVID).length, 1);
        assertEq(tokenDistributor.getAssociatedTokens(DAVID)[0], address(token1));
        vm.startPrank(DAVID);
        token1.transfer(JANE, 5);
        vm.stopPrank();
        assertEq(tokenDistributor.getAssociatedTokens(JANE).length, 1);
        assertEq(tokenDistributor.getAssociatedTokens(JANE)[0], address(token1));
    }

    function test_mintStoreToken_DoesNotAddUpTo100_Reverts() public {
        RoyaltyTokenData memory token;

        token.kind = "some generic type";
        token.name = "token name";
        token.symbol = "token symbol";
        token.memo = "memo";
        token.targets = new SplitTarget[](2);
        token.targets[0] = SplitTarget({holderAddress: BOB, amount: 1e18, memo: ""});
        token.targets[1] = SplitTarget({holderAddress: MARY, amount: 98e18, memo: ""});

        vm.expectRevert("split does not add up to 100");
        vm.prank(BOB);
        registry.mintStoreToken(token);
    }

    function test_mintStoreToken_with10_000_Splits_ShoudlWork() public {
        RoyaltyTokenData memory token;

        token.kind = "some generic type";
        token.name = "token name";
        token.symbol = "token symbol";
        token.memo = "memo";
        token.targets = new SplitTarget[](10 * 1000);
        uint256 amountToGive = 100 ether / token.targets.length;
        for (uint256 i = 0; i < token.targets.length; i++) {
            token.targets[i] = SplitTarget({holderAddress: BOB, amount: amountToGive, memo: ""});
        }
        vm.prank(BOB);
        registry.mintStoreToken(token);
        vm.prank(BOB);
        registry.addPayer(MARY);

        _fundAndApproveUSDC(MARY, address(feeDistributor), 100e6, 100e6);

        vm.prank(MARY);
        registry.externalPayment(
            ExternalPaymentRequest({
                target: address(registry),
                amount: 10e6, //10 USDC
                currency: USDC_ADDRESS,
                memo: "some memo",
                payer: MARY
            })
        );
    }
}
