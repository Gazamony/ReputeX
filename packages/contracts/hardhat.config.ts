import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "@openzeppelin/hardhat-upgrades";
import "@typechain/hardhat";
import "solidity-coverage";
import "dotenv/config";

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
      chainId: 123,
    },
    "iopn-mainnet": {
      url: process.env.IOPN_MAINNET_RPC || "https://mainnet-rpc.iopn.io",
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [],
      chainId: 456,
    },
  },
  etherscan: {
    apiKey: {
      "iopn-testnet": process.env.IOPN_ETHERSCAN_API_KEY || "",
      "iopn-mainnet": process.env.IOPN_ETHERSCAN_API_KEY || "",
    },
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
};

export default config;
