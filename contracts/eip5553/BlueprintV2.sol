// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import "lib/openzeppelin-contracts/contracts/access/AccessControl.sol";
import "lib/openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";
import "./IIPRepresentation.sol";
import "contracts/interfaces/ITokenized.sol";
import "contracts/interfaces/Structs.sol";
import "contracts/interfaces/IVersioned.sol";

contract BlueprintV2 is ERC721, IIPRepresentation, ITokenized, AccessControl, IVersioned {
    bool initialized;
    string public override kind;
    address public songLedger;
    address[] _tokens;
    string public override metadataURI;
    string public fileHash;
    string private __name;
    string private __symbol;
    uint256 public tokenId;
    bool public activated;
    bytes32 public constant BINDER_ROLE = keccak256("BINDER_ROLE");
    bytes32 public constant ITEM_STORE_OWNER_ROLE = keccak256("ITEM_STORE_OWNER_ROLE");

    function getVersion() external pure override returns (uint8) {
        return 2;
    }

    /**
     * @dev See {IERC721Metadata-name}.
     */
    function name() public view override returns (string memory) {
        return __name;
    }

    // /**
    //  * @dev See {IERC721Metadata-symbol}.
    //  */
    function symbol() public view override returns (string memory) {
        return __symbol;
    }

    modifier isInitialized() {
        require(initialized, "blueprintv2 not initialized!");
        _;
    }

    modifier onlyOwner() {
        require(msg.sender == songLedger, "BlueprintV2: only owner allowed");
        _;
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC721, IERC165, AccessControl)
        returns (bool)
    {
        return interfaceId == type(IIPRepresentation).interfaceId || super.supportsInterface(interfaceId);
    }

    function tokens() public view override returns (address[] memory) {
        return royaltyPortionTokens();
    }

    function getInterfaceId() public pure returns (bytes4) {
        return type(IIPRepresentation).interfaceId;
    }

    function addBinder(address _binder) public override isInitialized onlyRole(DEFAULT_ADMIN_ROLE) {
        _grantRole(BINDER_ROLE, _binder);
    }

    function initialize(
        uint256 _tokenId,
        address _songLedger,
        string memory _metadataURI,
        string memory _shortName,
        string memory _symbol,
        string memory _kind,
        string memory _fileHash
    ) public {
        require(!initialized, "already initialized!");
        initialized = true;

        __name = _shortName;
        __symbol = _symbol;
        _grantRole(DEFAULT_ADMIN_ROLE, _songLedger);
        _grantRole(BINDER_ROLE, _songLedger);
        songLedger = _songLedger;
        metadataURI = _metadataURI;
        fileHash = _fileHash;
        tokenId = _tokenId;
        kind = _kind;

        _safeMint(_songLedger, _tokenId);
        emit Minted(_shortName, _songLedger, _msgSender(), tokenId, _metadataURI);
    }

    constructor(
        uint256 _tokenId,
        address _songLedger,
        string memory _metadataURI,
        string memory _shortName,
        string memory _symbol,
        string memory _kind,
        string memory _fileHash
    ) ERC721(_shortName, _symbol) {
        initialize(_tokenId, _songLedger, _metadataURI, _shortName, _symbol, _kind, _fileHash);
    }

    function changeMetadataURI(string memory _newURI, string memory _newFileHash)
        public
        override
        onlyRole(DEFAULT_ADMIN_ROLE)
        isInitialized
    {
        string memory oldURI = metadataURI;
        string memory oldHash = fileHash;
        metadataURI = _newURI;
        fileHash = _newFileHash;

        emit MetadataChanged(oldURI, oldHash, _newURI, _newFileHash);
    }

    function royaltyPortionTokens() public view override returns (address[] memory) {
        return _tokens;
    }

    function bindToken(address token) public override isInitialized onlyRole(BINDER_ROLE) {
        require(token != address(0), "cannot add address 0 token");
        _tokens.push(token);
    }

    function ledger() external view override returns (address) {
        return songLedger;
    }

    function isOwner(address addr) external view returns (bool) {
        return hasRole(DEFAULT_ADMIN_ROLE, addr);
    }

    event MetadataChanged(string oldUri, string oldFileHash, string newUri, string newFileHash);
    event Minted(string abbvName, address ledger, address creator, uint256 tokenId, string metadataUri);
}
