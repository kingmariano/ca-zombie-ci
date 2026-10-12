# Armada (Solana) — L2 Phase-2 deep-dive: zombie-hunt II

**Date:** 2026-10-12 · **Chain:** Solana mainnet-beta · **Status:** read-only; no transactions sent; all proofs via `simulateTransaction` (chain-native, read-only) and on-chain account dumps. PoC verification runs in CI (`kingmariano/ca-zombie-ci`, branch `armada`).

**Target:** Armada CLP-Vault program `ArmN3Av2boBg8pkkeCK9UuCN9zSUVc2UQg1qR2sKwm8d` (Mithraic Labs / PsyFi lineage; closed-source program, state crate public as [`clmm-bindings`](https://crates.io/crates/clmm-bindings), CPI reference [`clpcpi`](https://crates.io/crates/clpcpi)).

**Triage row (L-2 Phase-1, `l2-triage-c`):** `armada` · LIVE-FUNDED · **$352,107.64** (medium confidence) · "24 CLP vaults + token vaults; whirlpool position layer not separately valued — understates."

---

## 1. TL;DR

| # | Target | Live extractable (unprivileged) | Why closed / open | Latent risk |
|---|--------|-------------------------------|-------------------|-------------|
| 1 | CLP-Vault program `ArmN3Av2…` + 24 vaults ($554,524 live) | **$0** | All 11 attack-path simulations revert on live-state gates: SPL burn authority (`owner does not match`), `has_one` vault-account checks (6013/6014/6015), fee-owner checks (6019/6021), MM signer (3010), admin check (6018), swap source/dest check (6028). No permissionless instruction moves value to a caller-chosen account. | **High (privileged):** admin key `7btJUB…` (a Squads v3 multisig vault) can set `withdrawal_fee`≈100% and capture all LP withdrawal value — demonstrated in simulation (§7). Same key is the program **upgrade authority**. 5 hot MM EOAs + `features_enabled=1` (JIT-swap feature) on 14 vaults. |
| 2 | Vault LP holders (self-service withdraw) | n/a (H-O) | Withdraw works today at live-fair value: simulation of a real holder withdrawing 0.99747 LP returned 418,678,575 mSOL raw + 1,813,693,950 JitoSOL raw = **1.0004× / 0.9999×** of the independently computed live pro-rata share. | Deposit pricing ≠ withdraw pricing (round trip loses ~21% A / ~12% B on the tested vault) — a user-loss/accounting inconsistency, not an extraction path. |

**Total live value in custody: $554,524.13** (staging accounts $353,048.78 + Orca CLMM positions $201,475.36), slot **455,861,230** (2026-10-12 01:13:21 UTC). The triage figure ($352,107.64) was **staging-only** and understated by ~$202K (the CLMM position layer). 4 additional tokens are unpriced and have **no market** (no DEX pairs, no Jupiter price): PSY 2,611,232.31, `GePFQaZ…` 4,526.77, `C4Kkr9NZ…` 41.11, `CKa9…` 0 — excluded from the USD total (if any had value the total would be higher, not lower).

**Headline: E-U = $0.00 · confidence high.** (H-O = $554,524.13 · P = $554,524.13 · S = $0.)

---

## 2. What the protocol is, and what was actually deployed

Armada is a *concentrated-liquidity provider (CLP) vault*: each `ClpVault` PDA owns SPL token staging accounts (`token_vault_a/b`) and a bundle of Orca Whirlpool positions; depositors receive LP tokens (`lp_mint`, mint authority = the vault PDA). A market-making key rebalances positions; a fee owner collects fees.

- Program: `ArmN3Av2boBg8pkkeCK9UuCN9zSUVc2UQg1qR2sKwm8d`, owner `BPFLoaderUpgradeab1e…`, executable.
- ProgramData: `6D2vs5yJxzGBuzH7x133tmghi9ur37ummJJday6gi8Pt`, **deployed slot 262,177,169 = 2024-04-25 14:28 UTC** (last upgrade; earlier upgrades Jul 2023 → Jan 2024).
- **Upgrade authority: `7btJUBpZq3pzhYJBF9pkCBJ4xa4de1ZnUeJ4WiA5TiHT`** (system-owned, 0-data, 35.57 SOL). The 2024-04-25 upgrade transaction was executed through **Squads v3 multisig** programs (`SMPLecH534NA9acpos4G6x7uf3LWbCAwZQE9e8ZekMu`, `SMPLKTQhrgo22hFCVq2VGX1KAktTWjeizkhrdB1eauK`); `7btJUB` signs via CPI as the multisig vault — it is not a hot EOA. Same key is `admin_key` of 23/24 vaults.
- The program stores **its own Anchor IDLs on-chain** in 5 zlib-compressed blob accounts (discriminator `184662bf3a907b9e`, authority `7VKPHnP2MnahWVAZs7WadH1AWPfGnChS1H6qknEbRPDd`), versions **v0.1.1, v0.1.2, v0.1.3**. The deployed binary is **v0.1.3** (proven by observed v0.1.3-only error codes 6026 `CleanupIxNotFound`, 6028 `InvalidSwapVault`). Extracted IDLs are in `analysis/onchain-idl-0.1.{1,2,3}.json`.
- Instruction set (v0.1.3): `initialize`, `updateConfig`, `initializePositionBundle`, `deposit`, `withdraw`, `openPosition`, `closePosition`, `increaseLiquidity`, `decreaseLiquidity`, `collectRewards`, `collectFees`, `updateTokenMeta`, `setVaultRatioCache`, `externalSwapSetup`, `externalSwapCleanup`.
- No Anchor IDL account at `["anchor:idl"]` PDA; no IDL on Solana registry. Dispatch is partially runtime-hashed (name strings `"global"`, `"external_swap_setup"` are in `.rodata`), so a BPF dump + disassembly was also performed (`analysis/armada-program.so`, `analysis/armada-disasm.txt`).

### The 24 vaults (slot 455.86M)

| vault | pair | live USD | LP supply | LP holders | admin | MM | fe |
|---|---|---|---|---|---|---|---|
| `6JwmYu4c…` | USDC/PYTH | $223,207 | 204,501.99 | 1 | 7btJUB | 2xFbZtJj | 1 |
| `DRgwP2sZ…` | USDC/JitoSOL | $124,684 | 55,211.79 | 13 | 7btJUB | 2xFbZtJj | 1 |
| `7c75jrcM…` | INF/USDC | $80,866 | 221.97 | 209 | 7btJUB | 2xFbZtJj | 1 |
| `HTKMVZXE…` | mSOL/JitoSOL | $77,206 | 234.33 | 13 | 7btJUB | 3w6py7p6 | 0 |
| `7rMx8a5V…` | SOL/USDT | $18,931 | 82.91 | 18 | 7btJUB | 2xFbZtJj | 1 |
| `AAqJh2pA…` | SOL/USDC | $9,402 | 197.46 | 43 | 7btJUB | 3w6py7p6 | 0 |
| `Beaq19pN…` | JUP/USDC | $4,720 | 4,649.85 | 18 | 7btJUB | 2xFbZtJj | 1 |
| `6GvyFRCY…` | BONK/USDC | $4,239 | 221,294.02 | 21 | 7btJUB | 2xFbZtJj | 1 |
| `CxwD1AWk…` | USDC/HXRO | $3,530 | 20,374.40 | 3 | 7btJUB | 2xFbZtJj | 1 |
| `GCyxDsKh…` | PSY/USDC | $2,913 | 1,395,386.63 | 6 | 7btJUB | 9xq6X56W | 1 |
| `GAXzSmxk…` | SOL/FM | $1,856 | 429.81 | 24 | 7btJUB | 9xq6X56W | 1 |
| `5pRwjZip…` | USDC/FM | $1,426 | 8,798.83 | 23 | 7btJUB | 9xq6X56W | 1 |
| `9AFtBurZ…` | USDC/JitoSOL | $619 | 254.67 | 9 | 7btJUB | 3w6py7p6 | 0 |
| `H8oSVjrY…` | bSOL/C4Kkr9NZ | $417 | 1.69 | 2 | 7btJUB | 2xFbZtJj | 1 |
| `GyU6WALG…` | USDC/GePFQaZ | $247 | 553.92 | 1 | 7btJUB | 2kh5MQHV | 0 |
| `ARSSATav…` | USDC/HXRO | $234 | 1,241.09 | 25 | 7btJUB | 3w6py7p6 | 0 |
| `jkBWDkYC…` | SOL/USDT | $24 | 0.14 | 1 (admin 9xq6X56W itself) | **9xq6X56W** | 9xq6X56W | 1 |
| `EcyuJx6P…` | SOL/USDT | $1.74 | 0.0056 | 1 | 7btJUB | 2xFbZtJj | 1 |
| `9QSvxJjT…` | tBTC/USDC | $2.05 | 0.000036 | 0† | 7btJUB | 3w6py7p6 | 0 |
| `4ASsWZv9…` | tBTC/USDC | $0.59 | 0.000008 | 1 | 9xq6X56W | 9xq6X56W | 0 |
| `3DHHGTZw`, `5N3KrNt4`, `AscsFRRm`, `F3GMe197` | — | $0 (empty) | 0 | 0 | 7btJUB | — | 0 |

† holder query 403'd once (rate limit) — not material at $2.

- All 24 vaults: **`withdrawal_fee = 0`**; `performance_fee = 0.095×2³²`, `market_making_fee = 0.0475×2³²` (except two with `0.1×2³²`).
- Vault staging token accounts are **owned by the ClpVault account itself** (e.g. `6JwmYu…`'s USDC staging `JBuW7rDWsoYz…` owner = `6JwmYu…`), and LP mint authority = the vault PDA. This is the structural reason why no third party can move vault tokens.
- `features_enabled = 1` (external/JIT swap feature) on 14 vaults; 0 on 10.
- Second admin key `9xq6X56Wus7xpCjEQiQQFiwYcB1ZJNS9j9Z2An5wtmF9` is a plain EOA (signs directly; last activity 2024-05-03) administering the oldest vault (`jkBWDkYC…`, $24, 100% of LP held by itself).
- Program activity: 1,000-signature window spans 2024-05-29 → **2026-07-28** (newest); the newest txs are failed probes (`InstructionFallbackNotFound`, custom 101). Real instruction traffic samples span slots 288M–369M (2024).

---

## 3. Method: how "extractable" was decided

Because the program is closed-source, the audit is **behavioral on the deployed binary**:

1. Full account/state reconstruction from the on-chain IDLs + raw account decoding (ClpVault layout, Orca Whirlpool/Position layouts verified against known-good accounts).
2. Exact-value measurement: staging balances (token accounts), Orca CLMM position amounts (liquidity × tick math), DefiLlama prices.
3. **`simulateTransaction` attack suite** against live state: each candidate unprivileged path was executed as a simulation (no signatures verified, nothing broadcast) with attacker-controlled accounts substituted for the legitimate ones; outcomes were read from the Anchor/SPL error codes. A path is "closed" only when the *live* program reverts it with the expected gate; a path is "open" only when the simulation succeeds and the resulting account deltas show value moving to the attacker.
4. Cross-checks: exact account lists and instruction data taken from real historical transactions (harvested from 100 recent txs), so the simulations are shaped exactly like legitimate calls.

### Attack surface — every permissionless entry point

| Instruction | Who may call | Simulated attack | Result |
|---|---|---|---|
| `withdraw` | LP holder (self) | attacker payer + **victim's LP account** (2 variants) | **Revert**: SPL Token `Custom 4` "owner does not match" at the burn CPI (attacker cannot burn LP it doesn't own; program has no delegate path). |
| `withdraw` | LP holder | wrong `lpMint` / `tokenVaultB` / `clp` / `tokenVaultA` substituted | **Revert**: 6015 / 6014 / 6007 / 6013 |
| `withdraw` | LP holder | self-withdraw by real holder (fair-value control) | **Success**, payout = live-fair (1.0004× A, 0.9999× B) |
| `deposit` | anyone | round trip deposit→withdraw, 3 sizes (1 raw, 1.0, 100 LP) | **Success but net LOSS** (ΔA −235,754 / −23,533,072 raw; ΔB −1,405,074 / −140,255,686 raw). No profit; see §8 caveat. |
| `collectFees` | anyone (keeper) | fee account = attacker ATA; MM-fee account = non-MM attacker ATA | **Revert**: 6019 `IncorrectFeeOwner`; 6021 `IncorrectMMFeeOwner` |
| `collectRewards` | anyone (keeper) | fee accounts = attacker ATAs (both slots) | **Revert**: 6019 `IncorrectFeeOwner` |
| `setVaultRatioCache` | anyone | wrong vault/token/clp/lp accounts | **Revert**: 6013/6014/6015/6007; requires exact `[position,tickLower,tickUpper]×N` remaining accounts (6016 otherwise) |
| `externalSwapSetup` | **MM signer** | MM account present but not signing | **Revert**: 3010 `AccountNotSigner` |
| `externalSwapSetup/Cleanup` | MM | source/dest = other vault's account / attacker ATA | **Revert**: 6028 `InvalidSwapVault` (explicit `Bad source:`/`Bad dest:` logs) |
| `externalSwapCleanup` | anyone? | cleanup called alone (no setup) | **Success but balance-neutral** (source/dest deltas = 0; cache poke only). Low impact; noted for completeness. |
| `updateConfig` | admin | attacker signer | **Revert**: 6018 `InccorectAdminKey` (logs show expected vs given key) |
| `updateTokenMeta` | admin | non-admin payer | **Revert**: 6024 `IncorrectAuthority` (`update_token_meta.rs:121`) |
| `initialize` | anyone | — (creates a *new* vault; token vaults & LP mint are `init`-created PDAs owned by the new vault; mints are validated against the CLP) | No path to point a new vault at an existing vault's accounts: `init` fails on existing accounts, and transfers from a vault's accounts require that vault's PDA signature. |
| MM instructions (`open/closePosition`, `increase/decreaseLiquidity`) | MM signer | not individually simmed — same `Signer`+`has_one` pattern, error 6006 `MarketMakerMustSign` present in v0.1.2/v0.1.3 | closed by construction (signer constraint) |

**Cost/preconditions:** every attack path reverts; the only "costs" measured are CU (e.g., attacker withdraw attempt burned 186,202 CU before reverting). No flash-loan/capital requirement exists for any path because none executes.

---

## 4. Live-state assessment (addresses, roles, balances)

All reads at slot ≈ 455,861,230 (2026-10-12 01:13 UTC) unless stated. Full dumps: `analysis/recon1.json` (program + 24 decoded vaults), `analysis/recon2.json` (192 vault-linked accounts: token accounts, LP mints, Orca positions/bundles), `analysis/recon3_mints.json` (18 mints), `analysis/recon4_activity.json` (1,000 signatures), `analysis/recon6_lpholders.json` (LP holder distribution), `analysis/valuation3.json` (per-vault USD incl. positions).

**Value reconciliation:**
- Triage (Phase 1): $352,107.64 — reproduced as **staging-only $353,048.78** (Δ = price drift).
- This phase: **+$201,475.36** in Orca Whirlpool position liquidity (29 of 48 positions have L>0) → **$554,524.13** total.
- DefiLlama's own adapter currently reports $550,808 (last data 2026-10-11) — consistent with our number, confirming the triage undercount.
- Unpriced (no market): PSY `PsyFiqqjiv41G7o5SMRzDJCu4psptThNR2GtfeGHfSq` 2,611,232.31; `GePFQaZKHcWE5vpxHfviQtH5jgxokSs51Y5Q4zgBiMDs` 4,526.77; `C4Kkr9NZU3VbyedcgutU6LKmi6MKz81sx6gRmk5pX519` 41.11; `CKa9Xn2XrtroKD5fz7UdddJ8p7NP99yS3oYhdbb5VnyD` 0 (DexScreener: no pairs for all four; Jupiter price APIs 404).

**LP token distribution (who is H-O):** real, multi-party distribution — 209 holders on `7c75jrcM`, 43 on `AAqJh2pA`, 25 on `ARSSATav`, 24 on `GAXzSmxk`, 23 on `5pRwjZip`, 21 on `6GvyFRCY`… down to single-holder vaults (`6JwmYu` 1 holder, `jkBWDk` 1 holder = its admin). Several LP owners are "ghost" pubkeys with no on-chain account (`9HArgPaKd1…`): their token accounts exist and hold LP; because `withdraw` requires the LP owner to sign *and pay the fee*, such holders would need a ~0.001 SOL donation to their key before they can self-withdraw (not stuck, but friction).

**Program upgrade posture:** upgradeable; no upgrades since 2024-04-25; upgrade authority = multisig vault `7btJUB…` (§2).

---

## 5. What an attacker can / cannot do (exact call paths)

Closed (simulated reverts, exact error codes above):
- Cannot withdraw/burn another holder's LP (SPL burn authority; Custom 4).
- Cannot redirect withdrawals, deposit mints, fee collections or rewards to an attacker-controlled account (6019/6021/6013-6015/6028).
- Cannot touch the MM-only liquidity/swap instructions (3010/6006; source/dest checks 6028).
- Cannot alter vault config or metadata (6018/6024).
- Cannot fake a vault that references another vault's token accounts (init + PDA ownership).

Open (unprivileged, but no value transfer to the caller):
- Anyone can deposit (priced against vault state), refresh the ratio cache, and run the fee/reward keeper instructions — the keeper calls only push value into fee-owner-validated accounts.
- `externalSwapCleanup` can be called standalone by anyone; on live state it is balance-neutral (cache poke).

Privileged (not E-U): the multisig admin key can (a) set `withdrawal_fee` up to ~100% (u32 max / 2³²) and route all withdrawal value to `fee_owner` — **demonstrated**; (b) change `fee_owner`, `market_making_key`, strategy, `features_enabled`; (c) upgrade the program (upgrade authority = same key). The 5 hot MM EOAs on 14 swap-enabled vaults are a secondary key-compromise risk for JIT-swap value extraction (bounded by the swap-cache sanity checks).

---

## 6. Live extraction test (the "can anyone take the money" experiment)

- **Victim-LP theft:** simulation burns the *victim's* LP account with the attacker as sole signer. The transaction executes 186,202 CU of the full flow (Orca `UpdateFeesAndRewards`, `DecreaseLiquidity` CPIs) and dies only at the LP burn with SPL `Custom 4` "owner does not match" — i.e., the vault program itself does not gate on `user_lp_token_acct.owner == payer` early, but SPL Token's burn semantics make the attack impossible. Because the whole transaction reverts, no state change occurs.
- **Privileged seizure (control):** admin sets `withdrawal_fee = 4294967295`, then the real holder withdraws 997,470 raw LP: holder receives **0** mSOL + **0** JitoSOL; `fee_owner` receives 419,128,724 mSOL raw + 1,813,207,853 JitoSOL raw; LP supply decreases by exactly 997,470. This is the *only* live path we found that moves vault value to a different party — and it requires the admin signature (P, not E-U).

---

## 7. CI verification

CI job: `armada/ci/run.sh` → `ci/verify.py` (read-only; env-provided RPC; keys never printed). It reproduces program meta, the 24-vault enumeration, and 5 decisive simulations with expected error codes asserted:

| check | expected | observed |
|---|---|---|
| `withdraw` self by real holder | success | **success** (196,346 CU) |
| `withdraw` attacker vs victim LP | revert, code 4 | revert, **Custom 4** |
| `collectFees` attacker fee account | revert, code 6019 | revert, **6019** |
| `externalSwapSetup` without MM sig (paired w/ cleanup) | revert, code 3010 | revert, **3010** |
| `updateConfig` without admin | revert, code 6018 | revert, **6018** |

**Result: 5/5 PASS** — artifacts in `ci-out/verify.json`, `ci-out/verify-ci.json` (downloaded CI artifact) and `ci-out/verify.log`; **CI run: https://github.com/kingmariano/ca-zombie-ci/actions/runs/38191200745** (artifact `result-armada`, 2026-10-12T01:15Z). Locally, the wider suite (~50 `simulateTransaction` runs incl. deposit math, round trips, ratio-cache, rewards/fees substitution, external-swap substitution, privileged seizure) behaved as expected; scripts are in `analysis/sim_*.py`.

---

## 8. Verdict, residual risk, caveats

**Verdict: E-U = $0.00 (high confidence).** No unprivileged attacker can extract live value from the Armada CLP-Vault program. The value ($554,524) is recoverable by LP holders at fair value (H-O), and controllable only through the multisig admin/upgrade authority (P).

Residual / latent risk:
1. **Admin multisig can capture 100% of withdrawals** via `withdrawal_fee` (demonstrated) and can upgrade the program. Single point of control for $554K. (Mitigant: Squads v3 multisig, not a hot key.)
2. **5 hot MM EOAs** (`2xFbZtJj…`, `3w6py7p6…`, `9xq6X56W…`, `A533R5K5…`, `2kh5MQHV…`) control positions/swaps on the 14 swap-enabled vaults; a compromised MM could attempt value extraction through JIT swap routes (bounded by swap-cache checks; not evaluated to the same depth).
3. **Deposit pricing inconsistency:** on `DRgwP2sZ` a deposit charged 1.112576 USDC + 0.010933 JitoSOL per LP while the withdraw payout for the same LP was 0.876822 USDC + 0.009528 JitoSOL (round trip loses ~21%/12%). Not exploitable by an outsider, but it silently transfers value from depositors to existing LPs; any user depositing today overpays by double-digit %.
4. One vault (`jkBWDk`, $24) is administered by a plain EOA (`9xq6X56W…`), not the multisig.

Caveats & limitations:
- Closed-source program: conclusions are behavioral (simulations on the deployed binary) + disassembly of the stripped SBF; we did not fully reconstruct the withdraw/deposit arithmetic. The `withdraw`-vs-`deposit` basis mismatch (3.) is measured, not explained.
- Simulations use `sigVerify:false` (no signatures) and `replaceRecentBlockhash:true`; they exercise the real program with real state. Nothing was broadcast. RPC reads/simulations are point-in-time at slot 455,861,230.
- USD values use DefiLlama prices at 2026-10-12 ~01:20 UTC; CLMM position amounts use Orca's integer tick math (validated against a known-good pool). 4 unpriced tokens excluded (no market).
- The `collect_rewards` account order in the deployed v0.1.3 binary differs from the stored IDL blob's order (fee accounts sit at indices 5/6, `tokenProgram` at 7, remaining = `[position,tickLower,tickUpper]×N`); gate tests used the deployed order (verified by account-type inspection).

---

## 9. Methodology & sources

- **On-chain (read-only):** Solana mainnet-beta via Alchemy + public RPC fallbacks; `getAccountInfo`, `getMultipleAccounts`, `getProgramAccounts`, `getTokenAccountsByOwner`, `getSignaturesForAddress`, `getTransaction`, `getBlockTime`, `getSlot`, `simulateTransaction`. Key slot: 455,861,230.
- **Program artifacts:** BPF dump `6D2vs5y…` → `analysis/armada-program.so` (1,423,856 B, ELF64-BPF, stripped), `llvm-objdump-14` disassembly (`analysis/armada-disasm.txt`), `.rodata` strings (source paths, error messages, allow-listed program IDs `JUP6Lkb…` (Jupiter v6), `exch6P2D…` (Psy Token Exchange)).
- **IDL recovery:** 5 on-chain zlib blobs (v0.1.1/0.1.2/0.1.3) decompressed to `analysis/onchain-idl-*.json`; cross-checked with DefiLlama adapter IDL and the `clmm-bindings`/`clpcpi` crates (docs.rs/crates.io, MIT/public).
- **Real instruction samples:** 100 recent txs → 22 withdraw, 6 collectFees, 6 collectRewards, 8+8 external-swap, 1 setVaultRatioCache, 6 decreaseLiquidity, 1 increaseLiquidity, 1 closePosition (`analysis/ix-full-samples.json`).
- **Pricing:** DefiLlama coins API (`coins.llama.fi`), DexScreener (for the 4 unpriced mints → no pairs).
- **Files index:** `analysis/` (scripts, dumps, IDLs, disassembly, valuation), `ci/` (verify job), `ci-out/` (CI artifacts), `summary.json`.

*No secrets are contained in this folder; all scripts read credentials from the environment. No mainnet transaction was signed or sent at any point.*
