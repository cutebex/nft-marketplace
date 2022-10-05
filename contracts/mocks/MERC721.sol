// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "hardhat/console.sol";


contract MERC721 is ERC721 {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
    
    constructor(
        string memory name,
        string memory symbol
    ) payable ERC721(name, symbol) {
    }

    function mint() public returns (uint256) {
        _tokenIds.increment();

        uint256 newItemId = _tokenIds.current();
        _safeMint(msg.sender, newItemId);
        return newItemId;
    }

}
