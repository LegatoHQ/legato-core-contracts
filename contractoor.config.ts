import { ConfigParams } from "contractoor";

const config: ConfigParams = {
    contracts: [
        {
            contract: "EternalStorage",
            args: [
                "0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC",
                "0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC",
            ],
        },
        {
            contract: "AddressManager"
        },
        {
            contract: "RootRegistryV4",
        },
        {
            contract: "LicenseRegistryV2",
        },
        {
            contract: "FeeDistributorV4",
        },
        {
            contract: "TokenDistributor",
        },
        {
            contract: "LegatoLicenseV3",
        },
        {
            contract: "RegistryImplV5",
        },
    ]
};

export default config;
