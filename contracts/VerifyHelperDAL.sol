// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import "contracts/storage/EternalStorage.sol";
import "contracts/storage/DALBase.sol";

contract VerifyHelperDAL is DALBase {
    function PREFIX() public pure override returns (string memory) {
        return "verifyHelper";
    }
}
