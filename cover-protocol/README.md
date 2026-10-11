# Cover Protocol (legacy coverage, post-2020 exploit) — live-state assessment & extractable-value determination

**Campaign:** zombie-hunt II (L2 Phase 2) · **Chain:** Ethereum mainnet · **Date of work:** 2026-10-11
**Status:** read-only research; all PoC/boundary tests verified on a mainnet fork in CI; **no mainnet transactions sent**.
**State block:** `26,171,719` (2026-10-11). Prices at the same time: DAI $1.000072 (DefiLlama), yDAI priced at its on-chain `getPricePerFullShare()` 1.143253938 × DAI.

**TL;DR — an external, unprivileged attacker can extract ≈ $0 from Cover Protocol today.** The entire
$508,851.21 of live cover collateral is a **bearer entitlement** of the outstanding CLAIM/NOCLAIM covTokens:
it pays out only to token holders (H-O, $505,620.38 net of the 0.1% redemption fee), and every path that
could take it *without* the tokens — mint, redeem-without-tokens, collateral redeem on expired covers,
claim acceptance, proxy upgrade, router sweep — is gated (fork-proven, 25/25 tests). $2,724.70 is genuinely
stuck (orphaned LP stakes in Cover's own reward contracts + dust in small third-party contracts). The only
non-holder control is the Cover dev Safe's proxy-admin power over all 55 cover proxies (privileged, P).

| # | Surface | Live extractable (E-U) | Why closed / open | Latent risk |
|---|---|---|---|---|
| 1 | 55 cover contracts holding DAI/yDAI (54 with live state) | **$0** | Collateral balance == redeemable entitlement of outstanding covTokens, cover-by-cover, exactly (≤1e6 wei). `mint` is `onlyOwner`+not-expired; all covers expired 2021 | Dev Safe can upgrade any cover proxy (P) |
| 2 | Coverage claim path (`ClaimManagement`/`enactClaim`) | **$0** | Filing is permissionless but decision is auditor/governance-gated; window-passed → denied. Even a fully-colluding claimManager cannot pay CLAIM on expired covers (incident today > 2021 expiry → `redeemClaim` reverts; NOCLAIM still gets its own 1:1) | Live auditor Safe (4/13) could accept a *new* round's claim — pays NOCLAIM holders only |
| 3 | Cover redemption (`redeemClaim`/`redeemNoclaim`/`redeemCollateral`) | **$0** | Pays only `balanceOf(msg.sender)`; `redeemCollateral` is not-expired-gated; round-trips ≤ deposit | None |
| 4 | Balancer BPools (92) holding 78% of the covTokens | **$0** | Pools finalized+public; swaps priced on a 49:1 curve above par (buy+redeem is a loss, fork-tested); exits are for BPT holders only | If BPT/claims ever trade < par, buyers arbitrage *sellers*, not the protocol |
| 5 | CoverRouter (2 deployments) | **$0** | Zero residual balances; `removeLiquidity` requires caller BPT; `rollover` dead (no future active timestamps) | None |
| 6 | Blacksmith / BonusRewards staking | **$0** | Per-user `withdraw`/`emergencyWithdraw`; `collectDust` blocked for pool tokens | Orphaned BPT ($2.7k) is stuck (S) |
| 7 | COVER token mint paths (Blacksmith, Migrator/SAFE2) | **$0** | Old Blacksmith minting rights moved to a new Blacksmith (0x1D5f…): `withdraw`/`claimRewards` revert, only `emergencyWithdraw` works. SAFE2→COVER `migrateSafe2` is live but SAFE2's only venue holds 0.033 SAFE2 + $0.02 WETH | COVER DEX depth ~$4.0k; emissions unclaimable |
| 8 | CoverFeeReceiver | **$0** | `collect`/`buyBack` `onlyOwner` (dev Safe). Holds $630.46 (601.04 DAI + 25.69 yDAI) | P |

**Total live extractable now: $0** (confidence: high; fork-verified).
**Holder-recoverable (H-O): $506,126.50 gross / $505,620.38 net** (direct holders $110,018.73 + live stakers $386,411.10 + other BPT holders $9,696.68).
**Stuck (S): $2,724.70.** **Privileged (P): the full $508,851.21 via cover-proxy upgrade + $630.46 fee receiver.**

---

## 1. Scope & target enumeration (exhaustive)

Target set = the DefiLlama `cover-protocol` adapter's custody plus everything reachable from it. Enumeration
was done from primitives, not lists:

1. **`ProtocolFactory` `0xedfC81Bf63527337cD2193925f9C0cF2D537AccA`** (`getAllProtocolAddresses()`) → **39 protocols**;
   each `getProtocolDetails()` → **55 Cover proxies** (54 with non-zero state). This is the canonical v1.1 factory
   (CoverProtocol/cover-core-v1 README) and the one DefiLlama counts.
2. Per cover: `getCoverDetails()` (name, expiry, collateral, claimNonce, CLAIM/NOCLAIM token addresses),
   collateral `balanceOf`, covToken `totalSupply`, proxy admin/impl EIP-1967 slots.
3. **All covToken holders** (55 NOCLAIM + 55 CLAIM tokens, 107 live tokens) via GoldRush `token_holders_v2`
   (sums reconcile to supply exactly for every token).
4. **All 92 Balancer V1 BPools** holding covTokens: `isFinalized`/`isPublicSwap`/controller/tokens/balances,
   BPT holders, and the controllers (**CoverRouter** ×2, **DSProxies**, zero-address).
5. **Staking venues**: `Blacksmith 0xE0B94a7B…` (81 pools) and `BonusRewards 0x8fC8551d…` (36 pools) — every
   depositor enumerated from BPT `Transfer` logs (Etherscan) and their live records read (`miners`/`getUser`).
6. **Protocol roles**: factory owner/governance/treasury/claimManager, `ClaimManagement` (auditor, fees),
   `CoverFeeReceiver`, the new Blacksmith `0x1D5f…`, `Migrator`, both COVER tokens, SAFE2.
7. Exhaustive checks that nothing else carries value: factory, implementations, routers, ClaimManagement,
   treasuries, and every protocol/cover proxy balance (ETH + DAI + yDAI + USDC + WETH + both COVER tokens).

State dumps: `analysis/state.json` (block 26,171,719), `analysis/pools.json`, `analysis/holders_classified.json`,
`analysis/pool_reconcile.json`, `analysis/staker_enum.json`, `analysis/final_numbers.json`,
`ci-out/cover_state.{json,txt}` (CI artifact).

## 2. The mechanism in exact terms (deployed code)

Cover v1.1 (solc 0.7.3, verified source `analysis/source/` + `/tmp` fetch of Etherscan) works as follows:

- **Cover.sol** (`0xcB0900D9307Da7FD4e000A9093f24Ce25D937D42` impl behind per-cover proxies): holds the
  collateral; `mint()` is `onlyOwner` (= Protocol contract), `onlyNotExpired`, and blocked after a claim;
  `redeemClaim()/redeemNoclaim()` pay `balanceOf(msg.sender) × payout` (never anyone else's);
  `redeemCollateral(amount)` burns equal CLAIM+NOCLAIM from the caller, `onlyNotExpired`.
- **Protocol.sol**: `addCover()` moves the caller's own collateral and mints CLAIM+NOCLAIM 1:1;
  `enactClaim()` is `claimManager`-only; `setActive/updateCollateral/updateExpirationTimestamp` are dev-only.
- **ClaimManagement.sol**: `fileClaim`/`forceFileClaim` are permissionless (fee-paid) but only create claims;
  `validateClaim` is governance-only; `decideClaim` is auditor-only (auditor set) and **defaults to Denied
  once the 7-day window passes** — there is no auto-accept. Acceptance calls `Protocol.enactClaim`.
- **CoverRouter.sol** (`0x5b63C3C6…`/`0xe303f708…`): Balancer LP helper. `removeLiquidity` sweeps the router's
  *entire* token balances — but the routers hold **zero** (verified at the block), and callers need BPT.
  `rollover()` requires a future active expiry; every protocol's expiry list is 2021 → dead.
- **The accounting invariant (the reason E-U=$0):** for every cover, `collateralBalance == entitlement`, where
  entitlement = NOCLAIM supply (no claim) or `CLAIM×num/den + NOCLAIM×(den−num)/den` (claim rounds), exact to
  ≤1e6 wei. There is **no excess collateral** anywhere and no way to mint entitlement without depositing
  collateral. Three claim rounds exist: YEARN 36/100, PICKLE 100/100, BTFINANCE 60/100.

## 3. Live-state assessment (block 26,171,719)

**Roles (all verified on-chain):**

| Role | Address | Type |
|---|---|---|
| Factory owner (= admin of all 55 cover proxies) | `0x15957f0CA310d35b2E73fB5070Ce44A5B0141AB1` | Gnosis Safe, threshold 3/5, owners incl. the original dev EOA |
| Governance | `0xc698645B5C5b662B52a5A5C092804F23e3F5B4C5` | Gnosis Safe 3/6 |
| Claim auditor | `0x7eba9c735f8C1fe0670Be69edf61DbFbBB3C76e4` | Gnosis Safe 4/13 |
| ClaimManager | `0xd33F2e0173Fd0aE2A64B208A7BD16bcdc68bC862` | `ClaimManagement` (auditorVoting=true, fee DAI, balance 0) |
| Treasury | `0xe0632311772d362F49b5118c40d5251C44bC8b2E` | `CoverFeeReceiver` (holds 601.04 DAI + 25.69 yDAI) |
| Old factory owner (admin of first 10 protocol proxies) | `0xDd79dc5B781B14FF091686961ADc5d47E434f4B0` | EOA (dust balance) |
| New Blacksmith (holds COVER minting rights) | `0x1D5faB8A0E88020309e52B77B5C8eDF63c519A26` | `Blacksmith`-named proxy, 0 BPT of any pool |

**Collateral (exact wei):** DAI `332,464.224005` in 35 covers = **$332,488.16**; yDAI `154,253.000410` in 19
covers = **$176,363.05**; **gross $508,851.21**, **net of the 10/10,000 fee $508,342.36**. Top covers:
RAI 97,073.8 DAI · ORIGIN 95,174.6 yDAI · CDS_rcWETH 75,900.0 DAI · CREAM_2020 43,963.5 DAI ·
BTFINANCE_1 27,011 DAI · RULER 22,731.7 DAI · AAVE 14,193.1 DAI.

**Where the covTokens sit (weighted redeemable value):** 78.2% ($397,672) is inside the 92 Balancer pools;
21.8% ($111,179) is held directly by EOAs/EIP-7702 accounts. Of the pool-held value: **$386,411 is behind
live staker records** (BonusRewards/Blacksmith `miners`/`getUser` ≥ the BPT the contracts hold — e.g. one
staker holds 970,000 BPT of the RAI pool), **$9,697 behind other EOA BPT holders** (exitPool is public),
**$2,724 orphaned** (contract holds BPT, every depositor's record is 0; `collectDust` is blocked for pool
tokens → nobody can ever move it).

**yDAI backing (holder-recoverable):** vault `0x16de59092dAE5CcF4A1E6439D611fd0653f0Bd01` — PPS
1.143253938, totalSupply 341,568.16, assets 390,499.15 DAI held in dYdX Solo (per C-31's venue map; the
covers' 154,253 yDAI ≈ 45% of the vault). C-31 fork-proved yDAI withdrawals pay; supply has drifted down
~65 yDAI since C-31, i.e. redemptions still happen.

**Claim rounds:** YEARN (incident 1612396800 ≤ expiry; 36/100), PICKLE (100/100), BTFINANCE (60/100);
redeem delays long passed. Entitlements match balances exactly (see §2).

## 4. What an attacker can / cannot do

**Cannot (all fork-proven, see §5):**
1. `mint()` on any cover → `Ownable: caller is not the owner` (and all covers are expired anyway).
2. `redeemCollateral()` → `COVER: cover expired`; `addCover()` on any timestamp → `COVER: invalid expiration date`.
3. `redeemClaim()` without an accepted claim → `COVER: no claim accepted`; `redeemNoclaim()` without tokens →
   `COVER: low covToken balance`. Neither pays anyone but `msg.sender`.
4. File a claim and decide it yourself → `decideClaim` reverts `COVER_CM: !auditor`; `validateClaim` reverts
   `COVER_CC: !governance`; `enactClaim` reverts `COVER: caller not claimManager`. (Filing itself is
   permissionless but costs 50 DAI and goes nowhere without the auditor; the window defaults to Denied.)
5. Redirect expired covers' collateral via a malicious claim acceptance: `redeemClaim` reverts
   `COVER: cover expired before incident` (incident today > 2021 expiry), NOCLAIM still gets its own 1:1.
6. Upgrade/re-init any cover proxy → not admin / `require(_implementation() == address(0))`.
7. Buy NOCLAIM from the public Balancer pools and redeem at par → the 49:1 curve prices it above par;
   fork test buys 100 DAI worth and gets <100 DAI back after redeeming.
8. Sweep the CoverRouters → zero balances; `removeLiquidity` needs caller BPT (`insufficient BPT`).
9. Use `rollover()` to recycle covTokens → `new timestamp is not active` (no future expiry exists).
10. Take staked BPT or farm rewards from Blacksmith/BonusRewards → per-user records only; `collectDust` on a
    pool token reverts; the old Blacksmith cannot even mint COVER any more (minting rights moved), so its
    `withdraw`/`claimRewards` revert and only `emergencyWithdraw` works (the staker's own path).
11. Mint COVER via the Migrator → `migrateSafe2` is live but SAFE2's only venue holds 0.033 SAFE2 and
    $0.02 of WETH (dead); the Merkle `claim` list is fixed and capped.

**Can (unprivileged, but not protocol extraction):**
- Any covToken holder redeems their own collateral: NOCLAIM 1:1 (no claim) or the payout split; e.g. the
  YEARN NOCLAIM holder received 64% and the CLAIM holder 36%, each minus 0.1% to the treasury (fork-tested).
- BPT holders exit the public Balancer pools and redeem (fork-tested); stakers withdraw (BonusRewards) or
  `emergencyWithdraw` (Blacksmith) and then do the same.
- Anyone can **farm the Blacksmith's 654 COVER/week** — 31.5% of the weight sits in pools with zero stake —
  but the old Blacksmith's minting rights were moved to `0x1D5f…`, so those emissions cannot actually be
  minted. Even if they could, COVER's entire DEX depth is ~$4.0k (Uniswap pair 1,950 COVER + 0.128 WETH;
  Sushi pair 22,220 COVER + 1.456 WETH) — bounded, and it would come from COVER market LPs, not the covers.

## 5. PoC / fork verification

- **Project:** `poc/` (Foundry 0.8.24, vendored `forge-std`), tests in `poc/test/Cover.t.sol` — **25 tests**.
- **Fork:** pinned Ethereum block **26,171,719** (RPC: archive-capable keyed endpoint from CI env; never stored).
- **Result:** **25 passed / 0 failed** (local run; CI run URL in `summary.json`/`ci-log.txt`).
- Coverage of the suite: live state (39 protocols/55 covers, exact totals, roles, factory fees); exact
  accounting invariant for all 54 live covers; 10 negative E-U proofs (mint/redeem/addCover/claim/decide/
  validate/enact/upgrade/re-init/router-sweep/rollover/fee-receiver/dust); 6 positive H-O proofs (YEARN
  NOCLAIM 64% + CLAIM 36% payouts with fee check, BPT exit + redeem, BonusRewards withdraw, Blacksmith
  emergencyWithdraw + bricked `withdraw`); market-loss proof (pool buy+redeem < cost); malicious-acceptance
  proof (CLAIM can never be paid on expired covers); orphaned-BPT stuck proof.
- **Heavy job:** `ci/run.sh` re-dumps the full state at the pinned block → `ci-out/cover_state.{json,txt}`
  (artifact).

## 6. Verdict & residual / latent risk

**Verdict:** closed to unprivileged extraction — **E-U = $0**. $505,620 (net) is bearer-recoverable by
covToken holders (H-O); $2,725 is stuck (S). The only path to move cover collateral without the tokens is
the dev Safe's proxy-admin power (P): it can upgrade any of the 55 cover proxies and change the payout logic
in one transaction. This is a live 3/5 Gnosis Safe whose owners include the original dev EOA — the single
most important residual risk on this protocol.

**Latent risks (not E-U today):**
- **Proxy-admin capture (P):** the dev Safe can upgrade all covers; the old factory owner EOA still admins
  10 protocol proxies (but protocols hold no funds).
- **Auditor capture (P):** a live 4/13 auditor Safe can accept a claim for the *current* round of any
  protocol; for the expired covers this can only accelerate NOCLAIM holders' own 1:1 payout (incident > expiry).
- **Market arbitrage:** if any NOCLAIM/CLAIM or BPT re-trades below par, a buyer can redeem at par — value
  comes from the seller, not the protocol.
- **yDAI venue risk:** the covers' yDAI leg is only as good as the iEarn vault's dYdX Solo position
  (390,499 DAI backing 341,568 yDAI). If dYdX liquidity vanished, the yDAI leg (~$176k) would become S.

**Blockers / uncertainties:** H-O assumes holders/stakers still control their keys (not verifiable on-chain);
the S portion assumes the staking contracts' pool registrations are not changed (no owner function can free
them); USD is point-in-time (yDAI at on-chain PPS; DefiLlama's cross-check was $508,827).

## 7. Methodology & sources

- On-chain: batched `eth_call`/`eth_getStorageAt` at the pinned block (Nodereal), Etherscan V2 (sources,
  `getLogs` for staker enumeration), GoldRush `token_holders_v2` (covToken + BPT holders), DefiLlama prices.
- Sources of truth: `zombie_hunt/FINDINGS.md` (master row, `cover-protocol`), `l2-triage-a` row/evidence
  ($508,837, 55 covers), CoverProtocol/cover-core-v1 + cover-token-mining READMEs (canonical addresses),
  c-31 (iEarn yDAI venue map & withdraw proof).
- Corrections vs the corpus/triage: (a) the triage's "55 covers holding DAI+yDAI" is right but 78% of that
  value sits in Balancer pools/staking contracts, not directly in the covers; (b) the Blacksmith's regular
  `withdraw` is bricked (minting rights moved) — `emergencyWithdraw` is the live path; (c) the triage's
  yDAI price is confirmed on-chain (PPS 1.143253938).

**Caveats & limitations:** fork tests pin one block; holder/staker liveness is an assumption; the orphaned-BPT
classification relies on complete depositor enumeration via Transfer logs; gas/flash-loan costs are irrelevant
at $0.

## 8. Files index

```
cover-protocol/
├── README.md                      # this file
├── summary.json                   # machine-readable summary
├── analysis/
│   ├── enumerate.py               # factory→protocols→covers→balances at pinned block
│   ├── state.json                 # full live state (block 26,171,719)
│   ├── analyze_state.py           # accounting checks (bal vs entitlement)
│   ├── fetch_holders.py / holders_classified.json   # all covToken holders + classification
│   ├── analyze_pools.py / pools.json                # 92 BPools: composition/controller/BPT
│   ├── check_router_residuals.py / enumerate_stakers.py / staker_enum.json
│   ├── reconcile_pools.py / pool_reconcile.json     # BPT vs live records vs orphaned
│   ├── final_aggregate.py / final_numbers.json      # exact USD split by category
│   ├── identify_privileged.py / privileged_contracts.json / privileged_balances.json
│   ├── check_farm_rewards.py / blacksmith_pools.json / bonusrewards_pools.json
│   └── ... (identify_holders.py, probe_unverified.py, find_stakers.py, check_depositors.py)
├── poc/                           # Foundry project (forge-std vendored), test/Cover.t.sol (25 tests)
├── ci/run.sh + ci/dump_state.py   # CI heavy job → ci-out/cover_state.{json,txt}
├── ci-out/                        # CI artifact output
├── ci-log.txt / ci-artifacts/     # final CI run log + artifacts
```
