# Pact (Algorand AMM) — legacy pool custody / extraction assessment

**Date:** 2026-10-10 · **Chain:** Algorand mainnet · **Status:** read-only; no transactions sent; no dryrun executed (public nodes return 404 for both dryrun paths — see §6).
**Round:** pool list + reserves at algod round **65,847,980** (top-30 dump at 65,847,915; every dump carries its own `round` field). **Prices:** coins.llama.fi (2026-10-10): ALGO $0.1154, gALGO $0.1173, USDC $0.9997, goBTC $82,081.71, goETH $2,490.32.

**Target set — exhaustive for this API:** `https://api.pact.fi/api/internal/pools_details/all` (the exact source the DefiLlama adapter `projects/pactfi.js` uses) returned **4,008 pools** on 2026-10-10:
- **v100 "classic" family: 3,867 pools — all flagged `is_deprecated: true` — API TVL $495,982.49** (pool types: CONST 3,826; STBL 41).
- **v201 "managed weighted" family: 141 pools — live — API TVL $428,576.46**.
- Total **$924,558.95** (matches the DefiLlama `pact-fi` TVL of ~$898k within normal staleness).

Pool IDs, escrow addresses and per-asset reserves are in `raw/pact_pools_api_2026-10-10.json`; on-chain reserve dumps: `raw/pact_top30_reserves.json`, `raw/pact_deprecated_ge1000_reserves.json`.

---

## TL;DR

| Segment | Live reserves (on-chain verified) | USD | Classification | Gate |
|---|---|---|---|---|
| Classic pools (v100, deprecated), reserve held in pool app escrow | top-54 (≥$1k) verified; sample matches API within ~2% | **$495,982.49** (API; 89% of it on-chain verified in USD at $440.7k API/`$367.3k` measured — pricing gaps for exotic tokens) | **H-O** for LP holders (pro-rata `REMLIQ` works; LPs outstanding = `L`−1000 locked) | `gtxn[-1]` axfer of LP asset `LTID` → app; admin keys otherwise |
| v201 managed-weighted (141 pools) | reserves held in shared vault app `3656084807` (1,370,283.908260 ALGO (r65,848,046) + 92,423.822096 USDC + ~20 more assets); per-pool escrow holds only unminted LP | **$428,576.46** (API) | **H-O** for LP holders; **P** for per-pool `manager` / factory admin | manager/factory (Pact team keys) |
| **Total** | | **$924,558.95** | | |

**E-U proven today: $0.** No unprivileged path was found that lets an attacker take reserves without holding LP tokens. One **live weakness**: min-out/slippage arguments are silently discarded (`pop`) in `SWAP`, `ADDLIQ` and `REMLIQ` — direct swappers on classic pools (still actively traded) are exposed to MEV sandwich extraction. It leaks value from swappers, it does not drain the pool.

---

## 1. Deployed-code audit (TEAL from algod, disassembled via algod /v2/teal/disassemble)

### 1.1 Classic CONST template — app 1073557308 (pragma v8; same template for the 3,826 CONST pools)
Methods (ApplicationArgs[0]): `OPTIN, CLT, SWAP, ADDLIQ, REMLIQ, WITHDRAWFEES, CHANGE_ADMIN, CHANGE_TREASURY, CHANGE_PACT_FEE`.
- `CLT` (create LP asset, once): `txn Sender == global CreatorAddress`.
- `SWAP`: requires gtxn[-1] = `axfer` of asset A or B to app (asset id, receiver, no close/rekey checks) then constant-product math: `out = B·in/(A+in)` (mulw/divw 128-bit), LP fee retained (`FEE_BPS`), pact fee `PACT_FEE_BPS` subtracted from tracked reserves → excess sent to `TREASURY` by `WITHDRAWFEES` (callable by anyone, funds only to treasury).
- `REMLIQ`: requires gtxn[-1] = `axfer` of `LTID` to app **from the same sender**; asserts `L != 0`; `outA = amt·A/L`, `outB = amt·B/L`; sends both to sender. Verified on-chain: e.g. pool 2757646117 saw 13 successful `REMLIQ` (rounds 50,264,189–50,929,983) and 33 `ADDLIQ`.
- `CHANGE_ADMIN`/`CHANGE_TREASURY`/`CHANGE_PACT_FEE`: `txn Sender == ADMIN` (both sampled pools ADMIN = `KIRIMYBSL4EH4UQUUGBOG4S5RLBRJPJK4LG4SCFS6AXK2YCQDULANQH7V4`); `CHANGE_PACT_FEE ≤ FEE_BPS/2`.
- **Slippage bug:** min-out args are read, subtracted and **`pop`-discarded** — e.g. SWAP: `load 13; txna ApplicationArgs 1; btoi; -; pop` (no `assert`). Same pattern in ADDLIQ and REMLIQ. `minOut` is therefore not enforced.
- Creation path asserts `OnCompletion == NoOp` for calls and only allows create/opt-in paths → the programs are not updateable/deletable through the program (update/delete OC rejected). Immutability verified by the code path reached for ApplicationID≠0.

### 1.2 Classic STBL template — app 985089418 (pragma v6; 41 stableswap pools)
Same method family plus `RAMP_A`/`STOP_RAMP_A` (ADMIN-gated). State `A, FUTURE_A, INITIAL_A/FUTURE_A_TIME` (amortised A ramp, e.g. 5000→10000), `PRIMARY_FEES`/`SECONDARY_FEES`. `REMLIQ` identical LP verification and math as CONST (`amt·A/L`, `amt·B/L`); same discarded min-out checks. Admin gates `txn Sender == ADMIN` (same admin address as CONST pools).

### 1.3 v201 managed-weighted + vault (141 pools)
Per-pool app (e.g. 3662410374): state `manager, weight_a, swap_fee_bps, protocol_fee_bps, vault, factory, reserve_a/b, issued_lp, must_allowlist`. Reserves are **not** in the pool escrow (escrow holds only unminted LP supply + 0.2 ALGO); they sit in the shared vault app **3656084807** (escrow: **1,370,283.908260 ALGO** [r65,848,046], USDC 92,423.822096, goBTC 0.17144235, goETH 0.88523627, SILVER$ 906.311450, GOLD$ 3.193476, ASASTATS 191.36B, Finite 10.46B, Vote 55.06B, … tokens). Vault admin / staking_manager / fee_collector = Pact team addresses (`eAUyolM…`, `eAUyoaJ…`); factory 3656084442 (`admin=contract_manager`, `paused=0`, `deployed_count=145`). This is the live v2 product; manager roles are **P**.

---

## 2. Live reserves — verified samples (raw amounts, round cited)

| Pool | Type | API TVL | On-chain escrow |
|---|---|---|---|
| 985089418 (STBL, dep) | ALGO–gALGO | $57,013.14 | 246,966.268912 ALGO + 250,239.656438 gALGO |
| 1073557308 (CONST, dep) | ALGO–USDC | $52,411.62 | 227,050.392196 ALGO + 26,235.932523 USDC |
| 2757646117 (CONST, dep) | ALGO–Finite | $41,070.74 | 177,951.317210 ALGO + 304,578,393.900083 Finite |
| 1116363704 (CONST, dep) | fALGO–fUSDC (v2 fAssets) | $35,729.48 | 132,702.264155 fALGO + 14,306.740305 fUSDC |
| 2757488616 (CONST, dep) | ALGO–USDC | $33,698.45 | 145,913.753360 ALGO + 16,875.152319 USDC |
| 1205810547 (STBL, dep) | ALGO–mALGO | $25,057.97 | 108,536.475873 ALGO + 69,019.214671 mALGO |
| 3662410374 (v201, live) | MWP ALGO–USDC | $126,916.58 | 0.2 ALGO (reserves in vault) |

Aggregate check: the 54 deprecated pools with API TVL ≥ $1,000 sum to **$440,723.43** API (89% of the $495,982.49 classic subtotal); their measured on-chain value = **$367,328.87** at 2026-10-10 prices (difference = unpriced exotic tokens and fAsset/LP residues, e.g. fgoETH held by classic pools). Every large pool matches within pricing noise. LP backing: e.g. pool 985089418 LP asset 985089595 outstanding 232,313,819,999 = `L` 232,313,820,999 − 1,000 locked; pool 1073557308 outstanding 52,247,289,907 = `L` − 1,000; pool 2757646117 outstanding 7,079,185,520,029. Pools are **actively traded**: direct `SWAP` calls e.g. 985089418 round 64,001,345; `swapmixed` router calls at round 64,001,133; 254 SWAPs on 985089418 and 632 on 1073557308 within the first 1,000 txns after round 50M.

## 3. Candidate unprivileged paths tried and outcomes

1. **Take reserves without LP** — `REMLIQ`/`SWAP` require the LP axfer / asset-in; no other path sends reserves to a caller. → **closed**.
2. **Fake LP asset** — `gtxn[-1] XferAsset == LTID` assert. → **closed**.
3. **Change admin / fee** — `txn Sender == ADMIN`. → **closed (P)**.
4. **Withdraw protocol fees to self** — `WITHDRAWFEES` computes `balance − reserves` and pays the stored `TREASURY` only (sender-independent). → **closed**.
5. **Slippage-arg abuse (live)** — min-out args discarded (`pop`) ⇒ a searcher can sandwich a swapper who passes a min-out bound. Classic pools still receive swaps (r64M+), so this is a live but flow-dependent MEV leak, not a pool drain. → **open (low severity)**.
6. **LP redeemability** — `REMLIQ` verified by TEAL + historical success (13× on 2757646117; 2× on 985089418). → **open (H-O)**.

## 4. Classification summary

- **E-U:** $0 of pool reserves directly extractable; live MEV leak via ignored min-out (unquantified, victim-flow-bounded).
- **H-O:** **$495,982.49** classic-family LP claims (pro-rata burn of LP against escrow reserves) + **$428,576.46** v201 LP claims → **$924,558.95** total LP-recoverable custody (holder-initiated).
- **P:** classic ADMIN key (`KIRIMYBSL4EH4UQ…`) admin methods; v201 per-pool `manager`, vault/factory admin (Pact team).
- **S:** none identified (no pool found where `REMLIQ` is structurally blocked; all sampled pools functional).
- **Confidence:** high for totals/mechanics on the verified top-54 (89% of deprecated subtotal) and for the TEAL gates; medium for the residual 3,813 sub-$1k pools (individually <$1k, assumed same templates); medium for the stableswap curve math (dispatch/gates/REMLIQ/fee logic audited; full N-coins invariant review = CI candidate).

## 5. Blockers / dead ends
- **Dryrun disabled:** `POST /v2/transactions/dryrun` and `/v2/teal/dryrun` return **404** on mainnet-api.algonode.cloud and mainnet-api.4160.nodely.dev; `POST /v2/transactions/simulate` works but requires a funded sender (no state injection), so gate proofs are static TEAL + historical on-chain successes. CI candidate: algokit/local-node dryrun for `REMLIQ` positive test.
- Full escrow sweep of all 3,867 deprecated pools not run (heavy; ≥$1k subset covers 89%); remaining pools are dust (<$1k each) → **CI candidate** script provided.
- Pact docs contain no legacy-address table; enumeration relied on the official API + on-chain verification (documented above).

## 6. Files
- `raw/pact_pools_api_2026-10-10.json` (4,008 pools, complete)
- `raw/pact_top30_reserves.json` (top 30 by TVL, incl. v201 + deprecated)
- `raw/pact_deprecated_ge1000_reserves.json` (54 deprecated pools ≥$1k, on-chain escrow balances)
- `raw/pact_teal_1073557308.txt` (CONST template disassembly), `raw/pact_teal_985089418.txt` (STBL template)
- `scripts/fetch_pact_reserves.py` (reproducible keyless enumeration + reserve verification)
