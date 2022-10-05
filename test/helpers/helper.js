const ethUtil = require('ethereumjs-util');
const Web3 = require("web3");
const web3 = new Web3();

function getAssetType(str) {
	const buff = Buffer.from(str, "utf-8");
	return `0x${ethUtil.keccak256(buff).toString("hex").substring(0, 8)}`;
}

function encodeData(token, tokenId) {
	if (tokenId) {
		return web3.eth.abi.encodeParameters(["address", "uint256"], [token, tokenId]);
	} else {
		return web3.eth.abi.encodeParameter("address", token);
	}
}

const ETH = getAssetType("ETH");
const ERC20 = getAssetType("ERC20");
const ERC721 = getAssetType("ERC721");
const ERC1155 = getAssetType("ERC1155");

module.exports = { getAssetType, encodeData, ETH, ERC20, ERC721, ERC1155 }
