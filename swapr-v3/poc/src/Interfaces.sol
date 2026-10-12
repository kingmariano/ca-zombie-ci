// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// Minimal interfaces for Swapr V3 (Algebra V1.9) live-state PoC — Gnosis chain.
// Addresses are passed in from the test; no secrets here.

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
    function transfer(address, uint256) external returns (bool);
    function decimals() external view returns (uint8);
    function totalSupply() external view returns (uint256);
    function symbol() external view returns (string memory);
}

interface IAlgebraPool {
    function token0() external view returns (address);
    function token1() external view returns (address);
    function factory() external view returns (address);
    function tickSpacing() external view returns (int24);
    function liquidity() external view returns (uint128);
    function activeIncentive() external view returns (address);
    function liquidityCooldown() external view returns (uint32);
    function dataStorageOperator() external view returns (address);
    function totalFeeGrowth0Token() external view returns (uint256);
    function totalFeeGrowth1Token() external view returns (uint256);
    function globalState()
        external
        view
        returns (
            uint160 price,
            int24 tick,
            uint16 fee,
            uint16 timepointIndex,
            uint8 communityFeeToken0,
            uint8 communityFeeToken1,
            bool unlocked
        );
    function positions(bytes32 key)
        external
        view
        returns (
            uint128 liquidity,
            uint32 lastLiquidityAddTimestamp,
            uint256 innerFeeGrowth0Token,
            uint256 innerFeeGrowth1Token,
            uint128 fees0,
            uint128 fees1
        );
    function initialize(uint160 price) external;
    function mint(address sender, address recipient, int24 bottomTick, int24 topTick, uint128 liquidityDesired, bytes calldata data)
        external
        returns (uint256 amount0, uint256 amount1, uint128 liquidityActual);
    function burn(int24 bottomTick, int24 topTick, uint128 amount) external returns (uint256 amount0, uint256 amount1);
    function collect(address recipient, int24 bottomTick, int24 topTick, uint128 amount0Requested, uint128 amount1Requested)
        external
        returns (uint128 amount0, uint128 amount1);
    function swap(address recipient, bool zeroToOne, int256 amountRequired, uint160 limitSqrtPrice, bytes calldata data)
        external
        returns (int256 amount0, int256 amount1);
    function swapSupportingFeeOnInputTokens(address sender, address recipient, bool zeroToOne, int256 amountRequired, uint160 limitSqrtPrice, bytes calldata data)
        external
        returns (int256 amount0, int256 amount1);
    function flash(address recipient, uint256 amount0, uint256 amount1, bytes calldata data) external;
    function setCommunityFee(uint8 communityFee0, uint8 communityFee1) external;
    function setTickSpacing(int24 newTickSpacing) external;
    function setLiquidityCooldown(uint32 newLiquidityCooldown) external;
    function setIncentive(address virtualPoolAddress) external;
    function getTimepoints(uint32[] calldata secondsAgos)
        external
        view
        returns (int56[] memory tickCumulatives, uint160[] memory secondsPerLiquidityCumulatives, uint112[] memory volatilityCumulatives, uint256[] memory volumePerAvgLiquiditys);
}

interface IAlgebraFactory {
    function owner() external view returns (address);
    function poolDeployer() external view returns (address);
    function farmingAddress() external view returns (address);
    function vaultAddress() external view returns (address);
    function defaultCommunityFee() external view returns (uint8);
    function poolByPair(address, address) external view returns (address);
    function setOwner(address) external;
    function setFarmingAddress(address) external;
    function setDefaultCommunityFee(uint8) external;
    function setVaultAddress(address) external;
    function setBaseFeeConfiguration(uint16, uint16, uint32, uint32, uint16, uint16, uint32, uint16, uint16) external;
    function createPool(address tokenA, address tokenB) external returns (address pool);
}

interface IHypervisor is IERC20 {
    function deposit(uint256 deposit0, uint256 deposit1, address to, address from, uint256[4] memory inMin) external returns (uint256 shares);
    function withdraw(uint256 shares, address to, address from, uint256[4] memory minAmounts) external returns (uint256 amount0, uint256 amount1);
    function getTotalAmounts() external view returns (uint256 total0, uint256 total1);
    function getBasePosition() external view returns (uint128 liquidity, uint256 amount0, uint256 amount1);
    function getLimitPosition() external view returns (uint128 liquidity, uint256 amount0, uint256 amount1);
    function owner() external view returns (address);
    function whitelistedAddress() external view returns (address);
    function pool() external view returns (address);
    function token0() external view returns (address);
    function token1() external view returns (address);
    function baseLower() external view returns (int24);
    function baseUpper() external view returns (int24);
    function limitLower() external view returns (int24);
    function limitUpper() external view returns (int24);
    function directDeposit() external view returns (bool);
    function fee() external view returns (uint8);
    function feeRecipient() external view returns (address);
    function rebalance(int24, int24, int24, int24, address, uint256[4] memory, uint256[4] memory) external;
    function pullLiquidity(int24, int24, uint128, uint256[2] memory) external returns (uint256, uint256);
    function setWhitelist(address) external;
    function transferOwnership(address) external;
}

interface IUniProxy {
    function deposit(uint256 deposit0, uint256 deposit1, address to, address pos, uint256[4] memory minIn) external returns (uint256 shares);
    function clearance() external view returns (address);
    function owner() external view returns (address);
    function getDepositAmount(address pos, address token, uint256 _deposit) external view returns (uint256, uint256);
}

interface IClearing {
    function clearDeposit(uint256 deposit0, uint256 deposit1, address from, address to, address pos, uint256[4] memory minIn) external view returns (bool);
    function clearShares(address pos, uint256 shares) external view returns (bool);
    function checkPriceChange(address pos, uint32 twapInterval, uint256 priceThreshold) external view returns (uint256);
    function getDepositAmount(address pos, address token, uint256 _deposit) external view returns (uint256, uint256);
    function paused() external view returns (bool);
    function twapCheck() external view returns (bool);
    function owner() external view returns (address);
}

interface INFPM {
    struct CollectParams {
        uint256 tokenId;
        address recipient;
        uint128 amount0Max;
        uint128 amount1Max;
    }
    struct DecreaseLiquidityParams {
        uint256 tokenId;
        uint128 liquidity;
        uint256 amount0Min;
        uint256 amount1Min;
        uint256 deadline;
    }
    function positions(uint256 tokenId)
        external
        view
        returns (
            uint96 nonce,
            address operator,
            address token0,
            address token1,
            int24 tickLower,
            int24 tickUpper,
            uint128 liquidity,
            uint256 feeGrowthInside0LastX128,
            uint256 feeGrowthInside1LastX128,
            uint128 tokensOwed0,
            uint128 tokensOwed1
        );
    function ownerOf(uint256) external view returns (address);
    function collect(CollectParams calldata params) external payable returns (uint256 amount0, uint256 amount1);
    function decreaseLiquidity(DecreaseLiquidityParams calldata params) external payable returns (uint256 amount0, uint256 amount1);
    function burn(uint256 tokenId) external payable;
    function totalSupply() external view returns (uint256);
}

interface IFarmingCenter {
    function withdrawToken(uint256 tokenId, address to, bytes memory data) external;
    function totalSupply() external view returns (uint256);
    function ownerOf(uint256) external view returns (address);
}

interface IAlgebraEternalFarming {
    struct IncentiveKey {
        address rewardToken;
        address bonusRewardToken;
        address pool;
        uint256 startTime;
        uint256 endTime;
    }
    struct IncentiveParams {
        uint256 reward;
        uint256 bonusReward;
        uint128 rewardRate;
        uint128 bonusRewardRate;
        uint24 minimalPositionWidth;
        address multiplierToken;
    }
    struct Tiers {
        uint256 tokenAmountForTier1;
        uint256 tokenAmountForTier2;
        uint256 tokenAmountForTier3;
        uint32 tier1Multiplier;
        uint32 tier2Multiplier;
        uint32 tier3Multiplier;
    }
    function createEternalFarming(IncentiveKey memory key, IncentiveParams memory params, Tiers calldata tiers) external returns (address);
    function owner() external view returns (address);
    function incentiveMaker() external view returns (address);
    function isEmergencyWithdrawActivated() external view returns (bool);
}

interface IV3Fees {
    function collectFees() external;
    function tokens(uint256) external view returns (address);
    function owner() external view returns (address);
    function treasury() external view returns (address);
    function algebra() external view returns (address);
    function algebraCut() external view returns (uint256);
}

interface IDataStorageOperator {
    struct FeeConfiguration {
        uint16 alpha1;
        uint16 alpha2;
        uint32 beta1;
        uint32 beta2;
        uint16 gamma1;
        uint16 gamma2;
        uint32 volumeBeta;
        uint16 volumeGamma;
        uint16 baseFee;
    }
    function changeFeeConfiguration(FeeConfiguration calldata _feeConfig) external;
    function feeConfig() external view returns (FeeConfiguration memory);
}
