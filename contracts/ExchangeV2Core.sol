// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import "./models/OrderModel.sol";
import "./libraries/generateHash.sol";
import "./OrderValidator.sol";
import "./AssetMatcher.sol";

import "./TransferProxy.sol";
import "./ERC20TransferProxy.sol";

import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";

import "hardhat/console.sol";

contract ExchangeV2Core is
    ContextUpgradeable,
    OrderValidator,
    AssetMatcher,
    TransferProxy,
    ERC20TransferProxy
{
    uint256 private constant UINT256_MAX = 2**256 - 1;

    mapping(bytes32 => uint256) public fills;

    //events
    event Cancel(bytes32 hash);
    event Transfer(OrderModel.Asset asset, address from, address to);

    function initialize() public initializer {
        __OrderValidator_init();
    }

    function cancel(OrderModel.Order memory order) external {
        require(_msgSender() != order.maker, "not maker");
        require(order.salt != 0, "salt error");

        bytes32 orderHash = generateHash.getGeneralHash(order);
        fills[orderHash] = UINT256_MAX;

        emit Cancel(orderHash);
    }

     /**
    * @dev validate, match and transfer orders
    * @param orderLeft left order
    * @param signatureLeft order left signature
    * @param orderRight right order
    * @param signatureRight order right signature
    */
    function matchOrders(
        OrderModel.Order memory orderLeft,
        bytes memory signatureLeft,
        OrderModel.Order memory orderRight,
        bytes memory signatureRight
    ) external payable {
        // At frist, Orders are being validated by validateOrders() internal function, if error is find, function being reverted.
        validateOrders(orderLeft, signatureLeft, orderRight, signatureRight);

        matchAndTransfer(orderLeft, orderRight);
    }

    /**
    * @dev validate orders
    * @param orderLeft left order
    * @param signatureLeft order left signature
    * @param orderRight right order
    * @param signatureRight order right signature
    */
    function validateOrders(
        OrderModel.Order memory orderLeft,
        bytes memory signatureLeft,
        OrderModel.Order memory orderRight,
        bytes memory signatureRight
    ) internal view {
        require(
            orderLeft.taker != address(0) &&
            orderLeft.maker != address(0) &&
            orderRight.taker != address(0) &&
            orderRight.maker != address(0),
            "maker and taker address is zero"
        );

        require(
            orderLeft.maker == orderRight.taker,
            "orderLeft maker isn't same as orderRight taker"
        );
        require(
            orderLeft.taker == orderRight.maker,
            "orderLeft taker isn't same as orderRight maker"
        );
        validateOrder(orderLeft, signatureLeft);
        validateOrder(orderRight, signatureRight);
    }

    /**
    * @notice matches valid orders and transfers their assets
    * @param orderLeft the left order of the match
    * @param orderRight the right order of the match
    */
    function matchAndTransfer(
        OrderModel.Order memory orderLeft,
        OrderModel.Order memory orderRight
    ) internal {
        //fill the order if the left and right order are perfectly matched
        matchAssets(orderLeft, orderRight);

        require(
            orderLeft.makeAsset.amount > 0 &&
            orderLeft.takeAsset.amount > 0 &&
            orderRight.makeAsset.amount > 0 &&
            orderRight.takeAsset.amount > 0,
            "order amount is not zero"
        );
        require(
            orderLeft.makeAsset.amount == orderRight.takeAsset.amount &&
            orderLeft.takeAsset.amount == orderRight.makeAsset.amount,
            "order amount not matched"
        );

        setFillEmitMatch(orderLeft, orderRight);
        doTransfers(orderLeft, orderRight);
    }

    /**
    * @notice validate the order by signature using EIP712
    * @param order the order
    * @param signature the signature of the order
    */
    function validateOrder(OrderModel.Order memory order, bytes memory signature)
        internal
        view
    {
        OrderModel.orderValidation(order);
        validate(order, signature);
    }

    /**
    * @notice matches assetType of orders
    * @param orderLeft the left order of the match
    * @param orderRight the right order of the match
    */
    function matchAssets(
        OrderModel.Order memory orderLeft,
        OrderModel.Order memory orderRight
    ) internal pure {
        OrderModel.AssetType memory makeMatch = matchAssets(
            orderLeft.makeAsset.assetType,
            orderRight.takeAsset.assetType
        );
        require(makeMatch.tp != 0, "assets not matched");
        OrderModel.AssetType memory takeMatch = matchAssets(
            orderLeft.takeAsset.assetType,
            orderRight.makeAsset.assetType
        );
        require(takeMatch.tp != 0, "assets not matched");
    }

    function setFillEmitMatch(
        OrderModel.Order memory orderLeft,
        OrderModel.Order memory orderRight
    ) internal {
        bytes32 orderLeftHash = generateHash.getGeneralHash(orderLeft);
        bytes32 orderRightHash = generateHash.getGeneralHash(orderRight);

        fills[orderLeftHash] = orderLeft.takeAsset.amount;
        fills[orderRightHash] = orderRight.takeAsset.amount;
    }

    /**
    * @notice transfer assetType of orders
    * @param orderLeft the left order of the match
    * @param orderRight the right order of the match
    */
    function doTransfers(
        OrderModel.Order memory orderLeft,
        OrderModel.Order memory orderRight
    ) internal {
        doTransfer(orderLeft.makeAsset, orderLeft.maker, orderRight.maker);
        doTransfer(orderRight.makeAsset, orderRight.maker, orderLeft.maker);
    }

    function doTransfer(
        OrderModel.Asset memory asset,
        address from,
        address to
    ) internal {
        if (asset.assetType.tp == OrderModel.ETH_TYPE) {
            require(msg.value >= asset.amount, "amount not enough");
            payable(to).transfer(asset.amount);
        } else if (asset.assetType.tp == OrderModel.ERC20_TYPE) {
            address token = abi.decode(asset.assetType.data, (address));
            erc20safeTransferFrom(IERC20Upgradeable(token), from, to, asset.amount);
        } else if (asset.assetType.tp == OrderModel.ERC721_TYPE) {
            (address token, uint256 tokenId) = abi.decode(
                asset.assetType.data,
                (address, uint256)
            );
            require(asset.amount == 1, "ERC721 amount error");
            erc721safeTransferFrom(IERC721Upgradeable(token), from, to, tokenId);
        } else if (asset.assetType.tp == OrderModel.ERC1155_TYPE) {
            (address token, uint256 tokenId) = abi.decode(
                asset.assetType.data,
                (address, uint256)
            );
            erc1155safeTransferFrom(
                IERC1155Upgradeable(token),
                from,
                to,
                tokenId,
                asset.amount
            );
        }
        emit Transfer(asset, from, to);
    }

    function directPurchase(OrderModel.Purchase calldata direct)
        external
        payable
    {
        OrderModel.AssetType memory paymentAssetType = getPaymentAssetType(
            direct.paymentToken
        );

        OrderModel.Order memory sellOrder = OrderModel.Order(
            direct.sellOrderMaker,
            OrderModel.Asset(
                OrderModel.AssetType(direct.nftAssetClass, direct.nftData),
                direct.sellOrderNftAmount
            ),
            address(0),
            OrderModel.Asset(paymentAssetType, direct.sellOrderPaymentAmount),
            direct.sellOrderSalt,
            direct.sellOrderStart,
            direct.sellOrderEnd,
            direct.sellOrderDataType,
            direct.sellOrderData
        );

        OrderModel.Order memory buyOrder = OrderModel.Order(
            _msgSender(),
            OrderModel.Asset(paymentAssetType, direct.buyOrderPaymentAmount),
            address(0),
            OrderModel.Asset(
                OrderModel.AssetType(direct.nftAssetClass, direct.nftData),
                direct.buyOrderNftAmount
            ),
            0,
            0,
            0,
            direct.sellOrderDataType,
            direct.buyOrderData
        );

        validateOrder(sellOrder, direct.sellOrderSignature);

        matchAndTransfer(sellOrder, buyOrder);
    }

    function directAcceptBid(OrderModel.AcceptBid calldata direct)
        external
        payable
    {
        OrderModel.AssetType memory paymentAssetType = getPaymentAssetType(
            direct.paymentToken
        );

        OrderModel.Order memory buyOrder = OrderModel.Order(
            direct.bidMaker,
            OrderModel.Asset(paymentAssetType, direct.bidPaymentAmount),
            address(0),
            OrderModel.Asset(
                OrderModel.AssetType(direct.nftAssetClass, direct.nftData),
                direct.bidNftAmount
            ),
            direct.bidSalt,
            direct.bidStart,
            direct.bidEnd,
            direct.bidDataType,
            direct.bidData
        );

        OrderModel.Order memory sellOrder = OrderModel.Order(
            _msgSender(),
            OrderModel.Asset(
                OrderModel.AssetType(direct.nftAssetClass, direct.nftData),
                direct.sellOrderNftAmount
            ),
            address(0),
            OrderModel.Asset(paymentAssetType, direct.sellOrderPaymentAmount),
            0,
            0,
            0,
            direct.bidDataType,
            direct.sellOrderData
        );

        validateOrder(buyOrder, direct.bidSignature);

        matchAndTransfer(sellOrder, buyOrder);
    }

    function getPaymentAssetType(address token)
        internal
        pure
        returns (OrderModel.AssetType memory)
    {
        OrderModel.AssetType memory result;
        if (token == address(0)) {
            result.tp = OrderModel.ETH_TYPE;
        } else {
            result.tp = OrderModel.ERC20_TYPE;
            result.data = abi.encode(token);
        }
        return result;
    }
}
