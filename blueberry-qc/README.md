# Blueberry — QC-4 adversarial re-audit (L2 Phase-2 quality control)

**Date:** 2026-10-13 · **Chains:** Monad (143), Ethereum (1), HyperEVM (999)
**Status:** read-only; fork PoCs on CI; **no mainnet transactions, no secrets.**
**Prior dossier:** `l2-triage-a` row #2 — Blueberry ("E-U ≈ $0.84 dust", 9/9 Monad + 2/2 ETH).
**This pass:** assume the prior closure is WRONG, try to break it.

---

## 1. TL;DR — verdict

> **Closure stands.** No material fresh-attacker path found. Fresh-attacker
> E-U = **≈ $0.84** (dust), unchanged in magnitude — but the composition is
> different from the prior dossier, and the prior *missed three of the five
> live reward auctions*.

| Category | USD (2026-10-13) | Confidence | Δ vs prior |
|---|---|---|---|
| **E-U** external unprivileged attacker | **≈ $0.84 net** (auction lots, after decay/price floors) | high | same magnitude, new breakdown |
| **H-O** holder/user self-service | ≈ $1.2329M (Monad vaults $1.2060M at face + ETH fork ≈ $26.3k + bank $79 + HL ≤ $498.24) | high | +$1.9k (vault drift) |
| **P** privileged-only | ≈ $9.8k (HL rest) + issuer/admin trust over the rest | medium | unchanged |
| **S** stuck/bricked | $0 | high | unchanged |

**Fresh-attacker E-U breakdown (fork-verified, §4):**

| Lot | Gross value | Min achievable payment | Net to attacker |
|---|---|---|---|
| opt2 active auction — 30.6386655 cWMON | $0.7808 | $0.00737 (decayed) | **$0.7735** |
| q1 orphan auction — 7.6557801 cWMON | $0.1951 | $0.15368 (per-token floor 0.02) | **$0.0414** |
| q3 orphan auction — 4.8807108 cWMON | $0.1244 | $0.10138 (per-token floor 0.02) | **$0.0230** |
| q2 orphan auction — 0.4436475 cWMON | $0.0113 | ≥$0.1109 within window | **$0 (unprofitable)** |
| strategy cWMON dust | ≈$0.000003 | — | ≈$0 |
| **Total** | **≈$1.11 gross** | | **≈$0.838 net ≈ $0.84** |

The prior's headline **$0.84 was numerically right but structurally wrong**: it
counted only opt2's *gross* lot value at MON $0.02575 (=$0.842) and missed
q1/q2/q3 entirely. At today's MON price ($0.02441) the opt2 lot is only $0.78
gross; the missed orphan lots add back ≈$0.064 net, landing at ≈$0.84 again.

---

## 2. What I attacked, and what actually moved

### 2.1 NEW: `kickAuction()` is PERMISSIONLESS in the deployed AuctionSwapper (prior assumed keeper-only)

The deployed `CurvanceOptimizer`/AuctionSwapper version has **no `onlyKeepers`
on `kickAuction`** (`function kickAuction(address _from) external virtual`) —
the source comments say it plainly: *"`kickAuction()` is public and
permissionless — anyone can trigger auctions"*. Gating is only:

1. `_isProtectedToken()` = `{asset, strategy, markets[]}` (Curvance markets are protected), and
2. the **Auction contract's governance-controlled `enable()` list**.

Fork proof (`test_qc02`): a fresh EOA re-kicks q1's expired auction
successfully; `kickAuction(asset)` and `kickAuction(market)` revert (protected);
`kickAuction(USDC)` reverts (not enabled). All five strategy auctions have
exactly **one** enabled token: cWMON. `governanceOnlyKick == false`,
`minimumPrice` is 0 (opt1/opt2) — so for enabled tokens anyone can kick and
take at decay. **This is the actual prior E-U path; it is real, and it is
broader than the prior believed (expired auctions are re-kickable by anyone).**

### 2.2 NEW: three of five auctions were missed — the orphan-strategy lots

The prior census found only opt2's auction. On-chain `getAllEnabledAuctions()`
+ balances show **five** auction contracts with **43.62 cWMON ≈ $1.11 gross**
in total, not 31.31 cWMON ≈ $0.84:

- opt2 (V2's strategy) — 30.6386655 cWMON, **active** (decaying);
- **q1** `0x481d…dbc6` — 7.6557801 cWMON in an **expired** auction (kickable by anyone);
- **q2** `0x814b…e071` — 0.4436475 cWMON, expired;
- **q3** `0x5b5d…f4b3` — 4.8807108 cWMON, expired.

q1/q2/q3 are *orphaned* strategies: they are in the vaults' default queues but
have `current_debt = 0`, `totalSupply = 0`, and **the vaults hold zero shares**;
their keeper still reports them (`last_report` within hours). The lots were
kicked ~6 days ago, expired, and nobody re-kicked them for 6 days.

### 2.3 The price floors blunt the new lots (exact economics)

`minimumPrice` is a **per-token** floor (`_price()` compares against the
per-unit price, not the lot price):

- q1/q3 floor **0.02/token** → best take ≈ 0.1537 AUSD / 0.1014 USDC → net $0.0414 / $0.0230;
- q2 floor **0.025/token** and startingPrice 150 (vs 0.44-token lot) → the
  floor is only reachable after 113,868 s > the 24 h window → best in-window
  payment 0.1109 AUSD ≫ value $0.0113 → **q2 is not extractable at a profit**.

Fork proofs: `test_qc03` (opt2 whole lot for 7,369 USDC-units = $0.00737),
`test_qc04` (q1 + q3 net), `test_qc05` (q2 unprofitable). CI: §6.

### 2.4 NEW (live-change): the ETH remnant is being actively upgraded

While running the ETH guard tests, the CI fork surfaced that the old Compound
fork's Unitroller (`0xcb0D9fF5…`) has a **pending comptroller implementation
`0x327e45b3…`** (verified source name `Comptroller`, 22,129 bytes) queued by the
admin (mgmt Safe). `comptrollerImplementation()` is still the old `0xffadb0bb…`.
This is an admin (P/trust) action, not an attacker path — but it shows the ETH
remnant is not fully dormant and is subject to implementation upgrades without a
timelock. The attacker's `_setPendingImplementation(ATTACKER)` was denied
(UNAUTHORIZED) even with the queued upgrade present.

### 2.5 The rest of the attack surface — all re-tested, all held

| # | Attack attempt | Result |
|---|---|---|
| 1 | Vault/strategy re-`initialize` by attacker | revert (PoC qc07) |
| 2 | Vault `set_role`, RoleManager `setPositionHolder`/`acceptGovernance` | revert; governance = mgmt Safe, pending = 0 (PoC qc07) |
| 3 | Accountant `redeemUnderlying`/`distribute`/`acceptFeeManager` | revert (onlyFeeManager/Recipient) (PoC qc07) |
| 4 | Strategy `report`/`tend`/`shutdownStrategy`/`emergencyWithdraw`/`setKeeper`/`setAuction`/`setUseAuction` | revert (PoC qc07) |
| 5 | `kickAuction` on asset / Curvance market / non-enabled token | revert (PoC qc02) |
| 6 | Donation to vault / strategy / sandwich around own redeem | pps + convertToShares unchanged; sandwich is a pure loss (PoC qc06) |
| 7 | Deposit→redeem round-trips: sizes {2, 1e3, 123456, 1e10} raw | out ≤ in in all cases (2→1, 1000→999, 123456→123454, 1e10→9999999999) (PoC qc06) |
| 8 | Vault: EIP-1167 45-byte minimal proxy, no EIP-1967 impl/admin slots | confirmed (PoC qc08) |
| 9 | Strategy proxy: ERC-1967 → canonical TokenizedStrategy `0xD377919F…`, admin slot 0 | confirmed (PoC qc08) |
| 10 | Deposit 1 raw unit → `cannot mint zero` (share 6 dp, no first-depositor edge) | harmless revert (observed) |
| 11 | Strategy deposits open to outsiders | `maxDeposit(attacker)=0`; `allowed` = vault only (PoC qc07) |
| 12 | Curvance position kick / liquidation | markets protected; positions are supply-only (no borrows) → nothing to liquidate |
| 13 | Vault queue withdrawals via orphan strategies | vault holds 0 shares of q1/q2/q3, `maxRedeem(vault)=0` → skipped |
| 14 | ETH Unitroller `_setPendingImplementation` / `_acceptImplementation` | returns `UNAUTHORIZED(1)`; admin = mgmt Safe; attacker cannot become pending impl (CI ETH test). **Live change observed: the admin has queued a real pending comptroller `0x327e45b3…` (verified `Comptroller`, 22,129 bytes)** |
| 15 | ETH cToken `_reduceReserves` as attacker | reverts / non-zero error code; all 13 markets have a real admin, pending 0 (CI ETH test) |
| 16 | ETH bank `liquidate(38/39)`, `execute(38, attacker, …)` | revert; owner = Safe; bank holds 0 USDC/USDT/WETH (CI ETH test) |
| 17 | HyperEVM router `redeem` beyond escrow liquidity | reverts (`FETCH_ASSETS_FAILED`); cap = escrow balance = `maxWithdrawable` $498.24 |
| 18 | HyperEVM router owner key | **2-of-3 Gnosis Safe** `0x08be6a54…` (≠ prior assumption of an EOA); `feeRecipient` = same Safe |

**Unrealised-loss / redeemer-ordering path:** the vault's loss assessment and the
strategy's `_withdraw` charge any realized loss to the redeemer of the moment
(3-arg strategy `redeem`, default `maxLoss = MAX_BPS`); a user cannot hand
losses to the rest of the pool, and an attacker cannot profit by redeeming
around a loss (they can only *avoid* their own loss, and only for losses not yet
recognized at the strategy level — which are recognized at withdrawal).
Unrealised loss at pin was 0 (prior); nothing changed.

---

## 3. Conditional paths (quantified, exact preconditions — never E-U)

| ID | Path | Preconditions | Value | Notes |
|---|---|---|---|---|
| **C1** | HyperEVM deposit→redeem share-price manipulation | (i) attacker can move the HL L1 spot mid of a supported deposit asset; (ii) router `deposit` is open (it is); (iii) deposit ≥ $10 minDeposit; (iv) redemption ≤ escrow liquid withdraw-asset | **≤ $498.24** (escrows `0xba3b…cc2` 37.68 USDT0 + `0x5652…d1f3` 460.55 USDT0) | Reclassifies part of H-O; adds no new value. `_getRate` uses HL spot oracles for non-USDC assets; USDC-indexed = $1. Economically marginal, capital-intensive. |
| **C2** | Profit-unlock capture | predict keeper `report()` with a gain; deposit before it; hold through the unlock | a share of *real* reported yield ∝ deposit size | Not principal theft; standard ERC-4626 yield participation. Keeper is an active EOA with `REPORTING` only. |
| **C3** | Role/key acquisition | compromise mgmt Safe **3-of-4** `0x72d1…9582` (all 14 vault roles + strategy management) **or** HL router 2-of-3 Safe | up to ≈$1.23M | P/trust; no timelock observed; no unprivileged route to roles (pending governance 0; management position holder is `address(0)` — inert). |
| **C4** | AUSD issuer/upgrade | AUSD is an **upgradeable proxy** (impl `0xc1e3c7d4…`); issuer can mint/freeze | $1.159M AUSD exposure | Issuer trust (Agora). No unguarded upgrade function reachable by outsiders found. |
| **C5** | Curvance-liquidity freeze | Curvance market illiquidity/solvency event | up to $1.205M (vault assets) | Losses socialize to holders; availableWithdrawLimit == debt and all positions liquid at the prior pin. Not attacker-extractable. |

**Closure conditions (what would re-open it):**
governance enabling another auction token with a material balance (all current
non-cWMON balances are protected or zero); `governanceOnlyKick` staying false
while reward lots grow (E-U scales linearly with any future enabled token);
MON price moves (E-U scales with MON); any new keeper-less strategy deployment.

**Privileged note (P):** the five Auction contracts have governance = the
3-of-4 mgmt Safe with `pendingGovernance = 0`; `sweep()` transfers any
auctioned token balance to the caller (governance), and `disable()`/`forceKick()`
are governance-only. The Safe can therefore confiscate the ~$1.11 of auctioned
cWMON to itself at any time — further bounding the attacker take-window, and
confirming the lots are not "orphaned" from the team's control.
The CoW `isValidSignature` path is price-bound (`buyAmount >= current
decayed payment`, receiver = strategy) and adds no discount beyond `take`.

---

## 4. Fork-verified numbers (Monad)

**QC fork blocks 113,070,305 → 113,075,181+ (2026-10-13); MON $0.02440884, cWMON rate 1.04410.**

```
opt2 auction: lot 30.638665528169386568 cWMON, active, kicked 1791893827
              take at kick+86,390s: need = 7,369 USDC-units ($0.00737)
              received value = $0.78084  → net $0.77347
q1 auction:   lot 7.655780076492398407 cWMON (incl. strategy dust)
              take at kick+50,000s: pay 153,683 AUSD ($0.15368) → value $0.19511 → net $0.04143
q3 auction:   lot 4.880710818980593294 cWMON
              take at kick+55,000s: pay 101,377 USDC ($0.10138) → value $0.12439 → net $0.02301
q2 auction:   lot 0.443647460842906079 cWMON — best in-window payment 110,536 AUSD ($0.1105)
              vs value $0.0113 → not profitable (floor unreachable within 24 h)
Total net  = 0.77347 + 0.04143 + 0.02301 ≈ $0.838
```

**Vaults live at QC fork:** V1 `totalAssets` 1,159,072.18 AUSD; V2 46,946.57 USDC;
V1 queue = [opt1 (debt), q1 (0), q2 (0)], V2 queue = [opt2 (debt), q3 (0)].
V1 `totalAssets == opt1 debt`; strategy shares 100% vault-held; deposits open, strategies closed.

---

## 5. QC counter-hypotheses rejected (with reason)

1. **"kickAuction is keeper-only"** — false; it is permissionless (2.1). Tested.
2. **"Only one auction exists / only 31.31 cWMON is exposed"** — false; five auctions, 43.62 cWMON gross (2.2). Tested.
3. **"Expired auctions can't be re-kicked"** — false; `_kick` requires `!isActive`; anyone can reset the 24 h window. Tested.
4. **"Take at near-zero payment"** — no; per-token `minimumPrice` floors + `needed != 0` + expiry at exactly 24 h. Tested.
5. **"Market tokens are ERC-20 balances held by the strategy and kickable"** — the strategy's positions live *inside* the market contracts; `markets[]` are in `protectedTokens()`; `kickAuction(market)` reverts. Tested.
6. **"Vault share inflation via donation / sandwich"** — stored accounting; unchanged pps; sandwich is a loss. Tested.
7. **"Rounding grinding"** — all conversions round against the user; 4 sizes tested.
8. **"Role acquisition via RoleManager/Accountant"** — all setters gated; governance Safe; pending 0. Tested.
9. **"Proxy upgrade / re-init"** — vault = immutable 45-byte minimal proxy; strategy admin slot 0; re-init reverts. Tested.
10. **"ETH bank liquidatable / cToken admin drain"** — no; guards + zero bank balances. Tested (CI).
11. **"HL router drain via redeem"** — capped at escrow liquidity; owner is a Safe. Verified live.

---

## 6. PoC / CI verification

| Project | Chain | Tests | Result |
|---|---|---|---|
| `poc-monad/` (`test/BlueberryQc.t.sol`) | Monad fork @head-200 via `https://rpc.monad.xyz` | 9 | **9/9 PASS** (local + CI) |
| `poc/` (`test/BlueberryEthQc.t.sol`) | Ethereum fork (latest) via `FORK_RPC_URL` | 4 | **4/4 PASS** (CI) |

CI runs (public repo `kingmariano/ca-zombie-ci`, branch `blueberry-qc`, workflow `poc.yml`):
- **Run 1** (first dispatch): `https://github.com/kingmariano/ca-zombie-ci/actions/runs/38422529491` — Monad 9/9 PASS; ETH 3/4 (one over-strict assertion, fixed below).
- **Run 2 (final)**: `https://github.com/kingmariano/ca-zombie-ci/actions/runs/38423003426` — **Monad 9/9 PASS + ETH 4/4 PASS**; logs `ci-log.txt`, artifacts `ci-artifacts/` (`ci-out/monad-qc-tests.log`).
- ETH run-1 finding (kept, now an assertion): the admin has queued a real pending comptroller `0x327e45B3…` (verified `Comptroller`) — the attacker cannot become pending impl.

Local QC run (DRPC, 2026-10-13):
```
Ran 9 tests for test/BlueberryQc.t.sol:BlueberryQcTest
[PASS] test_qc01_auction_surface()                 [PASS] test_qc06_vault_math_edges()
[PASS] test_qc02_kickAuction_permissionless()      [PASS] test_qc07_guards_sweep()
[PASS] test_qc03_extract_opt2_auction()            [PASS] test_qc08_proxy_surface()
[PASS] test_qc04_extract_q1_and_q3_orphan_lots()   [PASS] test_qc09_live_totals()
[PASS] test_qc05_q2_not_profitable()
Suite result: ok. 9 passed; 0 failed
```

---

## 7. Methodology, evidence, caveats

**Method:** recovered the prior dossier from the CI branch `blueberry`; re-read
all verified sources (vault Vyper, TokenizedStrategy, AuctionSwapper/Auction,
CurvanceOptimizer, RoleManager, Accountant, HyperVaultRouter/Escrow,
BlueberryBank, Compound-fork Comptroller); live keyless/read-only state on
Monad/Ethereum/HyperEVM; adversarial Foundry fork PoCs on CI.

**Evidence files:** `analysis/` (recovered prior sources + extracted raw soldity),
`live/` (QC live-read scripts + `auction-state.json`), `poc-monad/`, `poc/`,
`ci/`, `ci-out/`.

**Caveats:**
1. Point-in-time values; vaults and auctions are actively managed (keeper reports every few hours).
2. USD figures use MON $0.02440884 (DefiLlama, 2026-10-13) and cWMON rate 1.04410; AUSD face $1 in totals.
3. Strategy/proxy ownership and beneficiary resolution: q1/q2/q3 strategy shares have `totalSupply = 0` (orphaned) — the team's operational history explains them; their cWMON is bounty for anyone.
4. The ETH/HyperEVM figures are carried over from the prior dossier (unchanged addresses/values verified live where possible).
5. Curvance protocol internals beyond the strategy boundary were not re-audited (out of scope).
6. Auction lots can be taken by keepers/arbitrageurs at any moment; the q1/q3 figures assume the lots still exist at execution time.

---

## 8. Chain of custody

- Prior dossier branch (read-only): `kingmariano/ca-zombie-ci@blueberry` — `blueberry/README.md`, `summary.json`, `ci-out/state.json`.
- QC branch: `kingmariano/ca-zombie-ci@blueberry-qc` — this dossier + tests.
- All calls read-only; no keys; no transactions; faucets impersonated only inside forks.
