# UTONIC (TON liquid restaking, uTON) — live custody & extraction assessment

**Date:** 2026-10-10 (UTC) · **Chain:** TON mainnet · **Status:** read-only; keyless endpoints only; no signing/sending.

Scope: the UTONIC uTON system as deployed on TON mainnet — uTON jetton master (minter), the whitelisted
proxy contracts (retail TON, LST, whale), the retail withdraw contracts, and their configured receivers.
Mission: how much can an **external unprivileged attacker** extract live; classify E-U / H-O / P / S.

> Context note: Toncoin was renamed **TON → GRAM** during 2026; this report uses "TON" for the native coin
> (DefiLlama price `coingecko:the-open-network` = **$1.4571640190692876**, ts 1791601377).
> Contract sources reviewed from the project repo `UTONICFinance/utonic-contracts-uTON` (BUSL-1.1);
> audit PDF present in-repo (`audits/Audit Report by TonBit.pdf`, not re-verified in depth here).

---

## 1. TL;DR

| Target | Live value (measured on-chain) | E-U | Why |
|---|---|---|---|
| uTON jetton master (minter) `EQAfF5j3…qHTz` | total_supply **2,950,470.022524 uTON**; own balance **609.045 TON** | $0 | stake only from whitelisted proxies (sender check); burns only from the user's own jetton wallet + whitelisted proxy id; every admin op owner-gated (single EOA) |
| 12 whitelisted proxies | **17.75 TON total** (all dust; e.g. retail 9.004 TON) | $0 | user funds are forwarded out; proxy pays TON only against valid burn notifications; refunds sender-locked |
| Retail receiver EOA `EQANkMsid…` (0:0d90cb22…) | **0.206 TON** (wallet_v4r2) | $0 | EOA, swept; recent flows are tiny |
| Admin wallet `EQATJtZf…` (0:1326d65f…) | **1.289 TON** (wallet_v4r2, single key) | — | **P**: controls price, proxy whitelist, and `set_code`/`set_data` on the master |
| Outstanding uTON holder claims | **2.95M uTON ⇒ ≈3,142,971 TON ≈ $4,579,000** at contract rate | — | **H-O (conditional)**: redeemable only through the whitelisted-proxy burn flow, which currently has ~17.75 TON of liquidity in proxies; system quiet since 2026-09-15 |
| **Total E-U extractable** | | **$0 (medium-high confidence)** | no unprivileged drain path found in source + state |

Cross-check: DefiLlama `UTONIC` TVL **$4,305,527** = supply (2,950,470.02252 GRAM) × spot price — their
adapter tracks the **frozen supply**, it is not evidence of live flows. uTON supply is unchanged through
the latest adapter samples (real-time token count equals the master's `total_supply` exactly).

---

## 2. Contracts and live state

### 2.1 uTON master / minter (TEP-74 jetton + minter, same contract)

| Field | Value | Source / ref |
|---|---|---|
| Address | `EQAfF5j3JMIpZlLmACv7Ub7RH7WmiVMuV4ivcgNYHvNnqHTz` (raw `0:1f1798f724c2296652e6002bfb51bed11fb5a689532e5788af7203581ef367a8`) | tonapi `since get_jetton_data`; registry: tonkeeper/ton-assets ("UTONIC TON, the Liquid Re-staking Token") |
| `get_minter_data` (run-method, exit 0) | `total_supply = 2950470022523729` raw; `last_price_day = 20052`; `last_price = 1000266000`; `price_inc = 95000`; `admin = pending_admin = 0:1326d65f…aba7`; whitelist dict (12 entries); content URL; wallet code | tonapi `POST /v2/blockchain/accounts/…/methods/get_minter_data`, 2026-10-10 ~05:4x UTC |
| Derived burn/mint price | `price = last_price + price_inc·(day − last_price_day)`, day = unix/86400 (`common_utils.func`: `get_day = timestamp/ONE_DAY`); day 20736 → **1,065,246,000 = 1.065246 TON per uTON** | contract math; note: UTONIC site UI showed “1 uTON = 1.0244 TON” (stale cache) — discrepancy flagged, not resolved |
| Implied backing at contract rate | 2,950,470.0225 × 1.065246 = **3,142,971 TON ≈ $4,579,000** | computed |
| Own balance | `609,045,408,991` nanoTON = **609.045 TON** | tonapi account |
| Holders | 4,114 | tonapi jetton |
| Last activity | `last_activity = 1789489304` = **2026-09-15 16:21:44 UTC** (≈25 days before this report) | tonapi account + toncenter tx history (newest tx lt `103678321000014`) |
| Verification | whitelist | tonapi |

Source (`minter.func`): `STAKE` requires `sender == proxy_whitelist[proxy_id].address` and
`real_type == proxy_type` plus value checks; `BURN_NOTIFICATION` requires
`sender == calculate_user_jetton_wallet_address(from_address)` i.e. the user's own uTON wallet, a
whitelisted `proxy_id`, and forwards `ton_amount = uton_amount·price/1e9` to that proxy's address;
`QUERY` is a read-only reply; admin ops (`UPDATE_ADMIN` 2-phase, `UPDATE_PRICE`, `UPDATE_PRICE_INC`,
`UPDATE_CONTENT`, `UPDATE_PROXY_WHITELIST`, **`UPDATE_CODE_AND_DATA` = arbitrary `set_code`/`set_data`**)
are gated on `sender == admin_address` (the single EOA). Unknown ops throw `0xffff`.

### 2.2 Whitelisted proxies (parsed from the master's on-chain dict)

| id | type | address | balance (TON) | details |
|---|---|---|---|---|
| 0 | 0 (TON retail) | `EQA4xu7Svw4KRf4brUyu7FpW-ay8-RlFtqjKagcJxzSFCU7r` | 9.003970659 | `debt_ton = 102,466.194584338 TON`; withdraw_pending_time `259200 s` (3 days); receiver `EQANkMsid…` |
| 1 | 1 (LST) | `EQCs8l5n574OUztxnMEpOgPhsNiuxnRTZiQ3UDwHWh_a-Svl` | 5.752957966 | lst_price 1.0478; capacity 41,944.342154339; lst_wallet `EQC3AZqr…` (empty now); receiver `EQANkMsid…` |
| 2 | 1 (LST) | `EQAYHoNEDKK49YUBWH6-ThH90ks-JaN_DCzv04SQN-SrTEuz` | 1.834267910 | lst_price 1.0404; capacity 8,523.059639589; lst_wallet `EQAI7zwT…` (empty now) |
| 4–12 | 4 (whale) | `EQACZFrj…`, `EQCR3StM…`, `EQAhLrkg…`, `EQBAWL9t…`, `EQCo-uai…`, `EQAM5GwB…`, `EQBng4mY…`, `EQDqHAp3…`, `EQBVXSZc…` | 0.102–0.178 each | per-whale proxies; capacities 0–3 TON; each stores whale address + uTON receiver; admin = same EOA (id 4 has a different admin `EQCU2cvY…`) |
| — | — | **Σ = 17.754550596 TON** | all 12 live-probed 2026-10-10 |

Proxy source (`proxy_ton.func`, `proxy_lst_ton`, `proxy_whale3` + storage): on stake, forwards
`ton_amount` (after fees) to the configured `ton_receiver`/`lst receiver`, then notifies the minter
which mints uTON to the user. On burn, the minter notifies the proxy, which creates/pays a per-user
**Withdraw** contract (ops `0x4501 INIT_WITHDRAW_DATA`, `0x4502 WITHDRAW`; init callable only by the
proxy) after `withdraw_pending_time` (3 days for proxy 0).

### 2.3 Receivers / custody

- Retail + LST receivers = the same EOA `EQANkMsidDQaQg2bKR8QeRXlH9CWpx67V4GtOESsI8YPGnWd`
  (`0:0d90cb2274341a420d9b291f107915e51fd096a71ebb5781ad3844ac23c60f1a`), interface `wallet_v4r2`,
  balance **0.206 TON**, live (2026-10-10). Its recent 100 transactions are tiny (in: 0.00007–0.0001 TON
  receipts; out: 1.9–6.1 TON sends to two contracts) — no large "staked" balance is held by this wallet now.
- **Where the 2.95M uTON backing sits is not identifiable from the current contract set.**
  Current proxies + receivers hold ≈18 TON; the master holds 609 TON. Historical stake/burn flows through
  the whitelisted proxies cannot explain the outstanding supply (proxy-0 lifetime debt 102,466 TON; LST
  capacities ≈50.5k TON-eq; whale capacities ≈11 TON). The remainder was minted via proxies no longer in
  the whitelist (ids 3 and 13 are absent today; deployment docs reference id 13) and/or via flow paths
  (validators / external staking) that are outside the contracts we can read here.
  **Blocker/CI candidate:** enumerate the master's full `emit_stake_log`/`emit_burn_log` external-out
  history (paginate `getTransactions` from lt ≈ 4.6e13 to 1.04e14) and reconstruct cumulative flows by
  proxy_id; then trace receivers' stake destinations. Scripts note in §6.
- uTON on-chain market: the only DeDust pool with the uTON master is
  `EQCfYrAZUFLwFhUHWvU63PS0FBIh5CePWEho6T2TDgoGok50` (volatile, reserves 8.204 TON / 9.606 uTON at API
  snapshot lt 86921213000009) — dust; the token's real market has been elsewhere (not assessed).

### 2.4 Live activity

Master tx sample (30 newest, toncenter): last active window 2026-09-15 around 16:20 UTC — continuous burn
notifications (op `0x7bdd97de`, ~10/minute burst; e.g. qid 1789489288108, uton_amount 436,361.114 uTON at
the decoded burn-record fields; exact per-burn amounts in `recent_master_txs.json`). After that timestamp
the master has **no** further transactions (through 2026-10-10). The system appears **dormant**, not
drained: `total_supply` still 2,950,470.0225 uTON (unchanged; matches DefiLlama token counts).

---

## 3. Classification

| Category | Value | Reasoning |
|---|---|---|
| **E-U** (external unprivileged) | **$0** | Every value-moving inbound path is sender-gated: `STAKE` (whitelisted proxy), `BURN_NOTIFICATION` (must originate from the burn subject's own jetton wallet **and** carry a whitelisted `proxy_id`), admin ops (single EOA), proxy messages (proxy/owner addresses), withdraw init (proxy only). No dynamic-call/reentrancy surface across messages on TVM. No unprivileged path to mint uTON without TON, or to redirect a payout to an attacker destination, was found in source or on-chain state. Confidence: medium-high (source + state; we did not run emulations for UTONIC, unlike DeDust). |
| **H-O** (holder-only) | **2.95M uTON ≈ $4.58M at contract rate** (holders 4,114) | Redemption requires the whitelisted-proxy burn flow and proxy liquidity (Σ proxies = 17.75 TON). Since 2026-09-15 the system is dormant; redemptions are operationally dependent on the deployer funding proxies / unstaking receivers. Conditional, not guaranteed. |
| **P** (privileged) | whole system | Admin = **single wallet_v4r2 EOA** `0:1326d65f3d48a6cffa03afdc5a69c065aedd52fa0f22873cca31f6d054f0aba7` (`EQATJtZf…`, 1.289 TON). It can set price/price_inc (mint & burn rate), rewrite the proxy whitelist, and **arbitrarily `set_code`/`set_data` on the master** (`UPDATE_CODE_AND_DATA`). Same EOA is proxy admin for ids 0–3 and 5–12. This is a single point of control over the whole custody design. |
| **S** (stuck) | potential subset | uTON minted via now-removed proxy ids (3, 13, others) can in principle still be burned by supplying **any** whitelisted `proxy_id` (the user chooses it in the burn message), so it is not strictly locked — but with proxies holding only dust and the system dormant, effective redemption is blocked until/unless the operator funds a proxy. Ids 3/13 absence noted. |

**Headline: E-U = $0; H-O = 2,950,470.0225 uTON (~$4.31M per DefiLlama spot / $4.58M at contract rate), operationally conditional; P = single-EOA admin with code-upgrade power.**

---

## 4. Blockers / open items

1. Backing opacity: 2.95M uTON outstanding vs ≤~150k TON of identifiable flows through today's whitelist
   → historical flows via removed proxies / external staking could not be reconstructed within this pass.
2. Price discrepancy: contract math 1.065246 TON/uTON vs site UI 1.0244 — unresolved (site likely stale).
3. No fork/emulation PoC for UTONIC in this pass (DeDust emulation infrastructure could be reused).
4. Deployed code vs repo assumption: `get_minter_data` and the whitelist parsed exactly with the repo's
   storage layout, and observed burn bodies match the repo's handler order — strong, but not full, evidence.

## 5. Evidence files

```
utonic/
├── REPORT.md                (this file)
├── minter_data.json         raw get_minter_data stack (run-method, keyless)
├── minter_parsed.json       decoded: supply, price state, admin (values in REPORT §2.1)
├── proxy_whitelist.json     parsed dict: 12 entries id→(address, type)
├── proxy_datas.json         raw account data of all 12 proxies (toncenter)
├── proxies_parsed.json      parsed per-proxy state (type, debt/capacity, receiver, admin, balance)
├── receiver_txs.json        retail receiver tx history (100 newest)
├── recent_master_txs.json   master tx history (30 newest; last activity 2026-09-15)
├── uton_jetton.json         tonapi jetton view (supply, holders, admin)
├── llama_utonic.json        DefiLlama adapter data (supply-valued TVL)
└── scripts/                 whitelist parser, proxy parser, decode helpers (keyless)
```

Method: toncenter v2 + JSON-RPC `runGetMethod`, tonapi `_bulk`/methods, project source on GitHub,
tonkeeper/ton-assets registry, DefiLlama. Nothing was signed or sent.
