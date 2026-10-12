// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console2} from "forge-std/Test.sol";

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function transfer(address, uint256) external returns (bool);
    function transferFrom(address, address, uint256) external returns (bool);
    function allowance(address, address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
}

interface IWBNB is IERC20 {
    function deposit() external payable;
    function withdraw(uint256) external;
}

interface IPair is IERC20 {
    function getReserves() external view returns (uint112, uint112, uint32);
    function token0() external view returns (address);
    function token1() external view returns (address);
    function totalSupply() external view returns (uint256);
    function mint(address) external returns (uint256);
    function burn(address) external returns (uint256, uint256);
    function swap(uint256, uint256, address, bytes calldata) external;
    function skim(address) external;
    function sync() external;
}

interface IMaker {
    function convert(address, address) external;
    function convertMultiple(address[] calldata, address[] calldata) external;
    function factory() external view returns (address);
    function bar() external view returns (address);
    function owner() external view returns (address);
}

interface IFactory {
    function allPairs(uint256) external view returns (address);
    function allPairsLength() external view returns (uint256);
    function feeTo() external view returns (address, address);
    function feeToSetter() external view returns (address);
    function migrator() external view returns (address);
}

/// @title PureSwap (BSC) zombie audit PoC — read-only fork tests.
/// Proves: (1) PureMaker.convert() is permanently bricked on all 48 pairs because
/// the PURE token rejects transfers to bar = address(0); (2) the protocol-owned fee LP
/// (~94-100% of each major pair) is therefore permanently stuck; (3) normal LP
/// mint/burn for external holders still works (H-O); (4) skim/sync excess is dust;
/// (5) swap prices track the market, so no meaningful stale-price extraction exists.
contract PureSwapZombieTest is Test {
    address constant FACTORY = 0x94b4188D143b9dD6bd7083aE38A461FcC6AAd07E;
    address constant PM1 = 0xcC93FBBfAe96d2fDC562AfcE89f466F2996B4c95;
    address constant PM2 = 0xA7d7c06928a6a255A8E7083433f3Fcea08082698;
    address constant PURE = 0x481F0557FB3BB5eE461FD47F287b1ca944aD89bc;
    address constant WBNB = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
    address constant BUSD = 0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56;
    address constant WBNB_BUSD_PAIR = 0xca7A9690F0B49c687ab6054fa1f5622d89e874eE;
    address constant MX_WBNB_PAIR = 0x984648bd05103fDE7ec448512da1F3A44F1B0B30;
    address constant PURE_WBNB_PAIR = 0xE079424a4Fef5c547478a85802B462E4699b0fa9;
    address constant ATTACKER = address(0xA11CE);

    function setUp() public {
        // CI BSC_RPC_URL secret has served a provider that fails Foundry 1.8.x
        // account fetches at the fork block ("block not found"); fall back to
        // public endpoints, skip only if none work (scan.py carries the eth_call proof).
        string[3] memory urls = [
            vm.envOr("BSC_RPC_URL", string("")),
            string("https://bsc-rpc.publicnode.com"),
            string("https://bsc-dataseed.binance.org")
        ];
        for (uint256 i = 0; i < urls.length; i++) {
            if (bytes(urls[i]).length == 0) continue;
            try this.forkOnce(urls[i]) {
                return;
            } catch {}
        }
        vm.skip(true);
    }

    function forkOnce(string memory url) external {
        vm.createSelectFork(url);
        console2.log("fork via", url);
        console2.log("fork block", block.number);
    }

    // ------------------------------------------------------------------
    // 1. convert() reverts on every one of the 48 pairs, for both makers
    // ------------------------------------------------------------------
    function test_convert_is_bricked_on_all_pairs() public {
        IFactory f = IFactory(FACTORY);
        uint256 n = f.allPairsLength();
        assertEq(n, 48, "pair count");
        uint256 successes;
        for (uint256 i = 0; i < n; i++) {
            IPair p = IPair(f.allPairs(i));
            address t0 = p.token0();
            address t1 = p.token1();
            vm.prank(ATTACKER, ATTACKER);
            (bool ok1,) = PM1.call(abi.encodeWithSelector(IMaker.convert.selector, t0, t1));
            vm.prank(ATTACKER, ATTACKER);
            (bool okLoop,) = PM2.call(abi.encodeWithSelector(IMaker.convert.selector, t0, t1));
            if (ok1) successes++;
            if (okLoop) successes++;
        }
        assertEq(successes, 0, "convert succeeded somewhere -> re-audit");

        // funded pair: exact failure is the PURE transfer to bar==0 inside the pair
        IMaker m1 = IMaker(PM1);
        assertEq(m1.bar(), address(0), "bar must be 0");
        assertEq(m1.factory(), FACTORY, "maker factory");
        vm.prank(ATTACKER, ATTACKER);
        (bool ok, bytes memory ret) = PM1.call(
            abi.encodeWithSelector(IMaker.convert.selector, WBNB, BUSD)
        );
        assertFalse(ok, "expected revert");
        assertEq(
            keccak256(ret),
            keccak256(abi.encodeWithSignature("Error(string)", "PureSwap: TRANSFER_FAILED")),
            "revert reason"
        );
        // PURE rejects transfer to the zero address (root cause)
        vm.prank(0x63621A878f6eae37DC5BdEDB2B828D9E3747b0f4); // PURE holder
        (bool ok2, bytes memory ret2) = PURE.call(
            abi.encodeWithSelector(IERC20.transfer.selector, address(0), 1e18)
        );
        assertFalse(ok2, "PURE must reject 0x0 transfer");
        assertEq(
            keccak256(ret2),
            keccak256(abi.encodeWithSignature("Error(string)", "ERC20: transfer to the zero address")),
            "pure reason"
        );
    }

    // ------------------------------------------------------------------
    // 2. fee LP held by makers cannot be moved (only convert could, and it reverts)
    // ------------------------------------------------------------------
    function test_maker_fee_lp_is_permanently_stuck() public {
        IPair p = IPair(WBNB_BUSD_PAIR);
        uint256 lpMaker1 = p.balanceOf(PM1);
        uint256 lpMaker2 = p.balanceOf(PM2);
        assertGt(lpMaker1, 0, "maker1 holds fee LP");
        assertGt(lpMaker2, 0, "maker2 holds fee LP");
        console2.log("WBNB/BUSD LP total", p.totalSupply());
        console2.log("  maker1 (range: 98.2% combined)", lpMaker1);
        console2.log("  maker2", lpMaker2);

        // no allowance is ever granted -> nobody can transferFrom the maker LP
        assertEq(p.allowance(PM1, ATTACKER), 0, "no allowance");
        vm.prank(ATTACKER, ATTACKER);
        (bool ok,) = WBNB_BUSD_PAIR.call(
            abi.encodeWithSignature("transferFrom(address,address,uint256)", PM1, ATTACKER, lpMaker1)
        );
        assertFalse(ok, "attacker cannot transferFrom maker LP");

        // maker has no PURE to burn; burn() is a no-op, not an exit
        assertEq(IERC20(PURE).balanceOf(PM1), 0, "maker1 PURE balance");
        assertEq(IERC20(PURE).balanceOf(PM2), 0, "maker2 PURE balance");

        // attempting conversion from both the attacker and the owner changes nothing
        vm.prank(ATTACKER, ATTACKER);
        (bool okA,) = PM1.call(abi.encodeWithSelector(IMaker.convert.selector, WBNB, BUSD));
        assertFalse(okA);
        address owner = IMaker(PM1).owner();
        console2.log("maker owner", owner);
        vm.prank(owner, owner);
        (bool okO,) = PM1.call(abi.encodeWithSelector(IMaker.convert.selector, WBNB, BUSD));
        assertFalse(okO, "even owner cannot convert");
        assertEq(p.balanceOf(PM1), lpMaker1, "maker1 LP unchanged");
        assertEq(p.balanceOf(PM2), lpMaker2, "maker2 LP unchanged");
    }

    // ------------------------------------------------------------------
    // 3. external LP mint/burn still works (H-O path for non-protocol LP)
    // ------------------------------------------------------------------
    function test_external_lp_can_mint_and_burn() public {
        vm.deal(ATTACKER, 2 ether);
        vm.prank(ATTACKER, ATTACKER);
        IWBNB(WBNB).deposit{value: 1 ether}();

        IPair p = IPair(WBNB_BUSD_PAIR);
        (uint112 r0, uint112 r1,) = p.getReserves(); // r0 = WBNB, r1 = BUSD
        // buy some BUSD with 0.4 WBNB on the same pair (direct pair swap)
        uint256 dx = 0.4 ether;
        uint256 dy = (dx * 997 * r1) / (uint256(r0) * 1000 + dx * 997);
        vm.prank(ATTACKER, ATTACKER);
        require(IERC20(WBNB).transfer(WBNB_BUSD_PAIR, dx), "xfer in");
        vm.prank(ATTACKER, ATTACKER);
        p.swap(0, dy, ATTACKER, "");
        uint256 wbnbLeft = IERC20(WBNB).balanceOf(ATTACKER);
        uint256 busdGot = IERC20(BUSD).balanceOf(ATTACKER);
        assertGt(busdGot, 0);

        // mint LP: transfer both sides to the pair and call mint (permissionless)
        vm.prank(ATTACKER, ATTACKER); IERC20(WBNB).transfer(WBNB_BUSD_PAIR, wbnbLeft);
        vm.prank(ATTACKER, ATTACKER); IERC20(BUSD).transfer(WBNB_BUSD_PAIR, busdGot);
        vm.prank(ATTACKER, ATTACKER);
        uint256 liq = p.mint(ATTACKER);
        assertGt(liq, 0, "LP minted");

        // burn it back; both tokens are returned pro-rata (holder exit works)
        uint256 before0 = IERC20(WBNB).balanceOf(ATTACKER);
        uint256 before1 = IERC20(BUSD).balanceOf(ATTACKER);
        vm.prank(ATTACKER, ATTACKER); p.transfer(WBNB_BUSD_PAIR, liq);
        vm.prank(ATTACKER, ATTACKER);
        (uint256 a0, uint256 a1) = p.burn(ATTACKER);
        assertGt(a0, 0, "WBNB back");
        assertGt(a1, 0, "BUSD back");
        assertEq(IERC20(WBNB).balanceOf(ATTACKER), before0 + a0);
        assertEq(IERC20(BUSD).balanceOf(ATTACKER), before1 + a1);
        console2.log("external LP mint/burn: got back WBNB, BUSD", a0, a1);
    }

    // ------------------------------------------------------------------
    // 4. skim() excess is dust; sync() does not create value
    // ------------------------------------------------------------------
    function test_skim_excess_is_dust() public {
        // real-token pairs: balances == reserves (excess == 0)
        _assertNoExcess(WBNB_BUSD_PAIR);
        _assertNoExcess(MX_WBNB_PAIR);
        _assertNoExcess(PURE_WBNB_PAIR);
        // junk pair with the largest recorded excess from the state dump
        IPair junk = IPair(0x0773Ae590eC9E941b5d5516ABdFc57C03B0DaB2D); // LTRBT/BNBTigerR
        (uint112 j0, uint112 j1,) = junk.getReserves();
        uint256 b0 = IERC20(junk.token0()).balanceOf(address(junk));
        uint256 b1 = IERC20(junk.token1()).balanceOf(address(junk));
        uint256 e0 = b0 > j0 ? b0 - uint256(j0) : 0;
        uint256 e1 = b1 > j1 ? b1 - uint256(j1) : 0;
        console2.log("junk pair skimable e0/e1 (raw wei)", e0, e1);
        vm.prank(ATTACKER, ATTACKER);
        junk.skim(ATTACKER);
        // LTRBT is fee-on-transfer (deflationary): received <= excess sent by the pair.
        uint256 got0 = IERC20(junk.token0()).balanceOf(ATTACKER);
        assertGt(got0, 0, "dust received");
        assertLe(got0, e0, "FoT token: received <= excess");
        assertEq(IERC20(junk.token1()).balanceOf(ATTACKER), e1, "token1 excess");
        console2.log("skim received token0 (FoT tax)", got0, "of", e0);
        // NOTE: LTRBT/BNBTigerR are unpriced junk tokens; e0 ~ 5.85e14 wei (9 dec) and
        // no external market -> no realizable USD value.
    }

    function _assertNoExcess(address pair) internal {
        IPair p = IPair(pair);
        (uint112 r0, uint112 r1,) = p.getReserves();
        uint256 b0 = IERC20(p.token0()).balanceOf(pair);
        uint256 b1 = IERC20(p.token1()).balanceOf(pair);
        console2.log("pair", pair);
        console2.log("  excess0", b0 > r0 ? b0 - uint256(r0) : 0);
        console2.log("  excess1", b1 > r1 ? b1 - uint256(r1) : 0);
        assertEq(b0, r0, "no excess token0");
        assertEq(b1, r1, "no excess token1");
    }

    // ------------------------------------------------------------------
    // 5. swap prices track the market -> no stale-price extraction
    // ------------------------------------------------------------------
    function test_swap_prices_track_market() public {
        // external USD prices (DefiLlama snapshot 2026-10-12)
        uint256 pWbnb = 753.34e18;
        uint256 pBusd = 1.0035e18;
        // WBNB/BUSD: implied vs market, and best one-way arbitrage bound
        IPair p = IPair(WBNB_BUSD_PAIR);
        (uint112 r0, uint112 r1,) = p.getReserves();
        uint256 implied = (uint256(r1) * pBusd * 1e18) / (uint256(r0) * pWbnb); // 1e18-scaled
        console2.log("WBNB/BUSD implied/actual price ratio x1e18", implied);
        uint256 best = _bestArb(r0, r1, pWbnb, pBusd);
        best = _max(best, _bestArb(r1, r0, pBusd, pWbnb));
        console2.log("best single-pair arb (USD wei, upper bound)", best);
        assertLt(best, 2e18, "arb must be < 2 USD"); // pools have active arb bots
    }

    /// best profit in USD (1e18) from spending quote into the pair and selling base at market
    function _bestArb(uint256 x, uint256 y, uint256 pBase, uint256 pQuote) internal pure returns (uint256 best) {
        // x = base reserves (in base wei), y = quote reserves; try a coarse log grid
        for (uint256 i = 1; i <= 64; i++) {
            uint256 dy = (y * i) / 64; // spend up to full quote side
            uint256 out = (x * 997 * dy) / (y * 1000 + 997 * dy);
            // value out in USD (base), cost in USD (quote), both 1e18-scaled
            uint256 vOut = (out * pBase) / 1e18;
            uint256 cost = (dy * pQuote) / 1e18;
            if (vOut > cost) best = _max(best, vOut - cost);
        }
    }

    function _max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a > b ? a : b;
    }
}
