// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.7;

import "forge-std/Test.sol";

import "openzeppelin-contracts/token/ERC20/IERC20.sol";
import "contracts/RegistryToken.sol";
// import "contracts/registries/RegistryImplV1.sol";
// import "contracts/registries/RegistryImplV2.sol";
import "contracts/registries/RegistryImplV3.sol";
// import "contracts/registries/RegistryImplV4.sol";
import "contracts/registries/RegistryImplV5.sol";
import "contracts/interfaces/IRoyaltyPortionToken.sol";
import "contracts/dataBound/FeeDistributor/FeeDistributor.sol";
import "contracts/dataBound/FeeDistributor/FeeDistributorV2.sol";
import "contracts/dataBound/FeeDistributor/FeeDistributorV3.sol";
import "contracts/dataBound/FeeDistributor/FeeDistributorV4.sol";
import "contracts/LegatoLicense/LegatoLicense.sol";
import "contracts/LegatoLicense/LegatoLicenseV2.sol";
import "contracts/LegatoLicense/LegatoLicenseV3.sol";
import "contracts/eip5553/IIPRepresentation.sol";
import "contracts/eip5553/BlueprintV3.sol";
import "contracts/interfaces/Structs.sol";
import "forge-std/console.sol";
import "contracts/dataBound/LicenseRegistry/LicenseRegistry.sol";
import "contracts/dataBound/LicenseRegistry/LicenseRegistryV2.sol";
import "contracts/LicenseBlueprint.sol";
import "contracts/VerifyHelper.sol";
import "contracts/interfaces/ILicenseBlueprint.sol";
import "contracts/dataBound/RootRegistry/RootRegistryV2.sol";
import "contracts/dataBound/RootRegistry/RootRegistryV3.sol";
import "contracts/dataBound/RootRegistry/RootRegistryV4.sol";
import "openzeppelin-contracts/utils/Strings.sol";
import "contracts/interfaces/IUSDC.sol";
import "contracts/storage/EternalStorage.sol";
import "contracts/storage/AddressManager.sol";
import "contracts/storage/DALBase.sol";
import "../dummies/FakeToken.sol";
import "contracts/registries/RegistryProxyPointer.sol";
import "contracts/testContracts/RegistryImplV2Dummy.sol";
import "contracts/storage/StorageContractPointer.sol";

abstract contract HelperContract is Test, IERC721Receiver {
    EternalStorage public eternalStorage;
    AddressManager public addressManager;
    LicenseRegistryV2 public licenseRegistry;
    LicenseBlueprint public licenseBlueprint;
    RegistryImplV5 public registry;
    RegistryProxyPointer public registryProxyPointerImpl;
    FeeDistributor public feeDistributor;
    FeeDistributorV2 public feeDistributorV2;
    // FeeDistributorV3 public feeDistributorV3;
    FeeDistributorV4 public feeDistributorV4;
    FeeDistributor public feeDistributorPointer;
    TokenDistributor public tokenDistributor;
    LegatoLicense public legatoLicense;
    LegatoLicenseV2 public legatoLicenseV2;
    LegatoLicenseV3 public legatoLicenseV3;
    VerifyHelper public verifyHelper;
    RootRegistryV4 public rootRegistry;
    BaseIPPortionToken public baseTokenImpl;
    StorageContractPointer public storageContractPointerImpl;
    ERC20 usdc;

    RegistryImplV5 public registry_implementation;
    RegistryImplV2Dummy public registryV2DummyImplementation;
    BlueprintV3 public blueprintImplementation;

    LicenseField[] SELLER_FIELDS; //= new LicenseField[](2);
    LicenseField[] BUYER_FIELDS; // = new LicenseField[](2);
    LicenseField[] AUTO_FIELDS; // = new LicenseField[](2);

    address LICENSE_BLUEPRINT;
    address LICENSE_REGISTRY;
    address REGISTRY;
    address BLUEPRINT_IMPL;
    address TOKEN_DISTRIBUTOR;
    address LEGATO_LICENSE;
    uint256 ONE_USDC = 1e6;
    uint256 FORK_MAINNET;

    address DEPLOYER = vm.addr(777);
    address BOB = vm.addr(1);
    address MARY = vm.addr(2);
    address SAM = vm.addr(3);
    address DAVID = vm.addr(4);
    address JANE = vm.addr(5);
    address ROOT_ADMIN = vm.addr(6);
    address VERIFY_HELPER;

    address USDC_ADDRESS;

    function onERC721Received(address, address, uint256, bytes calldata) external pure override returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    constructor() {
        // string memory MAINNET_RPC = vm.envString("POLYGON_RPC");
        // if (bytes(MAINNET_RPC).length == 0) {
        //     revert("Please provide MAINNET_RPC in your .env file");
        // }
        // uint256 fork = vm.createFork(MAINNET_RPC);
        // vm.selectFork(fork);

        _setupLicenseFields();

        usdc = deployUSDC();

        /// Create Eternal Storage
        vm.startPrank(DEPLOYER);
        eternalStorage = new EternalStorage(DEPLOYER, DEPLOYER);
        eternalStorage.allowContract(address(this));
        /// Setup Address Manager
        addressManager = new AddressManager();
        eternalStorage.allowContract(address(addressManager));
        addressManager.selfRegister(DEPLOYER, address(eternalStorage));
        // addressManager.initialize(DEPLOYER, address(eternalStorage));
        // addressManager.registerNewContract("contracts.addressManager", address(addressManager));
        // addressManager.registerNewContractWithPointer("contracts.addressManager", address(addressManager),DEPLOYER);
        addressManager = AddressManager(addressManager.getAddressManager());

        /// HAS TO COME BEFORE ANY OTHER CONTRACTS (so we can make pointers to them)
        storageContractPointerImpl = new StorageContractPointer();
        addressManager.registerNewContract("contracts.storageContractPointerImpl", address(storageContractPointerImpl));

        feeDistributor = new FeeDistributor();
        rootRegistry = new RootRegistryV4();
        licenseRegistry = new LicenseRegistryV2();

        legatoLicense = new LegatoLicense();
        baseTokenImpl = new BaseIPPortionToken(address(this), address(this), address(this), "", "", "");
        addressManager.registerNewContract("contracts.baseIPPortionTokenImpl", address(baseTokenImpl));
        tokenDistributor = new TokenDistributor();
        verifyHelper = new VerifyHelper();
        legatoLicenseV2 = new LegatoLicenseV2();
        legatoLicenseV3 = new LegatoLicenseV3();
        // verifyHelper = new VerifyHelper(address(eternalStorage));

        ///DATA BOUND CONTRACTS that require a pointer
        addressManager.registerNewContract("contracts.usdcAddress", address(usdc));
        feeDistributor =
            FeeDistributor(wrapPointerAndLabel("contracts.feeDistributor", address(feeDistributor), DEPLOYER));
        rootRegistry = RootRegistryV4(wrapPointerAndLabel("contracts.rootRegistry", address(rootRegistry), DEPLOYER));
        licenseRegistry =
            LicenseRegistryV2(wrapPointerAndLabel("contracts.licenseRegistry", address(licenseRegistry), DEPLOYER));
        tokenDistributor =
            TokenDistributor(wrapPointerAndLabel("contracts.tokenDistributor", address(tokenDistributor), DEPLOYER));
        verifyHelper = VerifyHelper(wrapPointerAndLabel("contracts.verifyHelper", address(verifyHelper), DEPLOYER));
        legatoLicenseV2 =
            LegatoLicenseV2(wrapPointerAndLabel("contracts.licenseContractV2", address(legatoLicenseV2), DEPLOYER));
        legatoLicense = LegatoLicense(address(legatoLicenseV2));
        legatoLicenseV3 = LegatoLicenseV3(address(legatoLicenseV3));

        addressManager.registerNewContract("contracts.licenseContract", address(legatoLicense));

        /// Allow EternalStorage
        eternalStorage.allowContract(address(verifyHelper));
        eternalStorage.allowContract(address(licenseRegistry));
        eternalStorage.allowContract(address(rootRegistry));
        eternalStorage.allowContract(address(tokenDistributor));
        eternalStorage.allowContract(address(tokenDistributor));
        eternalStorage.allowContract(address(feeDistributor));
        // eternalStorage.allowContract(address(feeDistributorV2));
        // eternalStorage.allowContract(address(wrapPointer()));

        registryProxyPointerImpl = new RegistryProxyPointer(); //Registry has a special user-upgradeable pointer
        // registryV1Implementation = new RegistryImplV1();
        registry_implementation = new RegistryImplV5();
        registryV2DummyImplementation = new RegistryImplV2Dummy();
        blueprintImplementation = new BlueprintV3();

        addressManager.registerNewContract("contracts.registryProxyPointerImpl", address(registryProxyPointerImpl));
        addressManager.registerNewContract("contracts.registryImplementation", address(registry_implementation));
        addressManager.registerNewContract("contracts.blueprintImplementation", address(blueprintImplementation));
        vm.label(address(registry_implementation), "registry impl v4");
        vm.label(address(registryV2DummyImplementation), "registry impl DUMMY v2");
        vm.label(address(blueprintImplementation), "blueprint impl");
        vm.label(address(registryProxyPointerImpl), "registry proxy pointer impl");

        // Initialize Contracts
        verifyHelper.initialize(address(eternalStorage));
        feeDistributor.initialize(address(eternalStorage), DEPLOYER, USDC_ADDRESS, 10000);
        tokenDistributor.initialize(address(eternalStorage), DEPLOYER);
        licenseRegistry.initialize(address(eternalStorage), DEPLOYER);

        ////upgrade fee distributor to V2
        // addressManager.changeContractAddressVersioned("contracts.feeDistributor", address(feeDistributorV2));
        // feeDistributor = wrapPointer();//make sure we are always dealing with version 2 or later
        ////MAKE SURE ALL POINTERS ARE SET BEFORE THIS

        // vm.startPrank(DEPLOYER);
        initializeRootGrantAdmins();

        //UPGRADES
        feeDistributorV2 = new FeeDistributorV2();
        addressManager.changeContractAddressVersioned("contracts.feeDistributor", address(feeDistributorV2));

        feeDistributorV4 = new FeeDistributorV4();
        addressManager.changeContractAddressVersioned("contracts.feeDistributor", address(feeDistributorV4));

        vm.stopPrank();

        registry = RegistryImplV5(rootRegistry.mintRegistryFor(BOB, "Bobs Registry", true));
        assertEq(registry.getVersion(), 5);
        // vm.prank(DEPLOYER);
        //allow future tests to mint multipel stores for BOB
        // rootRegistry.setStoreMaxForAccountTypes(makeUInt8ArrayWithValue(uint8(AccountType.DEFAULT)), makeUint256ArrayWithValue(100));
    }

    function makeUInt8ArrayWith2Values(uint8 value1, uint8 value2) internal pure returns (uint8[] memory) {
        uint8[] memory arr = new uint8[](2);
        arr[0] = uint8(value1);
        arr[1] = uint8(value2);
        return arr;
    }

    function makeUint256ArrayWith2Values(uint256 value1, uint256 value2) internal pure returns (uint256[] memory) {
        uint256[] memory array = new uint256[](2);
        array[0] = value1;
        array[1] = value2;
        return array;
    }

    function makeUInt8ArrayWithValue(uint8 value) internal pure returns (uint8[] memory) {
        uint8[] memory arr = new uint8[](1);
        arr[0] = uint8(value);
        return arr;
    }

    function makeUint256ArrayWithValue(uint256 value) internal pure returns (uint256[] memory) {
        uint256[] memory array = new uint256[](1);
        array[0] = value;
        return array;
    }

    function allow100StoresForDefaultAccounts() public {
        RootRegistryV4 reg4 = RootRegistryV4(address(rootRegistry));
        vm.prank(DEPLOYER);
        reg4.setStoreMaxForAccountType(uint8(AccountType.DEFAULT), 100);
    }

    function wrapPointerAndLabel(string memory _contractName, address _implAddress, address _pointerOwner)
        public
        returns (address)
    {
        addressManager.registerNewContractWithPointer(_contractName, _implAddress, _pointerOwner);
        address pointerAddress = addressManager.getPointerForContractName(_contractName);
        // label + "Pointer"
        vm.label(pointerAddress, string(abi.encodePacked(_contractName, " :pointer")));
        return pointerAddress;
    }

    function initializeRootGrantAdmins() public {
        vm.label(address(DEPLOYER), "deployer");
        vm.label(address(rootRegistry), "root registry");
        eternalStorage.grantAllower(address(rootRegistry));
        rootRegistry.initialize(address(eternalStorage));

        feeDistributor.grantAdmin(address(rootRegistry));
        tokenDistributor.grantAdmin(address(rootRegistry));
        legatoLicenseV2.initialize(DEPLOYER, address(addressManager));

        legatoLicenseV3.initialize(DEPLOYER, address(addressManager));
        // legatoLicenseV2.grantAdmin(address(rootRegistry));
        ///<--- POINTS to V2
        addressManager.changeContractAddressDangerous("contracts.licenseContract", address(legatoLicenseV2));
        addressManager.changeContractAddressDangerous("contracts.licenseContract", address(legatoLicenseV3));
        ////check for version 2
        // assertEq(IVersioned(addressManager.getLicenseContract()).getVersion(), 3);
        // legatoLicenseV2.initialize(DEPLOYER,address(rootRegistry));
        // legatoLicense.grantAdmin(DEPLOYER);
        // legatoLicenseV2.grantAdmin(DEPLOYER);
    }

    function getFieldsAsMemory(LicenseField[] memory from) public pure returns (LicenseField[] memory to) {
        to = new LicenseField[](from.length);
        for (uint256 i = 0; i < from.length; i++) {
            to[i] = LicenseField({
                id: from[i].id,
                name: from[i].name,
                val: from[i].val,
                dataType: from[i].dataType,
                info: from[i].info
            });
        }
    }

    function addFakeNonActiveLicense() public returns (uint256) {
        licenseBlueprint = new LicenseBlueprint(
            address(this),
            "uri",
            "ipfsFileHash",
            "name",
            getFieldsAsMemory(SELLER_FIELDS),
            getFieldsAsMemory(BUYER_FIELDS),
            getFieldsAsMemory(AUTO_FIELDS),
            false,
            10,
            false,
            uint8(LicenseScope.SINGLE)
        );
        LICENSE_BLUEPRINT = address(licenseBlueprint);
        vm.label(LICENSE_BLUEPRINT, "license blueprint");

        uint256 id = licenseRegistry.addLicenseBlueprintFromAddress(LICENSE_BLUEPRINT);
        return id;
    }

    function makeChildRegistryV2(address _ownerWallet) public returns (RegistryImplV1) {
        address newReg = payable(rootRegistry.mintRegistryFor(_ownerWallet, "", false));
        vm.label(newReg, "child registry");
        return RegistryImplV1(newReg);
    }

    uint256 regCount = 1;

    function makeRegistryV2(address _ownerWallet) public returns (RegistryImplV1) {
        // RegistryImplV1 reg = new RegistryImplV1('',_ownerWallet, address(eternalStorage));
        RegistryImplV1 reg = RegistryImplV1(rootRegistry.mintRegistryFor(_ownerWallet, "", false));
        bytes memory log = abi.encodePacked("registery v2 direct impl", Strings.toString(regCount++));
        console.log(string(log));
        vm.label(address(reg), string(log));
        return reg;
    }

    function addFakeBLANKET_STORELicenseBlueprint(LicenseRegistryV2 licReg) public returns (uint256) {
        LicenseBlueprint bp = new LicenseBlueprint(
            address(this),
            "uri",
            "ipfsFileHash",
            "name",
            getFieldsAsMemory(SELLER_FIELDS),
            getFieldsAsMemory(BUYER_FIELDS),
            getFieldsAsMemory(AUTO_FIELDS),
            false,
            10,
            true,
            uint8(LicenseScope.STORE)
        );
        vm.label(address(bp), "license blueprint");

        uint256 id = licReg.addLicenseBlueprintFromAddress(address(bp));
        return id;
    }

    function addFakeBLANKETLicenseBlueprint(LicenseRegistryV2 licReg, LicenseScope _scope) public returns (uint256) {
        LicenseBlueprint bp = new LicenseBlueprint(
            address(this),
            "uri",
            "ipfsFileHash",
            "name",
            getFieldsAsMemory(SELLER_FIELDS),
            getFieldsAsMemory(BUYER_FIELDS),
            getFieldsAsMemory(AUTO_FIELDS),
            false,
            10,
            true,
            uint8(_scope)
        );
        vm.label(address(bp), "license blueprint");

        uint256 id = licReg.addLicenseBlueprintFromAddress(address(bp));
        return id;
    }

    function addFakeLicenseBlueprint(LicenseRegistryV2 licReg) public returns (uint256) {
        LicenseBlueprint bp = new LicenseBlueprint(
            address(this),
            "uri",
            "ipfsFileHash",
            "name",
            getFieldsAsMemory(SELLER_FIELDS),
            getFieldsAsMemory(BUYER_FIELDS),
            getFieldsAsMemory(AUTO_FIELDS),
            false,
            10,
            true,
            uint8(LicenseScope.SINGLE)
        );
        vm.label(address(bp), "license blueprint");

        uint256 id = licReg.addLicenseBlueprintFromAddress(address(bp));
        return id;
    }

    function mintSongBlueprintAs() public returns (address) {
        BlueprintMintingParams memory bmp = BlueprintMintingParams({
            shortName: "abc",
            fileHash: "",
            symbol: "SONG",
            metadataURI: "meta",
            kind: "song",
            tokens: new RoyaltyTokenData[](2)
        });

        bmp.tokens[0].kind = "some comp type";
        bmp.tokens[0].name = "token name";
        bmp.tokens[0].symbol = "token symbol";
        bmp.tokens[0].memo = "memo";
        bmp.tokens[0].targets = new SplitTarget[](2);
        bmp.tokens[0].targets[0] = SplitTarget({holderAddress: BOB, amount: 25e18, memo: ""});
        bmp.tokens[0].targets[1] = SplitTarget({holderAddress: MARY, amount: 75e18, memo: ""});

        bmp.tokens[1].kind = "some rec type";
        bmp.tokens[1].name = "token name";
        bmp.tokens[1].symbol = "token symbol";
        bmp.tokens[1].memo = "memo";
        bmp.tokens[1].targets = new SplitTarget[](2);
        bmp.tokens[1].targets[0] = SplitTarget({holderAddress: BOB, amount: 25e18, memo: ""});
        bmp.tokens[1].targets[1] = SplitTarget({holderAddress: MARY, amount: 75e18, memo: ""});

        address newSongAddress = registry.mintIP(bmp);
        return newSongAddress;
    }

    function _setupLicenseFields() private {
        SELLER_FIELDS.push(LicenseField(1, "seller name", "name of seller", "string", "name of seller"));
        SELLER_FIELDS.push(LicenseField(1, "seller address", "address of seller", "string", "address of seller"));

        BUYER_FIELDS.push(LicenseField(1, "buyer name", "name of buyer", "string", "name of buyer"));
        BUYER_FIELDS.push(LicenseField(1, "buyer address", "address of buyer", "string", "address of buyer"));

        AUTO_FIELDS.push(LicenseField(1, "AUTO_TX_ID", "name of auto", "string", "name of auto"));
        AUTO_FIELDS.push(LicenseField(1, "AUTO_CONTRACT_ADDRESS", "address of auto", "string", "address of auto"));
    }

    function _getUSDC(address to, uint256 _amount) internal {
        // vm.prank(usdc.masterMinter());
        // usdc.configureMinter(address(this), type(uint256).max);

        // usdc.mint(to, _amount);
        usdc.transfer(to, _amount);
    }

    function _approveUSDC(address _owner, address _spender, uint256 _amount) internal {
        vm.prank(_owner);
        usdc.approve(_spender, _amount);
    }

    function _fundAndApproveUSDC(address _owner, address _spender, uint256 _amountIn, uint256 _amountOut) internal {
        _getUSDC(_owner, _amountIn);
        _approveUSDC(_owner, _spender, _amountOut);
    }

    function deployUSDC() private returns (ERC20) {
        FakeTokenForTests fakeUSDC = new FakeTokenForTests("USDC", "USDC");
        USDC_ADDRESS = address(fakeUSDC);
        return ERC20(USDC_ADDRESS);
    }
}
