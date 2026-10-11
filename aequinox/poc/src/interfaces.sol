// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
    function transfer(address, uint256) external returns (bool);
    function transferFrom(address, address, uint256) external returns (bool);
    function allowance(address, address) external view returns (uint256);
    function decimals() external view returns (uint8);
    function totalSupply() external view returns (uint256);
    function symbol() external view returns (string memory);
}

interface IVault {
    enum SwapKind { GIVEN_IN, GIVEN_OUT }

    struct SingleSwap {
        bytes32 poolId;
        SwapKind kind;
        address assetIn;
        address assetOut;
        uint256 amount;
        bytes userData;
    }

    struct FundManagement {
        address sender;
        bool fromInternalBalance;
        address payable recipient;
        bool toInternalBalance;
    }

    struct BatchSwapStep {
        bytes32 poolId;
        uint256 assetInIndex;
        uint256 assetOutIndex;
        uint256 amount;
        bytes userData;
    }

    struct JoinPoolRequest {
        address[] assets;
        uint256[] maxAmountsIn;
        bytes userData;
        bool fromInternalBalance;
    }

    struct ExitPoolRequest {
        address[] assets;
        uint256[] minAmountsOut;
        bytes userData;
        bool toInternalBalance;
    }

    struct PoolBalanceOp {
        uint8 kind; // 0=WITHDRAW 1=DEPOSIT 2=UPDATE
        bytes32 poolId;
        address token;
        uint256 amount;
    }

    function getPoolTokens(bytes32 poolId)
        external
        view
        returns (address[] memory tokens, uint256[] memory balances, uint256 lastChangeBlock);

    function getPoolTokenInfo(bytes32 poolId, address token)
        external
        view
        returns (uint256 cash, uint256 managed, uint256 lastChangeBlock, address assetManager);

    function getPausedState() external view returns (bool paused, uint256 pauseWindowEndTime, uint256 bufferPeriodEndTime);
    function getAuthorizer() external view returns (address);
    function getProtocolFeesCollector() external view returns (address);

    function swap(SingleSwap memory singleSwap, FundManagement memory funds, uint256 limit, uint256 deadline)
        external
        payable
        returns (uint256);

    function batchSwap(
        uint8 kind,
        BatchSwapStep[] memory swaps,
        address[] memory assets,
        FundManagement memory funds,
        int256[] memory limits,
        uint256 deadline
    ) external payable returns (int256[] memory);

    function joinPool(bytes32 poolId, address sender, address recipient, JoinPoolRequest memory request)
        external
        payable;

    function exitPool(bytes32 poolId, address sender, address payable recipient, ExitPoolRequest memory request)
        external;

    function registerPool(uint8 specialization) external returns (bytes32);
    function registerTokens(bytes32 poolId, address[] memory tokens, address[] memory assetManagers) external;
    function deregisterTokens(bytes32 poolId, address[] memory tokens) external;
    function managePoolBalance(PoolBalanceOp[] memory ops) external;
    function setPaused(bool paused) external;
    function setAuthorizer(address newAuthorizer) external;
    function flashLoan(address recipient, address[] memory tokens, uint256[] memory amounts, bytes memory userData)
        external;
}

interface IFlashLoanRecipient {
    function receiveFlashLoan(
        address[] memory tokens,
        uint256[] memory amounts,
        uint256[] memory feeAmounts,
        bytes memory userData
    ) external;
}

interface IProtocolFeesCollector {
    function getFlashLoanFeePercentage() external view returns (uint256);
    function getSwapFeePercentage() external view returns (uint256);
}

interface IGauge {
    function lp_token() external view returns (address);
    function admin() external view returns (address);
    function is_killed() external view returns (bool);
    function totalSupply() external view returns (uint256);
    function balanceOf(address) external view returns (uint256);
    function deposit(uint256 value) external;
    function deposit(uint256 value, address addr) external;
    function withdraw(uint256 value) external;
    function withdraw(uint256 value, bool claimRewards) external;
    function claim_rewards() external;
    function initialize(address lpToken) external;
    function transfer(address, uint256) external returns (bool);
    function transferFrom(address, address, uint256) external returns (bool);
}

interface IStablePool {
    function getRate() external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function balanceOf(address) external view returns (uint256);
    function getPoolId() external view returns (bytes32);
    function getSwapFeePercentage() external view returns (uint256);
    function getPausedState() external view returns (bool, uint256, uint256);
    function inRecoveryMode() external view returns (bool);
    function getOwner() external view returns (address);
    function getAuthorizer() external view returns (address);
    function enableRecoveryMode() external;
    function disableRecoveryMode() external;
    function setSwapFeePercentage(uint256) external;
    function pause() external;
    function unpause() external;
}
