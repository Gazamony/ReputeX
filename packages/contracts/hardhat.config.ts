import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "@openzeppelin/hardhat-upgrades";
import "@typechain/hardhat";
import "hardhat-contract-sizer";
import "solidity-coverage";
import * as dotenv from "dotenv";

dotenv.config();

const config: HardhatUserConfig = {
  solidity: {
    version: "0.8.24",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
  networks: {
    hardhat: {
      chainId: 1337,
    },
    "iopn-testnet": {
      url: process.env.IOPN_TESTNET_RPC || "https://testnet-rpc.iopn.io",
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [],
      chainId: 1883,
    },
    "iopn-mainnet": {
      url: process.env.IOPN_MAINNET_RPC || "https://mainnet-rpc.iopn.io",
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [],
      chainId: 1882,
    },
  },
  etherscan: {
    apiKey: {
      "iopn-testnet": process.env.IOPN_ETHERSCAN_API_KEY || "",
      "iopn-mainnet": process.env.IOPN_ETHERSCAN_API_KEY || "",
    },
    customChains: [
      {
        network: "iopn-testnet",
        chainId: 1883,
        urls: {
          apiURL: "https://testnet-explorer.iopn.io/api",
          browserURL: "https://testnet-explorer.iopn.io",
        },
      },
      {
        network: "iopn-mainnet",
        chainId: 1882,
        urls: {
          apiURL: "https://explorer.iopn.io/api",
          browserURL: "https://explorer.iopn.io",
        },
      },
    ],
  },
  paths: {
    sources: "./contracts",
    tests: "./test",
    cache: "./cache",
    artifacts: "./artifacts",
  },
  typechain: {
    outDir: "typechain-types",
    target: "ethers-v6",
  },
  contractSizer: {
    runOnCompile: true,
    only: ["LaunchpadToken", "BondingCurveAMM", "LaunchpadFactory"],
  },
  mocha: {
    timeout: 40000,
  },
};

export default config;
