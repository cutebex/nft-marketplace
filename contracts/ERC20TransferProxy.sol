// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;
pragma abicoder v2;

import "./interfaces/IERC20TransferProxy.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract ERC20TransferProxy is IERC20TransferProxy, Initializable {
    function erc20safeTransferFrom(IERC20Upgradeable token, address from, address to, uint256 amount) override public {
        IERC20Upgradeable(token).transferFrom(from, to, amount);
    }
}
