// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import "contracts/interfaces/Structs.sol";
import "contracts/interfaces/BaseIPPortionToken.sol";
import "contracts/interfaces/IFeeDistributor.sol";
import "contracts/registries/IRegistryV2.sol";
import "contracts/interfaces/ITokenized.sol";
import "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "lib/openzeppelin-contracts/contracts/utils/math/SafeMath.sol";
// import "lib/openzeppelin-contracts/contracts/access/AccessControl.sol";
import "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol"; // Import the SafeERC20 library
// import "lib/openzeppelin-contracts/contracts/security/Pausable.sol";
import "lib/openzeppelin-contracts-upgradeable/contracts/proxy/utils/Initializable.sol";
import "lib/openzeppelin-contracts-upgradeable/contracts/access/AccessControlUpgradeable.sol";
import "lib/openzeppelin-contracts-upgradeable/contracts/security/PausableUpgradeable.sol";
//pausable upgradeable
import "lib/forge-std/src/console.sol";
import "./FeeDistributorDAL.sol";
import "contracts/interfaces/IVersioned.sol";
import "contracts/storage/AccessControlStorage.sol";
import "contracts/storage/PausableStorage.sol";
import "contracts/dataBound/CommonUpgradeableStorageVars.sol";

//enum enabled disabled currency

contract FeeDistributorV2 is
    FeeDistributorDAL,
    IFeeDistributor,
    AccessControlUpgradeable,
    PausableUpgradeable,
    IVersioned
{
    function getVersion() external pure override returns (uint8) {
        return 2;
    }

    function getStorage() internal view returns (address) {
        console.log("FeeDist:getStorage returing", address(__DATA__));
        return address(__DATA__);
    }

    function getPrefix() internal view returns (string memory) {
        console.log("FeeDist:getPrefix returing", PREFIX());
        return PREFIX();
    }

    using SafeMath for uint256;
    using SafeERC20 for IERC20; // Use the SafeERC20 library for IERC20 tokens

    event ClaimCreated(
        uint256 claimId,
        uint256 indexed paymentId,
        uint256 amount,
        address paymentCurrency,
        address indexed royaltyToken,
        address indexed target
    );

    event ProtocolFeeUpdated(uint256 protocolFee);

    bytes32 public constant PAYER_ROLE = keccak256("PAYER_ROLE");
    bytes32 public constant LEGATO_ADMIN_ROLE = keccak256("LEGATO_ADMIN_ROLE");

    modifier onlyOwner() {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "owner-only action is allowed");
        _;
    }

    function addCurrency(address _currency) public onlyOwner {
        // console.log("addCurrency", _currency);
        _requireNotPaused();
        require(_currency != address(0), "empty address");
        require(uint8(_data_getCurrencyStatus(_currency)) == 0, "FeeDistributor: currency already added");
        ///<-----bugfix in V2
        _data_addToAllowedCurrenciesList(_currency);
        ///
    }

    function initialize(address _storage, address _legatoAdmin, address _allowedCurrency, uint256 _protocolFee)
        public
        initializer
    {
        __AccessControl_init();
        __Pausable_init();
        // require(!isInitialized[address(this)], "v1 already initialized" );
        // isInitialized[address(this)] = true;

        __DATA__ = EternalStorage(_storage);
        _grantRole(DEFAULT_ADMIN_ROLE, getAddressManager().getRootRegistry());
        _grantRole(LEGATO_ADMIN_ROLE, _legatoAdmin);
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        setProtocolFee(_protocolFee);
        //@follow-up add test
        addCurrency(_allowedCurrency);
    }

    function pause() public onlyRole(LEGATO_ADMIN_ROLE) {
        require(hasRole(LEGATO_ADMIN_ROLE, msg.sender), "only admin can pause");
        _pause();
    }

    function unpause() public onlyRole(LEGATO_ADMIN_ROLE) {
        require(hasRole(LEGATO_ADMIN_ROLE, msg.sender), "only admin can pause");
        _unpause();
    }

    function revokeLegatoAdmin(address _oldAdmin) public whenNotPaused onlyRole(LEGATO_ADMIN_ROLE) {
        require(hasRole(LEGATO_ADMIN_ROLE, msg.sender), "not admin");
        //do not allow to revoke yourself
        require(_oldAdmin != msg.sender, "cannot revoke yourself");
        _revokeRole(LEGATO_ADMIN_ROLE, _oldAdmin);
    }

    function grantLegatoAdmin(address _newAdmin) public whenNotPaused onlyRole(LEGATO_ADMIN_ROLE) {
        _grantRole(LEGATO_ADMIN_ROLE, _newAdmin);
    }

    function grantAdmin(address _registry) public override whenNotPaused onlyRole(DEFAULT_ADMIN_ROLE) {
        _grantRole(DEFAULT_ADMIN_ROLE, _registry);
    }

    function grantPayer(address _registry) public override whenNotPaused onlyRole(DEFAULT_ADMIN_ROLE) {
        _grantRole(PAYER_ROLE, _registry);
    }

    function removeCurrency(address _currency) public whenNotPaused onlyRole(LEGATO_ADMIN_ROLE) {
        require(_currency != address(0), "empty address");
        require(_data_getCurrencyStatus(_currency) == CurrencyStatus.ENABLED, "not listed or already disabled");
        changeCurrencyStatus(_currency, CurrencyStatus.DISABLED);
    }

    function getAllowedCurrencies() public view returns (address[] memory) {
        // return allowedCurrenciesList;
        uint256 bufferLocation = 0;
        address[] memory allowedCurrenciesList = _data_getAllowedCurrenciesList();
        address[] memory result = new address[](allowedCurrenciesList.length);
        for (uint256 i = 0; i < allowedCurrenciesList.length; i++) {
            if (_data_getCurrencyStatus(allowedCurrenciesList[i]) == CurrencyStatus.ENABLED) {
                //makes sure that the array is not filled with empty addresses in the middle
                result[bufferLocation++] = allowedCurrenciesList[i];
            }
        }
        //pop empty array items
        while (result[result.length - 1] == address(0)) {
            delete result[result.length - 1];
        }
        return result;
    }
    //@follow-up add test

    function changeCurrencyStatus(address _currency, CurrencyStatus _status)
        public
        whenNotPaused
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(_currency != address(0), "empty address");
        require(_status == CurrencyStatus.DISABLED || _status == CurrencyStatus.ENABLED, "invalid new status");
        require(_data_getCurrencyStatus(_currency) != _status, "already set");
        require(uint8(_data_getCurrencyStatus(_currency)) > 0, "must add currency first");
        //check boolean is not null in mapping

        //require already set
        _data_setCurrencyStatus(_currency, _status);
        // allowedCurrencies[_currency] = _status;
    }

    function getClaimByClaimId(uint256 _claimId) public view returns (ClaimInfo memory) {
        return _data_getClaimByClaimId(_claimId);
    }

    function getPendingClaimIdsFor(address _target) public view returns (uint256[] memory) {
        uint256[] memory ids = _data_getClaimIdsByAddress(_target);
        uint256 length = ids.length;
        uint256[] memory pendingIds = new uint256[](length);
        uint256 nextPendingIndex;
        for (uint256 i; i < length;) {
            if (_data_getClaimByClaimId(ids[i]).paid == false) {
                pendingIds[nextPendingIndex++] = ids[i];
                // console.log("-------->> --->pending", ids[i]);
            }
            unchecked {
                ++i;
            }
        }
        if (nextPendingIndex > 0) {
            return pendingIds;
        } else {
            return new uint256[](0);
        }
    }

    function getAllClaimIdsFor(address _target) public view returns (uint256[] memory) {
        return _data_getClaimIdsByAddress(_target);
    }

    function claimByID(uint256 claimId) public whenNotPaused {
        ClaimInfo memory claim = _data_getClaimByClaimId(claimId);
        // console.log("claim target",claim.target);
        // console.log("msgsender",msg.sender);
        require(claim.target == msg.sender, "you cannot claim this");
        //@follow-up add test
        require(claim.target != address(0), "cannot be burned as claim");
        require(claim.paid == false, "already paid");
        require(claim.left > 0, "nothing left to pay");

        IERC20 token = IERC20(claim.currency);
        token.safeApprove(claim.target, 0);
        token.safeApprove(claim.target, claim.left);
        uint256 toPay = claim.left;

        claim.paid = true;
        claim.left = 0;
        _data_setClaimByClaimId(claimId, claim); //to prevent reentrancy

        token.safeTransfer(claim.target, toPay);
    }

    struct MyVars {
        IERC20 erc;
        address[] tokens;
        ClaimInfo[] claimsTemp;
        uint256 foundClaimsCount;
        ClaimInfo[] foundClaims;
        uint256 subAmount;
        uint256 tokenLength;
        uint256 ONE_PERCENT;
        bool isPaid;
        uint256 fee;
    }

    //    function pay(address _blueprint, address _currency, uint256 _amount, address _onBehalfOf) external returns(uint256) {
    function payStoreWithToken(FeeInfo memory _feeInfo, address _target)
        public
        override
        whenNotPaused
        onlyRole(PAYER_ROLE)
        returns (uint256)
    {
        return pay(_feeInfo, _target);
    }

    function payStoreDirect(FeeInfo memory _feeInfo)
        public
        override
        whenNotPaused
        onlyRole(PAYER_ROLE)
        returns (uint256)
    {
        require(_feeInfo.blueprint != address(0), "no blueprint specified");
        require(_feeInfo.currency != address(0), "no currency specified");
        require(_data_getCurrencyStatus(_feeInfo.currency) == CurrencyStatus.ENABLED, "currency not allowed");
        MyVars memory vars;
        vars.erc = IERC20(_feeInfo.currency);

        IRegistryV2 store = IRegistryV2(_feeInfo.blueprint);
        uint256 fee = 0;
        vars.subAmount = 0;
        //@follow-up add test
        _data_incRunningPaymentBatchId();
        // runningPaymentBatchId++;

        // bool isPaid = false;

        vars.isPaid = false;
        if (_feeInfo.amount > 0) {
            fee = _feeInfo.amount * _data_getProtocolFee() / 100000;
            vars.subAmount = (_feeInfo.amount - fee);
            //protocol gets the fee
            vars.erc.safeTransferFrom(_feeInfo.onBehalfOf, address(this), fee);

            // __DATA__.setUIntValue(keccak256(abi.encodePacked("protocolFee", runningPaymentBatchId)), fee);
            // ercFeeBalances[_feeInfo.currency] += fee;
            uint256 currentFees = _data_getProtocolFees(_feeInfo.currency);
            _data_setProtocolFees(_feeInfo.currency, currentFees + fee);
            //store gets the main amount
            vars.erc.safeTransferFrom(_feeInfo.onBehalfOf, address(store), vars.subAmount);
        }
        vars.isPaid = true;
        _data_incRunningPaymentId();
        PaymentInfo memory info = PaymentInfo({
            paymentBatchId: _data_getRunningPaymentBatchId(),
            id: _data_getRunningPaymentId(),
            paid: vars.isPaid,
            amount: vars.subAmount,
            left: vars.subAmount,
            blockNumber: block.number,
            currency: _feeInfo.currency,
            blueprint: _feeInfo.blueprint,
            royaltyToken: address(0)
        });

        _data_addPaymentInfo(info);
        // payments.push(info);
        return _data_getRunningPaymentBatchId();
    }

    function pay(FeeInfo memory _feeInfo, address _target)
        public
        override
        whenNotPaused
        onlyRole(PAYER_ROLE)
        returns (uint256)
    {
        require(_feeInfo.blueprint != address(0), "no IP specified");
        require(_feeInfo.blueprint == _target, "IP does not match fee target");
        require(_feeInfo.currency != address(0), "no currency specified");
        require(_data_getCurrencyStatus(_feeInfo.currency) == CurrencyStatus.ENABLED, "currency not allowed");
        MyVars memory vars;
        vars.erc = IERC20(_feeInfo.currency);

        vars.erc.safeTransferFrom(_feeInfo.onBehalfOf, address(this), _feeInfo.amount);
        //only do tis for single scope
        vars.fee = _feeInfo.amount * _data_getProtocolFee() / 100000;
        vars.tokens = ITokenized(_target).tokens();
        vars.subAmount = (_feeInfo.amount - vars.fee) / vars.tokens.length;
        vars.ONE_PERCENT = vars.subAmount / 100;
        //@follow-up add test
        _data_incRunningPaymentBatchId();

        // bool isPaid = false;

        vars.isPaid = false;
        if (_feeInfo.minAmount == 0) {
            // console.log("--------> set paid to true");
            vars.isPaid = true;
        }
        for (uint256 royaltyTokenIndex; royaltyTokenIndex < vars.tokens.length; royaltyTokenIndex += 1) {
            // if(_feeInfo.)
            BaseIPPortionToken token = BaseIPPortionToken(vars.tokens[royaltyTokenIndex]);
            _data_incRunningPaymentId();
            PaymentInfo memory info = PaymentInfo({
                paymentBatchId: _data_getRunningPaymentBatchId(),
                id: _data_getRunningPaymentId(),
                paid: vars.isPaid,
                amount: vars.subAmount,
                left: vars.subAmount,
                blockNumber: block.number,
                currency: _feeInfo.currency,
                blueprint: _feeInfo.blueprint,
                royaltyToken: vars.tokens[royaltyTokenIndex]
            });

            _data_addPaymentInfo(info);
            Balance[] memory currentHolders = token.getHolders();
            // console.log("HOLDER COUNT",snapshotCurrent.length);
            uint256 length2 = currentHolders.length;
            for (uint256 holderIndex; holderIndex < length2; holderIndex += 1) {
                Balance memory holderSnapshot = currentHolders[holderIndex];
                if (holderSnapshot.amount > 0) {
                    //@follow-up possible bug with decimals
                    uint256 amountOwed = (holderSnapshot.amount.div(1e18)) * vars.ONE_PERCENT;
                    _data_incRunningClaimId();
                    ClaimInfo memory claim = ClaimInfo({
                        paymentBatchId: _data_getRunningPaymentBatchId(),
                        id: _data_getRunningClaimId(),
                        royaltyToken: info.royaltyToken,
                        paymentId: info.id,
                        target: holderSnapshot.holder,
                        currency: _feeInfo.currency,
                        amount: amountOwed,
                        left: amountOwed,
                        paid: vars.isPaid
                    });
                    _data_pushClaimIdToListByPaymentId(info.id, claim.id);
                    // claimsByPaymentId[info.id].push(claim.id);
                    _data_pushClaimIdToListByAddress(claim.target, claim.id);
                    _data_setClaimByClaimId(claim.id, claim);
                }
            }
        }

        uint256 currentValue = _data_getProtocolFees(_feeInfo.currency);
        _data_setProtocolFees(_feeInfo.currency, currentValue + vars.fee);
        return _data_getRunningPaymentBatchId();
    }

    function getClaimIdsByPaymentId(uint256 _paymentId) public view returns (uint256[] memory) {
        return _data_getClaimIdsByPaymentId(_paymentId);
    }

    function getPaymentInfo(uint256 _id) public view returns (PaymentInfo memory) {
        return _data_getPaymentInfo(_id);
    }

    function getProtocolFee() public view returns (uint256) {
        return _data_getProtocolFee();
    }

    /**
     * @dev Allows the LEGATO_ADMIN_ROLE to set the protocol fee.
     * @param _protocolFee The new protocol fee to set.
     * Requirements:
     * - The function can only be called by the LEGATO_ADMIN_ROLE.
     * - The protocol fee cannot exceed 10%.
     * Emits:
     * - A `ProtocolFeeUpdated` event with the new protocol fee.
     */
    function setProtocolFee(uint256 _protocolFee) public onlyRole(LEGATO_ADMIN_ROLE) {
        require(_protocolFee <= 10000, "Protocol fee cannot exceed 10%");
        _data_setProtocolFee(_protocolFee);
        emit ProtocolFeeUpdated(_protocolFee);
    }

    /**
     * @dev Allows the LEGATO_ADMIN_ROLE to withdraw ERC protocol fees from the contract.
     * @param _ercPaymentToken The address of the ERC20 token to withdraw.
     * @param _to The address to send the tokens to.
     * @param _amount The amount of tokens to withdraw.
     * Requirements:
     * - The function can only be called by the LEGATO_ADMIN_ROLE.
     * Effects:
     * - The function transfers the specified amount of ERC20 tokens to the specified address.
     */
    function withdrawFees(address _ercPaymentToken, address _to, uint256 _amount)
        external
        onlyRole(LEGATO_ADMIN_ROLE)
    {
        uint256 currentFees = _data_getProtocolFees(_ercPaymentToken);
        require(currentFees >= _amount, "Insufficient fee balance for withdrawal");
        _data_setProtocolFees(_ercPaymentToken, currentFees - _amount);
        IERC20(_ercPaymentToken).safeTransfer(_to, _amount);
    }

    function getFeesFor(address token) public view returns (uint256) {
        return _data_getProtocolFees(token);
    }

    /**
     * @dev Allows the LEGATO_ADMIN_ROLE to withdraw native ETH balance from the contract.
     * @param to The address to send the ETH to.
     * @param amount The amount of ETH to withdraw.
     * Requirements:
     * - The function can only be called by the LEGATO_ADMIN_ROLE.
     * Effects:
     * - The function transfers the specified amount of ETH to the specified address.
     */
    function withdrawNativeBalance(address payable to, uint256 amount) external onlyRole(LEGATO_ADMIN_ROLE) {
        (bool success,) = to.call{value: amount}("");
        require(success, "Transfer failed.");
    }
}
