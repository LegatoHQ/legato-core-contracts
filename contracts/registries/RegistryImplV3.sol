// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

// import "forge-std/console.sol";
import "lib/openzeppelin-contracts/contracts/utils/Counters.sol";
import "lib/openzeppelin-contracts/contracts/utils/Strings.sol";
import "lib/openzeppelin-contracts-upgradeable/contracts/access/AccessControlUpgradeable.sol";
import "lib/openzeppelin-contracts-upgradeable/contracts/security/PausableUpgradeable.sol";
// import "lib/openzeppelin-contracts-upgradeable/contracts/proxy/utils/Initializable.sol";
import "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol"; // Import the SafeERC20 library
import "contracts/interfaces/IRootRegistry.sol";
import "contracts/interfaces/IRootRegistryV2.sol";
import "./IRegistryV2.sol";
import "contracts/interfaces/IFeeDistributor.sol";
import "../storage/IEternalStorage.sol";
import "../eip5553/BlueprintV2.sol";
import "../eip5553/BlueprintV3.sol";
import "../dataBound/TokenDistributor.sol";
import "contracts/interfaces/Structs.sol";
import "../VerifyHelper.sol";
import "../Cloner.sol";
import "./RegistryStorageLayout.sol";
//import rootregistry
import "../dataBound/RootRegistry/RootRegistry.sol";
import "lib/openzeppelin-contracts-upgradeable/contracts/access/AccessControlUpgradeable.sol";
// import "lib/openzeppelin-contracts-upgradeable/contracts/proxy/utils/Initializable.sol";
// import "contracts/dataBound/CommonUpgradeableStorageVars.sol";
// import "lib/openzeppelin-contracts-upgradeable/contracts/security/PausableUpgradeable.sol";

contract RegistryImplV3 is
    RegistryStorageLayout,
    IRegistryV2,
    AccessControlUpgradeable,
    IERC721Receiver,
    PausableUpgradeable,
    ITokenized,
    IVersioned
{
    // Initializable

    using Counters for Counters.Counter;
    using SafeERC20 for IERC20; // Use the SafeERC20 library for IERC20 tokens

    bool private _disabled;

    function isDisabled() public view returns (bool) {
        return _disabled;
    }

    function setDisabled(bool _val) public onlyStoreOwner {
        _disabled = _val;
    }

    function getVersion() external pure override returns (uint8) {
        return 3;
    }

    modifier isInitialized() {
        require(initialized, "Registry not initialized!");
        _;
    }

    modifier onlyStoreOwner() {
        if (!hasRole(STORE_OWNER_ROLE, _msgSender())) require(false, "Not store owner");
        _;
    }

    modifier onlyStorePayer() {
        if (!hasRole(STORE_PAYER_ROLE, _msgSender())) require(false, "Not store payer");
        _;
    }

    modifier onlyAdmin() {
        if (!hasRole(DEFAULT_ADMIN_ROLE, _msgSender())) require(false, "Not admin");
        _;
    }

    modifier onlyActive() {
        if (storeStatus != StoreStatus.ACTIVE) require(false, "Store not active");
        _;
    }

    function getName() external view override returns (string memory) {
        return ledgerName;
    }

    function setIpStatus(address _ip, bool _active) external onlyStoreOwner {
        require(isChild(_ip), "IP not found in store");
        require(_ip != address(0), "0 address");
        BlueprintV3(_ip).setActive(_active);
    }

    function removePayer(address _payer) public override onlyStoreOwner {
        require(_payer != address(0), "remove 0 address");
        require(!hasRole(DEFAULT_ADMIN_ROLE, _payer), "cannot remove admin as payer");
        require(!hasRole(STORE_OWNER_ROLE, _payer), "cannot remove store owner as payer");
        _revokeRole(STORE_PAYER_ROLE, _payer);
    }

    function addPayer(address _payer) public override onlyStoreOwner {
        require(_payer != address(0), "0 address");
        _grantRole(STORE_PAYER_ROLE, _payer);
    }

    function tokens() public view override returns (address[] memory) {
        address[] memory list = new address[](1);
        list[0] = token;
        return list;
    }

    function addBinder(address _binder) public override isInitialized onlyRole(DEFAULT_ADMIN_ROLE) {
        _grantRole(BINDER_ROLE, _binder);
    }

    function bindToken(address _token) public override isInitialized onlyRole(BINDER_ROLE) {
        token = _token;
    }

    constructor() {}

    function isChild(address _address) public view override returns (bool) {
        return isChildBlueprint[_address];
    }

    function isOwner(address _address) public view override returns (bool) {
        return hasRole(STORE_OWNER_ROLE, _address);
    }

    function isAdmin(address _address) public view override returns (bool) {
        return hasRole(DEFAULT_ADMIN_ROLE, _address);
    }

    function initialize(string memory _name, address _ownerWallet, address _eternalStorage, uint256 _nonce)
        public
        override
    {
        require(!initialized, "already initialized!");
        initialized = true;
        nonce = _nonce; //used to save our data per store
        __DATA__ = EternalStorage(_eternalStorage);
        ledgerName = _name;
        ownerWallet = _ownerWallet;
        _grantRole(DEFAULT_ADMIN_ROLE, getAddressManager().getRootRegistry());
        _grantRole(DEFAULT_ADMIN_ROLE, _ownerWallet);
        _grantRole(PAUSER_ROLE, _ownerWallet);
        _grantRole(STORE_OWNER_ROLE, _ownerWallet);
        _grantRole(STORE_PAYER_ROLE, _ownerWallet);
        storeStatus = StoreStatus.ACTIVE;
        storageState = StorageState.Initialised;
    }

    function getAddressManager() public view returns (AddressManager) {
        return AddressManager(__DATA__.getAddressManager());
    }

    function setName(string memory _name) external override onlyStoreOwner {
        ledgerName = _name;
    }

    function onERC721Received(address, address, uint256, bytes calldata) external pure override returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    function pause() public override whenNotPaused onlyRole(PAUSER_ROLE) onlyActive {
        _pause();
        storeStatus = StoreStatus.PAUSED;

        emit StatusUpdated(StoreStatus.PAUSED);
    }

    function unpause() public override whenPaused onlyRole(PAUSER_ROLE) {
        _unpause();
        storeStatus = StoreStatus.ACTIVE;

        emit StatusUpdated(StoreStatus.ACTIVE);
    }

    function optOutofLicense(uint256 _licenseId, uint256 _preConditionId)
        public
        override
        isInitialized
        onlyActive
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        LicenseRegistry licReg = LicenseRegistry(getAddressManager().getLicenseRegistry());
        licReg.optOutOfLicensePrecondition(address(this), _licenseId, _preConditionId);
    }

    function optIntoLicense(
        LicenseScope _scope,
        uint256 _licenseId,
        address _currency,
        uint256 _minCost,
        string memory _name,
        LicenseField[] memory _sellerFields,
        string memory _encryptedInfo
    ) public override isInitialized onlyActive onlyStoreOwner returns (uint256) {
        VerifyHelper helper = VerifyHelper(getAddressManager().getVerifyHelper());
        helper.checkActiveLicense(_licenseId);
        helper.checkScopeBeforeOptin(_licenseId, _scope);
        LicenseRegistry licReg = LicenseRegistry(getAddressManager().getLicenseRegistry());
        return licReg.addOptInToLicense(
            _scope, address(this), _licenseId, _currency, _minCost, _name, _sellerFields, _encryptedInfo
        );
    }

    /**
     * @dev Allows a store payer, or anyone who was added as a payer,  to make an external payment to :
     * a store or to one of the assets in a store. If the store is the target, and the store does not have a token,
     * then the ERC tokens are balanced to the address of the store.
     * If the target is the store and the store has a token, then the payment is made to the owners of the store's token, based on their amount of tokens held.
     * If the target is an asset, then the payment is made to the owners of the asset's royalty tokens based on their amount of tokens held.
     * All payments are then claimable by calling the `claimById` function of the `TokenDistributor` contract.
     * @param req An `ExternalPaymentRequest` struct containing information about the payment request.
     * @return The ID of the payment.
     * Requirements:
     * - The payment amount must be greater than 1000 units.
     * - The called and the request.payer must have the `STORE_PAYER_ROLE`.
     * Emits:
     * - A `PaymentProcessed` event with the ID of the payment, the address of the store, and the address of the payer.
     */
    function externalPayment(ExternalPaymentRequest memory req)
        external
        onlyStorePayer
        isInitialized
        onlyActive
        returns (uint256)
    {
        //TODO support ETH payments
        //@follow-up check min price
        //TODO: check min amount
        // uint256 paymentId = payer.pay(_songAddress, _currency,_amount,_to);
        uint256 paymentId;
        require(req.amount > 1000, "amount too low. At least 1000 units");
        require(hasRole(STORE_PAYER_ROLE, req.payer), "req.payer not a payer");
        FeeInfo memory feeInfo = FeeInfo({
            minAmount: 1000,
            blueprint: req.target,
            currency: req.currency,
            amount: req.amount,
            onBehalfOf: req.payer,
            memo: req.memo
        });
        paymentId = internalPay(feeInfo, req.target);
        require(paymentId > 0, "payment failed");
        return paymentId;
    }

    function internalPay(FeeInfo memory _feeInfo, address _target)
        internal
        isInitialized
        onlyActive
        returns (uint256)
    {
        // if payment is to store, require store to be active
        // if payment is to asset, require asset to be active
        if (_target == address(this)) {
            require(storeStatus == StoreStatus.ACTIVE, "store not active");
        } else {
            require(isChild(_target), "target not found in store");
            require(BlueprintV3(_target).activated(), "asset not active");
        }
        IFeeDistributor payer = IFeeDistributor(getAddressManager().getFeeDistributor());
        if (_target == address(this) && token == address(0)) {
            //no store token, byt store payment needed
            return payer.payStoreDirect(_feeInfo);
        } else {
            return payer.pay(_feeInfo, _target);
        }
    }

    function mintLicense(MintLicenseRequest memory req) external override isInitialized onlyActive returns (uint256) {
        //TODO support ETH payments
        // require target to be active
        if (isChild(req.target)) {
            require(BlueprintV3(req.target).activated(), "asset not active for licensing");
        } else {
            require(req.target == address(this), "blanket license target must be same store");
        }
        LegatoLicense licenseContract = LegatoLicense(getAddressManager().getLicenseContract());
        require(address(licenseContract) != address(0), "registryv3 - license not attached ");
        VerifyHelper helper = VerifyHelper(getAddressManager().getVerifyHelper());
        helper.checkLicense(req, address(this));
        LicenseRegistry licReg = LicenseRegistry(getAddressManager().getLicenseRegistry());
        LicenseOptInV2 memory optInInfo = licReg.getOptInById(req.optInId);
        require(licReg.paused() == false, "license registry is paused");
        require(optInInfo.licenseBlueprintId == req.licenseBlueprintId, "optin does not match license");
        require(optInInfo.minAmount <= req.amount, "amount too low");
        if (optInInfo.minAmount == 0) {
            require(req.amount == 0, "you are trying to pay for a free license");
        }
        tempLicenseMIntParams memory temp;
        temp.licReg = licReg;
        temp.licenseBlueprint = temp.licReg.getLicenseBlueprintbyId(req.licenseBlueprintId);
        temp.licenseNFT = licenseContract;
        temp.newInfo = PurchasedLicenseV2({
            scope: optInInfo.scope,
            licenseBlueprintId: req.licenseBlueprintId,
            basedOnLicenseBlueprint: temp.licenseBlueprint.contractAddress,
            target: req.target,
            kind: temp.licenseBlueprint.name,
            fileHash: temp.licenseBlueprint.ipfsFileHash,
            uri: temp.licenseBlueprint.uri,
            licenseOwner: _msgSender(),
            canExpire: temp.licenseBlueprint.canExpire,
            expiryDate: 0,
            auto_minter: address(0),
            auto_blockNumber: 0,
            auto_timestamp: 0,
            auto_chainId: 0,
            auto_paymentId: 0,
            auto_tokenId: 0,
            encryptedSellerInfo: optInInfo.encryptedInfo,
            encryptedBuyerInfo: req.encryptedBuyerInfo
        });

        FeeInfo memory feeInfo = FeeInfo({
            minAmount: optInInfo.minAmount,
            blueprint: req.target,
            currency: req.currency,
            amount: req.amount,
            onBehalfOf: req.to,
            memo: req.memo
        });
        uint256 paymentId;
        paymentId = internalPay(feeInfo, req.target);

        require(paymentId > 0, "payment failed");

        LicenseField[] memory sellerFields = temp.licReg.getSellerFieldsForOptInId(req.optInId);
        uint256 nftId = temp.licenseNFT.safeMint(temp.newInfo, req.buyerFields, sellerFields, paymentId);
        return nftId;
    }

    /**
     * @dev Allows the owner of the store to withdraw ERC20 tokens or Ether that have been credited to the store address.
     * @param _token The address of the ERC20 token to withdraw. If set to `address(0)`, the function transfers Ether instead of ERC20 tokens.
     * @param _to The address to send the tokens to.
     * @param _amount The amount of tokens to withdraw.
     * Requirements:
     * - The function can only be called by the owner of the store.
     * - The store must be active and initialized.
     * - If `_token` is set to `address(0)`, the function transfers Ether to the `_to` address. Otherwise, the function transfers ERC20 tokens to the `_to` address.
     */
    function withdraw(address _token, address _to, uint256 _amount) public isInitialized onlyActive onlyStoreOwner {
        require(_to != address(0), "registryv2 - withdraw to address 0");
        if (_token == address(0)) {
            payable(_to).transfer(_amount); //ether
        } else {
            IERC20(_token).safeTransfer(_to, _amount); //erc20
        }
    }
    /**
     * @dev Allows the owner of the store to mint a new store token to allow for revenue sharing.
     * @param _token A `RoyaltyTokenData` struct containing information about the new token to be minted.
     * Requirements:
     * - The function can only be called by the owner of the store.
     * - The store must be active and initialized.
     * - The `token` variable should not have been set yet
     * Effects:
     * - The function mints a new store token using the `TokenDistributor` contract specified in the `tokenDistributor` variable.
     * - The `mintIPTokens` function of the `TokenDistributor` contract is called to mint the new token.
     * - The address of the newly minted token is stored in the `token` variable.
     * - Based on the split data in the RoyaltyTokenData struct, Various addresses of people that are part of the store will get initial tokens
     * - Tokens are limited to 100
     * Emits:
     * - An `NewStoreToken` event with the address of the newly minted token and the address of the store.
     */

    function mintStoreToken(RoyaltyTokenData memory _token) external isInitialized onlyStoreOwner onlyActive {
        require(token == address(0), "token already set");
        RoyaltyTokenData[] memory tokensToBe = new RoyaltyTokenData[](1);
        tokensToBe[0] = _token;
        TokenDistributor dist = TokenDistributor(getAddressManager().getTokenDistributor());
        addBinder(address(dist));
        dist.mintIPTokens(tokensToBe, address(this), address(this));

        emit NewStoreToken(token, address(this));
    }

    /**
     * @dev Allows the owner of the store to mint a new intellectual property (IP) asset.
     * @param _params A `BlueprintMintingParams` struct containing information about the new IP token to be minted.
     * Requirements:
     * - The function can only be called by the owner of the store.
     * - The store must be active and initialized.
     * Emits:
     * - A `NewSong` event with the address of the newly minted IP token, the short name, symbol, and address of the store.
     */
    function mintIP(BlueprintMintingParams memory _params)
        external
        override
        isInitialized
        onlyStoreOwner
        onlyActive
        returns (address)
    {
        ipIds.increment();

        TokenDistributor dist = TokenDistributor(getAddressManager().getTokenDistributor());
        address instanceAddress = Cloner.createClone(getAddressManager().getBlueprintCloneImpl());
        BlueprintV2 newIP = BlueprintV2(instanceAddress);
        newIP.initialize(
            ipIds.current(),
            address(this),
            _params.metadataURI,
            _params.shortName,
            _params.symbol,
            _params.kind,
            _params.fileHash
        );
        newIP.addBinder(address(dist));
        dist.mintIPTokens(_params.tokens, address(newIP), address(this));
        isChildBlueprint[address(newIP)] = true;
        ipList.push(address(newIP));

        emit NewIP(address(newIP), _params.shortName, _params.symbol, address(this));
        return address(newIP);
    }

    function getAllIps() external view override returns (address[] memory) {
        //@follow-up can this break?
        return ipList;
    }

    function getIpsPaged(uint256 startIndex) external view override returns (address[] memory) {
        //@follow-up what if it break mid loop + get by index
        address[] memory list = new address[](10);
        if (startIndex < 0) {
            return list;
        }
        uint256 localList = 0;
        for (uint256 i = startIndex; i < startIndex + 10;) {
            unchecked {
                list[localList++] = ipList[i];
                ++i;
            }
        }
        return ipList;
    }

    function getIpCount() public view override returns (uint256) {
        return ipList.length;
    }

    /// @notice Removes the owner of the store and its privileges and aligns the accounting in RootRegistry
    function detachStore() external override onlyStoreOwner {
        IRootRegistryV2(getAddressManager().getRootRegistry()).delistStoreByOwner(address(this));
        _revokeRole(DEFAULT_ADMIN_ROLE, ownerWallet);
        ownerWallet = address(0);
        emit RegistryDetached(address(this));
    }

    /// @notice update the owner wallet of the registry
    /// @param _newWallet the new wallet address
    function updateOwnerWallet(address _newWallet) external override onlyStoreOwner {
        if (_newWallet == address(0)) require(false, "Cannot set owner to 0");
        _revokeRole(DEFAULT_ADMIN_ROLE, ownerWallet);
        _grantRole(DEFAULT_ADMIN_ROLE, _newWallet);
        RootRegistry(getAddressManager().getRootRegistry()).transferStoreOwnership(
            address(this), ownerWallet, _newWallet
        );
        ownerWallet = _newWallet;
        emit OwnerUpdated(ownerWallet);
    }

    function updateStoreStatus(uint8 _newStatus) external override onlyStoreOwner {
        if (_newStatus > 2) require(false, "Invalid store status");
        storeStatus = StoreStatus(_newStatus);

        emit StatusUpdated(storeStatus);
    }

    function getOwnerWallet() external view override returns (address) {
        return ownerWallet;
    }

    function getSettingsUri() external view override returns (string memory) {
        return settingsUri;
    }

    function setSettingsUri(string memory _settingsUri) external override onlyStoreOwner {
        settingsUri = _settingsUri;
    }
}
