// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

// Minimal interfaces for the deployed Hyphen (Biconomy) contracts.
// Addresses are public mainnet deployments (see README).

interface IPool {
    function owner() external view returns (address);
    function paused() external view returns (bool);
    function baseGas() external view returns (uint256);
    function getExecutorManager() external view returns (address);
    function tokenManager() external view returns (address);
    function liquidityProviders() external view returns (address);
    function initialize(address, address, address, address, address) external;
    function sendFundsToUser(address, uint256, address payable, bytes calldata, uint256, uint256) external;
    function sendFundsToUserV2(address, uint256, address payable, bytes calldata, uint256, uint256, uint256) external;
    function withdrawErc20GasFee(address) external;
    function withdrawNativeGasFee() external;
    function transfer(address, address, uint256) external;
    function setLiquidityProviders(address) external;
    function setExecutorManager(address) external;
    function setTokenManager(address) external;
    function setCurrentLiquidity(address) external;
    function setBaseGas(uint128) external;
    function setSwapAdaptor(string calldata, address) external;
    function getCurrentLiquidity(address) external view returns (uint256);
    function getRewardAmount(uint256, address) external view returns (uint256);
    function gasFeeAccumulated(address, address) external view returns (uint256);
    function incentivePool(address) external view returns (uint256);
    function processedHash(bytes32) external view returns (bool);
    function isTrustedForwarder(address) external view returns (bool);
    function isPauser(address) external view returns (bool);
    function pause() external;
}

interface IProviders {
    function owner() external view returns (address);
    function paused() external view returns (bool);
    function initialize(address, address, address, address) external;
    function addTokenLiquidity(address, uint256) external;
    function addNativeLiquidity() external payable;
    function increaseTokenLiquidity(uint256, uint256) external;
    function increaseNativeLiquidity(uint256) external payable;
    function removeLiquidity(uint256, uint256) external;
    function claimFee(uint256) external;
    function addLPFee(address, uint256) external;
    function increaseCurrentLiquidity(address, uint256) external;
    function decreaseCurrentLiquidity(address, uint256) external;
    function setCurrentLiquidity(address, uint256) external;
    function setLiquidityPool(address) external;
    function setLpToken(address) external;
    function totalReserve(address) external view returns (uint256);
    function totalLiquidity(address) external view returns (uint256);
    function currentLiquidity(address) external view returns (uint256);
    function totalLPFees(address) external view returns (uint256);
    function totalSharesMinted(address) external view returns (uint256);
    function getSuppliedLiquidity(uint256) external view returns (uint256);
    function getTokenPriceInLPShares(address) external view returns (uint256);
    function sharesToTokenAmount(uint256, address) external view returns (uint256);
    function getFeeAccumulatedOnNft(uint256) external view returns (uint256);
}

interface ILPToken {
    function ownerOf(uint256) external view returns (address);
    function tokenMetadata(uint256) external view returns (address, uint256, uint256);
    function mint(address) external returns (uint256);
    function updateTokenMetadata(uint256, LpTokenMetadata calldata) external;
    function totalSupply() external view returns (uint256);
    function exists(uint256) external view returns (bool);
    function liquidityProvidersAddress() external view returns (address);
    function owner() external view returns (address);
    function paused() external view returns (bool);
    function isTrustedForwarder(address) external view returns (bool);
}

struct LpTokenMetadata {
    address token;
    uint256 suppliedLiquidity;
    uint256 shares;
}

interface IExecutorManager {
    function getExecutorStatus(address) external view returns (bool);
    function getAllExecutors() external view returns (address[] memory);
}

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
    function transfer(address, uint256) external returns (bool);
    function allowance(address, address) external view returns (uint256);
    function decimals() external view returns (uint8);
}

interface IBiconomyForwarder {
    struct ERC20ForwardRequest {
        address from;
        address to;
        address token;
        uint256 txGas;
        uint256 tokenGasPrice;
        uint256 batchId;
        uint256 batchNonce;
        uint256 deadline;
        bytes data;
    }
    function executePersonalSign(ERC20ForwardRequest calldata, bytes calldata) external returns (bool, bytes memory);
    function executeEIP712(ERC20ForwardRequest calldata, bytes32, bytes calldata) external returns (bool, bytes memory);
    function getNonce(address, uint256) external view returns (uint256);
}

library Hyphen {
    address constant NATIVE = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    // Ethereum mainnet deployments (identical addresses on Polygon/Avalanche for
    // the pool+providers pair; BSC and OP/ARB differ - see README).
    address constant ETH_POOL = 0x2A5c2568b10A0E826BfA892Cf21BA7218310180b;
    address constant ETH_PROVIDERS = 0xebaB24F13de55789eC1F3fFe99A285754e15F7b9;
    address constant ETH_LPTOKEN = 0xc49B65e5a350292Afda1f239eBefE562668717c2;
    address constant ETH_EXEC_MGR = 0xbd761D917fB77381B4398Bda89C7F0d9A2BD1399;
    address constant ETH_FORWARDER = 0x84a0856b038eaAd1cC7E297cF34A7e72685A8693;

    address constant ETH_USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant ETH_USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address constant ETH_BICO = 0xF17e65822b568B3903685a7c9F496CF7656Cc6C2;
    address constant ETH_MATIC = 0x7D1AfA7B718fb893dB30A3aBc0Cfc608AaCfeBB0;

    // POL/OP/ARB/BSC pool+providers pairs
    address constant POL_POOL = 0x2A5c2568b10A0E826BfA892Cf21BA7218310180b;
    address constant POL_PROVIDERS = 0xebaB24F13de55789eC1F3fFe99A285754e15F7b9;
    address constant BSC_POOL = 0x94D3E62151B12A12A4976F60EdC18459538FaF08;
    address constant BSC_PROVIDERS = 0x279ac60785A2FCb85550EB243B9A42A543171Cc7;
    address constant OP_POOL = 0x856cb5c3cBBe9e2E21293A644aA1f9363CEE11E8;
    address constant OP_PROVIDERS = 0xb4778f5aeFEb4605Ed96E893417271d4A55E32eE;
    address constant ARB_POOL = 0x856cb5c3cBBe9e2E21293A644aA1f9363CEE11E8;
    address constant ARB_PROVIDERS = 0xb4778f5aeFEb4605Ed96E893417271d4A55E32eE;
    address constant AVAX_POOL = 0x2A5c2568b10A0E826BfA892Cf21BA7218310180b;
    address constant AVAX_PROVIDERS = 0xebaB24F13de55789eC1F3fFe99A285754e15F7b9;
}
