# C2-48 · StarkDeFi (Starknet) — abandoned Cairo-1 AMM: live pre-fix `skim` bug on 96 pairs, $0.00 extractable today

**Date:** 2026-10-10 · **Chain:** Starknet mainnet · **Status:** read-only research; all proofs are
`starknet_call` / `starknet_simulateTransactions` (no signatures, no transactions, state discarded) and
public GitHub Actions runs. No mainnet transactions were signed or sent.

**Corpus claim (ZOMBIE-HUNT-II C2-48):** "$72.5k in 67/312 pairs; abandoned Cairo-1 AMM".
**Re-verified reality:** factory has **312 pairs** (all with non-zero reserves; **68 pairs have priced
TVL > $1**, matching the corpus' "67/312 funded" count), priced TVL **$71,875.62** at Starknet block
16,155,532 (DefiLlama reports $71,533.68), plus
**$14,730.64** of accumulated fees sitting in per-pair fee vaults. **96 of the 312 pairs still run the
pre-fix (buggy) `skim` class** — a real, proven, permissionless drain primitive — but the value actually
reachable through it is **$0.00** (nominal token1 balances $114.59; capital requirements 10²–10⁸× the
steal). The $68.8k of TVL is in the *fixed* pair class and is LP-owned.

---

## 1. TL;DR

| Target | Live extractable (unprivileged) | Why closed / open | Latent risk |
|---|---|---|---|
| StarkDeFi pair class `0xaef408ec…` (**96 pairs**, incl. factory's *current* class) | **$0.00** (nominal token1 balances $114.59; SPIST $62.09 of it) | Pre-fix `skim` bug **is live and proven** (starknet_call + full simulateTransaction drain). Every pair with nominally meaningful token1 needs a token0 donation of ≈$100k–$36M+ (priced cases; 3 pairs unpriced) or an unprofitable swap to steal ≤$43 nominal, realizable ≤~$40; the capital-feasible drains (JEDI-P nested meme LPs) are worth ≈$0 | New pairs created today inherit the bug; if any token1 (esp. SPIST) gains value/liquidity, the drain becomes profitable |
| Pair classes `0x30ca5759…` (192), `0x4a56a2e3…` (22), `0x63c46cdc…` (2) | $0.00 | `skim` fixed (proven by 309-pair behavioral probe: transfers 0, no revert) | — |
| Pair reserves (all 312) | — | **H-O**: LP-owned, withdrawable via `burn`/`remove_liquidity` | — |
| Fee vaults (312, one class) | $0.00 | **H-O/P**: `claim_lp_fees` pair-gated; `claim_protocol_fees` fee_handler-or-pair | $14,730.64 fees idle |

**Total live extractable now (external, unprivileged): $0.00 — confidence: high.**
Nominal upper bound if capital, fees and slippage are ignored: **$114.59** (token1 balances of the 96 buggy pairs).

---

## 2. The bug, in exact terms

StarkDeFi is a Solidly-style AMM (volatile `x·y=k` + stable curve), Cairo-1, open-source
(`github.com/Starkdefi/StarkDefi`). Its `skim(to)` is supposed to return balances *above* stored reserves.
The pre-fix version reads the token1 balance from **token0**:

```cairo
// src/dex/v1/pair/Pair.cairo  (pre-fix, commit 4cfba60, fixed in 6a68300)
let balance0 = InternalFunctions::_balance_of(config.token0, this_address);
let balance1 = InternalFunctions::_balance_of(config.token0, this_address); // BUG: token0, not token1
token0Dispatcher.transfer(to, balance0 - reserve0);
token1Dispatcher.transfer(to, balance1 - reserve1);   // = (token0_balance - reserve1) of TOKEN1
```

The fix (`6a68300`, 2024-08-08, "bug: fix balance1 in skim") was merged to `main` only on **2025-06-07**
(PR #18 "fix/zellic-bug-report" = the Zellic audit fix). On-chain, **four different pair classes** exist;
the buggy one is deployed and live:

| Pair class hash | pairs | creation indices | `skim` behavior (probed) | verdict |
|---|---|---|---|---|
| `0x30ca57592ec02e083d3fefd0245b2c10ca15a3d7f1c88e6675db051f94c2e9f` | 192 | 5…215 (interleaved) | 192/192 OK (transfer 0) | fixed |
| `0x4a56a2e38b5d525a6d441e8d40d8546f6599442f1f8b8e466e45063592872b1` | 22 | 0…215 (interleaved) | 20/20 OK (transfer 0) | fixed (+`recover_orphaned_fees`) |
| `0x63c46ccdc3f160cc701e34179c6066949d6465693b7464ed4e643262513c05c` | 2 | 36, 73 | 2/2 OK (transfer 0) | fixed (+`recover_orphaned_fees`) |
| **`0xaef408ec73c83edbc42d00af164ae8073404aa665b9895041c705c871809f9`** | **96** | **216…311 (contiguous, newest)** | **95/95 REVERT** on quiet pairs: 50× `u256_sub Overflow` (`0x753235365f737562204f766572666c6f77`), 44× `ERC20: insufficient balance` (`0x45524332303a20696e73756666696369656e742062616c616e6365`), 1× `Must be greater than zero` | **BUGGY (pre-fix)** |

`0xaef408ec…` is also the factory's **current** `class_hash_for_pair_contract` — pairs created today
inherit the bug.

**Exploit math (proven by simulation, §6):** with token balances `b0,b1` and stored reserves `r0,r1`:

- `skim(to)` transfers `amount1 = b0 − r1` of **token1** (uncapped); succeeds iff `0 ≤ b0 − r1 ≤ b1`.
- Donating `d` of token0 first (returned by the same call as `amount0 = d`) sets `b0' = b0 + d`; choosing
  `d = r1 + b1 − b0` drains **the entire token1 balance `b1`**.
- Free steal without capital exists iff `0 < b0 − r1 ≤ b1`.
- If `b0 < r1` (token0 raw balance below token1 reserve), only a donation works, of size `≈ r1 − b0`.
- If `b0 > r1 + b1` (raw), a preceding swap of token1→token0 can shrink `b0` and open the window.

**Live proof (trace from `starknet_simulateTransactions`, block 16,156,748):** on pair
`0x46632b5586cf8e3af119060e0eb2bb70a2929819ce439492c15f6b4ddbdfe39` (STRK / JEDI-P 0x7f6087e5),
the trace shows **both `balanceOf` calls hitting token0 (STRK)** — the exact pre-fix line — then
`STRK.transfer(sender, 47,811,138,131,899,003,674)` (donation returned) and
`JEDI-P.transfer(sender, 24,577,169,190,437,310,013)` = **the full token1 balance** (`b1`), reproduced
identically in CI (run [38021322075](https://github.com/kingmariano/ca-zombie-ci/actions/runs/38021322075)).

---

## 3. Live-state assessment (all reads at explicit blocks)

- **Factory** `0x02721f5ab785ae5E13b276ca9d41e859B7b150440A288A7826Ba5E27Dd05E08e` (class `0x6c77d54b…`):
  `all_pairs_length = 312`; `paused = false` (probe `assert_not_paused` OK, block 16,150,647);
  `fee_handler = 0x283b6df5330e5ba0c9ffc4a5c80de4227bdab78b6a155654ae78f220d6bdf53`;
  `fee_to = 0x1335ab829016118d33c11475eee49f302fd48a2d207aa74067cda44b0942279`;
  `get_fees() = (4, 30)` (0.04% stable / 0.30% volatile; per-pair custom tiers 1/4/30/100 exist);
  `protocol_fee_on = true`; `class_hash_for_pair_contract = 0xaef408ec…` (buggy class).
- **Pair classes:** counts above; creation order shows the buggy class is the **newest batch**
  (indices 216–311).
- **Fee vaults:** all 312 share class `0x288f17818d7d3d63ff93b8e349387281eba86d807a5caa44252ec115e0b2e6b`
  with exactly `claim_lp_fees(user,u256,u256)` (caller must be the pair), `update_protocol_fees`
  (pair-only), `claim_protocol_fees` (fee_handler **or** pair). **291/312 vaults hold non-zero fees,
  total $14,730.64** priced (largest: $5,187.63 and $5,020.83). By design (protocol_fee_on) ~70% is LP
  claimable (H-O via `pair.claim_fees()`), ~30% protocol (P, claimable to `fee_to`).
- **Value by pair class** (block 16,155,532; DefiLlama prices):

  | class | pairs | priced TVL | notes |
  |---|---|---|---|
  | `0x4a56a2e3…` (fixed) | 22 | **$68,788.60** | holds the report's $72.5k; LP-owned |
  | `0x30ca5759…` (fixed) | 192 | $2,781.63 | 134 unpriced token sides |
  | `0xaef408ec…` (**buggy**) | 96 | **$168.55** | 93 unpriced token sides |
  | `0x63c46cdc…` (fixed) | 2 | $74.76 | |
  | **total** | **312** | **$71,875.62** | matches DefiLlama $71,533.68 |

- **Buggy class token1 inventory (the only thing `skim` can move):** nominal **$114.59** total, of which
  **359,930,678 SPIST ≈ $62.09** (at $1.725e-7 — median of 5 on-chain implied prices; SPIST supply 7.37B,
  buggy pairs hold 4.9%), the rest is wei-dust STRK/ETH/USDT and JEDI-P nested meme-LP tokens
  (Fuel/$BRRR/WARS/nested LP — unpriced by DefiLlama, ≈$0).
- **`fee_handler`** is an OpenZeppelin/ArgentX account (class `0x61dac032…`, 58.22 STRK, nonce 291);
  **`fee_to`** is a Braavos account (class `0x3a4c71a7…`, 168.09 STRK, nonce 277) — both funded, so the
  privileged paths are presumably still operable (P, not E-U). No evidence of key loss; "abandoned" is a
  product-level statement, not a key-level one.
- **Router:** only caller-scoped `add/remove_liquidity` + swap functions; **no open multicall / arbitrary
  call** — no approval-drain path. `upgrade`/`set_factory` are fee_handler-gated.
- **Pairs hold no self-LP balances** (0/312) — the `burn(to)` sweep is not available.
- Unknown `_6bdf53(u64)` on the two newest fixed classes reverts `not allowed` (`0x6e6f7420616c6c6f776564`)
  — handler-gated.

---

## 4. What an attacker can / cannot do (exact paths, costs)

**Can (all proven read-only):**
1. `pair.skim(attacker)` on any of the 96 buggy pairs — reverts on quiet pairs; succeeds only where
   `0 < b0 − r1 ≤ b1` (free steal). Across all 96 pairs this yields exactly **one** pair,
   `0x5076b9365fc6dc…`, for **217 wei STRK (≈$1.7e-14)**; its `b1` is already 217 below `r1`, i.e. the
   pair looks like it was already skimmed by that exact amount. CI reproduced the 217 transfer in trace.
2. Donation + `skim` full drain: multicall `[token0.transfer(pair, d), pair.skim(attacker)]`,
   `d = r1 + b1 − b0`. Proven end-to-end (24.577 JEDI-P drained; donation returned atomically).
   Feasibility per pair:
   - **JEDI-P pairs (capital-feasible: d = 1.9–90.5 STRK, returned):** stolen JEDI-P is 0.9–99.96% of
     LP supply of nested meme pools (Fuel/$BRRR/WARS/SPIST-in-JEDI-P) with no DefiLlama market → ≈**$0**.
   - **SPIST pairs (the only nominally meaningful token1):** `d` must be 4.8e23–5.0e26 raw token0 →
     e.g. 249.4M STRK (≈$18.3M) for the biggest pair (249.4M SPIST ≈ $43 nominal), 14.6M LORDS (≈$52k)
     for 14.6M SPIST (≈$2.5), 32.1M NSTR (≈$162k) for 16M SPIST (≈$2.8). Total SPIST exit liquidity
     across all 48 JediSwap SPIST pools is ≈**$40–80** (largest pool 236M SPIST/0.0164 ETH ≈ $81 TVL).
     → capital-infeasible and even free capital could not realize >~$40.
   - **STRK/ETH/USDT dust pairs:** steal is 10⁻¹⁰–10⁻¹⁵ tokens — no economic value.
3. Swap-then-skim variant (for `b0 > r1 + b1` pairs): reduces `b0`, raises `b1`, then drains all of `b1`.
   Best case over the whole class: pair `0x7ab8b6ff48d5d9…` — nominal profit **$4.30** (13.8B BROTHER
   $4.28 nominal + 22.1M SPIST $0.03) requiring **388.6M SPIST ≈ $67** of capital, with the BROTHER leg
   sellable only into a pool DefiLlama prices at $3.1e-10 and SPIST into ~$80 of depth → negative after
   slippage. All other swap-needed pairs (e.g. `0x2d403244…`: needs ~3.76M STRK swap, fee ≈11,300 STRK
   ≈$829 vs $25.8 steal; `0x63759f94…`: needs ~68M USDT swap, fee ≈204k USDT vs $25.5 steal) are deeply
   negative.

**Cannot:**
- Move any LP reserves ($71,875.62) — only LP holders via `burn`/`remove_liquidity` (H-O).
- Touch fee vaults — `claim_lp_fees` asserts `caller == pair`; `claim_protocol_fees` asserts
  `fee_handler || pair`; `update_protocol_fees` pair-only.
- Use the router as a confused deputy — no arbitrary-call entry point; approvals to it are not abusable.
- Steal LP tokens held by pairs (none exist), or pause/unpause/set fees/upgrade (all `fee_handler`-gated).
- Profit from `create_pair` (permissionless) — creates only empty new pairs.

**Costs:** Starknet gas is cents; the binding constraint is capital (`d`/swap input) and exit liquidity,
both quantified above.

---

## 5. Category split

- **E-U (external unprivileged): $0.00** — high confidence. The bug is live but no economically viable
  extraction exists at current state/prices. (Nominal, capital-free, slippage-free bound: $114.59.)
- **H-O (holder-only): $71,875.62** LP reserves (withdrawable by LP holders; mostly fixed class) +
  **~$10,311** (≈70%) of vault fees claimable by LP holders via `pair.claim_fees()` — high confidence on
  paths; medium on how much is actually claimed by live holders.
- **P (privileged): ~$4,419** (≈30% protocol share of vault fees, claimable to `fee_to` by
  `fee_handler`/pair) + the `fee_handler` account's full admin authority (upgrade any pair, set fees,
  pause) — a live key risk over the whole $86.6k, not attacker-extractable.
- **S (stuck): $0** — nothing bricked; pairs unpaused; `burn` works.

---

## 6. PoC / verification (read-only, no transactions)

| Proof | Method | Result | Where |
|---|---|---|---|
| 312 pairs / class map | `starknet_call all_pairs` + `starknet_getClassHashAt` ×312 | 312 pairs; 192/22/2/96 classes | `analysis/pairs_raw.jsonl`, `factory_state.json`, CI `ci_verify.json` |
| 309-pair `skim` probe | `starknet_call skim(dummy)` per quiet pair | fixed classes OK (0 transfer); buggy class 95/95 REVERT (`u256_sub Overflow` / `ERC20: insufficient balance`) | `analysis/skim_probe.jsonl`, CI probe |
| Full-drain simulation | `starknet_simulateTransactions` (`SKIP_VALIDATE`,`SKIP_FEE_CHARGE`), sender = fee_handler (58.2 STRK, no signature), calls = `STRK.transfer(pair,d)` + `pair.skim(sender)` | trace: both `balanceOf` on token0 (bug), donation returned, **24,577,169,190,437,310,013 JEDI-P (full `b1`) transferred out** | `analysis/simulate_drain_result.json`, `ci-out/simulate_drain_raw.json` |
| Free-steal simulation | same harness, `pair.skim(sender)` on `0x5076b936…` | 217 wei STRK transferred | `analysis/simulate_drain_result.json` |
| SPIST price | 48 JediSwap pools enumerated; 5 priced pools → median implied $1.725e-7 | 359.9M SPIST ≈ $62.09 nominal; pools ≈$40–80 total | `analysis/spist_pools.json` |
| Vault fees | `balanceOf` ×2 on 312 vaults | $14,730.64; 291/312 non-zero; vault class funcs gated | `analysis/vault_balances.json`, `analysis/factory_state.json` |
| Feasibility | exact donation/swap math over all 96 pairs (incl. live `get_amount_out` checks) | donation-feasible pairs only JEDI-P (≈$0 assets); swap best case $4.30 nominal | `analysis/final_quant_v2.json`, `drainable_buggy_class.json` |

**CI:** GitHub Actions run **https://github.com/kingmariano/ca-zombie-ci/actions/runs/38021322075**
(branch `starkdefi`, block 16,156,138; custom job `ci/run.sh` → `analysis/ci_verify.py`; artifacts
`result-starkdefi`: `ci-out/ci_verify.json`, `ci-out/simulate_drain_raw.json`). CI reproduced: 312 pairs,
identical class counts, fixed-class probes OK, buggy-class probes REVERT, and the identical full-drain
transfer amount. Log: `ci-log.txt`.

---

## 7. Verdict, residual & latent risk

**Verdict:** C2-48's live extractable value by an external unprivileged attacker is **$0.00** (high
confidence). The pre-fix `skim` on 96 pairs (including the factory's current class) is a genuine,
proven permissionless drain primitive, but today it can only move tokens that are worthless or require
10³–10⁸× more capital than the steal, into exit liquidity of ≈$40–80. The report's $72.5k is LP-owned TVL
in the *fixed* class, not attacker-exposed.

**Latent risk (monitor):**
1. **New pairs inherit the buggy class** (`class_hash_for_pair_contract = 0xaef408ec…`). Any fresh pair
   with real token1 liquidity is drainable at the cost of a returned donation (flash-loanable if the
   token0 has lenders).
2. **SPIST upside:** if SPIST gains price/liquidity (it has a CMC market listing with $1,154 daily
   volume), the 10 SPIST pairs holding 359.9M SPIST become worth draining — still gated by the donation
   size (249M STRK for the largest), so only pairs where the attacker can source the raw token0 cheaply
   matter.
3. **Privileged upgrade:** `fee_handler` (funded ArgentX account) can `upgrade` any pair — including the
   fixed class holding $68.8k — to arbitrary code, or repoint `set_pair_contract_class`. This is P, but
   it is the fastest way the remaining value can go to zero.

**Blockers that keep E-U at $0:** (a) token1 assets in buggy pairs are meme/dust; (b) the donation is in
raw token0 units, ≈10²–10⁸× the steal value for every pair with a nominally valuable token1
(≈$100k–$36M+ for ≤$43 nominal);
(c) exit liquidity for the only nominally valuable token (SPIST) is ≈$40–80; (d) no other unguarded path
(router, vaults, upgrades, pause all gated or harmless).

---

## 8. Methodology, caveats, files

**Method:** exhaustive factory enumeration via `all_pairs` (312/312), per-pair `snapshot` + real
`balanceOf`, per-pair class hash, behavioral `skim` probe on all 309 quiet pairs, full source review of
`Pair.cairo`/`factory.cairo`/`pairFeesVault.cairo`/`router.cairo`/`upgradable.cairo` against the public
repo (`github.com/Starkdefi/StarkDefi`, incl. fix commits `6a68300`/`9c08834`), live `get_amount_out`
checks for the swap variant, DefiLlama pricing (`coins.llama.fi`) + on-chain implied SPIST price,
`starknet_simulateTransactions` with `SKIP_VALIDATE`+`SKIP_FEE_CHARGE` (no signature; state discarded).

**Caveats:**
- Prices are spot DefiLlama/implied-pool values at the stated blocks; token values are estimates.
- LP-token holder distribution is not enumerable without events; H-O assumes holders exist. If LP tokens
  are held by dead addresses, parts of H-O degrade to S.
- The vault fee 70/30 LP/protocol split is by design; exact per-vault claimability depends on live LP
  claims.
- `fee_handler`/`fee_to` account liveness is inferred from funded balances/nonces, not tx history
  (public event APIs were unreliable during the window; a keyed RPC could confirm activity).
- The stable-curve rounding of the fixed classes was not exhaustively fuzzed; the `k`-check plus fees
  make extraction implausible, but this is a residual (low) uncertainty, not a proven path.

**Files:** `summary.json` · `analysis/pairs_raw.jsonl` (312 pair snapshots) · `analysis/pair_balances.jsonl`
(real balances) · `analysis/skim_probe.jsonl` (309 probes) · `analysis/pair_table.csv` · 
`analysis/factory_state.json` (class map, vaults, roles) · `analysis/drainable_buggy_class.json` ·
`analysis/final_quant_v2.json` · `analysis/simulate_drain_result.json` · `analysis/spist_pools.json` ·
`analysis/vault_balances.json` · `analysis/lp_token_info.json` · `analysis/class_abis.json` ·
`analysis/jedip_drain_values.json` · scripts `analysis/*.py` · CI `ci/run.sh`, `ci-out/ci_verify.json`,
`ci-out/simulate_drain_raw.json` · `ci-log.txt`, `ci-artifacts/`.
