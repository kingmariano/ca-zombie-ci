# Augury Finance — live-state evidence (raw reads, keyless RPC)

All reads via `https://polygon-bor-rpc.publicnode.com` (keyless). Recorded 2026-10-12.
Primary block for balances: **95,394,160** (re-confirmed same values earlier at 95,383,542).
Fork PoC pins block **95,385,542**.

## Addresses (all Polygon, chain id 137)

| Role | Address | Notes |
|---|---|---|
| MasterAugur (MasterChef farm) | `0x6ad70613d14c34aa69e1604af91c39e0591a132e` | verified source `MasterAugur.sol`; not a proxy |
| OMEN token | `0x76e63a3E7Ba1e2E61D3DA86a87479f983dE89a7E` | owner == MasterAugur |
| AugurDividendsV1 (legacy) | `0xd5d5eDdC6D634a729EcEf53f710B4a3Cd61bc2B2` | created by MasterAugur (nonce 1) |
| DividendsV3 (current) | `0xf9dF350c1e9888452E4E7fd7A014503FA0eaB7e4` | `MasterAugur.dividends()` == V3 |
| AuguryStateRepositoryV1 | `0x8709278f89D6fB589f1188F6b415d3eDEe88a2F6` | owner == MasterAugur; lastCapturedEpoch 33 |
| SB0 AuguryStateBasedDividendsV1 (pid 0, OMEN) | `0xf6380D9b4CC3a0a180d5f1D78e3b7a33ec3048E3` | lastReadyPeriod 6 |
| SB1 AuguryStateBasedDividendsV1 (pid 1, OMEN-USDC) | `0x9E8eE4F17F17371d53e2fB19BDDE7a084215bb0E` | lastReadyPeriod 6 |
| SB17 AuguryStateBasedDividendsV1 (pid 17, OMEN-WETH) | `0x070aEf7a90bD7B4B3b43355C81c56011D5B2A238` | lastReadyPeriod 6 |
| SB18 AuguryStateBasedDividendsV1 (pid 18, OMEN-WMATIC) | `0x33c3834262903d6bCecB0Ba936fc65CAa4d11B26` | lastReadyPeriod 6 |
| Owner EOA (MasterAugur, SB contracts, repo) | `0x1eADf5caC8E5751D8420775875D30985D9390312` | EOA; operator of SB0/SB1; MasterAugur operator |
| Dev EOA | `0xE2E26BAc2ff37A7aE219EcEF74C5A1Bf95d5f854` | MasterAugur operator |
| Community wallet EOA | `0x57831E532fc14846511D3B8A86AA692528e06A9a` | received V1/V3 funding; SB communityWallet |

The four SB contracts have **byte-identical bytecode**
`keccak256(code) = 0x8847a444147dbbc6245921528d7935345c7864c2bd1325d47da54c90e5161138`
(verified 2026-10-12).

## USDC balances (block 95,394,160)

| Contract | USDC raw (6dp) | USDC |
|---|---|---|
| SB0 | 473,354,106 | 473.354106 |
| SB1 | 15,671,625,229 | 15,671.625229 |
| SB17 | 7,417,729,569 | 7,417.729569 |
| SB18 | 5,669,330,433 | 5,669.330433 |
| **SB total** | | **29,232.039337** |
| AugurDividendsV1 | 50,759,362,424 | 50,759.362424 |
| DividendsV3 | 695,557,794 | 695.557794 |

MasterAugur native balance 0; its value is in staked LP/ERC20 (see farm table below).

## Core mechanics (verified in deployed source)

- `MasterAugur`: standard MasterChef (Sushi fork). `omenPerBlock() == 0` → emissions off.
  `getMultiplier` mints 0; referral == 0x0, rate 0. `owner()` == 0x1EAD EOA, operators == {0x1EAD, dev}.
  19 pools; deposit fees all 0; no sweep/migrate/pause functions.
- `AugurDividendsV1`: `lastFundedEpoch == 2` (only epoch 2 funded, 2021-06-18);
  `lastClosedEpoch == 17`; funding 323,001 USDC in (June 18, 2021; txs `0x10023d86…` 1 USDC test +
  `0x8472c2df…` 323,000 USDC); 2,775 outgoing claims totalling **272,241.637576** USDC (last 2021-10-02);
  residue = 50,759.362424 USDC. `collectDividends()` requires stake history; `lastEpochClaimed` is set
  monotonically to `lastFundedEpoch` — no reset path → **no replay**. Registration path
  `setUserStakedAmount` is `onlyOwner` and MasterAugur (owner) now routes to V3 only → frozen.
- `DividendsV3`: 110,000 USDC funded (60,000 on 2021-07-30 tx `0xbf95965d…`; 50,000 on 2021-08-06
  tx `0xa44090be…`); ~38k txs; still claimed as of 2026-09-24; residue 695.557794 USDC.
- `AuguryStateRepositoryV1`: TVL snapshot registry. `setUserStakedAmount` is `onlyOwner` == MasterAugur;
  last interaction July 2021 (`pools(0).lastInteractedAt = 1626897212`); userAddresses len = **8,773**;
  writes frozen since July 2021.
- `AuguryStateBasedDividendsV1` (verified source, Polygonscan v0.6.12):
  - `collectDividends()` pays `calculateUnclaimedDividends(msg.sender)` = pro-rata share of prepared
    periods 1..lastReadyPeriod(=6) using repo snapshots, then sets `users[msg.sender].lastCollectedPeriod = lastReadyPeriod`.
  - **`collectDividendsToPeriod(uint256 _period)`** accepts ANY `_period` (only capped if `> lastReadyPeriod`),
    pays `calculateUnclaimedDividendsToPeriod(msg.sender, _period)` and sets `lastCollectedPeriod = _period`.
    Calling it with **0** resets the pointer without payment → the next `collectDividends()` recomputes and
    re-pays the identical entitlement. Unbounded repeat → one eligible address can drain the whole balance.
  - `calculateUserDistribution` = `distributable * userTvl / poolTvl` over immutable snapshots, so each
    replay pays exactly the same amount (`X`); the drain stops when balance < X (transfer reverts).
  - Eligibility requires `hasUserInteracted(user) == true` in the repo (frozen writes) → only pre-epoch-49
    (i.e., June–July 2021) stakers can claim. A fresh address computes 0 and receives nothing.
  - Operator sweep: `emergencyReturnCommunityFunds()` (onlyOperator; operators = {0x1EAD}) can push the
    whole balance to the community wallet (privileged).

## Wild exploitation (on-chain, Sept 2026) — the replay is not theoretical

Sept 2026 USDC outflows: **SB0 11,844.33 / SB1 10,053.99 / SB17 863.43 / SB18 157.23 ≈ $22,919**.

| Contract | Tx | Block | Date | Pattern |
|---|---|---|---|---|
| SB0 | `0xb8d76bf289728f50c7895ea24c315b2266ce0b6b98bcf9fef32718ebe4e9eb26` | 94,682,167 | 2026-09-30 | calldata = **30× `collectDividends()` + 30× `collectDividendsToPeriod(0)`** (selectors `0x458bdf20` / `0x74daa9c0`, arg 0). 30 identical USDC transfers of 0.218497 to `0x16f548b6…` |
| SB1 | `0x03dd72c14c667e781cf257ee8ae162a09b6f8eb7466ab2875f5b56d7c78e75a6` | 94,373,360 | 2026-09-24 | 39 identical USDC transfers of 210.340764 to `0x83b566c0…` in one tx (plus `0xd95ba3f5…` 210.340764) |
| SB17 | 5 txs: `0x8239048f…`, `0x85437154…`, `0xdb356734…`, `0x6133001a…`, `0xbca397b4…` | 94,374,084… | 2026-09-24 | 5 identical claims of 4.295287 by `0x923f39b6…` |
| SB18 | `0x4487cb79d22f3f525d045d7a0b798920fa9ac0b4e35bd44502ebdfb61a4b0126` | 94,373,382 | 2026-09-24 | 13.087287 to `0xbe9588…` (plus many single claims 2026-09-01) |

Top external extractor in Sept 2026: `0x83b566c0…` — SB0 9,250.35 + SB1 8,623.97 = **$17,874.32**
(via EIP-7702 delegated EOAs; `eth_getCode` = `0xef0100…`). The extraction chain uses several
7702-delegated EOAs (`0x2a965185…`, `0x83b566c0…`, `0xbe958864…`), i.e., at least two independent actors.

## MasterAugur farm valuation (DefiLlama prices 2026-10-12)

Pools: 0 OMEN · 1 UNI-V2 OMEN/USDC · 2 WPOL · 3 WBTC · 4 WETH · 5 QUICK · 6 FISH · 7 USDC ·
8 USDT0 · 9 DAI · 10 PolyDoge · 11 LINK · 12 AGA · 13 AGAr · 14 AGA c · 15 AGA cr · 16 SUSHI ·
17 SLP OMEN/WETH · 18 SLP WMATIC/OMEN.

| Token | Farm balance | USD |
|---|---|---|
| WBTC | 3.02234644 | $251,934.7 |
| UNI-V2 OMEN/USDC | 0.188982 (88.7% of pair; pair = 7,855.7 USDC + 10.27M OMEN) | $13,940 |
| USDC | 5,246.241037 | $5,244.7 |
| OMEN | 6,455,556.27 | $4,953.6 |
| USDT0 | 2,267.906677 | $2,265.7 |
| SLP OMEN/WETH | 750.6237 (63.2% of pair; pair = 2.43M OMEN + 0.7303 WETH) | $2,351 |
| WPOL | 11,243.66808 | $1,162.9 |
| WETH | 0.339492687 | $863.4 |
| DAI | 388.601809 | $388.7 |
| SLP WMATIC/OMEN | 11,216.4215 (39.6% of pair; pair = 3,380.6 POL + 455,892 OMEN) | $277 |
| LINK | 18.202101 | $244.3 |
| AGA | 4,675.9238 | $227.6 (GoldRush price) |
| QUICK/PolyDoge/SUSHI/FISH | — | $128.2 |
| **Total** | | **≈ $283,754** |

Cross-checks: DefiLlama "Augury Finance" TVL **$283,036**; GoldRush `balances_v2` for MasterAugur
**$267,122** (does not price OMEN/USDC + SLP LP tokens). Triage headline $265,830 (GoldRush subset) —
re-verified and confirmed as the farm custody value only; it excludes the dividend pots below.

Solvency structure: `farm_balance(token) = Σ user.amount + direct donations` (MasterChef invariant;
fees are 0 and LP leaves only via `withdraw`/`emergencyWithdraw` which decrement `user.amount`), so all
staked positions are withdrawable by their owners (H-O). Leftover/donations → stuck (S).

## Other surfaces checked (negative)

- `MasterAugur`: no `sweep`/`migrate`/`pause`; `updateEmissionRate`, `updateMaxSupply`,
  `setDevAddress`, `add`, `set`, `changeDividendsContract` all owner/operator-only. `massUpdatePools`
  and `updatePool` are permissionless but mint 0 while `omenPerBlock == 0`.
- OMEN token: `mint` onlyOwner == MasterAugur; only mint call sites are `updatePool` (0 mint) and
  `payReferralCommission` (referral == 0x0, rate 0). totalSupply 51,047,375.3 < maxSupply 777,777,777,
  but supply is final per Augury docs and emission is 0.
- V1 `distributeUnclaimedDividends(from,to)` is permissionless but always pays the *staked user*
  (pays `stakedUserAddresses[i]`), never the caller — no caller profit.
- No other Augury custody contracts found (web + GitBook + creator histories): no bonds/bridges/NFT
  custody; GitBook's four "Stake dividends" addresses are exactly SB0/SB1/SB17/SB18.
- Farm pools 12–15 (AGA/AGAr/AGAc/AGAcr) hold the corresponding tokens as user stakes; AGAr/AGAc/AGAcr
  are unpriced (no DefiLlama/GoldRush price) and presumed near-worthless.
