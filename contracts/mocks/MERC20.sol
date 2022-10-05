// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "hardhat/console.sol";

contract MERC20 is ERC20 {
    constructor(
        string memory name,
        string memory symbol
    ) payable ERC20(name, symbol) {
    }

    function selfMint(address account, uint256 amount) public {
        _mint(account, amount);
    }
}
