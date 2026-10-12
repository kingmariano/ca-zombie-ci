# Lenfi (ex-Aada Finance) — Cardano — L2 Phase-2 deep dive

**Date:** 2026-10-12 · **Chain:** Cardano mainnet · **Status:** read-only; no transactions sent. All verification is chain-native *evaluation* (CEK) of on-chain script bytes against constructed script contexts, using keyless public APIs (Koios, DefiLlama).

**Triage input (l2-triage-c, `lenfi`):** "$155,400 live — 586K ADA in Cardano v1+v2 Plutus scripts; UTxO script validation unexplored". This deep dive re-derived the target set from deployment transactions (the triage list was incomplete), decoded every live UTxO/datum, decompiled every script, and CEK-proved the spend gates.

**Headline: live custody is $166,619 across V1+V2, but external unprivileged extraction is ~$0.00 (high confidence).**

---

## 1. TL;DR

| Target (validator) | Live value | Extractable by unprivileged attacker? | Why closed | Latent risk |
|---|---|---|---|---|
| **V1 `interest_v1`** (0x92862d28…) repaid loans awaiting lender claim | 567,513.79 ADA + tokens = **$143,665** (74 UTxOs) | **No** | Spend accepted iff tx burns exactly `-1` of `(lenderNftCs, datum.lenderNftTn)`; NFT names bound to `sha256(idx‖txid)` of a consumed UTxO → unforgeable (CEK 12/12). No payout check — funds follow the NFT. | 14 of 74 gate NFTs (backing **$116.8K**) sit in one key-controlled operational wallet (`addr1q9aq8mt5…`, the still-active "LENFI P2P" loan flow seen in a 2025-10 funding tx; possibly a third-party close-service e.g. FluidTokens); 1 UTxO ($0.27) has its NFT at a script addr → stuck. |
| **V1 `liquidation_v1`** (0xb1259b98…) post-liquidation leftovers | 878.56 ADA + 53,084 AADA + 5,653 IAG = **$334** (27 UTxOs) | **No** | Same: burn `(borrowerNftCs, datum.borrowerNftTn)` (CEK C1–C3). | 1 UTxO (**$121**: 1.31 ADA + 5,653 IAG) has its borrower NFT parked at a 46-byte always-fails burn script → **stuck (S)**. |
| **V1 `collateral_v1`/`_v2`** (0x2d75e5cf/0x31e7527a) active loan collateral | 2,303.18 ADA + tokens = **$3,936** | **No** | Release needs the unique borrower NFT (repay) or lender NFT (liquidate); all 53 gate NFTs alive, key-held. | — |
| **V1 `request_v1`/`_v2`** (0x0a5abd03/0xd721808a) unfunded borrower requests | 10,049.02 ADA + tokens = **$2,443** | **No** | Funding requires tx range to end *before* `requestExpiration`; every live request expired (2022/23) except micro-ones (~$0 equity). | Borrowers hold cancel rights; abandoned. |
| **V1 `debt_request_v1`/`_v2`** (0x16ecc417/0x34c3e3c6) lender offers | 5,805.47 ADA + tokens = **$12,420** | **No** | Taking requires tx range to end before expiry; all offers expired 2023–2026 (CEK W1–W4). Cancel needs lender NFT. | Historical under-collateralised offers (~$25 "free money") expired before discovery. |
| **V1 `lenfi_stake_holder`** (0x1999507b…) AADA staking | 93.85 ADA + 22,682 AADA + 48 bond NFTs = **$22.80** | **No** | Unstake burns both copies of the per-stake bond NFT; receipts user-held. | Lost receipts = stuck stakes. |
| **V2 `leftovers`** (0x9b99fef5…, Aiken) — **missed by triage** | 13,888.73 ADA = **$3,373** (249 UTxOs) | **No** | Burn-only spend; gating NFT is locked inside its pool UTxO (registries, $959) or requires the borrower NFT (31 liquidation leftovers, **$2,414**, H-O for borrowers — the triage never saw these addresses). | Registries brick if pool/delegator NFTs are burned/lost. |
| **V2 `pool`** (0x32e8c0ae…) 98 pools | 739.17 ADA + $47.68 tokens = **$228** | **No proven path** | Pre-fix `LpAdjust` withdraw predicate *is present* in the live bytecode (sub-audit UPLC read; fix f0148f9 post-dates deployment), but live pools hold only min-UTxO-scale value and no full drain tx was CEK-proven. | If anyone ever deposits into these pools, the pre-fix predicate allows one LP holder to withdraw more than their share. |
| **V2 `collateral`** (0x8021830a…) | 275.16 ADA = **$67** | **No** | 1 live loan (200 ADA) + carrier + dust; spend needs the borrower NFT / permissionless liquidation path with oracle checks. | — |
| **V2 `pool_config`** (0xecf0762d…) | 534.43 ADA + 269 NFTs = **$130** | not assessed | Config/treasury script; spend conditions not analysed this pass. | Unexplored. |
| **TOTAL** | **602,081.36 ADA + tokens = $166,619.39** | **E-U = $0.00** | | |

### 2. Total live extractable now: **$0.00** (confidence **high**)

- **E-U = $0.00.** Every value-bearing V1 UTxO is gated by a unique, unforgeable NFT (CEK 12/12) and the only alternative value-capture paths (fund/take offers) are closed by the deployed expiration gate (CEK 4/4). V2's known prefix flaw faces empty pools.
- **H-O = $166,270.44** — recoverable by position holders: V1 lenders/borrowers/lenders-of-record (incl. the Lenfi batcher), V1 stakers, V2 borrowers ($2,414 of liquidation leftovers), V2 registries ($959 via pool `Destroy` by LP+delegator holders), V2 config/pool owners.
- **P = $0** (no privileged path holds user value; immutable Plutus scripts, no upgrade authority).
- **S = $348.95** — V1: 2 UTxOs with script-gated NFTs ($121.20) + 62 datum-less dust UTxOs (442.22 ADA, `MissingDatum` = unspendable) ≈ $228.65; V2: 3 enterprise deploy carriers (101.33 ADA — datum `d87980` fails every handler) + no-datum dust (393.74 ADA) ≈ $120.30.
- Micro-edges found and deliberately not counted: funding one unexpired micro-request (`e3661f66b884#1`: +0.3 ADA after ~11 days ≈ $0.07); V2 pool drain ceiling ≈ $228 (unproven; pools effectively empty).

### 2.1 Historical context (Vacuumlabs audits; no verifiable pre-launch exploit)
The Aug–Sep 2022 commits in `aadafinance/aada-finance` are **audit fixes**, not incident response: Aada mainnet launched **2022-09-13** (launch PR) and the **Vacuumlabs V1 audit** (window 26 Jul – 2 Sep 2022, report dated 2022-09-02, final commit `19db8c9e`) found and tracked exactly these issues (APT-301→AADA-006, APT-303→AADA-101, APT-305→AADA-202/402, APT-306→AADA-104; also commit `edf9f2bd` fixing a vacuous-truth bug in `Collateral.hs`'s oracle-token check). Two further Vacuumlabs audits exist (DebtRequest 2022-11-25; Aiken V2 rewrite 2023-03-21). The frequently repeated "Aug-2022 Aada exploit (~$560K)" could **not be substantiated anywhere** (rekt.news, DeFiLlama's 1,300-entry hacks DB, SlowMist, news RSS, team posts — see `analysis/research-notes.md`); the team states the protocol ran uninterrupted from Sept 2022. Treat that figure as a misattribution; do not build a narrative on it.

Two audit findings were **acknowledged, not fixed** and are visible in the live design: **AADA-006/201** — after `loanDuration` passes, the lender-NFT holder may take the whole collateral with no oracle and no further structure checks (the `checkDeadline || checkForLiquidationToken` branch I verified); **AADA-007** — a compromised oracle node cannot be replaced. All audited logic (batched-input guard, single-script-input guard, oracle-mint-only pre-deadline liquidation) is present in the deployed scripts, consistent with the CEK results. The shipped oracle was a **3-of-3 fixed-signer native script**; post-deadline liquidations need no oracle.

V1 is now **abandoned but not dead**: `lenfi.io` redirects to an unrelated site (2026-10), the app/docs are down, socials silent since 2025, DefiLlama marked it dead — yet on-chain activity continues via third-party integrations (incl. FluidTokens, which can still close Lenfi loans). The Safety Module was **never activated** (zero transactions, zero safety tokens minted) and is therefore not in the live target set.

---

## 3. Target set — derived structurally (the triage list was incomplete)

1. **V1 stake-key enumeration:** all 7 `addr1z…` V1 addresses share stake key `69962602a7025d4163233855c5a379313b27239b8623ad53540815cb`; Koios `/account_addresses` returns exactly those 7 (`analysis/koios_account_addresses.json`).
2. **Deployment txs:** `a8168a1c…` (block 7,725,640, 2022-09-07) deployed `request_v1` + the lender NFT policy; siblings deployed the rest (`analysis/deployment_dates.json`). Table in §3 of the previous revision — all captured in `analysis/koios_script_info.json`.
3. **V2 (Aiken) — missed addresses found by the sub-audit:** the DefiLlama dead adapter lists only the *enterprise-form* V2 addresses (which are deploy "carriers", 101 ADA). The real V2 state sits at **stake-enabled addresses** (payment credential = script, per-pool stake script):
   * `pool` credential `32e8c0ae…`: 98 pool UTxOs at `addr1xyew3s9wx…<stake>` (739.17 ADA + loan tokens).
   * `leftovers` credential `9b99fef5…`: 249 UTxOs / **13,888.73 ADA** across 18 addresses (216 registries + 31 liquidation leftovers + carrier + dust).
   * `collateral` credential `8021830a…`: 10 UTxOs / 275.16 ADA (1 live loan datum of 200 ADA from 2024-05-15 + dust).
   * `pool_config` credential `ecf0762d…`: 269 UTxOs / **534.43 ADA** + 269 unique NFTs (largest single V2 address).
   Full evidence: `analysis/v2/v2-mapping.md`, `analysis/v2/v2_stats.json`, `analysis/v2/v2_valuation.json`.
4. **Script bytes** for all live validators/policies via Koios `/script_info` → `analysis/script_*.hex` + decompiled `analysis/uplc_*.uplc` (+ V2 dumps in `analysis/v2/`).

---

## 4. The mechanism, exactly

### 4.1 Identity model (AadaNft policy — V1)
CEK on the deployed bytes (`analysis/cek_proofs_aiken.py`): mint `+1` requires the redeemer UTxO to be an input AND `name == sha256(byte(idx)‖txid)` (**A1 ACCEPT**, **A2 REJECT**, **D1 REJECT**); burn `-1` unrestricted (**A3/D2 ACCEPT**). Empirically: real funding tx `daffd9d9…` minted NFT `9a6d79ad…` = `sha256(0x00‖a8168a1c…)` of its consumed input. **Names cannot be forged; identity is possession.**

### 4.2 Payout gates (V1 Interest / Liquidation, 2380 B each)
`mkValidator = case mintFlattened ctx of [(cs,tn,amt)] -> amt == -1 && cs == <NftCs> && tn == <datum TN>; _ -> False`.
CEK: **B1 ACCEPT** (exact burn, 100 % of a 50,000 ADA UTxO to an attacker address — no payout check), **B2/B3/B4 REJECT**; **C1–C3** identical for liquidation. Funds follow the NFT holder; outsiders cannot obtain the NFT.

### 4.3 Fund/take windows (V1 Request & DebtRequest)
`validateExpiration = after(requestExpiration, txRange)`. CEK on the deployed `debt_request_v2` with a real live offer (`b3af0800#1`): **W1 ACCEPT** with tx range `[1.600e12, 1.690e12]` ms (ends before exp 1.6914e12); **W2 REJECT** with `[1.700e12, ∞)`; **W3 Cancel ACCEPT** (lender NFT burn); **W4 REJECT** wrong burn. ⇒ **funding/taking is only possible before expiration**; all live requests/offers are expired (the high-value 10,000 ADA WMT-collateral request `e7cd3d8a` has been untakeable since 2022-11). Historic near-miss value (had windows been open): ~$2,020 request equity + ~$25.6 under-collateralised offers (`analysis/equity_calc.py`).

### 4.4 V1 Collateral & staking
Collateral release = borrower-NFT burn + Interest output (repay) OR lender-NFT burn + deadline/oracle mint (liquidation). Staking = burn `-2` of the per-stake bond (receipt + locked copy); live datums are all `(bondPolicy, "AadaBond")`.

### 4.5 V2 (Aiken, launched 2024-02) — `analysis/v2/v2-mapping.md`
* `pool.ak` (8021 B, deployed 2024-02-17): datum `{params, balance, lent_out, total_lp_tokens}`; spends need the config-NFT reference input; no signatures. **The live bytecode still contains the pre-fix `LpAdjust` withdraw predicate** (`lp_token_delta < total_lp_tokens` without `× -1`): a single LP holder can withdraw more than their pro-rata share, up to the pool's recorded balance, with unconstrained outputs. The 2024-12-20 fix (`f0148f9`) is **not** in the live script. Mitigating fact today: live pools hold only ~3.7 ADA each of min-UTxO + $47.68 of loan tokens in total, and many pools' datum/UTxO accounting is inconsistent (frozen).
* `leftovers.ak` (336 B, 2024-02-17): spend iff the mint field contains exactly `-1` of the datum's `(policy, name)` — burn-to-unlock, no output checks. Registry UTxOs (216, 3,946.35 ADA) are keyed to pool NFTs that live *inside* the pool UTxOs (so gated by pool `Destroy`: all LP + pool NFT + delegator NFT); liquidation leftovers (31, **9,938.39 ADA**) are keyed to borrower NFTs (user-held ⇒ H-O).
* `collateral.ak` (14,492 B, 2024-02-21): permissionless liquidation path with oracle data + 1-hour validity window + platform fee; repay needs the borrower NFT. Per-loan `liquidity_token.ak` (2852 B) and `pool_stake.ak` (5064 B) scripts are attached as CIP-31 reference scripts to registry UTxOs.
* Deploy carriers (enterprise addresses from the triage) hold only 101.33 ADA with a void datum that fails every handler → stuck.

---

## 5. Live state (read-only, keyless; tip 14,058,995, 2026-10-12)

* **V1 (7 base addresses + staking):** 586,643.86 ADA + tokens = **$163,198.84** — `interest_v1` 567,513.79 ADA ($143,665) · `debt_request_v2` 5,805.47 ADA + 100k HUNT ($12,420) · `request_v1` 10,030.52 ADA ($2,439) · `collateral_v1` 2,045.55 ADA ($497) · `collateral_v2` 257.63 ADA + 4M SNEK ($3,439) · `liquidation_v1` 878.56 ADA + 53k AADA + 5.7k IAG ($334) · `lenfi_stake` 93.85 ADA + 22,682 AADA ($23) · `request_v2` $4.49.
* **V2:** 15,437.49 ADA = **$3,420.55** — leftovers 13,888.73 ($3,373) · pools 739.17 + $47.68 tokens ($228) · collateral 275.16 ($67) · pool_config 534.43 ($130).
* **Gate-NFT custody (V1):** all 74 interest + 23/24 liquidation + all collateral/request/offer gate NFTs alive; 14 interest NFTs (**$116,810**) in one key-controlled operational wallet `addr1q9aq8mt5…` (carries the "LENFI P2P: Providing loan." CIP-674 tag from the 2025-10 funding tx; a plain key address, not a script — attribution to Lenfi's own batcher vs a third-party close-service is not proven); 59 with other key holders; 2 script-locked (stuck).
* **Protocol alive:** repayments created interest UTxOs as recently as 2026-01; funding in 2025-10; the batcher consolidates claim NFTs (last 2026-08-27).
* **Pricing:** ADA $0.24299; tokens via DefiLlama `cardano:<unit>` (HUNT $10.2k, DJED $5.5k, SNEK $3.4k live in V1; 60+ units unpriced incl. AADA; one 2025-minted fake "NIGHT" (24 B supply) excluded as a $91.5k pricing artifact).
* **Independent corroboration:** DefiLlama's last Lenfi TVL sample (2026-10-12) is **$164,806**, i.e. the same stuck V1 value + V2 pools this report measures (protocol marked `deadUrl`, adapter removed).
* **Version nuance:** `versions.json` labels the 2023-01 redeploy (request `d721808a…`, collateral `31e7527a…`, lender-request `34c3e3c6…`) as v0.1.1.0 "Aiken rewrite", but the deployed bytes decompile as PlutusTx/Haskell-style UPLC — normalized code is *identical* for request/debt-request and differs only by the Nov-2022 minimum-collateral change for collateral (see `analysis/v2`... no: `analysis/uplc_*.uplc`). The Vacuumlabs Aiken audit (2023-03-21) therefore does **not** describe the live v0.1.1.0 scripts; it is unrelated to the live custody.

---

## 6. What an attacker can / cannot do

**Cannot (CEK- or chain-verified):** forge a gate NFT (A2/D1) → cannot claim interest ($143.7k) or liquidation leftovers; take/fund expired offers/requests (W1–W4) → ~$2,045 of historic equity/offers are dead; release V1 collateral or the staking pool without the loan-side/receipt NFTs; reach the V2 registries/liquidation-leftovers without the gating pool/borrower NFTs; spend the 62 datum-less dust UTxOs or the 3 V2 carriers; move the batcher's NFTs/claims (key-controlled, not a script).

**Can (negligible/non-profit):** fund the one unexpired micro-request (+0.3 ADA ≈ $0.07 after ~11 days); burn one's own NFTs (griefing only); create permissionless registrar/leftover UTxOs (no value); in principle exercise the V2 `LpAdjust` pre-fix predicate — but the live pools hold only min-UTxO + $47.68 of tokens, and no full drain tx was proven.

**Costs:** Cardano fees (~0.17–0.5 ADA) exceed every residual edge → practical E-U is $0.

---

## 7. Verification (chain-native, read-only)

* `analysis/cek_proofs_aiken.py` — **12/12 PASS** (NFT name binding; Interest/Liquidation gates).
* `analysis/cek_window_proofs.py` — **4/4 PASS** (debt_request take/cancel + expiry semantics, using the real live offer `b3af0800#1`).
* Scripts = exact on-chain bytes (`analysis/script_*.hex` from Koios `/script_info`); contexts hand-built; evaluator = aiken v1.1.24 `uplc eval` (budget reported per case in the JSONs).
* Supporting evidence: `analysis/equity_calc.py` (per-position equity math), `analysis/nft_custody.py` (gate-NFT existence/custody), `analysis/valuation*.py`, `analysis/decode_datums2.py`, `analysis/decompile_all.py`, `analysis/v2/*`.
* **CI (public repo `kingmariano/ca-zombie-ci`):**
  * run **#38277843455** (final): 16/16 proofs in CI, live-state refresh, artifacts — <https://github.com/kingmariano/ca-zombie-ci/actions/runs/38277843455>
  * run #38272029921 (first attempt; dependency issue fixed in the final run).
  * `analysis/ci_runs.json` mirrors this list.

---

## 8. Verdict, residual & latent risk

**Verdict:** Lenfi's live Cardano custody (602,081 ADA ≈ $166.6k, of which the triage saw only ~586k ADA / $155k) is **not extractable by an external unprivileged attacker ($0.00, high confidence)**. The V1 protocol is protected by a clean NFT-possession model plus a deployment-wide expiration gate; the V2 custody (15.4k ADA) is gated by pool/borrower NFTs or is stuck.

**Residual/latent:**
1. **Claim-key concentration:** 14 lender NFTs backing **$116.8k** of claims sit in one key-controlled operational wallet; the `interest_v1` payout has no destination check, so whoever holds that key (Lenfi's successor flow or an integration) can route those payouts. Top latent risk.
2. **V2 pre-fix `LpAdjust`:** present in live bytecode; currently harmless because pools are empty. If LP activity resumed on these contracts, one LP holder could drain a pool. Worth a protocol-side migration/warning.
3. **V2 registries ($959) / config ($130):** burn/key-gated; bricking risk if pool/delegator/config NFTs are lost.
4. **Griefing:** unrestricted NFT burn can brick a specific claim (already happened once, $121).
5. **Trap collateral:** unexpired `request_v2` requests offering 1 ADA loans against ~$0 AADA can bait naive lenders (loss = the 1 ADA, not a protocol bug).
6. **Acknowledged audit findings (AADA-006/201):** after `loanDuration`, a lender-NFT holder may take the entire collateral with no oracle and no further structure checks — including on the still-live `collateral_v1/_v2` UTxOs (2,303 ADA). By design/acknowledged, but note it for borrowers. **AADA-007:** a compromised oracle signer cannot be rotated; pre-deadline liquidations would then be at risk. Shipped oracle = 3-of-3 native script.
7. **Not fully assessed:** V2 `pool_config` spend conditions; V1 `collateral_v2` differs from v1 by a Nov-2022 "minimum collateral" tightening (inferred from repo history, not CEK-evaluated).

**Blockers to extraction:** unique NFTs held off-chain, expired fund/take windows, immutable scripts with no admin path.

---

## 9. Methodology, caveats, files

**Method:** Koios (keyless) for state/scripts/datums; `uplc` + aiken for decompilation and CEK; DefiLlama for USD; source cross-checks with `aadafinance/aada-finance` (V1 Haskell) and `lenfiLabs/lenfi-smart-contracts` @ `882be2f` (V2 Aiken); V2 mapping in `analysis/v2/v2-mapping.md`.

**Caveats:** (1) point-in-time; token USD primary-priced via DefiLlama with ~60 unpriced units; (2) the "before-expiry" gate was CEK-proven on `debt_request_v2` and corroborated on-chain (all fundings happened pre-expiry; expired high-value requests never funded); a full `Request` funding-branch CEK reconstruction was attempted but rejected for a reason not isolated — documented in the artifacts; it cannot change the verdict because every live request is expired or ~$0-equity; (3) V2 pool drain predicate verified by UPLC inspection (sub-audit), not by a full CEK drain tx; (4) V2 byte-level commit attribution is source-diff/timestamp based (repo artifacts stale); (5) protocol history is per the Vacuumlabs audit PDFs + `analysis/research-notes.md` (no verifiable Aug-2022 exploit; Safety Module never activated); (6) no transactions were sent; no secrets in this folder.

**Files:** README.md · summary.json · analysis/ (all raw evidence, scripts, decoded datums, CEK harnesses, `v2/`) · ci/run.sh · ci-out/ (proof JSONs + summary).
