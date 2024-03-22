import { ethers as et } from "ethers";
import { DEPLOYROOT, sendUsdcTo } from "../test/rootHelper";
import { HardhatEthersHelpers } from "@nomicfoundation/hardhat-ethers/types";
import {  USDC_POLYGON, _CONTRACTS_, WETH_POYGON } from "./deploy";

export async function mainDeployment(chainId: string, ethers: HardhatEthersHelpers) {
  if (ethers === undefined) {
    console.error("ethers is undefined");
    return;
  }
  console.log(
    "running deployment on chain id:",
    chainId,
    ethers.getContractFactory
  );
  const [signer] = await ethers.getSigners();
  const firstAddress = await signer.getAddress();
  const balance = await ethers.provider.getBalance(firstAddress);
  console.log("balance:", et.formatEther(balance.toString()));

  const NEW_HOLDER = "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266";
  //TRY USDC
  if (chainId === "31338") {
    //polygon fork
    const parseUnits = et.utils.parseUnits;
    const accounts = await ethers.getSigners();
    console.log("sending forked USDC...");
    for await (const account of accounts) {
      await sendUsdcTo(
        "1500",
        await account.getAddress(),
        process.env.USDC_SENDER!,
        USDC_POLYGON,
        ethers
      );
    }

    console.log("done sending USDC.");
    console.log("deploying WITH USDC and WETH");
    _CONTRACTS_ = await DEPLOYROOT(ethers, USDC_POLYGON, WETH_POYGON, chainId);
  } else {
    console.log("deploying without USDC and WETH");
    _CONTRACTS_ = await DEPLOYROOT(ethers, "", "", chainId);
  }

  const addr1 = await signer.getAddress();
  const LicenseBlueprintDeployer = await ethers.getContractFactory(
    "LicenseBlueprint"
  );
  console.log(`   //---------------`);

  // console.log("deployed license blueprints:");
  console.log(`    RPC:                "http://127.0.0.1:8545",`);
  console.log(`    REAL_USDC:          "FILL_THIS_IN"`);
  console.log();
  console.log();
  console.log();
  console.log("----------------------");
  const amount = ethers.parseEther("10");
  await _CONTRACTS_.fakeToken.transfer(NEW_HOLDER, amount);
  console.log("sent fakeToken to ", NEW_HOLDER, amount);
  console.log("----------------------");

  const balance2 = await ethers.provider.getBalance(firstAddress);
  console.log("balance AFTER:", et.formatEther(balance.toString()));
  // console.log({
  //   defaultBuyerFieldsAggregation: BUYER_AGG,
  //   defaultSellerFieldsForAggregation: SELLER_AGGREGATION,
  //   defaultSellerFieldsForSyncFilm: SELLER_SYNC,
  //   defaultBuyerFieldsForSyncFilm: BUYER_SYNC_FILM,
  //   defaultSellerFieldsForYoutube: SELLER_YOUTUBE,
  //   defaultBuyerFieldsForYoutube: BUYER_YOUTUBE,
  // })
  // await sendUsdcTo("15",newHolder,)
  // const root = await RootRegistryDeployer.deploy(unlockTime, { value: lockedAmount });
  // await lock.deployed();
  // console.log(`Lock with 1 ETH and unlock timestamp ${unlockTime} deployed to ${lock.address}`);
}
