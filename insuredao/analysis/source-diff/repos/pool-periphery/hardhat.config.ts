import * as dotenv from "dotenv";

import { HardhatUserConfig, task } from "hardhat/config";
import "@nomiclabs/hardhat-etherscan";
import "@nomiclabs/hardhat-waffle";
import "@typechain/hardhat";
import "hardhat-gas-reporter";
import "solidity-coverage";

dotenv.config();

// This is a sample Hardhat task. To learn how to create your own go to
// https://hardhat.org/guides/create-task.html
task("accounts", "Prints the list of accounts", async (taskArgs, hre) => {
  const accounts = await hre.ethers.getSigners();

  for (const account of accounts) {
    console.log(account.address);
  }
});

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

const config: HardhatUserConfig = {
  solidity: {
    version: "0.8.10",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200000,
      },
    },
  },
  networks: {
    mainnet: {
      url: `${process.env.MAINNET_URL}`,
      accounts: [`0x${process.env.DEPLOY_KEY}`, `0x${process.env.CONTROL_KEY}`],
      gas: 6e6,
      gasPrice: 8e10,
      timeout: 2000000000,
    },
    astar: {
      url: process.env.ASTAR_URL,
      accounts: [`0x${process.env.DEPLOY_KEY}`, `0x${process.env.CONTROL_KEY}`],
      gasPrice: 3e9,
    },
    optimisticEthereum: {
      url: `${process.env.OPTIMISM_URL}`,
      accounts: [`0x${process.env.DEPLOY_KEY}`, `0x${process.env.CONTROL_KEY}`],
    },
    arbitrumOne: {
      url: process.env.ARBITRUM_URL,
      accounts: [`0x${process.env.DEPLOY_KEY}`],
    },
    goerli: {
      url: process.env.GOERLI_URL,
      accounts: [`0x${process.env.TEST_KEY}`],
    },
    optimisticGoerli: {
      url: process.env.OP_GOERLI_URL,
      accounts: [`0x${process.env.TEST_KEY}`],
    },
    arbitrumGoerli: {
      url: process.env.ARB_GOERLI_URL,
      accounts: [`0x${process.env.TEST_KEY}`],
    },
    mumbai: {
      url: process.env.MUMBAI_URL,
      accounts: [`0x${process.env.TEST_KEY}`],
    },
  },
  gasReporter: {
    enabled: process.env.REPORT_GAS !== undefined,
    currency: "USD",
  },
  etherscan: {
    apiKey: {
      mainnet: `${process.env.ETHERSCAN_API}`,
      goerli: `${process.env.ETHERSCAN_API}`,
      optimisticEthereum: `${process.env.OPT_ETHERSCAN_API}`,
      optimisticGoerli: `${process.env.OPT_ETHERSCAN_API}`,
      arbitrumOne: `${process.env.ARB_ETHERSCAN_API}`,
      arbitrumGoerli: `${process.env.ARB_ETHERSCAN_API}`,
    },
    customChains: [
      {
        network: "arbitrumGoerli",
        chainId: 421613,
        urls: {
          apiURL: "https://api-goerli.arbiscan.io/api",
          browserURL: "https://goerli.arbiscan.io/",
        },
      },
    ],
  },
};

export default config;
