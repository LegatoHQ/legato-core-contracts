// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import "lib/openzeppelin-contracts/contracts/utils/Counters.sol";
import "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "lib/openzeppelin-contracts/contracts/security/Pausable.sol";
import "contracts/interfaces/Structs.sol";
import "contracts/interfaces/BlanketStructs.sol";
import "contracts/interfaces/ILicenseBlueprint.sol";
import "lib/forge-std/src/console.sol";
import "contracts/storage/EternalStorage.sol";
import "contracts/storage/DALBase.sol";

contract TokenDistributorDAL is DALBase {
    string public constant WALLET_TO_TOKENS = "walletToTokens";

    function PREFIX() public pure override returns (string memory) {
        return "tokenDistributor.";
    }

    function _data_getBaseIPPortionTokenImpl() internal view returns (address) {
        return AddressManager(getAddressManager()).getBaseIPPortionTokenImpl();
    }

    function _data_pushTokensToWallet(address _wallet, address _tokenAddress) internal {
        __DATA__.pushToAddressList(PACK(WALLET_TO_TOKENS, _wallet), _tokenAddress);
    }

    function _data_getTokensForWallet(address _wallet) internal view returns (address[] memory) {
        return __DATA__.getAddressListValue(PACK(WALLET_TO_TOKENS, _wallet));
    }
}
