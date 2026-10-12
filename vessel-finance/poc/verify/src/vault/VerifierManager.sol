/*
Copyright 2024 Vessel Team.

Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the
License. You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an
"AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific
language governing permissions and limitations under the License.
*/
// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.19;

import { Governance } from "./Governance.sol";

contract VerifierManager is Governance {
    /**********
     * Events *
     **********/

    event LogNewSnarkVerifier(address);
    event LogNewCircuitVersion(string);
    event LogNewEternalTreeRoot(uint256);
    event LogNewEphemeralTreeRoot(uint256);

    /***************
     * Constructor *
     ***************/

    function initVerifierManager() public initializer {
        circuitVersion = "";
        snarkVerifier = address(0);
        eternalTreeRoot = 0;
        ephemeralTreeRoot = 0;
    }

    /*************************
     * Public View Functions *
     *************************/

    /// @notice Get SNARK verifier address.
    function getSnarkVerifierAddress() public view returns (address) {
        return snarkVerifier;
    }

    /// @notice Get circuit version.
    function getCircuitVersion() public view returns (string memory) {
        return circuitVersion;
    }

    /// @notice Get eternal tree root.
    function getEternalTreeRoot() public view returns (uint256) {
        return eternalTreeRoot;
    }

    /// @notice Get ephemeral tree root.
    function getEphemeralTreeRoot() public view returns (uint256) {
        return ephemeralTreeRoot;
    }

    /************************
     * Restricted Functions *
     ************************/

    /// @notice Only admin can update verifier.
    function updateAll(address snarkVerifier, string calldata circuitVersion) public onlyAdmin {
        updateSnarkVerifierAddress(snarkVerifier);
        updateCircuitVersion(circuitVersion);
    }

    /// @notice Only admin can update verifier.
    function updateSnarkVerifierAddress(address newVerifier) public onlyAdmin {
        snarkVerifier = newVerifier;
        emit LogNewSnarkVerifier(snarkVerifier);
    }

    /// @notice Only admin can update circuit version.
    function updateCircuitVersion(string calldata newCircuitVersion) public onlyAdmin {
        circuitVersion = newCircuitVersion;
        emit LogNewCircuitVersion(newCircuitVersion);
    }

    /**********************
     * Internal Functions *
     **********************/

    /// @dev Only verified SNARK proof should update new root.
    function updateEternalTreeRoot(uint256 newEternalTreeRoot) internal {
        eternalTreeRoot = newEternalTreeRoot;
        emit LogNewEternalTreeRoot(newEternalTreeRoot);
    }

    /// @dev Only verified SNARK proof should update new root.
    function updateEphemeralTreeRoot(uint256 newEphemeralTreeRoot) internal {
        ephemeralTreeRoot = newEphemeralTreeRoot;
        emit LogNewEphemeralTreeRoot(newEphemeralTreeRoot);
    }
}
