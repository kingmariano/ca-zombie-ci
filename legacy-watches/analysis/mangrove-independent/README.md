# Mangrove (Blast + Arbitrum) — independent live-state determination

**Verdict: E-U $0.00 (high confidence).** The reported ~$4.24M "TVL" on Blast (and $38.7k on
Arbitrum) is the **sum of live offers' promised `gives`** — promises, not custody. Every live
offer is **unfunded**: the maker holds dust of the outbound token while retaining an unlimited
Mangrove allowance. Mangrove's take flow pulls the outbound token from the maker during the take
(`transferTokenFrom(outbound, maker, mgv, takerWants)` after `makerExecute`), so unfunded offers
fail with `mgv/makerTransferFail` and deliver nothing.

## Contracts / state (all read-only, 2026-10-10, Blast block 41,411,145)

| Item | Value |
|---|---|
| Blast Mgv (BlastMangrove) | `0xb1a49c54192ea59b233200ea38ab56650dfb448c` |
| Blast MgvReader | `0x26fD9643Baf1f8A44b752B28f0D90AEBd04AB3F8` |
| Arbitrum MgvReader | `0x7E108d7C9CADb03E026075Bf242aC2353d0D1875` |
| `global()` decoded | **dead=false**, monitor `0x4ee4ab30…cb36`, gasprice=1, gasmax=2,000,000, maxGasreqForFailingOffers=6,000,000 |
| Open markets (Blast) | 6, **all `active=1`, `lock=0`** (tickspacing 1) |
| Live offers (Blast) | 40 across markets 1–5; market 0 (USDB/WETH) empty |
| Live offers (Arbitrum) | 1 (USDT0→USDC, 38,728.66 gives) |

### The stale-offer appearance (why this looked like a jackpot)
The WETH/BLAST asks were posted when BLAST ≈ $0.0041; ticks 133,069–135,538 imply
≈602k–790k BLAST per WETH. BLAST is now **$0.0000622** (67× lower) → a taker paying BLAST would
receive WETH at ~1/67 of market (e.g. offer 1: gives 0.832 WETH ≈ $2,076 for ~500,864 BLAST ≈ $31).
Similarly USDB trades at $0.988 vs USDe $0.999 and offers in market 3:1 give USDe for ~1.003–1.005 USDB.

### Why it is not extractable — maker balances (outbound token) vs promised
| Maker | Promises | Holds | Deliverable |
|---|---|---|---|
| `0xac1ce7f6…480e` | 14.86 WETH (mkt5:0); 2,091,000 USDe (mkt3:1); 2,096,294 USDB (mkt3:0) | **0.0064 WETH / 0.197 USDe / 0.397 USDB** | dust |
| `0x67270aee…0843` | 3.0 WETH (mkt1:0); 2.652 mwstETH20 (mkt1:1) | **0.0063 WETH / 0.0064 mwstETH20** | dust |
| `0x26e47dc2…69e0` | 1.0 WETH (mkt2:0); 2.242 mwstETH40 (mkt2:1) | **0.0019 WETH / 0.0073 mwstETH40** | dust |
| `0xe1c3a806…55fc` BlastKandel | 305,605 BLAST (mkt4:1); 17,208,270 BLAST (mkt5:1) | **33,973 BLAST / 0.048 WETH** | dust |
| `0xf9f77bb3…6a27` SmartKandel | 3.316 mwstETH40 (mkt2:1) | **0.0643 mwstETH40 / 0.117 WETH** | dust |

All five makers have **unlimited allowance to Mgv** (so the failure is purely lack of tokens).
The absolute upper bound of what a taker could pull from every maker's dust balance is ≈ **$30**
(e.g. 0.0064 WETH = $16; 0.0073 mwstETH40 ≈ $19 if mwstETH40 ≈ $2.6k) — before gas, and only if
each maker's `makerExecute` tolerates the transfer; realistically **$0** net. The per-offer bounty
for cleaning unfunded offers is native dust (provision ≈ 2.25e12 wei ≈ $0.000002) — below gas.

Arbitrum: single live offer (38,728.66 USDT0) from maker `0xd77ab271…3618`, **USDT0 balance 0** → same verdict.

## Fork PoC (final, 5/5 PASS; Blast fork, pinned block 41,411,145)
`poc/test/mangrove_blast.t.sol` — takers are real on-chain accounts (impersonated), no storage writes:

| # | Test | Result |
|---|---|---|
| 1 | `test_weth_blast_offer_maker_reverts` — cheapest WETH/BLAST ask (maxTick 133069), 0.05 WETH fill | `takerGot=0`, no balances change; trace shows the maker's `makerExecute` calling a Thruster V3 `swap` and reverting (`mgv/makerRevert`) — it cannot buy the WETH it must deliver |
| 2 | `test_mwsteth40_offer_delivers_at_loss` — mwstETH40 ask (tick −8076) | **delivers** 0.0029994 mwstETH40 for 0.00133784 WETH — but mwstETH40 trades at **0.05 WETH** on-chain, so the taker pays 0.446 WETH/unit → a **loss** (the maker wins) |
| 3 | `test_weth_for_mwsteth40_profit_dust` — nominally profitable direction (tick 8135; market: pay 2.26 mwstETH40 ≈ 0.113 WETH for 1 WETH) | **delivers 0** — maker 0x26e47dc2's `makerExecute` reverts when it would sell WETH below market |
| 4 | `test_mwsteth20_for_weth_profit_dust` — nominally profitable direction (ticks 1223/1238; mwstETH20 = 1.3925 WETH on-chain) | **delivers 0** — maker 0x67270aee reverts |
| 5 | `test_maker_balances` — maker dust | WETH 0.006406, USDe 0.197, USDB 0.397, mwstETH40 0.007287, mwstETH20 0.006434 |

**Interpretation:** the makers are semi-live arbitrage strategies that only deliver when the trade
is profitable *for them*. Every taker-profitable direction reverts; the one deliverable offer is a
taker loss at market. **E-U = $0.00 exactly.**

Market-price refs (on-chain, 2026-10-10): mwstETH20 = 1.3925 WETH (Thruster V3 pool
`0x4e0e7d3b06ed61d10bee6067446b10c482c53323`), mwstETH40 = 0.0500 WETH (pool
`0x9649ab08123c2709ea93ccfee83cf827e02775ea`).
Run via CI (`poc.yml`, branch `legacy-watches`); earlier runs 38054849715 / 38064371232,
final green run URL in the parent README.

## Files
- `evidence.json` — consolidated state, makers, verdict.
- `mgv_scan.py` (markets), `mgv_full.py` (offers+ticks+local flags), `mgv_makers.py` (makers+details),
  `mgv_offers.py` — scripts (public RPC only).
- `mgv_markets.json`, `mgv_offers2.json`, `mgv_details.json` — raw dumps.
