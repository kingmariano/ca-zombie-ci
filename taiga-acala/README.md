# Taiga Acala (tapio / tDOT stable pool) — L2 Phase-2 deep dive

**Date:** 2026-10-11 · **Chain:** Acala (Substrate, parachain 2000) · **Status:** read-only; no transactions; no secrets; CI-verified at public RPC blocks **12,188,628** and **12,188,690** (two runs, identical verdict).

**One-line:** The "Taiga" custody the triage flagged (`23M5ttkp2zdM8qa6LFak4BySWZDsAVByjepAfr7kt929S1U9`) is the **StableAsset pallet account** (`modl nuts/sta`) holding **pool 0's** reserves — a **DOT/LDOT stable pool whose LP token is tDOT ("Taiga DOT")**. Every value-moving extrinsic on the pool currently **reverts** (the pool is bricked by a 2.87 % drop in the Homa LDOT exchange rate on 2026-09-22), so **external unprivileged extraction = $0**; the ~$270 k–$369 k inside is stuck (S) pending rate recovery. The triage's **$1,405,835 headline is a pricing error** (LDOT was valued at DOT parity; LDOT is worth ≈ 0.19 DOT at the Homa redemption rate).

---

## 1. TL;DR

| Target | Live extractable (unprivileged) | Why closed/open | Latent risk |
|---|---|---|---|
| StableAsset pallet account `23M5ttkp2zdM8qa6LFak4BySWZDsAVByjepAfr7kt929S1U9` (pool 0 = DOT/LDOT, LP = tDOT) | **$0** | `collect_yield()` gate: D(updated) = 298,289.71 < total_supply = 303,965.21 (deficit 5,675.50 DOT-eq). All 5 user extrinsics (mint/swap/redeem_proportion/redeem_single/redeem_multi) call `collect_yield` → revert `InvalidPoolValue`. | If the Homa rate recovers ≥ 0.197178032 (+2.87 %), the pool re-opens: tDOT holders can redeem (H-O, not E-U). A ~$100 one-time `redeem_multi` imbalance discount exists only after re-opening. No tDOT market exists. |
| Admin/upgrade authority | **$0** | `create_pool`/`modify_a`/`modify_fees`/`modify_recipients` require root or half General Council and **cannot move assets**. `Sudo.Key` is the pallet account `modl aca/trsy` → sudo is unusable. No rescue/force-withdraw call exists in the deployed pallet. | Governance runtime upgrade could in principle add a rescue path (P — not counted). |

**Total live extractable now: $0 (E-U) — confidence: high.** Stuck value: **$369,259.36** at protocol-fundamental pricing (range ≈ **$269,837.69 – $369,259.36** using the only market quote; see §5.2).

---

## 2. What the target actually is (correction of the triage label)

The triage row called the account a "tapio LSD" module account. On-chain decoding shows it is the **`StableAsset` pallet account** of Acala runtime spec 2370:

* Account pubkey = `6d6f646c` + `6e7574732f737461` (`modl` + `nuts/sta`) + 24 zero bytes = `PalletId(*b"nuts/sta")` (`StableAssetPalletId`, `runtime/acala/src/lib.rs` L189). This is the pooled-asset account of the **Taiga stable-swap pallet** (`nutsfinance-stable-asset`, Acala tag **2.37.0** pins submodule commit `aa101e87…`, the exact revision audited here).
* `StableAsset.PoolCount = 1`; `Pools[0]` = **DOT/LDOT** pool; LP token `StableAssetPoolToken(0)` = **tDOT** ("Taiga DOT", 10 dp, asset-registry metadata).
* The pallet account holds pool 0's reserves. (Taiga's "tapio" brand = the tDOT LSD product; the LP token is what the triage mis-read.)

The pallet's math for LDOT goes through Acala's **rebase combiner**: `RebaseTokens = orml_tokens::Combiner<IsLiquidToken, Mapper<Currencies, ConvertBalanceHoma>, Currencies>` — every LDOT balance the pallet sees is `raw_LDOT × Homa_exchange_rate` (DOT-equivalent, 10 dp), and LDOT transfers in/out are converted back by floor division. This is what links the pool's solvency to Homa's exchange rate.

**Deployed-code verification (three independent fingerprints).** The runtime spec version on-chain is **2370** = Acala release tag `2.37.0`, which pins `ecosystem-modules/stable-asset` at `aa101e87234bd3d388c8de062f231d635d79cf7b`. My Python re-implementation of the pallet invariant (`get_d`, `get_y`, fees) reproduces:

1. `D(stored balances) == Pools[0].total_supply` **to the unit** (3,039,652,087,142,047);
2. at the last swap (block 12,048,434) the model's output amount **equals the on-chain event** exactly (2,261,908,216,954 raw DOT), and the supply delta equals `FeeCollected.amount` exactly (5,718,334,393);
3. same equality holds at the pre-swap block (12,048,433).

→ the deployed gate code is the audited revision; the revert conclusion is not a code-mismatch artifact.

---

## 3. The mechanism that closes the pool (exact gate)

Deployed pallet (`aa101e87`), `collect_yield()` is called at the start of **every** user path:

```
update_balance(pool)         // pool_info.balances[i] = Assets::balance(asset_i, pool_account) * precisions[i]
new_d = get_d(balances)      // stableswap invariant over converted balances
old_d = pool_info.total_supply
ensure!(new_d >= old_d, Error::InvalidPoolValue)   // <-- the gate
```

* `Assets::balance(LDOT, pool_account) = floor(raw_LDOT × rate)`, `rate = TotalStakingBonded / (LDOT_total_issuance + TotalVoidLiquid)` (FixedU128 floor).
* At the last successful interaction (2026-09-21 19:40 UTC, block 12,048,434) the rate was **0.197178032**; the stored balances and supply were written at that rate (D == supply exactly).
* Since 2026-09-22 the rate has been **below** that value (crash to 0.190746, now 0.191685455). With the same raw balances, D(updated) is now **298,289.7093946633** < supply **303,965.2087142047** → deficit **5,675.4993195414 DOT-eq (56,754,993,195,414 raw)** → `collect_yield` returns `InvalidPoolValue` → **mint, swap, redeem_proportion, redeem_single, redeem_multi all revert**.

`InvalidPoolValue` is also the first error hit (before any balance/fee logic), so the failure is deterministic and independent of caller, amount, or slippage parameters.

**Timeline (archive-state forensics, block-exact):**

| UTC | Block | Event |
|---|---|---|
| 2026-09-21 ~19:30 | 12,047,663 | Homa era 2302 bump; LDOT burned/withdrawn 25,837.38 LDOT for 5,094.57 DOT unbond; rate reaches all-time high **0.197178032** |
| 2026-09-21 19:40 | **12,048,434** | **Last successful pool interaction** — `stableAsset.swap(0, 1→0, dx=230.0762 LDOT-eq, min_dy=225.9646 DOT)` by `24mTvAxyVzTpVBTkMLchwBNx4oMSQdbgeLPVa16Lzm1kvRyk`; 1,166.845 raw LDOT in, 226.1908 DOT out; fee 5,718,334,393 raw tDOT minted to the fee recipient |
| 2026-09-22 ~01:11 | 12,051,373 | `homa.LedgerBondedReset{subAccount 0, newBonded=1,948,711.4997 DOT}` — **−65,708.32 DOT** vs Homa's recorded staking → rate crashes to **0.190746** |
| 2026-09-22 → today | — | rate never recovered above 0.197178032; pool has been non-interactive for **19+ days** (no pool state change since 12,048,434) |
| 2026-10-11 14:48 / 15:02 | 12,188,628 / 12,188,690 | rate 0.191685455 (+2.87 % short of the gate) — CI re-verification, two runs |

The rate is currently **rising** (~+0.035 %/day observed since 09-27: LDOT burns from Homa redemption processing plus staking rewards; 0.190746 on 09-27 → 0.191685 on 10-11). At that pace the gate clears in ~3 months; if the pending Homa redemption flow (236,862 DOT claimable `UnclaimedRedemption`, 54,020 DOT unbonding) completes with LDOT burns, materially faster. Conversely further `LedgerBondedReset` drops would delay it.

---

## 4. Live-state assessment (Acala block 12,188,690, 2026-10-11 15:02 UTC; CI artifact — first run at block 12,188,628 identical)

**Pallet account `23M5ttkp2zdM8qa6LFak4BySWZDsAVByjepAfr7kt929S1U9`** (`modl nuts/sta`), nonce 0, never signs:

| Asset | Raw | Amount | Note |
|---|---|---|---|
| DOT (`Token(2)`) | 993,810,871,531,292 | **99,381.0871531292** | liquid, priced $1.23665 |
| LDOT (`Token(3)`) | 10,392,844,659,613,585 | **1,039,284.4659613585** | = 199,215.7158 DOT-eq at the Homa rate |
| PINK (`ForeignAsset(13)`) | 3,837,129,980,808,646 | 3,837.129980808646 | unpriced/illiquid (no DEX pair) — excluded from totals |
| ACA | 5,907,970,449,812 | 5.907970449812 | dust |

**Pool 0** (`StableAsset.Pools[0]`, key `0xdf6d686c…b500000000`): assets `[Token DOT, Token LDOT]`; precisions `[1,1]`; fees mint 0 / swap 0.25 % / redeem 0.3 %; A=30 (3000/APrecision 100); total_supply **303,965.2087142047** tDOT; balances `[99,381.0871531292, 204,924.0653489222]` (DOT-eq); `fee_recipient = yield_recipient = 23AdbsfTWCWtRFweQF4f3iZLcLBPwSHci9CXuMhqFirZmUZj` (= EVM-mapped `evm:081efb42231fca2cfa81cdedb6b68433ce61c486`); `account_id` = the pallet account (pool 0's sub-account derivation collapses to it).

**Homa** (rate source): `TotalStakingBonded` 1,930,696.4240444358 DOT; `LDOT total_issuance` 10,072,211.3901338099; `TotalVoidLiquid` 0 → rate = **0.1916854550864132** (raw 191,685,455,086,413,192). Homa pallet account `23M5ttkmR6Kco5pqN691bGfU3BhfU6QPG9arw6SR1XpNuQqu` holds 236,862.056 DOT (`UnclaimedRedemption`) + 414.17 LDOT escrow.

**Gate math (CI-reproduced):** D(stored) = 3,039,652,087,142,047 (**== supply**); D(updated) = 2,982,897,093,946,633; deficit = 56,754,993,195,414 raw = **5,675.4993195414 DOT-eq ≈ $7,019.6**; min rate for interactivity = **0.19717803167524825**; gap = **+2.8654 %**.

**tDOT holders (full enumeration, 364 entries, 100.0 % of issuance):** top holder `23AdbsgD7HB7ZJJiNiHuJmQn9CA3FyGVoyTk7iDjfjc3dtD8` (EVM `0xe1bd4306a178f86a9214c39abcd53d021bedb0f9`) = **255,276.5361 tDOT (84.0 %)**; top-5 = 93.7 %; top-20 = 97.9 %; 127 holders < 1 tDOT. Module accounts: `Loans` (`modl aca/loan`) 4,184.81; legacy `aca/reco` 479.11; fee/yield recipient 24.97.

**Markets:** all DEX pairs for tDOT are `Disabled` (no tDOT market). The only LDOT venue is the Acala DEX `AUSD/LDOT` pool: 95,881.5131 AUSD / 19,529.5762 LDOT (≈ 4.9096 AUSD/LDOT); second pool `LDOT/Erc20 0xa7fb…` holds 52.0 LDOT. DefiLlama's adapter (`tapio.js`) reads exactly this pallet account (DOT + LDOT) but its LDOT leg is unpriced in DefiLlama's coin API (current chain TVL ≈ DOT leg only, ~$121.7 k), which is why the triage's DefiLlama cross-check looked small.

**Authority:** `Sudo.Key = 23M5ttkmR6KcoTAAE6gcmibnKFtVaTP5yxnY8HF1BmrJ2A1i` = `modl aca/trsy` (HomaTreasury pallet account, no private key → sudo unusable). General Council = 3 members. No emergency pause is set on the pool (the pallet has no pause switch in this revision).

---

## 5. What an attacker can / cannot do

### 5.1 Closed paths (all verified against deployed code + live state)

| Path | Result | Evidence |
|---|---|---|
| `stableAsset.mint` / `swap` / `redeem_proportion` / `redeem_single` / `redeem_multi` | **Revert `InvalidPoolValue`** (gate) | §3; all five call `collect_yield` first (`lib.rs` L1617, 1692, 1764, 1852, 1941) |
| `Tokens.transfer` out of the pallet account | impossible — pallet account has no signer | nonce 0, `modl`-derived key |
| `create_pool` / `modify_a` / `modify_fees` / `modify_recipients` | privileged (root / half General Council), **move no assets** | `ListingOrigin = EnsureRootOrHalfGeneralCouncil` |
| Sudo | unusable (key = pallet account `modl aca/trsy`) | `Sudo.Key` read on-chain |
| XCM / teleport | pallet account cannot sign XCM messages; no pallet code sends these assets via XCM | pallet has no XCM calls; `orml_xtokens` requires signed origin |
| EVM / precompiles | no precompile touches `StableAsset`; tokens have ERC-20 precompiles only for their own holders | Acala runtime precompiles list; public RPC exposes no `eth_` namespace |
| Donation to un-brick | possible (transfer DOT/LDOT **to** the account), but the D surplus is minted as yield tDOT to the **yield recipient** on the next interaction → donor loses the donation; no extraction | `collect_yield` mints `new_d − old_d` tDOT to `yield_recipient` |

### 5.2 Latent path if/when the gate clears (quantified, not E-U today)

* **H-O:** tDOT holders (364 accounts) can then redeem pro-rata (~0.327 DOT + 3.42 LDOT per tDOT ≈ $0.89–$1.22 per tDOT).
* **`redeem_multi` imbalance discount:** withdrawing the overweight LDOT side pays `ΔD` (below the linear amount). Modelled maximum ≈ **86 DOT-eq (~$106)** one-time at x ≈ 50 k LDOT-eq; it shrinks as the pool re-balances (CI artifact `results.json → latent_redeem_multi`). Not material.
* **Market arb:** the pool prices LDOT at the Homa rate (~0.19 DOT), while the only market (AUSD/LDOT DEX pool) implies ~$0.17–0.24/LDOT at best, with **only ~19.5 k LDOT depth** — far too thin to drain the pool's 99.4 k DOT side; and unreachable while bricked.
* The pool's internal LDOT price exceeds *market* LDOT if the market quote ($0.141) is taken at face value; even then, realizable extraction is bounded by market depth (≤ ~$3–5 k of LDOT acquirable) and requires the gate to clear first.

### 5.3 Costs / preconditions
Nothing is executable now; gas/flash costs are moot. The only "precondition to open" is the Homa rate reaching **0.197178032 (+2.8654 %)**, or a governance runtime change.

---

## 6. PoC / verification (CI)

No Foundry project (Substrate chain, no EVM path). Heavy job: **`ci/run.sh` → `ci/taiga_ci.py`** (pure Python, public RPC only) run on GitHub Actions:

* **CI runs:** https://github.com/kingmariano/ca-zombie-ci/actions/runs/38148650658 (block 12,188,628) and https://github.com/kingmariano/ca-zombie-ci/actions/runs/38149486584 (block 12,188,690) — both success; branch `taiga-acala`; artifact `result-taiga-acala`. `ci-out/` holds the second run's files; the first run's verdict was identical (value $369,458.19 vs $369,259.36, a 0.05 % DOT-price drift).
* Checks performed at block 12,188,690 (all pass):
  1. state snapshot + PoolInfo byte-exact decode (`consumed == len`);
  2. gate math: `D(stored) == supply`; `D(updated) < supply`; deficit + min-rate bisection;
  3. archive timeline: last-change block = 12,048,434 (state frozen since);
  4. **full tDOT holder enumeration** (160,556 `Tokens.Accounts` keys scanned → 364 holders, Σ = issuance exactly);
  5. valuation + price fetch.
* Artifacts: `ci-out/results.json`, `ci-out/state.json`, `ci-out/tdot-holders.csv`, `ci-out/ci-run.log` (also copied to `ci-artifacts/result-taiga-acala/ci-out/`).
* Local reproduction scripts in `analysis/` (all read-only, public endpoints only): `fetch_state.py`, `pool_math.py` (+`pool-math-out.txt`), `archive_forensics2.py` (+out), `key-events.json`, `probe2/3/4-out.json`, `last-interaction-out.txt`.

**Key numbers reproduced:** gate deficit 5,675.4993195414 DOT-eq; min rate 0.19717803167524825; holders 364; top-1 84.0 %; value $369,259.36 (fundamental).

**Dry-run limitation (documented):** Acala's public RPC exposes `system_dryRun`, but Substrate dry-runs require a freshly signed extrinsic; the campaign rules forbid signing on mainnet, and keyless alternatives (`TransactionPaymentCallApi_query_call_info`) do **not** execute the call. The gate is therefore proven by (a) the deployed revision pin + behavioral fingerprints, (b) exact invariant reproduction, (c) archive-state timeline. The frozen pool state since 12,048,434 (19+ days, 0 interactions) is consistent.

---

## 7. Verdict

* **E-U = $0 (high confidence).** No external unprivileged path moves value out of the pool today: all five user extrinsics deterministically revert at the `collect_yield` gate; no admin/withdraw/rescue extrinsic exists; sudo is unusable; no XCM/EVM path; donations only add value that accrues to the yield recipient.
* **S = $369,259.36** (protocol-fundamental; **range $269,837.69–$369,259.36** market) is currently **stuck**: nobody — not even tDOT holders — can redeem while the rate is below 0.197178032.
* **H-O = $0 today** (would become ≈ the same amount for the 364 tDOT holders if/when the gate clears). **P = $0** (governance can only act via a runtime upgrade; no direct rescue call).
* **Triage correction:** $1,405,834.90 → **$369,259.36** fundamental (LDOT priced at 0.191685 DOT via Homa, not DOT-parity). Token amounts unchanged since triage; only the pricing was wrong (LDOT ≈ $0.2370 fundamental / $0.1414 last market quote, not $1.2346).
* **Residual/latent risk (medium):** if the gate clears (Homa rate recovery or governance), the pool re-opens; then (i) tDOT holders redeem pro-rata, (ii) a ≤$106 one-time `redeem_multi` concavity discount is available, (iii) a thin-market arb exists but is depth-bounded. Nothing here is extractable now.
* **Blockers to re-opening:** Homa rate +2.87 % (currently ~+0.035 %/day observed, uncertain), or governance action; further Homa `LedgerBondedReset` reductions would delay it further.

## 8. Methodology & sources; caveats

* **Method:** public Substrate JSON-RPC (`https://acala-rpc-0..3.aca-api.network`) reads at explicit blocks; archive `state_getStorage` at historical block hashes for the timeline; `state_getKeysPaged` full `Tokens.Accounts` scan; exact re-implementation of `nutsfinance-stable-asset@aa101e87` + Acala `2.37.0` rebase math; Acala repo clone + submodule pin verification; DefiLlama/CoinGecko price APIs; GitHub Actions for the heavy scan.
* **Corpus corrections applied:** the triage's "tapio LSD module account" label and the DOT-parity LDOT proxy are both wrong; DefiLlama's TVL excludes the LDOT leg.
* **Caveats:** (1) LDOT pricing is genuinely uncertain: fundamental = Homa redemption rate 0.191685 DOT ($0.2370); the CoinGecko id `liquid-staking-dot` returns $0.1414 on `/simple/price` but **does not resolve** on `/coins` (not a canonical listing), and the only on-chain market is thin — treat $269.8 k as a low-end estimate. (2) The revert conclusion relies on the deployed revision = tag 2.37.0 (spec 2370 + submodule pin + three exact behavioral fingerprints); a hypothetical silent runtime patch inside spec 2370 cannot be fully excluded without a fresh signed dry-run. (3) `PINK` (3,837.13) is excluded from totals (no market). (4) Rate recovery pace is extrapolated from 19 days of samples.

## 9. Files index

```
taiga-acala/
├── README.md                     # this report
├── summary.json                  # machine-readable summary
├── ci/run.sh, ci/taiga_ci.py     # CI heavy job (state + gate + holder scan)
├── ci-out/                       # CI results (results.json, state.json, tdot-holders.csv, ci-run.log)
├── ci-log.txt                    # full GitHub Actions log
├── ci-artifacts/result-taiga-acala/ci-out/   # downloaded artifact copy
└── analysis/
    ├── fetch_state.py / state-12188215.json  # first full state snapshot (raw+decoded)
    ├── fetch_state.js / state-node.json      # polkadot-js cross-check
    ├── probe2/3/4-out.json                   # oracle, DEX pools, homa ledgers, asset metadata
    ├── pool_math.py / pool-math-out.txt      # invariant + gate reproduction
    ├── archive_forensics2.py / archive-forensics2-out.txt  # last-change + rate trajectory
    ├── last-interaction-out.txt, tsb-crash-out.txt
    └── key-events.json                       # block-exact events: era bump, last swap, rate crash
```

*Public CI repo: `github.com/kingmariano/ca-zombie-ci`, branch `taiga-acala`, runs [38148650658](https://github.com/kingmariano/ca-zombie-ci/actions/runs/38148650658) and [38149486584](https://github.com/kingmariano/ca-zombie-ci/actions/runs/38149486584).*
