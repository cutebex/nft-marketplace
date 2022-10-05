const { expect } = require("chai");
const { ethers, upgrades } = require("hardhat");
const {
  getAssetType,
  encodeData,
  ETH,
  ERC20,
  ERC721,
  ERC1155,
} = require("./helpers/helper");
const { AssetType, Asset, Order, sign } = require("./helpers/order");

const getSignature = async (order, signer, verifyingContract) => {
  return await sign(order, signer, verifyingContract);
};
const ZERO = ethers.constants.AddressZero;

describe("AssetMatcher Test", function () {
  let exchange;
  let merc20;
  let merc721;
  let merc1155;
  before(async () => {
    [user1, user2, user3] = await ethers.getSigners();
    const ExchangeV2Core = await ethers.getContractFactory("ExchangeV2Core");
    exchange = await upgrades.deployProxy(ExchangeV2Core);
    await exchange.deployed();

    const MERC20 = await ethers.getContractFactory("MERC20");
    merc20 = await MERC20.deploy("ERC20", "ERC20");
    await merc20.deployed();

    const MERC721 = await ethers.getContractFactory("MERC721");
    merc721 = await MERC721.deploy("ERC721", "ERC721");
    await merc721.deployed();

    const MERC1155 = await ethers.getContractFactory("MERC1155");
    merc1155 = await MERC1155.deploy();
    await merc1155.deployed();

    await merc20.selfMint(user1.address, 10000);
    await merc20.connect(user1).approve(exchange.address, 10000);
    await merc721.connect(user2).mint();
    await merc721.connect(user2).setApprovalForAll(exchange.address, true);
    await merc1155.connect(user2).mint();
    await merc1155.connect(user2).setApprovalForAll(exchange.address, true);

    makeOrders = async (maker, taker, amount1 = 150, amount2 = 1) => {
      const left = Order(
        maker,
        Asset(ERC20, encodeData(merc20.address), amount1),
        taker,
        Asset(ERC721, encodeData(merc721.address, 1), amount2),
        1,
        0,
        0,
        "0xffffffff",
        "0x"
      );
      const right = Order(
        taker,
        Asset(ERC721, encodeData(merc721.address, 1), amount2),
        maker,
        Asset(ERC20, encodeData(merc20.address), amount1),
        1,
        0,
        0,
        "0xffffffff",
        "0x"
      );
      return { left, right };
    };
  });

  describe("Order validation test", function () {
    it("maker and taker address is zero test", async () => {
      // console.log("user1 erc20 amount: ", await merc20.balanceOf(user1.address));
      const { left, right } = await makeOrders(user1.address, ZERO);

      const signature = await getSignature(
        left,
        user1.address,
        exchange.address
      );

      await expect(
        exchange.matchOrders(left, signature, right, "0x")
      ).to.be.revertedWith("maker and taker address is zero");
    });
    it("orderLeft maker and orderRight taker test", async () => {
      const { left, right } = await makeOrders(user1.address, user2.address);
      left.taker = user3.address;
      right.taker = user3.address;

      const signature = await getSignature(
        left,
        user1.address,
        exchange.address
      );
      await expect(
        exchange.matchOrders(left, signature, right, "0x")
      ).to.be.revertedWith("orderLeft maker isn't same as orderRight taker");
    });
    it("orderLeft taker and orderRight maker test", async () => {
      const { left, right } = await makeOrders(user1.address, user2.address);
      left.taker = user3.address;
      const signature = await getSignature(
        left,
        user1.address,
        exchange.address
      );
      await expect(
        exchange.matchOrders(left, signature, right, "0x")
      ).to.be.revertedWith("orderLeft taker isn't same as orderRight maker");
    });

    it("order start invalid test", async () => {
      const now = parseInt(new Date().getTime() / 1000);

      const { left, right } = await makeOrders(user1.address, user2.address);
      left.start = now + 1000;

      const signature = await getSignature(
        left,
        user1.address,
        exchange.address
      );
      await expect(
        exchange.connect(user1).matchOrders(left, signature, right, "0x")
      ).to.be.revertedWith("order start invalid");
    });

    it("order end invalid test", async () => {
      const now = parseInt(new Date().getTime() / 1000);

      const { left, right } = await makeOrders(user1.address, user2.address);
      left.end = now - 1000;

      const signature = await getSignature(
        left,
        user1.address,
        exchange.address
      );
      await expect(
        exchange.connect(user1).matchOrders(left, signature, right, "0x")
      ).to.be.revertedWith("order end invalid");
    });
    it("order validation is not needed test", async () => {
      const { left, right } = await makeOrders(user1.address, user2.address);

      const signature = await getSignature(
        left,
        user1.address,
        exchange.address
      );
      await expect(
        exchange.connect(user1).matchOrders(left, signature, right, "0x")
      ).to.be.revertedWith("order validation is not needed");
    });

    it("order signature verification error test", async () => {
      const left = Order(
        user1.address,
        Asset(ERC20, encodeData(merc20.address), 150),
        user2.address,
        Asset(ERC721, encodeData(merc721.address, 1), 1),
        1,
        0,
        0,
        "0xffffffff",
        "0x"
      );
      const right = Order(
        user2.address,
        Asset(ERC721, encodeData(merc721.address, 1), 1),
        user1.address,
        Asset(ERC20, encodeData(merc20.address), 150),
        1,
        0,
        0,
        "0xffffffff",
        "0x"
      );
      const signature = await getSignature(
        left,
        user2.address,
        exchange.address
      );
      await expect(
        exchange.connect(user3).matchOrders(left, signature, right, "0x")
      ).to.be.revertedWith("order signature verification error");
    });
  });

  describe("Order Asset match Test", function () {
    it("assets not matched test", async () => {
      const { left, right } = await makeOrders(user1.address, user2.address, 0);

      const signatureLeft = await getSignature(
        left,
        user1.address,
        exchange.address
      );
      const signatureRight = await getSignature(
        right,
        user2.address,
        exchange.address
      );
      await expect(
        exchange
          .connect(user3)
          .matchOrders(left, signatureLeft, right, signatureRight)
      ).to.be.revertedWith("order amount is not zero");
    });

    it("order amount is zero test", async () => {
      const { left, right } = await makeOrders(user1.address, user2.address, 0);
      const signatureLeft = await getSignature(
        left,
        user1.address,
        exchange.address
      );
      const signatureRight = await getSignature(
        right,
        user2.address,
        exchange.address
      );
      await expect(
        exchange
          .connect(user3)
          .matchOrders(left, signatureLeft, right, signatureRight)
      ).to.be.revertedWith("order amount is not zero");
    });

    it("order amount not matched test", async () => {
      const { left, right } = await makeOrders(user1.address, user2.address);
      left.makeAsset.amount = 300;
      const signatureLeft = await getSignature(
        left,
        user1.address,
        exchange.address
      );
      const signatureRight = await getSignature(
        right,
        user2.address,
        exchange.address
      );
      await expect(
        exchange
          .connect(user3)
          .matchOrders(left, signatureLeft, right, signatureRight)
      ).to.be.revertedWith("order amount not matched");
    });
    it("make asset not matched test", async () => {
      const { left, right } = await makeOrders(user1.address, user2.address);
      left.makeAsset = Asset(ETH, encodeData(ZERO), 100);
      const signatureLeft = await getSignature(
        left,
        user1.address,
        exchange.address
      );
      const signatureRight = await getSignature(
        right,
        user2.address,
        exchange.address
      );
      await expect(
        exchange
          .connect(user3)
          .matchOrders(left, signatureLeft, right, signatureRight)
      ).to.be.revertedWith("assets not matched");
    });
    it("take asset not matched test", async () => {
      const { left, right } = await makeOrders(user1.address, user2.address);
      left.takeAsset = Asset(ETH, encodeData(ZERO), 100);
      const signatureLeft = await getSignature(
        left,
        user1.address,
        exchange.address
      );
      const signatureRight = await getSignature(
        right,
        user2.address,
        exchange.address
      );
      await expect(
        exchange
          .connect(user3)
          .matchOrders(left, signatureLeft, right, signatureRight)
      ).to.be.revertedWith("assets not matched");
    });
    it("make asset not matched test", async () => {
      const { left, right } = await makeOrders(user1.address, user2.address);
      left.takeAsset = Asset(ERC721, encodeData(merc20.address), 100);
      const signatureLeft = await getSignature(
        left,
        user1.address,
        exchange.address
      );
      const signatureRight = await getSignature(
        right,
        user2.address,
        exchange.address
      );
      await expect(
        exchange
          .connect(user3)
          .matchOrders(left, signatureLeft, right, signatureRight)
      ).to.be.revertedWith("assets not matched");
    });

    it("make asset not matched test", async () => {
      const { left, right } = await makeOrders(user1.address, user2.address);
      left.takeAsset = Asset(ERC20, encodeData(merc20.address), 100);
      const signatureLeft = await getSignature(
        left,
        user1.address,
        exchange.address
      );
      const signatureRight = await getSignature(
        right,
        user2.address,
        exchange.address
      );
      await expect(
        exchange
          .connect(user3)
          .matchOrders(left, signatureLeft, right, signatureRight)
      ).to.be.revertedWith("assets not matched");
    });
  });

  describe("Order transfer test", function () {
    it("amount not enough test", async () => {
      const { left, right } = await makeOrders(user1.address, user2.address);
      left.makeAsset.assetType.tp = ETH;
      left.makeAsset.assetType.data = encodeData(ZERO);
      right.takeAsset.assetType.tp = ETH;
      right.takeAsset.assetType.data = encodeData(ZERO);
      const signatureLeft = await getSignature(
        left,
        user1.address,
        exchange.address
      );
      const signatureRight = await getSignature(
        right,
        user2.address,
        exchange.address
      );
      await expect(
        exchange
          .connect(user3)
          .matchOrders(left, signatureLeft, right, signatureRight),
        { value: 100 }
      ).to.be.revertedWith("amount not enough");
    });
    it("ERC721 amount error test", async () => {
      const { left, right } = await makeOrders(user1.address, user2.address);
      left.takeAsset.amount = 300;
      right.makeAsset.amount = 300;
      const signatureLeft = await getSignature(
        left,
        user1.address,
        exchange.address
      );
      const signatureRight = await getSignature(
        right,
        user2.address,
        exchange.address
      );
      await expect(
        exchange
          .connect(user3)
          .matchOrders(left, signatureLeft, right, signatureRight)
      ).to.be.revertedWith("ERC721 amount error");
    });
    it("ERC20 and ERC721 tokens transfer test", async () => {
      const { left, right } = await makeOrders(user1.address, user2.address);
      const signatureLeft = await getSignature(
        left,
        user1.address,
        exchange.address
      );
      const signatureRight = await getSignature(
        right,
        user2.address,
        exchange.address
      );
      
      expect(await merc20.balanceOf(user1.address)).to.be.equal(10000);
      expect(await merc20.balanceOf(user2.address)).to.be.equal(0);
      expect(await merc721.balanceOf(user1.address)).to.be.equal(0);
      expect(await merc721.balanceOf(user2.address)).to.be.equal(1);
      await exchange
        .connect(user3)
        .matchOrders(left, signatureLeft, right, signatureRight);
      expect(await merc20.balanceOf(user1.address)).to.be.equal(9850);
      expect(await merc20.balanceOf(user2.address)).to.be.equal(150);
      expect(await merc721.balanceOf(user1.address)).to.be.equal(1);
      expect(await merc721.balanceOf(user2.address)).to.be.equal(0);
    });

    it("ERC20 and ERC1155 tokens transfer test", async () => {
      const { left, right } = await makeOrders(user1.address, user2.address);
      left.takeAsset = Asset(
        ERC1155,
        encodeData(merc1155.address, 3),
        100000000
      );
      right.makeAsset = Asset(
        ERC1155,
        encodeData(merc1155.address, 3),
        100000000
      );
      const signatureLeft = await getSignature(
        left,
        user1.address,
        exchange.address
      );
      const signatureRight = await getSignature(
        right,
        user2.address,
        exchange.address
      );
      expect(await merc20.balanceOf(user1.address)).to.be.equal(9850);
      expect(await merc20.balanceOf(user2.address)).to.be.equal(150);
      expect(await merc1155.balanceOf(user1.address, 3)).to.be.equal(0);
      expect(await merc1155.balanceOf(user2.address, 3)).to.be.equal(1000000000);
      await exchange
        .connect(user3)
        .matchOrders(left, signatureLeft, right, signatureRight);
      expect(await merc20.balanceOf(user1.address)).to.be.equal(9700);
      expect(await merc20.balanceOf(user2.address)).to.be.equal(300);
      expect(await merc1155.balanceOf(user1.address, 3)).to.be.equal(100000000);
      expect(await merc1155.balanceOf(user2.address, 3)).to.be.equal(900000000);
    });

    it("ETH and ERC1155 tokens transfer test", async () => {
      const { left, right } = await makeOrders(user1.address, user2.address);
      left.takeAsset = Asset(
        ERC1155,
        encodeData(merc1155.address, 3),
        100000000
      );
      right.makeAsset = Asset(
        ERC1155,
        encodeData(merc1155.address, 3),
        100000000
      );
      const signatureLeft = await getSignature(
        left,
        user1.address,
        exchange.address
      );
      const signatureRight = await getSignature(
        right,
        user2.address,
        exchange.address
      );
      await exchange
        .connect(user3)
        .matchOrders(left, signatureLeft, right, signatureRight, {
          value: 100,
        });
    });

    it("order cancel not maker test", async () => {
      const { left, right } = await makeOrders(user1.address, user2.address);
      await expect(exchange.connect(user1).cancel(left)).to.be.revertedWith(
        "not maker"
      );
    });
    it("order cancel salt error test", async () => {
      const { left, right } = await makeOrders(user1.address, user2.address);
      left.salt = 0;
      await expect(exchange.connect(user3).cancel(left)).to.be.revertedWith(
        "salt error"
      );
    });
    it("order cancel test", async () => {
      const { left, right } = await makeOrders(user1.address, user2.address);
      await exchange.connect(user3).cancel(left);
    });
  });

  describe("direct test", function () {
    it("directPurchase test", async () => {
      await merc721.connect(user1).mint();
      await merc721.connect(user1).setApprovalForAll(exchange.address, true);
      // const left = Order(user1.address, Asset(ERC721, encodeData(merc721.address, 1), 1), ZERO, Asset(ETH, "0x", 100), 1, 0, 0, ORDER_DATA_V3_SELL, encDataLeft);
      const left = Order(
        user1.address,
        Asset(ERC721, encodeData(merc721.address, 2), 1),
        ZERO,
        Asset(ETH, encodeData(ZERO), 100),
        1,
        0,
        0,
        getAssetType("SELL"),
        "0x"
      );
      left.takeAsset.assetType.tp = ETH;
      left.takeAsset.assetType.data = "0x";
      const signature = await getSignature(
        left,
        user1.address,
        exchange.address
      );

      const directPurchase = {
        sellOrderMaker: user1.address,
        sellOrderNftAmount: 1,
        nftAssetClass: ERC721,
        nftData: encodeData(merc721.address, 2),
        sellOrderPaymentAmount: 100,
        paymentToken: ZERO,
        sellOrderSalt: 1,
        sellOrderStart: 0,
        sellOrderEnd: 0,
        sellOrderDataType: getAssetType("SELL"),
        sellOrderData: "0x",
        sellOrderSignature: signature,
        buyOrderPaymentAmount: 100,
        buyOrderNftAmount: 1,
        buyOrderData: "0x",
      };
      expect(await merc721.balanceOf(user1.address)).to.be.equal(2);
      expect(await merc721.balanceOf(user2.address)).to.be.equal(0);
      await exchange
        .connect(user2)
        .directPurchase(directPurchase, { value: 100 });
      expect(await merc721.balanceOf(user1.address)).to.be.equal(1);
      expect(await merc721.balanceOf(user2.address)).to.be.equal(1);
    });

    it("directAcceptBid test", async () => {
      const ZERO = ethers.constants.AddressZero;
      const left = Order(
        user1.address,
        Asset(ERC20, encodeData(merc20.address), 100),
        ZERO,
        Asset(ERC721, encodeData(merc721.address, 2), 1),
        1,
        0,
        0,
        getAssetType("BUY"),
        "0x"
      );
      const signature = await getSignature(
        left,
        user1.address,
        exchange.address
      );
      const directAccept = {
        bidMaker: user1.address,
        bidNftAmount: 1,
        nftAssetClass: ERC721,
        nftData: encodeData(merc721.address, 2),
        bidPaymentAmount: 100,
        paymentToken: merc20.address,
        bidSalt: 1,
        bidStart: 0,
        bidEnd: 0,
        bidDataType: getAssetType("BUY"),
        bidData: "0x",
        bidSignature: signature,
        sellOrderPaymentAmount: 100,
        sellOrderNftAmount: 1,
        sellOrderData: "0x",
      };
      expect(await merc721.balanceOf(user1.address)).to.be.equal(1);
      expect(await merc721.balanceOf(user2.address)).to.be.equal(1);
      expect(await merc20.balanceOf(user1.address)).to.be.equal(9550);
      expect(await merc20.balanceOf(user2.address)).to.be.equal(450);
      await exchange
        .connect(user2)
        .directAcceptBid(directAccept, { value: 100 });
      expect(await merc721.balanceOf(user1.address)).to.be.equal(2);
      expect(await merc721.balanceOf(user2.address)).to.be.equal(0);
      expect(await merc20.balanceOf(user1.address)).to.be.equal(9450);
      expect(await merc20.balanceOf(user2.address)).to.be.equal(550);
    });
  });
});
