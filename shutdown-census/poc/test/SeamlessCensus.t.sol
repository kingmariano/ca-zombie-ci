// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
}

interface ILeverageManager {
    struct LeverageTokenState {
        uint256 collateralInDebtAsset;
        uint256 debt;
        uint256 equity;
        uint256 collateralRatio;
    }

    struct LeverageTokenConfig {
        address lendingAdapter;
        address rebalanceAdapter;
        uint256 mintTokenFee;
        uint256 redeemTokenFee;
    }

    function getLeverageTokenState(address token) external view returns (LeverageTokenState memory);
    function getLeverageTokenConfig(address token) external view returns (LeverageTokenConfig memory);
    function getLeverageTokenRebalanceAdapter(address token) external view returns (address);
    function getLeverageTokenDebtAsset(address token) external view returns (address);
    function getLeverageTokenCollateralAsset(address token) external view returns (address);
    function convertToAssets(address token, uint256 shares) external view returns (uint256);

    struct RebalanceAction {
        uint8 actionType; // 0=AddCollateral 1=RemoveCollateral 2=Borrow 3=Repay
        uint256 amount;
    }

    function rebalance(
        address leverageToken,
        RebalanceAction[] calldata actions,
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOut
    ) external;
}

interface IRebalanceAdapter {
    function isEligibleForRebalance(
        address token,
        ILeverageManager.LeverageTokenState memory state,
        address caller
    ) external view returns (bool);
}

interface IMorpho {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function market(bytes32 id) external view returns (uint128, uint128, uint128, uint128, uint128, uint128);

    function position(bytes32 id, address user) external view returns (uint256, uint128, uint128);

    function borrow(MarketParams memory marketParams, uint256 assets, uint256 shares, address onBehalf, address receiver)
        external;
}

/// @title H-5 Seamless V2 (Leverage Tokens) — live gates and extraction-bound proof
/// @notice Read-only fork tests. No mainnet transactions. All calls are static or expect-revert.
contract SeamlessCensus is Test {
    address constant LM = 0x5C37EB148D4a261ACD101e2B997A0F163Fb3E351;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant ATTACKER = 0x000000000000000000000000000000000000dEaD;

    // T3: RLP/USDC token and its lending adapter / Morpho market
    address constant T3 = 0x6426811fF283Fa7c78F0BC5D71858c2f79c0Fc3d;
    address constant T3_ADAPTER = 0xe33Eaf6EE64f4B9353ff2ce3748FA05EEb9bd809;
    bytes32 constant T3_MARKET_ID = 0xe1b65304edd8ceaea9b629df4c3c926a37d1216e27900505c04f14b2ed279f33;

    // T2: wstETH/WETH token (the only material holder equity)
    address constant T2 = 0x98c4E43e3Bde7B649E5aa2F88DE1658E8d3eD1bF;

    address[10] internal TOKENS = [
        0x10041DFFBE8fB54Ca4Dfa56F2286680EC98A37c3,
        0x98c4E43e3Bde7B649E5aa2F88DE1658E8d3eD1bF,
        0x6426811fF283Fa7c78F0BC5D71858c2f79c0Fc3d,
        0x0E5eB844bc0A29c9B949137bbb13327f86809779,
        0xE282a1A02A7b607d616B3311fE528d1Af4A31233,
        0x734a39FcA4562C5A2F6337555B34E4cA78678F6f,
        0xeE2aE3A033154dE692f1E14B4E8fBAD5Bce18E7a,
        0x604d37747f3382fA51519e7542d54F1e730B97A3,
        0xc73CE54dBC4A02D7110F69AdF123B3DbE5B3033f,
        0xCE937010b7E55dA282E6161f7Aa4744A0B732035
    ];

    function setUp() public {
        vm.createSelectFork(
            vm.envOr("FORK_RPC_URL", vm.envOr("RPC_URL", string("https://ethereum-rpc.publicnode.com")))
        );
    }

    /// @dev Only the insolvent RLP token is rebalance-eligible for an arbitrary caller; the
    ///      eight funded tokens are inside their collateral-ratio bands (no permissionless rebalance).
    function test_seamless_rebalance_eligibility_live() public {
        ILeverageManager lm = ILeverageManager(LM);
        uint256 eligible;
        for (uint256 i = 0; i < TOKENS.length; i++) {
            ILeverageManager.LeverageTokenState memory st = lm.getLeverageTokenState(TOKENS[i]);
            IRebalanceAdapter ra = IRebalanceAdapter(lm.getLeverageTokenRebalanceAdapter(TOKENS[i]));
            bool ok = ra.isEligibleForRebalance(TOKENS[i], st, ATTACKER);
            emit log_named_address("token", TOKENS[i]);
            emit log_named_uint("collateralInDebtAsset", st.collateralInDebtAsset);
            emit log_named_uint("debt", st.debt);
            emit log_named_uint("equity", st.equity);
            emit log_named_uint("collateralRatio", st.collateralRatio);
            emit log_named_string("eligible", ok ? "yes" : "no");
            if (ok) eligible++;
        }
        assertEq(eligible, 1, "expected exactly one eligible token (RLP/T3)");
    }

    /// @dev The extraction path on the eligible token must borrow from Morpho; Morpho rejects it
    ///      ("insufficient collateral") because the position is far below LLTV. Proved end-to-end
    ///      through LeverageManager.rebalance (caller = unprivileged attacker).
    function test_T3_rebalance_borrow_path_reverts() public {
        // action list: single Borrow(1 USDC)
        ILeverageManager.RebalanceAction[] memory actions = new ILeverageManager.RebalanceAction[](1);
        actions[0] = ILeverageManager.RebalanceAction({actionType: 2, amount: 1e6});
        vm.prank(ATTACKER);
        vm.expectRevert(bytes("insufficient collateral"));
        ILeverageManager(LM).rebalance(T3, actions, address(0), address(0), 0, 0);
    }

    /// @dev Morpho market for T3 is 100% utilized: zero available liquidity, so even a healthy
    ///      borrower could not extract USDC from it.
    function test_T3_morpho_market_fully_utilized() public view {
        (uint128 totalSupplyAssets, , uint128 totalBorrowAssets, , , ) = IMorpho(MORPHO).market(T3_MARKET_ID);
        assertEq(uint256(totalSupplyAssets), uint256(totalBorrowAssets), "market not fully utilized");
    }

    /// @dev T2 (wstETH/WETH) holds the only material holder equity (~106 ETH); positive and
    ///      redeemable by share holders (H-O), not by third parties.
    function test_T2_holder_equity_positive() public {
        ILeverageManager.LeverageTokenState memory st = ILeverageManager(LM).getLeverageTokenState(T2);
        assertGt(st.equity, 100e18, "T2 equity unexpectedly small");
        uint256 perShare = ILeverageManager(LM).convertToAssets(T2, 1e18);
        assertGt(perShare, 0, "T2 shares not convertible");
        emit log_named_uint("T2 equity (WETH wei)", st.equity);
        emit log_named_uint("T2 convertToAssets(1e18 shares)", perShare);
    }
}
