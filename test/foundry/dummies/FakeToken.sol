// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.7;

import "openzeppelin-contracts/token/ERC20/ERC20.sol";
import "forge-std/console.sol";

contract FakeTokenForTests is ERC20 {
    constructor(string memory _name, string memory _symbol) ERC20(_name, _symbol) {
        _mint(msg.sender, 10000000e18);
        // console.log("MINTED FAKE TOKEN");
    }
}
