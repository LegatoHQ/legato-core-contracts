// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import "lib/openzeppelin-contracts/contracts/access/AccessControl.sol";
import "contracts/interfaces/Structs.sol";
import "contracts/interfaces/BlanketStructs.sol";
import "contracts/interfaces/ILicenseBlueprint.sol";
import "lib/forge-std/src/console.sol";

contract LicenseBlueprint is ILicenseBlueprint, AccessControl {
    uint8 public scope;
    address public owner;
    address public controller;
    string public uri;
    string public ipfsFileHash;
    bool public canExpire;
    bool public active;
    string public name;
    uint256 public fee;
    LicenseField[] public sellerFields;
    LicenseField[] public buyerFields;
    LicenseField[] public autoFields;

    function makeCopy() private view returns (LicenseBlueprintInfoV2 memory) {
        LicenseBlueprintInfoV2 memory bpi = LicenseBlueprintInfoV2({
            contractAddress: address(this),
            owner: owner,
            controller: controller,
            uri: uri,
            ipfsFileHash: ipfsFileHash,
            canExpire: canExpire,
            active: active,
            name: name,
            fee: fee,
            sellerFields: new LicenseField[](sellerFields.length),
            buyerFields: new LicenseField[](buyerFields.length),
            autoFields: new LicenseField[](autoFields.length),
            scope: scope
        });

        return bpi;
    }

    function getFieldsAsMemory(LicenseField[] memory from) internal pure returns (LicenseField[] memory to) {
        uint256 length = from.length;
        to = new LicenseField[](length);
        for (uint256 i = 0; i < length;) {
            to[i] = LicenseField({
                id: from[i].id,
                name: from[i].name,
                val: from[i].val,
                dataType: from[i].dataType,
                info: from[i].info
            });
            unchecked {
                ++i;
            }
        }
    }

    function getBlueprintInfo() external view override returns (LicenseBlueprintInfoV2 memory) {
        LicenseBlueprintInfoV2 memory bpi = makeCopy();
        bpi.sellerFields = getFieldsAsMemory(sellerFields);
        bpi.buyerFields = getFieldsAsMemory(buyerFields);
        bpi.autoFields = getFieldsAsMemory(autoFields);
        // uint lengthSeller = bpi.sellerFields.length;
        // for (uint i; i < lengthSeller;) {
        //     bpi.sellerFields[i] = LicenseField({
        //         name:sellerFields[i].name,
        //         val:sellerFields[i].val,
        //         id:sellerFields[i].id
        //     });
        //     unchecked { ++i; }
        // }

        // uint lengthAuto = bpi.autoFields.length;
        // for (uint i; i < lengthAuto;) {
        //     bpi.buyerFields[i] = LicenseField({
        //         name:autoFields[i].name,
        //         val:autoFields[i].val,
        //         id:autoFields[i].id
        //     });
        //     unchecked { ++i; }
        // }
        // uint lengthBuyer = bpi.buyerFields.length;
        // for (uint i; i < lengthBuyer;) {
        //     bpi.buyerFields[i] = LicenseField({
        //         name:buyerFields[i].name,
        //         val:buyerFields[i].val,
        //         id:buyerFields[i].id
        //     });
        //     unchecked { ++i; }
        // }
        return bpi;
    }

    constructor(
        address _controller,
        string memory _uri,
        string memory _ipfsFileHash,
        string memory _name,
        LicenseField[] memory _sellerFields,
        LicenseField[] memory _buyerFields,
        LicenseField[] memory _autoFields,
        bool _canExpire,
        uint256 _fee,
        bool _active,
        uint8 _scope
    ) {
        _grantRole(DEFAULT_ADMIN_ROLE, _controller);
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        owner = msg.sender;
        controller = _controller;
        active = _active;
        uri = _uri;
        ipfsFileHash = _ipfsFileHash;
        canExpire = _canExpire;
        name = _name;
        fee = _fee;
        scope = _scope;
        // console.log("ctor: fields length" , _fields.length );
        uint256 sellerLength = _sellerFields.length;
        for (uint256 i; i < sellerLength;) {
            sellerFields.push(
                LicenseField({
                    name: _sellerFields[i].name,
                    val: _sellerFields[i].val,
                    id: _sellerFields[i].id,
                    dataType: _sellerFields[i].dataType,
                    info: _sellerFields[i].info
                })
            );
            unchecked {
                ++i;
            }
        }
        uint256 autoLength = _autoFields.length;
        for (uint256 i; i < autoLength;) {
            autoFields.push(
                LicenseField({
                    name: _autoFields[i].name,
                    val: _autoFields[i].val,
                    id: _autoFields[i].id,
                    dataType: _autoFields[i].dataType,
                    info: _autoFields[i].info
                })
            );
            unchecked {
                ++i;
            }
        }
        uint256 buyerLength = _buyerFields.length;
        for (uint256 i; i < buyerLength;) {
            // console.log("adding field id",_buyerFields[i].id);
            buyerFields.push(
                LicenseField({
                    name: _buyerFields[i].name,
                    val: _buyerFields[i].val,
                    id: _buyerFields[i].id,
                    dataType: _buyerFields[i].dataType,
                    info: _buyerFields[i].info
                })
            );
            unchecked {
                ++i;
            }
        }
    }
}
