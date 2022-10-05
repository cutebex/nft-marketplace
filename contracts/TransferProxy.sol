// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;
pragma abicoder v2;

import "./models/OrderModel.sol";
import "./interfaces/ITransferProxy.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract TransferProxy is ITransferProxy, Initializable {

    function erc721safeTransferFrom(IERC721Upgradeable token, address from, address to, uint256 tokenId) override public {
        IERC721Upgradeable(token).safeTransferFrom(from, to, tokenId);
    }

    function erc1155safeTransferFrom(IERC1155Upgradeable token, address from, address to, uint256 id, uint256 amount) override public {
        IERC1155Upgradeable(token).safeTransferFrom(from, to, id, amount, "");
    }
}
