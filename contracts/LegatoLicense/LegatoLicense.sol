// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import "lib/openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";
import "lib/openzeppelin-contracts/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "lib/openzeppelin-contracts/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "lib/openzeppelin-contracts/contracts/security/Pausable.sol";
import "lib/openzeppelin-contracts/contracts/access/AccessControl.sol";
import "lib/openzeppelin-contracts/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "lib/openzeppelin-contracts/contracts/utils/Counters.sol";
import "contracts/interfaces/Structs.sol";
import "contracts/interfaces/BlanketStructs.sol";

/// @custom:security-contact security@legatomusic.xyz
contract LegatoLicense is ERC721, ERC721Enumerable, ERC721URIStorage, Pausable, AccessControl, ERC721Burnable {
    using Counters for Counters.Counter;

    address parentRootRegistry;
    address parentLicenseRegistry;
    mapping(uint256 => PurchasedLicenseV2) idToLicenseInfo;
    mapping(uint256 => LicenseField[]) idToBuyerFields;
    mapping(uint256 => LicenseField[]) idToSellerFields;
    mapping(uint256 => LicenseField[]) idToAutoFields;
    mapping(address => uint256[]) bluePrintAddressToLicenseIds;
    mapping(address => uint256[]) storeAddressToLicenseIds;
    mapping(address => uint256[]) artistAddressToLicenseIds;
    mapping(address => uint256[]) rootAddressToLicenseIds;

    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant ROOTREG_ROLE = keccak256("ROOTREGR_ROLE");
    Counters.Counter private _tokenIdCounter;

    //do not allow transfer from non empty address(override)
    // function _beforeTokenTransfer(address from, address to, uint256 tokenId, uint _batchSize) internal virtual override(ERC721) {
    //     super._beforeTokenTransfer(from, to, tokenId, _batchSize);
    // }

    function getLicenseFields(uint256 id) public view returns (LicenseField[] memory) {
        return idToBuyerFields[id];
    }

    function getLicenseInfo(uint256 id) public view returns (PurchasedLicenseV2 memory) {
        return idToLicenseInfo[id];
    }

    function grantMinter(address _minter) public onlyRole(ROOTREG_ROLE) {
        _grantRole(MINTER_ROLE, _minter);
    }

    function grantAdmin(address _rootRegistry) public onlyRole(DEFAULT_ADMIN_ROLE) {
        parentRootRegistry = _rootRegistry;
        _grantRole(ROOTREG_ROLE, _rootRegistry);
        _grantRole(PAUSER_ROLE, _rootRegistry);
        _grantRole(MINTER_ROLE, _rootRegistry);
    }

    constructor() ERC721("LegatoLicense", "LEGATOLCNS") {
        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
    }

    function _baseURI() internal pure override returns (string memory) {
        return "baseuri";
    }

    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    function safeMint(
        PurchasedLicenseV2 memory _info,
        LicenseField[] memory _buyerFields,
        LicenseField[] memory _sellerFields,
        uint256 _paymentId
    ) public onlyRole(MINTER_ROLE) returns (uint256) {
        require(_info.licenseOwner != address(0), "license: cannot mint to burn address");
        _info.auto_minter = msg.sender;
        _info.auto_blockNumber = block.number;
        _info.auto_timestamp = block.timestamp;
        _info.auto_chainId = block.chainid;
        _info.auto_paymentId = _paymentId;

        _tokenIdCounter.increment();
        uint256 tokenId = _tokenIdCounter.current();
        _info.auto_tokenId = tokenId;

        _safeMint(_info.licenseOwner, tokenId);
        _setTokenURI(tokenId, _info.uri);
        idToLicenseInfo[tokenId] = _info;

        //switch on scope
        if (_info.scope == LicenseScope.SINGLE) {
            bluePrintAddressToLicenseIds[_info.target].push(tokenId);
        } else if (_info.scope == LicenseScope.STORE) {
            storeAddressToLicenseIds[_info.target].push(tokenId);
        } else if (_info.scope == LicenseScope.ARTIST) {
            artistAddressToLicenseIds[_info.target].push(tokenId);
        } else if (_info.scope == LicenseScope.ROOT) {
            rootAddressToLicenseIds[_info.target].push(tokenId);
        } else {
            //TBD - support root and artist
            require(false, "license: invalid scope");
        }

        for (uint256 i; i < _buyerFields.length; i++) {
            idToBuyerFields[tokenId].push(_buyerFields[i]);
        }
        //TODO: add auto fields (niv?)
        for (uint256 i; i < _sellerFields.length; i++) {
            idToSellerFields[tokenId].push(_sellerFields[i]);
        }
        return tokenId;
    }

    //get licenses for root, artist, store, or blueprint

    function getLicensesForBlueprint(address _ipBlueprint) public view returns (uint256[] memory) {
        return bluePrintAddressToLicenseIds[_ipBlueprint];
    }

    function getLicensesForStore(address _store) public view returns (uint256[] memory) {
        return storeAddressToLicenseIds[_store];
    }

    function getLicensesForArtist(address _artist) public view returns (uint256[] memory) {
        return artistAddressToLicenseIds[_artist];
    }

    function getLicensesForRoot(address _root) public view returns (uint256[] memory) {
        return rootAddressToLicenseIds[_root];
    }

    function _beforeTokenTransfer(address from, address to, uint256 tokenId, uint256 batchsize)
        internal
        override(ERC721, ERC721Enumerable)
        whenNotPaused
    {
        require(from == address(0) || to == address(0), "license is not transferrable. Only mintable and burnable");
        super._beforeTokenTransfer(from, to, tokenId, batchsize);
    }

    // The following functions are overrides required by Solidity.

    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }

    function tokenURI(uint256 tokenId) public view override(ERC721, ERC721URIStorage) returns (string memory) {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function checkSingleLicense(PurchasedLicenseV2 storage license, address _licensee, LicenseScope _scope)
        internal
        view
        returns (bool)
    {
        if (license.licenseOwner == _licensee && license.scope == _scope) {
            if (license.canExpire == false) {
                return true;
            }
            if (license.canExpire && license.expiryDate > block.timestamp) {
                return true;
            }
        }
        return false;
    }

    function isLicensed(address _target, address _licensee) public view returns (bool) {
        //ToDO: check expiry date

        //check at song Level
        uint256[] memory licenses = getLicensesForBlueprint(_target);
        for (uint256 i; i < licenses.length; i++) {
            PurchasedLicenseV2 storage license = idToLicenseInfo[licenses[i]];
            if (true == checkSingleLicense(license, _licensee, LicenseScope.SINGLE)) {
                return true;
            }
        }
        //Check at store level
        address parentStore = ISong(_target).songLedger();
        uint256[] memory storeBlanketLicenses = getLicensesForStore(parentStore);
        for (uint256 i; i < storeBlanketLicenses.length; i++) {
            PurchasedLicenseV2 storage license = idToLicenseInfo[storeBlanketLicenses[i]];
            if (true == checkSingleLicense(license, _licensee, LicenseScope.SINGLE)) {
                return true;
            }
        }

        // check at artist level
        address storeOwner = IStore(parentStore).ownerWallet();
        uint256[] memory storeOwnerLicenses = getLicensesForArtist(storeOwner);
        for (uint256 i; i < storeOwnerLicenses.length; i++) {
            PurchasedLicenseV2 storage license = idToLicenseInfo[storeOwnerLicenses[i]];
            if (true == checkSingleLicense(license, _licensee, LicenseScope.SINGLE)) {
                return true;
            }
        }

        return false;
    }
}

interface IStore {
    function ownerWallet() external view returns (address);
}

interface ISong {
    function songLedger() external view returns (address);
}
