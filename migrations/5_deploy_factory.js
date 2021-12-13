const { deployProxy } = require('@openzeppelin/truffle-upgrades');
const PuggNFT = artifacts.require("PuggNFT");
const TESTToken = artifacts.require("TESTToken");
const TESTToken_6 = artifacts.require("TESTToken_6");
const PuggNFTSale = artifacts.require("PuggNFTSale");


module.exports = async function (deployer) {
  // const nft = await PuggNFT.deployed();
  // const tESTToken = await TESTToken.deployed();
  // const tESTToken_6 = await TESTToken_6.deployed();
  // await deployProxy(PuggNFTSale, [nft.address, tESTToken_6.address, tESTToken.address, ""], { deployer, initializer: '__initialize' });
};
