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
import { IERC20 } from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract TokenManager is Governance {
    /**********
     * Events *
     **********/

    event LogAssetActive(uint256 assetId);
    event LogAssetInactive(uint256 assetId);
    event LogAssetRegistered(
        uint256 assetId, address assetAddress, uint8 limitDigit, uint8 precisionDigit, uint8 decimals
    );
    event LogAssetLimitAndPrecisionUpdated(uint256 assetId, uint8 limitDigit, uint8 precisionDigit);
    event LogWethAddressSet(address addr);

    /**********************
     * Function Modifiers *
     **********************/

    modifier assetActive(uint256 assetId) {
        _checkAssetActive(assetId);
        _;
    }

    modifier vaultAssetAmountUnderLimit(uint256 assetId) {
        _;
        _checkVaultAssetAmountUnderLimit(assetId);
    }

    /***************
     * Constructor *
     ***************/

    function initTokenManager() public initializer {
        // Register native asset (address 0) as id 0.
        assetAddressToId[address(0)] = 0;
        assetIdToInfo[0] = AssetInfo(address(0), 10, 8, 18, false);
    }

    /// @notice WETH used to wrap/unwrap ETH
    function setWethAddress(address addr) external onlyAdmin {
        wethAddress = addr;
        emit LogWethAddressSet(addr);
    }

    /*************************
     * Public View Functions *
     *************************/

    /// @notice Asset is ERC20 iff assetId > 0.
    function isERC20(uint256 assetId) public pure returns (bool) {
        return assetId > 0;
    }

    /// @notice Asset is native iff assetId == 0.
    function isNative(uint256 assetId) public pure returns (bool) {
        return assetId == 0;
    }

    /// @notice Retrieve assetInfo by assetId.
    function getAssetInfo(uint256 assetId)
        public
        view
        returns (address assetAddress, uint8 limitDigit, uint8 precisionDigit, uint8 decimals, bool isActive)
    {
        assetAddress = assetIdToInfo[assetId].assetAddress;
        limitDigit = assetIdToInfo[assetId].limitDigit;
        precisionDigit = assetIdToInfo[assetId].precisionDigit;
        decimals = assetIdToInfo[assetId].decimals;
        isActive = assetIdToInfo[assetId].isActive;
    }

    /// @notice Get assetId from contract address.
    function extractAssetId(address assetAddress) public view returns (uint256) {
        return assetAddressToId[assetAddress];
    }

    /// @notice constrain amount to align with asset precisionDigit and decimals.
    ///     The returned constrainedAmount is truncated to be multiple of (0.1 ** precisionDigit) 
    ///     and then multiply to (10 ** decimals).
    function constrainAmountWithPrecision(
        uint256 assetId,
        uint256 amount
    )
        public
        view
        returns (uint256 constrainedAmount)
    {
        uint8 precisionDigit = assetIdToInfo[assetId].precisionDigit;
        uint8 decimals = assetIdToInfo[assetId].decimals;
        uint256 divisor = uint256(10) ** uint256(decimals - precisionDigit);
        constrainedAmount = (amount / divisor) * divisor;
    }

    /*****************************
     * Public Mutating Functions *
     *****************************/

    /// @notice Only operator can register a new asset.
    function registerNewAsset(
        address assetAddress,
        uint256 assetId,
        uint8 limitDigit,
        uint8 precisionDigit,
        uint8 decimals
    )
        public
        onlyOperator
    {
        _registerNewAsset(assetAddress, assetId, limitDigit, precisionDigit, decimals);
    }

    /// @notice Only operator can update limitDigit and precisionDigit. Asset address and decimals cannot be changed.
    function updateAssetLimitAndPrecision(
        uint256 assetId,
        uint8 limitDigit,
        uint8 precisionDigit
    )
        public
        onlyOperator
    {
        require(
            precisionDigit <= assetIdToInfo[assetId].decimals,
            "Token Manager: precision digit must be smaller than token decimals"
        );
        assetIdToInfo[assetId].limitDigit = limitDigit;
        assetIdToInfo[assetId].precisionDigit = precisionDigit;
        emit LogAssetLimitAndPrecisionUpdated(assetId, limitDigit, precisionDigit);
    }

    /// @notice Only operator can activate an asset.
    function setAssetActive(uint256 assetId) public onlyOperator {
        assetIdToInfo[assetId].isActive = true;
        emit LogAssetActive(assetId);
    }

    /// @notice Only operator can activate an asset.
    function setAssetInactive(uint256 assetId) public onlyOperator {
        assetIdToInfo[assetId].isActive = false;
        emit LogAssetInactive(assetId);
    }

    /**********************
     * Internal Functions *
     **********************/

    function _checkAssetActive(uint256 assetId) internal view {
        require(assetIdToInfo[assetId].isActive, "Token Manager: asset is not active");
    }

    function _checkVaultAssetAmountUnderLimit(uint256 assetId) internal view {
        uint256 amountLimit = uint256(10) ** uint256(assetIdToInfo[assetId].limitDigit);
        uint256 amountLimitWithDecimals = (uint256(10) ** uint256(assetIdToInfo[assetId].decimals)) * amountLimit;
        if (isNative(assetId)) {
            require(address(this).balance < amountLimitWithDecimals, "Token Manager: vault amount exceeds asset limit");
        } else {
            require(
                IERC20(assetIdToInfo[assetId].assetAddress).balanceOf(address(this)) < amountLimitWithDecimals, 
                "Token Manager: vault amount exceeds asset limit"
            );
        }
    }

    function _checkAndExtractAssetId(address assetAddress) internal view returns (uint256) {
        uint256 assetId = 0;
        if (assetAddress != ETH_ADDRESS) {
            assetId = assetAddressToId[assetAddress];
            require(assetId != 0, "Token Manager: token is not registered");
        }
        _checkAssetActive(assetId);
        return assetId;
    }

    /// @dev Internal function for register new asset. New registered asset will be inactive by default.
    /// @param limitDigit deposit amount will be constrained to less than (10 ** limitDigit).
    /// @param precisionDigit deposit amount will be constrained to be multiple of (0.1 ** precisionDigit), taking
    ///     decimals into consideration.
    /// @param decimals ERC20 token decimals.
    function _registerNewAsset(
        address assetAddress,
        uint256 assetId,
        uint8 limitDigit,
        uint8 precisionDigit,
        uint8 decimals
    )
        internal
    {
        require(assetId <= 0xFFFFFFFF, "Token Manager: asset id does not fit in 4 bytes");
        require(assetAddressToId[assetAddress] == 0, "Token Manager: registered asset");
        require(assetIdToInfo[assetId].assetAddress == address(0), "Token Manager: registered assetId");
        require(assetAddress != address(0) && assetId != 0, "Token Manager: native token is registered to assetId 0");
        require(precisionDigit <= decimals, "Token Manager: precision digit must be smaller than token decimals");
        assetAddressToId[assetAddress] = assetId;

        assetIdToInfo[assetId] = AssetInfo(assetAddress, limitDigit, precisionDigit, decimals, false);
        emit LogAssetRegistered(assetId, assetAddress, limitDigit, precisionDigit, decimals);
    }
}
