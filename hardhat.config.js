require("@nomicfoundation/hardhat-toolbox");
require('dotenv').config();

const { ADMIN_PRIVATE_KEY, AMOYSCAN_API, SEPOLIASCAN_API, AMOY_API_URL, SEPOLIA_API_URL } = process.env;

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  defaultNetwork: "hardhat",
  networks: {
      hardhat: {
      },
      sepolia: {
        url: SEPOLIA_API_URL,
        accounts: [ADMIN_PRIVATE_KEY]
      },
      amoy: {
        url: AMOY_API_URL,
        accounts: [ADMIN_PRIVATE_KEY]
      },
    },
    etherscan: {
      apiKey: SEPOLIASCAN_API 
    },
    solidity: {
      version: "0.8.26",
    },
    paths: {
      sources: "./contracts",
      tests: "./test",
      cache: "./cache",
      artifacts: "./contracts/artifacts"
    },
    sourcify: {
      enabled: true
    },
  mocha: {
    timeout: 20000
  },
};