// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/Test.sol";

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
    function decimals() external view returns (uint8);
    function totalSupply() external view returns (uint256);
}

interface IIronSwap {
    function getTokens() external view returns (address[] memory);
    function getTokenBalances() external view returns (uint256[] memory);
    function getAdminBalances() external view returns (uint256[] memory);
    function getLpToken() external view returns (address);
    function getVirtualPrice() external view returns (uint256);
    function paused() external view returns (bool);
    function owner() external view returns (address);
    function initialize(
        address[] memory, uint8[] memory, string memory, string memory,
        uint256, uint256, uint256, uint256, address
    ) external;
    function swap(uint8, uint8, uint256, uint256, uint256) external returns (uint256);
    function calculateSwap(uint8, uint8, uint256) external view returns (uint256);
    function addLiquidity(uint256[] memory, uint256, uint256) external returns (uint256);
    function removeLiquidity(uint256, uint256[] memory, uint256) external returns (uint256[] memory);
    function calculateRemoveLiquidity(address, uint256) external view returns (uint256[] memory);
    function removeLiquidityImbalance(uint256[] memory, uint256, uint256) external returns (uint256);
    function updateUserWithdrawFee(address, uint256) external;
    function withdrawAdminFee() external;
    function pause() external;
    function unpause() external;
    function setFee(uint256, uint256, uint256) external;
    function rampA(uint256, uint256) external;
    function stopRampA() external;
    function setFeeController(address) external;
    function setFeeDistributor(address) external;
    function transferOwnership(address) external;
    function renounceOwnership() external;
}

interface IIronChef {
    function deposit(uint256, uint256, address) external;
    function withdraw(uint256, uint256, address) external;
    function emergencyWithdraw(uint256, address) external;
    function userInfo(uint256, address) external view returns (uint256, int256);
    function poolLength() external view returns (uint256);
}

contract IronFinanceTest is Test {
    // ---- Polygon addresses (chain 137) ----
    address constant POOL   = 0x837503e8A8753ae17fB8C8151B8e6f586defCb57; // IronSwap IS3USD
    address constant LP     = 0xb4d09ff3dA7f9e9A2BA029cb0A81A989fd7B8f17; // IS3USD LP
    address constant USDC   = 0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174;
    address constant USDT   = 0xc2132D05D31c914a87C6611C10748AEb04B58e8F;
    address constant DAI    = 0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063;
    address constant CHEF   = 0x1fD1259Fa8CdC60c6E8C86cfA592CA1b8403DFaD; // IronChef
    address constant ISPUSD = 0x4A783cD1b4543559eCe45dB47e07E0Cb59e55c09;
    address constant ISXUSD = 0xe440CCc13e6f273c110Cf3cF4087C23a66B8e872;
    address constant ISIRON = 0xCaEb732167aF742032D13A9e76881026f91Cd087;
    address constant PUSD   = 0x9aF3b7DC29D3C4B1A5731408B6A9656fA7aC3b72;
    address constant XUSD   = 0x3A3e7650f8B9f667dA98F236010fBf44Ee4B2975;
    address constant IRON   = 0xD86b5923F3AD7b585eD81B448170ae026c65ae9a;
    address constant POOL_OWNER = 0xCe7C13ea272Ab43b3107A3192B779Ca71E510f35;
    address constant FEE_CTRL   = 0x66C8096Fa2F5fD21062a27C202a330e64E0ae2fc;

    // ---- market prices used for extraction tests (documented in analysis/) ----
    // GeckoTerminal, 2026-10-12: xUSD/USDC mid 1.0514 (DMM pool w/ 116.3k USDC);
    // IRON/USDC 0.00007380; PUSD/USDC 0.13167. LP NAV = virtual price 1.0108.
    uint256 constant XUSD_ASK  = 1.0514e18;
    uint256 constant IRON_MKT  = 0.00007380e18;
    uint256 constant PUSD_MKT  = 0.13167e18;

    address attacker;
    address mallory;

    /// RPC choice written by ci/run.sh probe ("ENV" or a keyless public URL).
    function _pickRpc(string memory file, string memory envName, string memory publicFallback)
        internal view returns (string memory)
    {
        string memory v = vm.readFile(file); // files always exist (committed; CI overwrites)
        if (keccak256(bytes(v)) == keccak256(bytes("ENV"))) {
            return vm.envOr(envName, publicFallback);
        }
        return v;
    }

    function setUp() public {
        string memory rpc = _pickRpc("rpc-polygon.txt", "POLYGON_RPC_URL",
            "https://polygon-bor-rpc.publicnode.com");
        if (!_tryPolyFork(rpc)) {
            if (!_tryPolyFork("https://polygon-bor-rpc.publicnode.com")) {
                if (!_tryPolyFork("https://polygon-rpc.com")) {
                    vm.createSelectFork("https://rpc.ankr.com/polygon");
                }
            }
        }
        attacker = makeAddr("attacker");
        mallory = makeAddr("mallory");
        emit log_named_uint("POLYGON FORK BLOCK", block.number);
    }

    function _tryPolyFork(string memory url) internal returns (bool ok) {
        try vm.createSelectFork(url) {
            ok = block.number > 1;
        } catch {
            ok = false;
        }
    }

    function _tryFork(string memory url) internal returns (uint256 id) {
        try vm.createFork(url) returns (uint256 fid) {
            id = fid;
        } catch {
            id = 0;
        }
    }

    // ---------------------------------------------------------------- helpers
    function _microUSD(address who) internal view returns (uint256) {
        return IERC20(USDC).balanceOf(who)
             + IERC20(USDT).balanceOf(who)
             + IERC20(DAI).balanceOf(who) / 1e12;
    }

    function _tokens() internal view returns (address[] memory) {
        return IIronSwap(POOL).getTokens();
    }

    // Foundry's deal() locates the balance slot automatically for standard ERC20s.
    function _give(address token, address to, uint256 amt) internal {
        deal(token, to, amt);
        require(IERC20(token).balanceOf(to) >= amt, "deal failed");
    }

    // ---------------------------------------------------------------- 01 state
    function test_01_live_state() public {
        address[] memory t = _tokens();
        assertEq(t.length, 3, "3 coins");
        assertEq(t[0], USDC, "coin0 USDC.e");
        assertEq(t[1], USDT, "coin1 USDT");
        assertEq(t[2], DAI,  "coin2 DAI");
        IIronSwap p = IIronSwap(POOL);
        assertFalse(p.paused(), "pool live");
        assertEq(p.owner(), POOL_OWNER, "owner");
        assertEq(p.getLpToken(), LP, "lp token");
        uint256 supply = IERC20(LP).totalSupply();
        assertGt(supply, 300_000e18, "LP supply large");
        assertLt(supply, 325_000e18, "LP supply sane");
        uint256 vp = p.getVirtualPrice();
        assertGt(vp, 1.0e18, "vp > 1");
        assertLt(vp, 1.03e18, "vp sane");
        uint256[] memory bals = p.getTokenBalances();
        assertGt(bals[0], 60_000e6, "USDC.e balance");
        assertGt(bals[1], 150_000e6, "USDT balance");
        assertGt(bals[2], 60_000e18, "DAI balance");
        uint256[] memory admin = p.getAdminBalances();
        assertGt(admin[0] + admin[1] + admin[2] / 1e12, 200e6, "admin fees > $200");
        emit log_named_uint("lp_supply", supply);
        emit log_named_uint("virtual_price", vp);
        emit log_named_uint("pool_usdc", bals[0]);
        emit log_named_uint("pool_usdt", bals[1]);
        emit log_named_uint("pool_dai", bals[2]);
        emit log_named_uint("admin_usdc", admin[0]);
        emit log_named_uint("admin_usdt", admin[1]);
        emit log_named_uint("admin_dai", admin[2]);
    }

    // ------------------------------------------------- 02 swap round-trip loses
    function test_02_swap_roundtrip_loses() public {
        _give(USDC, attacker, 10_000e6);
        uint256 start = IERC20(USDC).balanceOf(attacker);
        vm.startPrank(attacker);
        IERC20(USDC).approve(POOL, type(uint256).max);
        uint256 usdtOut = IIronSwap(POOL).swap(0, 1, 10_000e6, 0, block.timestamp + 600);
        IERC20(USDT).approve(POOL, type(uint256).max);
        uint256 usdcBack = IIronSwap(POOL).swap(1, 0, usdtOut, 0, block.timestamp + 600);
        vm.stopPrank();
        emit log_named_uint("usdc_in", 10_000e6);
        emit log_named_uint("usdt_mid", usdtOut);
        emit log_named_uint("usdc_back", usdcBack);
        assertLt(IERC20(USDC).balanceOf(attacker), start, "must lose on round trip");
        assertLt(usdcBack, 10_000e6, "no free money via swap");
    }

    // ------------------------------------- 03 add + remove liquidity round-trip
    function test_03_add_remove_roundtrip_loses() public {
        _give(USDC, attacker, 2_000e6);
        _give(USDT, attacker, 2_000e6);
        _give(DAI,  attacker, 2_000e18);
        uint256 before = _microUSD(attacker);
        vm.startPrank(attacker);
        uint256[] memory amounts = new uint256[](3);
        amounts[0] = 1_000e6; amounts[1] = 1_000e6; amounts[2] = 1_000e18;
        IERC20(USDC).approve(POOL, type(uint256).max);
        IERC20(USDT).approve(POOL, type(uint256).max);
        IERC20(DAI).approve(POOL, type(uint256).max);
        uint256 lpOut = IIronSwap(POOL).addLiquidity(amounts, 0, block.timestamp + 600);
        IERC20(LP).approve(POOL, type(uint256).max); // burnFrom needs an allowance
        uint256[] memory mins = new uint256[](3);
        IIronSwap(POOL).removeLiquidity(lpOut, mins, block.timestamp + 600);
        vm.stopPrank();
        uint256 afterBal = _microUSD(attacker);
        emit log_named_uint("before_microUSD", before);
        emit log_named_uint("lp_minted", lpOut);
        emit log_named_uint("after_microUSD", afterBal);
        assertLt(afterBal, before, "round trip must lose (fees + withdraw fee)");
    }

    // --------------------- 04 proportional remove = holder path (works, even paused)
    function test_04_removeLiquidity_works_for_holder() public {
        _give(USDC, attacker, 2_000e6);
        _give(USDT, attacker, 2_000e6);
        _give(DAI,  attacker, 2_000e18);
        vm.startPrank(attacker);
        uint256[] memory amounts = new uint256[](3);
        amounts[0] = 1_000e6; amounts[1] = 1_000e6; amounts[2] = 1_000e18;
        IERC20(USDC).approve(POOL, type(uint256).max);
        IERC20(USDT).approve(POOL, type(uint256).max);
        IERC20(DAI).approve(POOL, type(uint256).max);
        uint256 lpOut = IIronSwap(POOL).addLiquidity(amounts, 0, block.timestamp + 600);
        IERC20(LP).approve(POOL, type(uint256).max); // burnFrom needs an allowance
        vm.stopPrank();
        // owner pauses the pool on the fork; proportional remove must still work
        vm.prank(POOL_OWNER);
        IIronSwap(POOL).pause();
        assertTrue(IIronSwap(POOL).paused(), "paused");
        uint256[] memory mins = new uint256[](3);
        vm.prank(attacker);
        uint256[] memory out = IIronSwap(POOL).removeLiquidity(lpOut, mins, block.timestamp + 600);
        vm.prank(POOL_OWNER);
        IIronSwap(POOL).unpause();
        assertGt(out[0], 0, "usdc out > 0");
        assertGt(out[1], 0, "usdt out > 0");
        assertGt(out[2], 0, "dai out > 0");
        uint256 totalOut = out[0] + out[1] + out[2] / 1e12; // micro-USD
        assertLt(totalOut, 3_000e6, "proportional exit loses a little");
        assertGt(totalOut, 2_950e6, "proportional exit near NAV");
        emit log_named_uint("total_out_microUSD", totalOut);
        emit log_named_uint("lp_burned", lpOut);
        emit log_named_uint("out_usdc", out[0]);
        emit log_named_uint("out_usdt", out[1]);
        emit log_named_uint("out_dai", out[2]);
    }

    // ------------------------------- 05 removeLiquidityImbalance is bricked (1e10x)
    function test_05_removeLiquidityImbalance_bricked() public {
        _give(USDC, attacker, 2_000e6);
        _give(USDT, attacker, 2_000e6);
        _give(DAI,  attacker, 2_000e18);
        vm.startPrank(attacker);
        uint256[] memory amounts = new uint256[](3);
        amounts[0] = 1_000e6; amounts[1] = 1_000e6; amounts[2] = 1_000e18;
        IERC20(USDC).approve(POOL, type(uint256).max);
        IERC20(USDT).approve(POOL, type(uint256).max);
        IERC20(DAI).approve(POOL, type(uint256).max);
        uint256 lpOut = IIronSwap(POOL).addLiquidity(amounts, 0, block.timestamp + 600);
        IERC20(LP).approve(POOL, type(uint256).max); // allowance present so the revert can only be the burn amount
        vm.stopPrank();
        // A $3 removal: fair burn ~3e18 LP; deployed code multiplies by
        // (FEE_DENOMINATOR - fee) = ~1e10 WITHOUT dividing by 1e10
        // => burnAmount ~3e28 > the attacker's entire balance => revert.
        uint256[] memory out = new uint256[](3);
        out[0] = 1e6; out[1] = 1e6; out[2] = 1e18; // $3 total
        vm.prank(attacker);
        vm.expectRevert(bytes("ERC20: burn amount exceeds balance"));
        IIronSwap(POOL).removeLiquidityImbalance(out, type(uint256).max, block.timestamp + 600);
        emit log_named_uint("holder_lp_balance", lpOut);
        emit log("removeLiquidityImbalance reverted (burn 1e10x too large) for a $3 withdrawal");
        // dust-only: ~1011x wei of DAI (1e-15 USD) is the largest that survives
        uint256[] memory dust = new uint256[](3);
        dust[2] = 2000; // wei of DAI (~2e-15 USD)
        vm.prank(attacker);
        uint256 burned = IIronSwap(POOL).removeLiquidityImbalance(dust, 1e18, block.timestamp + 600);
        emit log_named_uint("dust_burn_wei", burned);
        assertLt(burned, 1e16, "dust-scale burn only (1e10x multiplier still visible)");
    }

    // ----------------------------------------------- 06 admin/init paths gated
    function test_06_admin_paths_gated() public {
        vm.startPrank(attacker);
        vm.expectRevert(); IIronSwap(POOL).pause();
        vm.expectRevert(); IIronSwap(POOL).setFee(1e6, 1e10, 5e6);
        vm.expectRevert(); IIronSwap(POOL).rampA(2000, block.timestamp + 2 days);
        vm.expectRevert(); IIronSwap(POOL).stopRampA();
        vm.expectRevert(); IIronSwap(POOL).setFeeController(attacker);
        vm.expectRevert(); IIronSwap(POOL).setFeeDistributor(attacker);
        vm.expectRevert(); IIronSwap(POOL).withdrawAdminFee();
        vm.expectRevert(); IIronSwap(POOL).transferOwnership(attacker);
        vm.expectRevert(); IIronSwap(POOL).renounceOwnership();
        vm.expectRevert(); IIronSwap(POOL).updateUserWithdrawFee(attacker, 1);
        address[] memory coins = new address[](3);
        coins[0] = USDC; coins[1] = USDT; coins[2] = DAI;
        uint8[] memory decs = new uint8[](3);
        decs[0] = 6; decs[1] = 6; decs[2] = 18;
        vm.expectRevert();
        IIronSwap(POOL).initialize(coins, decs, "x", "x", 100, 1e6, 1e10, 5e6, attacker);
        vm.stopPrank();
        emit log("all admin/init/re-init paths revert for unprivileged caller");
    }

    // --------------------------------------- 07 IronChef: stakes are holder-only
    function test_07_ironchef_stakes_holder_only() public {
        _give(USDC, attacker, 2_000e6);
        _give(USDT, attacker, 2_000e6);
        _give(DAI,  attacker, 2_000e18);
        vm.startPrank(attacker);
        uint256[] memory amounts = new uint256[](3);
        amounts[0] = 1_000e6; amounts[1] = 1_000e6; amounts[2] = 1_000e18;
        IERC20(USDC).approve(POOL, type(uint256).max);
        IERC20(USDT).approve(POOL, type(uint256).max);
        IERC20(DAI).approve(POOL, type(uint256).max);
        uint256 lpOut = IIronSwap(POOL).addLiquidity(amounts, 0, block.timestamp + 600);
        IERC20(LP).approve(CHEF, type(uint256).max);
        IIronChef(CHEF).deposit(0, lpOut, attacker);
        vm.stopPrank();
        (uint256 staked, ) = IIronChef(CHEF).userInfo(0, attacker);
        assertEq(staked, lpOut, "attacker stake recorded");
        uint256 chefLPBefore = IERC20(LP).balanceOf(CHEF);

        // mallory cannot withdraw attacker's stake
        vm.prank(mallory);
        vm.expectRevert();
        IIronChef(CHEF).withdraw(0, 1, mallory);
        // emergencyWithdraw with zero stake moves nothing
        vm.prank(mallory);
        IIronChef(CHEF).emergencyWithdraw(0, mallory);
        assertEq(IERC20(LP).balanceOf(CHEF), chefLPBefore, "chef LP untouched by mallory");

        // attacker withdraws own stake
        vm.prank(attacker);
        IIronChef(CHEF).withdraw(0, lpOut, attacker);
        assertEq(IERC20(LP).balanceOf(attacker), lpOut, "own stake returned");
        emit log_named_uint("chef_lp_global", chefLPBefore);
        emit log("IronChef: only the staker can withdraw their LP; owner-only admin");
    }

    // ---------------------- 08 meta-pool dumps: negative at market prices (views)
    function test_08_meta_pool_extraction_negative_views() public {
        // isxusd: dumping xUSD buys IS3USD LP at ~1.01-1.04 per xUSD (< ask 1.0514)
        uint256 lpOutX = IIronSwap(ISXUSD).calculateSwap(1, 0, 200e18);
        uint256[] memory outX = IIronSwap(POOL).calculateRemoveLiquidity(attacker, lpOutX);
        uint256 valX = outX[0] + outX[1] + outX[2] / 1e12; // micro-USD
        uint256 costX = 200e6 * XUSD_ASK / 1e18;
        emit log_named_uint("isxusd_200xUSD_lpOut", lpOutX);
        emit log_named_uint("isxusd_value_microUSD", valX);
        emit log_named_uint("isxusd_cost_microUSD", costX);
        assertLt(valX, costX, "xUSD dump unprofitable at ask 1.0514");

        // isiron: 500k IRON -> LP value < cost at market
        uint256 lpOutI = IIronSwap(ISIRON).calculateSwap(1, 0, 500_000e18);
        uint256[] memory outI = IIronSwap(POOL).calculateRemoveLiquidity(attacker, lpOutI);
        uint256 valI = outI[0] + outI[1] + outI[2] / 1e12;
        uint256 costI = 500_000e6 * IRON_MKT / 1e18;
        emit log_named_uint("isiron_500kIRON_lpOut", lpOutI);
        emit log_named_uint("isiron_value_microUSD", valI);
        emit log_named_uint("isiron_cost_microUSD", costI);
        assertLt(valI, costI, "IRON dump unprofitable at 0.0000738");

        // ispusd: 500 PUSD -> LP value < cost at market 0.13167
        uint256 lpOutP = IIronSwap(ISPUSD).calculateSwap(1, 0, 500e18);
        uint256[] memory outP = IIronSwap(POOL).calculateRemoveLiquidity(attacker, lpOutP);
        uint256 valP = outP[0] + outP[1] + outP[2] / 1e12;
        uint256 costP = 500e6 * PUSD_MKT / 1e18;
        emit log_named_uint("ispusd_500PUSD_lpOut", lpOutP);
        emit log_named_uint("ispusd_value_microUSD", valP);
        emit log_named_uint("ispusd_cost_microUSD", costP);
        assertLt(valP, costP, "PUSD dump unprofitable at 0.13167");

        // reverse direction sanity: LP -> xUSD at par-or-worse
        uint256 xusdOut = IIronSwap(ISXUSD).calculateSwap(0, 1, 1e18);
        assertLe(xusdOut, 1.0e18, "LP->xUSD <= 1:1");
    }

    // ---------------------- 08b real end-to-end dump round trips (with tokens)
    function test_08b_meta_pool_real_roundtrips() public {
        // xUSD
        _give(XUSD, attacker, 200e18);
        vm.startPrank(attacker);
        IERC20(XUSD).approve(ISXUSD, type(uint256).max);
        uint256 lpOut = IIronSwap(ISXUSD).swap(1, 0, 200e18, 0, block.timestamp + 600);
        IERC20(LP).approve(POOL, type(uint256).max);
        uint256[] memory mins = new uint256[](3);
        IIronSwap(POOL).removeLiquidity(lpOut, mins, block.timestamp + 600);
        vm.stopPrank();
        uint256 val = _microUSD(attacker); // first leg: absolute == delta
        uint256 cost = 200e6 * XUSD_ASK / 1e18;
        emit log_named_uint("rt_xusd_value_microUSD", val);
        emit log_named_uint("rt_xusd_cost_microUSD", cost);
        assertLt(val, cost, "xUSD real round trip loses");

        // IRON
        uint256 balBeforeIron = _microUSD(attacker);
        _give(IRON, attacker, 500_000e18);
        vm.startPrank(attacker);
        IERC20(IRON).approve(ISIRON, type(uint256).max);
        uint256 lpOut2 = IIronSwap(ISIRON).swap(1, 0, 500_000e18, 0, block.timestamp + 600);
        IERC20(LP).approve(POOL, type(uint256).max);
        uint256[] memory mins2 = new uint256[](3);
        IIronSwap(POOL).removeLiquidity(lpOut2, mins2, block.timestamp + 600);
        vm.stopPrank();
        uint256 val2 = _microUSD(attacker) - balBeforeIron; // delta of this leg only
        uint256 cost2 = 500_000e6 * IRON_MKT / 1e18;
        emit log_named_uint("rt_iron_value_microUSD", val2);
        emit log_named_uint("rt_iron_cost_microUSD", cost2);
        assertLt(val2, cost2, "IRON real round trip loses");
    }

    // ------------------------- 09 lending markets: cash is dust (holders-only)
    function test_09_lending_markets_dust() public {
        // Polygon IronLend (Compound fork) markets
        address[8] memory mkts = [
            0x186C4137136970739b472A8192D3D2AFc5543B61, // rWETH
            0xbEbAD52f3A50806b25911051BabDe6615C8e21ef, // rUSDC
            0xCa0F37f73174a28a64552D426590d3eD601ecCa1, // rMATIC
            0xEe1eb5fEBeF78A1eb1a23E79930D9c587F954E05, // rWBTC
            0xad6AD29d6b8B74b4302dD829c945ca3274035c16, // rUSDT
            0xf535B089453dfd8AE698aF6d7d5Bc9f804781b81, // rICE
            0x09cA5d827712dD7b2570FD534305B663Ae788C17, // rIRON
            0x32dbCdaFA80f58FfE45C825cf1Bd04f5260FC596  // rDFYN
        ];
        uint256 iceCash;
        for (uint256 i = 0; i < mkts.length; i++) {
            (bool ok, bytes memory ret) = mkts[i].staticcall(abi.encodeWithSignature("getCash()"));
            if (ok && ret.length >= 32) {
                uint256 cash = abi.decode(ret, (uint256));
                emit log_named_uint("market_cash", cash);
                if (i == 5) iceCash = cash;
            }
        }
        // rICE holds 12.3M ICE (worth ~$24 at GT price $1.9e-6); others dust
        assertGt(iceCash, 10_000_000e18, "rICE cash present");
        assertLt(iceCash, 50_000_000e18, "rICE cash < 50M ICE");
    }

    // --------------------------------------------- 10 cross-chain (Fantom, Avax)
    function test_10_crosschain_readonly() public {
        // Fantom
        string memory frpc = _pickRpc("rpc-fantom.txt", "FANTOM_RPC_URL",
            "https://rpcapi.fantom.network");
        uint256 fid = _tryFork(frpc);
        if (fid == 0) fid = _tryFork("https://rpcapi.fantom.network");
        if (fid == 0) fid = _tryFork("https://fantom.drpc.org");
        vm.selectFork(fid);
        address fPool = 0x952BDA8A83c3D5F398a686bb4e8C6DD90072d523;
        assertFalse(IIronSwap(fPool).paused(), "fantom pool live");
        uint256[] memory fb = IIronSwap(fPool).getTokenBalances();
        assertGt(fb[0], 5e6, "fantom usdc");
        assertGt(fb[1], 10e6, "fantom usdt");
        assertGt(fb[2], 100e18, "fantom dai");
        emit log_named_uint("fantom_block", block.number);
        emit log_named_uint("fantom_usdc", fb[0]);
        emit log_named_uint("fantom_usdt", fb[1]);
        emit log_named_uint("fantom_dai", fb[2]);
        address fCtl = 0xDc4C597E36Fc80876801df0309Cc11A7C12E0764;
        (bool ok, bytes memory ret) = fCtl.staticcall(abi.encodeWithSignature("getAllMarkets()"));
        assertTrue(ok, "fantom controller markets readable");

        // Avalanche (public fallback; no AVAX_RPC_URL in CI env)
        string memory arpc = vm.envOr("AVAX_RPC_URL", string("https://avalanche-c-chain-rpc.publicnode.com"));
        uint256 aid = vm.createFork(arpc);
        vm.selectFork(aid);
        address aPool = 0x952BDA8A83c3D5F398a686bb4e8C6DD90072d523;
        assertFalse(IIronSwap(aPool).paused(), "avax pool live");
        uint256[] memory ab = IIronSwap(aPool).getTokenBalances();
        emit log_named_uint("avax_block", block.number);
        emit log_named_uint("avax_usdce", ab[0]);
        emit log_named_uint("avax_usdte", ab[1]);
        emit log_named_uint("avax_daie", ab[2]);
        assertLt(ab[0], 100e6, "avax pool < $100 (dust)");
        assertGt(ab[2], 1e18, "avax dai present");
    }
}
