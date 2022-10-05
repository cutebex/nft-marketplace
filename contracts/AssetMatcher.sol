// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import "./models/OrderModel.sol";

contract AssetMatcher {

    function matchAssets(
        OrderModel.AssetType memory leftAssetType,
        OrderModel.AssetType memory rightAssetType
    ) internal pure returns (
        OrderModel.AssetType memory
    ) {
        bytes4 leftType = leftAssetType.tp;
        bytes4 rightType = rightAssetType.tp;
        bytes32 leftDataHash = keccak256(leftAssetType.data);
        bytes32 rightDataHash = keccak256(rightAssetType.data);
        
        if(leftType == OrderModel.ETH_TYPE) {
            if(rightType == OrderModel.ETH_TYPE) {
                return leftAssetType;
            } else {
                return OrderModel.AssetType(0, "");
            }
        } else {
            if(leftType == rightType) {
                if(leftDataHash == rightDataHash) {
                    return leftAssetType;
                } else {
                    return OrderModel.AssetType(0, "");
                }
            } else {
                return OrderModel.AssetType(0, "");
            }
        }
        
    }

}