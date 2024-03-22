// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import "contracts/registries/RegistryImplV1.sol";
import "contracts/dataBound/RootRegistry/RootRegistry.sol";
import "contracts/dataBound/LicenseRegistry/LicenseRegistry.sol";
import "contracts/interfaces/Structs.sol";
import "contracts/VerifyHelperDAL.sol";
import "contracts/storage/EternalStorage.sol";
import "lib/openzeppelin-contracts-upgradeable/contracts/access/AccessControlUpgradeable.sol";
import "lib/openzeppelin-contracts-upgradeable/contracts/proxy/utils/Initializable.sol";
import "contracts/dataBound/CommonUpgradeableStorageVars.sol";
import "lib/openzeppelin-contracts-upgradeable/contracts/security/PausableUpgradeable.sol";
import "contracts/interfaces/IVersioned.sol";
// import "lib/openzeppelin-contracts-upgradeable/contracts/security/PausableUpgradeable.sol";

contract VerifyHelper is VerifyHelperDAL, AccessControlUpgradeable, IVersioned {
    function getVersion() external pure override returns (uint8) {
        return 1; //Increment at every new cotract version
    }

    function initialize(address _storage) public initializer {
        __AccessControl_init();
        __DATA__ = EternalStorage(_storage);
    }

    function notEmpty(address _addr, string memory _name) internal pure {
        // consider making it pure?
        require(_addr != address(0), string(abi.encodePacked(_name, " issue")));
    }

    function checkRootConfiguration() public view {
        notEmpty(getAddressManager().getFeeDistributor(), "FeeDistributor");
        notEmpty(getAddressManager().getTokenDistributor(), "TokenDistributor");
        notEmpty(getAddressManager().getLicenseRegistry(), "licenseRegistry");
        notEmpty(getAddressManager().getVerifyHelper(), "verifyhelper");
        notEmpty(getAddressManager().getLicenseContract(), "legatolicense");
        notEmpty(getAddressManager().getUSDCContract(), "usdc");
    }

    function checkOptedInLicense(uint256 _licenseBlueprintId, address _byRegistry) public view {
        LicenseRegistry licReg = LicenseRegistry(getAddressManager().getLicenseRegistry());
        require(
            licReg.getOptInStatus(_byRegistry, _licenseBlueprintId) == true,
            "registryv2 license not opted-in or does not exist"
        );
    }

    function checkOptInPreconditions(MintLicenseRequest memory req, address _registry) public view {
        LicenseRegistry licReg = LicenseRegistry(getAddressManager().getLicenseRegistry());
        uint256[] memory preconditionIds = licReg.getOptinIdsForLicenseBlueprintId(_registry, req.licenseBlueprintId);
        bool found = false;
        uint256 length = preconditionIds.length;
        for (uint256 i; i < length;) {
            uint256 optinId = preconditionIds[i];
            LicenseOptInV2 memory optinInfo = licReg.getOptInById(optinId);
            if (
                optinInfo.active && optinInfo.registry == _registry
                    && optinInfo.licenseBlueprintId == req.licenseBlueprintId && optinInfo.minAmount <= req.amount
                    && optinInfo.currency == req.currency
            ) {
                found = true;
                break;
            }
            unchecked {
                ++i;
            }
        }

        require(found, "These payment terms do not match any of the allowed terms by the registry for this license.");
    }

    function checkTargetBeforeLicense(MintLicenseRequest memory _mlr, address _registry) public view {
        LicenseRegistry licReg = LicenseRegistry(getAddressManager().getLicenseRegistry());
        LicenseBlueprintInfoV2 memory info = licReg.getLicenseBlueprintbyId(_mlr.licenseBlueprintId);
        if (info.scope == uint8(LicenseScope.STORE)) {
            require(_mlr.target == _registry, "checkTargetBeforeLicense: for STORE scope, target must be the store");
        }
        if (info.scope == uint8(LicenseScope.SINGLE)) {
            IRegistryV2 reg = IRegistryV2(_registry);
            require(reg.isChild(_mlr.target), "checkScopeBeforeOptin: target must be a child of the registry");
        }
    }

    function checkScopeBeforeOptin(uint256 _licenseBlueprintId, LicenseScope _scope) public view {
        LicenseRegistry licReg = LicenseRegistry(getAddressManager().getLicenseRegistry());
        LicenseBlueprintInfoV2 memory info = licReg.getLicenseBlueprintbyId(_licenseBlueprintId);
        require(uint8(info.scope) == uint8(_scope), "checkScopeBeforeOptin: license scope mismatch");
    }

    function checkActiveLicense(uint256 _licenseBlueprintId) public view {
        LicenseRegistry licReg = LicenseRegistry(getAddressManager().getLicenseRegistry());
        LicenseBlueprintInfoV2 memory info = licReg.getLicenseBlueprintbyId(_licenseBlueprintId);
        require(info.active == true, "registryv2 license blueprint not active yet/anymore");
    }

    function checkFields(MintLicenseRequest memory _REQ) public view {
        LicenseRegistry licReg = LicenseRegistry(getAddressManager().getLicenseRegistry());
        LicenseBlueprintInfoV2 memory expected = licReg.getLicenseBlueprintbyId(_REQ.licenseBlueprintId);
        //check scope is the same
        require(
            expected.buyerFields.length == _REQ.buyerFields.length, "registryv2: buyer license field count mismatch"
        );
        uint256 loopLength = expected.buyerFields.length;
        for (uint256 i; i < loopLength;) {
            // console.log("expected buyer field id: ", expected.buyerFields[i].id, expected.buyerFields[i].name);
            // console.log("actual buyer field id:   ", _REQ.buyerFields[i].id, _REQ.buyerFields[i].name);
            // console.log("--------------------");
            require(
                expected.buyerFields[i].id == _REQ.buyerFields[i].id, "registryv2: license: buyer field id mismatch"
            );
            require(
                keccak256(abi.encodePacked(expected.buyerFields[i].name))
                    == keccak256(abi.encodePacked(_REQ.buyerFields[i].name)),
                "registryv2: license: buyer field name mismatch"
            );
            unchecked {
                ++i;
            }
        }
    }

    function checkLicense(MintLicenseRequest memory req, address _registry) external view {
        checkActiveLicense(req.licenseBlueprintId);
        checkOptedInLicense(req.licenseBlueprintId, _registry);
        checkTargetBeforeLicense(req, _registry);
        checkFields(req);
        checkOptInPreconditions(req, _registry);
    }
}
