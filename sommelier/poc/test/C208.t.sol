// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {IUniswapV2Pair, IUniswapV2Router02, IERC20, ICellar} from "../src/Interfaces.sol";

/// @title C2-08 Sommelier governance-capture — EVM-side fork verification
/// @notice Read-only fork tests. No mainnet transactions are ever sent; these are view calls
///         and expected-revert probes against pinned fork state.
contract C208SommelierTest is Test {
    address constant SOMM = 0xa670d7237398238DE01267472C6f13e5B8010FD1; // ERC-20 SOMM (Ethereum)
    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant ROUTER = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D; // Uniswap V2
    address constant PAIR = 0x8Bbe2a88603e63bA5F2fAC8ee4F54171d9BfAA96;  // SOMM/WETH V2 pair
    address constant GRAVITY = 0x69592e6f9d21989a043646fE8225da2600e5A0f7; // Sommelier Gravity bridge (Ethereum)
    address constant AXELAR_PROXY = 0xEe75bA2C81C04DcA4b0ED6d1B7077c188FEde4d2; // cork executor proxy

    uint256 constant QUORUM_SOMM = 35_700_000e6; // half of bonded (naive "to-quorum" figure)
    uint256 constant SOLO_SOMM = 71_500_000e6;   // solo quorum incl. own bonded stake

    // ---------------------------------------------------------------- Ethereum

    function test_mainnet_pair_is_dead_buying_quorum_impossible() public {
        vm.createSelectFork(vm.envOr("FORK_RPC_URL", string("https://ethereum-rpc.publicnode.com")));

        (uint112 r0, uint112 r1, ) = IUniswapV2Pair(PAIR).getReserves();
        emit log_named_uint("pair reserve0 (SOMM, 6dp)", r0);
        emit log_named_uint("pair reserve1 (WETH wei)", r1);
        assertLt(uint256(r0), 4e6, "pair holds < 4 SOMM");
        assertLt(uint256(r1), 1e15, "pair holds < 0.001 WETH");

        // Buying the naive quorum amount out of the pair must revert (amountOut > reserveOut).
        address[] memory buyPath = new address[](2);
        buyPath[0] = SOMM;
        buyPath[1] = WETH;
        vm.expectRevert();
        IUniswapV2Router02(ROUTER).getAmountsIn(QUORUM_SOMM, buyPath);

        // The entire WETH reserve cannot buy more than the SOMM reserve (~3.49 SOMM).
        address[] memory sellPath = new address[](2);
        sellPath[0] = WETH;
        sellPath[1] = SOMM;
        uint256[] memory outs = IUniswapV2Router02(ROUTER).getAmountsOut(uint256(r1), sellPath);
        emit log_named_uint("SOMM obtainable with entire WETH reserve", outs[1]);
        assertLe(outs[1], uint256(r0), "cannot buy more SOMM than the reserve");
        assertLt(outs[1], 4e6, "entire pool < 4 SOMM");

        // Selling quorum-sized SOMM into the pair returns dust (< 0.000001 WETH).
        uint256[] memory sellOut = IUniswapV2Router02(ROUTER).getAmountsOut(QUORUM_SOMM, buyPath);
        emit log_named_uint("WETH out for 35.7M SOMM", sellOut[1]);
        assertLt(sellOut[1], 1e12, "35.7M SOMM sells for < 1e12 wei WETH");
    }

    function test_mainnet_somm_supply_and_gravity_holdings() public {
        vm.createSelectFork(vm.envOr("FORK_RPC_URL", string("https://ethereum-rpc.publicnode.com")));

        uint256 supply = IERC20(SOMM).totalSupply();
        emit log_named_uint("SOMM ERC-20 totalSupply (6dp)", supply);
        assertGt(supply, 36_000_000e6);
        assertLt(supply, 37_500_000e6);

        uint256 gweth = IERC20(WETH).balanceOf(GRAVITY);
        uint256 gusdc = IERC20(USDC).balanceOf(GRAVITY);
        emit log_named_uint("Gravity WETH", gweth);
        emit log_named_uint("Gravity USDC (6dp)", gusdc);
        assertGt(gweth, 22e18, "gravity holds >22 WETH");
        assertGt(gusdc, 1_500e6, "gravity holds >1500 USDC");
    }

    // ---------------------------------------------------------------- Arbitrum

    function test_arbitrum_cellars_owner_is_proxy_and_not_permissionless() public {
        vm.createSelectFork(vm.envOr("ARB_RPC_URL", string("https://arb1.arbitrum.io/rpc")));

        ICellar usdcCellar = ICellar(0x438087f7c226A89762a791F187d7c3D4a0e95ae6);
        ICellar usdcCellar2 = ICellar(0x392B1E6905bb8449d26af701Cdea6Ff47bF6e5A8);
        ICellar wethCellar = ICellar(0xC47bB288178Ea40bF520a91826a3DEE9e0DbFA4C);

        assertEq(usdcCellar.owner(), AXELAR_PROXY, "cellar owner is the axelar cork proxy");
        assertEq(usdcCellar2.owner(), AXELAR_PROXY, "cellar owner is the axelar cork proxy");
        assertEq(wethCellar.owner(), AXELAR_PROXY, "cellar owner is the axelar cork proxy");

        // A random caller cannot move cellar funds.
        vm.expectRevert();
        usdcCellar.callOnBehalfOf(address(0xdead), "", 0);

        uint256 ta = usdcCellar2.totalAssets();
        emit log_named_uint("arb USDC cellar totalAssets (6dp)", ta);
        assertGt(ta, 29_000e6, "cellar holds >$29k USDC");
        assertLt(ta, 30_000e6, "cellar holds <$30k USDC");
    }

    // ---------------------------------------------------------------- Optimism

    function test_optimism_cellar_owner_is_proxy() public {
        vm.createSelectFork(vm.envOr("OP_RPC_URL", string("https://mainnet.optimism.io")));

        ICellar wethCellar = ICellar(0xC47bB288178Ea40bF520a91826a3DEE9e0DbFA4C);
        assertEq(wethCellar.owner(), AXELAR_PROXY, "cellar owner is the axelar cork proxy");

        uint256 ta = wethCellar.totalAssets();
        emit log_named_uint("op WETH cellar totalAssets (wei)", ta);
        assertGt(ta, 12.8e18, "cellar holds >12.8 WETH");

        vm.expectRevert();
        wethCellar.callOnBehalfOf(address(0xdead), "", 0);
    }
}
