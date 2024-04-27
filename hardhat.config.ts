import { HardhatUserConfig, task } from "hardhat/config";
import { deplooy } from "contractoor";

import "@nomicfoundation/hardhat-toolbox-viem";
import "@nomicfoundation/hardhat-toolbox";
import '@openzeppelin/hardhat-upgrades';
require("dotenv").config();
import "@nomicfoundation/hardhat-ethers";


task("deploy", "Deploys contracts based on the configuration", async (_, hre) => {
  await hre.run('compile'); // Ensure contracts are compiled before deployment
  const rootDir = "./contracts"; // Specify the root directory for your contracts
  const configFilePath = "./contractoor.config.ts"; // Specify the path to your configuration file
  await deplooy({ hre, rootDir, configFilePath });
});

const config: HardhatUserConfig = {
  // typechain: {
  //   outDir: "typechain-types",
  //   target: "ethers-v5",
  // },
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
  // etherscan: {
  //   apiKey: process.env.ETHERSCAN_API_KEY
  // },
  networks: {
     // for testnet
     'base-sepolia': {
      url: 'https://sepolia.base.org',
      accounts: [process.env.WALLET_KEY as string],
      gasPrice: 1000000000,
    },
    // polygon: {
    //   url: process.env.POLYGON_RPC || "",
    //   accounts: [process.env.WALLET_PK_POLYGON || ""]
    // } ,
    
    // hardhat: {
    //   chainId: 31337,
    // } 

  },
  //   mumbai: {
  //     url: process.env.MUMBAI_RPC || "",
  //     accounts: [process.env.WALLET_PK_MUMBAI || ""]
  //   },
  //   localhost: {
  //     chainId: 31337,
    // },
  // },
  // },
};

export default config;

