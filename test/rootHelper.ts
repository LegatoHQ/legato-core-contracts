import "@nomicfoundation/hardhat-ethers";
import { HardhatEthersHelpers } from "@nomicfoundation/hardhat-ethers/types";
import { _____x, _____ll, __GRANT_ALLOWER_ONLY, __WAIT, addressOf, DEPLOY_CONTRACT_FULL, DEPLOY_STORAGE_AND_ADDRESS_MANAGER, deployLicenseBlueprints, runSmokeTestAfterDeploy, __DEPLOY_ONLY, DEPLOY_CONTRACT_UPGRADE } from "./deployHelpers";
import { LicenseRegistry__factory } from "../typechain-types";
import { RootRegistry__factory } from "../typechain-types/factories/contracts/RootRegistry.sol";
import { getAddress, getIcapAddress, verifyMessage } from "ethers";

export async function DEPLOYROOT(
  ethers: HardhatEthersHelpers,
  usdcAddress: string,
  wethAddress: string,
  chainId: string,
  etherscanVerify: boolean = false

) {

  const EternalStorageDeployer = await ethers.getContractFactory("EternalStorage");
  const AddressManagerDeployer = await ethers.getContractFactory("AddressManager");
  const VerifyHelperDeployer = await ethers.getContractFactory("VerifyHelper");
  const LicenseRegistryDeployer = await ethers.getContractFactory("LicenseRegistry");
  const LegatoLicenseDeployer = await ethers.getContractFactory("LegatoLicense");
  const FakeTokenDeployer = await ethers.getContractFactory("FakeToken");
  const FeeDistDeployer = await ethers.getContractFactory("FeeDistributor");
  const TokenDistDeployer = await ethers.getContractFactory("TokenDistributor");
  const RootRegistryDeployer = await ethers.getContractFactory("RootRegistry");
  const RegistryV2Deployer = await ethers.getContractFactory("RegistryImplV1");
  const registryProxyPointerDeployer = await ethers.getContractFactory("RegistryProxyPointer");
  const storageContractPointerDeployer = await ethers.getContractFactory("StorageContractPointer");
  const BlueprintV2Deployer = await ethers.getContractFactory("BlueprintV2");
  const BaseMusicPortionTokenDeployer = await ethers.getContractFactory("BaseIPPortionToken");
  const FeeDist_V2_Deployer = await ethers.getContractFactory("FeeDistributorV2");
  const FeeDist_V3_Deployer = await ethers.getContractFactory("FeeDistributorV3");
  const LegatoLicense_V2_Deployer = await ethers.getContractFactory("LegatoLicenseV2");

  const ALLOWED_TRUE = true;

  // console.log(ethers);
  const addr1 = await addressOf((await ethers.getSigners())[0]);

  interface deployParams {
    deployer: any,
    name: string,
    ctorArgs?: any | undefined,
    initArgs?: any | undefined,
    storageAccess: boolean
    storageInstance: any,
    addrMgrInstance: any
  }
  _____x("deploying ALL CONTRACTS");

  let TX;
  //--------------ETERNAL STORAGE AND ADDRESS MANAGER-----------------------
  const { storageInstance, addrMgrInstance } =
    await DEPLOY_STORAGE_AND_ADDRESS_MANAGER(
      addr1,
      EternalStorageDeployer,
      AddressManagerDeployer,
      chainId);

  const addrStorage = await addressOf(storageInstance);

  ///---------------STORAGE CONTRACT POINTER IMPL----------------------

  const storageContractPointerImpl = await DEPLOY_CONTRACT_FULL({
    deployer: storageContractPointerDeployer,
    name: "contracts.storageContractPointerImpl",
    ctorArgs: undefined,
    initArgs: undefined,
    storageAccess: false,
    storageInstance,
    addrMgrInstance,
    chainId
  })
  ///-------------LICENSE REGISTRY---------------------------
  const licenseRegistry = await DEPLOY_CONTRACT_FULL({
    deployer: LicenseRegistryDeployer,
    name: "contracts.licenseRegistry",
    ctorArgs: undefined,
    initArgs: [addrStorage, addr1],
    storageAccess: ALLOWED_TRUE,
    storageInstance,
    addrMgrInstance,
    chainId,
    wrapWithPointer: true
  })

  ///-----------VERIFY HELPER-------------------------
  const verifyHelper = await DEPLOY_CONTRACT_FULL({
    deployer: VerifyHelperDeployer,
    name: "contracts.verifyHelper",
    ctorArgs: undefined,
    initArgs: [addrStorage],
    storageAccess: ALLOWED_TRUE,
    storageInstance,
    addrMgrInstance,
    chainId
    , wrapWithPointer: true
  })

  ///-----------------FAKE TOKEN-------------------------
  const fakeToken = await DEPLOY_CONTRACT_FULL({
    deployer: FakeTokenDeployer,
    name: "contracts.fakeToken",
    ctorArgs: ["Legato Token", "Legato"],
    initArgs: undefined,
    storageAccess: false,
    storageInstance,
    addrMgrInstance,
    chainId
  })

  ///--------------BASE IP PORTION TOKEN IMPL----------
  const addr = await (await ethers.getSigner(addr1)).getAddress();
  const baseMusicPortionTokenImpl = await DEPLOY_CONTRACT_FULL({
    deployer: BaseMusicPortionTokenDeployer,
    name: "contracts.baseIPPortionTokenImpl",
    ctorArgs: [addr1, addr1, addr1, "", "", ""],
    initArgs: undefined,
    storageAccess: false,
    storageInstance,
    addrMgrInstance,
    chainId
  })


  ///----------------ROOT REGISTRY-----------------------------
  const ROOT_REGISTRY = await DEPLOY_CONTRACT_FULL({
    deployer: RootRegistryDeployer,
    name: "contracts.rootRegistry",
    ctorArgs: undefined,
    initArgs: [addrStorage],
    storageAccess: ALLOWED_TRUE,
    storageInstance,
    addrMgrInstance,
    chainId,
    wrapWithPointer: true,
    postDeployFn: async (newInstance: any) => {
      _____ll("storage granting allower to root");
      _____ll("storage: ", await addressOf(storageInstance));
      _____ll("root: ", newInstance.target);
      await __GRANT_ALLOWER_ONLY(newInstance.target, storageInstance, chainId, "contracts.rootRegistry");
    }
  })
  // console.log("root registery created at :", ROOT_REGISTRY.target);

  ///--------------LEGATO LICENSE--------------------------------
  const legatoLicense = await DEPLOY_CONTRACT_FULL({
    deployer: LegatoLicenseDeployer,
    name: "contracts.licenseContract",
    ctorArgs: undefined,
    initArgs: undefined,
    storageAccess: false,
    storageInstance,
    addrMgrInstance,
    chainId,
    postDeployFn: async (newInstance: any) => {
      _____ll("legatoLicense granting admin to root", await addressOf(ROOT_REGISTRY));
      TX = await newInstance.grantAdmin(await addressOf(ROOT_REGISTRY));
      await __WAIT(TX, chainId);
    }
  })


  ///------------TOKEN DISTRIBUTOR---------
  const tokenDist = await DEPLOY_CONTRACT_FULL({
    deployer: TokenDistDeployer,
    name: "contracts.tokenDistributor",
    ctorArgs: undefined,
    initArgs: [addrStorage, addr],
    storageAccess: ALLOWED_TRUE,
    storageInstance,
    addrMgrInstance,
    chainId,
    wrapWithPointer: true,
    postDeployFn: async (newInstance: any) => {
      _____ll("tokenDist granting admin to root", await addressOf(ROOT_REGISTRY));
      TX = await newInstance.grantAdmin(await addressOf(ROOT_REGISTRY));
      await __WAIT(TX, chainId);
    }
  })

  ///-----------REGISTRY STORE PROXY POINTER (USER UPGRADABLE)---------------------------
  const registryProxyPointer = await DEPLOY_CONTRACT_FULL({
    deployer: registryProxyPointerDeployer,
    name: "contracts.registryProxyPointerImpl",
    ctorArgs: undefined,
    initArgs: undefined,
    storageAccess: false,
    storageInstance,
    addrMgrInstance,
    chainId
  });

  ///-------------REGISTRY IMPL---------------------------------
  const registry_impl = await DEPLOY_CONTRACT_FULL({
    deployer: RegistryV2Deployer,
    name: "contracts.registryImplementation",
    ctorArgs: undefined,
    initArgs: undefined,
    storageAccess: false,
    storageInstance,
    addrMgrInstance,
    chainId
  })
  ///----------Song Blueprint IMPL-----------------------
  const blueprint_impl = await DEPLOY_CONTRACT_FULL({
    deployer: BlueprintV2Deployer,
    name: "contracts.blueprintImplementation",
    ctorArgs: [0, addr1, "", "", "", "", ""],
    initArgs: undefined,
    storageAccess: false,
    storageInstance,
    addrMgrInstance,
    chainId
  })
  ///-----------FEE DIST V1-------------------------
  const feeDist = await DEPLOY_CONTRACT_FULL({
    deployer: FeeDistDeployer,
    name: "contracts.feeDistributor",
    ctorArgs: undefined,
    initArgs: [addrStorage, addr, await addressOf(fakeToken), 10000],
    storageAccess: ALLOWED_TRUE,
    storageInstance,
    addrMgrInstance,
    chainId,
    wrapWithPointer: true,
    postDeployFn: async (newInstance: any) => {
      _____ll("feeDist granting admin to root", await addressOf(ROOT_REGISTRY));
      TX = await newInstance.grantAdmin(await addressOf(ROOT_REGISTRY));
      await __WAIT(TX, chainId);
      if (usdcAddress !== "") {
        _____ll("adding currency to fee dist", usdcAddress);
        TX = await newInstance.addCurrency(usdcAddress);
        await __WAIT(TX, chainId);
        _____x("added usdc address to fee dist", usdcAddress);
      } else {
        _____ll(
          "SKIPPED USDC ADDRESS setting for non fake token since it was an empty parameter"
        );
      }
    }
  })

  ///-----------FEE DIST V2-------------------------
  const feeDistV2 = await DEPLOY_CONTRACT_UPGRADE({
    deployer: FeeDist_V2_Deployer,
    name: "contracts.feeDistributor", //the name the previous version was deployed with
    versionName: "v2",
    chainId,
    addrMgrInstance,
    storageInstance,
    storageAccess: false,
    hasPointer: true,
  });

  ///-----------LegatoLicense V2-------------------------
  const legatoLicenseV2 = await DEPLOY_CONTRACT_FULL({
    deployer: LegatoLicense_V2_Deployer,
    name: "contracts.licenseContractV2", //the name the previous version was deployed with
    chainId,
    addrMgrInstance,
    storageInstance,
    storageAccess: true,
    hasPointer: true,
    wrapWithPointer: true,
    initArgs: [addr1, await addressOf(addrMgrInstance)],

    postDeployFn: async (newInstance: any) => {
      _____ll("legatoLicenseV2 granting admin to addr1", addr1);
      // TX = await newInstance.grantAdmin(addr1);
      const rootRegAddress = await addrMgrInstance.getRootRegistry();
      const rootReg = await RootRegistry__factory.connect(rootRegAddress, RootRegistryDeployer.runner as any);
      _____ll("getting list of stores")
      const stores = await rootReg.getAllRegistries();
      console.log(stores);
      _____ll("got stores list, found ", stores.length.toString(), "stores")
      for (let i = 0; i < stores.length; i++) {
        const store = stores[i];
        _____ll("legatoLicensev2 granting minter to store", store);
        await newInstance.grantMinter(store);
      }
      _____ll("done");
      const rootToGrantTo = await addrMgrInstance.getRootRegistry();
      _____ll("legatoLicensev2 granting admin to root", rootToGrantTo);
      TX = await newInstance.grantAdmin(rootToGrantTo);
      await __WAIT(TX, chainId);

      _____ll("replacing address of licenseContract with pointer to V2");
      _____ll(await addrMgrInstance.getLicenseContract(), "will change to:");
      _____ll(await addressOf(newInstance));
      TX = await addrMgrInstance.changeContractAddressDangerous("contracts.licenseContract", await addressOf(newInstance));
      await __WAIT(TX, chainId);
    }
  });

  ///-----------FEE DIST V3-------------------------
  const feeDistV3 = await DEPLOY_CONTRACT_UPGRADE({
    deployer: FeeDist_V3_Deployer,
    name: "contracts.feeDistributor", //the name the previous version was deployed with
    versionName: "v3",
    chainId,
    addrMgrInstance,
    storageInstance,
    storageAccess: false,
    hasPointer: true,
  });
  ///-----------------------------
  const rootAddress = await addressOf(ROOT_REGISTRY);
  const addressOfRegistryImpl = await addressOf(registry_impl);
  const addressOfBlurptintImpl = await addressOf(blueprint_impl);
  const addressOfLicenseRegistry = await addressOf(licenseRegistry);
  const addressOfLegatoLicense = await addressOf(legatoLicense);
  const addressOffakeToken = await addressOf(fakeToken);
  const addressOfFeeDist = await addressOf(feeDist);
  const addressOfTokenDist = await addressOf(tokenDist);
  const addressOfVerifyHelper = await addressOf(verifyHelper);
  const addressManagerAddress = await addressOf(addrMgrInstance);

  const allContracts = {
    root: ROOT_REGISTRY,
    licenseRegistry,
    legatoLicense,
    fakeToken,
    feeDist,
    tokenDist,
    verifyHelper,
    eternalStorage: storageInstance,
    addressManager: addrMgrInstance,
  }

  await deployLicenseBlueprints(ethers, allContracts, chainId);
  await runSmokeTestAfterDeploy(allContracts, chainId, ethers);


  _____x();
  _____x();
  _____x();
  _____x();

  const output = `  
    //--------------------------------
    IMPL_REGISTRY:        "${addressOfRegistryImpl}",
    IMPL_BLUEPRINTV2:     "${addressOfBlurptintImpl}",
    IMPL_BASETOKEN:       "${await addressOf(baseMusicPortionTokenImpl)}",
    //--------------------------------
    ROOT_REGISTRY:        "${rootAddress}",
    LICENSE_REGISTRY:     "${addressOfLicenseRegistry}",
    FEE_DISTRIBUTOR:      "${addressOfFeeDist}",
    TOKEN_DISTRIBUTOR:    "${addressOfTokenDist}",
    LEGATO_LICENSE:       "${addressOfLegatoLicense}",
    VERIFY_HELPER:        "${addressOfVerifyHelper}", 
    FAKE_USDC:            "${addressOffakeToken}",
    ADDRESS_MANAGER:      "${addressManagerAddress}",
    ETERNAL_STORAGE:      "${addrStorage}",
    `
    ;

  console.log(output);
  console.log();


  return allContracts;
}





