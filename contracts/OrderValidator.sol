// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import "./libraries/generateHash.sol";
import "./models/OrderModel.sol";

import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/draft-EIP712Upgradeable.sol";
// import "@openzeppelin/contracts-upgradeable/utils/cryptography/ECDSAUpgradeable.sol";
import "@openzeppelin/contracts/utils/cryptography/draft-EIP712.sol";
import "@openzeppelin/contracts/interfaces/IERC1271.sol";
import "hardhat/console.sol";
contract OrderValidator is Initializable, ContextUpgradeable, EIP712Upgradeable {
    using AddressUpgradeable for address;

    bytes4 constant internal MAGICVALUE = 0x1626ba7e;

    function __OrderValidator_init() internal initializer {
        __EIP712_init("NFT-Marketplace", "1");
    }

    function validate(
        OrderModel.Order memory order,
        bytes memory signature
    ) internal view {
        require(_msgSender() != order.maker, "order validation is not needed");

        bytes32 digest  = _hashTypedDataV4(generateHash.getOrderHash(order));
        
        if (order.maker.isContract()) {
            require(
                IERC1271(order.maker).isValidSignature(digest, signature) == MAGICVALUE,
                "order signature verification error"
            );
        } else {
            address signer;
            if(signature.length == 65) {
                signer = ECDSA.recover(digest, signature);
            }
            if(signer != order.maker) {
                revert("order signature verification error");    
            }
        }

    }

}