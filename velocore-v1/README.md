# Velocore V1 (zkSync Era) — zombie-hunt II, L2 RELATED row deep-dive

**Date:** 2026-10-13 · **Chain:** zkSync Era (chain id 324) · **Status:** read-only; all PoC runs on a
local `anvil-zksync` fork; **no mainnet transactions were sent**; no secrets in this folder.

**Watchlist row:** `Velocore V1` — zkSync Era, ~$131.9k live, "RELATED only — H-47 audited Velocore V2;
V1 flagged separate/unaudited".

---

## 1. TL;DR

| Target | Live extractable (unprivileged, fresh attacker) | Why open / closed | Latent risk |
|---|---|---|---|
| **Voter emission stream (VC)** — create pool + gauge, buy/lock VC, vote, `distribute`, stake, `getReward`, sell VC | **~$2,000 (range $1k–$8k)** — **OPEN, fork-proven** | `createPair`/`createGauge`/`distribute`/`getReward` are all permissionless; the only gate is voting weight, obtainable by buying VC (DEX liquidity ≈ $12.9k) and locking it. The Minter keeps minting **414,941 VC/week** to the Voter. | Weekly bleed continues while the Minter schedule runs; capped only by VC exit liquidity |
| **Voter's stranded VC balance — 67,837,833 VC** | **$0** (S — stuck) | All 46 gauges are `isAlive=false`; `_updateFor` silently skips dead gauges (supplyIndex := index, no accrual) so the accumulated balance can never be paid out. No rescue function; the Voter is not a proxy. Fork-verified. | Governor/emergencyCouncil could only kill/revive gauges (P) — revival does not restore the lost accrual |
| **Old gauge reward balances — 831,441 VC** | **$0** to a fresh attacker (H-O for historical stakers) | Reward periods ended 2023-09; `earned()` for any new staker is 0; rewards are only claimable by accounts staked during the period | Stakers who lost keys ⇒ stranded |
| **RewardsDistributor — 651,725 VC** | **$0** to a fresh attacker (H-O) | `claim(tokenId)` pays only the veNFT owner; a freshly-created veNFT claimed **0** on the fork (no retroactive accrual) | Abandoned veNFTs ⇒ stranded |
| **V1 pools (171 pairs, ≈$125k TVL)** | **$0** (no pool-level drain found) | Velodrome-V1/Solidly-v2-family pools; the June-2024 Velocore defect (`velocore__execute` + uncapped `feeMultiplier`/`fee1e9`) **does not exist in V1** (all selectors revert). `skim()` excess = $0; swaps take a fixed 0.25–0.5% fee routed to the owner EOA | Stable-pool rounding math not exhaustively fuzzed (low value at risk) |
| **V2 (June-2024 bug) on zkSync** | **$0** | V2 zkSync vault holds 0.000407 ETH; H-47 already found `fee1e9=0` on the pools | none live |
| **Governor privileges** (swap-fee stream, gauge kill/revive, whitelist, setters) | P — `0x1234561fEd41DD2D867a038bBdB857f291864225` (EOA) | privileged | owner key compromise would open the fee stream |

**Total live extractable now (E-U): ≈ $2,000** (range $1k–$8k), **confidence: high on mechanism / medium on USD**.
Everything else of value is either privileged (P), holder-only (H-O) or permanently stuck (S).

---

## 2. The June-2024 defect does **not** persist on V1

Velocore was exploited 2024-06-02 (~$6.8M) in its **V2** architecture (singleton Vault + diamond facets +
`ConstantProductPool` satellites). Root cause (OAK/Beosin, reproduced by H-47): missing `msg.sender == vault`
check on `velocore__execute`, uncapped `feeMultiplier`, and an `unchecked` fee subtraction that wraps when the
effective fee exceeds 100 % → a withdrawal is inverted into a huge token-out.

V1 on zkSync is a **different codebase** (Solidly-v2/Velodrome-V1 family: pools hold their own tokens, factory
`allPairs`, Voter/Minter/Gauge/Bribe system). Probed on the live V1 pools (block 72,470,026):

| Selector | Function | Result on V1 pools |
|---|---|---|
| `0xec378808` | `velocore__execute` | **revert** (absent) |
| `0x48313a81` | `fee1e9()` | **revert** (absent) |
| `0xe5a70ef7` | `feeMultiplier()` | **revert** (absent) |
| `0x9c77ac51` | `lastWithdrawTimestamp()` | **revert** (absent) |
| `0x0902f1ac` | `getReserves()` | OK |
| `0x392f37e9` | `metadata()` | OK (Solidly layout) |

So the specific H-47 exploit class is closed on V1. The V2 zkSync deployment (factory
`0xf55150000aac457eCC88b34dA9291e3F6E7DB165`, vault `0xf5E67261CB357eDb6C7719fEFAFaaB280cB5E2A6`) holds only
**0.000407 ETH** and no tokens at block 72,471,542 — even a resurrected V2 bug has nothing to take.

---

## 3. Live extractable path (E-U): capture the emission stream with a permissionless gauge

### 3.1 Mechanism

The Minter (`0x8f0b4B3e…`) mints a decaying weekly emission (`weekly()` = **419,132.5 VC** at block 72,471,542).
On `update_period()` (callable by anyone) it mints, pays a fee to the governor EOA (~17,290 VC) and a small
amount to the RewardsDistributor, then notifies the **Voter** (`0xe09A60FA…`) with **414,941 VC** — confirmed by
tracing the live call (`debug_traceCall`) and by the fork balance delta.

The Voter pays a gauge `weights[pool] / totalWeight × (index delta)` through `distribute(gauge)` — **but only if
the gauge is alive**. All 46 legacy gauges are `isAlive = false`, so the entire 67.8M VC balance that has
accumulated in the Voter is unreachable (see §5). The live, open path is:

1. `PairFactory.createPair(tokenA, tokenB, stable)` — **permissionless** for whitelisted tokens
   (whitelist at block 72,471,542: VC, WETH, USDC.e, USD+, ZKDOGE). No existing pool with both tokens
   whitelisted lacks a gauge, so the attacker creates a *new* pair (e.g. USDC/ZKDOGE — succeeded on the fork).
2. `Voter.createGauge(newPool)` — **permissionless** for factory pools with whitelisted tokens (`exists` and
   `!_pool`/`!whitelisted` are the only gates). The new gauge is **alive**.
3. Acquire VC on the DEX (VC/WETH pool ≈ 2.4 WETH / 5.45M VC; VC/USDC pool ≈ $1.8k) and
   `VotingEscrow.create_lock(amount, duration ≤ 4 y)` → veNFT.
4. `Voter.vote(tokenId, [newPool], [balanceOfNFT])` — one vote per epoch per veNFT.
5. `Voter.distribute([newGauge])` — **permissionless**; mints the weekly emission and pays the gauge
   `weights[pool]/totalWeight × notified`.
6. Add any amount of liquidity to the new pool → `Gauge.deposit(lp, tokenId)` → after vesting
   `Gauge.getReward(attacker, [VC])` pays the VC.
7. Sell VC into the shallow pools for WETH/USDC.

### 3.2 Fork proof (anvil-zksync, fork of zkSync Era mainnet, block 72,471,480)

```
T2 (fresh fork, attacker = fresh account, capital simulated via fork cheat):
  createPair(USDC, ZKDOGE, false)            -> ok    new pool 0x539903F38dE34486fe73B6E60E01b2802b3154b4
  createGauge(newPool)                       -> ok    new gauge 0x6dEe156b89e243a182841db7aCC300862a8C1532 (isAlive=true)
  create_lock(5,000,000 VC, 125,000,000 s)   -> ok    veNFT #10042
  vote(10042, [newPool], [4.94e24])          -> ok    attacker weight 4,942,410.7 veVC / totalWeight 9,508,243.5 (52%)
  distribute([newGauge])                     -> ok    index +4.36e16 ; gauge received 215,687.57 VC
  mint LP + deposit(LP, 10042)               -> ok    staked 499,999,999,999,000 LP
  anvil_increaseTime(3 days) + getReward     -> ok    attacker received 92,438.60 VC
T1 (fresh fork, legacy gauge):
  distribute([legacy USDC/WETH gauge])       -> ok    gauge received 0 VC ; Voter +414,941.22 VC
T3:
  skim(biggest pool)                         -> ok    pool USDC balance == reserve0 ⇒ excess 0
```

### 3.3 Economics (why the headline is low-thousands, not the $75k notional)

* Attacker's share = `x / (4,565,832 + x)` where `x` = VC locked. The existing 4.57M veVC weight is
  abandoned but still counts.
* `x = 1,000,000 VC` costs ≈ 0.54 WETH (~$1.35k) to buy (pool 2.4 WETH / 5.45M VC) → share ≈ 18 % →
  ≈ 74.5k VC/week ≈ $82/week at the $0.001106 spot.
* The **only exit** is the DEX: VC/WETH pool holds 2.4003 WETH (~$6.0k), VC/USDC pool ~0.39 WETH + $796,
  SpaceFi ~$18. Total DEX liquidity ≈ **$12.9k**, of which the hard-asset side a seller can take is
  ≈ **$7.8k**.
* Therefore the maximum net extraction (sell all captured emissions until the pools' WETH is gone) is
  ≈ **$1k–$8k**, realistically ~$2k for an optimally-sized attack; the locked VC is recoverable after the
  4-year lock (or by selling the veNFT at a discount).
* The bleed continues each week until the Minter schedule ends or governance intervenes — but the
  *realizable* amount stays bounded by the exit liquidity.

### 3.4 Preconditions / gates (explicit)

| Step | Gate | Live value |
|---|---|---|
| createPair | `tokenA`/`tokenB` in whitelist (for non-governor) | VC, WETH, USDC.e, USD+, ZKDOGE whitelisted |
| createGauge | `gauges[pool]==0`, `isPair(pool)`, both tokens whitelisted | attacker's new pool passes |
| vote | `isApprovedOrOwner(veNFT)`, one vote/epoch, gauge exists | attacker's own veNFT |
| distribute | permissionless; requires `isAlive[gauge]` | new gauge is alive |
| getReward | `msg.sender == account` (or voter) | attacker claims for self |
| exit | DEX depth | ≈ $7.8k hard-asset side |

---

## 4. Live-state assessment (block 72,471,542, 2026-10-13)

Full JSON: `analysis/live_state_final.json`; pool census: `analysis/pairs_priced.json`; gauges:
`analysis/gauges.json`; system contracts: `analysis/system_contracts.json`.

**Factories / pools**
| Item | Value |
|---|---|
| PairFactory (official) `0xE140EaC2bB748c8F456719a457F26636617Bb0E9` | 167 pairs, `owner()` = `0x1234561fEd41DD2D867a038bBdB857f291864225`, `getFee(bool)` = 50 (0.5 %) |
| PairFactory (old POAP) `0xF5719b1Ea3C9bF6491E22C49379E31060d0FbFc1` | 4 pairs, no `owner()` |
| Pools enumerated | 171 (166 non-empty); total reserves ≈ **$125.3k** (DefiLlama reports $126.3k) |
| Largest pools | F2 USDC.e/WETH `0xcD52…997Df` 26,772.40 USDC + 10.6819 WETH ≈ $53.5k · F1 USDC.e/old-WETH `0xA203…C3fA` 20,462.95 USDC + 8.1515 oldWETH ≈ $40.9k |
| Pool code | 2 identical implementation groups (167 F2 pools share one code hash; 4 F1 pools another); source unverified, behaviour matches Solidly-v2/Velodrome-V1 family |
| Fee flow | every swap sends 0.5 % of the input (F2) / 0.25 % (F1) directly to the owner EOA `0x1234561fEd…`; pool `balanceOf == reserve` |
| `skim()` excess | only one pool (`0x3f5e…8841` keyVC/LIBERA) has 4.18e-9 LIBERA ≈ $0 |

**System contracts**
| Contract | Address | Live state |
|---|---|---|
| VC token | `0x85D84c774CF8e9fF85342684b0E795Df72A24908` | totalSupply 161,523,633.7 VC; `minter()` = Minter |
| Voter | `0xe09A60FAe6d77658b9767A70e2f361b46Dd3f16A` | **67,837,832.79 VC balance**; 46 gauges, all `isAlive=false`; `totalWeight` 4,565,832.7 veVC; `governor`/`emergencyCouncil` = `0x1234561fEd…` (EOA); not a proxy (EIP-1967 slots empty); no rescue functions |
| VotingEscrow | `0xbdE345771Eb0c6adEBc54F41A169ff6311fE096F` | 39,677,494.5 VC locked (veNFTs), `token()` = VC, MAXTIME 4 years |
| RewardsDistributor | `0xD7107a47B4fBBc585b25BbEe3777B2EDC11D156C` | 651,725.0 VC; `claim(tokenId)` pays the veNFT owner only (fresh veNFT claim = 0 on fork) |
| Minter | `0x8f0b4B3e211c84061ab5959Bd3D49C6B3EeC1d7D` | `weekly()` 419,132.5 VC; `active_period` 2025-09-04 (stale — anyone can advance it) |
| Legacy gauges | e.g. `0xb3120Ad6C3285fc4E422581d9ad003277802CC47` | hold 831,441 VC total (reward periods ended 2023-09) |
| F1 fee vault | `0x03dc61793565b6073496fb0e24770c7e41b97edc` | empty (0 USDC / 0 oldWETH) |
| V2 vault (zkSync) | `0xf5E67261CB357eDb6C7719fEFAFaaB280cB5E2A6` | 0.000407 ETH, no tokens |
| VC market | VC/WETH `0x80aB452b…` ($12.06k liq), VC/USDC `0xF746D0be…` ($796), SpaceFi ($18) | price $0.001106 |

---

## 5. What an attacker can / cannot do

**Can (E-U):** as §3 — capture up to `x/(4.57M+x)` of each weekly 414,941 VC mint, realize ≈ $1k–$8k
through the DEX, keep the locked VC recoverable.

**Cannot:**
* Touch the Voter's 67.8M VC (S): all gauges dead; `_updateFor` sets `supplyIndex := index` without accrual
  (fork-verified with and without votes); new gauges start at the current index → no retroactive capture
  (fork-verified: new gauge received only the fresh mint's share). No rescue/sweep; not a proxy.
* Claim legacy gauge rewards (831k VC) or RewardsDistributor funds (652k VC) without being the historical
  staker / veNFT owner.
* Reproduce the June-2024 V2 defect on V1 (selectors absent) — nor is there value left in V2-on-zkSync.
* Extract anything from the pools beyond normal LP/swap flows: `skim()` excess is $0, `balanceOf == reserve`,
  and swaps route a fixed fee to the owner EOA.

**Privileged (P):** governor/emergencyCouncil EOA `0x1234561fEd…` can `killGauge`/`reviveGauge`,
`setGovernor`, `setEmergencyCouncil`, whitelist tokens, and receives the swap-fee stream (0.5 %/0.25 % of
every swap). Note: even the governor cannot recover the Voter's stranded 67.8M VC (no such function; revival
does not restore destroyed accrual).

**Holder-only (H-O):** LP positions in the 171 pools (≈$125k), locked veVC (39.7M VC), historical gauge
rewards, RewardsDistributor claims.

---

## 6. Verdict and residual risk

* **Headline E-U ≈ $2,000** (range $1k–$8k), confidence **medium** on the USD figure (depends on how much VC
  the attacker buys and how much the shallow pools can absorb) and **high** on the mechanism (full chain
  fork-proven end-to-end).
* **S ≈ $75k notional** (67.84M VC) permanently stranded in the Voter + ~$0.9k in dead gauges.
* **Residual/latent:** the weekly 414,941 VC mint continues; each week the attacker can re-capture their share.
  If VC ever gains external liquidity, the realizable amount rises with it. If governance (EOA) revives a
  legacy gauge, the revived gauge still cannot recover past accrual (supplyIndex == index), so the 67.8M VC
  stays stranded.
* **Blockers:** the attacker needs VC capital (the pool is small); the 4-year lock ties up capital; exit is
  capped by ~$7.8k of hard assets in the VC pools.

---

## 7. Methodology & sources

* Chain access: keyless public zkSync Era RPC (`https://mainnet.era.zksync.io`); reads pinned to explicit
  blocks (72,470,026 pool census; 72,471,542 final snapshot).
* Source discovery: Velocore docs (`docs.velocore.xyz` V1 zkSyncEra page — factories/Voter/Minter/etc.),
  DefiLlama adapters (`velocore/index.js`, `velocore-v2/index.js`), Beefy/DappRadar configs (router/factory),
  sanbir/evm-hack-registry Velocore V2 exploit write-up (root cause), OAK/Rekt post-mortems.
* ABI discovery: selector probing against live contracts (Solidly/Velodrome-V1 family), raw storage reads
  (Voter slot 18 = `index`; keccak(gauge,19) = `supplyIndex`), Blockscout (`zksync.blockscout.com`) for
  balances/transfers/holders, `debug_traceCall` for the live `distribute` call.
* Fork PoC: `anvil-zksync` v0.7.1 forking zkSync Era mainnet, driven by `ci/run.sh` + `ci/fork_test.py`
  (T1/T2/T3). All transactions are local to the fork; the fork cheats (storage write for VC, impersonation
  for token funding) only simulate an attacker's capital, which is standard for fork PoCs.
* CI: GitHub Actions run on the public `kingmariano/ca-zombie-ci` repo (branch `velocore-v1`) — URL in §8.

### Caveats
* The V1 pool/gauges/Voter sources are **unverified**; behaviour was established by probing + fork execution,
  not by reading Solidity. The exact internal reason `_updateFor` skips accrual for dead gauges (isAlive
  short-circuit vs. mis-keyed weights) is not distinguishable without source, but the outcome — no payout —
  is directly proven for both an existing dead gauge and a fresh alive gauge.
* USD figures use DefiLlama/DexScreener prices at 2026-10-13 ($ETH 2,507.33, VC $0.001106) and are notional
  for illiquid VC.
* The stable-pool rounding math (54 stable pools, ≈$5k) was not fuzzed; the volatile pools hold the value
  (~$110k) and their behaviour was spot-checked (`skim`, reserves/balances, fee routing).

---

## 8. PoC / fork verification

| Item | Value |
|---|---|
| Driver | `ci/fork_test.py` (T1 legacy-gauge distribute, T2 full attack chain, T3 skim) |
| Runner | `ci/run.sh` (downloads anvil-zksync v0.7.1, forks mainnet with the keyless public RPC, runs the three tests on fresh forks) |
| Local results | `ci-out/fork-results.json`, `ci-out/fork-run.log` |
| CI run | see `ci-log.txt` / `ci-artifacts/` (URL recorded in `summary.json`) |
| Key numbers | T1: legacy gauge +0 VC (Voter +414,941.22 VC) · T2: gauge +215,687.57 VC, attacker claim 92,438.60 VC · T3: excess 0 |

## 9. Files index

```
velocore-v1/
├── README.md                     # this report
├── summary.json                  # machine-readable summary
├── analysis/
│   ├── enumerate.py              # census of all 171 pairs from both factories
│   ├── analyze_pools.py          # code groups, stable flags, balances vs reserves (skim excess)
│   ├── fix_meta.py               # token/pool metadata decode
│   ├── price_pools.py            # USD pricing of every pool
│   ├── system_contracts.py/.json # system contract census (code, VC balances)
│   ├── probe_abi.py / probe_abi2.py / probe_mint_gates.py / probe_voter.py   # selector/behaviour probes
│   ├── gauges_scan.py + gauges.json          # all 46 gauges: weights, claimables, balances, state
│   ├── final_snapshot.py + live_state_final.json  # final pinned-block snapshot
│   ├── pairs_raw.json / pairs_deep.json / pairs_priced.json   # pool census data
│   └── fork_test_*.sh / manual_t2.sh          # early manual fork experiments (superseded by ci/)
├── ci/
│   ├── run.sh                    # CI job: anvil-zksync fork + T1/T2/T3
│   └── fork_test.py              # fork test driver
└── ci-out/
    ├── fork-results.json         # fork evidence (from local + CI runs)
    └── fork-run.log
```
