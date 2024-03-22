// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import "lib/openzeppelin-contracts/contracts/utils/introspection/IERC165.sol";

interface IIPRepresentation is IERC165 {
    /// @notice returns the kind of IP represented. i.e 'video', 'audio', 'image' or something else.
    function kind() external returns (string memory);

    /// @notice Called with the new URI to an updated metadata file
    /// @param _newUri - the URI pointing to a metadata file (file standard is up to the implementer)
    /// @param _newFileHash - The hash of the new metadata file for future reference and verification
    function changeMetadataURI(string memory _newUri, string memory _newFileHash) external;

    /// @return array of addresses of ERC20 tokens representing royalty portion in the IP
    /// @dev i.e implementing ERC5501 (IRoyaltyInterestToken interface)
    function royaltyPortionTokens() external view returns (address[] memory);

    /// @return the address of the contract or EOA that initialized the IP registration
    /// @dev i.e., a registry or registrar, to be implemented in the future
    function ledger() external view returns (address);

    /// @return the URI of the current metadata file for the II P
    function metadataURI() external view returns (string memory);

    /// @dev event to be triggered whenever metadata URI is changed
    /// @param byAddress the addresses that triggered this operation
    /// @param oldURI the URI to the old metadata file before the change
    /// @param oldFileHash the hash of the old metadata file before the change
    /// @param newURI the URI to the new metadata file
    /// @param newFileHash the hash of the new metadata file
    event MetadaDataChanged(address byAddress, string oldURI, string oldFileHash, string newURI, string newFileHash);
}
