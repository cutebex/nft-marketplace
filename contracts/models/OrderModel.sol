// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;
import "hardhat/console.sol";
library OrderModel {

    bytes4 constant public ETH_TYPE = bytes4(keccak256("ETH"));
    bytes4 constant public ERC20_TYPE = bytes4(keccak256("ERC20"));
    bytes4 constant public ERC721_TYPE = bytes4(keccak256("ERC721"));
    bytes4 constant public ERC1155_TYPE = bytes4(keccak256("ERC1155"));

    struct AssetType {
        bytes4 tp;
        bytes data;
    }

    struct Asset {
        AssetType assetType;
        uint amount;
    }

    struct Order {
        address maker;
        Asset makeAsset;
        address taker;
        Asset takeAsset;
        uint salt;
        uint start;
        uint end;
        bytes4 dataType;
        bytes data;
    }

    struct Purchase {
        address sellOrderMaker;
        uint256 sellOrderNftAmount;
        bytes4 nftAssetClass;
        bytes nftData;
        uint256 sellOrderPaymentAmount;
        address paymentToken;
        uint256 sellOrderSalt;
        uint sellOrderStart;
        uint sellOrderEnd;
        bytes4 sellOrderDataType;
        bytes sellOrderData;
        bytes sellOrderSignature;
        
        uint256 buyOrderPaymentAmount;
        uint256 buyOrderNftAmount;
        bytes buyOrderData;
    }

    struct AcceptBid {
        address bidMaker;
        uint256 bidNftAmount;
        bytes4 nftAssetClass;
        bytes nftData;
        uint256 bidPaymentAmount;
        address paymentToken;
        uint256 bidSalt;
        uint bidStart;
        uint bidEnd;
        bytes4 bidDataType;
        bytes bidData;
        bytes bidSignature;

        uint256 sellOrderPaymentAmount;
        uint256 sellOrderNftAmount;
        bytes sellOrderData;
    }

    function orderValidation(Order memory order) internal view {
        require(order.start == 0 || order.start < block.timestamp, "order start invalid");
        require(order.end == 0 || order.end > block.timestamp, "order end invalid");
    }
    
}