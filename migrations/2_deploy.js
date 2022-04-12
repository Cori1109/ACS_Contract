const AltCoinStaking = artifacts.require("AltCoinStaking");

module.exports = function (deployer) {
  deployer.deploy(AltCoinStaking, "0xd136EB70B571cEf8Db36FAd5be07cB4F76905B64");
};
