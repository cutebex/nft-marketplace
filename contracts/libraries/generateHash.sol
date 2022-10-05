// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import "../models/OrderModel.sol";

library generateHash {

    bytes32 constant ORDER_TYPEHASH = keccak256(
        "Order(address maker,Asset makeAsset,address taker,Asset takeAsset,uint256 salt,uint256 start,uint256 end,bytes4 dataType,bytes data)Asset(AssetType assetType,uint256 amount)AssetType(bytes4 tp,bytes data)"
    );

    bytes32 constant ASSET_TYPE_TYPEHASH = keccak256(
        "AssetType(bytes4 tp,bytes data)"
    );

    bytes32 constant ASSET_TYPEHASH = keccak256(
        "Asset(AssetType assetType,uint256 amount)AssetType(bytes4 tp,bytes data)"
    );
    
    function getAssetTypeHash(OrderModel.AssetType memory assetType) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            ASSET_TYPE_TYPEHASH,
            assetType.tp,
            keccak256(assetType.data)
        ));
    }

    function getAssetHash(OrderModel.Asset memory asset) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            ASSET_TYPEHASH,
            getAssetTypeHash(asset.assetType),
            asset.amount
        ));
    }

    function getOrderHash(OrderModel.Order memory order) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            ORDER_TYPEHASH,
            order.maker,
            getAssetHash(order.makeAsset),
            order.taker,
            getAssetHash(order.takeAsset),
            order.salt,
            order.start,
            order.end,
            order.dataType,
            keccak256(order.data)
        ));
    }

    function getGeneralHash(OrderModel.Order memory order) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            order.maker,
            getAssetTypeHash(order.makeAsset.assetType),
            getAssetTypeHash(order.takeAsset.assetType),
            order.salt,
            order.data
        ));
    }

}