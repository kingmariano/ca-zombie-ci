# C2-20 — rsETH whale-Safe Router bypass (Ethereum): live weapon, $0 fresh E-U, $133.1M fenced by disabled modules

**Campaign:** zombie-hunt II · **Chain:** Ethereum mainnet · **Date of work:** 2026-10-08/09
**Status:** read-only research; fork-only PoC (`poc/`); no mainnet transactions signed or sent.
**Latest blocks of live reads:** 26,149,511 (matrix); 26,149,821 (state dump); 26,151,578–26,151,700 (census, verification, holders).

---

## TL;DR

| Target | Live extractable (unprivileged) | Why closed/open today | Latent risk |
|---|---|---|---|
| **Whale Safe `0x40E93a52…`** — 50,278.79 aEthrsETH, Aave collateral **$133.09M** | **$0** | The exploit's entry module `0xeA18B13d…` is **disabled** on the Safe (and so is the recipe's action module `0xdcdc4ef8…`). The exact public exploit payload now reverts `GS104` inside the Safe. | **Re-arm = 2 Safe txs.** Router flaw is live, module un-paused, Router still in its caller set, allowlist root still validates the public payload; only the module bits stand between the weapon and the position. |
| **Second live client `0x3edc8427…`** — module `0x0763fea1…` (family) | **$0** | This Safe **does** enable its (whitelisted, un-paused) family module, so the Router bypass is reachable — but the Safe holds **1 HEX (~$0)** and zero rsETH-family assets; no root-valid recipe payload for this module is public. | Same class: value appearing on this Safe becomes reachable through the flawed Router. |
| **Empty Safe `0xbbd6b5b3…`** (enables `0xeA18B13d`) | **$0** | Holds nothing; the module is **bound to the whale Safe** (`slot 2`), so enabling it elsewhere is inert (fork-proved). | None by itself. |
| **Other Router-whitelisted modules** `0xd479bcc8…`, `0xf73a5695…` (targets `0xb8e12daf…`, `0x6a1fac6b…`) | **$0** | Both targets disabled their module (live `isModuleEnabled=false`, empty module lists). | Re-enable ⇒ reachable through the same bypass. |
| **All other family-shaped modules enabled anywhere** (global census: 27,429 unique enabled modules → 39 family hits) | **$0** | Every family-enabled Safe holds **zero aEthrsETH and zero rsETH**, ≤0.02 ETH (max); only two of them are whitelisted in the flawed Router. | Low; monitor. |

**Total live extractable now: $0 (high confidence).**
**Dormant weapon: the DELEGATECALL authority over the whale Safe's $133.09M Aave position, fenced by two disabled-module bits.** The public exploit payload is fork-proven to extract **2,900 aEthrsETH ≈ $7.63M** under pre-hack conditions; its amount is Aave-health-factor-bounded.

---

## 1. The incident this finding derives from (Sept 15, 2026)

- Exploit tx `0x0e7680b06cb8a6f86c149d9ba90d98e3d334e7b072dde03909d43fcfd98a8705`, **block 25,980,525**, success, 3,207,685 gas.
- Top-level sender: MEV bot **Yoink** `0xFDe0d157…` → its contract `0x80BF7Db6…`. The original attacker (`0x0dC2c5D6…`, RAILGUN-funded) broadcast to the public mempool and lost the race; the bot took **2,882.37 rsETH**.
- **2,900 aEthrsETH** left the whale Safe `0x40E93a52F6Af9fCD3b476aeDADD7FeABD9f7AbA8` (transfer to the Uniswap v4 PoolManager `0x000…4444c`), was unwrapped to rsETH through the attacker's pre-staged v4 pool, and exited. Loss ≈ $7.7–7.8M at the time.
- The tx emitted `ExecutionFromModuleSuccess` (topic `0x6895c136…`) **8×**: 7× via module `0xdcdc4ef8…` (a beacon-proxy module) and 1× via `0xeA18B13d…` — both enabled on the whale Safe at the time. The **recipe's action leg calls `0xdcdc4ef8`** (fork-proved, §5).
- Post-hack cleanup by the Safe's owners (1-of-3): modules disabled — `0xeA18B13d` + `0xdcdc4ef8` at block 25,980,931 (tx `0x94439062…`), 8 more at block 25,981,331 (tx `0x89389520…`). At block **25,990,335** a fresh **empty** Safe `0xbbd6b5b3…` enabled `0xeA18B13d` via `execTransaction` (tx `0x25d4eaea…`, owner `0x9Fcf27e4…`) — the only Safe still enabling it.

Primary sources: DeFiHackLabs PR #1262 (payload reconstruction), SigIntZero incident write-up (Sept 17, 2026), on-chain reads below.

## 2. The bug, in exact terms

Two unverified contracts carry the flaw:

**Router `0x4f0055926c839D1d960a82CBF84E2eE933958ebC`** (2,128 bytes; deployed 2025-06-24 block 22,773,479 by `0xe9ecfb46…`; owner `0x6a1fac6b…` = 1-of-2 Safe):

```solidity
// multicall(address _contract, bytes[] _data) — selector 0x00c25829
// Disassembly of the authorization helper at 0x69a: it returns true whenever the call
// target equals address(this) — 0x6b4 ADDRESS / 0x6b5 DUP4 / 0x6b6 EQ / 0x6b7 JUMPI 0x811.
// Otherwise it STATICCALLs the target with selector 0x0000004f and requires the caller to be
// in the returned address[] (the target's caller allowlist).
```

**Whitelist (mutable by the owner — corrected from the wave-2 note):** the constructor registered three modules `0xd479bcc8…`, `0xf73a5695…`, `0xeA18B13d…`. The owner **later extended the whitelist**: `0x0763fea1…` is whitelisted (`isModule=true`; mapping slot `0xf7ed06…` = 1 from ~block 23.6M, right after that module's deployment at 23,568,785 — the owner Safe `0x6a1fac6b` is active around those blocks). No direct top-level `setTarget` tx appears in the router's 285 txs, so the extension was made through the owner Safe. **Among all 27,429 modules currently enabled by any Safe, exactly two are whitelisted in this Router: `0xeA18B13d…` and `0x0763fea1…`.**

**Module `0xeA18B13d11f705a68F0954f637949e1eaA7AC4ca`** (7,070 bytes; deployed 2023-10-14 block 18,348,814 by keeper `0xd7ed6cb1…`):

- `slot 0`/`slot 2` = `0x40E93a52…` (the Safe it serves; also its admin).
- `slot 3` = EnumerableSet of **7 allowed callers** (selector `0x0000004f`): `0x45eec627…`, `0x84513a7d…`, `0x853778e4…`, `0x814124bc…`, `0x25117f09…`, `0x9efa4021…`, **and Router `0x4f005592…`**.
- `slot 5` = a rotating Merkle allowlist root (`0x20ec13db…`), **unchanged since before the hack** (checked at blocks 25,980,524 and 26,149,5xx).
- Entry `0x000000df` requires `msg.sender ∈ callers`, `!paused`, a proof against the stored root; it then calls the Safe:

```solidity
safe.execTransactionFromModuleReturnData(RecipeExecutor, 0, executeRecipeData, /*operation=*/1); // 0x5229073f, DELEGATECALL
```

The recipe (opaque skeleton, allowlisted by the Merkle root) executes **with DELEGATECALL inside the Safe** — the Safe's storage, the Safe's balances — and its first action calls the second family module `0xdcdc4ef8…` (beacon proxy, impl `0xC62d6FDC…`), which makes the Safe perform further calls (approve/Permit2/v4).

**Composed exploit (permissionless, single tx):**

```
attacker → Router.multicall(ROUTER, [                        // outer target == router ⇒ auth short-circuit
             Router.multicall(MODULE, [ 0x000000df…recipe ]) // inner runs with msg.sender == router
           ])
   → module (router ∈ callers) → Safe.execTransactionFromModuleReturnData(..., op=1)
   → recipe delegatecalled in the Safe → module 0xdcdc4ef8 → Safe actions → v4 capture leg
```

No owner signature, no caller gating survives. Amounts/venue parameters are attacker-supplied within the recipe skeleton (bounded by Aave health, §5).

## 3. Live-state assessment (all reads on-chain)

### 3.1 The whale Safe — modules disabled (the fence)

| Check | Value | Block |
|---|---|---|
| `getThreshold()` / owners | **1-of-3** (`0x8c2AEcCe…`, `0x5F411B44…`, `0xe32e3BD2…`) | 26,149,408 |
| `nonce()` | 780 (actively used) | 26,149,408 |
| `getModulesPaginated(0x1,30)` | **`[]`** — no modules at all | 26,149,408 |
| `isModuleEnabled(0xeA18B13d…)` / `(0xdcdc4ef8…)` | **false / false** | 26,149,408 |
| `aEthrsETH.balanceOf` | **50,278.791748538196099080** (grows with Aave interest) | 26,149,821 |
| `rsETH.balanceOf` | 2.873 | 26,149,821 |
| ETH / other tokens | 0 ETH; ~$2k of RPL/BAL/AURA/CVX/ALCX dust | 26,149,821 |
| Aave v3 `getUserAccountData` | collateral **$133,086,612.94**, debt **$122,747,699.09**, liq. threshold 95%, **HF = 1.0300** | 26,149,821 |
| Pre-hack Aave state | collateral $144,157,953.67, debt $129,360,095.91, **HF = 1.0587** | 25,980,524 |

### 3.2 Other module-enabled Safes (all $0 of rsETH-family value)

- **Empty Safe `0xbbD6B5b3565e151528c44200D4Ee1a6895206962`** (owners `0x9Fcf27e4…`+`0xe8710182…`, 1-of-2, nonce 2): `isModuleEnabled(0xeA18B13d…)=true`, balances 0; module `slot 2` targets the whale Safe, so it is inert (fork-proved).
- **Second live client `0x3edc8427…`** (1-of-2, nonce 159): enables `0x0763fea1…` (family module, `slot 0/2` = itself; callers = `0x63186326…`, `0x25117f09…`, Router; `paused=false`; own root `0xbfb8606e…`). Enablement tx block 23,569,025. Balances: **1 HEX (~$0.00)**, 0 ETH, 0 rsETH-family. The Router bypass reaches it; nothing to take.
- Full census of family-enabled Safes: 39 (below) — **zero aEthrsETH, zero rsETH; max ETH 0.02**.

### 3.3 The weapon's other gates are still open (block 26,149,511, fresh random caller)

| # | Call | Result | Meaning |
|---|---|---|---|
| T1/T2 | `multicall(ROUTER,[])`; nested self-reference | ✅ | self-target allowed; nested wrap works |
| T3 | `multicall(ROUTER,[multicall(MODULE,[])])` | ✅ | module reachable with Router identity |
| T4 | `multicall(MODULE,[])` direct | ❌ `0x7899fd73` | caller check blocks direct use |
| T5/T6 | same wrap for `0xd479bcc8` / `0xf73a5695` | ✅ | both further-whitelisted modules reachable |
| T7 | wrap for `0x853778e4…` | ❌ `0xe3e9c6e4` | not whitelisted (gate 1) |
| P1 | **exact public exploit payload** via the full chain | ❌ **`GS104`** | **everything passes until the Safe's disabled-module check** |
| P2 | same payload without the self-ref wrap | ❌ `0x7899fd73` | the bypass is load-bearing |
| S1–S5 | sibling `multicall` contracts `0x853778e4…`, `0x9efa4021…` | ❌ | no self-reference bypass there; flaw specific to `0x4f00559…` |

Module state: `paused()=false`; `callers()` still contains the Router; `slot 5` root unchanged since before the hack.

### 3.4 Global census — who enables family modules today

Full-history scan of Safe `EnabledModule`/`DisabledModule` events (GoldRush 1M-block windows, block 26,151,578; re-runnable via `ci/run.sh`):

| Metric | Value |
|---|---|
| EnabledModule events (all Safes, all history) | **118,601** |
| DisabledModule events | **21,368** |
| Currently-enabled (Safe, module) pairs | **97,222** |
| Unique modules currently enabled | **27,429** |
| Family-fingerprint hits among them (9 big-module code + 28 beacon-proxy + 2 MakinaX minimal-proxy) | **39** |
| …of those, target Safes with non-zero aEthrsETH or rsETH | **0** |
| …of those, modules whitelisted in the flawed Router | **2** (`0xeA18B13d…` target disabled; `0x0763fea1…` target enabled, value ≈ $0) |

Recovery note: the initial pass undercounted because one `EnabledModule` variant carries the module in **topic1 (indexed)** rather than data; parsing both variants recovered 11,626 modules (15,800 → 27,429) and eliminated all empty-module rows. A 200-pair live spot-check of the shipped census (plus the 4 critical pairs) is included in the CI artifacts.

Target-side census:
- **aEthrsETH**: 96 holders, supply 321,555.26. Whale is #2 (50,278.79). Only **3 holders are module-enabled Safes** (6,411.88 + 1,615.30 + 780.36 aEthrsETH) — all use non-family modules (**Roles**, `0x4f122c94…`). **Family intersection: 0.**
- **rsETH**: 22,975 holders; 13 are module-enabled Safes holding **0.0339 rsETH combined**; **family intersection: 0.**

## 4. What an attacker can and cannot do today

**Cannot (proved):** extract rsETH-family value anywhere. The whale Safe (the exploit module's only target) has every module disabled; the public payload reverts `GS104`. The one other Router-reachable, module-enabled Safe holds ≈$0 and no root-valid payload for its module is public. No family module is enabled on any Safe holding rsETH-family assets.

**Re-arm condition (precise):** the whale Safe `0x40E93a52…` executes **two** `enableModule` calls — `0xeA18B13d` (entry gate) **and** `0xdcdc4ef8` (the recipe's action module). Then, with no other change:
1. Router flaw live ✅ (T1–T3),
2. both modules un-paused ✅,
3. Router still in `callers()` ✅,
4. allowlist root still validates the public payload ✅ (P1 reached GS104 — i.e. passed the proof),
5. Safe module-enabled ❌ → **flips to ✅** ⇒ the full delegatecall recipe chain executes inside the Safe (fork-proved, C2).
   The final capture leg of the *public* payload additionally needs the attacker's pre-staged v4 environment (stale after Sept 2026; attacker-owned and in principle re-stageable, not demonstrated). The amount is bounded by the Safe's Aave health factor (5,000 reverts `HealthFactorLowerThanLiquidationThreshold`; 2,900 was the pre-hack max; today's same-recipe cap ≈ 1,474 aEthrsETH ≈ $3.9M).

The same shape applies to `0xd479bcc8…` (target `0xb8e12daf…`) and `0xf73a5695…` (target `0x6a1fac6b…`): one `enableModule` by each target re-arms them (targets hold ~0.01 ETH, no rsETH today).

**Costs:** one call; original tx 3.2M gas (~0.2 ETH then). No flash loan needed.

## 5. PoC / fork verification

`poc/` — Foundry project; tests in `poc/test/RsethRouterC220.t.sol` (fork-only; no mainnet transactions). **7/7 PASS** in CI:

| Test | Result | What it proves |
|---|---|---|
| `test_A_latest_bypass_primitive_and_GS104` | PASS | At latest block: self-ref bypass succeeds, direct module call reverts `0x7899fd73`, module reachable through the wrap, exact public payload stops at `GS104`; no balance moves. |
| `test_B_historical_drain_replay` | PASS | Fork at block 25,980,524: the public payload **extracts 2,899.999999999997756821 aEthrsETH** — incident reproduced end-to-end. |
| `test_B2_amount_above_HF_cap_does_not_extract` | PASS | Amount 5,000: Aave leg reverts `HealthFactorLowerThanLiquidationThreshold`, nothing extracted — amount is health-factor-bounded. |
| `test_C_rearm_entry_only_not_enough_for_public_payload` | PASS | Enabling only `0xeA18B13d` at latest: recipe's first action calls `0xdcdc4ef8` (disabled) ⇒ 0 extracted. Two modules are required for this payload. |
| `test_C2_rearm_both_modules_executes_recipe_delegatecall` | PASS | Re-enabling both: the delegatecall chain executes — the Safe emits `ExecutionFromModuleFailure(0xdcdc4ef8)` from the recipe's action module — capture leg needs the stale attacker environment ⇒ 0 extracted. Proves the fence is exactly the module bits. |
| `test_D_empty_safe_is_inert` | PASS | Empty Safe enables the module but `slot 2` targets the whale; payload still reverts `GS104`. |
| `test_E_auth_surface_state` | PASS | Router whitelist holds the modules; module caller set holds the Router; module not paused. |

CI (public repo `kingmariano/ca-zombie-ci`): final clean run URL in `summary.json`; logs in `ci-log.txt`, artifacts in `ci-artifacts/` (state dump, eth_call matrix, census attempt + spot-verify, family sweep).

**Key numbers:** historical drain 2,900 aEthrsETH ≈ $7.63M at $2,631.18/rsETH; exploit gas 3,207,685; pre-hack HF 1.0587, today 1.0300; today's same-recipe HF cap ≈ $3.9M.

## 6. Verdict and residual risk

- **Fresh E-U (external unprivileged, today): $0 — high confidence.** Proofs: the whale Safe's module state (live + fork), the exact payload reverting `GS104`, and the census showing (a) only two Router-reachable enabled modules (whale → disabled; `0x3edc8427` → value ≈ $0), (b) no family module enabled on any Safe holding rsETH-family assets.
- **Dormant weapon:** the module family grants **DELEGATECALL authority** over the whale Safe's **$133.09M** Aave position, fenced by two disabled-module bits. The public payload is fork-proven to extract 2,900 aEthrsETH (~$7.63M) under pre-hack conditions; the amount is Aave-HF-bounded. Full-balance extraction via other root-valid recipes is not excluded but not demonstrated.
- **Mitigations already applied:** modules disabled (Sept 15, 2026). **Not applied:** allowlist root rotation (`slot 5` still validates the public payload), Router flaw (immutable), module caller-set pruning, pause. The Router whitelist is owner-mutable — it still lists the two disabled client modules plus the new client's module; pruning it (or fixing the Router) is a one-tx hardening.
- P / S / H-O for this finding: **$0**.

## 7. Methodology & sources

- Live reads via NodeReal/PublicNode RPC at explicit blocks; Etherscan V2 (sources, txlists, logs, internal txs); GoldRush (global event census, holders); cast disassembly of unverified bytecode; DefiLlama prices (rsETH $2,631.18, ETH $2,453.95 at 2026-10-08).
- Incident sources: DeFiHackLabs PR #1262 (public payload), SigIntZero write-up, on-chain exploit tx/trace.
- Files: `analysis/` — `census.py` (GoldRush + Etherscan fallback), `family_sweep.py`, `census_spot_verify.py`, `state_dump.py`, `matrix.py` (re-runnable); `census_*.json` (118,601/21,368 events; 97,222 current pairs); `family_sweep_hits.json` / `family_sweep_live.json` / `family_enabled_targets.json` (39 modules, 0 rsETH-family value); `router_whitelisted_enabled_modules.json` (2); `matrix_results.json` (T/P/S at 26,149,511); `state_latest.json` (RPC redacted); `incident_exploit_tx.json`; `module_disasm.txt` / `router_disasm.txt`; `router_txlist_full.json` (285 txs); `aethrseth_holder_intersection.json` / `rseth_holder_intersection.json`; `difhack1262.diff`.
- **Caveats:** Router/module/RecipeExecutor and siblings are unverified bytecode (analysis = disassembly + behaviour). The recipe skeleton is opaque; amount freedom is HF-bounded (fork-proved). The census relies on event parsing of both `EnabledModule` layouts; a 200-pair live spot-check plus the critical pairs are in the artifacts. Whitelist entries that are *not* currently enabled cannot be enumerated from storage (only the owner knows the full list); the live question is answered by the enabled∩whitelisted intersection. Point-in-time reads; the whale Safe is actively managed and its HF is 1.03 (liquidatable if prices move).
- **Operational note:** an early version of the CI state dump wrote the RPC endpoint (including its API-key path) into `analysis/state_latest.json`, which the CI helper syncs to the public CI repo branch. The field is now redacted, the file was scrubbed, the public branch was force-pushed clean and old CI runs were deleted. **Rotate `NODEREAL_API_KEY` as a precaution.**
- No transactions were signed or sent; all exploit demonstrations ran on local forks in CI.

*Research is informational; verify all data on-chain before acting.*
