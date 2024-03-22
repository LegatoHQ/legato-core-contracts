import { HardhatUserConfig, task } from "hardhat/config";

// import { HardhatRuntimeEnvironment } from "hardhat/types";
import { mainDeployment } from "./scripts/mainDeployment";
import "@nomicfoundation/hardhat-toolbox";
// import { deploySingleLicense } from "./scripts/deploy_only_aggLicense";
import { addCurrency, deploySingleLicenseFileWithIpfsAndEth } from "./scripts/deploy_license_file";
import { convertJsonToTableDocx, processDocx } from "./scripts/helpers/openaiHelper";
import path from "path";
import { resolve } from "path";
import '@openzeppelin/hardhat-upgrades';
import { HardhatEthersHelpers } from "hardhat/types";
import { doDeployProxy } from "./scripts/helpers/proxyDeployer";
require("dotenv").config();
import "@nomicfoundation/hardhat-ethers";
import { hasRestParameter } from "typescript";
import { DEPLOYFeeDistV3 } from "./test/deployFeeDistV3";
import { downloadVideo, summerizeTextFromFile, transcribeAudio, transcribeFromUrl } from "./scripts/helpers/openaiTranscriber";
import { downloadFromInfo } from "ytdl-core";
require("hardhat-tracer");

task("jsonToTable", "converts json to table docx")
  .addParam("path", "path of the json file")
  .setAction(async ({ path }, { ethers }) => {
    try {
      // console.log(ethers.getContractFactory)
      await convertJsonToTableDocx(resolve(path));
    } catch (error) {
      console.log(error);
    }
  });


task("summerize", "youtube")
  .addParam("url", "path of the audio file")
  .addOptionalParam("textfile", "path of the descriptor file")
  .setAction(async ({ url, textfile }, { ethers }) => {
    try {
      // console.log(ethers.getContractFactory)
      if(textfile){ 
        console.log("SUMMERIZING TEXT fROM FILE");
        await summerizeTextFromFile(resolve(textfile));
      }else{
        console.log("SUMMERIZING TEXT FROM URL");
        await transcribeFromUrl(url);
      }
      // await transcribeAudio(resolve(path));
    } catch (error) {
      console.log(error);
    }
  });


task("docjson", "converts docx to json")
  .addParam("path", "path of the docx file")
  .setAction(async ({ path }, { ethers }) => {
    try {
      await processDocx(resolve(path));
    } catch (error) {
      console.log(error);
    }
  });



task("add-currency", "adds currency to fee dist")
  .addParam("currency", "address of currency")
  .addParam("feedist", "address of feedist")
  .addParam("chainid", "chain id (137 polygon)")
  .setAction(async ({ currency, feedist, chainid }, { ethers }) => {
    try {
      await addCurrency(currency, feedist, chainid, ethers);
    } catch (error) {
      console.log(error);
    }
  });

task("license", "deploys license")
  .addParam("name", "license name")
  .addParam("pdfpath", "path of the pdf file")
  .addParam("descpath", "path of the descriptor file")
  .addParam(
    "reg",
    "address of the license registry",
    "0x15993662556bd062f0Af819B780A62AEC0D528Ba"
  )
  .addOptionalParam("chainid", "id of the chain in hardhat config.", "31338")
  .setAction(async ({ pdfpath, descpath, name, reg, chainid }, { ethers }) => {
    try {
      // console.log(ethers.getContractFactory)
      await deploySingleLicenseFileWithIpfsAndEth(
        path.resolve(pdfpath),
        path.resolve(descpath),
        name,
        reg,
        chainid,
        ethers);
    } catch (error) {
      console.log(error);
    }
  });

task("deployProxy", "upgrades feedist")
  .addOptionalParam("chainid", "id of the chain in hardhat config.", "31338")
  .setAction(async ({ chainid }, { upgrades, ethers }) => {
    try {

      console.log("deploying proxy");
      // console.log("signers", (await ethers.getSigners())[0]);
      // console.log("upgrades:", upgrades);
      await doDeployProxy(ethers, upgrades);
      console.log("done deploying proxy");
    } catch (error) {
      console.log(error);

    }
  });
task("legato", "deploys legato")
  .addOptionalParam("chainid", "id of the chain in hardhat config.", "31338")
  .setAction(async ({ chainid }, { ethers }) => {
    try {
      // console.log(ethers.getContractFactory)
      //signers
      await mainDeployment(chainid, ethers);
    } catch (error) {
      console.log(error);
    }
  });

// task("feeDistv3", "deploys feeDistributor V3")
//   .addOptionalParam("chainid", "id of the chain in hardhat config.", "31338")
//   .setAction(async ({ chainid }, { ethers }) => {
//     try {
//       // console.log(ethers.getContractFactory)
//       //signers
//       await DEPLOYFeeDistV3(chainid, ethers);
//     } catch (error) {
//       console.log(error);
//     }
//   });

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
      url: "https://crimson-dawn-layer.matic-testnet.quiknode.pro/2f96338b3a272ff0801a885469489d340d782714",
      accounts: [process.env.WALLET_PK_MUMBAI || ""]
    },
    localhost: {
      chainId: 31337,
      // forking: {
      //   url: process.env.POLYGON_RPC || "NO ENV VARIABLE FOUND FOR POLYGON_RPC",
      // },
      mining: {
        // auto: false,
        // interval: 2000
      }
    },
    hardhat: {
      chainId: 31337,
      // forking: {
      //   url: process.env.POLYGON_RPC || "NO ENV VARIABLE FOUND FOR POLYGON_RPC",
      // },
      // mining: {
        // auto: false,
        // interval: 2000
      // }
    },
  },
};

export default config;

