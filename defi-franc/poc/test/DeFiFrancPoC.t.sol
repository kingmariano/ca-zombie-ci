// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/Test.sol";
import {IERC20Like, ITroveManager, ITroveManagerHelpers, IStabilityPoolLike, ICollSurplusPoolLike,
        IBorrowerOpsLike, IHintHelpersLike, IPriceFeedLike, IMONStakingLike, IUniswapV3PoolLike,
        IQuoterV2Like, IAggregatorLike} from "../src/Interfaces.sol";

/// @title DeFi Franc (DCHF) — live unprivileged-extraction audit PoC
/// @notice Read-only fork tests. No mainnet transactions. Everything runs on a local anvil fork
///         taken from a public RPC via `vm.createSelectFork`.
contract DeFiFrancPoC is Test {
    // --- deployment (Ethereum mainnet, Oct 2026) ---
    address constant ETH_SP     = 0x6a9f9d6F5D672a9784c5E560a9648de6cbe2c548;
    address constant WBTC_SP    = 0x04556d845f12Ff7D8Ff04a37F40387Dd1B454c4b;
    address constant TROVE_MGR  = 0x99838142189adE67c1951f9c57c3333281334F7F;
    address constant TM_HELPERS = 0xaAACB8C39Bd5Acbb0A236112Df8d15411161e518;
    address constant BORROW_OPS = 0x9eB2Ce1be2DD6947e4f5Aabe33106f48861DFD74;
    address constant ACTIVE_POOL= 0x77E034c8A1392d99a2C776A6C1593866fEE36a33;
    address constant DEFAULT_POOL=0xC1f785B74a01dd9FAc0dE6070bC583fe9eaC7Ab5;
    address constant COLL_SURPL = 0xA622c3bdBFBE749B1984bc127bFB500e196F594b;
    address constant DCHF       = 0x045da4bFe02B320f4403674B3b7d121737727A36;
    address constant MON        = 0x1EA48B9965bb5086F3b468E50ED93888a661fc17;
    address constant MON_STAKING= 0x8Bc3702c35D33E5DF7cb0F06cb72a0c34Ae0C56F;
    address constant PRICE_FEED = 0x09AB3C0ce6Cb41C13343879A667a6bDAd65ee9DA;
    address constant HINT_HELP  = 0x17244338034Bea1fA940779Bc769Ff01833406c4;
    address constant V3_POOL    = 0x0B1debf6f99a5e2b240296219B76DFebB2183F16; // DCHF/USDC 0.05%
    address constant QUOTER_V2  = 0x61fFE014bA17989E743c5F6cB21bF9697530B21e;
    address constant WBTC       = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;
    address constant USDC       = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant ETH_USD_FEED = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419; // Chainlink ETH/USD
    address constant CHF_USD_FEED = 0x449d117117838fFA61263B61dA6301AA2a88B13A; // Chainlink CHF/USD

    uint160 constant MAX_SQRT_RATIO = 1461446703485210103287273052203988822378723970341;

    // --- actors ---
    address constant ETH_TROVE_OWNER  = 0xAF534cF998662b1A09233Ea54B6ea2B4e2484C88; // holds ~21,558 DCHF
    address constant WBTC_TROVE_LOW   = 0xbCC26C10998B2CDd563ea62aD513c0CceF2Eed50; // ICR ~853%, no pending rewards
    address constant WBTC_TROVE_HIGH  = 0x9e0E1132d14f612FA25DFDe943c655DF90c06DA8; // ICR ~915%, holds pending rewards
    address constant SP_CLAIMANT      = 0x5d417DF2644B7f5309c5e94f78653B3516341BC6; // unclaimed SP gain ~0.79 ETH
    address constant CSP_CLAIMANT     = 0xf78DA622B1dcD66910E1b52f7b4C3743F20b551D; // unclaimed surplus ~0.915 WBTC
    address constant MON_RICH         = 0x8eba1aD289f5e6c50D2f924E17cC8dd607B3C083; // LockedMON, holds 10M MON
    address constant DCHF_WHALE       = 0x1815Cddd5Bc2be12C3d0f389Ea7080Fd230883BA; // EOA, holds 2,351 DCHF

    address ATTACKER = address(0xA77AC4E7);

    function setUp() public {
        string memory rpc = vm.envOr("FORK_RPC_URL", vm.envOr("RPC_URL", string("https://ethereum-rpc.publicnode.com")));
        uint256 pin = vm.envOr("FORK_BLOCK", uint256(0));
        if (pin != 0) {
            try this._forkAt(rpc, pin) {} catch {
                vm.createSelectFork(rpc);
            }
        } else {
            vm.createSelectFork(rpc);
        }
        emit log_named_uint("fork block", block.number);
        emit log_named_uint("basefee", block.basefee);
    }

    function _forkAt(string memory rpc, uint256 blk) external {
        vm.createSelectFork(rpc, blk);
    }

    // helpers ------------------------------------------------------------------

    function _price(address asset) internal returns (uint256) {
        return IPriceFeedLike(PRICE_FEED).fetchPrice(asset);
    }

    function _ethUsd1e8() internal view returns (uint256) {
        (, int256 a,,,) = IAggregatorLike(ETH_USD_FEED).latestRoundData();
        return uint256(a);
    }

    function _chfUsd1e8() internal view returns (uint256) {
        (, int256 a,,,) = IAggregatorLike(CHF_USD_FEED).latestRoundData();
        return uint256(a);
    }

    /// USD value (1e18) of `weiAmt` at Chainlink ETH/USD
    function _usd1e18(uint256 weiAmt) internal view returns (uint256) {
        return weiAmt * _ethUsd1e8() / 1e8;
    }

    function _fmt(string memory what, uint256 v1e18) internal pure returns (string memory) {
        return string.concat(what, " (1e18): ", vm.toString(v1e18));
    }

    // ---------------------------------------------------------------------------
    // 01 — live state: no liquidatable troves
    // ---------------------------------------------------------------------------
    function test_01_live_state_no_liquidatable_troves() public {
        uint256 pEth = _price(address(0));
        uint256 pBtc = _price(WBTC);

        uint256 nh = ITroveManagerHelpers(TM_HELPERS).getTroveOwnersCount(address(0));
        uint256 nw = ITroveManagerHelpers(TM_HELPERS).getTroveOwnersCount(WBTC);
        emit log_named_uint("ETH troves", nh);
        emit log_named_uint("WBTC troves", nw);
        emit log_named_uint("oracle ETH/CHF", pEth);
        emit log_named_uint("oracle WBTC/CHF", pBtc);

        address t0 = ITroveManagerHelpers(TM_HELPERS).getTroveFromTroveOwnersArray(address(0), 0);
        uint256 icr0 = ITroveManagerHelpers(TM_HELPERS).getCurrentICR(address(0), t0, pEth);
        emit log_named_address("ETH trove", t0);
        emit log_named_uint("ETH trove debt", ITroveManagerHelpers(TM_HELPERS).getTroveDebt(address(0), t0));
        emit log_named_uint("ETH trove coll", ITroveManagerHelpers(TM_HELPERS).getTroveColl(address(0), t0));
        emit log_named_uint("ETH trove ICR", icr0);
        assertGt(icr0, 1.1e18, "ETH trove above MCR");

        for (uint256 i; i < nw; i++) {
            address tw = ITroveManagerHelpers(TM_HELPERS).getTroveFromTroveOwnersArray(WBTC, i);
            uint256 icrw = ITroveManagerHelpers(TM_HELPERS).getCurrentICR(WBTC, tw, pBtc);
            emit log_named_address("WBTC trove", tw);
            emit log_named_uint("WBTC trove ICR", icrw);
            assertGt(icrw, 1.1e18, "WBTC trove above MCR");
        }

        emit log_named_uint("ActivePool ETH", ACTIVE_POOL.balance);
        emit log_named_uint("ActivePool WBTC", IERC20Like(WBTC).balanceOf(ACTIVE_POOL));
        emit log_named_uint("DefaultPool WBTC", IERC20Like(WBTC).balanceOf(DEFAULT_POOL));
        emit log_named_uint("SP_ETH ETH balance", ETH_SP.balance);
        emit log_named_uint("SP_ETH recorded collateral", IStabilityPoolLike(ETH_SP).getAssetBalance());
        emit log_named_uint("SP_ETH DCHF deposits", IStabilityPoolLike(ETH_SP).getTotalDCHFDeposits());
        emit log_named_uint("SP_WBTC WBTC balance", IERC20Like(WBTC).balanceOf(WBTC_SP));
        emit log_named_uint("CollSurplusPool ETH", COLL_SURPL.balance);
        emit log_named_uint("CollSurplusPool WBTC", IERC20Like(WBTC).balanceOf(COLL_SURPL));
        emit log_named_uint("DCHF totalSupply", IERC20Like(DCHF).totalSupply());
        emit log_named_uint("DCHF in MONStaking", IERC20Like(DCHF).balanceOf(MON_STAKING));
        emit log_named_uint("MONStaking ETH", MON_STAKING.balance);
        emit log_named_uint("MONStaking WBTC", IERC20Like(WBTC).balanceOf(MON_STAKING));
    }

    // ---------------------------------------------------------------------------
    // 02 — liquidations revert: every trove is far above MCR
    // ---------------------------------------------------------------------------
    function test_02_liquidation_reverts() public {
        uint256 pEth = _price(address(0));
        address t0 = ITroveManagerHelpers(TM_HELPERS).getTroveFromTroveOwnersArray(address(0), 0);
        assertGt(ITroveManagerHelpers(TM_HELPERS).getCurrentICR(address(0), t0, pEth), 1.1e18);

        vm.expectRevert();
        ITroveManager(TROVE_MGR).liquidate(address(0), t0);

        address[] memory arr = new address[](1);
        arr[0] = t0;
        vm.expectRevert();
        ITroveManager(TROVE_MGR).batchLiquidateTroves(address(0), arr);

        uint256 pBtc = _price(WBTC);
        assertGt(ITroveManagerHelpers(TM_HELPERS).getCurrentICR(WBTC, WBTC_TROVE_LOW, pBtc), 1.1e18);
        vm.expectRevert();
        ITroveManager(TROVE_MGR).liquidate(WBTC, WBTC_TROVE_LOW);

        emit log_string("PASS: no trove is liquidatable -> no liquidation extraction");
    }

    // ---------------------------------------------------------------------------
    // 03 — last trove of a collateral is unclosable; other troves are (H-O)
    // ---------------------------------------------------------------------------
    function test_03_last_trove_lock_and_owner_close() public {
        // fund the ETH trove owner - even then the close is blocked by the last-trove rule
        deal(DCHF, ETH_TROVE_OWNER, 100_000e18);
        vm.prank(ETH_TROVE_OWNER);
        (bool ok,) = BORROW_OPS.call(abi.encodeWithSelector(IBorrowerOpsLike.closeTrove.selector, address(0)));
        emit log_named_uint("closeTrove(ETH) success?", ok ? 1 : 0);
        assertFalse(ok, "closing the only ETH trove is blocked");

        // contrast: WBTC has 2 troves, the owner of one CAN close it (holder-recoverable)
        deal(DCHF, WBTC_TROVE_LOW, 10_000e18);
        uint256 collBefore = IERC20Like(WBTC).balanceOf(WBTC_TROVE_LOW);
        vm.prank(WBTC_TROVE_LOW);
        IBorrowerOpsLike(BORROW_OPS).closeTrove(WBTC);
        uint256 collAfter = IERC20Like(WBTC).balanceOf(WBTC_TROVE_LOW);
        emit log_named_uint("WBTC trove collateral before", collBefore);
        emit log_named_uint("WBTC trove collateral after", collAfter);
        assertGt(collAfter, collBefore, "owner recovered collateral (H-O)");
        assertEq(ITroveManagerHelpers(TM_HELPERS).getTroveOwnersCount(WBTC), 1, "one WBTC trove left");
    }

    // ---------------------------------------------------------------------------
    // 04 — redemption is fair value minus fee: no redeemer profit
    // ---------------------------------------------------------------------------
    function test_04_redemption_fair_value_minus_fee() public {
        assertFalse(ITroveManager(TROVE_MGR).isRedemptionWhitelisted(), "redemption open");

        uint256 pEth = _price(address(0));
        uint256 amount = 1_000e18;
        (address first, uint256 partialNICR, uint256 truncated) =
            IHintHelpersLike(HINT_HELP).getRedemptionHints(address(0), amount, pEth, 0);
        emit log_named_uint("truncated redeemable", truncated);
        require(truncated >= amount - 1, "not enough trove debt");

        uint256 balBefore = DCHF_WHALE.balance;
        vm.prank(DCHF_WHALE);
        ITroveManager(TROVE_MGR).redeemCollateral(address(0), amount, first, address(0), address(0), partialNICR, 0, 1e18);
        uint256 got = DCHF_WHALE.balance - balBefore;

        uint256 fair = amount * 1e18 / pEth; // fee-free
        uint256 feeRate = ITroveManagerHelpers(TM_HELPERS).getRedemptionRateWithDecay(address(0));
        emit log_named_uint("redemption fee rate", feeRate);
        emit log_named_uint("ETH received", got);
        emit log_named_uint("ETH fair (no fee)", fair);
        emit log_named_uint("USD of ETH received (1e18)", _usd1e18(got));
        emit log_named_uint("DCHF face USD (1e18)", amount * _chfUsd1e8() / 1e8);

        assertLt(got, fair, "fee is charged");
        // fee = floor + redeemedFraction/BETA (BETA=2) + decayed base; for 1000 DCHF on 32k debt ~2%
        assertGt(got, fair * 90 / 100, "received within 10% of fair");

        // redeemer loses the fee in USD terms
        assertLt(_usd1e18(got), amount * _chfUsd1e8() / 1e8, "redemption at fair value is a loss");
        emit log_string("PASS: redeeming burns DCHF for fair-value-minus-fee collateral");
    }

    // ---------------------------------------------------------------------------
    // 05 — stability pool: only recorded depositors can claim
    // ---------------------------------------------------------------------------
    function test_05_stability_pool_claim_gate() public {
        assertEq(IStabilityPoolLike(ETH_SP).getTotalDCHFDeposits(), 0, "pool emptied");
        assertGt(ETH_SP.balance, 1 ether, "collateral sits in SP");

        vm.prank(ATTACKER);
        vm.expectRevert(bytes("StabilityPool: User must have a non-zero deposit"));
        IStabilityPoolLike(ETH_SP).withdrawFromSP(0);

        uint256 gain = IStabilityPoolLike(ETH_SP).getDepositorAssetGain(SP_CLAIMANT);
        emit log_named_uint("claimant recorded deposit", IStabilityPoolLike(ETH_SP).deposits(SP_CLAIMANT));
        emit log_named_uint("claimant computed gain", gain);
        assertGt(gain, 0.7 ether);

        uint256 before = SP_CLAIMANT.balance;
        vm.prank(SP_CLAIMANT);
        IStabilityPoolLike(ETH_SP).withdrawFromSP(0);
        uint256 got = SP_CLAIMANT.balance - before;
        emit log_named_uint("claimant ETH received", got);
        assertApproxEqRel(got, gain, 0.01e18);
        emit log_string("PASS: SP collateral claimable only by snapshot-holding depositors (H-O)");
    }

    // ---------------------------------------------------------------------------
    // 06 — coll surplus pool: only recorded trove owners can claim
    // ---------------------------------------------------------------------------
    function test_06_collsurplus_claim_gate() public {
        assertGt(IERC20Like(WBTC).balanceOf(COLL_SURPL), 2.3e8);

        vm.prank(ATTACKER);
        vm.expectRevert(bytes("CollSurplusPool: No collateral available to claim"));
        IBorrowerOpsLike(BORROW_OPS).claimCollateral(WBTC);

        uint256 claim = ICollSurplusPoolLike(COLL_SURPL).getCollateral(WBTC, CSP_CLAIMANT);
        emit log_named_uint("claimant WBTC surplus (18dec)", claim);
        assertGt(claim, 0.9e18);

        uint256 before = IERC20Like(WBTC).balanceOf(CSP_CLAIMANT);
        vm.prank(CSP_CLAIMANT);
        IBorrowerOpsLike(BORROW_OPS).claimCollateral(WBTC);
        uint256 got = IERC20Like(WBTC).balanceOf(CSP_CLAIMANT) - before;
        emit log_named_uint("claimant WBTC received (8dec)", got);
        assertEq(got, claim / 1e10, "surplus scaled to token decimals");
        emit log_string("PASS: coll-surplus claimable only by recorded owners (H-O)");
    }

    // ---------------------------------------------------------------------------
    // 07 — the only DCHF market: Uniswap V3 DCHF/USDC. Buy+redeem arb is dust.
    // ---------------------------------------------------------------------------
    function test_07_v3_arb_is_dust_and_gas_negative() public {
        // fund this contract with 10 USDC (slot 9 of USDC) — public liquidity
        vm.store(USDC, keccak256(abi.encode(address(this), uint256(9))), bytes32(uint256(10e6)));
        assertEq(IERC20Like(USDC).balanceOf(address(this)), 10e6, "usdc funded");

        uint256 chfUsd = _chfUsd1e8();
        uint256 pEth = _price(address(0));
        uint256 feeRate = ITroveManagerHelpers(TM_HELPERS).getRedemptionRateWithDecay(address(0));
        // USD (1e18) obtained by redeeming 1e18 DCHF
        uint256 usdPerDchf1e18 = (1e18 * 1e18 / pEth) * _ethUsd1e8() / 1e8;
        usdPerDchf1e18 = usdPerDchf1e18 * (1e18 - feeRate) / 1e18;
        emit log_named_uint("CHF/USD (1e8)", chfUsd);
        emit log_named_uint("redemption USD per DCHF (1e18)", usdPerDchf1e18);

        uint256 bestIn;
        uint256 bestProfit;
        for (uint256 i = 1; i <= 10; i++) {
            uint256 amtIn = i * 500_000; // 0.5 .. 5.0 USDC
            uint256 out = _quoteUsdcToDchf(amtIn);
            if (out == 0) continue;
            uint256 revenue1e18 = out * usdPerDchf1e18 / 1e18;
            uint256 spend1e18 = amtIn * 1e12; // USDC 6dec -> 1e18 USD
            if (revenue1e18 <= spend1e18) continue;
            uint256 net = revenue1e18 - spend1e18;
            emit log_named_uint("  quote usdc(1e6)", amtIn);
            emit log_named_uint("  dchf out (1e18)", out);
            emit log_named_uint("  gross profit USD (1e18)", net);
            if (net > bestProfit) { bestProfit = net; bestIn = amtIn; }
        }
        emit log_named_uint("BEST input (1e6 USDC)", bestIn);
        emit log_named_uint("BEST gross profit USD (1e18)", bestProfit);
        assertLt(bestProfit, 1e18, "gross arb below $1");

        if (bestIn > 0) {
            uint256 gas0 = gasleft();
            uint256 dchfOut = _swapUsdcToDchf(bestIn);
            emit log_named_uint("dchf bought", dchfOut);

            (address first, uint256 partialNICR, uint256 trunc) =
                IHintHelpersLike(HINT_HELP).getRedemptionHints(address(0), dchfOut, pEth, 0);
            uint256 ethBefore = address(this).balance;
            if (trunc > 0) {
                ITroveManager(TROVE_MGR).redeemCollateral(address(0), trunc, first, address(0), address(0), partialNICR, 0, 1e18);
            }
            uint256 ethGot = address(this).balance - ethBefore;
            uint256 gasUsed = gas0 - gasleft();
            emit log_named_uint("ETH from redemption", ethGot);
            emit log_named_uint("revenue USD (1e18)", _usd1e18(ethGot));
            emit log_named_uint("cost USD (1e18)", uint256(bestIn) * 1e12);
            emit log_named_uint("gas used", gasUsed);
            emit log_named_uint("gas cost USD at block basefee (1e18)", _usd1e18(gasUsed * block.basefee));
            emit log_named_uint("gas cost USD at 1 gwei (1e18)", _usd1e18(gasUsed * 1 gwei));
            uint256 gross1e18 = _usd1e18(ethGot);
            uint256 cost1e18 = uint256(bestIn) * 1e12;
            // the entire gross profit is smaller than the gas cost at 1 gwei
            assertLt(gross1e18, cost1e18 + _usd1e18(gasUsed * 1 gwei), "gross < gas even at 1 gwei");
            int256 net = int256(gross1e18) - int256(cost1e18) - int256(_usd1e18(gasUsed * block.basefee));
            emit log_named_int("net USD at block basefee (1e18)", net);
            assertLt(net, 5e16, "net below $0.05 even at the observed basefee");
        }
    }

    function _quoteUsdcToDchf(uint256 amtIn) internal returns (uint256) {
        (bool ok, bytes memory ret) = QUOTER_V2.call(
            abi.encodeWithSelector(
                IQuoterV2Like.quoteExactInputSingle.selector,
                IQuoterV2Like.QuoteExactInputSingleParams({
                    tokenIn: USDC,
                    tokenOut: DCHF,
                    amountIn: amtIn,
                    fee: uint24(500),
                    sqrtPriceLimitX96: uint160(0)
                })
            )
        );
        // QuoterV2 returns the tuple either as a normal return or as revert data (both 128 bytes)
        if (ret.length < 128) return 0;
        (uint256 out,,,) = abi.decode(ret, (uint256, uint160, uint32, uint256));
        return out;
    }

    function _swapUsdcToDchf(uint256 amtIn) internal returns (uint256) {
        uint256 before = IERC20Like(DCHF).balanceOf(address(this));
        IUniswapV3PoolLike(V3_POOL).swap(address(this), false, int256(amtIn), MAX_SQRT_RATIO - 1, "");
        return IERC20Like(DCHF).balanceOf(address(this)) - before;
    }

    function uniswapV3SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata) external {
        require(msg.sender == V3_POOL, "only pool");
        if (amount0Delta > 0) IERC20Like(DCHF).transfer(msg.sender, uint256(amount0Delta));
        if (amount1Delta > 0) IERC20Like(USDC).transfer(msg.sender, uint256(amount1Delta));
    }

    receive() external payable {}

    // ---------------------------------------------------------------------------
    // 08 — mint (open trove) + redeem round trip loses fees
    // ---------------------------------------------------------------------------
    function test_08_mint_and_redeem_roundtrip_unprofitable() public {
        uint256 pEth = _price(address(0));
        uint256 borrowRate = ITroveManagerHelpers(TM_HELPERS).getBorrowingRateWithDecay(address(0));
        uint256 redeemRate = ITroveManagerHelpers(TM_HELPERS).getRedemptionRateWithDecay(address(0));
        emit log_named_uint("borrowing fee rate", borrowRate);
        emit log_named_uint("redemption fee rate", redeemRate);
        assertGe(borrowRate + redeemRate, 9e15, "round trip costs >= 0.9%");

        address fresh = address(0xBEEF);
        vm.deal(fresh, 5 ether);
        uint256 coll = 2 ether;
        uint256 borrow = 2_100e18;
        vm.prank(fresh);
        IBorrowerOpsLike(BORROW_OPS).openTrove{value: coll}(address(0), 0, 5e16, borrow, address(0), address(0));
        uint256 dchfBal = IERC20Like(DCHF).balanceOf(fresh);
        emit log_named_uint("DCHF minted", dchfBal);
        assertGt(dchfBal, 2_000e18);

        (address first, uint256 partialNICR, uint256 trunc) =
            IHintHelpersLike(HINT_HELP).getRedemptionHints(address(0), dchfBal, pEth, 0);
        uint256 ethBefore = fresh.balance;
        if (trunc > 0) {
            vm.prank(fresh);
            ITroveManager(TROVE_MGR).redeemCollateral(address(0), trunc, first, address(0), address(0), partialNICR, 0, 1e18);
        }
        uint256 ethGot = fresh.balance - ethBefore;
        emit log_named_uint("ETH received redeeming the same DCHF", ethGot);
        emit log_named_uint("ETH deposited as collateral", coll);
        assertLt(ethGot, coll, "round trip returns less ETH than deposited");
        emit log_string("PASS: mint+redeem is circular and pays both fees");
    }

    // ---------------------------------------------------------------------------
    // 09 — MON staking: no free historical rewards for new stakers
    // ---------------------------------------------------------------------------
    function test_09_mon_staking_new_staker_no_free_rewards() public {
        assertFalse(IMONStakingLike(MON_STAKING).paused(), "staking unpaused");
        assertGt(MON_STAKING.balance, 1 ether, "ETH rewards present");
        emit log_named_uint("MONStaking ETH rewards", MON_STAKING.balance);
        emit log_named_uint("MONStaking WBTC rewards", IERC20Like(WBTC).balanceOf(MON_STAKING));
        emit log_named_uint("MONStaking DCHF rewards", IERC20Like(DCHF).balanceOf(MON_STAKING));

        address bob = address(0xB0B);
        vm.prank(MON_RICH);
        IERC20Like(MON).transfer(bob, 2e18);
        vm.prank(bob);
        IERC20Like(MON).approve(MON_STAKING, 2e18);
        vm.prank(bob);
        IMONStakingLike(MON_STAKING).stake(1e18);

        assertEq(IMONStakingLike(MON_STAKING).getPendingAssetGain(address(0), bob), 0, "no historical ETH");
        assertEq(IMONStakingLike(MON_STAKING).getPendingDCHFGain(bob), 0, "no historical DCHF");

        vm.prank(bob);
        IMONStakingLike(MON_STAKING).unstake(1e18);
        assertEq(IERC20Like(MON).balanceOf(bob), 2e18, "MON returned");
        emit log_string("PASS: MON staking rewards only accrue going forward (H-O for incumbents)");
    }

    // ---------------------------------------------------------------------------
    // 10 — DCHF market capacity: pool cannot sell meaningful size
    // ---------------------------------------------------------------------------
    function test_10_dchf_market_capacity() public {
        uint256 out100 = _quoteUsdcToDchf(100_000_000); // 100 USDC
        emit log_named_uint("DCHF out for 100 USDC", out100);
        assertLt(out100, 5e18, "pool sells < 5 DCHF even for 100 USDC");
        emit log_named_uint("pool DCHF balance", IERC20Like(DCHF).balanceOf(V3_POOL));
        emit log_named_uint("pool USDC balance", IERC20Like(USDC).balanceOf(V3_POOL));
        emit log_named_uint("pool liquidity", IUniswapV3PoolLike(V3_POOL).liquidity());
        emit log_string("PASS: DCHF market cannot supply an arb of any size");
    }

    // ---------------------------------------------------------------------------
    // 11 — AirdropMON aggregator: large unattributed balances are stuck (S)
    // ---------------------------------------------------------------------------
    function test_11_airdropmon_stranded_rewards() public {
        address AM = 0xFF42ec1C83e0f4939C45ab4F6a027b44e5A3fc8F;
        // user-side gate: a stranger's claim reverts, so the low-level call returns false
        vm.prank(ATTACKER);
        (bool ok,) = AM.call(abi.encodeWithSignature("claimExistingRewards()"));
        require(!ok, "stranger cannot claim");

        // biggest freezer user gets only their F_DCHF-scaled share
        address user1 = 0x8C35df4fD2250A1dC7bBeAD6F142Eb3fbC6a6380;
        uint256 pend = _pendingDchf(AM, user1);
        emit log_named_uint("freezer user pending DCHF", pend);
        uint256 before = IERC20Like(DCHF).balanceOf(user1);
        vm.prank(user1);
        (bool ok2,) = AM.call(abi.encodeWithSignature("claimExistingRewards()"));
        require(ok2, "freezer claim");
        uint256 got = IERC20Like(DCHF).balanceOf(user1) - before;
        assertEq(got, pend, "gets exactly their attributed share");

        // contract balances vs the sum of what all users can ever claim
        emit log_named_uint("AirdropMON DCHF balance", IERC20Like(DCHF).balanceOf(AM));
        emit log_named_uint("AirdropMON ETH balance", AM.balance);
        emit log_named_uint("AirdropMON WBTC balance", IERC20Like(WBTC).balanceOf(AM));

        // owner cannot rescue the protected tokens
        address ownerSafe = 0x83737EAe72ba7597b36494D723fbF58cAfee8A69;
        vm.prank(ownerSafe);
        (bool ok3,) = AM.call(abi.encodeWithSignature("sweep(address)", DCHF));
        emit log_named_uint("sweep(DCHF) by owner success?", ok3 ? 1 : 0);
        assertFalse(ok3, "DCHF is a protected token - cannot be swept");
        emit log_string("PASS: unattributed rewards inside AirdropMON are stuck (S)");
    }

    function _pendingDchf(address am, address user) internal view returns (uint256) {
        (bool ok, bytes memory ret) = am.staticcall(abi.encodeWithSignature("getPendingDCHFGain(address)", user));
        return ok ? abi.decode(ret, (uint256)) : 0;
    }
}
