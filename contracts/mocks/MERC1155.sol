// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "hardhat/console.sol";


contract MERC1155 is ERC1155 {

    constructor() public ERC1155("ERC1155") {
    }

    function mint() external {
        _mint(msg.sender, 0, 10**18, "");
        _mint(msg.sender, 1, 10**27, "");
        _mint(msg.sender, 2, 1, "");
        _mint(msg.sender, 3, 10**9, "");
        _mint(msg.sender, 4, 10**9, "");
    }

}
