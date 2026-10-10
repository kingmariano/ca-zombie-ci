# DeDust v2 (TON DEX) — live unprivileged-extraction assessment

**Date:** 2026-10-10 (UTC) · **Chain:** TON mainnet · **Status:** read-only; all "attack" tests executed via
read-only emulation (TonAPI `/v2/traces/emulate`, no signing, no sending, no state change on any real chain).

Scope: the DeDust v2 custody design (per-asset **Vault** contracts holding all reserves; Pools only
track reserves and instruct Vault payouts), the v2 factory, pools, and the legacy v1 contracts.
Mission: how much can an **external unprivileged attacker** extract live, right now.

---

## 1. TL;DR

| Target | Live value (measured) | E-U (unprivileged) | Why closed |
|---|---|---|---|
| Native Vault `EQDa4VO…Cq_` | **1,828,441.82 TON ≈ $2,664,340** | **$0** | `pay_out_from_pool` requires sender == derived Pool of proof (exit 265 live); `swap` overdraft rejected (exit 263); unknown ops bounce (65535) |
| Jetton Vaults (per asset, e.g. USD₮ vault + sampled top-9 ≈ $1.26M) | ≈ **$1,255,884 sampled** | **$0** | Jetton payouts only via vault's own Jetton Wallet (owner-locked, exit 73 on relay); forged `jetton_notify` only triggers an inert refund to the message source |
| Pools (52,340 in API) | top-40 native reserves = 869,037 TON (live) | **$0** | `swap_external` needs derived-Vault proof (exit 264); `swap_peer` needs derived-Pool proof (exit 265); `collect_fees`/`configure_*` need Operator role (exit 296) or are unimplemented (65535) |
| Factory (roles/owner paths) | 324.72 TON | **$0** | `destroy_non_ready_vault` → 256 OWNER_UNAUTHORIZED; `create_legacy_jetton_vault` → 296 OPERATOR_UNAUTHORIZED; `install` → 65535 |
| v1 legacy pools (`/v1/pools`, 1,761) | top-30 = **3.34 TON total** | **$0** | contracts active but drained; API reserves are historical |
| **Total live extractable (E-U)** | | **$0 (high confidence)** | every candidate path reverted with a documented gate, verified live |

DefiLlama protocol TVL cross-check (same day): **$4,913,800** (TON leg). The native vault balance is the
single largest custody item and matches the on-chain sum of pool native reserves within API-staleness error.

---

## 2. Contracts & addresses (all live-verified)

| Role | Address | Notes |
|---|---|---|
| Factory (v2) | `EQBfBWT7X2BHg9tXAxzhz2aKiNTU1tpt5NsiK0uSDW_YAJ67` (raw `0:5f0564fb5f604783db57031ce1cf668a88d4d4d6da6de4db222b4b920d6fd800`) | code-upgradeable via roles; balance 324.72 TON (tonapi `_bulk`, 2026-10-10 03:22 UTC) |
| Native Vault | `EQDa4VOnTYlLvDJ0gZjNYm5PXfSmmtL6Vs6A_CZEtXCNICq_` (raw `0:dae153a74d894bbc32748198cd626e4f5df4a69ad2fa56ce80fc2644b5708d20`) | interface `dedust_vault`; `get_asset` → `native` (run-method, exit 0); code root hash `875fac5e08e5062f0f7c5c9f4c989607108e35a9ad88dc563e3e4fc7a3d3e75c` (library-type wrapper `FF00F4A413F4BCF2C80B` + inlined code, 44 cells) |
| USD₮ Jetton Vault | `EQAYqo4u7VF0fa4DPAebk4g9lBytj2VFny7pzXR0trjtXQaO` (raw `0:18aa8e2eed51747dae033c079b93883d941cad8f65459f2ee9cd7474b6b8ed5d`) | holds USD₮ via its wallet `EQCI2sZ8zq25yub6rHEY8FwPqV3zbCqS5oasOdljENCjh0bs` (owner = vault, master = USD₮; `get_wallet_data` exit 0) |
| Pool (example: TON/USD₮ volatile) | `EQA-X_yo3fzzbDbJ_0bzFWKqtRuZFIRa1sJsveZJ1YpViO3r` (raw `0:3e5ffca8ddfcf36c36c9ff46f31562aab51b9914845ad6c26cbde649d58a5588`) | `get_reserves` 2026-10-10 04:32:50 UTC = `193,348,880,921,844` / `285,646,753,061`; pool account lt `108973767000007`-range |
| USD₮ jetton master | `EQCxE6mUtQJKFnGfaROTKOt1lZbDiiX1kCixRv7Nw2Id_sDs` | 6 decimals, whitelist-verified |

TL-B source of truth: `toncenter/ton-indexer` → `schemes.tlb` §"DeDust Protocol v2" (copied to
`dedust_v2_canonical_tlb.txt`): full op registry incl. roles (`code_installer`, `code_updater`,
`fee_collector`, `fee_configurator`, `stable_pool_factory`, `legacy_vault_factory`,
`quote_synchronizer`, `quote_configurator`) and `proof#_ factory_addr:MsgAddressInt contract_type
params` with `vault#01`, `pool#02`, `liquidity_deposit#03`, `operator#04`.

**Auth design (reconstructed from real traces + canonical TL-B, confirmed by live emulation):**
cross-contract messages carry a **proof** = `(factory, contract_type, params)`. The receiver recomputes
the derived address of the claimed sender from `(factory, type, params)` and requires
`sender == derived` — spoofing is preimage-bound. Jetton vaults additionally rely on TEP-74 wallet
owner checks.

---

## 3. Live funds (headline refs)

1. **Native Vault TON balance** — toncenter `getAddressInformation`
   `balance = 1828441824352921` raw = **1,828,441.824352921 TON**,
   seqno `98067263`, last-tx lt `108973767000007`, `sync_utime 1791606777`
   (2026-10-10 04:32:50 UTC). USD at DefiLlama TON $1.4571640190692876 (ts 1791601377):
   **$2,664,339.64**.
   (Time series same session: 1,828,834.87 → 1,828,843.65 → 1,829,131.12 → 1,828,441.82 TON; DEX is active.)
2. **USD₮ Jetton Vault holding** — `get_wallet_data` on `0:88dac67c…` = `785,137,112,232` raw (6 dec)
   at ~05:12 UTC; later read `784,985,817,981` (**$784,358** at $0.9992/tonapi rate). Jetton wallet
   owner is the vault (only the vault can move funds).
3. **Sampled top-9 jetton vaults** (factory `get_vault_address` + wallet `get_wallet_data`, live):
   USD₮ $784,358; OPEN $104,363; MEM $103,250; ANON $90,040; MTONGA $58,517; FISH $58,251;
   GOMINING $30,118; DUST $26,987; NOT (price≈0 in rate feed) — total ≈ **$1,255,884**.
   Raw rows in `dedust_numbers.json` / `jetton_vaults.json` / `jetton_meta.json`.
4. **Top-40 native pools (live `get_reserves`)** = **869,036.93 TON** vs DeDust API snapshot
   936,126.14 TON for the same pools → the public API `/v2/pools` is **stale for some large pools**
   (e.g. TON/USD₮ pool: live 193,405 TON vs API 224,131 TON). Full API total (52,340 pools) =
   1,854,374 TON native, i.e. same order as the vault balance; residual ≈ 959,405 TON sits in pools
   below the 5,000 TON cut-off (long tail). API `lt` fields show last-update ages of days–weeks.
   → Use live run-methods for any exact number; treat `api.dedust.io` reserves as indicative only.
5. DefiLlama: `https://api.llama.fi/protocol/dedust` TVL **$4,913,800.27** (2026-10-10).

v1 legacy check: `/v1/pools` (1,761) top-30 by advertised reserves hold **3.34 TON total**
(wallets/`dedust_pool`+`jetton_master` contracts, e.g. `EQC9miYY…` balance 0.121 TON) — the v1 era
custody is empty; API reserves are historical. **Dead end, no remaining value.**

---

## 4. Attack-path matrix — live read-only emulation (TonAPI `/v2/traces/emulate`)

All probes executed as external messages to an existing public wallet (**wallet v3r2
`UQC5p9zhlDG1YEQlTGmFjo3BH-xcB2He1BXjhvvktOEW9Xi0` state read live: seqno 2324; signature check
ignored by emulator; nothing broadcast**), or directly as simulated inbound messages. Raw traces in
`emulation/`. Exit codes are TVM compute-phase codes; "bounce" = 0xffffffff back to sender.

| # | Probe (message → target) | Result | Gate (documented code) |
|---|---|---|---|
| P0 | Legit swap `swap#ea06185d` (0.05 TON, real pool) wallet→Native Vault | **Full happy path exit 0**: wallet → vault → pool (`swap_external#61ee542d`) → USD₮ Jetton Vault (`pay_out_from_pool#ad4eb6f5`) → user wallet | n/a (sanity) |
| P1 | `swap` claiming amount=1000 TON, only 0.3 TON attached | vault aborted **exit 263 = `VALUE_TOO_LOW`**; bounce | value check |
| P2 | Forged `pay_out_from_pool` (0xad4eb6f5) claiming to be the real Pool (with its exact proof params) from attacker, requesting 1000 TON to attacker | vault aborted **exit 265 = `POOL_UNAUTHORIZED`** | derived-pool proof mismatch |
| P3 | Same with random fake pool params | **exit 265** | ditto |
| P4/P4b/P4c/P4d | Forged jetton `notify#7362d09c` → USD₮ Jetton Vault with forward payload `swap#e3a0d482` (claiming 1 USD₮ deposit; variants: claimed sender=vault, empty payload, garbage payload) | vault exit 0 but **no swap**: it emits an inert TEP-74 transfer instruction (0x0f8a7ea5) **to the message source** (attacker wallet; a plain wallet ignores it) and returns ~0.299 TON of attached gas. No jettons moved; no `swap_external` sent | jetton-notify only actionable when sender is the vault's own wallet; refund message cannot be redirected |
| P13/P14 | Relay the vault-generated transfer instruction (dest=attacker) to the vault's USD₮ wallet `0:88dac67c…` | wallet aborted **exit 73** (owner check, TEP-74) | wallet owner = vault |
| P11 | `swap_external#61ee542d` → real Pool with proof claiming to be the real Native Vault | pool aborted **exit 264 = `VAULT_UNAUTHORIZED`** | derived-vault proof mismatch |
| P12 | `swap_peer#72aca8aa` → real Pool with proof claiming to be the real Pool | pool aborted **exit 265 = `POOL_UNAUTHORIZED`** | derived-pool proof mismatch |
| P5 | `collect_fees#0b429f52` → Pool, destination=attacker | **exit 296 = `OPERATOR_UNAUTHORIZED`** | operator role (fee_collector) |
| P6 | `configure_trade_fee#c015297f` → Pool (fee=9999) | **exit 296** | operator role (fee_configurator) |
| P7 | `configure_start_time#7ed7f6ce` → Pool (far future) | **exit 65535 = `UNKNOWN_OP`** | not implemented in current pool code |
| P8 | `configure_quote_provider#abb46b3d` → Pool (attacker as provider) | **exit 296** | operator role (quote_configurator) |
| P9 | `configure_fee_collector_addr#eda15922` → Pool | **exit 65535** | not implemented |
| P10 | `payout#474f86cf` → Native Vault directly, value 0.3 TON | **exit 65535** + bounce | vault has no inbound `payout` handler |
| P15 | `destroy_non_ready_vault#8a518d0d` → Factory | **exit 256 = `OWNER_UNAUTHORIZED`** | owner-gated |
| P16 | `install#9b3aa3fa` (arbitrary code) → Factory | **exit 65535** | not a factory op |
| P17 | `create_legacy_jetton_vault#c9a5752d` → Factory (attacker minter/resolver) | **exit 296 = `OPERATOR_UNAUTHORIZED`** | `legacy_vault_factory` role |
| P18 | `provide_vault_state#e93405b9` → Native Vault | exit 0, replies `take_vault_state#a913dc0d` | permissionless info op (harmless) |

Documented error code registry (hub.dedust.io/contracts/v2/reference/core/errors) matches every observed
abort: 256 OWNER_UNAUTHORIZED, 264 VAULT_UNAUTHORIZED, 265 POOL_UNAUTHORIZED, 263 VALUE_TOO_LOW,
296 OPERATOR_UNAUTHORIZED, 65535 UNKNOWN_OP.

**Interpretation.** DeDust v2's custody is protected by derived-address proof checks on every value-moving
internal message plus TEP-74 owner checks on jetton wallets. No unprivileged path found to make any
contract pay out; every probe reverted at the contract executing the gate, before any transfer.

**Residual risk (not E-U today):**
- The factory is **upgradeable via roles** (`install_vault_code`, `install_pool_code`, `upgrade`,
  `upgrade_pool`, operators) — an admin/role compromise could rewrite code/data (P risk, privileged).
- `provide_vault_state`/`provide_pool_state` leak state info (no value).
- API staleness (above) can mislead integrators/analytics (led to a 26k TON "insolvency" false alarm
  during this assessment; resolved by live `get_reserves`).
- Long-tail fake-token pools exist (52k pools list); they hold real TON in the vault, but they are
  ordinary pools — no extra extraction surface observed.

---

## 5. Classification

| Category | Amount | Notes |
|---|---|---|
| **E-U** (external unprivileged) | **$0** | 22 probes (P0–P18 incl. variants), all value paths reverted with documented gates; live at seqno ≈ 98,067,263 (2026-10-10) |
| **H-O** (holders) | pools' LP/swap withdrawals work normally (see P0); vault-held reserves are redeemable by LPs through their pools subject to pool solvency (reserves == vault-covered) | normal operation |
| **P** (privileged) | whole custody is administrable: roles can upgrade vault/pool code, owner can governance-upgrade; single point of registry trust = Factory `EQBfBWT…` | role-gated (not tested with keys, by rule) |
| **S** (stuck) | none identified; v1 remnants empty (3.34 TON in top-30, inert) | |

**Headline: E-U ≈ $0 live, high confidence.** Confidence basis: (a) direct live emulation against current
state of the exact contracts holding the funds; (b) every rejection matched the protocol's own documented
error codes; (c) the address-derivation proof check is structurally preimage-bound.

---

## 6. Evidence files

```
dedust/
├── REPORT.md                     (this file)
├── vault_native_toncenter.json   getAddressInformation dump (balance/seqno/lt/code/data)
├── vault_native_tonapi.json      tonapi account view (interfaces: dedust_vault)
├── pool_usdt_ton_toncenter.json  TON/USD₮ pool account dump
├── top_pools_live.json           live get_reserves for top-40 native pools (vs API)
├── jetton_vaults.json            sampled jetton vaults: vault addr + wallet + balance
├── jetton_meta.json              metadata of the sampled jettons
├── dedust_numbers.json           computed USD table (native + sampled jetton vaults)
├── v1_pool_sample.txt            top-30 v1 pool balances (3.34 TON total)
├── dedust_v2_canonical_tlb.txt   canonical TL-B (toncenter/ton-indexer schemes.tlb excerpt)
├── emulation/                    raw TonAPI emulation traces for P0–P18 + probe message BOCs
└── scripts/                      keyless read-only scripts used (sweep/probes/decode)
```

Method: keyless endpoints only (toncenter v2 + jsonRPC `runGetMethod`, tonapi `_bulk`/methods/emulate,
api.dedust.io, coins.llama.fi). No keys, no signing, no sending.

**Blockers/limits:** TonAPI keyless throttling forced a reduced jetton-vault sweep (top-9 measured;
full 52k-pool per-asset sweep left as CI candidate — script `scripts/sweep2.py`/`sweep3.py`);
DeDust contracts are not open-source (no verified source; on-chain code is library-based; audit never
published — CertiK Skynet shows "audit in progress, remediating 85%"); conclusions rely on canonical
TL-B, real traced flows, and live emulation rather than source review.

Confidence: **high** for E-U $0 on the v2 core; medium for long-tail assets not individually probed
(the gates are shared code paths, so risk is low).
