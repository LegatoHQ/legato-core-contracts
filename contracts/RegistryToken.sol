// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "lib/forge-std/src/console.sol";

contract FakeToken is ERC20 {
    constructor(string memory _name, string memory _symbol) ERC20(_name, _symbol) {
        _mint(msg.sender, 100e18);
    }

    function drip() external {
        // require(totalSupply() < 1_000_000 * 1e21, "total supply is too high");
        // require(msg.sender == tx.origin, "no contracts");
        require(balanceOf(msg.sender) < 100e18, "Your balance is too high");
        _mint(msg.sender, 100e18);
    }
}
