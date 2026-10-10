# flare-flow — Sceptre Liquid (Flare) + MORE Markets (Flow EVM)

H2-09 "legacy-custody watches" deep-dive (zombie-hunt II), group **flare-flow**.
Date: 2026-10-10. All reads are **read-only** (`eth_call` / explorer API). No transactions signed or sent.
All RPCs used are public/keyless: `https://flare-api.flare.network/ext/C/rpc` (Flare), `https://mainnet.evm.nodes.onflow.org` (Flow EVM), explorers `flare-explorer.flare.network`, `evm.flow.com`, plus Blockscout MCP and DefiLlama/GeckoTerminal for prices.

Chain liveness verified (blocks advancing):
- Flare: 71,772,220 → **71,779,062** during the session (block time ≈1.8 s).
- Flow EVM: 81,310,662 → **81,320,327** during the session.

---

## 1. Sceptre Liquid — sFLR (Flare, chain 14)

**TVL (DefiLlama, 2026-10-10): $15,249,065.** Own computation at block 71,772,220: 2,165,600,711.41 pooled FLR × $0.007022478 (DefiLlama WFLR) = **$15.21M**.

### Contracts

| Role | Address | Notes |
|---|---|---|
| sFLR token (TransparentUpgradeableProxy, EIP-1967) | `0x12e605bc104e93b45e1ad99f9e555f659051c2bb` | proxy verified |
| Implementation `StakedFlr` | `0xCa0fEe77bDEAdcb0Af9C1b98d7776EFaa8a04B89` | verified source (solc 0.6.12), reviewed in full |
| ProxyAdmin | `0x1e3beaf840b96353a8be0a75b6dbb176dced66ce` | unverified; `owner()` = `0xf76a23626c2527638b3eaf3d497a7c111f6d0ef9` (**single EOA**) |
| wrappedToken | `0x1d80c49bbbcd1c0911346656b529df9e5c2f783d` | WFLR (1:1 wrap of FLR) |
| FlareDrops distribution (hard-coded) | `0x9c7A4C83842B29bB4A082b0E689CB9474BD938d0` | `claimReward()` calls this |
| `RECIPIENT_ADDRESS` (hard-coded) | `0xC2D2171434DC229E3F16167f453B84a94E323E38` | FlareDrop claim recipient |
| protocolRewardShareRecipient (live) | `0x93d67e3fe45017d85e333a595201a3a0546aa8db` | EOA, gets 10 % of accrued rewards |
| Role-holder contracts | `0xb8a32889545c2bc5c3ddbbbc42fc9e635f11fd71` (proxy → `FlareDropManager`), `0x6cad5d2650cab57d8aa10dd3291955c94d94d86b` (proxy) | 2 of the 40 unique role holders |

### Live state at block 71,772,220 (`0x447283c`, ts 1791631793) — raw JSON: `sceptre_state_block71772220.json`

- `totalPooledFlr()` = 2,165,600,711.407390189134515776 FLR
- `totalShares()` = 1,145,584,228.582273023744303130 sFLR
- `getPooledFlrByShares(1e18)` = **1.8903897743838938 FLR per sFLR**
- `instantRedeemBuffer()` = 46,724,137.596567959806612486 FLR (~$328 k) — logical cap for instant redeems
- `instantRedeemFee()` = 0.5 % (`5e15`); `buyInStakingFee()` = 0; `pendingBuyInFees()` = 0
- `cooldownPeriod()` = 1,252,800 s (14.5 d); `redeemPeriod()` = 172,800 s (2 d)
- `totalPooledFlrCap()` = 40e27 (40 B FLR — non-binding)
- `protocolRewardShare()` = 10 %; `paused()` = false; `mintingPaused()` = false; `stakerCount()` = 5,137
- WFLR balance of the sFLR contract = **48,620,332.03 WFLR (~$341 k)**; native FLR balance = 0
- Role counts: DEFAULT_ADMIN 1, ACCRUE_REWARDS 35, DEPOSIT 37, WITHDRAW 34, PAUSE/RESUME/PAUSE_MINTING/RESUME_MINTING 1 each, SET_CAP 2, MANAGE_INSTANT_REDEEM_BUFFER 34; **40 unique holders, 38 EOAs + 2 contracts** (`sceptre_roles_block71775945.json`)

### Checks

**(a) Custody & who can move it.** The contract itself only holds WFLR (48.62 M, 2.2 % of pooled FLR). The rest of the pooled FLR was withdrawn as native FLR by "warden" EOAs via `withdraw(amount)` (`Withdraw` events; top wardens each took 300–460 M FLR: `0x355ee796…`, `0x4cbc289f…`, `0xecb4b9c9…`, `0xabc938ca…`, `0x8d17aa0e…`, `0xf299ad5a…`, `0x6eb75fbe…`, `0x5801d09a…` — all EOAs; see `sceptre_withdraws_events.json`). `withdraw()` requires `ROLE_WITHDRAW` (34 EOAs/contracts), sends to `msg.sender` with no destination or timing restriction, and only asserts `totalPooledFlr` is unchanged (the unwrap must happen first). FLR already withdrawn sits with warden EOAs off-contract (delegated to validators). **P-class:** any `ROLE_WITHDRAW` holder can move the contract's WFLR balance; the ProxyAdmin owner EOA can upgrade the implementation (⇒ all funds).

**(b) Exchange rate computation.** `getPooledFlrByShares = shareAmount × totalPooledFlr / totalShares`; `totalPooledFlr` is an **internal accounting variable**, only mutated by `submit`/`submitWrapped` (+deposit), `accrueRewardsExt` (role-gated), `instantRedeem` (decrement by net payout), and `disableBuyInStaking`. `withdraw()`/`deposit()` assert `totalPooledFlr` does not change. **Not derived from any spot balance of a pool** ⇒ not spot-manipulable. Direct WFLR donations to the contract do not change the rate (no `balanceOf` use in pricing; there is no skim function — donations only become warden-withdrawable).

**(c) Mint/redeem paths.** Minting happens only in `submit()` (payable, wraps via `wrappedToken.deposit`) and `submitWrapped()` (pulls WFLR) at the fair rate; no unbacked mint path exists. The `_getShareAmount` fallback (`shareAmount = amount`) is only reachable when `totalPooledFlr == 0` because `getSharesByPooledFlr` reverts when the computed share count is 0 (`require(shares > 0)`); best-case rounding gain ≤ 1 wei FLR per tx and is unreachable in practice. `instantRedeem` burns shares, pays `net = gross − fee`, keeps the fee in `totalPooledFlr` (rate rises for holders), and is bounded by both the logical buffer and the physical WFLR balance. `redeem` pays at the **historical rate at the unlock-claimable timestamp** (latest recorded rate ≤ `startedAt + cooldown`); rates are non-decreasing, so a redemption can never exceed fair current value; if no rate ≤ claimable exists the fallback is `1e18` (pays *less*). All user entry points are `nonReentrant`.

**(d) Unstaking queue.** `requestUnlock` moves the user's shares to the contract and appends to `userUnlockRequests[msg.sender]` with `userSharesInCustody[msg.sender]` accounting; `redeem()`/`redeem(index)`/`cancelUnlockRequest`/`cancelPendingUnlockRequests`/`cancelRedeemableUnlockRequests`/`redeemOverdueShares` all operate only on `msg.sender`'s own requests. No cross-user path exists. `getPaginatedUnlockRequests(user)` is view-only.

**(e) Oracle dependencies (FTSO).** **None.** The reviewed implementation contains no price-oracle reads and the ABI exposes no oracle address. Staking/delegation rewards arrive as plain FLR via the role-gated `accrueRewardsExt`, and FlareDrops are claimed via `claimReward` → the hard-coded distribution contract. There is no on-chain price feed in scope, hence no oracle-manipulation surface for sFLR.

**(f) Admin gating.** AccessControl roles as listed above; DEFAULT_ADMIN/PAUSE/RESUME/MINTING_PAUSE are a **single EOA** (`0xf76a2362…`), which is also the owner of the ProxyAdmin (upgrade right). ROLE_WITHDRAW/DEPOSIT/ACCRUE_REWARDS are spread across 33–37 EOAs plus `FlareDropManager`. Upgrading is not timelocked (ProxyAdmin, no delay observed).

### Verdict

- **E-U: $0.** No unprivileged extraction path constructible: rate is internal accounting; mint requires deposit; redeem is user-scoped and rate-capped; rounding bounded at < 1 wei FLR/tx and unreachable; donations inert; queue cannot be touched cross-user. Best-case attacker take ≈ **$0**.
- **H-O: fair, holder-scoped.** User paths behave as designed for holders (fee retained to pool, historical-rate redemptions ≤ fair value).
- **P: material.** (i) single-EOA upgrade authority over a $15.2 M TVL proxy; (ii) 34 `ROLE_WITHDRAW` EOAs can move the contract's 48.6 M WFLR (~$341 k) with no destination restriction; (iii) ~2.1 B FLR already in warden EOA custody off-contract.
- **Confidence: high** (verified source fully reviewed + live reads at pinned blocks + role enumeration).

---

## 2. MORE Markets (Flow EVM, chain 747)

Two Aave-v3.0.x-fork markets. Snapshot block **81,310,662** (`0x4d8b3c6`, ts 1791636441) — raw JSON: `more_state_block81310662.json`.

### Contracts

| Role | Market 1 | Market 2 |
|---|---|---|
| DataProvider | `0x79e71e3c0EDF2B88b0aB38E9A1eF0F6a230e56bf` | `0xF580F6F3A2223Db22294c2241c7e0Cc401d20659` |
| AddressesProvider | `0x1830a96466d1d108935865c75B0a9548681Cfd9A` | `0xC75401A18Cd8a4A36b2F3F5945ee99223745b568` |
| Pool (proxy) | `0xbC92aaC2DBBF42215248B5688eB3D3d2b32F2c8d` | `0x23946E2fa751F0aecf655a59613beF86e20881B5` |
| Pool impl | `0x91eB147463a84112a57DAd27a180cDfDd628806B` (`Pool`, verified) | `0x51b72e1C2a4afd63Bdc073261a4e8e00A0F29948` |
| PriceOracle (`AaveOracle`) | `0x7287f12c268d7Dff22AAa5c2AA242D7640041cB1` | `0xB84736f2864139F4e78760bD2Fa54b2de960BF5D` |
| ACLManager | `0x5729Bd11b09fA80487221C32F47d22fC255B1A5D` | `0xc894162561228F95813aA79b92109B45F948Fe6d` |
| PoolConfigurator | `0x8385ed74a1a49ebd08044b17e17153cb9d0f0ad9` | `0x543e39df1015a5d1d23285d59ec1c2622d2dc85b` |
| Admin | `0x02362E5221B1D6045781975E5e9b3a9507A46447` — **Safe 5-of-9** | `0x1a638EdA3f63f7a311e2C83f51201EBB42B43499` — **single EOA** |
| Risk/emergency | EMERGENCY `0x2c262723…` Safe 2-of-3; RISK `0x667f84b5…`+`0x80bea47b…` `ReservesSetupHelper`, `0x2c262723…` Safe 2-of-3 | RISK `0x667f84b5…`; FLASH_BORROWER `0xd0d01ea1…` (`FlashLoanLiquidation`) |
| BRIDGE role | **not granted** (RoleGranted logs) | **not granted** |

### Market 1 reserves — all **PAUSED** (paused ⇒ supply/withdraw/borrow/repay/liquidate all revert, see proof below)

| Reserve | LTV/LT | bonus | eMode | supply (tokens) | cash | debt | USD supply¹ |
|---|---|---|---|---|---|---|---|
| WFLOW | 81.5/83 % | 1.05 | 1 | 78,615,534.02 | **0** | 78,653,570.56 | $2.52 M |
| ankrFLOWEVM | 78.5/81 % | 1.06 | 1 | 107,816,572.12 | 107,816,568.28 | 4.09 | $4.20 M / $2.99 M² |
| USDF | 75/79.25 % | 1.075 | 0 | 655,367.88 | 645,776.44 | 9,599.50 | $0.66 M |
| stgUSDC | 75/78 % | 1.075 | 0 | 667,709.26 | 315,032.71 | 353,083.77 | $0.67 M |
| WETH | 80/83 % | 1.05 | 0 | 66.9524 | 66.9601 | 4.9e-7 | $0.17 M |
| PYUSD0 | 75/78 % | 1.075 | 0 | 1,468,335.59 | 124,945.31 | 1,348,610.11 | $1.47 M |
| WBTC | 73/78 % | 1.05 | 0 | 0.001 | 0.001 | 0 | $83 |
| USDC.e, cbBTC | frozen | — | 0 | 0 | 0 | 0 | $0 |

¹ at oracle prices; ² $4.20 M at the oracle price vs $2.99 M at the DEX price ($0.02774, GeckoTerminal).
Totals: supply ≈ **$9.68 M**, debt ≈ **$4.24 M**, supplier equity ≈ **$5.45 M** (oracle-priced; DefiLlama reports $4.09 M with market-priced ankrFLOW). `unbacked = 0` on every reserve. All borrow/supply caps are 0 (= uncapped) except WBTC supplyCap 2.

### Market 2 reserves (not paused, effectively empty)

| Reserve | LTV/LT | paused | supply | cash | debt | borrowCap |
|---|---|---|---|---|---|---|
| WFLOW | 80.5/83 % | false | 1.0 | 1.0 | 0 | 80,000 |
| TRUMP | 65/70 % | false | 72.1384 | 72.1384 | 0 | 0 |
| stgUSDC | 75/78 % | false | 0.379536 | 0.379536 | 0 | 0 |

Total market-2 supply ≈ **$137**. No borrowable liquidity exists.

### The freeze (verified on-chain)

- `ReservePaused(asset, true)` emitted for **all 9 market-1 reserves at block 77,003,531 (2026-08-31 10:29:22 UTC)** — latest pause action; earlier freeze/unfreeze cycles: 2025-12-27 (all paused), 2026-01-01 (6 unpaused), 2026-05-22 (all paused, then unpaused 4 h later).
- Pause tx `0x5892f243aa4e6e51fe17e27349be6167c912b7d7f083de6db56009371a5a5c7c` = `execTransaction` of the **2-of-3 Risk Safe** `0x2C262723…`.
- In this fork `isPaused` is checked in `validateSupply`, `validateWithdraw`, `validateBorrow`, `validateRepay`, `validateSwapRateMode`, `validateRebalanceStableBorrowRate`, `validateSetUseReserveAsCollateral` **and `validateLiquidationCall`** (source read).
- `eth_call` simulations at the snapshot (from the largest aWFLOW supplier `0x7f8D3D53…`): `withdraw`, `borrow`, `supply`, `repay`, `liquidationCall` **all revert with Aave error 29 = RESERVE_PAUSED**. So suppliers cannot withdraw, borrowers cannot repay, and nobody can liquidate.

### Borrowers (health at snapshot; `more_health_block81310662.json`)

| User | collateral | debt | LT | HF (oracle) | collateral composition |
|---|---|---|---|---|---|
| `0xCBf9a775…` | $2,330,833 | $770,669 | 97.5 % | 2.949 | mixed |
| `0xA0C2fe72…` | $516,814 | $500,132 | 97.5 % | **1.008** | **100 % ankrFLOW** (13,307,608.86) |
| `0xD52526d3…` | $434,149 | $418,866 | 97.5 % | **1.011** | eMode WFLOW/ankrFLOW |
| `0x04f9c518…` | $369,933 | $359,708 | 97.5 % | **1.003** | **100 % ankrFLOW** (9,525,522.55) |
| `0xaF3F76eC…` | $275,303 | $180,568 | 79.25 % | 1.208 | — |
| `0x7f8D3D53…` | $3,356,443 | $1,332,728 | 81.2 % | 2.045 | — |

### Oracle

- Sources are Pyth adapters ("A port of a chainlink aggregator powered by pyth network feeds", decimals 8) for WFLOW/ETH/BTC/USDC/TRUMP, **except ankrFLOW**: `AnkrFlowToUsdFeed` `0xb9c94fc69bf20fab29c146b1efa1b2671328d5dc` computes `FLOW/USD ÷ AnkrRatioFeed.getRatioFor(ankrFLOW)`; the ratio feed (`AnkrRatioFeed` impl `0x4874247D…`, proxy `0x32015e1b…`) is operator-pushed, monotonically decreasing, updated weekly (last 2026-10-08 to `0.824544111365702947`).
- **ankrFLOW oracle = $0.0389431 vs DEX market $0.02774–0.02828 (GeckoTerminal; DefiLlama $0.026276): overvalued ~ +40 %.** All other feeds within ±1 % of DefiLlama (WFLOW +0.76 %, WETH +0.006 %, WBTC +0.09 %, stables ±0.03 %).
- Pyth adapters were **~1,391 s (23 min) stale** at the snapshot (`latestTimestamp 1791635050` vs block ts 1791636441); AaveOracle v3.0.x has no heartbeat/staleness check. Updates are permissionless via the Pyth contract, so this is a keeper-latency issue, not a manipulation primitive.
- Because of the inflated ankrFLOW feed, the two 100 %-ankrFLOW positions above are **insolvent at market prices**: `0x04f9c518` real HF ≈ 0.72, `0xA0C2fe72` real HF ≈ 0.72 (collateral at $0.02774). The oracle masks ≈ **$860 k of effectively bad debt**; the third (HF 1.011, $419 k) is at the edge.

### Checks & verdict

- **(a)** Reserves enumerated above; all live numbers in `more_state_block81310662.json`.
- **(b)** Oracle: owner-pushed only for the Ankr ratio; prices/timestamps vs real prices reported above; no zero/stale-broken feeds (all answers > 0, max staleness 23 min).
- **(c)** Fork hazards: `mintUnbacked` is `onlyBridge` and **BRIDGE is unassigned on both markets** (RoleGranted logs + `hasRole` checks) ⇒ cannot mint unbacked; `unbacked = 0` everywhere. eMode category 1 ("Wrapped native tokens", LTV 97 %, LT 97.5 %, bonus 1.01) includes ankrFLOW — the latent vector. Flash-loan/donation to the empty market is inert (Aave index-based accounting; market 2 has no victim liquidity). Liquidation bonus > 1 cannot be exploited because **liquidation itself reverts while paused**. `setUserUseReserveAsCollateral` also reverts while paused.
- **(d)** Roles: market 1 admin = 5-of-9 Safe, risk = 2-of-3 Safe + 2 helper contracts; market 2 admin = single EOA; no BRIDGE anywhere.
- **(e) Quantification — now: $0 extractable.** No unprivileged path: market 1 is fully frozen (all ops revert 29), market 2 has ≈$137 of liquidity and no borrowable cash. **Latent scenario (requires a privileged unpause, no oracle fix):** supply ankrFLOW bought at market (~$0.80 M real for 28.9 M ankrFLOW), borrow 97 % of the oracle-valued $1.12 M against the available stable cash (stgUSDC $315 k + USDF $646 k + PYUSD0 $125 k ≈ $1.09 M), default ⇒ protocol bad debt ≈ **$0.29 M per cycle** (and the existing $0.86 M masked shortfall becomes real). This is P-conditional, not E-U today.
- **Verdict: E-U $0 (proven for current state: pause simulations + empty market 2). P: admin freeze of ≈$5.45 M supplier equity since 2026-08-31 (all ops incl. liquidations blocked; S-conditional — reversible only by admin unpause); single-EOA admin on market 2; latent ankrFLOW oracle overvaluation (+40 %, $0.86 M masked shortfall).** Confidence: **high** (verified Aave v3.0.x source read + full reserve/oracle/role enumeration + revert simulations).

---

## Negatives recorded (with evidence)

- Sceptre: no oracle use (source+ABI); no unbacked mint; no cross-user queue path; donations inert; rounding < 1 wei/tx and unreachable; `redeem` capped by historical rate.
- MORE: `mintUnbacked` unreachable (no BRIDGE grantee); `unbacked=0` all reserves; no stale-zero feed; market 2 empty; flash-loan/donation path inert; no wrong-price liquidation possible while paused (liquidation reverts).
- Chain liveness confirmed on both networks at start and end of session.

## Evidence index

| File | Content |
|---|---|
| `sceptre_state_block71772220.json` | Sceptre live reads at Flare block 71,772,220 (raw JSON-RPC results) |
| `sceptre_roles_block71775945.json` | Full role enumeration + EOA/contract classification (40 holders) |
| `sceptre_withdraws_events.json` | `Withdraw(address,uint256)` events (top warden custody withdrawals) |
| `sceptre_stakedflr_source.sol` | StakedFlr verified implementation source (solc 0.6.12) |
| `more_state_block81310662.json` | MORE both markets: reserves, configs, reserveData, oracle prices/sources, ACL checks |
| `more_health_block81310662.json` | `getUserAccountData` for top debt holders |
| `more_debt_holders.json` | Variable-debt-token holders per reserve |
| `more_wflow_suppliers.json` | aWFLOW holders (withdraw simulation caller source) |
| `../ci/steps/flare_sceptre_more_enum.py` | Re-runnable enumeration script (public RPCs only) |

Pinned blocks: Sceptre state 71,772,220 / roles 71,775,945; MORE snapshot 81,310,662; final liveness Flare 71,779,062, Flow 81,320,327. USD prices: DefiLlama `coins.llama.fi` (FLR $0.007022478, FLOW $0.0318676) + GeckoTerminal (ankrFLOW $0.02774–0.02828).
