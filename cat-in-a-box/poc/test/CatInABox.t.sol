// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test, console2} from "forge-std/Test.sol";

/* ------------------------------------------------------------------------------------
   Cat in a Box (Ethereum) — live extraction analysis, read-only fork tests.
   All state is read at the latest fork block. No mainnet transactions are sent.
   ------------------------------------------------------------------------------------ */

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
    function transfer(address, uint256) external returns (bool);
    function allowance(address, address) external view returns (uint256);
    function totalSupply() external view returns (uint256);
}

interface IUniswapV3Pool {
    function token0() external view returns (address);
    function token1() external view returns (address);
    function fee() external view returns (uint24);
    function liquidity() external view returns (uint128);
    function slot0() external view returns (uint160 sqrtPriceX96, int24 tick, uint16 a, uint16 b, uint16 c, uint8 d, bool unlocked);
    function swap(address recipient, bool zeroForOne, int256 amountSpecified, uint160 sqrtPriceLimitX96, bytes calldata data)
        external returns (int256 amount0, int256 amount1);
}

interface ICDP {
    function deposited(address) external view returns (uint256);
    function debt(address) external view returns (uint256);
    function totaldeposits() external view returns (uint256);
    function totalDebt() external view returns (uint256);
    function unclaimed() external view returns (uint256);
    function totalPoints() external view returns (uint256);
    function pointMultiplier() external view returns (uint256);
    function lastPoints(address) external view returns (uint256);
    function ltv() external view returns (uint256);
    function mintingFee() external view returns (uint256);
    function enableRepaying(address) external view returns (bool);
    function stabilisePeg(uint256 amount, address depositor) external;
    function deposit(uint256 amount) external;
    function mint(uint256 amount) external;
    function repay(uint256 amount) external;
    function withdraw(uint256 amount) external;
    function poke(address depositor) external;
    function hasRole(bytes32 role, address account) external view returns (bool);
}

interface IWstETH {
    function wrap(uint256 stETHAmount) external returns (uint256);
    function unwrap(uint256 wstETHAmount) external returns (uint256);
}

interface IERC4626 {
    function deposit(uint256 assets, address receiver) external returns (uint256 shares);
    function redeem(uint256 shares, address receiver, address owner) external returns (uint256 assets);
    function previewRedeem(uint256 shares) external view returns (uint256);
    function convertToAssets(uint256 shares) external view returns (uint256);
    function totalAssets() external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function balanceOf(address) external view returns (uint256);
}

contract CatInABoxTest is Test {
    // --- mainnet addresses (verified on-chain at latest block) ---
    address constant STETH   = 0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84;
    address constant WSTETH  = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;
    address constant WETH    = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant BOXETH  = 0x7690202e2C2297bcD03664e31116d1dFfE7e3B73; // Cat-in-a-Box Ether
    address constant BOXFEE  = 0xE4B91fAf8810F8895772E7cA065D4CB889120f94; // Cat-in-a-Box Fee Token (ERC4626 over boxETH)

    address constant CDP1    = 0x7f0A0C7149a46Bf943cCd412da687144b49C6014; // catinaboxcdp
    address constant CDP11   = 0x6ffD098E92B606b2947b89A08911C00ca06890FA; // catinaboxcdp1point1
    address constant PSM     = 0x24146D1B3339Cf76b455dC42e71Ea5Cdff4aE0d7; // psmstart
    address constant FEESPLIT= 0x320c871b6f7721083604FfdD8070E64c1d3c5d7C; // feeSplitStaking
    address constant SAFE    = 0x98e6475C01D018Ae78c02ef48738f687538226Af; // Gnosis Safe 3/5 (treasury / role holder)

    // boxETH markets
    address constant POOL_BOX_WETH_005 = 0x287139599f1B5849f12Cf18244A74F595da9936D; // boxETH/WETH 0.05%
    address constant POOL_BOX_WST_1PCT = 0x703a177fCB4DeF281D180D3619A5EDbaE67ec7b5; // boxETH/wstETH 1%
    // deep wstETH/WETH pool used only to source wstETH/stETH in the tests
    address constant POOL_WST_WETH_001 = 0x109830a1AAaD605BbF02a9dFA7B0B92EC2FB7dAa; // wstETH/WETH 0.01%

    // top v1.1 borrowers (highest debt/deposited ratio => lowest redemption friction fee)
    address constant V11_HI_RATIO   = 0xB1da4206165EFb834aBBA56704d577D384917f36; // debt ~77.8, fee ~0.97%
    address constant V11_HI_RATIO2  = 0xCdD7E78bB4DC4F144c71D1aE700B284aC362f5EE; // debt ~65.4, fee ~1.10%
    address constant V11_BIG        = 0x83C874dbc7708B4E457b5587BB67f73FFdE59525; // debt ~106.5, fee ~4.4%
    address constant V11_LOW_FEE    = 0x5Ac09356EEBffa7bf20d55f1196F3E68b554FcAe; // debt ~6.1,  fee ~0.47%
    address constant V11_TINY_LOW   = 0xaD464ebA8cb053FDe4f2e60E89F0FeDADbc50615; // debt ~0.168, fee ~0.19%
    address constant V1_BIG         = 0x3E7929ac8E700f04bf0e2aeD1C5A19fA3EF2017F; // debt ~2.45, fee ~9.6%
    address constant V1_MID         = 0xeA2E8c2eD335fa094b5c87977f52C97C1E340C4F; // debt ~3.0,  fee ~5.0%

    uint256 constant MAX_SQRT_RATIO = 1461446703485210103287273052203988822378723970342;
    uint256 constant MIN_SQRT_RATIO = 4295128739;

    uint256 forkBlock;

    function setUp() public {
        string memory rpc = vm.envOr("FORK_RPC_URL", vm.envOr("RPC_URL", string("https://ethereum-rpc.publicnode.com")));
        forkBlock = vm.createSelectFork(rpc);
        console2.log("fork block:", forkBlock);
    }

    /* ------------------------------------------------------------------ helpers */

    function uniswapV3SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata) external {
        // pay what we owe on the pool that called us
        address t0 = IUniswapV3Pool(msg.sender).token0();
        address t1 = IUniswapV3Pool(msg.sender).token1();
        if (amount0Delta > 0) require(IERC20(t0).transfer(msg.sender, uint256(amount0Delta)));
        if (amount1Delta > 0) require(IERC20(t1).transfer(msg.sender, uint256(amount1Delta)));
    }

    /// @notice buy `amountIn` of token1 (WETH/wstETH) worth of boxETH (token0) on a boxETH pool
    function buyBoxETH(address pool, uint256 amountIn) internal returns (uint256 boxOut) {
        IUniswapV3Pool p = IUniswapV3Pool(pool);
        require(p.token0() == BOXETH, "token0 must be boxETH");
        uint256 before = IERC20(BOXETH).balanceOf(address(this));
        // zeroForOne=false: give token1, receive token0
        p.swap(address(this), false, int256(amountIn), uint160(MAX_SQRT_RATIO - 1), "");
        boxOut = IERC20(BOXETH).balanceOf(address(this)) - before;
    }

    /// @notice source stETH from the market: WETH -> wstETH (deep pool) -> unwrap
    function sourceStETH(uint256 wethIn) internal returns (uint256 stOut) {
        deal(WETH, address(this), wethIn);
        IERC20(WETH).approve(POOL_WST_WETH_001, wethIn);
        uint256 before = IERC20(WSTETH).balanceOf(address(this));
        // wstETH/WETH pool: token0 = wstETH, token1 = WETH -> zeroForOne=false gives token0
        IUniswapV3Pool(POOL_WST_WETH_001).swap(address(this), false, int256(wethIn), uint160(MAX_SQRT_RATIO - 1), "");
        uint256 wst = IERC20(WSTETH).balanceOf(address(this)) - before;
        stOut = IWstETH(WSTETH).unwrap(wst);
    }

    /// @notice redeem `amount` of boxETH against `victim` on `cdp` (capped to debt/4 per call)
    function redeemViaStabilisePeg(address cdp, address victim, uint256 amount) internal returns (uint256 stethOut) {
        uint256 before = IERC20(STETH).balanceOf(address(this));
        ICDP(cdp).stabilisePeg(amount, victim);
        stethOut = IERC20(STETH).balanceOf(address(this)) - before;
    }

    /// @notice redeem all available boxETH balance against one victim, looping the debt/4 cap
    function drainVictim(address cdp, address victim, uint256 boxBudget) internal returns (uint256 stethOut) {
        uint256 before = IERC20(STETH).balanceOf(address(this));
        for (uint256 i = 0; i < 40; i++) {
            uint256 d = ICDP(cdp).debt(victim);
            if (d == 0) break;
            uint256 bal = IERC20(BOXETH).balanceOf(address(this));
            if (bal == 0) break;
            uint256 amount = bal * 985 / 1000;
            if (amount > boxBudget) amount = boxBudget;
            if (amount == 0) break;
            uint256 balBefore = IERC20(BOXETH).balanceOf(address(this));
            ICDP(cdp).stabilisePeg(amount, victim);
            uint256 spent = balBefore - IERC20(BOXETH).balanceOf(address(this)); // burn + friction fee
            boxBudget -= spent;
            if (boxBudget == 0) break;
        }
        stethOut = IERC20(STETH).balanceOf(address(this)) - before;
    }

    /* ------------------------------------------------------------------ tests */

    /// T1: live state — custody, debts, roles, market prices
    function test_T1_live_state() public {
        console2.log("== live custody ==");
        console2.log("CDP v1   stETH:", IERC20(STETH).balanceOf(CDP1));
        console2.log("CDP v1.1 stETH:", IERC20(STETH).balanceOf(CDP11));
        console2.log("PSM      stETH:", IERC20(STETH).balanceOf(PSM));
        console2.log("feeSplit stETH:", IERC20(STETH).balanceOf(FEESPLIT));
        console2.log("boxFEE vault boxETH:", IERC20(BOXETH).balanceOf(BOXFEE));
        console2.log("pool 0.05% boxETH:", IERC20(BOXETH).balanceOf(POOL_BOX_WETH_005));
        console2.log("pool 1% wstETH boxETH:", IERC20(BOXETH).balanceOf(POOL_BOX_WST_1PCT));

        console2.log("== debts (redeemable via stabilisePeg) ==");
        console2.log("CDP v1   totalDebt:", ICDP(CDP1).totalDebt());
        console2.log("CDP v1.1 totalDebt:", ICDP(CDP11).totalDebt());
        console2.log("CDP v1   totaldeposits:", ICDP(CDP1).totaldeposits());
        console2.log("CDP v1.1 totaldeposits:", ICDP(CDP11).totaldeposits());
        console2.log("CDP v1   unclaimed:", ICDP(CDP1).unclaimed());
        console2.log("CDP v1.1 unclaimed:", ICDP(CDP11).unclaimed());

        console2.log("== market ==");
        (uint160 sp0,,,,,,) = IUniswapV3Pool(POOL_BOX_WETH_005).slot0();
        console2.log("pool 0.05% sqrtP:", sp0);
        (uint160 sp1,,,,,,) = IUniswapV3Pool(POOL_BOX_WST_1PCT).slot0();
        console2.log("pool 1% wstETH sqrtP:", sp1);

        // invariants
        assertGt(IERC20(STETH).balanceOf(CDP11), 400 ether, "v1.1 custody");
        assertGt(IERC20(STETH).balanceOf(CDP1), 80 ether, "v1 custody");
        assertGt(ICDP(CDP11).totalDebt(), 290 ether, "v1.1 debt");
    }

    /// T2: the only permissionless value-out path (stabilisePeg) is unprofitable at live market prices
    function test_T2_buy_boxeth_and_redeem_is_unprofitable() public {
        uint256[3] memory sizes = [uint256(0.5 ether), 2 ether, 5 ether];
        for (uint256 i = 0; i < 3; i++) {
            uint256 snap = vm.snapshot();
            uint256 wethIn = sizes[i];
            deal(WETH, address(this), wethIn);

            uint256 boxBefore = IERC20(BOXETH).balanceOf(address(this));
            uint256 bought = buyBoxETH(POOL_BOX_WETH_005, wethIn);
            require(IERC20(BOXETH).balanceOf(address(this)) == boxBefore + bought);

            IERC20(BOXETH).approve(CDP11, type(uint256).max);
            uint256 stOut = drainVictim(CDP11, V11_HI_RATIO, bought);

            uint256 leftoverBox = IERC20(BOXETH).balanceOf(address(this));
            // value any leftover boxETH at the pool spot (0.9947) is optimistic; ignore for the bound
            console2.log("buy size (WETH):", wethIn);
            console2.log("  boxETH bought:", bought);
            console2.log("  avg price (wei WETH/boxETH):", (wethIn * 1e18) / (bought == 0 ? 1 : bought));
            console2.log("  stETH redeemed:", stOut);
            console2.log("  leftover boxETH:", leftoverBox);
            console2.log("  NET stETH (redeemed - spent, ignoring leftover):", int256(stOut) - int256(wethIn));

            assertLe(stOut, wethIn, "net must be <= 0 ignoring leftover value");
            vm.revertTo(snap);
        }
    }

    /// T2b: the theoretical best case — tiny buys (negligible price impact) redeemed against the
    /// lowest-friction victims. Measures gross profit vs gas.
    function test_T2b_tiny_arb_best_case() public {
        uint256[2] memory sizes = [uint256(0.01 ether), 0.05 ether];
        address[4] memory tinyVictims = [
            0xaD464ebA8cb053FDe4f2e60E89F0FeDADbc50615, // v1.1 debt ~0.168, fee ~0.19%
            0xbbA31530Cd8e112be845da468B72fbbFE739387A, // v1.1 debt ~0.167, fee ~0.25%
            0x09d8B3952Aa1788F51336f86Fad63726AeB12934, // v1.1 debt ~0.034, fee ~0.19%
            0x5Ac09356EEBffa7bf20d55f1196F3E68b554FcAe  // v1.1 debt ~6.10,  fee ~0.47%
        ];
        for (uint256 i = 0; i < 2; i++) {
            uint256 snap = vm.snapshot();
            uint256 wethIn = sizes[i];
            deal(WETH, address(this), wethIn);
            uint256 g0 = gasleft();
            uint256 bought = buyBoxETH(POOL_BOX_WETH_005, wethIn);
            IERC20(BOXETH).approve(CDP11, type(uint256).max);
            uint256 stOut;
            for (uint256 j = 0; j < tinyVictims.length; j++) {
                stOut += drainVictim(CDP11, tinyVictims[j], type(uint256).max);
            }
            uint256 gasUsed = g0 - gasleft();
            console2.log("tiny buy (WETH):", wethIn);
            console2.log("  boxETH bought:", bought);
            console2.log("  stETH redeemed:", stOut);
            console2.log("  gross net stETH:", int256(stOut) - int256(wethIn));
            console2.log("  gas used:", gasUsed);
            vm.revertTo(snap);
        }
    }

    /// T3: wstETH-pool variant (1% fee) — even worse
    function test_T3_buy_on_wsteth_pool_unprofitable() public {
        uint256 wethIn = 2 ether;
        uint256 st = sourceStETH(wethIn); // WETH -> wstETH -> stETH
        IERC20(STETH).approve(WSTETH, st);
        uint256 wst = IWstETH(WSTETH).wrap(st);
        uint256 boxBefore = IERC20(BOXETH).balanceOf(address(this));
        buyBoxETH(POOL_BOX_WST_1PCT, wst);
        uint256 bought = IERC20(BOXETH).balanceOf(address(this)) - boxBefore;
        IERC20(BOXETH).approve(CDP11, type(uint256).max);
        uint256 stOut = drainVictim(CDP11, V11_HI_RATIO, bought);
        console2.log("wstETH spent:", wst);
        console2.log("boxETH bought:", bought);
        console2.log("stETH redeemed:", stOut);
        console2.log("stETH-equivalent spent (approx):", st);
        assertLe(stOut, st, "net must be <= 0");
    }
    /// T4: mint-based cycle (deposit -> mint -> redeem -> repay) cannot create value
    function test_T4_mint_redeem_cycle_negative() public {
        uint256 st = sourceStETH(3 ether);
        IERC20(STETH).approve(CDP11, st);
        ICDP(CDP11).deposit(st);
        uint256 minted = (st * 985) / 1000; // stay under 99% LTV incl. 0.5% minting fee
        ICDP(CDP11).mint(minted);

        uint256 debtBefore = ICDP(CDP11).debt(address(this));
        IERC20(BOXETH).approve(CDP11, type(uint256).max);
        uint256 stOut = drainVictim(CDP11, V11_HI_RATIO, minted);
        uint256 boxLeft = IERC20(BOXETH).balanceOf(address(this));

        // walk-away P&L: deposited is locked forever (nobody can liquidate a third party)
        console2.log("deposited stETH:", st);
        console2.log("minted boxETH:", minted);
        console2.log("debt after mint:", debtBefore);
        console2.log("stETH received by redeeming minted boxETH:", stOut);
        console2.log("boxETH left:", boxLeft);
        console2.log("walk-away net (stOut - deposited):", int256(stOut) - int256(st));

        // even a hypothetical perfect repayment at par leaves a loss (the 2x0.25% minting fee)
        int256 bestCase = int256(stOut) + int256(st) - int256(debtBefore) - int256(st);
        console2.log("net if debt repaid at par (1 boxETH = 1 stETH):", bestCase);
        assertLt(bestCase, 0, "no value creation");
        assertLt(int256(stOut) - int256(st), 0, "walk-away is a loss");
    }

    /// T5: role-gated exits revert for an unprivileged caller (PSM.trade, feeSplit.trade)
    function test_T5_role_gated_exits_revert() public {
        (bool ok1,) = PSM.call(abi.encodeWithSignature("trade(uint256)", 1 ether));
        require(!ok1, "psm.trade must revert for unprivileged caller");

        (bool ok2,) = FEESPLIT.call(abi.encodeWithSignature("trade(uint256)", 1 ether));
        require(!ok2, "feeSplit.trade must revert for unprivileged caller");

        (bool ok3,) = PSM.call(abi.encodeWithSignature("synthToFeeToken(uint256)", 1 ether));
        require(!ok3, "psm.synthToFeeToken must revert for unprivileged caller");

        assertFalse(ICDP(PSM).hasRole(keccak256("CONVERTER"), address(this)), "attacker has no role");
        assertFalse(ICDP(FEESPLIT).hasRole(keccak256("CONVERTER"), address(this)), "attacker has no role");
        // document who CAN pull: Safe 3/5 + the original deployer EOA (still live)
        bytes32 CR = keccak256("CONVERTER");
        assertTrue(ICDP(PSM).hasRole(CR, SAFE), "safe holds PSM converter");
        assertTrue(ICDP(PSM).hasRole(CR, 0x56C40ade4C96800b13E20A71Ff60c4005F0bCF8e), "deployer EOA holds PSM converter");
        assertTrue(ICDP(FEESPLIT).hasRole(CR, SAFE), "safe holds feeSplit converter");
        assertTrue(ICDP(FEESPLIT).hasRole(CR, 0x56C40ade4C96800b13E20A71Ff60c4005F0bCF8e), "deployer EOA holds feeSplit converter");
    }

    /// T6: boxFEE vault deposits are 1:1 but redemptions are at NAV (0.106 boxETH/share) — entry is a loss
    function test_T6_boxfee_vault_nav_loss() public {
        uint256 nav = IERC4626(BOXFEE).convertToAssets(1 ether);
        console2.log("boxFEE: totalAssets(boxETH):", IERC4626(BOXFEE).totalAssets());
        console2.log("boxFEE: totalSupply:", IERC4626(BOXFEE).totalSupply());
        console2.log("boxFEE: assets per 1 share:", nav);

        deal(BOXETH, address(this), 1 ether);
        IERC20(BOXETH).approve(BOXFEE, 1 ether);
        uint256 sharesBefore = IERC4626(BOXFEE).balanceOf(address(this));
        IERC4626(BOXFEE).deposit(1 ether, address(this));
        uint256 shares = IERC4626(BOXFEE).balanceOf(address(this)) - sharesBefore; // deposit() returns 0 in this vault
        uint256 back = IERC4626(BOXFEE).redeem(shares, address(this), address(this));
        console2.log("deposited boxETH: 1e18; shares:", shares);
        console2.log("redeemed boxETH:", back);
        assertLt(back, 1 ether, "1:1 deposit / NAV redeem = loss");
        assertEq(shares, 1 ether, "1:1 shares minted on deposit");
    }

    /// T7: gross cap — if boxETH were free, at most sum(debt) stETH is redeemable (302.03 total)
    function test_T7_gross_cap_with_free_boxeth() public {
        deal(BOXETH, address(this), 400 ether);
        IERC20(BOXETH).approve(CDP1, type(uint256).max);
        IERC20(BOXETH).approve(CDP11, type(uint256).max);

        uint256 stBefore = IERC20(STETH).balanceOf(address(this));
        // every address with debt > 0 in either CDP (from on-chain event enumeration)
        address[26] memory v11 = [
            0x83C874dbc7708B4E457b5587BB67f73FFdE59525,
            0xB1da4206165EFb834aBBA56704d577D384917f36,
            0xCdD7E78bB4DC4F144c71D1aE700B284aC362f5EE,
            0xA4e75DC1e25992e0A68DA2473DCe40c3542e0A2F,
            0x3D78A8af787fD617e2099B14f261581170d69D53,
            0x5Ac09356EEBffa7bf20d55f1196F3E68b554FcAe,
            0xb5b6AcabC1c2a1d1D1A5FA66577824eBc024e51b,
            0x0601C0c4aeB4a3A126F47aC3C940c4A82231ff72,
            0x17d2847b6844c6F90F182A07Ac5217ba53057727,
            0x8267deF5f3e271841B2236AE47769D6E00ea66B3,
            0x94A3181A0F5edE9d5AE0C8D65D6C95Db25687D24,
            0xcDd535328a10B84Ff64d69858C795A5C26981791,
            0x66F576C1eDa4044A01bF68A78564F39bA3BbF65b,
            0x68e2E52e24cB02d5b52384a5128bD6AbB4D1955a,
            0xbbA31530Cd8e112be845da468B72fbbFE739387A,
            0xaD464ebA8cb053FDe4f2e60E89F0FeDADbc50615,
            0x09d8B3952Aa1788F51336f86Fad63726AeB12934,
            0x53e213da8C28d85dc6663c3b5e35Bb0ffBb05752,
            0x72E5d8D85Db805C275561D9FCE16C11002c676FE,
            0x318C477Bcc1a8226f0e08D77Cd960aea35f09080,
            0xE1aC8aa6f7e27CCcba373DeeACBa012A28818C52,
            0x2F361e48a3A6631429F35376ECCB2aD79cfb5DB2,
            0xF5BAE96e458298d5B723aA350E3BeBaf4779CC24,
            0xe64Ad5F647098aD4c248f06e13Bf3b0148C5C382,
            0x64A0335d96d33EfB44900a593dDa74c518236672,
            0x771991Fc8ce57682775ee73Bb28B201f4016B090
        ];
        for (uint256 i = 0; i < v11.length; i++) drainVictim(CDP11, v11[i], 400 ether);

        address[19] memory v1 = [
            0x3E7929ac8E700f04bf0e2aeD1C5A19fA3EF2017F,
            0xeA2E8c2eD335fa094b5c87977f52C97C1E340C4F,
            0xa745258418E74145E786d3a6D041e4D210CeD10B,
            0x31617759518133EdF52A4b892b59Db906A9ca90F,
            0xB6b8B0e6c825F8436896C4556C6db31c998da325,
            0x56C40ade4C96800b13E20A71Ff60c4005F0bCF8e,
            0x0eD10386B94DBa17Df67693a72EE19E76F3D2adA,
            0x5Ce5CC60270bb7592CE5c96CEE6DFd63B12117a9,
            0xD8B826144e0d7b93f790c31dd06667336F14c68C,
            0x3F579673b2664b0c72e17D6877748371De71314d,
            0x5853eD4f26A3fceA565b3FBC698bb19cdF6DEB85,
            0x4267eC9E933489Dc3D636cF3cd8C2B83dd90776d,
            0x89Fb4C0AaE568dd26ba354f07717285975BF7749,
            0x489DE806345FE50Bee83D6C0363fA459BB31845f,
            0x5FB8b9512684d451D4E585A1a0AabFB48A253C67,
            0xF723E261C020475A638d0D072499125ceEa3120E,
            0xAD4396B8883b4423F3c84889f20ff01b277023ef,
            0xE436513333491CADF3D317e8bAA5Ee5eA04c4827,
            0x4AE25CEF2e5B1B54FD54FE0276124E165De31399
        ];
        for (uint256 i = 0; i < v1.length; i++) drainVictim(CDP1, v1[i], 400 ether);

        uint256 stOut = IERC20(STETH).balanceOf(address(this)) - stBefore;

        console2.log("gross stETH extracted with free boxETH:", stOut);
        console2.log("remaining v1.1 debt:", ICDP(CDP11).totalDebt());
        console2.log("remaining v1 debt:", ICDP(CDP1).totalDebt());
        console2.log("boxETH left (fees paid):", IERC20(BOXETH).balanceOf(address(this)));
        assertLt(stOut, 310 ether, "gross cap ~302 stETH (sum of debts)");
        assertGt(stOut, 250 ether, "most of the debt cap is reachable");
    }

    /// T8: per-call cap of stabilisePeg is debt/4 and total across calls cannot exceed the debt
    function test_T8_stabilisePeg_cap_is_debt() public {
        deal(BOXETH, address(this), 10 ether);
        IERC20(BOXETH).approve(CDP11, type(uint256).max);
        uint256 d0 = ICDP(CDP11).debt(V11_LOW_FEE);
        ICDP(CDP11).stabilisePeg(d0, V11_LOW_FEE); // asks for full debt, capped to debt/4
        uint256 d1 = ICDP(CDP11).debt(V11_LOW_FEE);
        console2.log("debt before:", d0, "after asking for full debt:", d1);
        assertGe(d1, d0 - d0 / 4 - 1, "cap is debt/4");
        assertGt(d1, 0, "debt not wiped in one call");
    }

    /// T9: withdrawals are self-service only — a third party cannot pull a victim's collateral
    function test_T9_third_party_cannot_withdraw() public {
        // non-depositor withdraw must revert (underflow on deposited[msg.sender])
        vm.expectRevert();
        ICDP(CDP11).withdraw(1);
        // a fresh depositor cannot withdraw beyond LTV headroom
        uint256 st = sourceStETH(1 ether);
        IERC20(STETH).approve(CDP11, st);
        ICDP(CDP11).deposit(st);
        ICDP(CDP11).mint(st * 9000 / 10000);
        vm.expectRevert();
        ICDP(CDP11).withdraw(st); // debt*10000/ltv = 0.909*st > st - st
    }

    /// T10: v1 accounting — sum of outstanding "Owing" must be <= unclaimed (no outsider claimable surplus)
    function test_T10_owing_vs_unclaimed() public {
        uint256 pm = ICDP(CDP1).pointMultiplier();
        uint256 tp = ICDP(CDP1).totalPoints();
        uint256 unclaimed = ICDP(CDP1).unclaimed();

        address[6] memory who = [
            0x3E7929ac8E700f04bf0e2aeD1C5A19fA3EF2017F,
            0xeA2E8c2eD335fa094b5c87977f52C97C1E340C4F,
            0xa745258418E74145E786d3a6D041e4D210CeD10B,
            0x31617759518133EdF52A4b892b59Db906A9ca90F,
            0x135879Dc37f2dE69022999185Fe606CCF98E3C1F,
            0x64d091A9C70256763D77fBd4BA2FB6D4D6527aCa
        ];
        uint256 sumOwing;
        for (uint256 i = 0; i < 6; i++) {
            uint256 dep = ICDP(CDP1).deposited(who[i]);
            uint256 debt = ICDP(CDP1).debt(who[i]);
            uint256 lp = ICDP(CDP1).lastPoints(who[i]);
            uint256 weight = dep - debt;
            uint256 owing = weight * (tp - lp) / pm;
            sumOwing += owing;
            console2.log("depositor", who[i]);
            console2.log("  deposited:", dep);
            console2.log("  debt:", debt);
            console2.log("  owing:", owing);
        }
        console2.log("sum owing (top6):", sumOwing);
        console2.log("unclaimed:", unclaimed);
        // unclaimed is paid only to the depositors it was credited to; not extractable by third parties
        assertTrue(sumOwing <= unclaimed + 1, "no outsider surplus");
    }
}
