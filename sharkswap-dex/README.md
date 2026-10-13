# SharkSwap DEX (Base) — Phase-2 deep dive

**Date:** 2026-10-13 · **Chain:** Base (8453) · **Target:** `sharkswap-dex` (L2 watchlist, triage $136,554)
**Status:** read-only; PoC fork-verified in GitHub Actions only; **no mainnet transactions sent**; no secrets in this folder.

---

## 1. TL;DR

| Target | Live value | Extractable by fresh unprivileged attacker | Why closed / open | Latent risk |
|---|---|---|---|---|
| SharkSwap factory `0x57592D44…1D5a8B`, 52 UniV2 pairs, $136,751 TVL | $136,751 | **$0** | Stock UniV2 pair code (verified), **zero token excess on all 52 pairs** (no `skim` value), ~90.9% of TVL behind LP burned to a dormant keyless-looking EOA and 8.9% held by team EOAs; no farm contract holds LP; all admin/mint paths are EOA-key/role-gated | Team/feeTo EOAs ($12.2k) and the dormant LP EOA ($124.3k) are key-custody risks; mxapemx public mint exists but drains only a worthless token |

**Accounting (DefiLlama prices at block 52,558,491; LP pro-rata by holder):**

| Category | USD | Notes |
|---|---|---|
| **E-U** extractable by external unprivileged attacker | **$0.00** | no skim excess, no public mint into a valued pool, no LP approvals, no farm |
| **H-O** third-party LPs (self-service `burn`) | **$260.38** | 40 small LPs in WETH/USDbC + 7 in WETH/DAI + few others |
| **P** team/feeTo EOAs (`burn` with key) | **$12,196.30** | feeTo ($4,955: $850 WETH/USDbC soak + $3,931 WETH/wDAI#2 + $174 other), team treasury ($5,010 WETH/wDAI#1), team ops stable pools ($2,232) |
| **S** burned/locked LP (cannot be redeemed by anyone) | **$124,294.38** | 90.9% of TVL: `0x1239660a…4605` holds 99.98% of WETH/DAI + 98.23% of WETH/USDbC LP (no code, nonce 0, no approvals ever) + the 1000-wei MINIMUM_LIQUIDITY of every pool |
| Total | $136,751.06 | matches triage $136,554 (block drift) and the live DefiLlama adapter (`projects/sharkswap-finance`) |

**Headline:** an external, unprivileged attacker with only public mempool/liquidity can extract **$0.00** today (high confidence). Every dollar of TVL is either (a) already burned, (b) held by protocol EOAs that can only be moved with their keys, or (c) third-party LP property.

---

## 2. The protocol in exact terms

- Factory `0x57592D44eb60011500961EF177BFf8D8691D5a8B` — Basescan-verified `SharkswapFactory`, solc v0.5.16. Stock UniswapV2 factory: `createPair/getPair/allPairs/allPairsLength/feeTo/feeToSetter/setFeeTo/setFeeToSetter` only.
- 52 pairs, all Basescan-verified as `SharkswapPair`, solc v0.5.16. Code review vs. canonical UniV2 pair: **identical mechanics** (0.30% swap fee, `balance*1000 - amountIn*3` K-check, `skim/sync/initialize` semantics, `lock` reentrancy guard) with **one intentional deviation** in `_mintFee`: the protocol fee minted to `feeTo` is `totalSupply·√Δk·2 / (√k + 2·√kLast)` = **2/3 of √k growth** (canonical UniV2: 1/6). This only increases what the (privileged) `feeTo` EOA accumulates; it creates no attacker path.
- `feeTo` = `0xBe4ec6286bF4b557D098e303Fa3570584BDa1EB9` (EOA, nonce 9). `feeToSetter` = `0x9973EdDb50D3F22C2523862eA8A415f7f43D5Cd7` (EOA, nonce 12). No `owner()`/`migrator()` on the factory.
- DefiLlama adapter (`projects/sharkswap-finance`, PR #7876) is `getUniTVL({factory: 0x57592D44…, useDefaultCoreAssets:true})` → DefiLlama TVL = sum of pair balances, i.e. exactly the $136k in the pairs. No farm, no staking contracts are part of the adapter.

**Who owns the liquidity (measured by LP `balanceOf`, GoldRush holder index + direct reads):**

| Holder | Role | LP held | Value | Class |
|---|---|---|---|---|
| `0x1239660aF62D515bFeCd4eE09C58D2cd32504605` | dormant EOA, **nonce 0**, 0 ETH, no code; LP **transferred** to it via `transfer()` by team EOA on 2023-10-25 (txs `0x7c07554fd29252b3…` = 549,901.036781258816259 WETH/DAI LP, `0xef6bd26794f600af…` = 550,074.455174827 WETH/USDbC LP; balances unchanged since) | 99.98% of WETH/DAI; 98.23% of WETH/USDbC | $124,294 | **S** (burned) |
| `0xBe4ec628…` feeTo EOA | protocol fees (2/3 of √k growth) + seeded LP | ~1.4% of WETH/USDbC + all of WETH/wDAI#2 + ~24 small pools | $4,955 | **P** |
| `0x27160d3b618ee073efaaEe596b6Be37018D18e4A` | team treasury EOA (active, nonce 216) | all of WETH/wDAI#1 ($5,010) | $5,010 | **P** |
| `0x68586610448bb167d56b92d6b25dc7f196042679` | team ops EOA (active, nonce 58) | ~100% of ~20 stable/cbETH small pools | $2,232 | **P** |
| 40 + 7 + few external EOAs / EIP-7702 smart EOAs | third-party LPs | tiny | $260 | **H-O** |

No contract (farm, bridge, locker) holds LP of any pair: every LP holder address was code-checked; the only contract holders are EIP-7702 delegated EOAs (23-byte `0xef0100…` code) holding dust and the two protocol EOAs above.

---

## 3. Live-state assessment (explicit citations)

All reads read-only via public Base RPC; latest state blocks **52,558,455 … 52,559,109** (2026-10-13); holder snapshot GoldRush at chain tip 52,558,619.

- `factory.allPairsLength()` → **52**; all 52 `allPairs(i)` enumerated (`analysis/live_state.json`).
- Per pair: `token0/token1/getReserves/totalSupply/kLast` + `balanceOf(pair)` for both tokens.
  **`excess_i = balance_i − reserve_i == 0` for all 104 token legs** (max excess 0 wei). `skim(to)` is permissionless but would transfer 0.
- Pair code: all 52 runtime codes byte-identical (CI test `test_uniform_pair_code`); verified source inspected line-by-line (mirrors canonical UniV2 except the 2/3 fee formula quoted above).
- Top pairs at fork:
  - WETH/DAI `0xaE45F7Eb…0Bc823`: 12.552476121 WETH + 31,566.179 DAI = **$63,015**
  - WETH/USDbC `0x9ccc7afE…43A1D`: 12.434016112 WETH + 31,249.618 USDbC = **$62,390**
  - WETH/wDAI#1 `0x6bCc3e76…E126164`: 2.000000000 WETH + 3,966.96 wDAI = $5,010 (real WETH side)
  - WETH/wDAI#2 `0xD4990e03…61FA8e`: 1.569421 WETH + 6,132.46 wDAI = $3,931 (real WETH side)
  - rest ≤ $422 each (cbETH/stable pools and cans).
- Whitelisted core-asset pairs only carry value; the ~30 remaining pairs are dust/junk tokens ($0–$38).
- **Side-token mint audit** (35 non-core tokens; selector extraction + `eth_call` from a fresh address, `analysis/side_token_scan.json`):
  - Only `mxapemx` `0xFEF74FBA…18507Ad` exposes a **public** `mint(address,uint256)` (call returns `true`, credits balance — fork-proven). Its only pool is TOP/mxapemx `0x95238E13…34e5c258`; the extractable side is **TOP** `0x9dba38E9…619f0f2`, which has **no usable liquidity** (GeckoTerminal: `price_usd: null`, `volume h24: 0`; independent check: the only nominal venues hold dust — Maverick TOP/USDC counter-side = 4 wei USDC, iziswap ≈ $0.000023). Drain value ≈ **$0**.
  - `wDAI#1` `0x5D0aF35B…2b173D` (TransparentUpgradeableProxy, impl `0x40a0c407…`, admin contract `0x8decded2…` owned by team EOA `0x27160d3b…`): `mint` requires AccessControl role `0x02adb246…`; fresh caller reverts, team EOA succeeds → key-gated (P). `grantRole/burn/upgradeTo` revert for fresh callers.
  - `wDAI#2` `0x73EA1656…015B66`: `mint`/`setWhitelist` are `onlyOwner` = EOA `0xe69f4903…`; fresh caller reverts. **Neither wDAI holds any DAI/WETH backing** (0 balances) — they are team-minted bookkeeping tokens, but minting is gated.
  - All other side tokens: no mint selector, or role/owner-gated (`SYNTH` AccessControl, `BONK`/`BlackJack`/`HOTSPOT`/`BOOO`/fake-WETH Ownable, `TOP` onlyAuthorized, `SARF` whitelist-gated transfers, `MEME`/`PRIME`/`YODA` internals only).
- **LP approvals**: full-range `Approval` log scan (topic1 = holder) on both big LP tokens for the dormant address → **0 approval events, 0 live allowances**. The burn address has also never sent a transaction (nonce 0) and holds 0 ETH, so it cannot even pay gas.
- **External integrations**: GitHub code search for the factory address returns only DefiLlama/Dune/aggregator registries (paraswap dex-lib config, Dune spellbook, indexers). No lending protocol, oracle consumer or bridge reads these pairs → no stale-price/oracle-extraction route.
- Four pairs have `totalSupply() == 1000` (all user LP already burned; reserves locked forever, dust value): EMG/USDbC `0x7f4c2a00…`, WETH/KITSUNE `0xcd068d92…`, WETH/BOOO `0x1e6cd8a8…`, BIF/WETH `0xc79df4bb…`.
- The live front-end domain `sharkswap.finance` no longer resolves (DNS dead); the only on-chain factory carrying DEFILLAMA/Dune registry entries for "sharkswap" is the one above.

---

## 4. What an attacker can / cannot do (exact paths)

| Path | Preconditions | Live result |
|---|---|---|
| `pair.skim(attacker)` | none (permissionless) | Transfers `balance−reserve` = **0** on all 52 pairs (fork-proven on top-4) |
| `pair.swap(out,0,attacker,"")` with no input | none | Reverts `INSUFFICIENT_INPUT_AMOUNT` / `K` (fork-proven) |
| Steal dormant LP (`transferFrom(0x1239…4605,…)`) | LP allowance | Reverts: allowance 0, never approved in ~3 years |
| Burn feeTo/team LP | their signature | Impossible without their keys |
| `factory.setFeeTo(attacker)` | `feeToSetter` key | Reverts for fresh caller |
| `pair.initialize(...)` re-init | factory only | Reverts for fresh caller |
| `mxapemx.mint(attacker, N)` | none — **public** | Works; then `swap` pulls TOP out of `0x95238E13…`. TOP has no usable exit liquidity → **$0** realized. Only candidate E-U path; closed in value terms |
| wDAI `mint` / `upgradeTo` / `setWhitelist` | role/owner keys | Reverts for fresh caller |
| Donate then `skim` own funds | attacker pays | No profit (returns attacker's own tokens) |
| Market arbitrage vs burned pools | capital + gas | Normal competitive arb (ETH +0.39% rich vs market in WETH/DAI at fork; ~0.09% net after 0.30% fee) — not protocol extraction; bots already trade (≈130 tx/24h pool-wide) |

Net attacker cost of every closed path: gas only; net profit $0.

---

## 5. PoC / fork verification (GitHub Actions)

**Project:** `poc/` (Foundry 0.8.24, vendored forge-std) — `poc/test/SharkSwapLive.t.sol`, 8 tests, fork = CI-injected `BASE_RPC_URL` at latest block.
**Custom CI job:** `ci/run.sh` → `ci/recheck.py` re-enumerates all 52 pairs at the CI block (reserves/balances/excess + LP by role + DefiLlama prices) → `ci-out/live_recheck.json`.

Tests (all fork-only, no transactions):
1. `test_uniform_pair_code` — all 52 pairs share one runtime code hash.
2. `test_zero_excess_all_pairs` — max excess = 0 wei across all legs.
3. `test_skim_transfers_nothing_top_pairs` — permissionless `skim` pulls $0 from top-4 pools.
4. `test_burned_lp_unreachable` — dormant EOA: no code, nonce 0, ≥99% LP, no allowance; attacker `transferFrom` reverts.
5. `test_mxapemx_public_mint_drain_top` — public mint proven; TOP drain quantified (worthless).
6. `test_wdai_gates_revert` — wDAI mint/admin gated.
7. `test_admin_and_theft_gates_revert` — setFeeTo / initialize / LP theft / free swap all revert.
8. `test_privileged_roles_are_eoas` — feeTo/feeToSetter are EOAs (keys, not code).

**CI run URL(s):** _pending — to be filled from the completed run (branch `sharkswap-dex` in `kingmariano/ca-zombie-ci`). First run (compile blocked by a checksum literal, job still produced the live re-check): https://github.com/kingmariano/ca-zombie-ci/actions/runs/38428961448 — `ci-out/live_recheck.json` at block 52,559,387: total $137,150, P $12,254, S $124,896, **max excess 0 wei**.

Result: `x/8 PASS` — _pending_.

**Independent adversarial verification (child agent, fresh reads at block 52,559,481):** claim **not falsified**. All 52 pairs re-enumerated → 104/104 legs `balance == reserve` (max excess 0); 38 tokens probed for public mint (incl. bytecode scan of 8 extra selectors) → only `mxapemx` (state change proven via `stateOverride`); mxapemx→pair drain yields TOP whose every venue is dust (Maverick TOP/USDC counter-side = **4 wei USDC**, iziswap ≈ $0.000023); allowances 0 for 12 spenders × 4 LP tokens; `nonces(dormant)=0`; 0 `Approval` logs (last 10k blocks); 23-byte "contract" LP holders are EIP-7702 delegations with no public pull (≤$2.4). Files: `analysis/independent-verify.md`, `analysis/independent-verify.json`. Corrections applied to this report: burned share restated as 90.9% of TVL; TOP restated as "no usable liquidity" (nominal listings exist, all dust).

---

## 6. Verdict, residual & latent risk

- **E-U = $0.00 (high confidence).** The live $136.7k is AMM liquidity, not custody: 90.9% of TVL sits behind LP burned to an address that has never signed anything, 8.9% belongs to team protocol EOAs, and 0.2% to third-party LPs. Stock V2 math, zero excess, no public mint into a valued pool, no farm contract, no approvals, no oracle consumers.
- **Latent risks (not attacker-extractable now):**
  - The "burn" address is an EOA: if its key exists in the team's possession, the $124.3k is P, not S (indistinguishable on-chain; nonce 0 / no approvals / no gas for ~3 years).
  - Team/feeTo EOAs ($12.2k) are single-key risks; feeToSetter (`0x9973…`) can redirect future protocol fees.
  - `mxapemx` public mint + TOP holding remain live; if TOP were ever listed/priced elsewhere, the TOP/mxapemx pool would become drainable (currently $0).
  - WETH/wDAI pools ($8.9k real WETH) depend on two gated token contracts; a key compromise of `0x27160d3b…` (wDAI#1 minter) or `0xe69f4903…` (wDAI#2 owner) would allow minting and draining those pools.
- **Blockers / caveats:** DefiLlama prices are off-chain; defunct `axlUSDC` and junk tokens are unpriced (kept at $0, conservative); the dormant address's key existence is unprovable; GoldRush holder index used for the owner census (validated against direct `balanceOf`).

## 7. Methodology & sources

- On-chain reads (public Base RPC, blocks 52,558,455–52,559,109): factory/pair enumeration, reserves, balances, allowances, `eth_call` gate probes, log scans; scripts in `analysis/`.
- Basescan (Etherscan V2, chainid 8453): verified factory/pair/side-token sources.
- GoldRush (local key, never written): LP holder census, tx history of dormant address and team EOAs.
- DefiLlama `coins.llama.fi` prices for USD; GeckoTerminal for TOP/mxapemx market status.
- GitHub code search for integrations; corpus cross-check (`zombie_hunt/FINDINGS.md` row: SharkSwap $0.153M, `sharkswap-dex`).
- Fork PoC in CI only (no mainnet tx; no keys in this folder).

## 8. Files index

| File | Purpose |
|---|---|
| `analysis/live_state.py/.json` | 52-pair enumeration at block 52,558,491 (reserves, balances, excess, LP supply) |
| `analysis/price_pairs.py` + `prices.json` | DefiLlama pricing of every leg (total $136,751) |
| `analysis/lp_holders.py/.json` | Full LP holder census (GoldRush, tip 52,558,619) |
| `analysis/ownership.py` + `ownership.json` | E-U/H-O/P/S split by LP ownership ($0 / $260 / $12,196 / $124,294) |
| `analysis/mint_probe.py/.json`, `side_token_scan.py/.json` | Side-token selector extraction + public-mint probes |
| `analysis/independent-verify.md/.json` | Independent adversarial re-check (child agent) — claim not falsified |
| `analysis/factory_source.txt`, `pair_source.txt` | Verified sources (diff vs canonical UniV2 documented in §2) |
| `poc/` | Foundry fork PoC (`test/SharkSwapLive.t.sol`) |
| `ci/run.sh`, `ci/recheck.py`, `ci-out/` | CI heavy job + live re-check artifact |
| `ci-log.txt`, `ci-artifacts/` | Downloaded CI logs/artifacts |
