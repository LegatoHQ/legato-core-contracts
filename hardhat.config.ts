import { HardhatUserConfig, task } from "hardhat/config";

import "@nomicfoundation/hardhat-toolbox";
import '@openzeppelin/hardhat-upgrades';
require("dotenv").config();
import "@nomicfoundation/hardhat-ethers";
require("hardhat-tracer");


const config: HardhatUserConfig = {
  typechain: {
    outDir: "typechain-types",
    target: "ethers-v5",
  },
  mocha: {
    timeout: 2000 * 10000
  },
  solidity: {
    version: "0.8.7",
    settings: {
      optimizer: {
        enabled: true,
        runs: 5,
      },
    },
  },
  etherscan: {
    apiKey: process.env.ETHERSCAN_API_KEY
  },
  networks: {
    polygon: {
      url: process.env.POLYGON_RPC || "",
      accounts: [process.env.WALLET_PK_MUMBAI || ""]
    },
    mumbai: {
      url: process.env.MUMBAI_RPC || "",
      accounts: [process.env.WALLET_PK_MUMBAI || ""]
    },
    localhost: {
      chainId: 31337,
    },
    hardhat: {
      chainId: 31337,
    },
  },
};

export default config;

