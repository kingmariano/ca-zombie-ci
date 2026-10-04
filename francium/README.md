# H-29 · Francium (Solana) — wind-down vaults, authorization-gated withdrawals

**Date:** 2026-10-04 · **Chain:** Solana mainnet · **Status:** read-only; `simulateTransaction` proofs only; **no mainnet transactions sent**

**Headline:** external unprivileged attacker can extract **$0.00** today (confidence: **medium**). All measured live custody (≈**$1,076,818**) is user/holder-recoverable (H-O) and sits behind explicit caller-authorization checks proven by RPC simulation; the only permissionless paths (liquidations) yield dead-pool LP collateral, not profit. Residual risk: the programs are still **upgradeable** by a live team key (P), and the wind-down self-service path currently rejects even the legitimate owner (`InvalidData`), so part of the H-O balance may be effectively stuck (S) until the team's custody-claim flow completes.

---

## 1. TL;DR

| Target | Live value (priced) | Unprivileged extractable (E-U) | Why closed / open | Latent risk |
|---|---|---|---|---|
| Francium Lend reserves (FC81…, 87 reserves, 52 funded) | **$663,523** (USDC 224.4k, SOL 1,470, wETH 22, stSOL 348, RAY 25.2k, ORCA 14k, mSOL 97.9, +long tail) | **$0** | Reserves are in wind-down; share redemption is user-gated; no obligation accounts exist (borrowers are strategy credit accounts), oracle fields zeroed/stale; no permissionless borrow path | Protocol upgrades (live authority); stale accounting |
| LYF strategy vaults (Raydium 2nAA…, Orca DmzA…) | **$411,053** pending user tokens in `tknAccount0/1` (e.g. 52,771 USDC + 566.8 SOL in SOL-USDC strategy alone) | **$0** | `SwapAndWithdraw` requires `user_info.user_main` **or** strategy admin to sign (`NeedUserOrAdminPermission`, `wind_down.rs:110`); destination accounts are raw-constrained to the position owner's accounts (`ConstraintRaw`, acct `user_tkn_account_0/1`) | Same code family as the 2022-12 Raydium-incident-affected positions; new wind-down code is unaudited |
| LYF user positions (52,187 accounts of 285B; 135 strategies) | claims on the above | **$0** | Every value-moving user instruction (`unstakeLpWithType`, `repay*`, `swapAndWithdraw`, `removeLiquidity`) requires the position owner or admin; permissionless `liquidate*` only returns LP collateral | Liquidate* math unaudited (not fully traced) |
| Lend-reward farms (3Kat…, 65 pools, 44 funded) | **$194** rewards + user-staked LP | **$0** | Farmer state is a PDA `[user, pool, user_ata]`; rewards are paid into the farmer's own reward account; unstake requires the user's stake account | Unclaimed rewards of dead pools |
| Protocol admin/upgrade authority (shared EOA `6M1rN486…`) | controls all 4 programs | n/a | **P** — live upgrade authority (1 SOL system account); team can upgrade/replace logic | If key leaks/abandoned → future drain; not attacker-accessible today |

**Total live extractable now: $0.00 (E-U) — confidence medium.**
**Total measured live custody: $1,076,818.19 (H-O, priced at 2026-10-04).**

---

## 2. What the protocol is and how it is deployed

Francium was a Solana leveraged-yield-farming / strategy platform (SOL-USDC etc. on Raydium AMM V4 and Orca). The website now says "Service terminated"; DefiLlama marks it dead 2025-11-30 (last-known TVL $6.144M, stale 302d). Contrary to the "abandoned" label, **the team has been actively upgrading the programs** — the two LYF programs were last deployed ~26 days before this audit (slots 447,452,146 / 447,452,190), adding an entire **wind-down / asset-custody** instruction set (strings: `WindDown*`, `Liquidate*`, `EmergencyCustody`, `CustodyRefill`, `AdminCustodyPayout`, …).

Programs (all upgradeable, same authority):

| Program | ID | Accounts | Last deploy slot | Upgrade authority |
|---|---|---|---|---|
| Lending | `FC81tbGt6JWRXidaWYFXxGnTk4VgobhJHATvTRVMqgWj` | 94 (87 reserves 495B, 6 oracle-info 130B, 1 market 194B) | 445,051,453 | `6M1rN486dffB6d7q35qdxHLuWUFF9QtbTjLnPtEyRyJd` (live system account, 1 SOL) |
| Lend-reward | `3Katmm9dhvLQijAvomteYMo6rfVbY5NaCRNq9ZBqBgr6` | 36,996 (65 farms 530B, 36,931 farmer states 313B) | 431,960,034 | same |
| LYF Raydium | `2nAAsYdXF3eTQzaeUQS3fr4o782dDg8L28mX39Wr5j8N` | 27,824 (80 StrategyState 903B, 26,766 UserInfo 285B, vaults 418/248/772B) | 447,452,146 | same |
| LYF Orca | `DmzAmomATKpNp2rCBfYLS7CSwQqeQTsgRYJA1oSSAJaP` | 25,505 (55 StrategyState 967B, 25,421 UserInfo 285B) | 447,452,190 | same |

Layouts were decoded from the official `francium-sdk@1.4.16` Anchor IDLs (Raydium: 50-field StrategyState = 895B + 8B discriminator; Orca: 48-field = 959B + 8B) and the Dappio `RESERVE_LAYOUT`/`FARM_LAYOUT` (495B/530B), cross-checked against raw account data (embedded mint/pubkey offsets verified, e.g. reserve `shareMint` matches the SDK's `lendingPoolShareMint`).

**Historical exploit correction:** the corpus note "known 2023 exploit" traces to the **2022-12-16 Raydium AMM V4 incident** ($4.4M, DefiLlama "Social Engineering/Malware"), which hit Francium's leveraged positions; Francium's own GitHub (`Francium-DeFi/dec_16_exploit`) contains the loss accounting (e.g. SOL-USDC vault loss ≈$2.92M, 9 pools ≈$4.4M). No Francium-program exploit is recorded in DefiLlama's hacks dataset.

---

## 3. Live value measured (2026-10-04, slot 453,190,351)

All balances read with `getMultipleAccounts`/`getTokenAccountBalance`; USD via DefiLlama coins API (SOL $120.66, USDC $1.0000). Full tables: `analysis/balances.json`, `analysis/summary_tables.json`.

| Category | USD | Accounts | Notes |
|---|---|---|---|
| `reserve_liquidity` (FC81 reserve supply accounts) | **$663,523.03** | 52 funded / 87 | Top: USDC 224,408.86; SOL 1,469.85; wETH 21.97; stSOL 348.10; RAY 25,206.63; ORCA 14,031.87; mSOL 97.86; USDT 43,960.77; ATLAS 6.14M (≈$940); long tail ≈0 |
| `strategy_token` (`tknAccount0/1` of 135 strategies) | **$411,053.21** | 184 funded | Top: 52,771 USDC + 566.8 SOL (strategy `34eXEXyp`, SOL-USDC); 43,266 USDT; 37,558 SRM; 21,235 USDC; 15,014 USDT; 10.8M 7xKXtg (≈$3.4k); … |
| `farm_rewards` (unclaimed FZN/RAY/etc.) | **$194.31** | 14 funded | 1.47M FZN in USDC farm (`34R2ZVwg…`), plus RAY/mSOL dust |
| `other` (rewards/stake-pool buffers, priced part) | **$2,047.65** | 230 | ORCA 558.8, MNDE 41.7k |
| `farm_staked` (users' staked Francium LP/shares) | unpriced | 44 funded | e.g. 3.887B USDC-share (`A9H3fAqk…`) — value is the reserve/LP backing above (avoid double counting) |
| `strategy_lp`, `reserve_fee`, `credit_debt` | unpriced / not assets | — | credit tokens = strategy debt receipts (negative value) |
| **Total priced** | **$1,076,818.19** | | H-O category |

The SOL-USDC strategy `34eXEXypQiwyQhMRAMbCEJSs16SVaN3C6wzPicEcBTH1` is a clean example of wind-down state: `totalLp=0`, `totalShares=0`, `pendingTkn0=52,771,336,587` (52,771.34 USDC), `pendingTkn1=566,828,868,557` (566.83 SOL) — and its vault token accounts hold exactly those amounts. `admin = 7MBLg6oV5phip11YBbJPuq7u38kdzSi9PM3BifKSpLaR` for all 135 strategies; `liquidateLine=120` (1.2×).

---

## 4. The mechanism: why an attacker cannot extract (proven by simulation)

The main value-moving instruction for the stranded pending tokens is **`SwapAndWithdraw`**. The deployed program uses legacy 8-byte discriminators (not the current Anchor `sha256("global:…")` values — `5d26b04eab5f00c3` is rejected with `InstructionFallbackNotFound`; the working selector is `6f607d39534edca0` + `withdrawType:u8`, per Dappio's mainnet builder).

Three `simulateTransaction` runs against the live program (`sigVerify:false`, `replaceRecentBlockhash:true`; no transaction broadcast), full 25-account wiring (strategy, Raydium AMM V4 SOL-USDC `58oQChx4…`, OpenBook market parsed via `Market.load`):

| Run | Signer | `user_tkn_account_0/1` | Result | Interpretation |
|---|---|---|---|---|
| **CONTROL** | victim `3CBKizNk…` (position owner) | victim's own USDC + wSOL ATAs | `Custom:6004 InvalidData` at `programs/lyf-raydium/src/wind_down.rs:122` | All account constraints pass; handler reached; wind-down state rejects this `withdrawType` (even for the owner) |
| **ATTACK-A** | unrelated real wallet `6joanWsS…` | victim's own ATAs | `Custom:6027 NeedUserOrAdminPermission` — "Need user or strategy admin signature" at `wind_down.rs:110` | **Authorization gate: caller must be the position owner or strategy admin** |
| **ATTACK-B** | unrelated wallet `6joanWsS…` | attacker's own ATAs | `Custom:2003 ConstraintRaw` on `user_tkn_account_0` | Destination accounts are raw-constrained to the position owner's accounts — no redirect |

Dispatch sanity check: a bogus discriminator returns `InstructionFallbackNotFound (101)`; the legacy selector logs `Instruction: SwapAndWithdraw`, proving the deployed dispatch.

The same program family contains explicit error strings for the gates: `InvalidUserInfoAccount`, `NeedUserOrAdminPermission` ("Need user or strategy admin signature"), `AlreadyInLiquidationOrWithdraw`, `InvalidLiquidator` (Raydium) and `UnauthorizedCaller` ("Caller is not authorized for this position"), `NeedAdminPermission`, `InvalidLiquidator` (Orca). The reward program stores the user's own `stake_token_account`/`rewards_token_account` inside the farmer PDA and requires the stake-account PDA seeds `[user, pool, user_ata]`.

**Permissionless paths assessed:** `LiquidateUnstakeLp`/`LiquidateRemoveLiquidity`/`LiquidateSwap`/`LiquidateSettle` are permissionless by design (liquidator signer). They only make sense when a position is underwater (`liquidateLine=120`); the liquidator must repay the debt to receive LP collateral. For the surviving strategies the LP collateral is in dead Raydium/Orca pools (unpriced; e.g. LP mints `8HoQnePL…`, `FbC6K13M…`) and the debt has compounded ~20× (reserve `cumulativeBorrowRate ≈ 20`); paying debt to seize dead LP is a net loss, so there is no rational E-U profit. I did not find a bug that lets a liquidator seize more than the debt repaid; this path remains the top residual-uncertainty item (medium-low confidence it is closed).

**Lending program:** 87 reserves hold the $663k; `shareSupplyPubkey` accounts are all empty (shares live with users), no obligation accounts exist, and the deployed strings show only "retained wind-down no-op". There is no permissionless borrow/liquidate on this deployment; redemptions are user share burns against a stale/insolvent reserve (borrowed wads ≈10–20× available, oracle zeroed, `last_update_stale` set on many). This is not attacker-extractable, but it is why the reserve backing is worth far less than nominal.

---

## 5. What an attacker can/cannot do — exact call paths

**Cannot (proven):**
- `SwapAndWithdraw(strategy 34eXEXyp, victim_user_info, attacker_accounts)` → `NeedUserOrAdminPermission` (6027) unless signer == `user_info.user_main` or strategy admin.
- Redirecting pending tokens to attacker-owned token accounts → `ConstraintRaw` (2003).
- Using a victim `user_info` with an attacker signer on the same path → 6027.

**Can (permissionless, no profit found):**
- Call `Liquidate*` on any position that is actually liquidatable; repays debt and receives LP collateral (dead-pool LP). Also `stakeLp`/`removeLiquidity` cranks that only move value between the strategy's own vaults.
- Call the reward program's farming instructions for one's own stake only; farmer PDAs are derived from the user's own ATA.

**Privileged (P):** upgrade all four programs (shared live authority `6M1rN486…`), `AdminStartCustody`/`AdminCustodyPayout`/`AdminSweepCustody`/`adminRepayBadDebts`/`adminBurnBorrowCredit`, etc.

**Holder-only (H-O):** position owners can claim pending tokens / unstake / repay through the wind-down custody flow (signature required). Note the CONTROL simulation shows the old `SwapAndWithdraw` path returning `InvalidData` even for the owner — the team appears to route claims through the new custody/receipt mechanism; if that flow is not usable, some of the $1.08M is effectively stuck (S).

---

## 6. PoC / verification

- **Type:** Solana RPC read-only simulations (no forks; no transactions signed with real keys or sent to mainnet). Implemented **npm-free in Python** (`analysis/simulate_gate.py`): hand-serialized legacy transactions + `simulateTransaction` with `sigVerify:false`, `replaceRecentBlockhash:true`; a Node/web3.js cross-check (`poc-sim/`) reproduces the same results.
- **Cases (strategy `34eXEXyp`, live SOL-USDC AMM + OpenBook market, 25-account wiring):**

| Run | Signer | `user_tkn_account_0/1` | Program result | Interpretation |
|---|---|---|---|---|
| CONTROL | position owner `3CBKizNk…` | owner's own USDC + wSOL ATAs | `InvalidData (6004)` at `wind_down.rs:122`, units 20,383 | All account constraints pass; handler reached; wind-down rejects the request even for the owner |
| ATTACK-A | unrelated wallet `6joanWsS…` | owner's ATAs | `NeedUserOrAdminPermission (6027)` at `wind_down.rs:110`, units 20,518 | **Caller must be position owner or strategy admin** |
| ATTACK-B | unrelated wallet `6joanWsS…` | unrelated wallet's ATAs | `ConstraintRaw (2003)` on `user_tkn_account_0`, units 18,840 | **Destinations are bound to the position owner** |

- **Result:** 3/3 decisive simulations reproduced the expected gate errors locally and in CI; raw output `ci-out/sim_gate.json`, logs `ci-out/sim_gate.log`.
- **CI:** `bash /home/heisenberg/CA/ci/ci-run.sh francium` → GitHub Actions run URL: _pending / see `ci-log.txt`_ (workflow `poc.yml`, repo `kingmariano/ca-zombie-ci`, branch `francium`). First CI run (state pass, slot 453,211,802): `https://github.com/kingmariano/ca-zombie-ci/actions/runs/37191218819`.
- **Dispatch sanity check:** bogus 8-byte discriminator → `InstructionFallbackNotFound (101)`; the legacy selector `6f607d39534edca0` logs `Instruction: SwapAndWithdraw` on the deployed program (current Anchor `sha256("global:…")` selectors are rejected — the deployed binary predates the rename).

---

## 7. Verdict, classification, confidence

| Class | USD | What it is | Confidence |
|---|---|---|---|
| **E-U** | **$0.00** | No unprivileged extraction found; `SwapAndWithdraw` gate proven (6027), destination ownership proven (2003); liquidations return dead LP for repaid debt | **medium** (high for the tested `SwapAndWithdraw` path; medium overall because not every permissionless `Liquidate*/WindDown*/stable*` handler was traced end-to-end) |
| **H-O** | **$1,076,818.19** priced | Reserve liquidity + pending strategy tokens + rewards, recoverable by position owners via signature | medium |
| **P** | n/a | 4 upgradeable programs under one live team key + admin custody/sweep instructions | high |
| **S** | 0 (risk flagged) | `SwapAndWithdraw` returns `InvalidData` even for the owner; if custody claims are unavailable, part of H-O is stuck | low-medium |

**Residual/latent risk:** (1) upgrade authority is a live single EOA — a key compromise or future upgrade could introduce a drain; (2) the wind-down/custody and `Liquidate*` code is new, unaudited and only partially traced; (3) the 2022 Raydium incident shows this code family already held catastrophic bad debt once; (4) long-tail reserves with stale/zero oracles remain unmeasured for accounting drift.

**What would change the verdict:** an audited trace or simulation showing a `Liquidate*`/custody instruction paying out more than the debt repaid, or a wind-down handler that pays a caller-supplied destination without the raw owner constraint.

---

## 8. Methodology & sources

- DefiLlama protocol metadata + dead-adapter registry (`francium`, deadFrom 2025-11-30); DefiLlama hacks dataset (Raydium 2022-12-16 $4.4M; 2026-06-10 $1.34M legacy AMM); DefiLlama coins prices (2026-10-04).
- On-chain: `getProgramAccounts` (full enumeration and size bucketing), `getMultipleAccounts`, `getTokenAccountBalance`, `getAccountInfo` (ProgramData upgrade authorities), `simulateTransaction` with `sigVerify:false` — public RPC `https://api.mainnet-beta.solana.com`.
- Layouts: `francium-sdk@1.4.16` (official npm, Anchor IDLs for both LYF programs, reserve/reward/farm layouts), `DappioLab/navigator` (deployed-layout `RESERVE_LAYOUT`, `FARM_LAYOUT`, instruction builders/discriminators), ELF strings from on-chain ProgramData (error codes, wind-down instruction names, source paths).
- No mainnet transactions; all simulations were unsigned/broadcast-free (`sigVerify:false`).

**Caveats:** prices are spot DefiLlama values; LP/share tokens are unpriced (value embedded in the priced backing, not double-counted); 242 long-tail mints had no price; Orca UserInfo decodes 1 byte shorter than the account size (deployed padding differs) but the Raydium path — where the value is — matches exactly; the `Liquidate*` family was assessed by design/account surface, not fully simulated.

## 9. Files index

```
francium/
├── README.md                  # this report
├── summary.json               # machine-readable summary
├── analysis/                  # raw dumps, scripts, evidence
│   ├── rpc.py, enumerate.py, balances.py, price.py, verify_state.py, fetch_elf.py
│   ├── strategies.json, farms.json, lend_state.json, balances.json, prices.json, summary_tables.json
│   ├── idl_raydium.json, idl_orca.json, raw_lend_program_accounts.json
│   ├── elf_*.bin, strings_*.txt          # on-chain program ELFs + strings (error codes)
│   └── samples_*.json
├── poc-sim/                   # RPC simulation PoC (CI-run)
│   ├── lib.js, sim_final.js, sim_run.js, sim_swap_partial.js, package.json, strategies.json
├── ci/run.sh                  # CI heavy job (state verify + simulations)
├── ci-out/                    # results written by CI
└── ci-log.txt                 # CI log (written by helper)
```
