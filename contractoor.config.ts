import dotenv from 'dotenv';
import { ConfigParams } from "contractoor";

dotenv.config();

const env = process.env;

const ETERNAL_STORAGE_ADDRESS = "@EternalStorage";
const ADDRESS_MANAGER_ADDRESS = "@AddressManager";
const STORAGE_CONTRACT_POINTER_ADDRESS = "@StorageContractPointer";
const REGISTRY_PROXY_POINTER_ADDRESS = "@RegistryProxyPointer";
const REGISTRY_IMPL_V5_ADDRESS = "@RegistryImplV5";
const BLUEPRINT_V2_ADDRESS = "@BlueprintV2";
const VERIFY_HELPER_ADDRESS = "@VerifyHelper";
const BASE_IP_PORTION_TOKEN_ADDRESS = "@BaseIPPortionToken";
const ROOT_REGISTRY_V4_ADDRESS = "@RootRegistryV4";
const LICENSE_REGISTRY_V2_ADDRESS = "@LicenseRegistryV2";
const FEE_DISTRIBUTOR_V4_ADDRESS = "@FeeDistributorV4";
const TOKEN_DISTRIBUTOR_ADDRESS = "@TokenDistributor";
const LEGATO_LICENSE_V3_ADDRESS = "@LegatoLicenseV3";

const config: ConfigParams = {
    contracts: [
        {
            contract: "EternalStorage",
            args: [env.OWNER_ADDRESS, env.OWNER_ADDRESS],
        },
        {
            contract: "AddressManager",
            dependencies: [ETERNAL_STORAGE_ADDRESS],
            actions: [
                { target: ETERNAL_STORAGE_ADDRESS, command: "allowContract", args: [ADDRESS_MANAGER_ADDRESS] },
                { target: ADDRESS_MANAGER_ADDRESS, command: "selfRegister", args: [env.OWNER_ADDRESS, ETERNAL_STORAGE_ADDRESS] },
            ]
        },
        {
            contract: "StorageContractPointer",
            dependencies: [ETERNAL_STORAGE_ADDRESS, ADDRESS_MANAGER_ADDRESS], 
            actions: [
                { target: ADDRESS_MANAGER_ADDRESS, command: "registerNewContract", args: ["contracts.storageContractPointerImpl", STORAGE_CONTRACT_POINTER_ADDRESS] },
            ]
        },
        {
            contract: "RegistryProxyPointer",
            dependencies: [ETERNAL_STORAGE_ADDRESS, ADDRESS_MANAGER_ADDRESS], 
            actions: [
                { target: ADDRESS_MANAGER_ADDRESS, command: "registerNewContract", args: ["contracts.registryProxyPointerImpl", REGISTRY_PROXY_POINTER_ADDRESS] },
            ]
        },
        {
            contract: "RegistryImplV5",
            dependencies: [ETERNAL_STORAGE_ADDRESS, ADDRESS_MANAGER_ADDRESS], 
            actions: [
                { target: ADDRESS_MANAGER_ADDRESS, command: "registerNewContract", args: ["contracts.registryImplementation", REGISTRY_IMPL_V5_ADDRESS] },
            ]
        },
        {
            contract: "BlueprintV2",
            args: [0,env.OWNER_ADDRESS,"","","","",""],
            dependencies: [ETERNAL_STORAGE_ADDRESS, ADDRESS_MANAGER_ADDRESS], 
            actions: [
                { target: ADDRESS_MANAGER_ADDRESS, command: "registerNewContract", args: ["contracts.blueprintImplementation", BLUEPRINT_V2_ADDRESS] },
            ]
        },
        {
            contract: "VerifyHelper",
            dependencies: [ETERNAL_STORAGE_ADDRESS],
            actions: [
                { target: ETERNAL_STORAGE_ADDRESS, command: "allowContract", args: [VERIFY_HELPER_ADDRESS] },
                { target: ADDRESS_MANAGER_ADDRESS, command: "registerNewContractWithPointer", args: ["contracts.verifyHelper", VERIFY_HELPER_ADDRESS, env.OWNER_ADDRESS] },
                { target: VERIFY_HELPER_ADDRESS, command: "initialize", args: [ETERNAL_STORAGE_ADDRESS] },
            ]
        },
        {
            contract: "BaseIPPortionToken",
            args: [env.OWNER_ADDRESS, env.OWNER_ADDRESS,env.OWNER_ADDRESS,"","",""],
            actions: [
                { target: ADDRESS_MANAGER_ADDRESS, command: "registerNewContractWithPointer", args: ["contracts.baseIPPortionTokenImpl", BASE_IP_PORTION_TOKEN_ADDRESS, env.OWNER_ADDRESS] },
            ],
            dependencies: [ETERNAL_STORAGE_ADDRESS, ADDRESS_MANAGER_ADDRESS]
        },
        {
            contract: "RootRegistryV4",
            dependencies: [ETERNAL_STORAGE_ADDRESS, ADDRESS_MANAGER_ADDRESS, STORAGE_CONTRACT_POINTER_ADDRESS],
            actions: [
                { target: ETERNAL_STORAGE_ADDRESS, command: "allowContract", args: [ROOT_REGISTRY_V4_ADDRESS] },
                { target: ADDRESS_MANAGER_ADDRESS, command: "registerNewContractWithPointer", args: ["contracts.rootRegistry", ROOT_REGISTRY_V4_ADDRESS, env.OWNER_ADDRESS] },
                { target: ROOT_REGISTRY_V4_ADDRESS, command: "initialize", args: [ETERNAL_STORAGE_ADDRESS] },
            ]
        },
        {
            contract: "LicenseRegistryV2",
            dependencies: [ETERNAL_STORAGE_ADDRESS, ADDRESS_MANAGER_ADDRESS, STORAGE_CONTRACT_POINTER_ADDRESS],
            actions: [
                { target: ETERNAL_STORAGE_ADDRESS, command: "allowContract", args: [LICENSE_REGISTRY_V2_ADDRESS] },
                { target: ADDRESS_MANAGER_ADDRESS, command: "registerNewContractWithPointer", args: ["contracts.licenseRegistry", LICENSE_REGISTRY_V2_ADDRESS, env.OWNER_ADDRESS] },
                { target: LICENSE_REGISTRY_V2_ADDRESS, command: "initialize", args: [ETERNAL_STORAGE_ADDRESS, env.OWNER_ADDRESS] },
            ]

        },
        {
            contract: "FeeDistributorV4",
            actions: [
                { target: ETERNAL_STORAGE_ADDRESS, command: "allowContract", args: [FEE_DISTRIBUTOR_V4_ADDRESS] },
                { target: ADDRESS_MANAGER_ADDRESS, command: "registerNewContractWithPointer", args: ["contracts.feeDistributor", FEE_DISTRIBUTOR_V4_ADDRESS, env.OWNER_ADDRESS] },
                { target: FEE_DISTRIBUTOR_V4_ADDRESS, command: "initialize", args: [ETERNAL_STORAGE_ADDRESS, env.OWNER_ADDRESS,env.ALLOWED_CURRENCY,env.DEFAULT_FEE] },
        ],
        dependencies: [ETERNAL_STORAGE_ADDRESS, ADDRESS_MANAGER_ADDRESS, STORAGE_CONTRACT_POINTER_ADDRESS, ROOT_REGISTRY_V4_ADDRESS],
        },
        {
            contract: "TokenDistributor",
            dependencies: [ETERNAL_STORAGE_ADDRESS, ADDRESS_MANAGER_ADDRESS, STORAGE_CONTRACT_POINTER_ADDRESS],
            actions: [
                { target: ETERNAL_STORAGE_ADDRESS, command: "allowContract", args: [TOKEN_DISTRIBUTOR_ADDRESS] },
                { target: ADDRESS_MANAGER_ADDRESS, command: "registerNewContractWithPointer", args: ["contracts.tokenDistributor", TOKEN_DISTRIBUTOR_ADDRESS, env.OWNER_ADDRESS] },
                { target: TOKEN_DISTRIBUTOR_ADDRESS, command: "initialize", args: [ETERNAL_STORAGE_ADDRESS, env.OWNER_ADDRESS] },
            ]
        },
        {
            contract: "FakeTokenForTests",
            args: ["Legato Token","LEGATO"],
            actions: [
                { target: ADDRESS_MANAGER_ADDRESS, command: "registerNewContractWithPointer", args: ["contracts.fakeToken", "@FakeTokenForTests", env.OWNER_ADDRESS] },
            ],
            dependencies: [ETERNAL_STORAGE_ADDRESS, ADDRESS_MANAGER_ADDRESS, STORAGE_CONTRACT_POINTER_ADDRESS, ROOT_REGISTRY_V4_ADDRESS],
        },
        {
            contract: "LegatoLicenseV3",
            dependencies: [ETERNAL_STORAGE_ADDRESS, ADDRESS_MANAGER_ADDRESS, STORAGE_CONTRACT_POINTER_ADDRESS, ROOT_REGISTRY_V4_ADDRESS],
            actions: [
                { target: ADDRESS_MANAGER_ADDRESS, command: "registerNewContractWithPointer", args: ["contracts.legatoLicense", LEGATO_LICENSE_V3_ADDRESS, env.OWNER_ADDRESS] },
                { target: LEGATO_LICENSE_V3_ADDRESS, command: "initialize", args: [env.OWNER_ADDRESS, ADDRESS_MANAGER_ADDRESS] },
            ]
        },
        {
            contract: "RegistryImplV5",
            dependencies: [ETERNAL_STORAGE_ADDRESS, ADDRESS_MANAGER_ADDRESS, STORAGE_CONTRACT_POINTER_ADDRESS],
            actions: [
                { target: ETERNAL_STORAGE_ADDRESS, command: "allowContract", args: [REGISTRY_IMPL_V5_ADDRESS] },
                { target: REGISTRY_IMPL_V5_ADDRESS, command: "initialize", args: ["someName", env.OWNER_ADDRESS, ETERNAL_STORAGE_ADDRESS, 1] },
            ]
        },
    ]
};

export default config;
