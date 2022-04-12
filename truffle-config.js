const HDWalletProvider = require("@truffle/hdwallet-provider");
require("dotenv").config();

module.exports = {
  networks: {
    development: {
      host: "127.0.0.1", // Localhost (default: none)
      port: 8545, // Standard Ethereum port (default: none)
      network_id: "*", // Any network (default: none)
    },
    mainnet: {
      provider: () =>
        new HDWalletProvider(
          process.env.MNEMONIC,
          `https://mainnet.infura.io/v3/${process.env.INFURA_PROJECT_ID}`
        ),
      network_id: "1",
      skipDryRun: true,
    },
    ropsten: {
      provider: () =>
        new HDWalletProvider(
          process.env.MNEMONIC,
          `https://ropsten.infura.io/v3/${process.env.INFURA_PROJECT_ID}`
        ),
      network_id: 3,
      networkCheckTimeout: "30000",
      skipDryRun: true,
    },
    rinkeby: {
      provider: () =>
        new HDWalletProvider(
          process.env.MNEMONIC,
          `https://rinkeby.infura.io/v3/${process.env.INFURA_PROJECT_ID}`
        ),
      network_id: 4,
      networkCheckTimeout: "30000",
      skipDryRun: true,
    },
    mumbai: {
      provider: () =>
        new HDWalletProvider(
          process.env.MNEMONIC,
          "https://polygon-mumbai.g.alchemy.com/v2/ssVft5x5v9KTuKKUG4DyjM7dW15YkDmS"
        ),
      network_id: 80001,
      networkCheckTimeout: "30000",
      skipDryRun: true,
    },
  },

  // Configure your compilers
  compilers: {
    solc: {
      version: "0.8.4",
      settings: {
        optimizer: {
          enabled: true,
          runs: 200,
        },
        evmVersion: "byzantium",
      },
    },
  },
  api_keys: {
    // etherscan: process.env.ETHERSCAN_API_KEY,
    etherscan: process.env.POLYGONSCAN_API_KEY,
  },
  plugins: ["truffle-plugin-verify"],
};
