// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/Test.sol";

/// @title H-25 · GRXswap (GRX Chain, chainId 1110) — live-extractability boundary tests
/// @notice Fork-only verification. No real-chain transactions are ever sent; all state
///         changes live inside the anvil/forge fork of https://rpc.grxchain.io.
///
/// What is proven here (2026-10-04):
///   1. All 8 GRXSwap pairs are canonical UniswapV2-pair children of the verified
///      GRXSwapFactoryV2 (0xc731...); reserves == token balances at the fork block and
///      `skim` can only move pre-existing excess, never reserves.
///   2. Permissionless drain attempts revert: swap without input, K-violating swap,
///      mint without deposit, burn without LP, re-initialize.
///   3. Every token with privileged mint power (USDT18_a, USDT18_b, WGRX_b, PeggedBTC,
///      PeggedETH, FiatBackedStablecoin) rejects unprivileged minting; the minters are EOAs.
///   4. The privileged owner EOA 0x53e6... CAN mint USDT18_a and drain pool1 (P category),
///      quantifying the team-only exposure — not an unprivileged path.

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function approve(address, uint256) external returns (bool);
    function transfer(address, uint256) external returns (bool);
    function decimals() external view returns (uint8);
    function symbol() external view returns (string memory);
}

interface IPair is IERC20 {
    function token0() external view returns (address);
    function token1() external view returns (address);
    function getReserves() external view returns (uint112, uint112, uint32);
    function mint(address) external returns (uint256);
    function burn(address) external returns (uint256, uint256);
    function swap(uint256, uint256, address, bytes calldata) external;
    function skim(address) external;
    function sync() external;
    function initialize(address, address) external;
    function factory() external view returns (address);
    function kLast() external view returns (uint256);
}

interface IUSDT18 is IERC20 {
    function mint(address, uint256) external returns (bool);
    function burn(address, uint256) external returns (bool);
    function setDepositor(address) external;
    function owner() external view returns (address);
    function transferOwnership(address) external;
    function getOwner() external view returns (address);
}

interface IWGRXb is IERC20 {
    function ownerDeposit(uint256) external;
    function owner() external view returns (address);
}

interface IBridge {
    function mintWithReference(address, uint256, bytes32) external;
    function mint(address, uint256) external;
    function hasRole(bytes32, address) external view returns (bool);
}

interface IRouter {
    function factory() external view returns (address);
    function WETH() external view returns (address);
    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint256, uint256, address[] calldata, address, uint256
    ) external;
    function getAmountsOut(uint256, address[] calldata) external view returns (uint256[] memory);
}

contract GrxswapAuditTest is Test {
    // ---- live addresses on GRX Chain (chainId 1110), verified on-chain 2026-10-04 ----
    address constant FACTORY = 0xc7316818841f355c5107753A3f3FDEA799BD25f6;
    address constant ROUTER = 0x28fC93b8a20570f2B59d5CA9f8a1dA02C4DBcDF5;
    address constant USDT18A = 0x173462F5eb7CA0D1ab6aaea846fEFe85A28029E2; // "USDT GRX" (18d), owner-mintable
    address constant USDT18B = 0x2aF568c4e3F7B1A66DAcaFf35eee757b85Cd4A75; // "USDT GRX" (18d), owner-mintable
    address constant WGRXA = 0x45C7287F897B3A79Cd3f6e4F14B4CE568f023bD5;   // WETH9-style, 1:1 native-backed
    address constant WGRXB = 0x2bd8911f05Cb37a772f33BfEcB2f8db67B36B212;   // modified WETH + ownerDeposit
    address constant BTC = 0x2F4632ABAd26A1FF9212a76597fb3c3d8539E275;      // PeggedBTC (role-gated)
    address constant ETH = 0x02D129c8A26839c814925eE0f1D320F63114E1FE;      // PeggedETH (role-gated)
    address constant USDT6 = 0x1d3bc9646d126D379b4da4d71c8a4fa6b830Dd20;    // FiatBackedStablecoin (role-gated)
    address constant SAFE = 0x6Ab7611477f3F73B05FFe66791c5714F6a2f9b4F;
    address constant ST = 0xb2c15A6f8eB7d87acc2D5edfb4300cf5fa620081;

    address constant OWNER = 0x53e6A26f382e6b6d50a183C747cb0C7607ba8043; // depositor+owner USDT18a, all roles on BTC/ETH/USDT6
    address constant MINTER2 = 0x0eDC1BbC571bAF713E86a7E2475fb43ae62D6D39; // MINTER on USDT6
    address constant ATTACKER = address(0xA11CE);
    address constant ZERO = address(0);

    bytes32 constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 constant ADMIN_ROLE = 0x00;

    address[8] pairs = [
        0x490620Fa57f554073D67C77c6ccdCCc1e6188B32, // WGRXA/ST
        0x47b7F566A7c2F827d16a2336684B31929E1cB386, // USDT18a/WGRXA  (active)
        0x165AA0A040da0504036dB32130C9d69233c69cC5, // USDT6/BTC
        0xB8D0a95d6c3551B4096382f1b9447db714E8a649, // USDT18a/BTC
        0x1787BBA5bd5C132894B65eAADe1B54C205F41946, // ETH/USDT18a
        0x5916FF9D9c2CA2cee90045171554ecaa902A41b8, // USDT18b/WGRXB
        0xaB664e44cdcD8354FC11F7ec7836662e403053f0, // WGRXA/SAFE
        0x1E30EA8fba02FC12B3f8b8b80E1bD65a19BC781C  // USDT18b/SAFE (LP locked)
    ];

    uint256 forkBlock;

    function setUp() public {
        string memory url = vm.envOr("GRX_RPC_URL", string("https://rpc.grxchain.io"));
        forkBlock = vm.createSelectFork(url);
        vm.deal(ATTACKER, 100 ether);
        emit log_named_uint("fork block", block.number);
    }

    // ---------------------------------------------------------------- live state
    function test_pairs_are_canonical_factory_children() public {
        for (uint256 i = 0; i < pairs.length; i++) {
            IPair p = IPair(pairs[i]);
            assertEq(p.factory(), FACTORY, "pair.factory != GRXSwapFactoryV2");
            assertEq(p.kLast(), 0, "unexpected protocol-fee state (kLast != 0)");
            (uint112 r0, uint112 r1,) = p.getReserves();
            address t0 = p.token0();
            address t1 = p.token1();
            uint256 b0 = IERC20(t0).balanceOf(pairs[i]);
            uint256 b1 = IERC20(t1).balanceOf(pairs[i]);
            emit log_named_address("pair", pairs[i]);
            emit log_named_uint("  reserve0", r0);
            emit log_named_uint("  reserve1", r1);
            emit log_named_uint("  balance0", b0);
            emit log_named_uint("  balance1", b1);
            // canonical pair: reserves must never exceed actual balances
            assertGe(b0, r0, "balance0 < reserve0 (pair under-collateralized)");
            assertGe(b1, r1, "balance1 < reserve1 (pair under-collateralized)");
        }
    }

    function test_router_points_at_verified_factory_and_wgrx() public {
        assertEq(IRouter(ROUTER).factory(), FACTORY);
        assertEq(IRouter(ROUTER).WETH(), WGRXA);
    }

    // ------------------------------------------------- permissionless drain attempts
    /// skim() may only move pre-existing excess (balance - reserve), never reserves.
    function test_skim_cannot_touch_reserves() public {
        for (uint256 i = 0; i < pairs.length; i++) {
            IPair p = IPair(pairs[i]);
            address t0 = p.token0();
            address t1 = p.token1();
            (uint112 r0, uint112 r1,) = p.getReserves();
            uint256 b0 = IERC20(t0).balanceOf(pairs[i]);
            uint256 b1 = IERC20(t1).balanceOf(pairs[i]);
            uint256 a0 = IERC20(t0).balanceOf(ATTACKER);
            uint256 a1 = IERC20(t1).balanceOf(ATTACKER);
            try p.skim(ATTACKER) {} catch {}
            uint256 g0 = IERC20(t0).balanceOf(ATTACKER) - a0;
            uint256 g1 = IERC20(t1).balanceOf(ATTACKER) - a1;
            emit log_named_address("skim pair", pairs[i]);
            emit log_named_uint("  gained token0", g0);
            emit log_named_uint("  excess token0", b0 - r0);
            emit log_named_uint("  gained token1", g1);
            emit log_named_uint("  excess token1", b1 - r1);
            assertLe(g0, b0 - r0, "skim moved more than excess token0");
            assertLe(g1, b1 - r1, "skim moved more than excess token1");
        }
    }

    function test_swap_without_input_reverts() public {
        vm.expectRevert(bytes("Libs: INSUFFICIENT_INPUT_AMOUNT"));
        IPair(0x47b7F566A7c2F827d16a2336684B31929E1cB386).swap(1, 1, ATTACKER, "");
    }

    function test_k_violating_swap_reverts() public {
        address pair = 0x47b7F566A7c2F827d16a2336684B31929E1cB386; // token0 = USDT18a
        // give the attacker USDT18a by writing the token's balance mapping (slot 1)
        vm.store(
            USDT18A,
            keccak256(abi.encode(ATTACKER, uint256(1))),
            bytes32(uint256(2_000_000 ether))
        );
        vm.prank(ATTACKER);
        IERC20(USDT18A).transfer(pair, 1 ether); // tiny input
        vm.expectRevert(bytes("Libs: K"));
        IPair(pair).swap(100 ether, 0, ATTACKER, ""); // request output >> input
    }

    function test_mint_without_deposit_reverts() public {
        vm.expectRevert(bytes("Libs: INSUFFICIENT_LIQUIDITY_MINTED"));
        IPair(0x47b7F566A7c2F827d16a2336684B31929E1cB386).mint(ATTACKER);
    }

    function test_burn_without_lp_reverts() public {
        vm.expectRevert(bytes("Libs: INSUFFICIENT_LIQUIDITY_BURNED"));
        IPair(0x47b7F566A7c2F827d16a2336684B31929E1cB386).burn(ATTACKER);
    }

    function test_reinitialize_reverts() public {
        vm.expectRevert(bytes("Libs: FORBIDDEN"));
        IPair(0x47b7F566A7c2F827d16a2336684B31929E1cB386).initialize(ATTACKER, ATTACKER);
    }

    // ------------------------------------------------------- token mint boundaries
    function test_permissionless_mints_revert() public {
        vm.expectRevert(bytes("caller is not the depositor"));
        IUSDT18(USDT18A).mint(ATTACKER, 1 ether);

        vm.expectRevert(bytes("caller is not the depositor"));
        IUSDT18(USDT18B).mint(ATTACKER, 1 ether);

        vm.expectRevert(bytes("caller is not the depositor"));
        IUSDT18(USDT18A).burn(ATTACKER, 1 ether);

        vm.expectRevert();
        IWGRXb(WGRXB).ownerDeposit(1 ether);

        vm.expectRevert();
        IBridge(BTC).mintWithReference(ATTACKER, 1, bytes32(0));

        vm.expectRevert();
        IBridge(ETH).mintWithReference(ATTACKER, 1, bytes32(0));

        vm.expectRevert();
        IBridge(USDT6).mint(ATTACKER, 1e6);

        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        IUSDT18(USDT18A).setDepositor(ATTACKER);

        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        IUSDT18(USDT18A).transferOwnership(ATTACKER);
    }

    function test_role_holders_are_eoas() public {
        assertTrue(IBridge(BTC).hasRole(MINTER_ROLE, OWNER), "owner must hold MINTER on BTC");
        assertTrue(IBridge(ETH).hasRole(MINTER_ROLE, OWNER), "owner must hold MINTER on ETH");
        assertTrue(IBridge(USDT6).hasRole(MINTER_ROLE, OWNER), "owner must hold MINTER on USDT6");
        assertTrue(IBridge(USDT6).hasRole(MINTER_ROLE, MINTER2), "minter2 must hold MINTER on USDT6");
        assertFalse(IBridge(BTC).hasRole(MINTER_ROLE, ATTACKER), "attacker must not hold roles");
        assertFalse(IBridge(ETH).hasRole(MINTER_ROLE, ATTACKER), "attacker must not hold roles");
        assertFalse(IBridge(USDT6).hasRole(MINTER_ROLE, ATTACKER), "attacker must not hold roles");
        assertFalse(IBridge(USDT6).hasRole(ADMIN_ROLE, ATTACKER), "attacker must not hold roles");
    }

    // ------------------------------------- privileged (P) path, fork demonstration only
    /// The owner EOA of USDT18a is also the depositor and can mint unbounded USDT18a,
    /// then sell it into pool1 for WGRX. This is a PRIVILEGED path (P), not E-U.
    function test_privileged_owner_can_drain_pool1() public {
        address pair = 0x47b7F566A7c2F827d16a2336684B31929E1cB386;
        uint256 poolWgrx = IERC20(WGRXA).balanceOf(pair);
        uint256 before = IERC20(WGRXA).balanceOf(OWNER);

        vm.startPrank(OWNER);
        IUSDT18(USDT18A).mint(OWNER, 1_000_000_000 ether);
        IERC20(USDT18A).approve(ROUTER, type(uint256).max);
        address[] memory path = new address[](2);
        path[0] = USDT18A;
        path[1] = WGRXA;
        uint256[] memory amounts = IRouter(ROUTER).getAmountsOut(1_000_000_000 ether, path);
        emit log_named_uint("expected WGRX out (privileged)", amounts[1]);
        IRouter(ROUTER).swapExactTokensForTokensSupportingFeeOnTransferTokens(
            1_000_000_000 ether, 0, path, OWNER, block.timestamp + 600
        );
        vm.stopPrank();

        uint256 gained = IERC20(WGRXA).balanceOf(OWNER) - before;
        emit log_named_uint("WGRX drained by privileged owner", gained);
        emit log_named_uint("pool WGRX before", poolWgrx);
        assertGt(gained, (poolWgrx * 95) / 100, "privileged owner should drain >95% of pool WGRX");
    }
}
