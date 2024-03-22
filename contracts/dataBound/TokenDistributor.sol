// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

// import "lib/forge-std/src/console.sol";
import "lib/openzeppelin-contracts/contracts/utils/Counters.sol";
import "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol"; // Import the SafeERC20 library
import "../eip5553/BlueprintV2.sol";
import "../Cloner.sol";
import "./TokenDistributorDAL.sol";
import "contracts/interfaces/BaseIPPortionToken.sol";
import "lib/openzeppelin-contracts-upgradeable/contracts/access/AccessControlUpgradeable.sol";

interface IBaseIPPortionToken {
    function initialize(
        address _ledger,
        address _rootIP,
        address _initialHolder,
        string memory _kind,
        string memory _name,
        string memory _symbol
    ) external;
}

contract TokenDistributor is TokenDistributorDAL, AccessControlUpgradeable, IVersioned {
    function getVersion() external pure override returns (uint8) {
        return 1;
    }

    using SafeERC20 for IERC20; // Use the SafeERC20 library for IERC20 tokens

    bytes32 public constant TOKENER_ROLE = keccak256("TOKENER_ROLE");
    bytes32 public constant TOKEN_ROLE = keccak256("TOKEN_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    function initialize(address _storage, address _owner) public initializer {
        // console.log(">>>>>>>> TokenDistributor.initialize: msg.sender", msg.sender, "calling", address(this) );
        __AccessControl_init();
        __DATA__ = EternalStorage(_storage);
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(DEFAULT_ADMIN_ROLE, _owner);
        _grantRole(TOKENER_ROLE, _owner);
        _grantRole(MINTER_ROLE, _owner);
        _grantRole(MINTER_ROLE, msg.sender);
    }

    function grantTokener(address _registry) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _grantRole(TOKENER_ROLE, _registry);
        _grantRole(MINTER_ROLE, _registry);
    }

    function grantAdmin(address _registry) public onlyRole(DEFAULT_ADMIN_ROLE) {
        // console.log(">>>>>>>> TokenDistributor.grandAdmin: msg.sender", msg.sender, "calling", address(this) );
        _grantRole(DEFAULT_ADMIN_ROLE, _registry);
    }

    function distribute(address _tokenAddress, SplitTarget[] memory _targets, address _ipAddress)
        public
        onlyRole(TOKENER_ROLE)
    {
        // BaseIPPortionToken token = BaseIPPortionToken(_tokenAddress);
        IERC20 token = IERC20(_tokenAddress); // Use the IERC20 interface for the token

        uint256 length = _targets.length;
        uint256 totalDealt = 0;
        for (uint256 i; i < length;) {
            SplitTarget memory targetInfo; // = _targets[i];
            assembly {
                //set targetInfo to items [i]
                targetInfo := mload(add(add(_targets, 0x20), mul(i, 0x20)))
            }
            //@follow-up add test
            require(targetInfo.holderAddress != address(0), "cannot split to burn address");
            //@follow-up add test
            require(targetInfo.amount > 0, "cannot split to zero amount");
            // uint amount = targetInfo.amount * 1e18;
            uint256 amount = targetInfo.amount;
            //ERC20Permit
            token.safeTransfer(targetInfo.holderAddress, amount);
            totalDealt += amount;

            emit RoyaltyTokenDistributed(
                _ipAddress, BaseIPPortionToken(_tokenAddress).kind(), _tokenAddress, amount, targetInfo.holderAddress
            );

            unchecked {
                ++i;
            }
        }
        require(totalDealt == 100e18, "split does not add up to 100");
    }

    function associateTokenToWallet(address _tokenAddress, address _wallet) public onlyRole(TOKEN_ROLE) {
        _data_pushTokensToWallet(_wallet, _tokenAddress);
    }

    function getAssociatedTokens(address _wallet) public view returns (address[] memory) {
        return _data_getTokensForWallet(_wallet);
    }

    function mintIPTokens(RoyaltyTokenData[] memory _tokens, address _ipAddress, address _registry)
        public
        onlyRole(MINTER_ROLE)
    {
        uint256 length = _tokens.length;
        //@follow-up add test
        require(length > 0, "no tokens to mint");
        for (uint256 i; i < length;) {
            //@follow-up add test
            require(_tokens[i].targets.length > 0, "no token split targets found");
            address tokenAddr = Cloner.createClone(getAddressManager().getBaseIPPortionTokenImpl());
            _grantRole(TOKEN_ROLE, tokenAddr); //needs to happen before distribute to allow token to call associateTokenToWallet
            IBaseIPPortionToken token = IBaseIPPortionToken(tokenAddr);
            token.initialize(_registry, _ipAddress, address(this), _tokens[i].kind, _tokens[i].name, _tokens[i].symbol);

            ITokenized(_ipAddress).bindToken(tokenAddr);

            distribute(tokenAddr, _tokens[i].targets, _ipAddress);
            unchecked {
                ++i;
            }
        }
    }

    event RoyaltyTokenDistributed(
        address ipAddress, string tokenType, address tokenAddress, uint256 amount, address receiver
    );
}
