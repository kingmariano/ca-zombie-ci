# AutoShark (BSC) — zombie-hunt L2 Phase 2 deep-dive

**Date:** 2026-10-13 · **Chains:** BSC (56) · **Status:** read-only; PoC fork-verified only; **no mainnet transactions**.
**Finding row:** L2-Triage-A #32 AutoShark — "LIVE-FUNDED $146,818" (finsFactory 194 pairs + jawsPool).
**Question:** how much can an **external, unprivileged attacker** (no team keys, no legacy positions, no whitelist) extract **live, right now**?

---

## 1. TL;DR

| Target | Live value (priced legs) | Extractable by fresh attacker (E-U) | Why closed / open | Latent risk |
|---|---|---|---|---|
| finsFactory DEX — 194 FinsPair LP pools | **$147,077** | **$0.00** | All LP is owned by third parties (H-O): EOAs, or staked in MasterOcean/MasterSquid. Pair accounting is standard Pancake-v2; balances == reserves on all value pairs; skim yields only unpriced zombie-token dust | none new |
| feeTo FeeDistributor `0x593CC3…` (protocol fees as LP) | $260 | $0.00 | `distribute`/`distributeSingle`/`burn` are **keeper/owner-gated** (decompiled impl `0xe1f153c3`); owner/keeper are team EOAs | upgradeable proxy (admin EOA holds upgrade right) |
| Squid fee vault `0xe0B4Add5…` (deposit-fee LP) | $15,217 | $0.00 | same gated FeeDistributor class (impl `0x45948ce5`); `withdrawBEP20` owner-only | upgradeable proxy (admin EOA) |
| MasterOcean farm (FINS era, 47 pools) `0x8857af82…` | $43,188 staked LP | $0.00 | standard MasterChef accounting; deposit/withdraw exact per user; **FINS emissions dead** (cap 500M reached, farm balance 0) | none material |
| MasterSquid farm (16 pools) `0x86a47ddd…` | $12,538 staked LP | $0.00 | standard MasterChef; deposit/withdraw/emergencyWithdraw all work for a fresh user (fork-verified); NFT boost is inert (`controller == address(0)` → `getBoost` returns 0); SQUID farm balance is 80,902 **wei** (≈$0); `massUpdatePools()` and pid-0 (SQUID single-stake) are bricked (SafeMath underflow) | latent: pid-15 takes ~100% of emissions but its stake token SQUIDY is team-held & unobtainable; SQUID exit liquidity ≈ $890 |
| jawsPool `0x5D2112Ba…` (JAWS staking) | $0 | $0.00 | 69.8M "shares" outstanding but **0 JAWS / 0 LP backing in the contract**; JAWS itself is ~$0 (only $105 WBNB in its one pair) | accounting-only wreck |
| Launchpad/IFO `0xa9f48fee…` | $479 LP | $0.00 | 2021 IFO: 751/753 participants already harvested; harvest pays the offering token (ATLAS, unpriced), not the LP; the 3,354 LP left in the contract is admin-only via `finalWithdraw` | none (P) |
| v1-era (SHARK): SharkPool `0x5F7de53f`, Zap, Panther vault, sharkChef | $0 | $0.00 | all empty; SHARK token holds $0.08 dust | none |
| SHARK/WBNB PantherPair `0x1fd789Fa` | $1,577 (pair reserves) | $0.00 | not AutoShark custody — LP held by EOAs; pair is a PantherSwap pair | none |

**Total live extractable now (E-U): $0.00 — confidence high** (≈$147,077 of live value exists, but it belongs to holders/team and every payout path we found is either self-service (holder), role-gated, or empty).

---

## 2. The protocol, exactly as deployed

AutoShark's **live** footprint on BSC (all verified at pinned block **127,400,000** unless noted):

* **DEX (FINS era, Sep-2021):** `FinsFactory 0xe759Dd4B9f99392Be64f1050a6A8018f73B53a13` (194 pairs, verified source `contracts/FinsFactory.sol`, solc 0.5.16) — a PancakeSwap-v2 fork; `FinsPair` verified (`contracts/FinsPair.sol`). `feeTo = 0x593CC303170367FCB249abdd08Aaaa736d552BA5`, `feeToSetter = 0xD9ebB6d95f3D8f3Da0b922bB05E0E79501C13554` (team EOA).
* **feeTo = FeeDistributor proxy** (`TransparentUpgradeableProxy`, impl `0xe1f153c3050a0b5f1bf1575454f28a6b894582eb`, unverified → decompiled). Functions: `distribute(address[])`, `distributeSingle(address[])`, `burn(address[])` (all `require(msg.sender == keeper || owner, "caller is not the keeper or owner")`); `setRouter`, `withdrawBEP20`, `transferOwnership`, `renounceOwnership` (owner-only). Live: owner `0xD9ebB6d9…`, keeper `0xa3B330220e7ae7C1616182C5a84Ba752b9d5b8cB`, router `0xB0EeB0632bAB15F120735e5838908378936bd484`. Holds 117 LP positions (fees accrued), $260 total.
* **MasterOcean 0x8857af8205f224870dea119e2c75af386efb192a** — 47-pool MasterChef ("fins" farm, NFT-boost variant). `owner = 0xD9ebB6d9…`, `fins = FINS 0x1b219Aca…`, `finsPerBlock = 21e18`, `totalAllocPoint = 8831`, `feeAddress = 0xD9ebB6d9…`. Live `FINS.balanceOf(farm) = 0`; FINS totalSupply 499,999,997.1 of 500,000,000 max ⇒ **no more FINS can ever be minted** (the cap silently defeats `mint`).
* **MasterSquid 0x86a47ddd4c6522251d6a5a5800f3f24c03332cb4** — 16-pool MasterChef ("squid" farm). `owner = 0xbf00B8b5C5D8694BB5E85e61518c4C3032122457`, `squid = 0xAE61e7dc989718E700C046a2483e93513eDCA484`, `squidPerBlock = 20e18`, `feeAddress = 0xe0B4Add5…` (the fee-vault proxy), `controller() == address(0)` (NFT boost inert — `getBoost` returns 0, live-verified). SQUID farm balance = 80,902 wei; `massUpdatePools()` reverts (`SafeMath: subtraction overflow`: pid-0 computes `balanceOf(farm) - squidStaked` = 80,902 - 1.7996e24); `updatePool(pid)` works per-pid for pid>0. pid-0 stakers' recorded **1,799,636 SQUID claims are unbacked** (paid out as rewards over time) and unrecoverable (S, ≈$130 at the pair-implied price).
* **Squid fee vault 0xe0B4Add509BAB9d04cA92541272C87CDB822FA32** — same FeeDistributor class (impl `0x45948ce5…`, decompiled): owner `0xbf00B8b5…`, keeper `0xc41E861Ec9EDC879Ef27958e2f7745f96862e60d`. `distributeSingle` pays swapped proceeds to `0x91d6136a…` (team fee EOA) and owner.
* **jawsPool 0x5D2112Ba0969EC66012380C1fb88F2A3D182Eb90** — proxy (impl `0x73f76d34…`): Synthetix-style JAWS staking (stakingToken = JAWS, rewardsToken = WBNB/JAWS LP `0x1BbA5C6C…`). Live: `totalSupply = 69,837,390.478` share-units (raw 6.9837e25), **JAWS balance = 0**, LP balance = 0, BNB = 0, `paused = false`, rewards ended `periodFinish = 1,705,683,967`. Owner `0xD9ebB6d9…`.
* **Launchpad/IFO 0xa9f48fee822530037628fcbbe2d7724221b1536d** (proxy, impl `0x2a5d80b7…`): raising token = FINS/WBNB LP, offering token = ATLAS `0xcf87Ccf9…`; `raisingAmount = 59,701 LP`, `totalAmount = 408,934 LP`, `allowClaim = true`, admin `0xD9ebB6d9…`. 753 depositors in 2021; checked all: **751 already flagged `hasHarvest`, 2 can still claim** (tiny ATLAS allocations, ≈$0). Contract still holds 3,354.1 LP (~$479) = raising proceeds, admin-withdrawable only (`finalWithdraw`).
* **Tokens:** FINS `0x1b219Aca…` (owner `0x0ff4436a…`), SQUID `0xAE61e7dc…` (owner `0x25BB7952…`), JAWS `0xdd97ab35…` (owner `0x342afF01…`). All `mint` functions are `onlyOwner` / `onlyMinter` (MasterOcean resp. MasterSquid are the only isMinters).
* **v1 (SHARK era):** SharkToken `0xf7321385…` (dust), SHARK Pool `0x5F7de53f…` ($0), Zap `0xA96CeA60…` ($0), Panther vault `0x9e7aEbAE…` ($0), sharkChef `0x115BebB4…` ($0), helper `0xBd17385A…` ($0), NFTController proxy `0xc404446f…` (impl `0x595ec111…`, admin = team ProxyAdmin).
* Historical context: DefiLlama hacks DB records **two 2021 "Reward Logic Flaw" incidents** ($822,800 on 2021-05-24; $580,000 on 2021-10-29). The public write-up of the first attack describes a *balance-based reward conversion* (`tokenToSharkBNB`) abused by donating tokens right before `getReward()` — that pattern lives in the **v1 vaults, which are empty today**; the v2 farms compute rewards purely from `accFinsPerShare`/`accSquidPerShare` (no balance-based conversion), so the class does not repeat.

---

## 3. Live-state evidence (address + block + call)

Pinned block **127,400,000** (archive reads via keyed RPC in-shell only; keyless public RPC for un-pinned cross-checks). Full dump: `analysis/live_state_pinned.json`.

| Fact | Call | Value |
|---|---|---|
| 194 pairs | `FinsFactory.allPairsLength()` | 194 |
| Top pair | `0x3942940E…getReserves()` | 13.3918 WETH + 0.40222 BTCB (≈$67.0k) |
| …its LP owner | `PAIR.balanceOf(0x91d6136a…)` / `totalSupply` | 2,180.2731 / 2,245.9131 = **97.08 %** (@127,400,000; 95.4% at an earlier snapshot), address is an **EOA** (codesize 0) |
| DAI/USDT pair | `0xbD78f8Cf…getReserves()` | 15,624.95 DAI + 15,629.32 USDT (≈$31.2k) |
| …staked in MasterOcean | `PAIR.balanceOf(MasterOcean)` / supply | 15,494.2236 / 15,502.03 = **99.95 %** |
| USDT/BUSD pair | `0x06347b91…getReserves()` | 10,317.88 USDT + 10,299.97 BUSD (≈$20.6k) |
| …holders | MasterSquid 5,232.54 (51.17 %), fee vault 4,348.85 (42.53 %), MasterOcean 578.48 (5.66 %) | |
| feeTo gating | `impl 0xe1f153c3` decompiled; `owner()`, `keeper()` | owner `0xD9ebB6d9…`, keeper `0xa3B33022…` (EOAs) |
| fee vault gating | `impl 0x45948ce5` decompiled; `owner()`, `keeper()` | owner `0xbf00B8b5…`, keeper `0xc41E861E…` |
| MasterOcean state | `poolLength()`, `finsPerBlock()`, `FINS.balanceOf(MO)` | 47, 21e18, **0** |
| MasterSquid state | `poolLength()`, `squidPerBlock()`, `controller()`, `SQUID.balanceOf(farm)`, `massUpdatePools()` | 16, 20e18, **address(0)**, **80,902 wei**, massUpdate reverts (pid-0 SafeMath underflow); `updatePool(15)` works |
| FINS cap | `totalSupply()`, `maxSupply()` | 499,999,997.1 / 500,000,000 |
| jawsPool | `totalSupply()`, `JAWS.balanceOf(pool)`, `periodFinish()` | 69,837,390.478 (raw 6.9837e25), **0**, 1,705,683,967 (ended) |
| Launchpad | `totalAmount()`, `raisingAmount()`, `allowClaim()` | 408,934.5 LP, 59,701 LP, true |
| EIP-1967 proxies | impl/admin slots | jawsPool/feeTo/feeVault/NFTController are upgradeable; all ProxyAdmins owned by team EOAs (`0xD9ebB6d9…`, `0xbf00B8b5…`) |
| Farm hot paths live | `eth_call` from fresh EOA: `MasterOcean.updatePool(25)`, `massUpdatePools()`, `deposit(25,0)`, `MasterSquid.updatePool(3)`, `deposit(3,0,0x0)`, `getBoost(any,3)` | all succeed (no revert) — FINS `mint` at cap silently no-ops (`mint` returns true, `_mint` returns false); `getBoost` returns 0 (NFT boost inert) — so user deposit/withdraw paths are not bricked |

**Value attribution (CI re-derivation, run 38431927753, block 127,435,890, `ci-out/autoshark_ci_facts.json`):** total priced pair value **$147,077.17**; attributed: team fee EOA `0x91d6136a…` **$65,101.68**, MasterOcean **$43,188.48**, fee vault **$15,216.92**, MasterSquid **$12,538.10**, launchpad **$478.82**, feeTo **$260.46**; remainder ≈ $10,293 in small third-party EOA positions. (A local run at block 127,432,152 gave $146,955.23; triage $146,818 / DefiLlama $161,109 — all within pricing basis.)

---

## 4. What an attacker can / cannot do (exact call paths)

**Cannot (all revert live, probed and/or fork-tested):**
* `FeeDistributor.distribute(...)` / `distributeSingle(...)` — `require(msg.sender == keeper || owner)`. Both instances.
* `FinsToken.mint(uint256)` (onlyOwner), `FinsToken.mint(address,uint256)` / `SquidToken.mint(address,uint256)` (onlyMinter), `JawsToken.mint(address,uint256)` (onlyOwner).
* `MasterOcean.withdraw(pid,amt)` / `MasterSquid.withdraw(pid,amt)` for an address with no stake — `"withdraw: not good"`.
* `Launchpad.harvest()` — fresh address has no `userInfo` ("nothing to harvest"); `finalWithdraw` (the only path that moves the remaining LP) is admin-only.
* `jawsPool.withdraw(...)` — "system locked" style guards; and the pool holds **0 JAWS**, so even a valid staker could not be paid.
* Proxy `upgradeTo` — only through team-owned ProxyAdmins.

**Can (permissionless, but pays ≈ nothing):**
* `FinsPair.skim(to)` on pairs with donations — measured live: 23 pairs carry excess balances at block 127,432,152 (6–23 across sampled blocks), all in **unpriced zombie tokens** (Kitty, Mousey, NFTART, …). Largest: 10,882.26 Mousey; total priced value **$0.00**. No excess exists on any value pair (balances == reserves exactly for WETH/BTCB, DAI/USDT, USDT/BUSD, FINS/WBNB).
* `MasterOcean.updatePool/massUpdatePools` — mints FINS *to the farm*, but the cap is reached ⇒ mints nothing.
* `MasterSquid.updatePool(pid>0)` — still mints SQUID to the farm (farm balance 80,902 wei ≈ $0; the only SQUID market is one pair with ~$890 WBNB side); stakers can claim pro-rata as normal farming, but the realisable value is ≈ $0. `massUpdatePools()` reverts and pid 0 is bricked (see §6).
* `Launchpad.deposit` — window closed long ago (`start/endBlock` 12,831,140–12,835,940).

**Can (legit self-service = H-O, not attacker-profit):**
* Any LP holder can `burn` their `FinsPair` LP for the underlying reserves (standard pair).
* Farm depositors can withdraw LP: verified on-fork — a real LP holder deposits and withdraws exact amounts from MasterOcean pid 25 (WETH/BTCB, fee 0). MasterSquid principals: `emergencyWithdraw` works.

**Costs/limits of any hypothetical path:** none found that pays a fresh attacker; the only literal permissionless payout (`skim`) is bounded at $0.00 (dust tokens with no bid).

---

## 5. PoC / fork verification

Foundry project `poc/` — fork of BSC, **no transactions sent to mainnet** (fork-only). Suite `test/AutoSharkLive.t.sol`:

1. `test_live_value_concentration` — reserves and holder concentration on the 3 value pairs + fee-vault/feeTo LP positions (the $147.1k is really there).
2. `test_no_excess_on_value_pairs` — balance == reserve exactly on WETH/BTCB, DAI/USDT, USDT/BUSD, FINS/WBNB (nothing to skim).
3. `test_skim_only_dust` — skim of the biggest donation pair pays only dust (≤ ~0.4e18 raw of a 9-decimal unpriced zombie token; the token also charges a ~10% transfer tax, measured).
4. `test_fee_distributors_revert_for_fresh_attacker` — both FeeDistributors revert for a fresh EOA; balances unmoved.
5. `test_token_mints_revert_for_fresh_attacker` — FINS/JAWS/SQUID mints revert; attacker balance 0.
6. `test_farm_deposit_withdraw_self_service` — real LP holder deposits/withdraws exactly; emergency path too.
7. `test_fresh_attacker_cannot_withdraw_others` — fresh attacker cannot withdraw LP from MasterOcean; balances unmoved.
8. `test_mastersquid_farm_paths_work` — MasterSquid farm paths (deposit/withdraw/emergencyWithdraw) work for a fresh user; NFT boost inert (`getBoost == 0`).
9. `test_jawsPool_custody_is_empty` — 69.8M shares, 0 JAWS backing, no payout possible.
10. `test_launchpad_claims_and_withdrawals_gated` — `harvest`/`finalWithdraw` revert for a fresh EOA while the contract still custodies $479 of LP.

CI (GitHub Actions, public repo `kingmariano/ca-zombie-ci`, branch `autoshark`):
* `ci/run.sh` job: independent re-enumeration of all 194 pairs + attribution + 12 live `eth_call` gate probes from a fresh EOA — expects **all gated probes to revert** and fails the job otherwise. Output artifact: `ci-out/autoshark_ci_facts.json`.
* `forge test -vvv`: the suite above.
* **Independent adversarial review** (separate subagent, read-only re-probe of all payout paths): verdict **not refuted** — see `analysis/child-adversarial-review.md`.
* **CI run URL:** https://github.com/kingmariano/ca-zombie-ci/actions/runs/38431927753 — `ci/run.sh` job: all gated probes reverted (`gates_all_reverted: true`), total re-derived $147,077.17; `forge test -vvv`: **10/10 PASSED** (suite result ok).

```bash
bash /home/heisenberg/CA/ci/ci-run.sh autoshark   # re-run everything
```

---

## 6. Verdict, residual & latent risk

* **E-U (fresh attacker, today): $0.00 — high confidence.** The value is real ($147,077 priced, up to ~$161k on DefiLlama's basis) but is third-party-owned LP; every privileged payout path is access-controlled and every permissionless path is either empty or pays unpriced dust.
* **H-O ≈ $131,121:** LP redemption by holders (team fee EOA `0x91d6136a…` $65,102 — privately held, not protocol custody; MasterOcean depositors $43,188; MasterSquid depositors $12,538 (normal withdraw works); ~$10,293 other EOA holders).
* **P ≈ $15,956:** fee vault $15,217 + feeTo $260 + launchpad leftover LP $479 (all but 2 of 753 participants already harvested; harvest pays ATLAS, not LP; LP is admin `finalWithdraw` only) → team owner/keeper EOAs.
* **S ≈ $0 (in-scope) + ≈$130 out-of-scope claims:** jawsPool's 69.8M share ledger with zero backing; 131.4 ATLAS stranded in the launchpad (unpriced); MasterSquid pid-0 stakers' 1,799,636 SQUID (~$130 at the pair-implied price) are unbacked and unrecoverable (farm balance 80,902 wei; update/withdraw revert).
* **Residual/latent risks (not extractable now):**
  * Upgradeable proxies (jawsPool, both FeeDistributors, NFTController) with team-EOA ProxyAdmins: key compromise → up to ~$15.9k (P→E-U); key loss → frozen.
  * `FeeDistributor.setFeeAddress`, `MasterOcean/MasterSquid.setFeeAddress` (current feeAddress can re-point), `updateEmissionRate`/`set` — all privileged.
  * If SQUID ever gained exit liquidity, MasterSquid's mint paths (emissions + referral mints; boost is inert) could be farmed — latent only; today the pair depth is ~$890, pid-15 (~100% of emissions) is staked solely by the team EOA and its stake token SQUIDY (0x15c51300…) is team-held (99.998%) with no permissionless mint/market found (checked Fins, Pancake v2/v3 all tiers, Ape, Bakery, MDEX, BiSwap, BabySwap, Thena).
  * Historical "balance-manipulation" reward bug class: not reproducible — the v1 vaults that had it hold $0; v2 farms use index-based accounting.

**Blockers/uncertainties:** four implementations (`0xe1f153c3`, `0x45948ce5`, `0x73f76d34`, `0x2a5d80b7`) are unverified — we decompiled them (heimdall 0.9.2) and read live state; decompiler output was validated against observed `eth_call` behavior (gated probes revert; user paths succeed). GoldRush holder data used for the top pairs; address-level completeness below ~$500/pair relies on the protocol-contract set enumerated from the official repos + DefiLlama registry + top-holder scans (no unknown LP-holding contract found).

---

## 7. Methodology & sources

1. Corpus + triage re-verification (`zombie_hunt/*`, `l2-triage-a/summary.json`); DefiLlama protocol/hacks API (`api.llama.fi/protocol/autoshark`: TVL $160,777; hacks $822.8k + $580k, "Reward Logic Flaw"); DefiLlama adapter registry (`registries/uniswapV2.js` → factory + staking addresses).
2. Official sources: `github.com/autoshark-finance/autoshark-contracts` (v1 vaults/pools), `fins-periphery`, `autoshark-subgraph-v1` (factory 0xe759…, startBlock 10,962,344).
3. On-chain (BSC): full 194-pair enumeration + reserves/LP/holders; DefiLlama/CoinGecko-free pricing via `coins.llama.fi`; GoldRush (Covalent) balances/holders for protocol + top-holder addresses; Etherscan V2 (chainid 56) verified sources for FinsFactory, FinsPair, JAWS/FINS/SQUID tokens, proxies; heimdall decompilation of unverified impls; Nodereal/Ankr archive reads at pinned block 127,400,000 (keyed URLs used in-shell only — never written to files).
4. Fork PoC on GitHub Actions (CI helper) — fork only, no mainnet writes; CI also re-derives the numbers and probes all gates.

**Caveats:** (i) USD values are pricing-basis dependent (protocol-token legs unpriced; zombie tokens treated as $0); (ii) unverified impls read via decompiler — behavior cross-checked live; (iii) block drift between reads is documented per file; (iv) this report deliberately classifies the team EOA's $65.0k LP as H-O (holder-held), flagging that it is team-linked.

**Files index:** `README.md`; `summary.json`; `analysis/` — `enumerate_pairs.py`+`pairs_raw.json` (194 pairs, reserves/LP/holders), `valuation.json`, `enumerate_farms.py`+`farm_pools.json` (farm pools + staked balances), `attribute_lp.py`+`lp_attribution.json` (LP value attribution), `live_state.py`+`live_state_pinned.json` (pinned-block state dump @127,400,000), `ATTEMPTS-AND-NEGATIVES.md` (dead ends + corrections log), `decompiled_*.sol` (heimdall output for the four unverified impls), `masterocean_verified_source.sol`, `mastersquid_verified_source.sol`; `poc/` (Foundry fork suite + vendored forge-std); `ci/run.sh` (heavy re-enumeration + gate probes); `ci-out/autoshark_ci_facts.json`; `ci-log.txt`; `ci-artifacts/`.
