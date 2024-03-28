import dotenv from 'dotenv';
import { ConfigParams } from "contractoor";

dotenv.config();

const env = process.env;

const config: ConfigParams = {
    contracts: [
        {
            contract: "EternalStorage",
            args: [env.OWNER_ADDRESS, env.OWNER_ADDRESS],
        },
        {
            contract: "AddressManager",
            dependencies: ["@EternalStorage"], 
            actions: [
                { target: "@EternalStorage", command: "allowContract", args: ["@AddressManager"] },
                { target: "@AddressManager", command: "selfRegister", args: [env.OWNER_ADDRESS, "@EternalStorage"] },
            ]
        },
        {
            contract: "StorageContractPointer",
            dependencies: ["@EternalStorage","@AddressManager"], 
            actions: [
                { target: "@AddressManager", command: "registerNewContract", args: ["contracts.storageContractPointerImpl","@StorageContractPointer"] },
            ]
        },
        {
            contract: "RegistryProxyPointer",
            dependencies: ["@EternalStorage","@AddressManager"], 
            actions: [
                { target: "@AddressManager", command: "registerNewContract", args: ["contracts.registryProxyPointerImpl","@RegistryProxyPointer"] },
            ]
        },
        {
            contract: "RegistryImplV5",
            dependencies: ["@EternalStorage","@AddressManager"], 
            actions: [
                { target: "@AddressManager", command: "registerNewContract", args: ["contracts.registryImplementation","@RegistryImplV5"] },
            ]
        },
        {
            contract: "BlueprintV2",
            args: [0,env.OWNER_ADDRESS,"","","","",""],
            dependencies: ["@EternalStorage","@AddressManager"], 
            actions: [
                { target: "@AddressManager", command: "registerNewContract", args: ["contracts.blueprintImplementation","@BlueprintV2"] },
            ]
        },
        {
            contract: "VerifyHelper",
            dependencies: ["@EternalStorage"],
            actions: [
                { target: "@EternalStorage", command: "allowContract", args: ["@VerifyHelper"] },
                { target: "@AddressManager", command: "registerNewContractWithPointer", args: ["contracts.verifyHelper","@VerifyHelper",env.OWNER_ADDRESS] },
                { target: "@VerifyHelper", command: "initialize", args: ["@EternalStorage"] },
            ]
        },
        {
            contract: "BaseIPPortionToken",
            args: [env.OWNER_ADDRESS, env.OWNER_ADDRESS,env.OWNER_ADDRESS,"","",""],
            actions: [
                { target: "@AddressManager", command: "registerNewContractWithPointer", args: ["contracts.baseIPPortionTokenImpl","@BaseIPPortionToken",env.OWNER_ADDRESS] },
            ],
            dependencies: ["@EternalStorage","@AddressManager"]
        },
        {
            contract: "RootRegistryV4",
            dependencies: ["@EternalStorage","@AddressManager","@StorageContractPointer"],
            actions: [
                { target: "@EternalStorage", command: "allowContract", args: ["@RootRegistryV4"] },
                { target: "@AddressManager", command: "registerNewContractWithPointer", args: ["contracts.rootRegistry","@RootRegistryV4",env.OWNER_ADDRESS] },
                { target: "@RootRegistryV4", command: "initialize", args: ["@EternalStorage"] },
            ]
        },
        {
            contract: "LicenseRegistryV2",
            dependencies: ["@EternalStorage","@AddressManager","@StorageContractPointer"],
            actions: [
                { target: "@EternalStorage", command: "allowContract", args: ["@LicenseRegistryV2"] },
                { target: "@AddressManager", command: "registerNewContractWithPointer", args: ["contracts.licenseRegistry","@LicenseRegistryV2",env.OWNER_ADDRESS] },
                { target: "@LicenseRegistryV2", command: "initialize", args: ["@EternalStorage", env.OWNER_ADDRESS] },
            ]

        },
        {
            contract: "FeeDistributorV4",
            actions: [
                { target: "@EternalStorage", command: "allowContract", args: ["@FeeDistributorV4"] },
                { target: "@AddressManager", command: "registerNewContractWithPointer", args: ["contracts.feeDistributor","@FeeDistributorV4",env.OWNER_ADDRESS] },
                { target: "@FeeDistributorV4", command: "initialize", args: ["@EternalStorage", env.OWNER_ADDRESS,env.ALLOWED_CURRENCY,env.DEFAULT_FEE] },
        ],
        dependencies: ["@EternalStorage","@AddressManager","@StorageContractPointer","@RootRegistryV4"],
        },
        {
            contract: "TokenDistributor",
            dependencies: ["@EternalStorage","@AddressManager","@StorageContractPointer"],
            actions: [
                { target: "@EternalStorage", command: "allowContract", args: ["@TokenDistributor"] },
                { target: "@AddressManager", command: "registerNewContractWithPointer", args: ["contracts.tokenDistributor","@TokenDistributor",env.OWNER_ADDRESS] },
                { target: "@TokenDistributor", command: "initialize", args: ["@EternalStorage", env.OWNER_ADDRESS] },
            ]
        },
        {
            contract: "FakeTokenForTests",
            args: ["Legato Token","LEGATO"],
            actions: [
                { target: "@AddressManager", command: "registerNewContractWithPointer", args: ["contracts.fakeToken", "@FakeTokenForTests",env.OWNER_ADDRESS] },
            ],
            dependencies: ["@EternalStorage","@AddressManager","@StorageContractPointer","@RootRegistryV4"],
        },
        {
            contract: "LegatoLicenseV3",
            dependencies: ["@EternalStorage","@AddressManager","@StorageContractPointer","@RootRegistryV4"],
            actions: [
                { target: "@AddressManager", command: "registerNewContractWithPointer", args: ["contracts.legatoLicense","@LegatoLicenseV3",env.OWNER_ADDRESS] },
                { target: "@LegatoLicenseV3", command: "initialize", args: [env.OWNER_ADDRESS, "@AddressManager"] },
            ]
        },
        {
            contract: "RegistryImplV5",
            dependencies: ["@EternalStorage","@AddressManager","@StorageContractPointer"],
            actions: [
                { target: "@EternalStorage", command: "allowContract", args: ["@RegistryImplV5"] },
                { target: "@RegistryImplV5", command: "initialize", args: ["someName", env.OWNER_ADDRESS, "@EternalStorage", 1] },
            ]
        },
    ]
};

export default config;
