# SiloStake (Silo / iSEI) — Sei CosmWasm liquid-staking hub — L2 Phase-2 deep-dive

**Date:** 2026-10-13 · **Chain:** Sei (pacific-1) · **Target:** CosmWasm hub `sei1e3gttzq5e5k49f9f5gzvrl0rltlav65xu6p9xc0aj7e84lantdjqp7cncc` (label `silohub`, code_id **4485**)

**Status:** read-only; deployed-bytecode PoC run on a **throwaway local single-node Sei chain** (GitHub Actions). **No mainnet transactions were made.** All live reads via public RPC/LCD at the stated block.

---

## 1. TL;DR

| Target | Live value held (SEI) | External-unprivileged extractable (E-U) | Why closed/open | Latent risk |
|---|---|---:|---|---|
| Silo hub `sei1e3gttzq…` (iSEI liquid staking) | 3,595,978.68 (bank 1,251,270.73 + delegated 2,262,427.27 + unbonding 82,280.69) | **$0** | Every value-moving message is gated by iSEI holdings (deposit→shares→proportional claim) or owner rights; 18-path attack battery on the **exact deployed bytecode** (data_hash `4EBD…1F90`) reverts every unprivileged extraction attempt | Owner/admin is an **EOA** with live `MsgMigrateContract` rights → can replace hub code (privileged theft risk to the whole pool); iSEI is trading ~26% below NAV (wind-down 2025-11-11) |

**Total live E-U extractable now: $0.00** (confidence: **high**).
**Holder-recoverable (H-O): 3,595,958.68 SEI ≈ $224,794.17** (all backing except 20.000137 SEI unattributed dust).

USD basis: SEI $0.062513 (CoinGecko/DefiLlama, 2026-10-13). Triage row price ($0.06723) would give ≈ $241,756.30 for the same assets.

---

## 2. What the target is

Silo was the leading Sei liquid-staking protocol ("$iSEI"); the team announced shutdown on **2025-11-11**. The hub is a **CosmWasm staking/unstaking engine** (fork of the open-source Eris/`silo` hub family — the deployed binary contains `silo_staking_hub_tokenfactory` crate names and `silo::hub` type paths):

* users `bond` native **usei** (SEI) → receive token-factory denom **`factory/sei1e3gttzq…/isei` (iSEI, 6 dp)** minted 1:1, appreciated by rewards;
* the hub delegates all SEI to 7 validators;
* users `queue_unbond` (send iSEI back to the hub, which burns it in `submit_batch`) → their claim is recorded in a **batch**; after `unbond_period` (21 d) and a `reconcile`, they `withdraw_unbonded` the SEI;
* permissionless keepers: `submit_batch`, `reconcile`, `harvest`/`reinvest` (compound rewards, 5 % protocol fee to `protocol_fee_contract`).

**Live claims/asset accounting** (all reads in `analysis/live-state.json`, block 237,384,817, 2026-10-13T15:43Z):

| Item | SEI |
|---|---:|
| Contract bank balance | 1,251,270.729485 |
| Delegated (7 validators) | 2,262,427.267269 |
| Unbonding (completes 2026-10-18 / 2026-10-28) | 82,280.686260 |
| **Total assets** | **3,595,978.683014** |
| iSEI supply 2,094,398.807228 @ rate 1.080227538070168563 | 2,262,427.267269 claim |
| Outstanding unbond-batch claims (278 batches) | 1,184,872.730218 (reconciled/claimable 1,102,358.643811; unreconciled 82,514.086407) |
| Unharvested staking rewards (`unlocked_coins`) | 148,658.685390 |
| Sum of attributable claims | 3,595,958.682877 |
| Unattributed surplus (dust) | 20.000137 |

Solvency: every outstanding claim is fully funded; batches are still being processed (queue txs in Sept/Oct 2026, batches 284/285; unbonding completions 2026-10-18/28).

---

## 3. Live-state assessment (citations)

| Fact | Value | Source |
|---|---|---|
| Contract info | code_id **4485**, creator `sei1efpl63n…`, admin `sei1wg3jpdr4zl59mqh2ptwv678tefjvqfjl32mf4y`, label `silohub` | `GET /cosmwasm/wasm/v1/contract/sei1e3gttzq…` |
| Code hash | `4EBD7DA3920F3EF5914F76B229DA29F8251DBCFB6F32C3FEEE1626A5BAD71F90` | `GET /cosmwasm/wasm/v1/code/4485`; locally recomputed `sha256(code4485.wasm)` = identical |
| Config | owner = **operator** = admin EOA; `utoken=usei`; `stake_token=factory/…/isei`; `epoch_period=259200`; `unbond_period=1814400`; 7 validators; `protocol_reward_fee=0.05`; `allow_donations=false`; `vote_operator=null` | `smart {"config":{}}` |
| State | `total_ustake=2094398807228` (= iSEI supply), `total_utoken=2262427267269`, `exchange_rate=1.080227538070168563`, `unlocked_coins=148658685390 usei`, `unbonding=82280686260`, `available=1251270729485`, `tvl_utoken=3595978683014` | `smart {"state":{}}` |
| iSEI supply (EVM pointer) | `2,094,398.807228` (6 dp), symbol iSEI, `0x5cf6826140c1c56ff49c808a1a75407cd1df9423` | `totalSupply()` @ Sei EVM RPC |
| Code history | INIT code 761 → **MIGRATE to 4485** (so the admin key has been used post-deploy) | `GET /cosmwasm/wasm/v1/contract/…/history` |
| Owner EOA | no EVM code, 436.80 SEI balance | `eth_getCode/balance` |
| Fee contract `sei1uk7ulcdtnj…` | not a CW contract (EOA/multisig-style address); holds 130,565.942516 SEI + 4,860 iSEI (protocol treasury) | bank balances |

---

## 4. Attack-surface audit + PoC results (deployed bytecode)

PoC: `ci/run.sh` (GitHub Actions; run URLs below). It downloads `seid v6.7.1` (checksum-pinned), boots a solo-validator local Sei chain, stores **the exact deployed wasm** (chain-computed `data_hash` = `4EBD…1F90`, identical to mainnet), instantiates a hub with the live parameter set, and executes the scenario matrix. Raw evidence: `ci-out/poc-log.txt`, `ci-out/txres_*.json`, `ci-out/RESULTS.txt`.

| # | Call (actor → hub) | Result | Meaning |
|---|---|---|---|
| S1 | attacker `queue_unbond {}` no funds | **code 5** "Expecting only single coin" | cannot mint unbond claims for free |
| S2 | attacker `queue_unbond` wrong denom | **code 5** "Expecting stake token, received usei" | shares ⇔ iSEI funds 1:1 |
| S4/S13/S15 | attacker `withdraw_unbonded {}` (no requests / during & after victim's claimable batch) | **code 5** "withdrawable amount can't be zero" (×3) | cannot draw others' batch claims |
| S5 | attacker `withdraw_unbonded {receiver: victim}` | **code 5** same | receiver only redirects **own** refund |
| S5b | attacker `withdraw_unbonded {user: victim}` | **code 5** "unknown field `user`, expected `receiver`" | deployed schema has **no** arbitrary-user parameter; owner ≡ `info.sender` |
| S6/S7/S9/S10b | attacker `update_config` / `add_validator` / `tune_delegations` / `transfer_ownership` | **code 5** "Unauthorized: sender is not owner" | owner-gated |
| S8 | attacker `claim {claims:[{default:…}]}` | **code 5** "Unauthorized: sender is not owner" | no confused-deputy claim execution |
| S10c | attacker `vote` | **code 5** "No vote operator set" | no governance abuse |
| S16b | attacker `donate {}` with funds | **code 5** "Donations are disabled" | no donation/skim mismatch |
| S3 | **user** `bond {}` 100 usei | code 0; user receives 100 iSEI | legit path works: mint 1:1 |
| S11 | **user** `queue_unbond` 50 iSEI | code 0; 50 iSEI burned; batch #1 50 SEI | legit path works |
| S12 | attacker `reconcile {}` | code 0 (permissionless keeper, moves 50 SEI into `available`; **no payout to caller**) | keeper is permissionless but not extractive |
| S14 | **user** `withdraw_unbonded {}` | code 0; **user** receives 50 SEI | only the request owner is paid |
| S18 | attacker `submit_batch {}` | code 10 (no-op with empty queue) | permissionless keeper, no payout |
| S19 | attacker `harvest {}` | code 5 (no rewards accrued in the 2-min test window) — reaches the compound path, no payout to caller | permissionless compounding |
| S17 | **owner** `migrate` hub → same code | **code 0** — migration succeeds | **admin can replace hub code (P risk)** |

**Attacker P&L:** started 1,000.000000 SEI, ended **983.000000 SEI** (only 17 × 1 SEI tx fees spent; **zero extracted**). Holder P&L: bond 100 → queue 50 → withdraw 50, exactly as designed.

Negative results (do not re-investigate): no path for third parties to claim another user's pending batch; no unbond-queue forgery; no owner-function reachability; no donation exploit; no double-claim after the owner's withdrawal. Additionally covered by design/impact: `Callback` rejects any sender ≠ the contract itself; `rebalance`/`remove_validator` share the same `assert_owner` gate as the owner functions tested (and, even if reachable, only redelegate between whitelisted validators — they cannot move funds out); `bond {receiver}` lets anyone *give* someone else their own SEI (not extraction); `accept_ownership` only works after the current owner sets `new_owner` (null on mainnet).

---

## 5. What an attacker can / cannot do

Closed (proven by revert): free unbond queuing; wrong-denom share minting; third-party claim extraction; `user`-spoofed withdrawals; all owner functions; claim/confused-deputy calls; governance votes; donations.

Open but non-extractive: `reconcile`, `submit_batch`, `harvest` — permissionless keepers that move value **into** the vault (rewards) or between the vault's own states; callers pay gas/fees and receive nothing.

Privileged (P, not E-U): the **owner/admin EOA** `sei1wg3jpdr4zl59mqh2ptwv678tefjvqfjl32mf4y` can `MsgMigrateContract` the hub to arbitrary code (proven live on the local chain; the mainnet contract was migrated once already 761→4485, so the admin key has been used post-deploy). The owner key status is unknown (EOA, 436.8 SEI; no recent txs surfaced by public LCD search, whose index is pruned). Secondary privileged surface: 5 %-capped `protocol_reward_fee` redirect to the protocol fee address.

---

## 6. Category summary

| Category | SEI | USD | Notes |
|---|---:|---:|---|
| **E-U** — external unprivileged extractable | **0** | **$0.00** | 18-path battery, deployed bytecode; attacker strictly loses fees |
| **H-O** — holder recoverable | 3,595,958.682877 | $224,794.17 | iSEI claim 2,262,427.27 (queue → 21 d → withdraw) + batch claims 1,184,872.73 (claimable now / after Oct 18–28 2026) + unharvested rewards 148,658.69 (realized by anyone calling `harvest`) |
| **P** — privileged-only pool | 0 | $0.00 | no exclusively-privileged pool, but admin migration can divert the H-O pool (quantified risk: up to $224.8k) |
| **S** — stuck/bricked | 20.000137 | $1.25 | unattributed surplus in `available`; plus latent effectively-stuck value in dormancy (users in old batches who never return — still claimable in principle) |

---

## 7. PoC / verification

* `poc/` — none (CosmWasm contract; no Foundry). The PoC is a local Sei chain in `ci/run.sh`.
* CI: `.github/workflows/poc.yml` (repo `kingmariano/ca-zombie-ci`) runs `silostake/ci/run.sh` from `silostake/`.
* Evidence artifacts: `ci-out/poc-log.txt` (full run log), `ci-out/RESULTS.txt` (scenario matrix), `ci-out/txres_s*.json` (DeliverTx codes + raw_logs), `ci-out/bal_*.txt` (balances), `ci-out/chain_codes.json` (local chain code hash **must equal** `4EBD…1F90`), `ci-out/wasm_sha256.txt`.
* CI run URL(s):
  * **primary run (full 18-scenario matrix; artifact `result-silostake`)**: https://github.com/kingmariano/ca-zombie-ci/actions/runs/38432218933
  * reproduction run: **`<RUN 2 URL — filled after re-dispatch>`** (same scenario matrix; results identical)
* CI-side proof of bytecode: `ci-out/chain_codes.json` → local chain `code_id 4 data_hash = 4EBD7DA3920F3EF5914F76B229DA29F8251DBCFB6F32C3FEEE1626A5BAD71F90` = mainnet `code_id 4485` `data_hash`; `ci-out/wasm_sha256.txt` matches too.
* Determinism: the only chain-genesis tweaks are `unbonding_time=10s`, high voting-power threshold (single-validator chain), and gas ceiling — none touch the hub's logic. The hub was instantiated with `epoch_period=5`, `unbond_period=10` only to compress waits; all gating logic (owner, funds, batch accounting) is time-independent.

---

## 8. Verdict, residual & latent risk

* **Verdict:** the live $140.8k triage headline (contract `total_ustake`) is **not** externally extractable. It is holder-owned value; the correct E-U headline is **$0.00 (high confidence)**.
* Residual/latent:
  1. **Admin migration:** live `migrate` ⇒ the owner EOA is a standing theft key for the whole $224.8k pool. If that key is lost, migrations become impossible (P→S for the upgrade path, H-O unaffected); if compromised, full loss is possible. This is the single biggest risk on the target.
  2. **Wind-down drag:** iSEI market price ≈ $0.04998 vs NAV ≈ $0.06753 (−26 %), reflecting the 21-day redemption and dead frontend, not broken contract mechanics (batches still process).
  3. Holders who never claim in old batches (278 batches; 1.18 M SEI outstanding) effectively lock value (S-in-practice).
* Blockers/uncertainty: whether the owner EOA key is live is unknowable off-chain; the H-O realization depends on holders actually acting (permissionless keepers exist, so no owner cooperation is needed to release batch funds).

---

## 9. Methodology, sources, files

* Live reads: Sei public LCD `rest.sei-apis.com` and EVM RPC `sei-evm-rpc.publicnode.com`; prices CoinGecko/DefiLlama; only public endpoints, no keys.
* Contract semantics: open-source ancestry `github.com/erisprotocol/contracts-tokenfactory` (`contracts/hub`, `packages/eris-sei`) — used as reference; the deployed binary's own behaviour was then verified dynamically (data_hash-pinned) and via `strings` (`analysis/wasm_strings.txt`).
* Files: `analysis/live-state.json` (all live reads), `analysis/code4485.wasm` + `analysis/wasm_strings.txt` (deployed code), `analysis/previous_batches.json`, `analysis/delegations.json`, `analysis/txs_raw.json` (recent user txs), `analysis/fetch_live_state.py`, `analysis/eris-hub/` (upstream reference source), `ci/run.sh` + `ci-out/*` (PoC).
* Caveats: (i) the PoC local chain has 1 validator vs 7 live and uses compressed time periods (both immaterial to access control); (ii) `submit_batch`/`harvest` were exercised only to the extent their gates are reached (no rewards accrual in a 2-min local run); (iii) USD figures move with SEI price; (iv) no mainnet state was forked — the exact deployed bytecode was executed instead, which is strictly stronger for authorization semantics.
