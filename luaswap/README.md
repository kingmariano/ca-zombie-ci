# C2-04 — LuaSwap (Viction): stale-price extraction from a dead DEX — live extractable-value determination

**Campaign:** zombie-hunt II · **Chain:** Viction (chain id 88, RPC `https://rpc.viction.xyz`) · **Date of work:** 2026-10-05
**Status:** read-only research; PoC fork-verified only; **no mainnet transactions were signed or sent**.
**Verdict headline:** an external, unprivileged attacker can still extract **≈ $17.8k net** (on-chain, fork-proven)
from LuaSwap's long-frozen pools by minting WTOMO 1:1 with VIC through `deposit()` and selling it into pools
that still price WTOMO at **~$5.57** vs the real VIC price of **$0.004476** (**~1,244×** stale).
Required attacker capital: **~113,356 VIC ≈ $507** (fully recoverable only as the extracted assets; no flash loan
needed and none is required). Confidence: **high** for the on-chain extraction; the main discount is the
bridged-asset exit risk (see §8).

---

## 1. TL;DR

| | |
|---|---|
| **Target** | LuaSwap (Viction) — dead UniswapV2 fork; factory `0x28c79368257CD71A122409330ad2bEBA7277a396`, 1,555 pairs (764 with liquidity) |
| **Live extractable (external unprivileged)** | **$17,792 net** on-chain (fork campaign, 2026-10-05); greedy upper-bound simulation **$17,814 net**. Gross $18,299 |
| **Why open** | `WTOMO.deposit()` mints 1:1 with VIC (payable, permissionless, fully backed). Pools were never re-priced when VIC fell; there is no oracle and no admin control over pair prices. All 79 USDT pools + ETH/BTC pools remain callable |
| **Capital requirement** | **113,356 VIC ≈ $507** (minted to WTOMO and sold; not recovered). Gas ≈ 0.0006 VIC. No flash-loan venue needed |
| **Composition** | USDT 10,541.29 + ETH 2.618579 + BTC 0.00780748 (fork-measured); sim also extracts 0.725 USDC |
| **Latent / additional** | 0.694 tETH in pair891 ($1.8k if legacy tETH is bridge-redeemable); 0.0104 WBTC in pair751/pair780 if those WBTC contracts are canonical ($0.8k) — excluded from the headline |
| **Not extractable** | $2,505 USDT in pair835 (HCC has no other pool → circular), $7.1k USDT in pair890 (tETH source depth), $3.2k USDT in pair2 (LUA source depth shared with the ETH sink), dust pools |
| **Status** | **CRIT — E-U** (verified live; no bug needed — the DEX is simply frozen at 2021 prices) |

The corpus C2-04 claim ("24,104.54 USDT across 79 pools, net bounded by pool depth ≈ $24.1k USDT") is
**partially corrected**: $24,104.54 is the *total* USDT held by all 79 USDT pairs (verified at blocks
114,799,532 / 114,804,371), but only ~$10.5k of it is reachable with correct depth accounting; conversely the
attacker also extracts **$7.8k of ETH/BTC**, so the true net (~$17.8k) is close to the original headline for
different reasons. See §5 for the exact pool-by-pool accounting.

---

## 2. The mechanism, in exact terms

All addresses below are on Viction (chain 88).

- **WTOMO** = `0xb1f66997a5760428d3a87d68b90bfe0ae64121cc` ("Wrapped TOMO", 1,781-byte WETH9-style contract).
  - `deposit()` (`0xd0e30db0`) is payable and permissionless; `withdraw()` (`0x2e1a7d4d`) exists.
  - `totalSupply() = 42,098.63809312115008282` and the contract's native VIC balance equals it exactly →
    **fully backed 1:1** (verified at multiple blocks; see `ci-out/viction-state.json`).
  - There is no cap, fee, whitelist, role or pause on deposit.
- **Real VIC price** = $0.004475563 (DefiLlama `viction:0xb1f66997…` price for the WTOMO contract, 2026-10-05;
  CoinGecko cross-checked). So minting 1 WTOMO costs **$0.004476**.
- **Pool price** (pair1 USDT/WTOMO `0x347f551eaba062167779c9c336aa681526857b81`):
  `4,883.128274 USDT / 876.709408977 WTOMO` → **$5.569 per WTOMO**, i.e. **1,244×** the mint cost.
  The whole pool graph is priced off the same 2021 web (many pools show the same ~$5.5/WTOMO).
- **Fee model (verified empirically):** `factory.swapFee() = 4` → **0.4%** per swap, not the UniswapV2 0.3%.
  A probe (`test_probe_actual_swap_fee`) binary-searches the maximum accepted output and recovers the fee
  numerator `= 4`. Separately, LuaSwap's pairs apply a TRC21-style transfer minFee on some tokens
  (`factory.getTransferFee(token, amount)`): USDC=1000, HY=2e15, USDE=1050, CBC=1e15 raw units; USDT/WTOMO/LUA/
  ETH/BTC/TAI/LEC/SRM/FTT = 0. These constants are charged to the sender and were modelled explicitly in the PoC.
- **No privilege needed:** pairs are ordinary UniswapV2 `swap()` (`0x022c0d9f`); the factory has no pause; every
  call in the PoC is a plain `transfer` + `swap` from a fresh test contract. The only "permission" is holding VIC.

**Extraction plan (fork-verified, exact amounts in `poc/test/LuaSwap.t.sol`):**

| # | Route | VIC in | Asset out |
|---|---|---|---|
| A | `deposit()` → sell WTOMO into pair1 (USDT/WTOMO) | 30,109.90 | 4,734.94 USDT |
| B | `deposit()` → sell WTOMO into pair4 (LUA/WTOMO) → split LUA: sell 2,707,725.52 LUA into pair2 (USDT/LUA) + rest into pair18 (ETH/LUA) | 76,902.89 | 4,970.46 USDT + 2.608487 ETH |
| C | `deposit()` → sell WTOMO into pair19 (BTC/WTOMO) | 849.30 | 0.00780778 BTC |
| D | `deposit()` → pair891 (tETH/WTOMO) → sell tETH into pair890 (USDT/tETH) | 4,335.00 | 673.69 USDT |
| E | `deposit()` → pair620 (WTOMO/TAI) → sell TAI into pair619 (USDT/TAI) | 828.70 | 129.35 USDT |
| F | `deposit()` → pair810 (LEC/WTOMO) → sell LEC into pair809 (LEC/USDT) | 90.68 | 14.25 USDT |
| G | 8 small routes (pair3 ETH; pair76→68 USDC→USDT; pair143→178 HY→USDT; pair829→828 USDE→USDT; pair1208→1207 MFC→USDT; pair785→784 CBC→USDT; pair32→226 SRM→ETH; pair142→217 FTT→ETH) | 217.30 | 18.60 USDT + 0.010093 ETH |
| | **Total** | **113,356.47 VIC ($507.33)** | **USDT 10,541.29 + ETH 2.618579 + BTC 0.00780748** |

The joint optimum for route B (LUA source pair4 shared between the USDT sink pair2 and the ETH sink pair18) was
solved numerically: at the optimum the marginal USD value of LUA is equalized between both sinks and equals the
marginal VIC cost of LUA — the greedy simulator (`analysis/extract_sim3.py`, marginal-step, 0.4% fee) reaches the
same point: **USDT 10,569.56 + ETH 2.624207 + BTC 0.007824 + USDC 0.725 for 118,696.8 VIC ($531) → net $17,813.91**.
The PoC's simpler static plan banks $17,792.16.

---

## 3. Total live extractable now

**≈ $17,792 net (on-chain) — confidence high for the on-chain extraction, medium for USD realization (exit risk).**

- Fork-verified campaign total (block ~114,805,650 at the local run; CI re-runs at head):
  `GROSS $18,299.49 − VIC cost $507.33 = NET $17,792.16`.
- Greedy upper-bound simulation on the full 1,555-pair graph: `GROSS $18,345.15 − $531.23 = NET $17,813.91`.
- Categories: **E-U = $17,792** (attacker-extractable); **H-O = 0**; **P = 0**; **S = 0** (no protocol roles or
  stuck paths are involved — everything is a plain public AMM).
- State stability: a full factory re-scan at block **114,804,371** found **zero reserve changes across all 1,555
  pairs** vs block **114,799,532** (≈4,839 blocks / ~2.7 h), and the pair reserves are unchanged again when
  re-read at later blocks — the DEX is effectively frozen, so the numbers are stable.

---

## 4. Live-state assessment (all reads are `eth_call` at explicit blocks)

### 4.1 Target set

- Factory `0x28c79368257CD71A122409330ad2bEBA7277a396`.
- Pair enumeration by full-history `PairCreated` logs: **1,555 pairs**, max index 1555, **764 pairs with
  non-zero liquidity** at block 114,799,532 (raw dump: `analysis/pairs_raw_latest.json`,
  `analysis/pairs_summary_latest.csv`).
- Canonical bridged assets (verified `name`/`symbol`/`decimals`/`totalSupply` on-chain):
  - USDT `0x381b31409e4d220919b2cff012ed94d70135a59e` 6 dec, supply 170,830.323768
  - USDC `0xcca4e6302510d555b654b3eab9c0fcb223bcfdf0` 6 dec
  - ETH `0x2eaa73bd0db20c64f53febea7b5f5e5bccc7fb8b` 18 dec, supply 211.63
  - BTC `0xae44807d8a9ce4b30146437474ed6faaafa1b809` 8 dec
  - tETH `0xa1ff8559646a79e47ecdfaca60272f3081998569` "TomoChain-ETH", 18 dec, supply 11.835
  - WBTC candidates `0x503b2ddc…` (supply 1.208) and `0xa9189563…` (supply 0.998)
- **Total canonical value parked in pools** (all pools, reachable or not): USDT **$24,104.54** (79 pools),
  ETH **4.345521 ($11,766.74)**, BTC **0.0078692 ($672.92)**, USDC **$11.23**, DAI **$0.02** — **$36.5k** gross.

### 4.2 Why only $17.8k is extractable (depth accounting)

| Pool | Held | Extractable now | Why not all |
|---|---|---|---|
| pair1 USDT/WTOMO `0x347f551e…` | 4,883.13 USDT | ~4,734.94 | direct, VIC-cost-limited |
| pair2 USDT/LUA `0x08975663…` | 8,196.13 USDT | ~4,970 (joint with pair18) | LUA must be bought from pair4, which only holds 7.09M LUA; the ETH sink competes for it |
| pair18 ETH/LUA `0x54a12b95…` | 4.320449 ETH | ~2.608 (joint with pair2) | same shared LUA source |
| pair890 USDT/tETH `0x2e5f7706…` | 7,812.15 USDT | ~674 | tETH source pair891 holds only 0.694 tETH |
| pair19 BTC/WTOMO `0x4fbd8ba7…` | 0.00786793 BTC | ~0.007808 | steeper price impact, negligible |
| pair619 USDT/TAI | 345.43 USDT | ~129 | TAI source pair620 holds 326.57 TAI; pool priced fairly relative to TAI |
| pair809 USDT/LEC | 277.58 USDT | ~14.3 | LEC source pair810 holds 8,170 LEC |
| pair835 USDT/HCC `0x56db0320…` | 2,505.13 USDT | **0** | **HCC exists only in this pool** → no non-circular way to acquire it |
| pair740 USDT/Shit | 32.37 USDT | ~0.05 | 134.8M Shit vs 32 USDT → dust |
| pair29 USDT/DTE | 1.71 USDT | **0** | DTE/EVND component isolated (circular) |
| other ~60 USDT pools | ~$30 total | ~$25 | small, but included in the campaign |
| pair3/73/217/… ETH pools | ~0.025 ETH | ~0.02 | small, included |

All other exact amounts and the full route table are in `analysis/extract_sim3.py` output
(`analysis/sim3_final.log`) and the PoC traces.

### 4.4 Other stale-priced pools (the whole web is frozen, not just pair1)

Implied USD price of 1 WTOMO at the venue, vs mint cost $0.004476:

| Pool | Implied WTOMO price | Multiple vs mint cost | Note |
|---|---|---|---|
| pair1 USDT/WTOMO `0x347f551e…` | $5.569 | 1,244× | direct sink, 4,883 USDT |
| pair4→pair2 (LUA then USDT) | $5.577 | 1,246× | joint USDT/ETH sink, LUA source 7.09M |
| pair3 ETH/WTOMO `0x75f1b142…` | $5.59 | 1,249× | direct ETH sink (0.00545 ETH) |
| pair19 BTC/WTOMO `0x4fbd8ba7…` | $139.2 | 31,100× | direct BTC sink (0.00787 BTC); the richest mispricing on the chain |
| pair891→pair890 (tETH then USDT) | $5.48 | 1,225× | tETH source depth 0.694 caps it |
| pair620→pair619 (TAI then USDT) | $5.52 | 1,233× | TAI source 326.6 units |
| pair143→pair178 (HY then USDT) | $5.66 | 1,265× | HY source 113.7 units |
| pair76 WTOMO/USDC `0xc3e1d07b…` | $1.037 | 232× | USDC/TRC21 quirk; small but included |
| pair780 WTOMO/WBTC `0x8502e57b…` | $1.685 (if WBTC canonical) | 376× | 0.004633 WBTC — excluded from headline |

The 526 of 669 tokens that are reachable from WTOMO form one connected stale-price web; the extraction problem
is a depth/allocation problem (which is why the joint optimiser matters), not a reachability problem.

### 4.3 Contract checks

- `WTOMO.deposit()` executes and mints exactly the sent value (`test_wtomo_deposit_withdraw_1to1`),
  `withdraw()` returns it. Contract native balance == totalSupply (fully backed, `ci-out/viction-state.json`).
- Pair1 code size **11,240 bytes**, exposes `swap`, `getReserves`, `token0/token1`; factory `swapFee() = 4`;
  pairs call the factory during `swap` (verified in traces). No pause/owner guards on swaps.
- The real-USDT token has **zero Transfer logs in the last 100,000 blocks** (~2.3 days) — the asset is dormant;
  this matters only for the exit path (§8).

---

## 5. What an attacker can and cannot do

**Can (all fork-proven):**
1. `WTOMO.deposit{value: VIC}()` for any amount, from any address, no allowlist.
2. Sell WTOMO into any of the 764 live pools with the standard `transfer`+`swap(…)` pattern; outputs match the
   0.4% constant-product model (plus the TRC21 minFee quirk on USDC/HY/USDE/CBC).
3. Repeat across pools. Because every pool was priced off the same 2021 web, the attack is a normal arbitrage
   against a frozen market — not an exploit of a flaw.
4. Extract **$17,792 net** with **113,356 VIC of capital**; the campaign is ~25 swaps, one contract or EOA.
   Gas at the measured 250 gwei is ~0.0006 VIC — economically zero.
5. Optionally keep going (greedy sim) for the last ~$22 of value at a higher VIC cost, or stop earlier:
   route A+B+C alone costs ~107,862 VIC ($483) and banks ~$17.1k.

**Cannot / not worth it:**
- Cannot reach the $2,505 USDT in pair835 (HCC is only traded there), nor the 1.71 USDT in pair29 (DTE/EVND
  component isolated), nor more than ~$674 of pair890 (tETH depth), nor the remaining ~$3.2k of pair2 (LUA depth).
- Cannot extract pair2's USDT without paying for LUA in pair4; pair4's LUA is the binding resource for both the
  USDT and ETH sinks.
- No flash loan needed or used; no lending protocol is live on Viction (DefiLlama lists only LuaSwap, Rabbit Swap,
  Baryon Network, Mori Protocol and deFusion; none offers flash liquidity), but the capital requirement is only ~$507.

---

## 6. PoC & fork verification

- **Project:** `poc/` (Foundry, solc 0.8.24, `via_ir`), vendored `lib/forge-std`.
- **Test:** `poc/test/LuaSwap.t.sol` — forks Viction at the latest head via
  `vm.envOr("VICTION_RPC_URL", "https://rpc.viction.xyz")` (override `FORK_BLOCK_VICTION` to pin).
- **Result (local run, fork block 114,805,650): 13/13 PASS.**

| Test | Proves | Gas |
|---|---|---|
| `test_wtomo_deposit_withdraw_1to1` | mint/burn 1:1, fully open | 53.7k |
| `test_swap_fee_model_matches_0_4pct` | 0.4% fee model fits live pairs | 167k |
| `test_probe_actual_swap_fee` | binary search recovers fee numerator = 4 | 4.37M |
| `test_probe_pair76_fee` | documents the TRC21 minFee (1000) quirk; USDC itself is fee-free | 9.68M |
| `test_recorded_reserves_still_today` | reserves still equal the recorded scan values | 14k |
| `test_A_pair1_direct_usdt` | **+4,734.94 USDT** for 30,109.90 VIC | 150k |
| `test_B_lua_two_hop_usdt_and_eth` | **+4,970.46 USDT + 2.608487 ETH** for 76,902.89 VIC | 338k |
| `test_C_btc_direct` | **+0.00780778 BTC** for 849.3 VIC | 147k |
| `test_D_teth_usdt` | **+673.69 USDT** for 4,335 VIC | 225k |
| `test_E_tai_usdt` | **+129.35 USDT** for 828.7 VIC | 241k |
| `test_F_lec_usdt` | **+14.25 USDT** for 90.68 VIC | 218k |
| `test_G_small_routes` | **+18.60 USDT + 0.010093 ETH** for 217.3 VIC | 1.46M |
| `test_full_campaign_net_value` | **campaign: 113,356.47 VIC → gross $18,299.49 → NET $17,792.16** | 2.32M |

- **Run IDs / CI:** see `ci-log.txt` and `summary.json` (`ci_run_urls`). The workflow runs
  `luaswap/ci/run.sh` (Viction RPC probe + read-only state snapshot into `ci-out/viction-state.json`) and then
  `forge test -vvv`.
- **Notable PoC details:** the pair code applies a TRC21 `getTransferFee` (constant minFee) to some transfers and
  queries `factory.swapFee()` live; the test models both, adds a ≤0.2% safety margin per swap, and still banked
  $17.79k net. All assertions use conservative floors; nothing was sent to mainnet.

---

## 7. Verdict and residual risk

- **Verdict:** the C2-04 surface is **live, permissionless and economically material**. A fresh address with
  ~$507 of VIC can net ~$17.8k today with standard AMM calls. The state has been frozen for hours-to-days
  (zero reserve changes across all pairs), so this is not a race.
- **Residual/latent upside (excluded from headline):**
  - 0.694 tETH in pair891 can be bought for ~$19 of VIC; the token is "TomoChain-ETH" (supply 11.835). If the
    legacy bridge still redeems tETH at ETH parity, that is an extra **~$1.8k**; if not, selling it back for USDT
    in pair890 yields the ~$674 already counted.
  - WBTC candidates `0x503b2ddc…` (0.004633 in pair780, buyable with ~$19 of VIC → ~$376) and `0xa9189563…`
    (0.005738 in pair751 → ~$466) if either is canonical. Multiple tokens use the WBTC symbol on Viction, so
    identity was not asserted.
  - The frozen pools will re-price instantly if anyone ever trades them with fresh capital; the opportunity is
    first-come and can be taken by anyone watching (including the original LP set).
- **Blockers/risks:**
  1. **Exit risk (the main one):** extracted USDT/ETH/BTC are legacy TomoBridge-era assets. On-chain
     transferability is proven; the legacy→native exit leg is not. The USDT token has zero transfers in the last
     100k blocks (no secondary market). Viction's docs state the bridge supports USDT/ETH/USDC, but the exact
     mapping to `0x381b31…` was not verified end-to-end. A realistic attacker would need to bridge or OTC-sell;
     face-value realization may be at a discount.
  2. The PoC's per-swap output margin costs ≤0.2%; a precise attacker can do slightly better.
  3. The extracted LUA/TAI/other intermediates are left in pools as expected (they are the payment), not a loss.

---

## 8. Methodology & sources

- **Enumeration:** full-history `eth_getLogs` of `PairCreated` on the factory (1,555 pairs), then batched
  `getReserves()` (764 live pools), token `symbol/decimals/name/totalSupply` reads; two independent scans
  (blocks 114,799,532 and 114,804,371) to bound drift.
- **Pricing:** DefiLlama `coins.llama.fi` (VIC/WTOMO $0.004475563; ETH $2,707.786; BTC $85,513.65; stables $1.00),
  timestamp recorded in `summary.json`.
- **Extraction modelling:** two independent methods — (a) exact integer constant-product math with the live 0.4%
  fee and per-route/numeric joint optimisation (`analysis/plan.py`), and (b) a marginal-step greedy over all 115
  valid routes with shared-pool depletion (`analysis/extract_sim3.py`). They agree to 0.1%
  ($17,792 vs $17,814 net).
- **Execution proof:** local Foundry fork + CI fork (`poc/`), 13 tests. No private keys, no mainnet writes.
- **Caveats:** USD figures are point-in-time; the on-chain extraction is the high-confidence part, the exit is
  not; pools could be re-priced by a third party at any time (that would close, not worsen, the opportunity).
  Deeper details, negative results (HCC circular, DTE circular, dust pools) and raw data are in `analysis/`.

## 9. Files index

| File | Purpose |
|---|---|
| `README.md` | this report |
| `summary.json` | machine-readable summary (E-U/H-O/P/S, CI URLs) |
| `analysis/scan_pairs.py`, `scan_pairs_latest.py` | full factory pair scanner (2 runs) |
| `analysis/pairs_raw.json`, `pairs_raw_latest.json` | raw pair/token dumps (blocks 114,799,532 / 114,804,371) |
| `analysis/pairs_summary.csv`, `pairs_summary_latest.csv` | flat reserve tables |
| `analysis/extract_sim.py` | reachability + gross-value census |
| `analysis/extract_sim3.py`, `sim3_final.log` | marginal-step greedy extraction simulation |
| `analysis/plan.py` | exact static execution plan (amounts used by the PoC) |
| `poc/` | Foundry project + `test/LuaSwap.t.sol` (13 tests) |
| `ci/run.sh`, `ci-out/viction-state.json` | CI RPC probe + read-only state snapshot |
| `ci-log.txt` | downloaded CI log (run URL in `summary.json`) |

*Research is informational; verify all data on-chain before acting. No mainnet transactions were sent.*
