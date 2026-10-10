# H2-01 — Sovryn legacy Lend/Borrow (RSK): the "$7.1M frozen behind a deactivation switch" is neither frozen nor switchable

**Campaign:** zombie-hunt II · **Chain:** Rootstock (RSK, chain id 30) · **Date of work:** 2026-10-10
**Status:** read-only research; fork tests only (public keyless RSK RPC); **no mainnet transactions sent**; no secrets.
**Target:** `sovrynProtocol` `0x5A0D867e0D70Fcc6Ade25C3F1B89d618b5B4Eaa7` + iTokens iWRBTC/iUSDT/iXUSD/iDOC/iDLLR/iBPro
**Finding under test (ZOMBIE-HUNT-II H2-01):** *"every call reverts `LoanTokenLogicProxy:target not active`; owner Safe `0x967c84b7…` can reactivate → the Oct-2022 iToken price-manipulation recipe (~$1.1M extracted then) applies immediately. HIGH tripwire."*

## TL;DR

**The finding's premise is wrong on every material point, and the latent risk it describes does not exist.**
The legacy Lend/Borrow protocol is **live and operating normally** (~$7.31M on-chain at RSK block 9,313,446):
`mint`, `burn`, `mintWithBTC`, `burnToBTC`, `borrow`, `marginTrade`, `liquidate`, `closeWithSwap`,
`closeWithDeposit`, `rollover`, collateral ops and external swaps are all **routed to active logic**;
nothing is paused. Only a handful of *auxiliary* selectors revert `LoanTokenLogicProxy:target not active`
(e.g. `flashBorrow`, iToken-level `withdrawAccruedInterest`/`liquidate`) — that is the kernel of truth the
finding over-generalised. The protocol owner is **not a Safe** but a **48h Timelock** governed by Bitocracy;
"reactivation" is a privileged governance action, and even a governance rollback to the oldest module in the
beacon's upgrade log does **not** resurrect the Oct-2022 recipe, because the fix (global mutex guard +
iToken-supply invariant) is compiled into every live module (verified in source *and* bytecode). The original
exploit is reproduced here on a pre-fix fork and shown to revert on today's fork.

| Target | Live extractable (unprivileged) | Why closed | Latent risk |
|---|---|---|---|
| Sovryn legacy Lend/Borrow (6 iTokens, $7.31M) | **$0** | Protocol live; Oct-2022 cross-contract reentrancy fixed since 2022-10-24 (`globallyNonReentrant` + `iTokenSupplyUnchanged` present in all active modules); no unprivileged reactivation path (`onlyOwner` = 48h Timelock) | **Privileged/governance** upgrade power over $7.31M (48h Timelock, Bitocracy; Sept-2026 governance-attack near-miss). Market/illiquidity risk (iDOC 99.9% borrowed, iDLLR 99.7%, iXUSD 62%). No latent unprivileged path via this vector |

**Total live extractable by an external unprivileged attacker today: $0.**
(Confidence: **high** for the H2-01 vector and the live/dead routing map; medium-high that no *other* unprivileged
extraction exists — this assessment targeted the H2-01 mechanism, it is not a full-protocol audit.)

---

## 1. The finding, corrected

| H2-01 claim | Reality (on-chain, 2026-10-10) |
|---|---|
| "every call reverts `LoanTokenLogicProxy:target not active`" | **False.** 48 selectors per beacon are routed to live logic; a fresh user can mint/burn iWRBTC (native RBTC) and iUSDT (rUSDT) in CI fork tests. Only auxiliary selectors revert (see §3). |
| "owner Safe `0x967c84b7…` can reactivate" | **Not a Safe.** It is a **48h Timelock** (`delay()=172800`, `admin=0x6496DF39…` = GovernorOwner/Bitocracy). Reactivation = `registerLoanTokenModule`/`rollback` (beacon) or `setTargets` (protocol), `onlyOwner` = the Timelock. |
| "the Oct-2022 iToken price-manipulation recipe applies immediately on reactivation" | **False.** The Oct-2022 exploit was a *cross-contract reentrancy* (stale iToken price during close), fixed by PR #453 and deployed 2022-10-24. The guard + supply invariant are in **every** live module, including both versions in the beacon's upgrade log. Reactivating dead selectors cannot remove them. Fork test: after a governance rollback to the 2023 module, the recipe-class call still reverts. |
| "$7.1M frozen" | **Not frozen.** ~$7.31M live; $2.25M immediately withdrawable by iToken holders; the rest is borrower collateral and performing loans. |

## 2. What the system actually is (deployed code, exact)

- **Dispatcher.** `sovrynProtocol` fallback routes `msg.sig` through `logicTargets[bytes4]`
  (`require(target != address(0), "target not active")`, verified source line 659-660).
- **iToken proxies.** Each iToken is a legacy `LoanToken` proxy whose `target_` (storage slot 24) points to the
  shared shell `0x8Cf4737DA60c5F04A3b1e3D63a4ed84a7f8fF26e`. The shell's fallback queries
  `ILoanTokenLogicBeacon(_beaconAddress()).getTarget(msg.sig)` (beacon address stored per-iToken at
  `keccak256("LOAN_TOKEN_LOGIC_BEACON_ADDRESS_SLOT")`) and then
  `require(target != address(0), "LoanTokenLogicProxy:target not active")`.
- **Beacons.** iWRBTC → `0x845eF7Be59664899398282Ef42239634aBDd752C`; the other five → `0x5b155ECcC1dC31Ea59F2c12d2F168C956Ac0FFAa`. Both owned by the 48h Timelock; both unpaused.
- **Modules (current).** iWRBTC: `LoanTokenLogicWrbtcLM` `0x6c8f59D3…` (v1, registered 2026-09-04 via SIP-0094
  "Perimeter"), `LoanTokenLogicWrbtc` `0xD0dbAe16…`, `LoanTokenSettingsLowerAdmin` `0x248dF850…`. LM tokens:
  `LoanTokenLogicLM` `0x593DB96E…`, `LoanTokenLogicStandard`-class `0x45569950…`, same settings module.
  The Perimeter exit fee is **ACTIVE**: `ExitFeeController` `0x99994b45…` has `exitFeeEnabled()=true`,
  `surfacePolicy(keccak("PERIMETER_SURFACE_LENDING_LENDER_WITHDRAW"))=(true, 10)` → **0.10% charged on iToken
  redemptions** to `ExitFeeVault` `0xDDE75f75…` (observed charging in the fork trace). This is a small
  user cost, not a blocker.
- **Oct-2022 fix present in deployed code.** Active `LoanClosingsWith` `0xa3FCC9F8…` verified source carries
  `nonReentrant globallyNonReentrant iTokenSupplyUnchanged(loanId)` on both closers; bytecode of all closing
  modules and all iToken logic modules contains the hardcoded Mutex `0xba10edD6ABC7696Eae685839217BdcC42139612b`
  and the invariant string `"loan token supply invariant chec…"`. The Oct-2022 logic (iUSDT mint target at block
  4,689,412 = `0x82C49eC67389B6e8c377eD1Da7816b9add4e3B1e`) contains **no** Mutex.

## 3. Live-state assessment (addresses, balances, roles, blocks)

Full detail: `analysis/current_state.md`, raw JSON: `analysis/targets_live.json`,
`analysis/lm_beacon_targets.json`, `analysis/balances_itype.json`, CI `ci-out/state_dump.json`.

- **LIVE (examples):** beacon `mint`/`burn` → `0x6c8f59D3`/`0x593DB96E`; `borrow`/`marginTrade` → `0xD0dbAe16`/`0x45569950`;
  protocol `liquidate` → `0xd01B701b`, `closeWithSwap` → `0xa3FCC9F8`, `borrowOrTradeFromPool` → `0x000fec34`,
  `withdrawAccruedInterest` → `0xa87Bd1eF`, `swapExternal` → `0xBba83482`.
- **DEAD (the finding's observation):** beacon `flashBorrow(0xd4299134)` → 0, iToken-level `withdrawAccruedInterest(0xe81fefa0)` → 0,
  iToken-level `liquidate`/`rollover` → 0, protocol-level legacy `borrow`/`marginTrade` → 0. All revert exactly
  `LoanTokenLogicProxy:target not active` / `target not active`.
- **Pause state:** `isProtocolPaused()=false`; `checkPause("borrow"|"marginTrade"|"mint"|"burn")=false` on all six iTokens.
- **Balances (block 9,313,380; prices DefiLlama 2026-10-10):** WRBTC 68.256 (pool 19.734 + protocol 48.523) = $5.658M;
  XUSD 882,563 = $877.9k; rUSDT 90,486 ≈ $90.5k; BPRO 5.463 = $549.6k; SOV 5,838,596 = $121.7k; DOC $4.5k; DLLR $4.1k.
  **Total ≈ $7,305,975.** Lender claims (totalSupply×tokenPrice) ≈ $4.80M, of which $2.25M withdrawable now;
  ≈ $2.55M borrowed out (iDOC 99.9%, iDLLR 99.7%, iXUSD 62%, iWRBTC 28% utilisation).
- **Control:** owner = 48h Timelock `0x967c84b7…` (admin `0x6496DF39…`); protocol admin = 24h Timelock `0x6c94c8aa…`;
  Exchequer 3-of-7 `0x924f5ad3…`; Contracts Guardian/pauser Gnosis Safe 3-of-7 `0xDd8e07A5…`.

## 4. What an attacker can / cannot do

- **Can:** use the protocol normally — mint/burn iTokens, borrow, margin-trade, trigger liquidations, swap — exactly
  like any user. That is *not* extraction; it is the product. Gas is the only cost.
- **Cannot:** reactivate dead selectors (owner-only), remove the reentrancy guard (it is compiled into the modules),
  or reproduce the Oct-2022 recipe (fork-verified revert, §5).
- **The Oct-2022 recipe model (for reference):** cross-contract reentrancy; iUSDT leg via ERC-777 `tokensToSend`
  inside `closeWithDeposit` (mint at stale price 1.14772, burn at 1.19569 → ≈ +1,086.6 rUSDT/cycle ×5);
  iRBTC leg via native-RBTC fallback inside `closeWithSwap` (≈ +2.23 WRBTC/cycle). Capital: ≈8.20 WRBTC
  **flash-swap** from three RskSwap pairs (no flash-loan protocol, ~0.03 RBTC own funds). Losses: 44.9368 RBTC +
  282,351.9644 rUSDT ≈ $1.1M (recovered/refilled by the Exchequer). Today this reverts: the nested guarded call
  makes the outer call fail its mutex check and the closing modules' `iTokenSupplyUnchanged` invariant also blocks
  supply changes inside a close.

## 5. PoC / fork verification

`poc/test/SovrynH201.t.sol` — Foundry suite against a fork of RSK mainnet (keyless public RPC), **all tests
fork-only**. Custom CI job `ci/run.sh` additionally replays the original exploit tx on a pre-fix archive fork.

| # | Test | Proves |
|---|---|---|
| 01 | `test_01_live_iWRBTC_mint_and_burn` | Fresh unprivileged user mints and burns iWRBTC with native RBTC — pool live |
| 02 | `test_02_live_iUSDT_mint_and_burn` | rUSDT holder mints and burns iUSDT — LM beacon live |
| 03 | `test_03_auxiliary_selectors_revert_target_not_active` | `flashBorrow`, iToken `withdrawAccruedInterest` revert exactly `LoanTokenLogicProxy:target not active` |
| 04 | `test_04_routing_live_vs_dead` | Full routing map: mint/burn/borrow/marginTrade live; flashBorrow dead; protocol `liquidate` live; no pause |
| 05 | `test_05_oct2022_recipe_class_blocked` | Nested iWRBTC mint inside the native payout callback is rejected by the `nonReentrant` guard (record mode: inner revert captured; propagate mode: whole tx reverts); control burn succeeds |
| 06 | `test_06_reactivation_privileged_only_and_recipe_stays_blocked` | Non-owner registration reverts; Timelock rollback succeeds; **recipe still reverts after rollback** |
| 07 | `test_07_before_after_guard_bytecode` | Mutex guard in all live modules; absent from Oct-2022 logic (block 4,689,412) |
| 08 | `test_08_live_state_snapshot` | Live supplies/prices/borrows |

- CI (GitHub Actions, public repo `kingmariano/ca-zombie-ci`): **RUN_URL_PLACEHOLDER** (status/结论 placeholder).
- Historical replay in CI: `ci-out/oct2022_exploit_replay.txt` + `ci-out/oct2022_summary.txt`
  (pre-fix fork, `cast run 0xf5ea6266…`: 5 `Mint`/5 `Burn` cycles, transaction succeeds).
- Local pre-run evidence: `analysis/oct2022_exploit_replay_local.txt` (same replay, 1,637 trace lines).

## 6. Verdict, residual & latent risk, blockers

**Verdict.** E-U today **$0** for the H2-01 vector; the "deactivation switch" story is refuted. The protocol is
an operating $7.31M lending market, not a frozen vault. **H-O**: $2.25M immediately withdrawable by iToken
holders ($4.80M total lender claims backed by performing loans). **P**: governance holds the upgrade keys over the
whole system (48h Timelock + Bitocracy) — a real but *privileged* risk, not an unprivileged path. **S**: none.

**Latent exposure (kept separate from today's number):**
1. *Latent E-U via this vector:* **$0** — reactivation cannot resurrect the 2022 recipe (guard is in code;
   no pre-fix module exists in the beacon upgrade log; fork-tested).
2. *Privileged/governance:* up to the full **$7.31M** could be redirected by a malicious governance action
   (module registration is `onlyOwner`; 48h delay + Bitocracy admin). This is the residual "tripwire" — but it is
   **P**, not E-U, and it applies to the entire protocol rather than to a hidden switch.
3. *Market:* high utilisation (iDOC 99.9%, iDLLR 99.7%) + grandfathered SOV-collateral loans (5.84M SOV held by
   the protocol; SIP-0093 disabled new SOV/BPro collateral in 2026-06) create bad-debt/illiquidity scenarios that
   would move value from H-O to S if borrowers default. Liquidations are live (SIP-0087 unliquidatable-loan bug
   was fixed in Oct-2025).

**Blockers to exploitation:** `onlyOwner` reactivation; `globallyNonReentrant` mutex; `iTokenSupplyUnchanged`
invariant; (positive for users) no pause currently active.

## 7. Methodology, caveats, files

**Method.** Exhaustive selector enumeration from the official `rskSovrynMainnet` deployment ABIs (230 selectors)
queried against both beacons (`getTarget(bytes4)`) and the protocol (`logicTargets(bytes4)`); verified-source and
deployed-bytecode inspection (guard addresses/strings, pre/post-fix); balance/price reads at explicit blocks;
historical `cast run` replay; Foundry fork tests in CI. Sources: Sovryn official postmortem & interim update,
PR #453, rekt.news/Beosin/Halborn/SolidityScan, SIP-0093/0094 forum posts; all cross-checked on-chain.

**Caveats.** (1) Scope is the H2-01 vector; no full-protocol audit, so "no other E-U" is asserted with medium-high
confidence only. (2) rUSDT priced at $1.00 (no DefiLlama quote). (3) Protocol-held tokens are classified as borrower
collateral by inference from pool/loan accounting, not by per-loan tracing. (4) SOV in the protocol contract is
assumed collateral/fee residue; not per-loan attributed. (5) The CI historical replay uses `--quick` (gas differs
from the historical receipt; the call sequence is unaffected).

**Files.** `README.md` (this) · `summary.json` · `analysis/` (incident reconstruction, current-state dossier,
raw dumps, protocol/iToken sources, local replay trace) · `poc/` (Foundry project, 8 tests) · `ci/` (custom job) ·
`ci-out/` (CI artifacts) · `ci-log.txt` · `ci-artifacts/`.
