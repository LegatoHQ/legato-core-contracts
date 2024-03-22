import { expect, version } from "chai";
import { ethers } from "hardhat";
import { mainDeployment } from "../scripts/mainDeployment";
import { DEPLOYROOT } from "./rootHelper";
import { TransactionReceipt, Typed } from "ethers";
import { __WAIT, _____ll, addressOf } from "./deployHelpers";

describe("RootRegistry", function () {
  it("can run maindeployment script", async () => {
    await mainDeployment("localhost", ethers);
  });

  it("can upgrade FeeDistributor and register address instead of old one", async () => {
    const [owner] = await ethers.getSigners();
    const { addressManager, eternalStorage, feeDist, fakeToken } = await DEPLOYROOT(
      ethers,
      "",
      "",
      "localhost"
    );
    expect(await feeDist.getVersion()).to.eq(3);

     } );

  it("can be deployed and mint a registry", async () => {
    const singers = await ethers.getSigners();
    const [owner, otherAccount] = singers;
    // const {root,licenseRegistry,legatoLicense,fakeToken,feeDist,tokenDist,verifyHelper} = await deployRoot();
    const { root, licenseRegistry, legatoLicense } = await DEPLOYROOT(
      ethers,
      "",
      "",
      "localhost"
    );
    console.log("minted root");
    expect((await root.getAllRegistries()).length).to.eq(1);
    expect(await root.getRegistryCount()).to.eq(1);

    const tx = await root.mintRegistryFor(owner.address, "", false);
    const receipt: TransactionReceipt = await tx.wait();

    expect((await root.getAllRegistries()).length).to.eq(2);
    expect(await root.getRegistryCount()).to.eq(2);
    const newRegAddress = (await root.getAllRegistries())[1];

    await tryMintingASongInStore(newRegAddress, owner, otherAccount, licenseRegistry, legatoLicense);
  });

  describe("Registry Store Upgrades", function () {
    it("needs to be forced to upgrade without auto upgrade", async () => {
      const signers = await ethers.getSigners();
      const [owner, otherAccount] = signers;
      const { root, addressManager } = await DEPLOYROOT(ethers, "", "", "localhost");
      const tx = await root.mintRegistryFor(owner.address, "Bobs Registry", false); //<--- key it is NOT auto upgradeable
      const newRegAddress = (await root.getAllRegistries())[1]; //first one is the one created in deployment smoke test
      const pointedStore = await ethers.getContractAt("IRegistryV2", newRegAddress);
      const pointer = await ethers.getContractAt("IRegistryProxyPointer", newRegAddress);
      const pointedVersion = await ethers.getContractAt("IVersioned", newRegAddress);

      expect(await pointer.resolveProxyVersion()).to.eq(1);
      expect(await pointedVersion.getVersion()).to.eq(1);

      const newReg = await ethers.getContractFactory("RegistryImplV2Dummy");
      const newRegImpl = await newReg.deploy();
      const newRegImplAddress = await addressOf(newRegImpl);
      // /register the addressin address manager

      // Test that the pointer is not using the latest proxy by default
      expect(await pointer.IsDefaultingToLatestVersion()).to.be.false;

      // Test that the pointer is pointing to the correct version of the registry
      expect(await pointer.resolveProxyVersion()).to.eq(1);

      expect(await pointedVersion.getVersion()).to.eq(1);

      // Test that the new registry implementation is not the same as the old one
      expect(newRegImplAddress).to.not.eq(await addressOf(pointedStore));

      // Test that the pointer is not using the latest proxy after the upgrade
      await addressManager.setRegistryImplAddress(newRegImplAddress);
      expect(await pointer.IsDefaultingToLatestVersion()).to.be.false;
      expect(await pointer.resolveProxyVersion()).to.eq(1);
      expect(await pointedVersion.getVersion()).to.eq(1);

      // Test that the pointer has the correct pending proxy
      expect(await pointer.getPendingProxy()).to.eq(newRegImplAddress);

      // Test that the pointer has the correct pending proxy version
      expect(await pointer.getPendingProxyVersion()).to.eq(255);

      // Test that the upgrade function reverts if called by a non-owner
      await expect(pointer.connect(otherAccount).upgradeProxy()).to.be.revertedWith(
        "Only owner can upgrade"
      );

      // Test that the upgrade function upgrades the proxy
      await pointer.upgradeProxy();
      expect(await pointer.resolveProxyVersion()).to.eq(255);
      expect(await pointer.resolveProxy()).to.eq(newRegImplAddress);
      expect(await pointedVersion.getVersion()).to.eq(255);

      expect(await pointer.pointerVersion()).to.eq(1);
    });
  });

  it("can allow Registry be auto-upgraded to latest version", async () => {
    const signers = await ethers.getSigners();
    const [owner, otherAccount] = signers;
    const { root, addressManager } = await DEPLOYROOT(ethers, "", "", "localhost");

    const tx = await root.mintRegistryFor(owner.address, "Bobs Registry", true); //<--- key. it IS auto-upgradeable

    const newRegAddress = (await root.getAllRegistries())[0];
    const pointer = await ethers.getContractAt("IRegistryProxyPointer", newRegAddress);
    const versionedUnderlying = await ethers.getContractAt("IVersioned", newRegAddress);

    expect(await pointer.IsDefaultingToLatestVersion()).to.be.true;
    expect(await pointer.resolveProxyVersion()).to.eq(1);
    expect(await versionedUnderlying.getVersion()).to.eq(1);

    const newReg = await ethers.getContractFactory("RegistryImplV2Dummy");
    const newRegImpl = await newReg.deploy();
    const newRegImplAddress = await addressOf(newRegImpl);
    expect(await pointer.resolveProxyVersion()).to.eq(1);
    expect(newRegImplAddress).to.not.eq(await addressOf(versionedUnderlying));

    await addressManager.setRegistryImplAddress(newRegImplAddress);

    expect(await versionedUnderlying.getVersion()).to.eq(255);
    expect(await pointer.resolveProxyVersion()).to.eq(255);
    expect(await pointer.resolveProxy()).to.eq(newRegImplAddress);
    expect(await pointer.getPendingProxy()).to.eq(newRegImplAddress);
    expect(await pointer.getPendingProxyVersion()).to.eq(255);

    await expect(pointer.upgradeProxy()).to.be.revertedWith(
      "Already defaulting to latest version"
    );

    expect(await versionedUnderlying.getVersion()).to.eq(255); //underlying versioned contract is at version 2
    expect(await pointer.pointerVersion()).to.eq(1); //pointer was not deployed. it remains at version 1
  });

  describe("Fee Distributor Upgrade", function () {
    it("has a bug in v1 - can add same currency twice", async () => {
      const signers = await ethers.getSigners();
      const [owner, otherAccount] = signers;
      const { root, addressManager,feeDist,licenseRegistry,legatoLicense } = await DEPLOYROOT(ethers, "", "", "localhost");
      const tx = await root.mintRegistryFor(owner.address, "Bobs Registry", false); //<--- key it is NOT auto upgradeable
      await feeDist.addCurrency(owner.address);
      await expect(feeDist.addCurrency(owner.address)).to.be.revertedWith('FeeDistributor: currency already added');
      const newRegAddress = (await root.getAllRegistries())[0];
      await tryMintingASongInStore(newRegAddress, owner, otherAccount, licenseRegistry, legatoLicense);
    });
  });

  it("bug is fixed in v2", async () => {
    const signers = await ethers.getSigners();
    const [owner, otherAccount] = signers;
    const { root, addressManager,licenseRegistry,legatoLicense } = await DEPLOYROOT(ethers, "", "", "localhost");

    const FeeDistributorV2Factory = await ethers.getContractFactory("FeeDistributorV2");
    const deployedFeeDistV2 = await FeeDistributorV2Factory.deploy() //deploy a new version of the fee distributor
    await deployedFeeDistV2.deploymentTransaction();

    _____ll("replace deployedFeeDistV2 in address manager")
    await addressManager.changeContractAddressDangerous("contracts.feeDistributor", await addressOf(deployedFeeDistV2)); 
    _____ll("deployedFeeDistV2 replaced in address manager", await addressOf(deployedFeeDistV2));
    _____ll("running standard test with new version")

    // const feeDistPointer = await addressManager.getFeeDistributor();
    const feeDistPointer = await addressManager.getFeeDistributor();
    const feeDistPointer2 = await addressManager.getPointerForContractName("contracts.feeDistributor");
    expect(feeDistPointer).to.eq(feeDistPointer2);

    const feeDistUnderlyingPointer = await addressManager.getUnderlyingFeeDistributor();
    expect(feeDistPointer).to.not.eq(feeDistUnderlyingPointer);
    expect(feeDistUnderlyingPointer).to.eq(await addressOf(deployedFeeDistV2));

    //expect revert if we try to add the same currency again
    const feeDistPointerInstance = await ethers.getContractAt("FeeDistributorV2", feeDistPointer);
    await feeDistPointerInstance.addCurrency(owner.address);
    // await feeDistPointerInstance.addCurrency(owner.address);
    await expect(feeDistPointerInstance.addCurrency(owner.address)).to.be.revertedWith('FeeDistributor: currency already added');

    ////////STANDARD TEST FOLLOWS BELOW
    const tx = await root.mintRegistryFor(owner.address, "Bobs Registry", true); //<--- key. it IS auto-upgradeable
    await tx.wait();

    //check we have 1 registry
    expect((await root.getAllRegistries()).length).to.eq(2); //on top of the previous one created in deployment smoke test
      const newRegAddress = (await root.getAllRegistries())[1];
      await tryMintingASongInStore(newRegAddress, owner, otherAccount, licenseRegistry, legatoLicense);

  });
});
 async function tryMintingASongInStore(newRegAddress: any, owner, otherAccount, licenseRegistry, legatoLicense) {
  console.log("regAddr", newRegAddress);
  const reg = await ethers.getContractAt("RegistryImplV1", newRegAddress);
  const theParams = {
    shortName: "a",
    fileHash: "a",
    symbol: "a",
    metadataURI: "a",
    kind: "a",
    tokens: [
      {
        kind: "YayaTokens",
        name: "yaya",
        symbol: "YAYA",
        tokenAddress: owner.address,
        memo: "",
        targets: [
          {
            holderAddress: owner.address,
            amount: ethers.parseEther("100"),
            memo: "",
          },
        ],
      },
    ],
  };
  console.log("functions ");
  // console.log("functions ", reg.interface)
  await reg.mintIP(theParams);
  console.log("minted song");
  const blueprintFac = await ethers.getContractFactory("LicenseBlueprint", otherAccount);
  const licBlueprint = await blueprintFac.deploy(
    otherAccount.address,
    "license blueprint uri",
    "ipfsFileHash",
    "lbp1",
    [
      { id: 1, name: "seller", val: "change me", dataType: "string", info: "change me", },
      { id: 2, name: "address", val: "change me", dataType: "address", info: "change me", },
    ],
    [
      { id: 1, name: "buyer", val: "change me", dataType: "string", info: "change me", },
      { id: 2, name: "address", val: "change me", dataType: "address", info: "change me", },
    ],
    [
      { id: 1, name: "auto buyer", val: "cannot change me", dataType: "string", info: "change me", },
      { id: 2, name: "auto address", val: "cannot change me", dataType: "address", info: "change me", },
    ],
    false,
    100,
    true,
    0 //SINGLE
  );
  const licreg = await licenseRegistry.connect(otherAccount);

  const licenseTypesBefore = await licreg.getAllLicenseTypeIds();
  // expect(licenseTypesBefore.length).to.equal(3);  //deployment + smoke test license types already exist
  const result = await licreg.addLicenseBlueprintFromAddress(await licBlueprint.getAddress());
  const rec = await result.wait();

  const licenseTypes = await licreg.getAllLicenseTypeIds();
  // expect(licenseTypes.length).to.equal(4);

  const songs = await reg.getAllIps();
  console.log({ songs });
  // expect(songs.length).to.eq(2); //deployment + smoke test deployed a song
 const foundLicenses = await legatoLicense.getLicensesForBlueprint(songs[0]);
  // expect(foundLicenses.length).to.eq(0);
}

