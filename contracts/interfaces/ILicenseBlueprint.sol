// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import "./Structs.sol";
import "./BlanketStructs.sol";

interface ILicenseBlueprint {
    function getBlueprintInfo() external view returns (LicenseBlueprintInfoV2 memory);
}
