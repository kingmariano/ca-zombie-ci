// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test, console2} from "forge-std/Test.sol";

/* ------------------------------------------------------------------------------------
   QC-3 — adversarial re-audit of "Cat in a Box" (Ethereum).
   Goal: ASSUME the prior E-U $0 closure is WRONG and try to break it with fresh
   attacker paths. Read-only fork tests; no mainnet transactions.
   Block: latest at run time (fork). All addresses re-verified 2026-10-13.
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
    function ltv() external view returns (uint256);
    function stabilisePeg(uint256 amount, address depositor) external;
    function deposit(uint256 amount) external;
    function mint(uint256 amount) external;
    function liquidate(uint256 amount) external;
    function repay(uint256 amount) external;
    function withdraw(uint256 amount) external;
    function hasRole(bytes32 role, address account) external view returns (bool);
}

interface IWstETH {
    function wrap(uint256 stETHAmount) external returns (uint256);
    function unwrap(uint256 wstETHAmount) external returns (uint256);
}

interface IERC4626 {
    function deposit(uint256 assets, address receiver) external returns (uint256 shares);
    function mint(uint256 shares, address receiver) external returns (uint256 assets);
    function withdraw(uint256 assets, address receiver, address owner) external returns (uint256 shares);
    function redeem(uint256 shares, address receiver, address owner) external returns (uint256 assets);
    function previewRedeem(uint256 shares) external view returns (uint256);
    function previewWithdraw(uint256 assets) external view returns (uint256);
    function convertToAssets(uint256 shares) external view returns (uint256);
    function totalAssets() external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function balanceOf(address) external view returns (uint256);
}

interface IPTO {
    function depositCheapeth(address receiver) external payable returns (uint256 shares);
    function previewRedeem(uint256 shares) external view returns (uint256);
    function redeem(uint256 shares, address receiver, address owner) external returns (uint256 assets);
    function totalAssets() external view returns (uint256);
    function totalSupply() external view returns (uint256);
}

contract QcCatInABoxTest is Test {
    address constant STETH   = 0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84;
    address constant WSTETH  = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;
    address constant WETH    = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant BOXETH  = 0x7690202e2C2297bcD03664e31116d1dFfE7e3B73;
    address constant BOXFEE  = 0xE4B91fAf8810F8895772E7cA065D4CB889120f94;

    address constant CDP1    = 0x7f0A0C7149a46Bf943cCd412da687144b49C6014;
    address constant CDP11   = 0x6ffD098E92B606b2947b89A08911C00ca06890FA;
    address constant PSM     = 0x24146D1B3339Cf76b455dC42e71Ea5Cdff4aE0d7;
    address constant FEESPLIT= 0x320c871b6f7721083604FfdD8070E64c1d3c5d7C;
    address constant SAFE    = 0x98e6475C01D018Ae78c02ef48738f687538226Af;
    address constant DEPLOYER= 0x56C40ade4C96800b13E20A71Ff60c4005F0bCF8e;
    address constant PTO     = 0xCdD7E78bB4DC4F144c71D1aE700B284aC362f5EE; // perpetualTokenOffering (3rd-party, holds 9.11 boxETH)

    address constant POOL_BOX_WETH_005 = 0x287139599f1B5849f12Cf18244A74F595da9936D;
    address constant POOL_BOX_WST_1PCT = 0x703a177fCB4DeF281D180D3619A5EDbaE67ec7b5;
    address constant POOL_BOX_WETH_1PCT = 0x53a26afD001D78dd2F7fa8F966add73F85F83f64; // dead
    address constant POOL_WST_WETH_001 = 0x109830a1AAaD605BbF02a9dFA7B0B92EC2FB7dAa;
    // boxFEE pools (all claimed dead by prior; re-verify live)
    address constant POOL_FEE_WETH_100  = 0x102B0E3ffDd6151d3e2bb760cfe67CB8571fb916;
    address constant POOL_FEE_WETH_3000 = 0x2582959B40449131154182Fa702CF9F29CF2B7cb;
    address constant POOL_FEE_WETH_1PCT = 0x4107a1341262493260F29d05AA5c26EebC31511e;

    uint256 constant MAX_SQRT_RATIO = 1461446703485210103287273052203988822378723970342;

    // ---- v1.1 low-friction victims (best-first, from live state 2026-10-13) ----
    address[10] private v11 = [
        0xaD464ebA8cb053FDe4f2e60E89F0FeDADbc50615, // debt 0.168 fee 0.19%
        0xbbA31530Cd8e112be845da468B72fbbFE739387A, // 0.167 0.25%
        0x5Ac09356EEBffa7bf20d55f1196F3E68b554FcAe, // 6.10  0.47%
        0xB1da4206165EFb834aBBA56704d577D384917f36, // 77.8  0.97%
        0xCdD7E78bB4DC4F144c71D1aE700B284aC362f5EE, // 65.4  1.10% (PTO)
        0x0601C0c4aeB4a3A126F47aC3C940c4A82231ff72, // 2.29  2.47%
        0xA4e75DC1e25992e0A68DA2473DCe40c3542e0A2F, // 26.2  3.75%
        0x83C874dbc7708B4E457b5587BB67f73FFdE59525, // 106.5 4.42%
        0x3D78A8af787fD617e2099B14f261581170d69D53, // 5.29  5.02%
        0xb5b6AcabC1c2a1d1D1A5FA66577824eBc024e51b  // 1.54  5.64%
    ];
    // ---- v1 low-friction victims ----
    address[4] private v1 = [
        0xB6b8B0e6c825F8436896C4556C6db31c998da325, // 0.228 0.10%
        0xD8B826144e0d7b93f790c31dd06667336F14c68C, // 0.020 0.25%
        0xeA2E8c2eD335fa094b5c87977f52C97C1E340C4F, // 3.00  5.04%
        0x3E7929ac8E700f04bf0e2aeD1C5A19fA3EF2017F  // 2.45  9.55%
    ];

    uint256 forkBlock;

    function setUp() public {
        string memory rpc = vm.envOr("FORK_RPC_URL", vm.envOr("RPC_URL", string("https://ethereum-rpc.publicnode.com")));
        vm.createSelectFork(rpc);
        forkBlock = block.number;
        console2.log("QC fork block:", forkBlock);
    }

    /* ------------------------------------------------------------------ helpers */

    function uniswapV3SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata) external {
        address t0 = IUniswapV3Pool(msg.sender).token0();
        address t1 = IUniswapV3Pool(msg.sender).token1();
        if (amount0Delta > 0) require(IERC20(t0).transfer(msg.sender, uint256(amount0Delta)));
        if (amount1Delta > 0) require(IERC20(t1).transfer(msg.sender, uint256(amount1Delta)));
    }

    function buyBoxETH(address pool, uint256 amountIn) internal returns (uint256 boxOut) {
        IUniswapV3Pool p = IUniswapV3Pool(pool);
        require(p.token0() == BOXETH, "token0 must be boxETH");
        uint256 before = IERC20(BOXETH).balanceOf(address(this));
        p.swap(address(this), false, int256(amountIn), uint160(MAX_SQRT_RATIO - 1), "");
        boxOut = IERC20(BOXETH).balanceOf(address(this)) - before;
    }

    function sourceStETH(uint256 wethIn) internal returns (uint256 stOut) {
        deal(WETH, address(this), wethIn);
        IERC20(WETH).approve(POOL_WST_WETH_001, wethIn);
        uint256 before = IERC20(WSTETH).balanceOf(address(this));
        IUniswapV3Pool(POOL_WST_WETH_001).swap(address(this), false, int256(wethIn), uint160(MAX_SQRT_RATIO - 1), "");
        uint256 wst = IERC20(WSTETH).balanceOf(address(this)) - before;
        stOut = IWstETH(WSTETH).unwrap(wst);
    }

    /// marginal friction fee (wad, per 1e18 redeemed) of a victim: 0.1 * (1 - debt/deposited)
    function margFee(address cdp, address victim) internal view returns (uint256) {
        uint256 D = ICDP(cdp).debt(victim);
        uint256 P = ICDP(cdp).deposited(victim);
        if (D < 4 || P == 0 || D > P) return type(uint256).max;
        return ((P - D) * 1e17) / P;
    }

    /// greedy optimal redemption of `budget` boxETH across the given victims (cheapest marginal fee first)
    function redeemOptimal(uint256 budget, uint256 maxSteps) internal returns (uint256 stethOut) {
        IERC20(BOXETH).approve(CDP1, type(uint256).max);
        IERC20(BOXETH).approve(CDP11, type(uint256).max);
        uint256 before = IERC20(STETH).balanceOf(address(this));
        uint256 startBal = IERC20(BOXETH).balanceOf(address(this));
        if (budget > startBal) budget = startBal;
        for (uint256 step = 0; step < maxSteps; step++) {
            uint256 bal = IERC20(BOXETH).balanceOf(address(this));
            if (startBal - bal >= budget) break;
            if (bal < 1e6) break;
            // pick cheapest marginal fee among both lists
            address cdp;
            address victim;
            uint256 best = type(uint256).max;
            for (uint256 i = 0; i < v11.length; i++) {
                uint256 f = margFee(CDP11, v11[i]);
                if (f < best) { best = f; cdp = CDP11; victim = v11[i]; }
            }
            for (uint256 i = 0; i < v1.length; i++) {
                uint256 f = margFee(CDP1, v1[i]);
                if (f < best) { best = f; cdp = CDP1; victim = v1[i]; }
            }
            if (cdp == address(0)) break;
            uint256 D = ICDP(cdp).debt(victim);
            uint256 amount = D / 4;                       // per-call cap
            uint256 remaining = budget - (startBal - bal); // boxETH still allowed
            uint256 burnCap = (bal < remaining ? bal : remaining) * 10 / 11; // <=10% fee headroom
            if (amount > burnCap) amount = burnCap;
            if (amount == 0) break;
            ICDP(cdp).stabilisePeg(amount, victim);
        }
        stethOut = IERC20(STETH).balanceOf(address(this)) - before;
    }

    /* ------------------------------------------------------------------ QC tests */

    /// QC1 — live state + roles re-verified fresh (block at run time)
    function test_QC1_live_state_and_roles_remain_gated() public {
        console2.log("CDP v1   stETH:", IERC20(STETH).balanceOf(CDP1));
        console2.log("CDP v1.1 stETH:", IERC20(STETH).balanceOf(CDP11));
        console2.log("v1 totalDebt:", ICDP(CDP1).totalDebt());
        console2.log("v1.1 totalDebt:", ICDP(CDP11).totalDebt());
        assertGt(IERC20(STETH).balanceOf(CDP11), 400 ether, "v1.1 custody");
        assertGt(IERC20(STETH).balanceOf(CDP1), 80 ether, "v1 custody");

        bytes32 CR = keccak256("CONVERTER");
        bytes32 ADMIN = keccak256("ADMIN");
        assertTrue(ICDP(PSM).hasRole(CR, SAFE));
        assertTrue(ICDP(PSM).hasRole(CR, DEPLOYER));
        assertTrue(ICDP(FEESPLIT).hasRole(CR, SAFE));
        assertTrue(ICDP(FEESPLIT).hasRole(CR, DEPLOYER));
        assertFalse(ICDP(PSM).hasRole(CR, address(this)), "attacker has PSM role");
        assertFalse(ICDP(FEESPLIT).hasRole(CR, address(this)), "attacker has feeSplit role");
        // boxETH mint right: only the two CDPs
        assertTrue(ICDP(BOXETH).hasRole(ADMIN, CDP1), "cdp1 mint right");
        assertTrue(ICDP(BOXETH).hasRole(ADMIN, CDP11), "cdp11 mint right");
        assertFalse(ICDP(BOXETH).hasRole(ADMIN, SAFE), "safe must not mint boxETH");
        assertFalse(ICDP(BOXETH).hasRole(ADMIN, DEPLOYER), "deployer must not mint boxETH");
        // role-gated exits revert for outsiders
        (bool ok1,) = PSM.call(abi.encodeWithSignature("trade(uint256)", 1 ether));
        assertFalse(ok1, "PSM.trade must revert");
        (bool ok2,) = PSM.call(abi.encodeWithSignature("synthToFeeToken(uint256)", 1 ether));
        assertFalse(ok2, "synthToFeeToken must revert");
        (bool ok3,) = FEESPLIT.call(abi.encodeWithSignature("trade(uint256)", 1 ether));
        assertFalse(ok3, "feeSplit.trade must revert");
    }

    /// QC2 — adversarial: sweep the FULL depth of both live pools; redeem with the
    /// globally optimal (lowest marginal fee) strategy. Claim to break: net > 0.
    function test_QC2_full_pool_sweep_is_unprofitable() public {
        uint256[6] memory sizes = [uint256(0.01 ether), 0.1 ether, 0.5 ether, 1 ether, 3 ether, 5 ether];
        for (uint256 i = 0; i < 6; i++) {
            uint256 snap = vm.snapshot();
            uint256 wethIn = sizes[i];
            deal(WETH, address(this), wethIn);
            uint256 bought = buyBoxETH(POOL_BOX_WETH_005, wethIn);
            uint256 stOut = redeemOptimal(bought, 60);
            int256 net = int256(stOut) - int256(wethIn);
            console2.log("QC2 buy WETH:", wethIn);
            console2.log("  boxETH bought:", bought);
            console2.log("  avg buy price (wei/boxETH):", (wethIn * 1e18) / (bought == 0 ? 1 : bought));
            console2.log("  stETH redeemed:", stOut);
            console2.log("  NET stETH:", net);
            // adversarial bar: no size may clear > $5 gross (0.002 stETH) before gas
            assertLe(net, 0.002 ether, "QC2: profitable sweep found");
            vm.revertTo(snap);
        }
    }

    /// QC2b — sweep the wstETH 1% pool (stETH-equivalent cost basis)
    function test_QC2b_wsteth_pool_sweep_unprofitable() public {
        uint256[2] memory sizes = [uint256(0.5 ether), 2 ether];
        for (uint256 i = 0; i < 2; i++) {
            uint256 snap = vm.snapshot();
            uint256 st = sourceStETH(sizes[i]);
            IERC20(STETH).approve(WSTETH, st);
            uint256 wst = IWstETH(WSTETH).wrap(st);
            uint256 bought = buyBoxETH(POOL_BOX_WST_1PCT, wst);
            uint256 stOut = redeemOptimal(bought, 60);
            console2.log("QC2b stETH spent:", st);
            console2.log("  boxETH bought:", bought);
            console2.log("  stETH redeemed:", stOut);
            assertLe(int256(stOut) - int256(st), 0.002 ether, "QC2b: profitable sweep found");
            vm.revertTo(snap);
        }
    }

    /// QC2c — buy from BOTH pools in one budget and redeem optimally (atomic best case)
    function test_QC2c_both_pools_combined_unprofitable() public {
        uint256 wethA = 1 ether;
        deal(WETH, address(this), wethA);
        uint256 boughtA = buyBoxETH(POOL_BOX_WETH_005, wethA);
        uint256 st = sourceStETH(1 ether);
        IERC20(STETH).approve(WSTETH, st);
        uint256 wst = IWstETH(WSTETH).wrap(st);
        uint256 boughtB = buyBoxETH(POOL_BOX_WST_1PCT, wst);
        uint256 stOut = redeemOptimal(boughtA + boughtB, 80);
        console2.log("QC2c combined bought:", boughtA + boughtB);
        console2.log("  spent (WETH + stETH-equivalent):", wethA + st);
        console2.log("  stETH redeemed:", stOut);
        assertLe(int256(stOut) - int256(wethA + st), 0.002 ether, "QC2c: profitable combined sweep found");
    }

    /// QC3 — NEW path not tested by the prior audit: mint on v1 (no minting fee) ->
    /// SELF-LIQUIDATE (collateral goes to PSM, boxETH is NOT burned) -> redeem boxETH
    /// against other borrowers. Try to convert own collateral into foreign stETH.
    function test_QC3_liquidate_cycle_is_unprofitable() public {
        uint256 snap = vm.snapshot();
        uint256 st = sourceStETH(3 ether);
        IERC20(STETH).approve(CDP1, st);
        ICDP(CDP1).deposit(st);
        uint256 minted = (st * 98) / 100; // 2.94 boxETH under 99% LTV
        ICDP(CDP1).mint(minted);
        assertEq(ICDP(CDP1).debt(address(this)), minted, "debt");

        uint256 psmBefore = IERC20(STETH).balanceOf(PSM);
        ICDP(CDP1).liquidate(minted); // sends own collateral to PSM; KEEPS boxETH
        uint256 psmGain = IERC20(STETH).balanceOf(PSM) - psmBefore;
        console2.log("QC3 psm collateral gained:", psmGain);
        assertGe(psmGain, minted - 2, "collateral moved to PSM");

        uint256 depLeft = ICDP(CDP1).deposited(address(this));
        if (depLeft > 0) ICDP(CDP1).withdraw(depLeft); // walk away with freed collateral

        uint256 stOut = redeemOptimal(minted, 60);
        int256 walkAway = int256(depLeft) + int256(stOut) - int256(st);
        console2.log("QC3 walk-away NET stETH:", walkAway);
        assertLt(walkAway, 0, "QC3: liquidate cycle creates value");
        vm.revertTo(snap);
    }

    /// QC4 — boxFEE vault: every entry/exit combination loses; no cheap share route
    function test_QC4_boxfee_vault_roundtrips_all_lose() public {
        uint256 TA = IERC4626(BOXFEE).totalAssets();
        uint256 TS = IERC4626(BOXFEE).totalSupply();
        console2.log("QC4 vault TA:", TA);
        console2.log("QC4 vault TS:", TS);

        // deposit 1 boxETH -> 1:1 shares -> redeem at NAV (<= 0.107)
        deal(BOXETH, address(this), 2 ether);
        IERC20(BOXETH).approve(BOXFEE, type(uint256).max);
        uint256 shBefore = IERC4626(BOXFEE).balanceOf(address(this));
        IERC4626(BOXFEE).deposit(1 ether, address(this));
        uint256 shares = IERC4626(BOXFEE).balanceOf(address(this)) - shBefore;
        assertEq(shares, 1 ether, "deposit mints 1:1");
        uint256 back = IERC4626(BOXFEE).redeem(shares, address(this), address(this));
        console2.log("QC4 deposit 1e18 -> redeem:", back);
        assertLt(back, 0.2 ether, "deposit->redeem must lose");

        // mint 1 share -> costs 1 boxETH (1:1) -> redeem at NAV
        uint256 shBefore2 = IERC4626(BOXFEE).balanceOf(address(this));
        IERC4626(BOXFEE).mint(1 ether, address(this));
        uint256 shares2 = IERC4626(BOXFEE).balanceOf(address(this)) - shBefore2;
        uint256 back2 = IERC4626(BOXFEE).redeem(shares2, address(this), address(this));
        console2.log("QC4 mint 1e18 shares cost 1e18 -> redeem:", back2);
        assertLt(back2, 0.2 ether, "mint->redeem must lose");

        // withdraw(1 boxETH) needs ~9.4x shares -> depositing shares costs 9.4x
        uint256 sharesNeeded = IERC4626(BOXFEE).previewWithdraw(1 ether);
        console2.log("QC4 shares needed to withdraw 1 boxETH:", sharesNeeded);
        assertGt(sharesNeeded, 5 ether, "withdraw path must need >5x shares");
    }

    /// QC5 — boxFEE pools and the dead 1% boxETH pool: re-verify dust (no cheap share route)
    function test_QC5_all_secondary_pools_are_dust() public {
        uint256 fee100 = IERC20(BOXFEE).balanceOf(POOL_FEE_WETH_100);
        uint256 fee3000 = IERC20(BOXFEE).balanceOf(POOL_FEE_WETH_3000);
        uint256 fee1pct = IERC20(BOXFEE).balanceOf(POOL_FEE_WETH_1PCT);
        console2.log("QC5 boxFEE pool100 boxFEE:", fee100);
        console2.log("QC5 boxFEE pool3000 boxFEE:", fee3000);
        console2.log("QC5 boxFEE pool1pct boxFEE:", fee1pct);
        assertLt(fee100, 1e15, "pool100 not dust");
        assertLt(fee3000, 1e15, "pool3000 not dust");
        assertLt(fee1pct, 1e16, "pool1pct not dust");
        assertEq(IUniswapV3Pool(POOL_FEE_WETH_100).liquidity(), 0, "pool100 liquidity");
        assertEq(IUniswapV3Pool(POOL_FEE_WETH_3000).liquidity(), 0, "pool3000 liquidity");
        assertLt(IUniswapV3Pool(POOL_FEE_WETH_1PCT).liquidity(), 1e16, "pool1pct liquidity");
        // dead boxETH/WETH 1% pool holds 4 wei
        assertLe(IERC20(BOXETH).balanceOf(POOL_BOX_WETH_1PCT), 100, "dead 1% pool");
    }

    /// QC6 — third-party boxETH holder PTO (9.11 boxETH): can it be acquired below fair?
    /// depositCheapeth applies a 10% haircut; shares are minted at NAV; no edge.
    function test_QC6_pto_boxeth_not_cheap() public {
        uint256 snap = vm.snapshot();
        vm.deal(address(this), 1 ether);
        uint256 sharesBefore = IERC20(PTO).balanceOf(address(this));
        IPTO(PTO).depositCheapeth{value: 0.1 ether}(address(this));
        uint256 shares = IERC20(PTO).balanceOf(address(this)) - sharesBefore;
        uint256 redeemable = IPTO(PTO).previewRedeem(shares);
        uint256 boxBefore = IERC20(BOXETH).balanceOf(address(this));
        uint256 got = IPTO(PTO).redeem(shares, address(this), address(this));
        uint256 boxGot = IERC20(BOXETH).balanceOf(address(this)) - boxBefore;
        console2.log("QC6 PTO shares for 0.1 ETH:", shares);
        console2.log("QC6 previewRedeem:", redeemable);
        console2.log("QC6 actual boxETH out:", got, boxGot);
        // 0.1 ETH in -> <=0.09 boxETH out (10% haircut) => not cheap boxETH
        assertLt(got, 0.1 ether, "PTO must not sell boxETH below par");
        assertLt(boxGot, 0.1 ether, "PTO boxETH out must be < 0.1");
        vm.revertTo(snap);
    }

    /// QC7 — re-verify the gross redemption ceiling (overhang exists but needs 315.68 boxETH)
    function test_QC7_gross_overhang_requires_boxeth() public {
        uint256 snap = vm.snapshot();
        deal(BOXETH, address(this), 400 ether);
        IERC20(BOXETH).approve(CDP1, type(uint256).max);
        IERC20(BOXETH).approve(CDP11, type(uint256).max);
        uint256 stBefore = IERC20(STETH).balanceOf(address(this));

        address[26] memory v11all = [
            0x83C874dbc7708B4E457b5587BB67f73FFdE59525, 0xB1da4206165EFb834aBBA56704d577D384917f36,
            0xCdD7E78bB4DC4F144c71D1aE700B284aC362f5EE, 0xA4e75DC1e25992e0A68DA2473DCe40c3542e0A2F,
            0x3D78A8af787fD617e2099B14f261581170d69D53, 0x5Ac09356EEBffa7bf20d55f1196F3E68b554FcAe,
            0xb5b6AcabC1c2a1d1D1A5FA66577824eBc024e51b, 0x0601C0c4aeB4a3A126F47aC3C940c4A82231ff72,
            0x17d2847b6844c6F90F182A07Ac5217ba53057727, 0x8267deF5f3e271841B2236AE47769D6E00ea66B3,
            0x94A3181A0F5edE9d5AE0C8D65D6C95Db25687D24, 0xcDd535328a10B84Ff64d69858C795A5C26981791,
            0x66F576C1eDa4044A01bF68A78564F39bA3BbF65b, 0x68e2E52e24cB02d5b52384a5128bD6AbB4D1955a,
            0xbbA31530Cd8e112be845da468B72fbbFE739387A, 0xaD464ebA8cb053FDe4f2e60E89F0FeDADbc50615,
            0x09d8B3952Aa1788F51336f86Fad63726AeB12934, 0x53e213da8C28d85dc6663c3b5e35Bb0ffBb05752,
            0x72E5d8D85Db805C275561D9FCE16C11002c676FE, 0x318C477Bcc1a8226f0e08D77Cd960aea35f09080,
            0xE1aC8aa6f7e27CCcba373DeeACBa012A28818C52, 0x2F361e48a3A6631429F35376ECCB2aD79cfb5DB2,
            0xF5BAE96e458298d5B723aA350E3BeBaf4779CC24, 0xe64Ad5F647098aD4c248f06e13Bf3b0148C5C382,
            0x64A0335d96d33EfB44900a593dDa74c518236672, 0x771991Fc8ce57682775ee73Bb28B201f4016B090
        ];
        for (uint256 i = 0; i < v11all.length; i++) drainAll(CDP11, v11all[i]);
        address[19] memory v1all = [
            0x3E7929ac8E700f04bf0e2aeD1C5A19fA3EF2017F, 0xeA2E8c2eD335fa094b5c87977f52C97C1E340C4F,
            0xa745258418E74145E786d3a6D041e4D210CeD10B, 0x31617759518133EdF52A4b892b59Db906A9ca90F,
            0xB6b8B0e6c825F8436896C4556C6db31c998da325, 0x56C40ade4C96800b13E20A71Ff60c4005F0bCF8e,
            0x0eD10386B94DBa17Df67693a72EE19E76F3D2adA, 0x5Ce5CC60270bb7592CE5c96CEE6DFd63B12117a9,
            0xD8B826144e0d7b93f790c31dd06667336F14c68C, 0x3F579673b2664b0c72e17D6877748371De71314d,
            0x5853eD4f26A3fceA565b3FBC698bb19cdF6DEB85, 0x4267eC9E933489Dc3D636cF3cd8C2B83dd90776d,
            0x89Fb4C0AaE568dd26ba354f07717285975BF7749, 0x489DE806345FE50Bee83D6C0363fA459BB31845f,
            0x5FB8b9512684d451D4E585A1a0AabFB48A253C67, 0xF723E261C020475A638d0D072499125ceEa3120E,
            0xAD4396B8883b4423F3c84889f20ff01b277023ef, 0xE436513333491CADF3D317e8bAA5Ee5eA04c4827,
            0x4AE25CEF2e5B1B54FD54FE0276124E165De31399
        ];
        for (uint256 i = 0; i < v1all.length; i++) drainAll(CDP1, v1all[i]);
        uint256 stOut = IERC20(STETH).balanceOf(address(this)) - stBefore;
        console2.log("QC7 gross stETH with free boxETH:", stOut);
        console2.log("QC7 v1.1 debt left:", ICDP(CDP11).totalDebt());
        console2.log("QC7 v1 debt left:", ICDP(CDP1).totalDebt());
        assertGt(stOut, 250 ether, "overhang must be real");
        assertLt(stOut, 310 ether, "gross cap ~302");
        vm.revertTo(snap);
    }

    /// QC8 — conditional quantification from live state:
    /// * the full-drain blended break-even is ~0.9568 stETH/boxETH (315.68 boxETH needed);
    /// * the debt redeemable at marginal fee <0.5% (i.e. near-par) is tiny;
    /// * total live market depth is 9.76 boxETH.
    function test_QC8_conditional_unlock_quantified() public {
        uint256 td1 = ICDP(CDP1).totalDebt();
        uint256 td11 = ICDP(CDP11).totalDebt();
        uint256 totalDebt = td1 + td11;
        console2.log("QC8 total redeemable debt (stETH):", totalDebt);
        assertGt(totalDebt, 290 ether);
        assertLt(totalDebt, 310 ether);

        // near-par debt: marginal fee < 0.5% across the union of known victims + top two
        uint256 nearPar;
        for (uint256 i = 0; i < v11.length; i++) {
            uint256 f = margFee(CDP11, v11[i]);
            if (f < 5e15) nearPar += ICDP(CDP11).debt(v11[i]);
        }
        for (uint256 i = 0; i < v1.length; i++) {
            uint256 f = margFee(CDP1, v1[i]);
            if (f < 5e15) nearPar += ICDP(CDP1).debt(v1[i]);
        }
        console2.log("QC8 debt at marginal fee <0.5%:", nearPar);
        assertLt(nearPar, 10 ether, "near-par redemption capacity must be small");

        // market depth: pools only
        uint256 depth = IERC20(BOXETH).balanceOf(POOL_BOX_WETH_005) + IERC20(BOXETH).balanceOf(POOL_BOX_WST_1PCT);
        console2.log("QC8 live pool depth (boxETH):", depth);
        assertLt(depth, 11 ether, "pool depth");

        // 0.05% pool marginal price (WETH per boxETH, 1e18) must be ~par
        (uint160 sp,,,,,,) = IUniswapV3Pool(POOL_BOX_WETH_005).slot0();
        uint256 priceWad = (uint256(sp) * uint256(sp) * 1e18) >> 192;
        console2.log("QC8 pool005 marginal WETH/boxETH:", priceWad);
        assertGt(priceWad, 0.95e18);
        assertLt(priceWad, 1.05e18);
    }

    function drainAll(address cdp, address victim) internal {
        IERC20(BOXETH).approve(cdp, type(uint256).max);
        for (uint256 i = 0; i < 40; i++) {
            uint256 d = ICDP(cdp).debt(victim);
            if (d < 4) break;
            uint256 amount = d / 4;
            if (amount == 0) break;
            ICDP(cdp).stabilisePeg(amount, victim);
        }
    }
}
