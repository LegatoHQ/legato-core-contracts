import "@nomicfoundation/hardhat-ethers";
// import { HardhatEthersHelpers } from "@nomicfoundation/hardhat-ethers/types";
import { ContractTransactionReceipt, formatEther, isAddress, parseUnits, toBigInt } from "ethers";
import fs from "fs";
import { IDeployedContracts, deployLicenseTemplate } from "../scripts/licenseTemplateHelpers";
import aggregatorLicenseDescriptor from "../scripts/license_aggLicense_single";
import blanketAggregatorLicenseDescriptor from "../scripts/blanket_license_aggLicense_profit";
import { expect } from "chai";
import { string } from "hardhat/internal/core/params/argumentTypes";
// import { ethers as et } from "ethers";

function stepOut() {
	depth--;
	if (depth < 0) depth = 0;
}
function stepIn() {
	depth++;
}
let depth = 0;
function seperator(ends: bool = false) {
	const ch = "_";
	if (depth === 0) {
		// timestampLog("/".repeat(80));
		timestampLog(ch.repeat(80));
	}
	else {
		timestampLog(ch.repeat(50));
	}
}
function depthPrefix() {
	const result = depth > 0 ? " ".repeat((depth) * 4) : "";
	return result + (depth === 0 ? "" : "|");
}

function timestampLog(...args) {
	const now = new Date();
	const timeString = now.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit', second: '2-digit', hour12: false });
	console.log(timeString, depthPrefix(), ...args);
}

async function balance(ethers: any) {
	//  console.log(ethers)
	const [signer] = await ethers.getSigners();
	const firstAddress = await signer.getAddress();
	const balance = await ethers.provider.getBalance(firstAddress);
	_____ll("balance:", formatEther(balance.toString()), "MATIC");
}

export async function sendUsdcTo(
	howMuchInEth: string,
	receiverAddress: string,
	senderAddress: string,
	usdcAddress: string,
	ethers: HardhatEthersHelpers
) {
	//based on https://gist.github.com/saucepoint/00ae29ae70a38f787b1f1aca6ef23f1f
	// ___log("----> connecting....")
	const impersonatedSigner = await ethers.getImpersonatedSigner(senderAddress);
	const usdc = (await ethers.getContractAt("ERC20", usdcAddress)).connect(impersonatedSigner);

	const howMuch = et.utils.parseUnits(howMuchInEth, 6);
	// const inWei = ethers.utils.parseEther((balanceSender.di).toString());
	await usdc.transfer(receiverAddress, howMuch.toString());
	_____x("-----> sent:", et.utils.formatUnits(howMuch.toString(), 6), "to", receiverAddress);
}

interface Progress {
	[name: string]: {
		[subkey: string]: {
			done: boolean;
			address: string;
			pointerAddress?: string;
			hasPointer?: boolean;
			ctorArgs?: any[];
			initArgs?: any[];
		};
	};
}

let progress: Progress = {};

function ___onProgressDone(name: string, key: string, _address: string = "", chainId: string, pointerAddress: string = "", wrapWithPointer: boolean = false, ctorArgs?: any[], initArgs?: any[]) {
	//create key if it doesn't exist
	if (depth === 0) {
		depth = 1;
	}
	stepOut();
	if (depth > 0) seperator(true);
	if (depth === 0) {
		timestampLog(`END: ${name}.${key}`);
		// balance(ethers);
		seperator(true);

		console.log();
	}
	if (!progress[name]) progress[name] = {};
	progress[name][key] = { done: true, address: _address, pointerAddress, hasPointer: pointerAddress !== "", ctorArgs, initArgs };
	if (chainId === "localhost") return; //don't write to file if we're on localhost
	fs.writeFileSync(`./progress.${chainId}.json`, JSON.stringify(progress, null, 2));
}
function ___onProgressStart(name: string, key: string, _address: string = "", chainId: string, ctorArgs?: any[], initArgs?: any[]) {
	//create key if it doesn't exist
	//repeat string N times:
	if (depth === 0) {
		console.log();
		console.log();
		seperator();
		// balance(ethers);
	}
	timestampLog(`START: ${name}.${key}`);
	if (depth > 0) seperator();
	stepIn();

	if (!progress[name]) progress[name] = {};
	progress[name][key] = { done: false, address: _address, ctorArgs, initArgs };
	if (chainId === "localhost") return; //don't write to file if we're on localhost
	fs.writeFileSync(`./progress.${chainId}.json`, JSON.stringify(progress, null, 2));
}

function makeFileName(chainId: string) {
	return `./progress.${chainId}.json`;
}
function ____isProgressDone(contractName: string, key: string, chainId: string) {
	if (!fs.existsSync(makeFileName(chainId))) {
		console.log("progress.json does not exist. creating...");
		fs.writeFileSync(makeFileName(chainId), JSON.stringify({}));
	}
	progress = JSON.parse(fs.readFileSync(makeFileName(chainId)).toString());
	return (
		progress[contractName] && progress[contractName][key] && progress[contractName][key].done
	);
}
function ____getDoneAddressFor(contractName: string, key: string) {
	const result = (
		progress[contractName] && progress[contractName][key] && (
			progress[contractName][key].hasPointer ?
				progress[contractName][key].pointerAddress :
				progress[contractName][key].address
		)
	);
	if (result === undefined || result === "") {
		throw new Error("existingContractAddress is undefined or empty");
	}
	return result;
}

export const _____ll_Skip__ = (stageName: string) => {
	_____ll("skipping", stageName, "because it was already called");
	stepOut();
};
export const _____ll = (text: string = "", text2: string = "", text3: string = "", text4: string = "") => {
	if (text === "") {
		// console.log();
	} else {
		timestampLog(">", text, text2, text3, text4);
	}
};
export const _____x = (text: string = "", text2: string = "") => {
	if (text === "") {
		// console.log();
	} else {
		timestampLog("====>", text, text2);
	}
};
export async function addressOf(item: any) {
	return (await item.getAddress()).toString();
}

/**
 * Helper function for DEPLOY_CONTRACT().
 * calls initialize() on a newly deployed contract with the given arguments.
 * Will skip if no initArgs are provided.
 * @param initArgs - The arguments to pass to the contract initialization function. pass UNDEFINED to SKIP.
 * @param newContract - The newly deployed contract.
 * @returns A promise that resolves to the transaction receipt.
 */
export async function __INITIALIZE_ONLY(
	initArgs: any,
	newContract: any,
	chainId: string,
	contractName: string
) {
	const stageName = "__INITIALIZE";
	if (____isProgressDone(contractName, stageName, chainId)) {
		_____ll_Skip__(stageName);
		return;
	}
	___onProgressStart(contractName, stageName, "", chainId);

	if (initArgs && initArgs.length > 0) {
		_____ll("initializing with :", initArgs);
		try {
			const tx3 = await newContract.initialize(...initArgs, { gasPrice: gasPriceToUse });
			await __WAIT(tx3, chainId);
		} catch (error) {
			const jsonText = JSON.stringify(error).toLocaleLowerCase();
			if (jsonText.includes("already initialized")) {
				_____ll("already initialized. skipping...");
			}

		}
	} else {
		_____ll("initialized SKIPPED: no init args", initArgs);
	}
	___onProgressDone(contractName, stageName, "", chainId, "", false, [], initArgs);
	_____ll();
}

/**
 * Helper function for DEPLOY_CONTRACT().
 * Registers the address of a newly deployed contract in the address manager.
 * @param name - The name of the contract.
 * @param newContractAddress - The address of the newly deployed contract.
 * @returns A promise that resolves to the transaction receipt.
 */
export async function __REGISTER_AND_WRAP_ADDRESS_ONLY(
	name: string,
	newContractAddress: any,
	addrMgrInstance: any,
	chainId: string,
	contractName: string,
	wrapWithPointer?: boolean,
	pointerOwnerAddress?: string
): Promise<string> {
	const stageName = "__REGISTER_AND_WRAP_ADDRESS_ONLY";
	if (____isProgressDone(contractName, stageName, chainId)) {
		_____ll_Skip__(stageName);
		return ____getDoneAddressFor(contractName, stageName);
	}
	___onProgressStart(contractName, stageName, "", chainId);
	///-----------------

	let tx2;
	let pointerAddress;
	let failed = false;
	if (addrMgrInstance !== undefined) {
		if (wrapWithPointer && wrapWithPointer === true) {
			if (pointerOwnerAddress === undefined || !isAddress(pointerOwnerAddress)) {
				throw new Error("pointerOwnerAddress must be a valid address");
			}
			_____ll('true wrapWithPointer:');
			_____ll("Registering with Pointer...", newContractAddress);
			try {
				tx2 = await addrMgrInstance.registerNewContractWithPointer(
					name,
					newContractAddress,
					pointerOwnerAddress,
					{ gasPrice: gasPriceToUse }
				);
				await __WAIT(tx2, chainId);
				pointerAddress = await addrMgrInstance.getPointerForContractName(name);
			} catch (error) {
				pointerAddress = await handleRegistrationErrorAndRetryNoPointer(error, pointerAddress, addrMgrInstance, name, tx2, chainId);
				if (pointerAddress.includes("0x00000")) {
					pointerAddress = "";
					throw new Error("pointerAddress is empty after retrying.");
				}

			}
			await __WAIT(tx2, chainId);
			_____ll("pointer address:", pointerAddress);
		} else { //no pointer
			_____ll('skipping wrapWithPointer:');
		}
	} else {
		_____ll("skipped: address manager not yet deployed");
	}
	___onProgressDone(contractName, stageName, pointerAddress, chainId, pointerAddress, wrapWithPointer);
	_____ll();
	return pointerAddress;
}

async function handleRegistrationErrorAndRetryPointer(error: unknown, pointerAddress: any, addrMgrInstance: any, name: string, tx2: any, chainId: string) {
	const jsonText = JSON.stringify(error).toLocaleLowerCase();
	if (jsonText.includes("already registered")) {
		_____ll("already registered. getting pointer address...");
		pointerAddress = await addrMgrInstance.getPointerForContractName(name);
		_____ll("pointer address: found", pointerAddress);
	} else if (jsonText.includes("zero address")) {
		_____ll("Zero Address error. Not finalized yet. waiting a bit...");
		__WAIT(tx2, chainId);
		pointerAddress = await addrMgrInstance.getPointerForContractName(name);
	} else {
		throw error;
	}
	return pointerAddress;
}
async function handleRegistrationErrorAndRetryNoPointer(error: unknown, directContractAddress: any, addrMgrInstance: any, name: string, tx2: any, chainId: string) {
	const jsonText = JSON.stringify(error).toLocaleLowerCase();
	if (jsonText.includes("already registered")) {
		_____ll("already registered. getting contract address...");
		directContractAddress = await addrMgrInstance.getContractAddress(name);
		_____ll("pointer address: found", directContractAddress);
	} else if (jsonText.includes("zero address")) {
		_____ll("Zero Address error. Not finalized yet. waiting a bit...");
		__WAIT(tx2, chainId);
		directContractAddress = await addrMgrInstance.getContractAddress(name);
	} else {
		throw error;
	}
	return directContractAddress;
}

export async function __CHANGE_ADDRESS_ONLY(
	contractName: string,
	newContractAddress: any,
	newContractInstance: any,
	addrMgrInstance: any,
	chainId: string,
	ethers: any,
	dangerously: boolean = false,
	hasPointer: boolean = true
) {
	const stageName = "__CHANGE_ADDRESS_ONLY" + (dangerously ? "_DANGEROUSLY" : "");
	if (____isProgressDone(contractName, stageName, chainId)) {
		_____ll_Skip__(stageName);
		const existingContractAddress = ____getDoneAddressFor(contractName, stageName);
		return existingContractAddress;
	}
	___onProgressStart(contractName, stageName, "", chainId);
	///-----------------

	const abi = ["function getVersion() view returns (uint8)"];
	const oldInstance = await ethers.getContractAt(abi, await addrMgrInstance.getContractAddress(contractName));
	const newInstance = await ethers.getContractAt(abi, newContractAddress);
	let pointedInstance;

	if (hasPointer) {
		pointedInstance = await ethers.getContractAt(abi, await addrMgrInstance.getPointerForContractName(contractName));
	}
	if (addrMgrInstance !== undefined) {
		////BEFORE
		_____ll("comparing versions:");
		try { hasPointer && _____ll("old version (pointer):", await pointedInstance.getVersion()); } catch (e) {
			if (e.message.includes("function selector was not recognized")) {
				_____ll("old version (pointer):", "not found (not getVersion() function?");
			} else throw e;
		}
		hasPointer && _____ll("Pointer Address (should remain):", await addrMgrInstance.getPointerForContractName(contractName));
		_____ll("new version (direct):", await newInstance.getVersion());
		_____ll("replacing old address (underlying):", await addrMgrInstance.getContractAddress(contractName));
		_____ll("with new address (underlying future):", newContractAddress);

		let tx2;
		if (dangerously) {
			_____ll("DANGEROUSLY replacing address in address manager...");
			tx2 = await addrMgrInstance.changeContractAddressDangerous(contractName, newContractAddress, { gasPrice: gasPriceToUse });
		} else {
			tx2 = await addrMgrInstance.changeContractAddressVersioned(contractName, newContractAddress, { gasPrice: gasPriceToUse });
		}

		await __WAIT(tx2, chainId);

		///AFTER
		hasPointer && _____ll("Done. getting new version:", await pointedInstance.getVersion());
		hasPointer && _____ll("Pointer Address: should remain:", await addrMgrInstance.getPointerForContractName(contractName));
		hasPointer && _____ll("Done. getting new version (underlying):", await newContractInstance.attach(
																			await addrMgrInstance.getContractAddress(contractName))
																			.getVersion());
		_____ll("new address (underlying):", await addrMgrInstance.getContractAddress(contractName));
	} else {
		_____ll("skipped: address manager not yet deployed");
	}
	___onProgressDone(contractName, stageName, newContractAddress, chainId, "", false);
	_____ll();
}

export async function __REGISTER_ADDRESS_ONLY(
	name: string,
	newContractAddress: any,
	addrMgrInstance: any,
	chainId: string,
	contractName: string,
	wrapWithPointer?: boolean,
	pointerOwnerAddress?: string
) {
	const stageName = "__REGISTER_AND_WRAP_ADDRESS_ONLY";
	if (____isProgressDone(contractName, stageName, chainId)) {
		_____ll_Skip__(stageName);
		const existingContractAddress = ____getDoneAddressFor(contractName, stageName);
		return existingContractAddress;
	}
	___onProgressStart(contractName, stageName, "", chainId);
	///-----------------

	if (addrMgrInstance !== undefined) {
		if (!Boolean(wrapWithPointer)) {
			_____ll('false wrapWithPointer:');
			_____ll("Registering in Address Manager without pointer ...", newContractAddress);
			let tx2;
			try {
				tx2 = await addrMgrInstance.registerNewContract(name, newContractAddress, { gasPrice: gasPriceToUse });
				await __WAIT(tx2, chainId);
			} catch (error) {
				const contractAddress = await handleRegistrationErrorAndRetryPointer(error, newContractAddress, addrMgrInstance, name, tx2, chainId);
			}
		}
	} else {
		_____ll("skipped: address manager not yet deployed");
	}
	___onProgressDone(contractName, stageName, newContractAddress, chainId, "", false);
	_____ll();
}

/**
 * helper function for DEPLOY_CONTRACT().
 * Allows or disallows a contract to access storage functions.
 * @param allow  true to allow, false to disallow
 * @param newContractAddress  the address of the contract to allow/disallow
 */
export async function __ALLOW_ONLY(
	allow: boolean,
	newContractAddress: any,
	storageInstance: any,
	chainId: string,
	contractName: string
) {
	const stageName = "__ALLOW_ONLY";
	if (____isProgressDone(contractName, stageName, chainId)) {
		_____ll_Skip__(stageName);
		return;
	}
	___onProgressStart(contractName, stageName, "", chainId);
	///-----------------

	if (allow) {
		_____ll("Allowing in Eternal Storage...",);
		const txAllow = await storageInstance.allowContract(newContractAddress, { gasPrice: gasPriceToUse });
		await __WAIT(txAllow, chainId);
	} else {
		_____ll("storage NOT allowed");
	}
	___onProgressDone(contractName, stageName, "", chainId);
	_____ll();
}

export async function __GRANT_ALLOWER_ONLY(
	newContractAddress: any,
	storageInstance: any,
	chainId: string,
	contractName: string
) {
	const stageName = "__GRANT_ALLOWER_ONLY";
	if (____isProgressDone(contractName, stageName, chainId)) {
		_____ll_Skip__(stageName);
		return;
	}
	___onProgressStart(contractName, stageName, "", chainId);
	///-----------------

	_____ll(storageInstance.target, "(storage) is granting ALLOWER role to...", newContractAddress);
	const txAllow = await storageInstance.grantAllower(newContractAddress, { gasPrice: gasPriceToUse });
	await __WAIT(txAllow, chainId);

	//-------------------
	___onProgressDone(contractName, stageName, "", chainId);
	_____ll();
}

/**
 * Helper function for DEPLOY_CONTRACT().
 * Deploys a contract with constructor arguments using the provided deployer.
 * @param ctorArgs - The constructor arguments for the contract.
 * @param deployer - The deployer object to use for deployment.
 * @returns A promise that resolves to the newly deployed contract.
 */
export async function __DEPLOY_ONLY(
	ctorArgs: any,
	deployer: any,
	chainId: string,
	contractName: string,
	versionName: string = ""
) {
	const stageName = "__DEPLOY_ONLY" + (versionName !== "" ? "_" + versionName : "");
	if (____isProgressDone(contractName, stageName, chainId)) {
		_____ll_Skip__(stageName);
		const existingContractAddress = ____getDoneAddressFor(contractName, stageName);
		return await deployer.attach(existingContractAddress);
	}
	___onProgressStart(contractName, "__DEPLOY_ONLY", "", chainId);
	///-----------------

	let newContract;
	_____ll("deploying with ctor args:", ctorArgs);
	if (ctorArgs && ctorArgs.length > 0) {
		newContract = await deployer.deploy(...ctorArgs, { gasPrice: gasPriceToUse });
	} else {
		newContract = await deployer.deploy({ gasPrice: gasPriceToUse });
	}
	await __WAIT(newContract.deploymentTransaction(), chainId);
	const newContractAddress = await addressOf(newContract);
	_____ll("deployed at:", await addressOf(newContract));
	___onProgressDone(contractName, "__DEPLOY_ONLY", newContractAddress, chainId, "", false, ctorArgs);

	_____ll();
	return newContract;
}
export const __WAIT = async (tx: any, chainId: string) => {
	let confirmations = 1;
	if (chainId !== "localhost") {
		confirmations = 3;
	}
	if (tx !== undefined) await tx.wait(confirmations);
};
/**
 * Deploys a contract with the given parameters.
 * @param deployer - The instance of the deployer.
 * @param name - The name of the contract.
 * @param ctorArgs - The arguments to pass to the contract constructor.
 * @param initArgs - The arguments to pass to the contract initialization function.
 * @param allow - is this contract allowed to access storage functions?
 * @returns The newly deployed contract.
 */
const gasPriceToUse = parseUnits(process.env.DEPLOY_GAS_PRICE || "100", "gwei");
_____x();
_____x();
_____ll("gasPriceToUse:", gasPriceToUse.toString());
_____x();
_____x();

export async function DEPLOY_CONTRACT_UPGRADE({
	deployer,
	name,
	addrMgrInstance,
	chainId,
	postDeployFn,
	versionName,
	dangerously,
	hasPointer = true
}: deployParams): Promise<ethers.Contract> {
	const STAGE_NAME = `_DEPLOY_CONTRACT_UPGRADE_${versionName}`;
	if (____isProgressDone(name, STAGE_NAME, chainId)) {
		_____ll_Skip__(STAGE_NAME);
		const existingContractAddress = ____getDoneAddressFor(name, STAGE_NAME);
		return await deployer.attach(existingContractAddress);
	}
	balance(ethers);
	___onProgressStart(name, STAGE_NAME, "", chainId)
	///-----------------

	const newContract = await __DEPLOY_ONLY(undefined, deployer, chainId, STAGE_NAME,versionName);
	const newContractAddress = await addressOf(newContract);
	_____ll("deployer:", deployer.runner.address);

	await __CHANGE_ADDRESS_ONLY(name, newContractAddress, newContract, addrMgrInstance, chainId, ethers, dangerously, hasPointer);
	if (postDeployFn !== undefined) {
		___onProgressStart(STAGE_NAME, "post-deploy", "", chainId);
		await postDeployFn(newContract);
		___onProgressDone(STAGE_NAME, "post-deploy", await addressOf(newContract), chainId);
	}
	___onProgressDone(name, STAGE_NAME, newContractAddress, chainId)
	// _____x(`-------END: ${name}-----------`);
	// _____x();
	return newContract;
}
export async function DEPLOY_CONTRACT_FULL({
	deployer,
	name,
	ctorArgs,
	initArgs,
	storageAccess: allow,
	wrapWithPointer,
	storageInstance,
	addrMgrInstance,
	chainId,
	postDeployFn
}: deployParams): Promise<ethers.Contract> {
	const STAGE_NAME = "_DEPLOY_CONTRACT_FULL";
	if (____isProgressDone(name, STAGE_NAME, chainId)) {
		_____ll_Skip__(STAGE_NAME);
		const existingContractAddress = ____getDoneAddressFor(name, STAGE_NAME);
		return await deployer.attach(existingContractAddress);
	}
	balance(ethers);
	___onProgressStart(name, STAGE_NAME, "", chainId, ctorArgs, initArgs);
	///-----------------

	const newContract = await __DEPLOY_ONLY(ctorArgs, deployer, chainId, name);
	const newContractAddress = await addressOf(newContract);
	_____ll("deployer:", deployer.runner.address);
	let pointerAddress;
	if (wrapWithPointer === true) {
		pointerAddress = await __REGISTER_AND_WRAP_ADDRESS_ONLY(
			name,
			newContractAddress,
			addrMgrInstance,
			chainId,
			name,
			wrapWithPointer,
			deployer.runner.address
		);
	}
	else {
		await __REGISTER_ADDRESS_ONLY(
			name,
			newContractAddress,
			addrMgrInstance,
			chainId,
			name,
			wrapWithPointer,
			deployer.runner.address
		);
	}
	const finalContractInstance = wrapWithPointer ? await deployer.attach(pointerAddress) : newContract;
	await __ALLOW_ONLY(allow, finalContractInstance, storageInstance, chainId, name);
	await __INITIALIZE_ONLY(initArgs, finalContractInstance, chainId, name);


	if (postDeployFn !== undefined) {
		___onProgressStart(name, "post-deploy", "", chainId);
		await postDeployFn(finalContractInstance);
		___onProgressDone(name, "post-deploy", await addressOf(finalContractInstance), chainId);
	}
	___onProgressDone(name, STAGE_NAME, newContractAddress, chainId, pointerAddress, wrapWithPointer, ctorArgs, initArgs);
	// _____x(`-------END: ${name}-----------`);
	// _____x();
	return finalContractInstance;
}
////---- END OF DEPLOY_CONTRACT FUNCTION -----------------

/**
 * Deploys the eternal storage and address manager contracts.
 * @dev This function is called first, before any other contract is deployed.
 * This is because the address manager needs to know the address of the eternal storage contract.
 * The eternal storage contract is used to store data for all other contracts.
 * The eternal storage contract is also used to allow contracts to access storage functions.
* @param owner  the owner of the contracts
* @param EternalStorageDeployer  the deployer for the eternal storage contract
* @param AddressManagerDeployer  the deployer for the address manager contract
* @param chainId  the chain id
* @returns an object with the storage and address manager instances
*/
export async function DEPLOY_STORAGE_AND_ADDRESS_MANAGER(
	owner: string,
	EternalStorageDeployer: any,
	AddressManagerDeployer: any,
	chainId: string
) {
	_____x();
	_____x("deploying eternal storage");
	let storageInstance, addrMgrInstance;
	let stageName1 = "_DEPLOY_CONTRACT_FULL";
	if (____isProgressDone("contracts.eternalStorage", stageName1, chainId)) {
		_____ll("skipping deploy() because it was already called");
		const existingContractAddress = ____getDoneAddressFor(
			"contracts.eternalStorage",
			stageName1
		);
		storageInstance = await EternalStorageDeployer.attach(existingContractAddress);
	}
	if (storageInstance === undefined)
		___onProgressStart("contracts.eternalStorage", stageName1, "", chainId);
	storageInstance = await __DEPLOY_ONLY(
		[owner, owner],
		EternalStorageDeployer,
		chainId,
		"contracts.eternalStorage"
	);
	___onProgressDone(
		"contracts.eternalStorage",
		"_DEPLOY_CONTRACT_FULL",
		await addressOf(storageInstance),
		chainId
	);

	_____x("deploying address manager");
	const contractName = "contracts.addressManager";
	const stageName2 = "_DEPLOY_CONTRACT_FULL";
	if (____isProgressDone(contractName, stageName1, chainId)) {
		_____ll("skipping deploy() because it was already called");
		const existingContractAddress = ____getDoneAddressFor(
			contractName,
			stageName2
		);
		addrMgrInstance = await AddressManagerDeployer.attach(existingContractAddress);
	}
	if (addrMgrInstance === undefined)
		___onProgressStart(contractName, stageName1, "", chainId);
	addrMgrInstance = await __DEPLOY_ONLY(
		undefined,
		AddressManagerDeployer,
		chainId,
		contractName
	);
	await __ALLOW_ONLY(
		true,
		await addressOf(addrMgrInstance),
		storageInstance,
		chainId,
		contractName
	);
	_____ll("self registering address manager in itself...")
	if (____isProgressDone(contractName, "selfRegister", chainId)) {
		_____ll("skipping selfRegister() because it was already called");
	}
	else {
		___onProgressStart(contractName, "selfRegister", await addressOf(addrMgrInstance), chainId);
		const tx = await addrMgrInstance.selfRegister(owner, await addressOf(storageInstance), { gasPrice: gasPriceToUse });
		__WAIT(tx, chainId);
		___onProgressDone(contractName, "selfRegister", await addressOf(addrMgrInstance), chainId, "", false, [], [owner, await addressOf(storageInstance)]);
	}

	_____x(`registering  eternal storage in address manager...`);
	await __REGISTER_ADDRESS_ONLY(
		"contracts.eternalStorage",
		await addressOf(storageInstance),
		addrMgrInstance,
		chainId,
		contractName
	);
	_____x();
	___onProgressDone(contractName, stageName2, await addressOf(addrMgrInstance), chainId);
	return { storageInstance, addrMgrInstance };
}

export interface deployParams {
	deployer: any;
	name: string;
	ctorArgs?: any | undefined;
	initArgs?: any | undefined;
	storageAccess: boolean;
	storageInstance: any;
	addrMgrInstance: any;
	chainId: string;
	wrapWithPointer?: boolean;
	postDeployFn?: (newContract: any) => Promise<void>;
	versionName?: string,
	dangerously?: boolean,
	hasPointer?: boolean
}

export async function deployLicenseBlueprints(ethers: any, _CONTRACTS_: IDeployedContracts, chainId: string) {
	if (____isProgressDone("licenseBlueprints", "_DEPLOY_ALL", chainId)) {
		_____ll_Skip__("skipping _DEPLOY_ALL for blueprint licenses");
		return;
	}
	___onProgressStart("licenseBlueprints", "_DEPLOY_ALL", "", chainId);
	// console.log("   // license blueprints...");
	const licenses = [
		aggregatorLicenseDescriptor,
		blanketAggregatorLicenseDescriptor
	];
	// console.log(`   //---------------`);
	for (const descriptor of licenses) {
		if (____isProgressDone("licenseBlueprints", descriptor.name, chainId)) {
			_____ll_Skip__(descriptor.name);
		}
		else {
			_____x();
			___onProgressStart("licenseBlueprints", descriptor.name, "", chainId);
			const result = await deployLicenseTemplate(_CONTRACTS_, ethers, descriptor, chainId);
			___onProgressDone("licenseBlueprints", descriptor.name, result, chainId);
			_____x();
		}
	}
	// console.log(`   //---------------`);

	// console.log("deployed license blueprints:");
	___onProgressDone("licenseBlueprints", "_DEPLOY_ALL", "", chainId);
}
export async function firstSigner(ethers: HardhatEthersHelpers) {
	return (await ethers.getSigners())[0];
}

export async function runSmokeTestAfterDeploy(allContracts: IDeployedContracts, chainId: string, ethers: any) {
	___onProgressStart("smokeTest", "_FULL", "", chainId);

	const { root, licenseRegistry, legatoLicense } = allContracts;
	const [owner, otherAccount] = await ethers.getSigners();
	const existingRegistryCount = await root.getRegistryCount();

	// expect((await root.getAllRegistries()).length).to.eq(0);
	// expect(await root.getRegistryCount()).to.eq(0);

	const tx = await allContracts.root.mintRegistryFor(owner.address, "Smoke Test Store", true);
	await __WAIT(tx, chainId);

	expect((await root.getAllRegistries()).length).to.eq( existingRegistryCount + BigInt(1));
	expect(await root.getRegistryCount()).to.eq(existingRegistryCount + BigInt(1));
	const newRegAddress = (await root.getAllRegistries())[0];
	_____ll("new registry address:", newRegAddress);

	___onProgressStart("smokeTest", "tryMintingASongInStore", "", chainId);
	await tryMintingASongInStore(newRegAddress, owner, otherAccount, licenseRegistry, legatoLicense, chainId, ethers);
	___onProgressDone("smokeTest", "tryMintingASongInStore", "", chainId);

	___onProgressDone("smokeTest", "_FULL", "", chainId);
}

export async function tryMintingASongInStore(newRegAddress: any, owner, otherAccount, licenseRegistry, legatoLicense, chainId: string, ethers: any) {
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
	// console.log("functions ");
	// console.log("functions ", reg.interface)
	_____ll("minting song...");
	await reg.mintIP(theParams);
	_____ll("Done. ");
}
