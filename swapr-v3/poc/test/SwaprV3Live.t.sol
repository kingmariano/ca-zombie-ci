// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {IERC20, IAlgebraPool, IAlgebraFactory, IHypervisor, IUniProxy, IClearing, INFPM, IFarmingCenter, IAlgebraEternalFarming, IV3Fees, IDataStorageOperator} from "../src/Interfaces.sol";
import {TickMath, FullMath} from "../src/Math.sol";

/// @title Swapr V3 (Gnosis) live-state PoC — read-only measurement on a fork.
/// No mainnet transactions: everything runs on a local fork of Gnosis.
/// Fork defaults to the RPC tip (set SWAPR_FORK_BLOCK to pin a block if the RPC serves archive state).
contract SwaprV3LiveTest is Test {
    // ---- live addresses (Gnosis chain 100) ----
    address constant FACTORY = 0xA0864cCA6E114013AB0e27cbd5B6f4c8947da766;
    address constant POOL = 0xA8bE29B73c9752AEB3DB3aa78f171861079685C7; // WETH/wstETH custom pool (tickSpacing=1)
    address constant WETH = 0x6A023CCd1ff6F2045C3309768eAd9E68F978f6e1;
    address constant WSTETH = 0x6C76971f98945AE98dD7d4DFcA8711ebea946eA6;
    address constant HYPERVISOR = 0x216D3DF2DF6DeC7c95D3b51F018eE4b11E416eBb; // Gamma Hypervisor aWETH-wstETH
    address constant UNIPROXY = 0x38f61169D8bcc08cE303401A13332259F557B35f;
    address constant CLEARING = 0x1E86A593E55215957C4755f1BE19a229AF3286f6;
    address constant NFPM = 0x91fD594c46D8B01E62dBDeBed2401dde01817834;
    address constant FARMING_CENTER = 0xDe51dDF1aE7d5BBD7bF1A0e40aAA1F6C12579106;
    address constant ETERNAL_FARMING = 0x607BbfD4CEbd869AaD04331F8a2AD0C3C396674b;
    address constant V3FEES = 0x187E0966046dA5b110Fdc986c9B94Bd8416837AF;
    address constant NFPM_POS_322_OWNER = 0xb2902572F50d05Ba7EF5F86f1eF42DcD267Bc935;
    address constant USDC_E = 0x2a22f9c3b484c3629090FeED35F17Ff8F88f76F0;

    IAlgebraPool pool = IAlgebraPool(POOL);
    IHypervisor hyp = IHypervisor(HYPERVISOR);

    function setUp() public {
        string memory rpc = vm.envOr("GNOSIS_RPC_URL", string("https://rpc.gnosischain.com"));
        uint256 fb = vm.envOr("SWAPR_FORK_BLOCK", uint256(0));
        if (fb == 0) vm.createSelectFork(rpc);
        else vm.createSelectFork(rpc, fb);
        vm.deal(address(this), 1000 ether); // gas (xDAI)
        console2.log("fork block", block.number);
    }

    // ---------------------------------------------------------------- helpers

    function _tick() internal view returns (int24 t) {
        (, t, , , , , ) = pool.globalState();
    }

    function _sqrtPrice() internal view returns (uint160 p) {
        (p, , , , , , ) = pool.globalState();
    }

    function _price1per0E18() internal view returns (uint256) {
        uint160 sp = _sqrtPrice();
        return FullMath.mulDiv(uint256(sp) * uint256(sp), 1e18, 2 ** 192);
    }

    function _valueInToken1(address who) internal view returns (uint256) {
        uint256 b0 = IERC20(WETH).balanceOf(who);
        uint256 b1 = IERC20(WSTETH).balanceOf(who);
        return b1 + FullMath.mulDiv(b0, _price1per0E18(), 1e18);
    }

    function _vaultValueInToken1() internal view returns (uint256) {
        (uint256 t0, uint256 t1) = hyp.getTotalAmounts();
        return t1 + FullMath.mulDiv(t0, _price1per0E18(), 1e18);
    }

    function _fund(uint256 wethAmt, uint256 wstethAmt) internal {
        deal(WETH, address(this), wethAmt);
        deal(WSTETH, address(this), wstethAmt);
        require(IERC20(WETH).balanceOf(address(this)) == wethAmt, "deal WETH failed");
        require(IERC20(WSTETH).balanceOf(address(this)) == wstethAmt, "deal wstETH failed");
        IERC20(WETH).approve(UNIPROXY, type(uint256).max);
        IERC20(WSTETH).approve(UNIPROXY, type(uint256).max);
    }

    function _pushPrice(bool pushDown, int24 targetTick) internal {
        uint160 limit = TickMath.getSqrtRatioAtTick(targetTick);
        pool.swap(address(this), pushDown, 1e30, limit, "");
    }

    function _swapExactIn(bool zeroToOne, uint256 amountIn, int24 targetTick) internal {
        uint160 limit = TickMath.getSqrtRatioAtTick(targetTick);
        pool.swap(address(this), zeroToOne, int256(amountIn), limit, "");
    }

    function algebraSwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata) external {
        require(msg.sender == POOL, "only pool");
        if (amount0Delta > 0) IERC20(WETH).transfer(POOL, uint256(amount0Delta));
        if (amount1Delta > 0) IERC20(WSTETH).transfer(POOL, uint256(amount1Delta));
    }

    /// staticcall to clearing.clearDeposit, returns success + raw revert data
    function _tryClearDeposit(uint256 d0, uint256 d1) internal view returns (bool ok, bytes memory data) {
        uint256[4] memory minIn;
        (ok, data) = CLEARING.staticcall(
            abi.encodeWithSelector(IClearing.clearDeposit.selector, d0, d1, address(this), address(this), HYPERVISOR, minIn)
        );
    }

    function _reason(bytes memory data) internal pure returns (string memory) {
        if (data.length < 68) return "<no reason>";
        // Error(string)
        bytes memory slice = new bytes(data.length - 4);
        for (uint256 i = 4; i < data.length; i++) slice[i - 4] = data[i];
        return abi.decode(slice, (string));
    }

    // ---------------------------------------------------------------- 1. live state

    function test_live_state() public view {
        (uint160 sp, int24 tick, uint16 fee, , uint8 cf0, uint8 cf1, bool unlocked) = pool.globalState();
        sp;
        console2.log("block", block.number);
        console2.log("pool token0", pool.token0());
        console2.log("pool token1", pool.token1());
        console2.log("pool tick", tick);
        console2.log("pool fee", fee);
        console2.log("communityFee0/1", cf0, cf1);
        console2.log("unlocked", unlocked);
        console2.log("pool liquidity", uint256(pool.liquidity()));
        console2.log("WETH in pool", IERC20(WETH).balanceOf(POOL));
        console2.log("wstETH in pool", IERC20(WSTETH).balanceOf(POOL));
        console2.log("factory owner", IAlgebraFactory(FACTORY).owner());
        console2.log("factory farming", IAlgebraFactory(FACTORY).farmingAddress());
        console2.log("factory vault", IAlgebraFactory(FACTORY).vaultAddress());
        console2.log("hypervisor baseLower", int256(hyp.baseLower()));
        console2.log("hypervisor baseUpper", int256(hyp.baseUpper()));
        console2.log("hypervisor limitLower", int256(hyp.limitLower()));
        console2.log("hypervisor limitUpper", int256(hyp.limitUpper()));
        (uint256 t0, uint256 t1) = hyp.getTotalAmounts();
        console2.log("hypervisor total0", t0);
        console2.log("hypervisor total1", t1);
        console2.log("hypervisor supply", hyp.totalSupply());
        console2.log("hypervisor owner", hyp.owner());
        console2.log("hypervisor whitelist", hyp.whitelistedAddress());
        assertEq(pool.token0(), WETH);
        assertEq(pool.token1(), WSTETH);
        assertTrue(unlocked);
    }

    // ---------------------------------------------------------------- 2. admin gates

    function test_admin_gates_closed() public {
        IAlgebraFactory f = IAlgebraFactory(FACTORY);
        vm.expectRevert();
        f.setOwner(address(this));
        vm.expectRevert();
        f.setFarmingAddress(address(this));
        vm.expectRevert();
        f.setDefaultCommunityFee(250);
        vm.expectRevert();
        f.setVaultAddress(address(this));
        vm.expectRevert();
        f.setBaseFeeConfiguration(1, 1, 1, 1, 1, 1, 1, 1, 1);

        vm.expectRevert();
        pool.setCommunityFee(250, 250);
        vm.expectRevert();
        pool.setTickSpacing(60);
        vm.expectRevert();
        pool.setLiquidityCooldown(3600);
        vm.expectRevert();
        pool.setIncentive(address(this));
        vm.expectRevert();
        pool.initialize(1 << 96);

        IDataStorageOperator dso = IDataStorageOperator(pool.dataStorageOperator());
        IDataStorageOperator.FeeConfiguration memory fc =
            IDataStorageOperator.FeeConfiguration(1, 1, 1, 1, 1, 1, 1, 1, 1);
        vm.expectRevert();
        dso.changeFeeConfiguration(fc);
        console2.log("admin gates: all reverted as expected");
    }

    // ---------------------------------------------------------------- 3. position isolation

    function test_position_isolation() public {
        int24 bl = hyp.baseLower();
        int24 bu = hyp.baseUpper();
        uint256 before0 = IERC20(WETH).balanceOf(address(this));
        uint256 before1 = IERC20(WSTETH).balanceOf(address(this));
        (uint128 a0, uint128 a1) = pool.collect(address(this), bl, bu, type(uint128).max, type(uint128).max);
        assertEq(uint256(a0) + uint256(a1), 0, "collected something");
        assertEq(IERC20(WETH).balanceOf(address(this)), before0);
        assertEq(IERC20(WSTETH).balanceOf(address(this)), before1);
        vm.expectRevert(); // 'LA' - cannot burn liquidity you do not have
        pool.burn(bl, bu, 1);
        console2.log("position isolation: collect=0, burn reverts for attacker-owned range");
    }

    // ---------------------------------------------------------------- 4. NFPM / farming gates

    function test_nfpm_position_322_gates() public view {
        (, , address t0, address t1, int24 tl, int24 tu, uint128 liq, , , uint128 owed0, uint128 owed1) = INFPM(NFPM).positions(322);
        owed0; owed1;
        console2.log("tokenId 322 owner", INFPM(NFPM).ownerOf(322));
        console2.log("t0", t0);
        console2.log("t1", t1);
        console2.log("tickLower", int256(tl));
        console2.log("tickUpper", int256(tu));
        console2.log("liquidity", uint256(liq));
        assertEq(INFPM(NFPM).ownerOf(322), NFPM_POS_322_OWNER);
    }

    function test_nfpm_and_farming_gates_closed() public {
        INFPM.CollectParams memory cp = INFPM.CollectParams(322, address(this), type(uint128).max, type(uint128).max);
        vm.expectRevert(bytes("Not approved"));
        INFPM(NFPM).collect(cp);
        INFPM.DecreaseLiquidityParams memory dp = INFPM.DecreaseLiquidityParams(322, 1, 0, 0, block.timestamp + 1000);
        vm.expectRevert(bytes("Not approved"));
        INFPM(NFPM).decreaseLiquidity(dp);
        vm.expectRevert();
        INFPM(NFPM).burn(322);
        vm.expectRevert();
        IFarmingCenter(FARMING_CENTER).withdrawToken(322, address(this), "");
        IAlgebraEternalFarming ef = IAlgebraEternalFarming(ETERNAL_FARMING);
        console2.log("eternalFarming incentiveMaker", ef.incentiveMaker());
        IAlgebraEternalFarming.IncentiveKey memory key =
            IAlgebraEternalFarming.IncentiveKey(WETH, WETH, POOL, block.timestamp, block.timestamp + 1 days);
        IAlgebraEternalFarming.IncentiveParams memory params =
            IAlgebraEternalFarming.IncentiveParams(1, 0, 1, 0, 0, address(0));
        IAlgebraEternalFarming.Tiers memory tiers = IAlgebraEternalFarming.Tiers(0, 0, 0, 0, 0, 0);
        vm.expectRevert();
        ef.createEternalFarming(key, params, tiers);
        console2.log("nfpm/farming gates: all reverted as expected");
    }

    // ---------------------------------------------------------------- 5. deposit gates

    function test_deposit_ratio_gate() public view {
        (uint256 min1, uint256 max1) = IUniProxy(UNIPROXY).getDepositAmount(HYPERVISOR, WETH, 10 ether);
        console2.log("allowed token1 for 10 WETH: min/max", min1, max1);
        // skewed deposit: 10 WETH + 10 wstETH (ratio ~1.0 vs vault ratio ~7.45)
        (bool ok, bytes memory data) = _tryClearDeposit(10 ether, 10 ether);
        assertFalse(ok, "skewed deposit cleared");
        console2.log("skewed clearDeposit revert reason:", _reason(data));
        // matched deposit must be inside the allowed band
        (bool ok2, ) = _tryClearDeposit(10 ether, (min1 + max1) / 2);
        console2.log("matched-ratio clearDeposit passes gate (twap/range permitting):", ok2);
    }

    function test_direct_deposit_whitelist() public {
        _fund(100 ether, 20 ether);
        uint256[4] memory minIn;
        vm.expectRevert(bytes("WHE"));
        hyp.deposit(1 ether, 0.13 ether, address(this), address(this), minIn);
        console2.log("direct hypervisor.deposit blocked by whitelist");
    }

    function test_withdraw_requires_shares() public {
        uint256[4] memory minAmounts;
        vm.expectRevert();
        hyp.withdraw(1e18, address(this), address(this), minAmounts);
        console2.log("withdraw without shares reverts");
    }

    /// Push the price outside the base range -> deposits must be blocked.
    function test_deposit_blocked_after_price_push() public {
        _fund(200 ether, 130 ether);
        int24 bu = hyp.baseUpper();
        _pushPrice(false, bu + 300);
        int24 t = _tick();
        console2.log("tick after push", t);
        assertGt(t, bu, "price not pushed above base range");

        (uint256 min1, uint256 max1) = IUniProxy(UNIPROXY).getDepositAmount(HYPERVISOR, WETH, 5 ether);
        (bool ok, bytes memory data) = _tryClearDeposit(5 ether, (min1 + max1) / 2);
        assertFalse(ok, "deposit cleared after manipulation");
        console2.log("clearDeposit after push revert reason:", _reason(data));
        vm.expectRevert(bytes("Price change Overflow"));
        IClearing(CLEARING).checkPriceChange(HYPERVISOR, 43200, 10050);
        console2.log("deposit after manipulation blocked (range + twap gates)");
    }

    // ---------------------------------------------------------------- 6. quantitative withdraw manipulation
    // The attacker is a pre-existing share holder (e.g. protocol treasury / LP). Shares are granted
    // via `deal` on the fork — no deposit is needed, isolating the withdraw-side manipulation P&L.

    function _scenario(string memory label, int24 targetTick, bool pushDown, uint256 shareFracE18) internal {
        _fund(200 ether, 130 ether);
        int24 tick0 = _tick();
        uint256 supply = hyp.totalSupply();
        uint256 shares = supply * shareFracE18 / 1e18;
        deal(address(hyp), address(this), shares);
        require(hyp.balanceOf(address(this)) == shares, "share deal failed");
        uint256 v0 = _valueInToken1(address(this)) + FullMath.mulDiv(_vaultValueInToken1(), shares, supply);
        console2.log(string.concat(label, ": shares"), shares);
        console2.log("  vault value (token1 units)", _vaultValueInToken1());

        _pushPrice(pushDown, targetTick);
        console2.log("  tick after push", _tick());

        uint256[4] memory minAmounts;
        (uint256 a0, uint256 a1) = hyp.withdraw(shares, address(this), address(this), minAmounts);
        console2.log("  withdrawn token0", a0);
        console2.log("  withdrawn token1", a1);

        _restore(tick0);

        uint256 v1 = _valueInToken1(address(this));
        console2.log("  tick after restore", _tick());
        console2.log("  value start (token1 units)", v0);
        console2.log("  value end   (token1 units)", v1);
        console2.log("  PnL (token1 units)", int256(v1) - int256(v0));
    }

    function _restore(int24 tick0) internal {
        int24 t = _tick();
        if (t > tick0) {
            uint256 bal = IERC20(WETH).balanceOf(address(this));
            _swapExactIn(true, bal, tick0);
        } else if (t < tick0) {
            uint256 bal = IERC20(WSTETH).balanceOf(address(this));
            _swapExactIn(false, bal, tick0);
        }
    }

    function test_manip_push_to_base_top() public {
        _scenario("push to base top", hyp.baseUpper(), false, 0.5e18);
    }

    function test_manip_push_far() public {
        _scenario("push far up", hyp.baseUpper() + 150, false, 0.5e18);
    }

    function test_manip_push_down() public {
        _scenario("push down", hyp.baseLower() - 7, true, 0.5e18);
    }

    // ---------------------------------------------------------------- 7. V3Fees

    function test_v3fees_permissionless_collect() public {
        IV3Fees v = IV3Fees(V3FEES);
        address alg = v.algebra();
        address tre = v.treasury();
        uint256 balBefore = IERC20(USDC_E).balanceOf(V3FEES);
        console2.log("V3Fees USDC.e", balBefore);
        v.collectFees(); // permissionless
        uint256 mine = IERC20(USDC_E).balanceOf(address(this));
        assertEq(mine, 0, "attacker gained");
        console2.log("collectFees triggered; attacker gained 0; recipients:", alg, tre);
    }
}
