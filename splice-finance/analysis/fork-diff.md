# Splice Finance fork vs canonical Pendle V2 — precise semantic diff & deployed-Mode verification

**Date:** 2026-10-12 · **Chains:** Mode (34443) [Blast checked only where the parent's scope needs it] · **Status:** read-only; no transactions signed or sent; public sources + `eth_getCode` only.

**Purpose (as delegated):** produce a *precise semantic diff* between the Splice Finance contracts repo
(`github.com/splice-finance/contracts-public`, commit `e1d051b…`, 2024-05-23) and the canonical Pendle V2 repo,
report whether the fork introduces any unprivileged extraction path, and verify the deployed **Mode** market
factory `0x9e6d12097339ddd5402FDD39fc0Ef86Eec54AB39` and yield-contract factory
`0xD0135DddcAaf13f9Bd6054E830dA8cdc199C4F82` against a local compile of the repo.

**Evidence files (same folder):** `fork-diff-evidence.json` (all bytecode-comparison results),
`upstream-gap-list.txt` (post-base canonical commits touching fork files), `final_compare.py` / `run_final_compare.py`
/ `gen_evidence.py` (reproduction scripts).

---

## 1. Which canonical Pendle was forked? (base-version determination)

**Method:** git blob-SHA-1 equality. Every tracked `.sol` file of the fork was hashed as
`sha1("blob <len>\0" + bytes)` and matched against `contracts/…` trees of **all 2,116 commits** in the canonical
repo (`pendle-finance/pendle-core-v2-public`, all refs). Byte-equality on git blob identity = byte-identical file.

**Result:**

| canonical commit | date | package.json | identical | differing | fork-only |
|---|---|---|---|---|---|
| `2482975450` | 2023-12-18 | 4.2.3 | **94/109** | 5 | 10 |
| `8384b66ef4` | 2024-02-28 | 4.2.3 | **94/109** | 5 | 10 |
| `9ec33fab18` | 2024-02-28 | 4.2.3 | **94/109** | 5 | 10 |
| `4321be0e6b` | 2024-03-11 | 4.2.3 | **94/109** | 5 | 10 |
| `bce84ca01b` | 2024-03-12 | 4.2.3 | **94/109** | 5 | 10 |
| `f486fb62e0` | 2024-03-12 | 4.2.3 | **94/109** | 5 | 10 |
| `922299c4ae` | 2024-03-13 | 4.2.3 | **94/109** | 5 | 10 |

* Max agreement anywhere in canonical history = 94/109; no commit scores higher.
* At **each** of the 7 commits the mismatch set is **identical**: the same 5 differing files and the same
  10 fork-only files (listed in §2). The fork is therefore a snapshot of canonical main somewhere in the
  window **2023-12-18 → 2024-03-13** (package v4.2.3; most consistent with Mar 11–13).
* **Reference base used below: `4321be0e6b` (2024-03-11, v4.2.3).** All 7 candidates yield the same diff.

> **Correction to the earlier quick-pass assumption.** The fork was previously assumed to be “mid-2024 v2.5.x
> canonical”. It is the opposite: a **December 2023 – March 2024** snapshot. Several differences reported in the
> quick pass (e.g. `PendleERC20`→`PendleERC20Permit`, revert-string→custom-error) are *canonical's own later
> changes* (permit removed 2024-04-01, error-string refactor 2024-04-22) that the fork simply lacks — see §4.

**Repo hygiene:** the published fork repo does **not compile as-is**: `src/router/PendleRouterV3.sol:8` imports
`../interfaces/Blast/IBlast.sol`, but that file is **not published** (not tracked by git). A 21-line standard
Blast `IBlast` interface stub was added locally to compile. The import is unused (see §2.1 item 2), so the stub
cannot affect the generated code of any contract; all bytecode matches below were reproduced with the stub.

---

## 2. Semantic diff — complete accounting (109 tracked `.sol` files)

**94 byte-identical · 5 differing · 10 fork-only · 0 material differences.**

### 2.1 Files that differ — every difference, with quotes and severity

#### (1) `core/Market/v3/PendleMarketV3.sol` — lines 37–38 (NAME/SYMBOL only)
Canonical @`4321be0e6b` (lines 37–38):
```solidity
    string private constant NAME = "Pendle Market";
    string private constant SYMBOL = "PENDLE-LPT";
```
Fork (lines 37–38):
```solidity
    string private constant NAME = "Splice Market";
    string private constant SYMBOL = "SPLICE-LPT";
```
**Severity: cosmetic** (token display metadata only). **Extraction impact: none.** Everything else in the file,
including `skim()` (line 223) and `_writeState` (line 295), transfer/fee logic, is byte-identical to canonical
(verified also at compiled-bytecode level, §3 row 3).

#### (2) `router/PendleRouterV3.sol` — line 8 (one added, unused import)
Canonical (line 8 is blank; imports end line 7):
```solidity
import "../interfaces/IDiamondCut.sol";

// solhint-disable no-empty-blocks
```
Fork (line 8 added):
```solidity
import "../interfaces/IDiamondCut.sol";
import "../interfaces/Blast/IBlast.sol";

// solhint-disable no-empty-blocks
```
`IBlast` occurs nowhere else in the file — the import is unused and has no codegen effect. The file is a thin
`Proxy`/diamond wrapper; the deployed Mode router is a different file (`PendleRouterV3__Mode`, fork-only, §3 table row 12).
**Severity: none/compile-only.** **Extraction impact: none.** (Side effect: the published repo is missing the
imported file, §1.)

#### (3) `core/StandardizedYield/implementations/PendleERC4626SY.sol` — trailing newline only
Byte tails: fork `…decimals());\n    }\n}` (3,004 B) vs canonical `…decimals());\n    }\n}\n` (3,005 B).
**Zero content-line differences.** **Severity: non-semantic (whitespace).** **Extraction impact: none.**
(`PendleERC4626SY` is the ERC4626 wrapper used by Splice's Blast SYs; it is canonical.)

#### (4) `core/YieldContracts/PendleYieldContractFactory.sol` — trailing newline only
Byte tails: fork `…im_symbol).toString();\n    }\n}` (7,348 B) vs canonical same + `\n` (7,349 B).
**Zero content-line differences.** **Severity: non-semantic (whitespace).** **Extraction impact: none.**

#### (5) `core/StandardizedYield/implementations/Renzo/PendleEzETHL2SY.sol` — Mode rewrite (EXCLUDED per scope)
35 content-line differences vs the base (constructor/asset-access pattern adapted for Mode). This file is in the
task's exclusion list ("Mode L2 SYs"). Note its **deployed Mode instance was bytecode-verified against the repo
compile** (§3 table row 16) and the parent's functional/vault analysis covers its behaviour.
**Severity: in scope-exclusion; not a material core change.** **Extraction impact: covered by parent's vault work; none found.**

### 2.2 Explicit "no differences found" — key files named in the task (all byte-identical, zero bytes differ)

| File | Result |
|---|---|
| `core/StandardizedYield/SYBase.sol` | **no differences found** (md5 `31de77ba…` both sides; `burnFromInternalBalance` at lines 64/69 as canonical) |
| `core/StandardizedYield/PYIndex.sol` | **no differences found** |
| `core/Market/MarketMathCore.sol` | **no differences found** (full AMM math; incl. `MAX_MARKET_PROPORTION` cap at line 46/365) |
| `core/Market/v3/PendleMarketFactoryV3.sol` | **no differences found** |
| `core/Market/OracleLib.sol` | **no differences found** |
| `core/YieldContracts/PendleYieldToken.sol` | **no differences found** (`redeemPY` line 125, `_getAmountPYToRedeem` line 350 as canonical) |
| `core/YieldContracts/InterestManagerYT.sol` | **no differences found** |
| `core/YieldContracts/PendlePrincipalToken.sol` | **no differences found** |
| `core/RewardManager/RewardManager.sol` | **no differences found** |
| `core/RewardManager/RewardManagerAbstract.sol` | **no differences found** |
| `router/ActionMiscV3.sol` | **no differences found** |
| `router/ActionAddRemoveLiqV3.sol` | **no differences found** |
| `router/ActionSwapPTV3.sol` | **no differences found** |
| `router/ActionSwapYTV3.sol` | **no differences found** |
| `router/base/ActionBase.sol`, `router/base/CallbackHelper.sol`, `router/base/MarketApproxLib.sol` | **no differences found** |
| `core/libraries/*` (`ArrayLib`, `BaseSplitCodeFactory`, `BoringOwnableUpgradeable`, `Errors`, `ExpiryUtilsLib`, `MiniHelpers`, `StringLib`, `TokenHelper`, `math/LogExpMath`, `math/PMath`) | **no differences found** |
| `core/erc20/PendleERC20.sol`, `core/erc20/PendleERC20Permit.sol` | **no differences found** |
| `core/Market/PendleGauge.sol`, `core/StandardizedYield/SYUtils.sol`, `core/StandardizedYield/implementations/PendleERC20SY.sol` | **no differences found** |
| `router/PendleRouterHelper.sol`, `router/swap-aggregator/IPSwapAggregator.sol` | **no differences found** |
| `oracles/PendleLpOracleLib.sol`, `oracles/PendlePtOracleLib.sol` | **no differences found** |
| all `interfaces/**` (incl. `IPMarketV3`, `IPYieldToken`, `IPPrincipalToken`, `IPLimitRouter`, Renzo/Connext) | **no differences found** |
| all `offchain-helpers/**` (incl. `router-static/**`, `PendleExchangeRateOracle`) | **no differences found** |
| all `LiquidityMining/**` | **no differences found** |

The complete 94-file identical list is in **Appendix A** (also machine-verified: git blob SHA-1 equality,
reproducible via `run_final_compare.py` methodology).

### 2.3 Fork-only files (10) — none change core accounting

| File | Nature |
|---|---|
| `core/StandardizedYield/implementations/EtherFi/SpliceWeETHL2SY.sol` | Mode L2 SY wrapper (excluded; deployed instance bytecode-verified §3 table row 14) |
| `core/StandardizedYield/implementations/KelpDAO/SpliceWrsETHL2SY.sol` | Mode L2 SY wrapper (excluded; verified §3 table row 15) |
| `interfaces/Mode/IMode.sol` | Mode interface |
| `mock/MockERC20.sol`, `mock/MockGaugeController.sol`, `mock/MockPendle.sol`, `mock/MockVePendle.sol` | mock contracts wired into this deployment as vePendle/gaugeController (excluded per scope; live-value coverage is the parent's state dump) |
| `offchain-helpers/ViewHelper.sol` | off-chain view helper |
| `oracles/PendlePtOracle.sol` | **byte-identical to canonical's own `PendlePtOracle.sol` at `e33cddef91` (2024-02-12)**; canonical renamed/extended it to `PendlePtLpOracle.sol` at `dd73ab9f` (2024-03-10) — the fork keeps the pre-rename version under the old name |
| `router/PendleRouterV3__Mode.sol` | Mode router/diamond wrapper (excluded; deployed instance verified §3 table row 12) |

### 2.4 Functions the parent specifically flagged — byte-identical to canonical

* `PendleYieldToken._getAmountPYToRedeem()` — line 350; canonical logic `min(selfBalance(PT), balanceOf(this))`, post-expiry `selfBalance(PT)`.
* `PendleYieldToken.redeemPY(address receiver)` — line 125; pays `receiver` (not `msg.sender`), redeems via `_getAmountPYToRedeem()`.
* `SYBase.redeem(..., bool burnFromInternalBalance)` — line 64/69; `burnFromInternalBalance=true` burns **`address(this)`** shares; same as canonical.
* `skim()` exists only in `PendleMarketV3.sol:223` (canonical; sends surplus to factory treasury — not to the caller).
* No fork-introduced redirection of any payout receiver, no new mint/burn/sweep entry points anywhere in the diff.

---

## 3. Deployed Mode bytecode verification (factory + yield-contract factory + full protocol set)

**Method.** `eth_getCode` at latest (Mode, 2026-10-12) → strip trailing CBOR metadata → mask (a) immutable
slots and (b) library link slots, using the refs of the locally compiled artifact → byte-compare / sha256-compare.
Local build: `solc 0.8.22+commit.4fc1097e`, `viaIR=true`, optimizer `runs=200`, `bytecodeHash=ipfs`;
EVM target `paris` for core/factory/router contracts, `shanghai` for the Mode L2 SYs (empirically determined;
shanghai builds of core contracts and paris builds of the SYs do **not** match). All fetches were re-verified by
address→code mapping on 2026-10-12 (§ evidence JSON `pairs[].address`).

**Result: every deployed Mode contract is byte-identical to the repo compile** (modulo immutables/links/metadata,
which cannot be part of a source-level diff). Table = 17 contracts; in addition, both factory split-code pairs
(4 helper contracts) were verified by concatenation, see below the table:

| # | Contract (repo artifact) | Deployed address (Mode) | Result | sha256 of masked comparison |
|---|---|---|---|---|
| 1 | `PendleMarketFactoryV3` | `0x9e6d12097339ddd5402FDD39fc0Ef86Eec54AB39` | **MATCH** (4,286 B both) | `428d0e9fc1d3125ea83a69f3f4973568b8a9993ed5adf3999d3c971bea2e4c0a` |
| 2 | `PendleYieldContractFactory` | `0xD0135DddcAaf13f9Bd6054E830dA8cdc199C4F82` | **MATCH except 32 B** (embedded PT hash, see below) | on-chain `b2927d2a…`, local `6fa54ba7…` |
| 3 | `PendleMarketV3` (weETH market) | `0xbF14932e1A7962C77D0b31be80075936bE1A43D4` | **MATCH** (20,091 B) | `f9dfa60a9c284f72bae110a7098ee00ff0978625419ebd05ef0bc368a7def40e` |
| 4 | `PendlePrincipalToken` (weETH PT) | `0x497D0106919FA821296261C0e9a9EAEF60b8d103` | **MATCH** (5,802 B) | `12d5d43209ec2523c34c63f08267d4e034fea80a1378d594eafaef03b7eade9d` |
| 5 | `PendleYieldToken` (weETH YT) | `0x9DBf254Cc5721868f151e41413f8D5B6040c8156` | **MATCH** (16,279 B) | `c4ff945a5918160587825172ebc9f59b5c8657cb1cb3750c4c748151dabfa09e` |
| 6 | `PendlePtOracle` | `0x75e33a93C33B9A3eE337926d978322422822B8c7` | **MATCH** (4,359 B) | `0cd9181632d1120846a963ef30cb8e4e5d4638bd1607bd6a5a0e2684a352f61f` |
| 7 | `ActionSwapPTV3` | `0xDE7ddb8E8778759c16A0a73c743a5d38165cB1A4` | **MATCH** (13,762 B) | `15639c424cfb5a0b1dec3e01c23212c3f279dff63127434e71b1f1816a961156` |
| 8 | `ActionAddRemoveLiqV3` | `0xe239D43D568De53DEB27B0B145e8Ad0ab3958D61` | **MATCH** (20,245 B) | `7214dee564d645678a7a85626e43822a583b403e8f9438028d4cbf18be57ed8d` |
| 9 | `ActionSwapYTV3` | `0xdDDFFE2a579658626Cf43Dd92dFf56dC8767fbbB` | **MATCH** (15,496 B) | `5d15e2e783606a325f16f5370b9af629582972a4388960cf99306c2f492d2b82` |
| 10 | `ActionMiscV3` | `0x8FD532444712f7807212638b03D111344a347eF9` | **MATCH** (8,607 B) | `1a58bc99e1061ab3602d7292163e019b2c1a3771a917563d3080646776dc7457` |
| 11 | `ActionCallbackV3` | `0x19f73Aba87404c91878F719c129aEee028CEc6f8` | **MATCH** (4,639 B) | `5b73bcd0d6331ff56df4ee6f97071446ad4f20be299f955a358e9655a66a564d` |
| 12 | `PendleRouterV3__Mode` | `0x7A3a94AE0fC1421A3eac23eA6371036ac8d8f448` | **MATCH** (4,749 B) | `d39dcf1f9dd6fd85b6feac6799c5cfa1691fe3fe05c3e8f10030ba1d18e7d6ba` |
| 13 | `OracleLib` (deployed library) | `0x56aff1cacabe994760bf8505ed7916a356e20b69` | **MATCH** (3,164 B) | `90b0dfb89e8cb01bdbbdb4cfe8d81c00c293c95b9d32d5ff9a58f20466435f31` |
| 14 | `SpliceWeETHL2SY` | `0x356B2eBc41Fcc7A84b59e998231C14317A5e286c` | **MATCH** (8,667 B) | `3eb8e849ca9e38d159508d366a4f527289d7fc19c4cb45fdd1646cf95be9ddfd` |
| 15 | `SpliceWrsETHL2SY` | `0x9bAF8D6A90c69944dD46fB46B0E620f8Ab23411d` | **MATCH** (8,667 B) | `c36fcecc5eb4d603b787667ebaa48fb1d82cc15d6627bcdff6ecd84f8c89a028` |
| 16 | `PendleEzETHL2SY` | `0x0Cd0F94bBEAd98b6A05773426a783eFE8588A559` | **MATCH** (8,667 B) | `d458190a96d5a195c14a5bc934e7ff9c1a4d6d7837d07a0e1a37efe4c91205a5` |
| 17 | `PendleERC20SY` ("Splice MODE" SY) | `0x5763BA22463ffBef84d5aa1a6Df983420852bED7` | **MATCH** (8,383 B) | `7b1a60e5ca431e6c9d11f1c6269c03de77b832a3fa670b19d426db4b2542f042` |

**Row 2 detail (YCF).** The only difference is the **32-byte embedded PT-creation-code IPFS hash** at bytes
17196–17227 of the stripped runtime (60 hex chars differing, all inside that hash):
* on-chain YCF embeds PT hash `a7de84d191b561a729f98f1b169de7f0bbd3014329d24c3771c12ff374f8e391`
* local build embeds PT hash `f502daf85302c5be91a40015432e25a6f5d53d7d408d67cbec74f9fc8273ec06`
* **cross-check:** the *deployed weETH PT contract itself* carries metadata hash `a7de84d1…` — i.e. exactly the
  hash the deployed YCF embeds → the deployed PT is exactly what the deployed YCF would deploy; the local
  difference is a build-environment metadata artifact (source path set/settings), not code.

**Split creation-code contracts (Mode factory construction)** — also verified:
* Market factory: `marketCreationCodeContractA` = `0x9eDB4E8ae4948f9382EFC8cd5c894f9c59fBA161` (11,825 B) +
  `…B` = `0x69969956FCA56C58EFFe591C7f5d1C9Da7d95fAC` (11,826 B). Concatenation **equals the repo's
  `PendleMarketV3` creation code (23,651 B)** except for (i) the 4 library-link slots, where the deployer
  substituted the OracleLib address `0x56aff1…` (local build carries the solc placeholder
  `__$fcd6a5a796f1bec599f7a6cb2dcb89ae26$__`), and (ii) the trailing 53-byte metadata hash. After masking
  those: identical, sha256 `672e6f79300111ecb73adf527a6223929f086d91c4673154d970c6973a18c24e`.
* Yield factory: `ytCreationCodeContractA` = `0x5C80bE8cFF7A5D25CbBE63EA60b85230Fde2432B` (9,450 B) + `…B` =
  `0x2225c1B706820c1b73cfE40c9D0119f60e0B2BAC` (9,450 B) = repo's `PendleYieldToken` creation code (18,900 B),
  only trailing metadata hash differs; after masking: identical, sha256
  `499b54da97a38d51957d55750b3c9560a3668659d9fde6975c516d30bbde58b5`.
* The deployed weETH market's runtime code embeds `0x56aff1…` (OracleLib) at all 3 link slots (bytes 3314/5074/10718).

**Wiring reads (read-only `eth_call`, Mode):** `market.readTokens()` = (`SY 0x356B2eBc…`, `PT 0x497D0106…`,
`YT 0x9DBf254C…`); `market.expiry()` = 1724198400; `market.factory()` = `0x9e6d…`; `PT.SY()/PT.YT()`,
`YT.SY()/YT.PT()` consistent; `PT.isExpired()` = true; `factory.isValidMarket(market)` = true.
Factory/YCF immutables read: owner/treasury `0x04d440CE29feC9a47Ed471fF0Dc7d002caAdbc66`;
`vePendle`/`gaugeController` = the mock contracts listed in the repo deployment file; YCF `interestFeeRate=0`,
`rewardFeeRate=0`, `expiryDivisor=86400`.

**Metadata hashes (all 17 contracts):** every on-chain metadata hash **differs** from the local build (e.g.
market factory on-chain `1bb650d4…` vs local `b2cfe299…`; weETH market `05ec5d84…` vs `3c22f627…`). This is
expected for a build-environment stamp (file set/paths/remappings) and is **not** semantic — the executions
codes are byte-identical. Full table: `fork-diff-evidence.json → metadata_hashes`.
*(Notable exception with meaning: `YCF-embedded PT hash == deployed weETH PT own hash = a7de84d1…`, proving the
deployment pipeline consistency, see above.)*

**Reference (not part of the fork):** canonical Pendle's Ethereum-mainnet factories
`0x1A6fCc85557BC4fB7B534ed835a03EF056552D52` / `0xdF3601014686674e53d1Fa52F7602525483F9122`
(solc **0.8.23**, 6,305 / 23,252 B) do **not** match the fork's factories — they are a *later* canonical code
line; consistent with §1 (the fork is an older snapshot), no conclusion drawn from them.

---

## 4. Version-gap analysis — upstream fixes after the fork's snapshot that the fork lacks

Computed from canonical history: all commits after `4321be0e6b` (until 2024-12-31) touching files that exist in
the fork. Full raw list: `upstream-gap-list.txt`. Security-relevant assessment:

| Date | Commit | Upstream change | Fork has it? | Extraction relevance |
|---|---|---|---|---|
| 2024-03-14 | `e5fbce78` | new error `ApxETHNotEnoughBuffer` (Errors.sol) | no | none — for an apxETH SY the fork doesn't include |
| 2024-03-15/19 | `ff53ade2`, `860b6b95` | interface additions/renames (`IPPtOracle`, deploy helper) | no | none (interfaces) |
| 2024-03-27 | `d836b4aa` | router line: `MAX_MARKET_PROPORTION` clamp **inside `MarketApproxLib` approximation**; `isEmptyFill` guard in `ActionCallbackV3.limitRouterCallback`; RouterV4 created | no | low — core trade cap existed since 2022 (`MarketMathCore:365`, fork has it); approximating-cap & limit-callback hardening. The fork repo contains **no limit-router implementation** (only the interface + the deployed callback facet), and its Mode deployment file lists no LimitRouter |
| 2024-04-01 | `135d5720` | **remove ERC20Permit** from Market/PT/YT | no (fork retains permit) | none — EIP-2612 approvals require the owner's signature; removal is a simplification, not a vuln fix |
| 2024-04-15 | `7f396746` | limit-order leniency (`limit/LimitRouterBase.sol`) | no | none — limit router implementation does not exist in the fork repo or Mode deployment |
| 2024-04-22/24 | `570f78cd`, `902470af` | custom errors → revert strings in action facets | no | none — revert-data representation only |
| 2024-05-15 | `463ff97d` | `getLpToAssetRate` post-expiry fix (router-static view helper) | no | none — off-chain view helper |
| 2024-06-02 | `9e273be6` | "CallAndReflect + ExitAll" new router features (ActionMisc/ActionSwapYT/Reflector) | no | none — additive features; fork facets match deployed code |
| 2024-06-04 | `4f6d2730` | YT oracle libs | no | none (new feature) |
| 2024-06-13 | `ad011361`+`d708fc40` | add (buggy) then fix `ArrayLib.create(4)` | no | none — the 4-arg function **does not exist** in the fork (added upstream only on Jun 13), so the fork never contained the bug |
| 2024-06-19 | `631d6c01` | `MarketMathCore` zero-amount guard (`syUsed<=0/ptUsed<=0`); `RewardManagerAbstract` `index==0` guard; YT post-expiry reward underflow clamp | no | low — fixes reverts/rounding edge cases (DoS-ish); no value redirection |
| 2024-07-02 | `6573ff85` | `rawDivUp` rounding for add-liquidity uses; `RewardManager` consumed-reward rounds up; `PMath.rawDivUp` added | no | low — accounting rounding hardening |
| later 2024 | e.g. `a904c7b5`, `0e8394d1`, `61a139c0`, `f2206765` | new SY variants / `PendleERC4626SY` evolution / repo prune | no | none — fork's deployed SYs verified as their own (older) bytecode; no extraction surface |

**Assessment:** all post-snapshot upstream changes are hardening/rounding/feature work. **None of them, by their
absence, creates an unprivileged extraction path** — they mostly fix reverts, rounding dust, or add
features. *(Marked as the one judgement item: "low" severities reflect code-reading, not PoC; the parent's
live-state/PoC work is the authoritative check for the deployed set.)* Separately, the *deployed* facets and
markets are frozen at the same code the fork repo compiles to (§3), so upstream gaps do not alternate the
deployed semantics.

---

## 5. Bottom line

**The fork introduces NO unprivileged extraction path.**

1. **94/109 files are byte-identical** to canonical main at the fork's snapshot (v4.2.3, Dec 2023–Mar 2024);
   the 5 differing files are: NAME/SYMBOL (2 lines), 1 unused import, 2 trailing newlines, 1 scope-excluded
   Mode SY rewrite (§2). No fork-introduced change touches accounting, mint/burn, redeem, fee, reward,
   oracle, or router-payout logic.
2. **Every deployed Mode contract checked is byte-identical to the repo compile** after masking immutables and
   library links — 17 contracts (both factories, market, PT/YT, PtOracle, all 5 router facets, Mode router,
   OracleLib, all 4 Mode SYs) **plus both factory split-code pairs** (4 helper contracts). The single YCF delta is the embedded PT
   build-metadata hash, which on-chain matches the deployed PT's own hash exactly (§3).
3. The version gap vs later canonical is real but consists of upstream hardening/rounding/feature changes
   (§4); none creates an extraction path by its absence.
4. Caveats: (a) metadata hashes are not reproducible (unknown deploy-time build environment), so "byte-identical"
   is asserted for execution code modulo immutables/links/metadata; (b) the `IBlast.sol` import file is not
   published — a stub was needed, with no codegen effect (unused import); (c) the Mode L2 SYs are excluded per
   task scope but were bytecode-verified; (d) the Ethereum canonical factories fetched as reference are a later
   code line and were not used for conclusions; (e) rows classified "low"/"none" in §4 are code-reading
   judgements where noted.

**Confidence: high** (byte-level equality for 94/109 sources and 17/17 deployed Mode contracts — YCF modulo the
fully-explained embedded build-metadata hash; the parent's live-state + PoC work independently concluded
$0 unprivileged-extractable).

---

## 6. Reproduction pointers

* Repo: `git clone https://github.com/splice-finance/contracts-public` → commit `e1d051b` (2024-05-23).
  Canonical: `pendle-finance/pendle-core-v2-public` @ `4321be0e6b` (2024-03-11). Add `src/interfaces/Blast/IBlast.sol` stub.
* Build: `forge build --use 0.8.22` with `viaIR=true, optimizer_runs=200, evm_version=paris`
  (Mode SYs: `evm_version=shanghai`).
* Compare: `python3 analysis/final_compare.py` helpers as invoked in `run_final_compare.py` / `gen_evidence.py`
  (paths inside the scripts point at the local clones under `/tmp/opencode/`).
* Raw on-chain code dumps used: `/tmp/opencode/splice-verify/*.json` (fetched 2026-10-12, Mode).

## Appendix A — the 94 byte-identical files (git blob SHA-1 equality vs `4321be0e6b`)

LiquidityMining: `libraries/VeBalanceLib.sol`, `libraries/VeHistoryLib.sol`, `libraries/WeekMath.sol` ·
core/Market: `MarketMathCore.sol`, `OracleLib.sol`, `PendleGauge.sol`, `v3/PendleMarketFactoryV3.sol` ·
core/RewardManager: `RewardManager.sol`, `RewardManagerAbstract.sol` ·
core/StandardizedYield: `PYIndex.sol`, `SYBase.sol`, `SYUtils.sol`, `implementations/PendleERC20SY.sol` ·
core/YieldContracts: `InterestManagerYT.sol`, `PendlePrincipalToken.sol`, `PendleYieldToken.sol` ·
core/erc20: `PendleERC20.sol`, `PendleERC20Permit.sol` ·
core/libraries: `ArrayLib.sol`, `BaseSplitCodeFactory.sol`, `BoringOwnableUpgradeable.sol`, `Errors.sol`,
`ExpiryUtilsLib.sol`, `MiniHelpers.sol`, `StringLib.sol`, `TokenHelper.sol`, `math/LogExpMath.sol`, `math/PMath.sol` ·
interfaces (44): `Connext/IConnext.sol`, `IAddressProvider.sol`, `IDiamondCut.sol`, `IDiamondLoupe.sol`,
`IERC4626.sol`, `IPActionAddRemoveLiqV3.sol`, `IPActionCallbackV3.sol`, `IPActionInfoStatic.sol`,
`IPActionMarketAuxStatic.sol`, `IPActionMarketCoreStatic.sol`, `IPActionMintRedeemStatic.sol`, `IPActionMiscV3.sol`,
`IPActionStorageStatic.sol`, `IPActionSwapPTV3.sol`, `IPActionSwapYTV3.sol`, `IPActionVePendleStatic.sol`,
`IPAllActionTypeV3.sol`, `IPAllActionV3.sol`, `IPExchangeRateOracle.sol`, `IPGauge.sol`, `IPGaugeController.sol`,
`IPInterestManagerYT.sol`, `IPLimitRouter.sol`, `IPMarket.sol`, `IPMarketFactory.sol`, `IPMarketFactoryV3.sol`,
`IPMarketSwapCallback.sol`, `IPMarketV3.sol`, `IPMiniDiamond.sol`, `IPPreviewHelper.sol`, `IPPrincipalToken.sol`,
`IPPtOracle.sol`, `IPRouterHelper.sol`, `IPRouterStatic.sol`, `IPVeToken.sol`, `IPVotingEscrowMainchain.sol`,
`IPYieldContractFactory.sol`, `IPYieldToken.sol`, `IRewardManager.sol`, `IStandardizedYield.sol`, `IWETH.sol`,
`Renzo/IRenzoDepositL2.sol`, `Renzo/IRenzoOracle.sol`, `Renzo/IRenzoRestakeManager.sol` ·
offchain-helpers: `BaseSplitCodeFactoryContract.sol`, `PendleExchangeRateOracle.sol`, `router-static/PendleRouterStatic.sol`,
`router-static/base/ActionInfoStatic.sol`, `ActionMarketAuxStatic.sol`, `ActionMarketCoreStatic.sol`,
`ActionMintRedeemStatic.sol`, `ActionStorageStatic.sol`, `ActionVePendleStatic.sol`, `StorageLayout.sol` ·
oracles: `PendleLpOracleLib.sol`, `PendlePtOracleLib.sol` ·
router: `ActionAddRemoveLiqV3.sol`, `ActionCallbackV3.sol`, `ActionMiscV3.sol`, `ActionSwapPTV3.sol`,
`ActionSwapYTV3.sol`, `PendleRouterHelper.sol`, `base/ActionBase.sol`, `base/CallbackHelper.sol`,
`base/MarketApproxLib.sol`, `swap-aggregator/IPSwapAggregator.sol`.
(Full per-file machine list: `fork-diff-evidence.json → file_diff_vs_4321be0e6b.identical`.)

## Appendix B — machine-readable results

`fork-diff-evidence.json` contains, per contract: address, artifact path, evm target, strip/mask parameters,
sizes, sha256(masked) for both sides, metadata hashes, split-code check results, YCF embed cross-check.
