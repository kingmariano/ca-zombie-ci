# H2-01 — live state assessment (Sovryn legacy Lend/Borrow, RSK mainnet, chain id 30)

All reads keyless via `https://public-node.rsk.co`; explorer `https://rootstock.blockscout.com`.
State captured 2026-10-10 at RSK blocks **9,313,380** (balances) and **9,313,446** (control/targets).
Raw dumps: `targets_live.json`, `lm_beacon_targets.json`, `balances_itype.json`, `module_selectors.json`,
CI `ci-out/state_dump.json`.

## 1. Contracts & control map

| Role | Address | What it is (verified on-chain) |
|---|---|---|
| Protocol dispatcher | `0x5A0D867e0D70Fcc6Ade25C3F1B89d618b5B4Eaa7` | `sovrynProtocol`, verified 0.5.17; fallback routes `logicTargets[msg.sig]` |
| Protocol **owner** | `0x967c84b731679E36A344002b8E3CE50620A7F69f` | **48h Timelock** (`delay()=172800`), admin = `0x6496DF39D000478a7A7352C01E0E713835051CcD` (GovernorOwner/Bitocracy). **NOT a Safe** |
| Protocol **admin** | `0x6c94c8aa97C08fC31fb06fbFDa90e1E09529FB13` | second **Timelock** (`delay()=86400`), admin = `0xfF25f66b7D7F385503D70574AE0170b6B1622dAd` |
| LoanTokenLogicBeacon (iWRBTC) | `0x845eF7Be59664899398282Ef42239634aBDd752C` | owner = 48h Timelock; `getTarget(bytes4)` (whenNotPaused) |
| LoanTokenLogicBeacon (LM tokens) | `0x5b155ECcC1dC31Ea59F2c12d2F168C956Ac0FFAa` | owner = 48h Timelock |
| SharedReentrancyGuard Mutex | `0xba10edD6ABC7696Eae685839217BdcC42139612b` | global counter used by `globallyNonReentrant` |
| Exchequer multisig | `0x924f5ad34698Fd20c90Fe5D5A8A0abd3b42dc711` | custom RSK `MultiSigWallet`, **3-of-7** (owners: 0x32406677…, 0xA56941f8…, 0xEaBB83a1…, 0xDE169048…, 0xDFD4dA0E…, 0xFEe171A1…, 0x0c9655A2…) |
| Contracts Guardian / pauser | `0xDd8e07A57560AdA0A2D84a96c457a5e6DDD488b7` | Gnosis Safe, **3-of-7** (owners: 0xDFD4dA0E…, 0x32406677…, 0xB2DB3FCB…, 0x27ae0fB7…, 0x6af32fE0…, 0xd24a9c55…, 0xEaBB83a1…) |

iToken proxies (all legacy `LoanToken`, all `target_` = shell `0x8Cf4737DA60c5F04A3b1e3D63a4ed84a7f8fF26e`):

| iToken | Address | Underlying | Beacon |
|---|---|---|---|
| iWRBTC | `0xa9DcDC63eaBb8a2b6f39D7fF9429d88340044a7A` | WRBTC `0x542fDA31…` | Wrbtc `0x845eF7Be…` |
| iUSDT | `0x849C47f9C259E9D62F289BF1b2729039698D8387` | rUSDT `0xEf213441…` | LM `0x5b155ECc…` |
| iXUSD | `0x8F77ecf69711a4b346f23109c40416BE3dC7f129` | XUSD `0xb5999795…` | LM |
| iDOC | `0xd8D25f03EBbA94E15Df2eD4d6D38276B595593c1` | DOC `0xe700691d…` | LM |
| iDLLR | `0x077FCB01cAb070a30bC14b44559C96F529eE017F` | DLLR `0xc1411567…` | LM |
| iBPro | `0x6e2Fb26a60DA535732f8149B25018c9C0823a715` | BPRO `0x440CD83C…` | LM |

Note: the H2-01 finding said "iTokens + 4 more" → 7 total; the chain has **6** iToken pools
(the 7th `LoanTokenLogicProxy`-named contract is a spare uninitialised shell).

## 2. Routing map (what is live vs dead) — blocks 9,313,446

**Beacon level (iToken functions)** — `getTarget(selector)`:

| Function | Selector | Target | Status |
|---|---|---|---|
| `mint(address,uint256)` | 0x40c10f19 | 0x6c8f59D3 (iWRBTC) / 0x593DB96E (LM) | **LIVE** |
| `burn(address,uint256)` | 0x9dc29fac | same | **LIVE** |
| `mintWithBTC(address,bool)` | 0xfb5f83df | 0x6c8f59D3 | **LIVE** |
| `burnToBTC(address,uint256,bool)` | 0x0506af04 | 0x6c8f59D3 | **LIVE** |
| `borrow(...)` | 0x2ea295fa | 0xD0dbAe16 (iWRBTC) / 0x45569950 (LM) | **LIVE** |
| `marginTrade(...)` | 0x28a02f19 | 0xD0dbAe16 / 0x45569950 | **LIVE** |
| `marginTradeAffiliate(...)` | 0xf6b69f99 | same | **LIVE** |
| `transfer`/`approve`/`transferFrom` | ERC20 | same | **LIVE** |
| `flashBorrow(...)` | 0xd4299134 | 0x0 | **DEAD** (never registered) |
| `withdrawAccruedInterest(address)` | 0xe81fefa0 | 0x0 | **DEAD** (present in 2022 logic, dropped in 2023 beacon migration) |
| `liquidate`/`rollover` (iToken level) | 0x709e8ca8 / 0xcf0eda84 | 0x0 | **DEAD** (liquidation is protocol-level now) |

**Protocol level** — `logicTargets(selector)`:

| Function | Selector | Target | Status |
|---|---|---|---|
| `liquidate(bytes32,address,uint256)` | 0xe4f3e739 | 0xd01B701b (LoanClosingsLiquidation) | **LIVE** |
| `closeWithSwap(...)` | 0xf8de21d2 | 0xa3FCC9F8 (LoanClosingsWith) | **LIVE** |
| `closeWithDeposit(...)` | 0x366f513b | 0xa3FCC9F8 | **LIVE** |
| `rollover(bytes32,bytes)` | 0xcf0eda84 | 0xdB4fF0a8 | **LIVE** |
| `borrowOrTradeFromPool(...)` | 0xd84ca254 | 0x000fec34 (LoanOpenings) | **LIVE** |
| `depositCollateral`/`withdrawCollateral` | 0xdea9b464 / 0xdb35400d | 0xa87Bd1eF (LoanMaintenance) | **LIVE** |
| `swapExternal(...)` | 0xe321b540 | 0xBba83482 (SwapsExternal) | **LIVE** |
| `marginTrade(...)` (legacy entry point) | 0x28a02f19 | 0x0 | **DEAD** |
| `borrow(...)` (legacy entry point) | 0x2ea295fa | 0x0 | **DEAD** |

**Pause state:** `isProtocolPaused() == false`; both beacons unpaused; per-iToken
`checkPause("borrow"|"marginTrade"|"mint"|"burn") == false` for all 6 iTokens.

## 3. Balances (block 9,313,380) and USD

Prices (DefiLlama, 2026-10-10): WRBTC $82,888.32 · XUSD $0.99471 · DOC $0.99967 · DLLR $0.99697 ·
BPRO $100,598.95 · SOV $0.02085 · rUSDT taken as $1.00 (bridged USDT; DefiLlama has no quote).

| Token | iToken pool balance | Protocol-held (collateral/fees) | Total | USD |
|---|---|---|---|---|
| WRBTC | 19.7338 | 48.5226 | 68.2564 | $5,657,660 |
| rUSDT | 90,417.53 | 68.94 | 90,486.47 | $90,486 |
| XUSD | 520,622.43 | 361,940.81 | 882,563.24 | $877,896 |
| DOC | 5.08 | 4,516.29 | 4,521.37 | $4,520 |
| DLLR | 1,468.68 | 2,655.29 | 4,123.97 | $4,112 |
| BPRO | 0.04986 | 5.41307 | 5.46293 | $549,572 |
| SOV | — | 5,838,596.30 | 5,838,596.30 | $121,729 |
| **Total** | **$2,250,489 liquid** | **$5,055,486** | | **$7,305,975** |

- **Lender claims** (totalSupply × tokenPrice): iWRBTC 27.531 WRBTC ($2.282M), iUSDT 90,417
  ($90.4k), iXUSD 1,370,776 ($1.364M), iDOC 622,800 ($622.6k), iDLLR 438,967 ($437.6k),
  iBPro 0.0525 ($5.3k) → **≈ $4.80M total**; of which **$2.25M withdrawable now** (pool balances).
- **Borrowed out:** iWRBTC 7.795 WRBTC ($646k), iXUSD 850,033 ($845.5k), iDOC 622,449 ($622.2k),
  iDLLR 437,493 ($436.2k) → ≈ $2.55M (iUSDT and iBPro have ~0 borrows).
- **Protocol-held tokens** are loan collateral (WRBTC/XUSD/DOC/DLLR/BPRO/SOV) + fee residue.

## 4. Reactivation mechanics (exact)

- A call to an iToken delegates to the shell `0x8Cf4737D…`, whose fallback does
  `ILoanTokenLogicBeacon(_beaconAddress()).getTarget(msg.sig)` and then
  `require(target != address(0), "LoanTokenLogicProxy:target not active")`.
  **The revert occurs exactly when the beacon's per-selector `logicTargets[sig]` is zero**
  (or when the beacon is paused → "LoanTokenLogicBeacon:paused mode").
- **Single owner action to (re)activate:** `LoanTokenLogicBeacon.registerLoanTokenModule(address)`
  or `rollback(bytes32,uint256)` — both `onlyOwner` (the 48h Timelock). At protocol level:
  `sovrynProtocol.setTargets(string[],address[])` — `onlyOwner` (same Timelock).
- **Non-owner path:** none. `onlyOwner` on all three; PoC test `test_06` proves an arbitrary
  caller's `registerLoanTokenModule` reverts.
- The beacon's upgrade log for module `LoanTokenLogicWrbtcLM`: v0 = `0x24B36879…` (Oct-2023),
  v1 = `0x6c8f59D3…` (Sep-2026, SIP-0094 "Perimeter"); both contain the Mutex guard. For
  `LoanTokenLogicLM`: v0 = `0xfaffde71…`, v1 = `0x593DB96E…`; both contain the guard.
  **No pre-fix (2022) module exists in the upgrade log.**
