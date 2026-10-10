# H2-06 / IOTA — Virtue (VUSD CDP) deep dive — parent fallback

**Date:** 2026-10-10 · **Chain:** IOTA Rebased L1 (MoveVM), RPC `https://api.mainnet.iota.cafe` (keyless)
**Status:** read-only; no transactions signed or sent. Evidence from on-chain objects, events, and
disassembled Move modules (fetched via `iota_getObject` / `iotax_queryEvents`).
**Child coverage note:** the assigned child subagent stalled at ~12:37 after collecting raw evidence
(`raw/`); this dossier was completed by the parent from that evidence + additional on-chain reads.

**Headline: E-U = $0.00 today (medium-high confidence).** Every price-dependent path (borrow, collateral
withdraw, liquidation) currently reverts because the protocol's only IOTA price source is **stale since
2026-08-28** (freshness gate 60 s). Liquidation is whitelist-gated to a single address; no unprivileged
value mover exists. **Latent HIGH risk documented in §6.**

## 1. Protocol identity

Virtue = over-collateralized CDP stablecoin (VUSD) on IOTA (docs.virtue.money). Collateral vaults:
IOTA, stIOTA (TokenLabs), vIOTA. Key objects (checkpoint 201,990,868 for the position census;
later reads ≈ checkpoint 202,016,900):

| Role | Object/package |
|---|---|
| Vault IOTA | `0xaf306be8419cf059642acdba3b4e79a5ae893101ae62c8331cefede779ef48d5` |
| Vault stIOTA | `0xc9cb494657425f350af0948b8509efdd621626922e9337fd65eb161ec33de259` |
| Vault vIOTA | `0x53b6405d2672be1e73f8ddea1766dbda57f1fed677be58fbfedc9fdddaafdd26` |
| Position tables | IOTA `0x5c11faed…f69fdd`, stIOTA `0x33c758d2…885f0c3`, vIOTA `0x7ee80e78…2b2a0a7c` |
| Treasury | `0x81f525f4fa5b2d3cf58677d3e39aabc4b0a1ca25cbba605033cfe417e47b0a16` (vusd `0xd3b63e60…`) |
| StabilityPool | `0x6101272394511caf38ce5a6d120d3b4d009b6efabae8faac43aa9ac938cec558` |
| Vault package | `0xb0ca01917f84a07774397395467fc2d56de377fab9d603cb79b82f062d1f6e9a` |
| CDP/events package | `0xcdeeb40cd7ffd7c3b741f40a8e11cb784a5c9b588ce993d4ab86479072386ba1` |
| Oracle: switchboard rule | `0x39fb7adf0abd75b31868e17706b8600cc943bc27422fb582f6e14282029cd5f0` (Config `0xa0c7b527…`) |
| IOTA aggregator | `0x7c16ffdac553a4816db57e5e2cfbba8245337f2983b4ffb4dd944493a530c556` |

## 2. Live state (exact reads)

- **Vaults:** MCR = **1.10** (110%), decimal 9, interest 5.5% / 6% / 6% p.a. (fixed, simple, accrued per ms).
- **Collateral (checkpoint 201,990,868; vault balances = Σ positions):**
  IOTA **2,410.072442864**, stIOTA **8,950,007.805576865**, vIOTA **3,000.003905922**.
  USD @ IOTA $0.05125438 (DefiLlama ts 1791634968), stIOTA = IOTA×1.156, vIOTA = IOTA×1.0588
  (ratios from the protocol's own oracle events): **≈ $530,574** total.
- **Debt (raw, 6-dec VUSD):** IOTA vault 4,942,752,461,742; stIOTA 140,610,974,289; vIOTA 65,223,280
  → **≈ $5,083,428.65** nominal. (See §6 anomaly.)
- **VUSD supply:** 5,137,176.190758 at 2026-08-28 (later 5,592,035,484,667 raw = $5.59M after the whale mint).
- **StabilityPool:** `vusd_balance = 189,497,634,597` raw = **$189,497.63**; `liquidator =
  0xf11c141e6a4c633baa304150c50c85ed66df639c995a1d26aedd5cc235c1f760`; fee_rate 2%, rebate_rate 0.5%.
- **Oracle:** switchboard Config maps IOTA → aggregator `0x7c16ffda…`; `tolerance_ms_map` empty →
  default freshness tolerance **60 s**; aggregator `current_result.min/max_timestamp_ms =
  1787958831000` (**2026-08-28 23:13 UTC**) → **stale by ~43 days**.
- **Last protocol activity:** last `PositionUpdated` events 2026-08-29 03:20 UTC; no liquidations found.

## 3. Contract reconstruction & path audit (disassembled Move)

- `vault::update_position` (borrow/repay/deposit/withdraw): requires oracle price + health check when
  `borrow_amount > 0` **or** `withdraw_amount > 0` with nonzero collateral; reverts
  `err_position_is_not_healthy` when CR < MCR; requires request-witness checklist.
- `stability_pool::liquidate`: **`assert_sender_is_liquidator`** — the `AccountRequest` sender must equal
  `pool.liquidator` (single whitelisted address) → reverts `err_sender_not_liquidator` for anyone else.
  Docs: “Liquidation Is Triggered by Whitelisted Executors Only”; liquidators receive **no bonus**
  (0.7–2% protocol fee; 99.3% to the pool).
- `stability_pool::deposit/withdraw/claim`: user/account-scoped (`AccountRequest`), no price required.
- `cdp_current::flash_loan/flash_repay`: repayment must equal `amount + ceil(amount×fee_rate)` in the
  same asset type (`err_flash_burn_not_enough`) — no extraction.
- Oracle submission `aggregator_submit_result_action::run` → `validate` + `actuate` with ECDSA
  verification (`ESignatureInvalid`, `ERecoveredPubkeyInvalid`) → only registered oracles can submit.
- `vusd::claim` is beneficiary-gated (`err_not_beneficiary`); admin caps govern limits/versions.

## 4. Proof / simulations

- Stranger `stability_pool::liquidate` → blocked by `assert_sender_is_liquidator` (source + object state
  `liquidator` ≠ caller).
- Any borrow/withdraw/liquidate today → `switchboard_rule::feed` freshness check fails (stale
  `min_timestamp_ms` vs 60 s tolerance) → no price collected → `aggregater::aggregate` aborts
  `err_total_weight_not_enough`.
- SP deposit/withdraw/claim do not consume a price → still functional (H-O).

## 5. Classification

| Category | Amount | Basis |
|---|---|---|
| **E-U** | **$0.00** | liquidation whitelisted; borrow/withdraw health-gated by a signed oracle; flash loans repay; SP/account paths sender-scoped; feed stale → price paths revert |
| H-O | **$189,497.63** | StabilityPool VUSD deposits (withdrawable without a price) |
| S | **≈ $530,574** | CDP collateral: withdrawals require the (stale) oracle → temporarily frozen, not bricked (recovers if the feed resumes) |
| P | admin caps / liquidator whitelist / oracle authority; VUSD supply nominal $5.59M unbacked beyond ~$0.53M collateral |

## 6. Latent HIGH risk (documented, not counted in E-U)

On **2026-08-28 21:53 UTC** the position `0x381d5b5f…` minted **4,942,703.659474 VUSD against 1 IOTA of
collateral** (tx `CaAD9SRJjuvEbNiHQcgT176kg4F8jKUTM1EneeYsd3Gd`), and the contract's health check
**passed** (contract-computed CR ≈ 2.0). The same transaction shows the account **submitting 14
Switchboard aggregator results** (`aggregator_submit_result_action::run`) before borrowing — i.e., the
position belongs to an oracle operator, and the price scale the contract used was inconsistent with the
economic value of the collateral. This indicates a **unit/price-scale defect in the borrow health check**
(collateral 1 IOTA ≈ $0.05 backing $4.94M VUSD). Consequences:
- Today it is unreachable: the feed is stale, and the actor is a privileged oracle submitter.
- If the Switchboard feed resumes updating, the borrow path may become exploitable by any account
  (bounded by VUSD sellability/marketability — no on-chain redemption exists; SP holds only $189k).
- Recommended follow-up: re-test borrow health math against `switchboard_rule::to_float` once the feed
  is live; treat as CRIT candidate.

## 7. Caveats

- The 6-dec debt vs 9-dec collateral unit reconciliation is anomalous (see §6); the debt figure is taken
  from raw on-chain fields and mint events.
- stIOTA/vIOTA USD values use oracle-implied ratios × market IOTA (no direct market).
- Event queries are limited to the last 600 `PositionUpdated` events (Aug 12–29); no liquidations were
  found in that window.
- All reads keyless; no transactions signed.

## 8. Files

- `raw/` — child-collected dumps (positions, Move modules, tx JSONs) + parent-added `switchboard_rule.move`,
  `sw_aggregator*.move`.
- `scripts/parse_positions.py`, `scripts/dump_positions.py` — position census.
