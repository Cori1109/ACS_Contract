// const ZenZebra = artifacts.require("ZenZebra");
const ZenMarketplace = artifacts.require("ZenMarketplace");

module.exports = function (deployer) {
  deployer.deploy(
    // ZenZebra,
    // "0x9eE7b666C0F9140CE067f88Ef262FD3d8f2396Be",
    // "0x666A09f7f7cB56dF3Ce65144eb1A8A839b8cEA28"
    ZenMarketplace,
    1000
  );
};
