# Balancer V2 — Post-Hack Mitigation & Wind-Down Research (Nov 2025 → Oct 2026)

Research date: **2026-10-04**. Method: web research (websearch/webfetch + Firecrawl scrape), primary sources preferred (balancer.fi forum, official Medium, docs, GitHub, governance dashboards). All uncertainty is marked. No API keys are stored in this file. A copy of the DeFiHackLabs PoC source was fetched into `analysis/poc-refs/` (see §5).

**Companion local artifact:** `analysis/poc-refs/DeFiHackLabs_BalancerV2_exp.sol` (458 lines, fetched 2026-10-04 from `https://raw.githubusercontent.com/SunWeb3Sec/DeFiHackLabs/main/src/test/2025-11/BalancerV2_exp.sol`).

---

## 0. TL;DR

1. **Nov 3, 2025, 07:46 UTC** — exploit of Balancer V2 **Composable Stable Pools (CSPv5)**, rounding-down bug in `_upscale()` on the EXACT_OUT path. Official post-mortem totals: **$121.1M gross losses / "$94.8M theft of user funds"**, across **Ethereum, Arbitrum, Base, Optimism, Polygon** (plus Gnosis frozen funds and fork losses). (~$45.7M protected/recovered, official; later Gnosis hard-fork recovery $9.4M and Berachain ~$12.8M.) Sources: [official post-mortem, 2025-11-18](https://medium.com/balancer-protocol/nov-3-exploit-post-mortem-51dcbeb6b020), [Certora](https://www.certora.com/blog/breaking-down-the-balancer-hack), [Check Point](https://research.checkpoint.com/2025/how-an-attacker-drained-128m-from-balancer-through-rounding-error-exploitation/).
2. **No V2 Vault-level pause was possible/used on Ethereum** (Vault emergency pause ended 2021-07-18). Emergency action was **pool-level: Hypernative auto-paused all pausable CSPv6 pools at 08:07 UTC** (protecting $19.3M) and enabled recovery mode at 11:01 UTC. CSPv5 pools (pause windows expired) could not be paused. No later unpause BIP was found; CSPv6 remained paused/withdrawals-only.
3. **No patched V2 factories or Vault migration.** V2 is immutable: Balancer **disabled all remaining V2 pool factories** — CSPv6 factory on 2025-11-05, then BIP-887 (passed 2025-11-18) disabled Weighted/Managed/LBP factories — and pushed LPs to V3. Unaffected V2 pools kept swapping; no blanket "do not use V2" order, but "avoid impacted contracts" and "strongly encourage migration" advisories.
4. **2026 wind-down is real and voted:** Balancer Labs wind-down announced 2026-03-23; **BIP-928 "Orderly Winddown" posted 2026-09-14, approved 2026-09-29 with 99.2% of 17,226,164 BAL.** Pausable V2+V3 pools move to **withdrawals-only 2026-10-30**; minimal withdrawal interface from 2026-11-01; v3 Vault paused 2026-11-30; treasury distributed to BAL burners from end-May 2027. BIP-929 fork proposal rejected.
5. **Relayers:** no post-2025 relayer vulnerability advisory found. **BIP-927 (2026-08-25)** revoked leftover V2 Vault permissions from all deprecated relayers, leaving only **Batch Relayer V6** (`BalancerRelayer 0x35Cea9e57A393ac66Aaa7E25C391D52C74B5648f` on Ethereum).

---

## 1. The Nov 3, 2025 exploit

### 1.1 Root cause (primary sources)

- Official post-mortem (2025-11-18): incorrect rounding in the "exact out" swap path. `_swapGivenOut()` adjusts `amountOut` for decimals/rate then **rounds down via `_upscale()`**, which also understates `amountIn` — the caller underpays. Three preconditions: (1) rounding error in EXACT_OUT; (2) rate providers (non-unitary scaling factors); (3) low-liquidity state to magnify imprecision. Only **Composable Stable Pools that actually incorporated BPT + rate providers** met all three. https://medium.com/balancer-protocol/nov-3-exploit-post-mortem-51dcbeb6b020
- Certora (2025-11-06): rounding direction should favor the protocol; composable pools let the attacker "borrow" BPT inside `batchSwap` and force low liquidity. https://www.certora.com/blog/breaking-down-the-balancer-hack
- Trail of Bits (2025-11-07): independently confirmed v3 unaffected; notes it had reported related rounding issues in 2021 (TOB-BALANCER-004, Linear Pools, "undetermined severity"). https://blog.trailofbits.com/2025/11/07/balancer-hack-analysis-and-guidance-for-the-defi-ecosystem/
- OpenZeppelin (2025-11-07): attack vector introduced by `_scalingFactors` overrides — MetaStablePool (2021-07-16), LinearPool (2021-09-01), StablePhantomPool/CSP (2021-09-20); those contracts were outside OZ's audit scope. https://www.openzeppelin.com/news/understanding-the-balancer-v2-exploit
- BlockSec (2025-11-06), Check Point (2025-11-05), SlowMist (2025-11-06), CertiK (2025-11-25), Coinspect, Olympix, Blockscope, anomly.rs: corroborating technical analyses (URLs in §7).

### 1.2 Affected pools (published addresses)

**Ethereum focal transaction** (the two pools drained in the first tx, 2025-11-03 07:46:47 UTC, block 23,717,397):

| Pool | Address / Pool ID | Assets extracted |
|---|---|---|
| osETH/wETH CSP | `0xDACf5Fa19b1f720111609043ac67A9818262850c`, poolId `0xdacf5fa1…0635` | 4,623.6015 WETH + 6,851.1230 osETH (+44.15 BPT) |
| wstETH/WETH CSP | `0x93d199263632a4EF4Bb438F1feB99e57b4b5f0BD`, poolId `0x93d19926…05c2` | 1,963.8388 WETH + 4,259.8435 wstETH (+20.41 BPT) |

Sources: [Check Point](https://research.checkpoint.com/2025/how-an-attacker-drained-128m-from-balancer-through-rounding-error-exploitation/), [anomly.rs](https://anomly.rs/balancer-bpt-batchswap), [Bearby](https://blog.bearby.io/blog/balancer-v2-stable-pool-hack-2025/), [CertiK](https://www.certik.com/blog/balancer-incident-analysis).

**Other affected/recovered pools published by BIP-892** (status 2025-11-27 — this is the best published pool list; the post-mortem's complete "list of affected pools" link was left as a `[PLACEHOLDER]`):

- Ethereum: `weETH/rETH` `0x05ff47af…0645`; `rsETH/WETH` `0x58aadfb1…067f`; `wstETH-WETH-BPT` `0x93d19926…05c2`; `osETH/wETH-BPT` `0xdacf5fa1…0635`. Metastable internal-rescue pools: B-rETH-STABLE `0x1e19cf2d…0112`, B-stETH-STABLE `0x32296969…0080`, B-wstETH-STABLE-C `0x851523a3…01ed`, B-staFiETH-WETH-Stable `0xb08885e6…0445`.
- Polygon PoS: B-stMATIC-Stable `0x8159462d…075d`; TruMATIC-WMATIC `0x951d84e3…0d62`; maticX-WMATIC-BPT `0xcd78a20c…0c22`.
- Base: weETH/wETH `0xab99a3e8…0118`; rETH-WETH-BPT `0xc771c1a5…0023`.
- Arbitrum: ankrETH/wstETH-BPT `0x3fd4954a…0480`; wstETH/rETH/cbETH `0x4a2f6ae7…0481`; sUSDX/USDX `0xb3047330…05e4`; ETHx/wstETH `0x7b54c44f…053c`; rsETH/WETH `0x90e6cb52…055c`; wstETH/sfrxETH `0xc2598280…04f3`; ezETH/wstETH `0xb61371ab…0516`; rETH/wETH-BPT `0xd0ec47c5…04ef`; weETH/wETH `0xf13758d6…0595`; metastable B-wstETH-WETH-Stable `0x36bf227d…0316`.
- Optimism metastable internal-rescue pools: BPT-rETH-ETH `0x4fd63966…002b`; BPT-WSTETH-WETH `0x7b507753…008b`.
Source: https://forum.balancer.fi/t/bip-892-distribution-of-rescued-funds-from-balancer-v2-november-3rd-2025-attacks/6883 (updated thread) and the snapshot repo https://github.com/maxyz-xyz/balancer-upscale-exploit-shares

**Vulnerable version distinction (critical):** CSPv5 pools (6-month pause windows, expired) were drained; **CSPv6 pools (4-year pause windows, still active) were paused in time** and only lost what left before the pause. See §1.5.

### 1.3 Chains

- Official post-mortem: first malicious txs "across **Ethereum, Arbitrum, Base, Optimism, and Polygon**"; losses totalled $121.1M across those five. Gnosis was also impacted and handled separately (bridge freeze, then hard fork — see §1.6).
- The Block (2025-11-06) listed CSP activity on Ethereum, Base, Avalanche, Arbitrum, Optimism, Gnosis, Polygon, Berachain, Sonic. Fork/partner protocols: **Beets** (Sonic) and **BEX**; CertiK estimated Balancer ~$113M, Beets ~$3.8M, Bex ~$12.4M of the ~$130M gross. Balancer's post-mortem explicitly says it cannot comment on forks.
- Chain-specific later recoveries: Gnosis ~$9.4M (hard fork, 2025-12-22); Berachain ~$12.8M returned by a whitehat (Dec 2025); Polygon $1.4M frozen; Sonic $3.3M initially frozen then allegedly laundered (CertiK, 2025-11-25).

### 1.4 Amounts stolen / recovered (conflicting figures — use with care)

| Figure | Amount | Source |
|---|---|---|
| Official headline "theft of user funds" | **$94.8M** | [Post-mortem, 2025-11-18](https://medium.com/balancer-protocol/nov-3-exploit-post-mortem-51dcbeb6b020) |
| Official "total losses" | **$121.1M** (Ethereum/Arbitrum/Base/Optimism/Polygon) | same |
| Official protected (CSPv6 paused) | **~$19.3M** | same |
| Official recovered (whitehats) | **~$4.6M** (Bitfinding/ETH $964k; Polygon $2.68M; Base $161k; Arbitrum $49k) | same |
| StakeWise emergency recovery (osETH/osGNO) | **~$19M + ~$1.9M** | same; [BIP-892](https://forum.balancer.fi/t/bip-892-distribution-of-rescued-funds-from-balancer-v2-november-3rd-2025-attacks/6883) |
| Internal Certora/metastable whitehat rescue | **~$4.1M** (ETH $3.59M, OP $488k, ARB $29k) | [BIP-892](https://forum.balancer.fi/t/bip-892-distribution-of-rescued-funds-from-balancer-v2-november-3rd-2025-attacks/6883) |
| "Protected or recovered" total | **~$45.7M** | post-mortem |
| Third-party gross estimates | $128.64M (Check Point); ~$130M incl. forks (CertiK); $116M (many outlets) | [Check Point](https://research.checkpoint.com/2025/how-an-attacker-drained-128m-from-balancer-through-rounding-error-exploitation/), [CertiK](https://www.certik.com/blog/balancer-incident-analysis) |
| Gnosis hard-fork recovery | **~$9.4M** | [crypto.news 2025-12-23](https://crypto.news/gnosis-chain-activates-hard-fork-to-recover-9-4m-frozen-during-balancer-exploit/); [Gnosis forum 2025-12-12](https://forum.gnosis.io/t/balancer-hack-hard-fork/11884) |
| Berachain whitehat return | **~$12.8M** | [crypto.news 2025-12-23](https://crypto.news/gnosis-chain-activates-hard-fork-to-recover-9-4m-frozen-during-balancer-exploit/) |
| BIP-892 distributable recoveries (excl. StakeWise) | **~$8M total**: $3.86M external whitehats + $4.11M internal metastable rescue | [BIP-892](https://forum.balancer.fi/t/bip-892-distribution-of-rescued-funds-from-balancer-v2-november-3rd-2025-attacks/6883) |

**Note:** the official $94.8M vs $121.1M figures are not reconcilable from the post-mortem text alone; the $94.8M is described as "theft of user funds" while $121.1M is "total losses". Treat exact totals as unsettled.

### 1.5 Pauses: what was paused, when, and whether lifted

**The premise "Vault `setPaused(true)`" does not apply to V2 mainnet.** The V2 `Vault.setPaused(bool)` exists ([Vault.sol](https://github.com/balancer/balancer-v2-monorepo/blob/master/pkg/vault/contracts/Vault.sol), [docs-v2](https://docs-v2.balancer.fi/reference/contracts/apis/vault.html)), but the Vault's own pause window was only ~3 months and **ended 2021-07-18** ("The Vault and WeightedPools are now immutable" — [Balancer V2 emergency pause docs](https://balancer.gitbook.io/balancer-v2/security/emergency-pause)). Later Vault deployments on other networks had their own (also expired-by-2025) windows; **no evidence of any chain-level Vault pause on 2025-11-03 was found** in the official post-mortem or third-party reporting — BlockSec explicitly noted the protocol "could not be paused due to certain constraints" for the affected pools.

What actually happened (official timeline, all 2025-11-03):

| Time (UTC) | Action |
|---|---|
| 07:46 | First malicious txs (ETH, ARB, Base, OP, Polygon) |
| 07:46 | Bitfinding front-runs attacker on Ethereum, recovers ~$964k |
| 07:52 | Hypernative flags; war room |
| **08:07** | **All pausable CSPv6 pools paused** via Hypernative's Safe module → $19.3M protected |
| 08:29 | All attacker addresses flagged |
| 09:50 | First public disclosure via @Balancer X ("aware of a potential exploit impacting Balancer v2 pools…") |
| **11:01** | **Recovery mode activated on affected pools** → proportional (withdraw-only) exits |
| Nov 4 | Emergency SubDAO killed all gauges tied to affected V2 pools |
| Nov 5 | CSPv6 factory disabled across chains; preliminary report published |
| Nov 8, 21:00 | Deadline in on-chain message to attacker (bounty offer, terms private) — no return; 3,711 ETH sent to Tornado Cash on Nov 15 (CertiK) |

Pause mechanism: Hypernative was given pause authority via **BIP-794** (forum 2025-01-20; safe module `0xbaEa4E4A47a3b88e03C003DE6Baf8F5404DA9d56` on the Emergency SubDAO safes; CSPv6-only pausability until Feb 2028 per **BIP-585**). CSPv6 existed on **Ethereum, Base, Optimism, Polygon, Gnosis, Arbitrum, Avalanche, zkEVM** (modules also configured on Mode, Fraxtal). Sources: [BIP-794](https://forum.balancer.fi/t/bip-794-enable-composable-stable-pool-pause-functionality-to-hypernative/6306), [BIP-585](https://forum.balancer.fi/t/bip-585-enable-composablestablepool-v6-long-pause-windows/5688), [SlowMist](https://slowmist.medium.com/when-small-flaws-collapse-a-giant-inside-balancers-100m-hack-85b9e92a9ae3).

**Were pauses lifted?** No public proposal to unpause the CSPv6 pools or disable recovery mode was found in the sources reviewed. They were paused/withdrawals-only going into the wind-down, which itself says "pools that can be paused are paused" on 2026-10-30. Mechanically, V2 `TemporarilyPausable` auto-unpauses a still-paused contract only after its **buffer-period end** (CSPv6 factory pause window runs to ~Feb 2028 + buffer), so no automatic unpause occurred before the wind-down. *Verify on-chain with `pool.getPausedState()` / `Vault.getPausedState()` if this matters for your analysis — not verified here.*

### 1.6 Later chain-level recoveries

- **Gnosis Chain**: validators first ran a targeted soft fork censoring the attacker address (Nov 2025), then executed an **irregular state-transition hard fork at 2025-12-22 16:11:40 UTC** replacing the attacker EOA's code with a hardcoded forwarder to a rescue safe — recovering **~$9.4M**. Spec: [gnosischain/specs commit 2025-12-15](https://github.com/gnosischain/specs/commit/8c846abc1b511c85fbde1eb521526413f56347d8); discussion: [forum.gnosis.io 2025-12-12](https://forum.gnosis.io/t/balancer-hack-hard-fork/11884); claim portal: **https://gnosis-balancer-claim.eth.limo/** (claim process: https://forum.gnosis.io/t/balancer-hack-claim-process/12149).
- **Berachain**: network halt + blacklist; ~$12.8M returned via whitehat ([crypto.news](https://crypto.news/gnosis-chain-activates-hard-fork-to-recover-9-4m-frozen-during-balancer-exploit/)).
- **Attacker bounty negotiation**: Nov 8, 2025 on-chain message offered a private-terms bounty + no-prosecution for return, deadline 2025-11-08 21:00 UTC; no funds returned ([Bitcoinist](https://bitcoinist.com/balancer-message-128m-hacker-offers-bounty/)). Some outlets reported a 20% bounty offer on Nov 3; BIP-726's Safe Harbor bounty is 10% for whitehats (cap $1M per operation).

---

## 2. Mitigation for the still-vulnerable V2 pools

**Bottom line: no patch was possible or deployed to V2.** All V2 contracts (Vault, pool implementations) are immutable and cannot be upgraded ([balancer-v2-monorepo README](https://github.com/balancer/balancer-v2-monorepo): "All core smart contracts are immutable, and cannot be upgraded"). Balancer's response was containment + deprecation + migration:

1. **CSPv6 (vulnerable, pausable):** paused 2025-11-03 08:07 UTC; recovery mode 11:01 UTC; **CSPv6 factory disabled 2025-11-05** so no new CSP can be created. $19.3M protected; large LPs (Crypto.com, Ether.fi) exited safely. Sources: [post-mortem](https://medium.com/balancer-protocol/nov-3-exploit-post-mortem-51dcbeb6b020), [The Block](https://www.theblock.co/post/377863/balancer-identifies-rounding-error-as-root-cause-of-multi-chain-defi-exploit).
2. **CSPv5 (exploited, not pausable):** pause windows expired; the factory had already been disabled in 2024 (BIP-585). No on-chain fix possible; gauges killed 2025-11-04; users guided to proportional exits / recovery mode where available. No patched CSPv5 factory exists (creation is dead by design).
3. **All remaining V2 factories disabled via BIP-887** — "Transitioning to Balancer v3: Disabling v2 Pool Factories": forum posted 2025-11-10, Snapshot 2025-11-14→18, **passed 2025-11-18** (quorum reached; payload merged in [multisig-ops PR #2529](https://github.com/BalancerMaxis/multisig-ops/pull/2529)). Disabled `WeightedPoolFactory`, `ManagedPoolFactory`, `NoProtocolFeeLiquidityBootstrappingPoolFactory` across all networks, completing V2 pool-creation deprecation. https://forum.balancer.fi/t/bip-887-transitioning-to-balancer-v3-disabling-v2-pool-factories/6874
4. **Flash re-audits / preventive whitehat:** Certora + Trail of Bits joined the war room; a *new value-extraction path* was found in **V2 meta-stable pools**. In coordination with Certora and SEAL911, ~**$4.1M** was proactively extracted (7 pools on ETH/OP/ARB) and returned to DAO multisig internal balances for distribution (BIP-892 §4.2.2). [Post-mortem](https://medium.com/balancer-protocol/nov-3-exploit-post-mortem-51dcbeb6b020), [X post 2025-11-13](https://x.com/Balancer/status/1988685056982835470).
5. **Migration path to V3:** post-mortem + BIP-887 commit to a migration pathway; concrete examples: BIP-888 (mainnet rETH gauge moved to v3, passed 2025-11-18), BIP-896 (Rocket Pool alliance), BIP-898 (ALCX/ETH gauge to v3, 2025-12-20). "Balancer V3: Why It Is Here To Stay" (2025-12-18) states: "Rather than patching V2 indefinitely, resources are being channeled toward V3" — and notes "existing V2 pools remain operational" while service providers "strongly recommend migration". https://medium.com/balancer-protocol/balancer-v3-here-to-stay-9ec37439b4be
6. **Did they leave V2 swaps enabled?** Yes — unaffected V2 pools (Weighted, Gyro, plain Stable, BPT infra like BAL/WETH and veBAL) stayed operational; only affected/vulnerable CSP pools went pause/withdraw-only. There was **no blanket "do not use V2" advisory**; the November guidance was "avoid impacted contracts" (preliminary report) and "strongly encourage migration" for stable pools. The definitive "withdraw only" regime arrives with the 2026 wind-down (§3).

---

## 3. The 2026 wind-down

### 3.1 Balancer Labs entity wind-down

- **2026-03-23** — Fernando Martinelli (co-founder) forum post: "On the Future of Balancer: Shutting Down Balancer Labs". BLabs becomes "a liability rather than an asset" (Nov 3 exploit legal exposure); essential staff absorbed into **Balancer OpCo**; BAL emissions to zero, veBAL wind-down, fee restructuring, and a BAL buyback (BIP-919) proposed as a "lean continuation". https://forum.balancer.fi/t/on-the-future-of-balancer-shutting-down-balancer-labs-supporting-the-path-forward/7002
- The broader **DAO/protocol wind-down** followed in September 2026 (below).

### 3.2 BIP-928 — "Orderly Winddown of Balancer and Distribution of the Treasury"

- Posted **2026-09-14**; edited 2026-09-24; **Snapshot vote 2026-09-25 → 2026-09-29**; **passed 99.2% of 17,226,164 BAL** (quorum 5M BAL set under BIP-924; 42 addresses; ~0.8% against). A parallel proposal **BIP-929 "Fork and Reincarnate" was rejected** (69.9% of 17,327,145 BAL against).
- Exact scope (verified against the forum text and secondary reports):
  - No new business development; phased sunset; **contracts are non-custodial and withdrawals never depend on Balancer**.
  - **2026-10-30: pausable pools are paused and move to withdrawals-only** (V2 + v3); recovery mode where contracts require it; **protocol fee set to zero** on the rest where contracts allow; **bug-bounty coverage ends**.
  - Exception: a v3 pool partner can request continued operation until **2026-11-30**, when the **v3 Vault is paused** (requests due 2026-10-16; list published before 10-30).
  - **From 2026-11-01:** minimal "exit stack" — simplified withdrawal interface, subgraph coverage, public documentation — run by a skeleton transition team on a **$400k budget** ($150k to May 2027, $30k after, $220k reserve).
  - Nov–Dec 2026: low-risk permission revocations. End Feb 2027: implementation spec for the claim contract published.
  - **Treasury distribution:** round 1 opens **end-May 2027** (burn BAL, receive in-kind pro-rata treasury; 6-month window); round 2 airdrop to round-1 redeemers by end-Jan 2028; final sweep end-Jul 2028; then entities close (Foundation last). Measured base: **$9,959,416 distributable / 63,068,821 redeemable BAL ≈ $0.1579 per BAL** (2026-09-18 prices, not audited). **BIP-919 buyback is cancelled**; BIP-687 bug-bounty ring-fence released.
  - Exploit-recovered funds are **ring-fenced for affected LPs** and excluded from the treasury distribution.
- Sources: https://forum.balancer.fi/t/bip-928-orderly-winddown-of-balancer-and-distribution-of-the-treasury/7107 ; [coinpaprika summary 2026-10-02](https://coinpaprika.com/education/balancer-wind-down-vote-result/) ; [The Defiant 2026-09-29](https://thedefiant.io/news/defi/balancer-holders-approve-wind-down-reject-official-fork) ; [cryptobriefing 2026-09-14](https://cryptobriefing.com/balancer-proposes-shutdown-treasury-distribution/).
- **Status as of 2026-10-04:** proposal passed; execution window not yet reached. `https://balancer.fi/` already shows the banner: "Balancer DAO has approved an orderly winddown (BIP-928). Most pools move to withdrawals only on 30 October 2026. Withdrawals remain available after that date." About **$52.4M remained in V2+V3 pools** at end-Sep 2026 ([The Defiant](https://thedefiant.io/news/defi/balancer-sets-shutdown-dates-after-bal-holders-approve-wind-down)).

### 3.3 Rescued-funds distribution & claim process (separate track)

- **BIP-892** (posted 2025-11-27; Snapshot **2025-12-12→16**; execution week 2025-W51): non-socialized, pro-rata, payment-in-kind distribution of ~$8M recovered funds; 10% whitehat bounties paid in-kind; separate handling for StakeWise (~$19.7M osETH/osGNO) and internally rescued metastable pools (~$4.1M, full amount to LPs). 180-day claim window; snapshot blocks: Ethereum 23,717,626 / Base 37,683,373 / Polygon 78,525,618 / Arbitrum 396,293,450 (plus per-pool blocks for metastables). https://forum.balancer.fi/t/bip-892-distribution-of-rescued-funds-from-balancer-v2-november-3rd-2025-attacks/6883
- **BIP-923** (posted 2026-07-23; first vote closed 2026-08-04 unanimously but below the then-10M quorum; **rerun 2026-08-21→25 under the new 5M quorum; approved August 2026**): extends the claim window another 6 months (total 12 months), keeps the existing Merkle contract live; ~$920k (~500 ETH) unclaimed as of July 2026; Ethena/ShapeShift rebates (12,518 USDe + 133,905 USDC) noted as not yet on a Merkle contract. https://forum.balancer.fi/t/bip-923-next-phase-decision-for-rescued-funds-distribution-from-balancer-v2-november-2025-attacks/7091 (*BIP-923 exact passage mechanics sourced from [caper.network](https://caper.network/wiki/daos/dexs/balancer-dao) and [DAO Radar](https://governance.alearesearch.io/item/f3c066bb-83c3-4190-b913-006f2756924d); mark as medium confidence.*)

### 3.4 Migration front-ends / contracts that let users withdraw

| Path | What it is | Source |
|---|---|---|
| `balancer.fi` / app UI | Wind-down banner; V2 and V3 pool pages remain; recovered-funds claim UI in the Balancer frontend (`PortfolioClaim/recovered-funds`, Merkl-based, chains 1/10/137/42161/8453) | [balancer.fi](https://balancer.fi/), [frontend-monorepo useClaimSteps.tsx](https://github.com/balancer/frontend-monorepo/blob/65bb0b56/packages/lib/modules/portfolio/PortfolioClaim/recovered-funds/useClaimSteps.tsx) |
| Minimal exit stack (from 2026-11-01) | Simplified withdrawal interface + subgraph + docs per BIP-928 | [BIP-928](https://forum.balancer.fi/t/bip-928-orderly-winddown-of-balancer-and-distribution-of-the-treasury/7107) |
| Direct contract exits (V2) | `Vault.exitPool()` (proportional/single-token/custom); recovery-mode proportional exit when a pool is paused; documented SDK flows | [docs-v2 exit guide](https://docs-v2.balancer.fi/guides/builders/exit-pool.html), [Pool Exits reference](https://docs-v2.balancer.fi/reference/joins-and-exits/pool-exits.html), [Vault API](https://docs-v2.balancer.fi/reference/contracts/apis/vault.html) |
| Recovered-funds claims | Merkle/merkl contracts deployed per-chain under BIP-892; claim data repo | [maxyz-xyz/balancer-upscale-exploit-shares](https://github.com/maxyz-xyz/balancer-upscale-exploit-shares), BIP-892 |
| Gnosis claim | https://gnosis-balancer-claim.eth.limo/ (1-year claim period) | [Gnosis claim site](https://gnosis-balancer-claim.eth.limo/), [Gnosis forum](https://forum.gnosis.io/t/balancer-hack-claim-process/12149) |

Context: a separate **Balancer V1 exploit occurred 2026-08-31** (single-sided join rounding), with its own recovery/distribution framework (BIP-930) — useful precedent, not V2 ([BIP-930](https://forum.balancer.fi/t/bip-930-distribution-of-recovered-funds-from-balancer-v1-august-31st-2026-exploit/7111)).

---

## 4. Public advisories by V2 pool type (post-hack)

- **CSPv5 (Composable Stable v5):** vulnerable and actually exploited. Not pausable (pause window expired); factory already disabled (2024). Advisory: migrate/withdraw; no patched factory. Compose with BIP-892 if in a recovered pool.
- **CSPv6:** vulnerable (same rounding bug) but pausable; auto-paused 2025-11-03 08:07 UTC, recovery mode 11:01 UTC; factory disabled 2025-11-05; never patched. Effectively withdrawals-only since.
- **MetaStable:** official statement: could **not** be exploited by the original attack (no low-liquidity/BPT mechanism), **but** a *different* value-extraction path was identified in re-audit and proactively rescued (~$4.1M, 7 named pools, §1.2). LPs are reimbursed via BIP-892 with the full rescued amount (no bounty deduction). Sources: [post-mortem](https://medium.com/balancer-protocol/nov-3-exploit-post-mortem-51dcbeb6b020), [BIP-892](https://forum.balancer.fi/t/bip-892-distribution-of-rescued-funds-from-balancer-v2-november-3rd-2025-attacks/6883).
- **Linear pools:** **no post-Nov-2025 Balancer advisory declares Linear pools vulnerable to this exploit.** The official precondition analysis says only CSPs with BPT + rate providers satisfied all three conditions. Caveats to note: OpenZeppelin documents that LinearPool (2021-09-01) introduced the same non-unitary `_scalingFactors` override that underpins the bug class, and Trail of Bits' 2021 audit flagged related rounding behavior in Linear pools as TOB-BALANCER-004 ("undetermined severity"). Linear pools were the subject of the **separate August 2023** linear-pool incident (different root cause: `_downscaleDown` rounding → cached rate manipulation). Sources: [OpenZeppelin](https://www.openzeppelin.com/news/understanding-the-balancer-v2-exploit), [Trail of Bits](https://blog.trailofbits.com/2025/11/07/balancer-hack-analysis-and-guidance-for-the-defi-ecosystem/), [BlockSec 2023](https://blocksec.com/blog/tiny-rounding-down-big-fund-losses-an-in-depth-analysis-of-the-recent-balancer-incident).
- **Weighted / Gyro / plain Stable pools:** officially unaffected (different math / no rate providers; weighted math absorbs 1-wei errors; Gyro uses virtual balances).
- **Balancer V3:** unaffected — separate architecture, explicit rounding controls, 18-decimal precision at the Vault, formal verification of roundtrip/share-value properties ([Certora](https://www.certora.com/blog/breaking-down-the-balancer-hack), [post-mortem](https://medium.com/balancer-protocol/nov-3-exploit-post-mortem-51dcbeb6b020)).
- **Overall V2 status messaging:** "strongly encourage migration to v3" (post-mortem) → factories disabled (BIP-887) → "V3 is the only platform for new liquidity" (2025-12-18) → BIP-928 withdrawals-only + fee-zero + interface sunset (2026).

---

## 5. Exploit artifacts & PoC code

### 5.1 Transactions & addresses (Ethereum, minimum set)

| Item | Value |
|---|---|
| Theft / drain tx (Ethereum) | `0x6ed07db1a9fe5c0794d44cd36081d6a6df103fab868cdd75d581e3bd23bc9742` (block 23,717,397; 2025-11-03 07:46:47 UTC, constructor executed the batch swaps) |
| Internal-balance withdrawal tx | `0xd155207261712c35fa3d472ed1e51bfcd816e616dd4f517fa5959836f5b48569` (block 23,717,404; 84 s later) |
| Attacker EOA (deployer) | `0x506D1f9EFe24f0d47853aDca907EB8d89AE03207` |
| Exploit contract (SC1) | `0x54B53503c0e2173Df29f8da735fBd45Ee8aBa30d` |
| Math helper (SC2) | `0x679B362B9f38BE63FbD4A499413141A997eb381e` |
| Sweep recipient (Exploiter 2) | `0xAa760D53541d8390074c61DEFeaba314675b8e3f` |
| Secondary address | `0xf19FD5c683a958ce9210948858B80d433F6BfaE2` |
| Balancer V2 Vault (Ethereum) | `0xBA12222222228d8Ba445958a75a0704d566BF2C8` |
| Arbitrum attack tx (reported) | `0x7da32ebc615d0f29a24cacf9d18254bea3a2c730084c690ee40238b1d8b55773` |
| Another Ethereum tx (reported) | `0x2a0ead4ee9b17a1afa5bfe3dc152833a957f2d25dd9b4b86d68f2c87bdacf69c` |

Sources: [Check Point](https://research.checkpoint.com/2025/how-an-attacker-drained-128m-from-balancer-through-rounding-error-exploitation/), [anomly.rs](https://anomly.rs/balancer-bpt-batchswap), [DeFiHackLabs PoC](https://github.com/SunWeb3Sec/DeFiHackLabs/blob/main/src/test/2025-11/BalancerV2_exp.sol), [DK27ss README](https://github.com/DK27ss/BalancerV2-128M-PoC) (Arbitrum/other-hash items are third-party reported, not re-verified here).

### 5.2 PoC code (links; do not clone heavy repos)

| Repo / file | Notes |
|---|---|
| `SunWeb3Sec/DeFiHackLabs` → `src/test/2025-11/BalancerV2_exp.sol` | Foundry PoC; fork block 23,717,397-1; reproduces both Ethereum pools. **Copy saved locally at `analysis/poc-refs/DeFiHackLabs_BalancerV2_exp.sol`.** https://github.com/SunWeb3Sec/DeFiHackLabs/blob/main/src/test/2025-11/BalancerV2_exp.sol |
| `DK27ss/BalancerV2-128M-PoC` | Write-up + code, multi-chain notes, pools and extraction flow. https://github.com/DK27ss/BalancerV2-128M-PoC |
| `ret2basic` gist | Fork-based PoC demonstrating scaling-factor rounding and attack economics. https://gist.github.com/ret2basic/0345c35ecf89b6b552f8763bb6136cac |
| `ret2basic/balancer-v2-2025.11-hack-analysis` | Analysis repo. https://github.com/ret2basic/balancer-v2-2025.11-hack-analysis |
| `wangshouh/balancer-v2-poc` | Referenced by the ret2basic PoC. https://github.com/wangshouh/balancer-v2-poc |
| Coinspect "Learn EVM Attacks" case | AttackCoordinator / BalancerExploitMath decompiled contracts + test harness. https://www.coinspect.com/learn-evm-attacks/cases/balancer-v2-stable-pools-rate-manipulation/ |
| `Adeshh/defi-hack-labs` | Educational re-implementation, `test/balancer2025/`. https://github.com/Adeshh/defi-hack-labs |

---

## 6. V2 BatchRelayer / relayer contracts

### 6.1 Post-2025 relayer actions & advisories

- **No relayer-specific security advisory (post-Nov-2025) was found** in public sources (forum, docs, GitHub). The relayer-related post-hack action is **BIP-927 "Revoke Unused V2 Vault Permissions from Deprecated Relayers"** (forum 2026-08-25; Snapshot 2026-08-30): revoke `swap`/`batchSwap`/`joinPool`/`exitPool`/`manageUserBalance`/`setRelayerApproval` permissions from all deprecated relayers on the V2 Vault across chains; **only `20231031-batch-relayer-v6/BalancerRelayer` is left intact**. It is framed as sunset hygiene, not a vulnerability disclosure. https://forum.balancer.fi/t/bip-927-revoke-unused-v2-vault-permissions-from-deprecated-relayers/7099
- Deprecated relayers to be revoked: v1 `20211203` (chains 1,137,42161), v2 `20220318` (137), v3 `20220720` (1,10,137,42161), v4 `20220916` (1,10,100,137,42161), v5 `20230314` (1,10,100,137,8453,42161,43114), `cow/vault_relayer` (1), `20210812-lido-relayer/LidoRelayer` (1), `CronV1Relayer` (1). Permission revocations scheduled Nov–Dec 2026 in the wind-down plan. (For comparison, a **v3** `permitBatchAndCall` reentrancy fix exists — balancer-v3-monorepo PR #1110, Nov 2024 — unrelated to V2 relayers.)
- *Absence-of-evidence flag: this does not prove there were no relayer issues; it means no public post-2025 advisory was surfaced by this research.*

### 6.2 Ethereum mainnet relayer deployments (from `balancer/balancer-deployments/addresses/mainnet.json`, fetched 2026-10-04)

| Task / version | Contract | Address | Status |
|---|---|---|---|
| 20210812-lido-relayer | LidoRelayer | `0xdcdbf71A870cc60C6F9B621E28a7D3Ffd6Dd4965` | DEPRECATED |
| 20211203-batch-relayer (v1) | BatchRelayerLibrary / BalancerRelayer | `0x41B953164995c11C81DA73D212ED8Af25741b7Ac` / `0xAc9f49eF3ab0BbC929f7b1bb0A17E1Fca5786251` | DEPRECATED |
| 20220318-batch-relayer-v2 | BatchRelayerLibrary / BalancerRelayer | `0xd45369c11870e2057D5be17Cc106d32Ea416F7c4` / `0x51CC53375A8920aE54C0561E73a9d0423A74832e` | DEPRECATED |
| 20220513-double-entrypoint-fix-relayer | DoubleEntrypointFixRelayer | `0xcA96C4f198d343E251b1a01F3EBA061ef3DA73C1` | ACTIVE (on file) |
| 20220720-batch-relayer-v3 | BatchRelayerLibrary / BalancerRelayer | `0xD966d712F470067B60D37246404D6DFe5Bf0B419` / `0x886A3Ec7bcC508B8795990B60Fa21f85F9dB7948` | DEPRECATED |
| 20220916-batch-relayer-v4 | BatchRelayerLibrary / BalancerRelayer | `0xd02992266BB6a6324A3aB8B62FeCBc9a3C58d1F9` / `0x2536dfeeCB7A0397CF98eDaDA8486254533b1aFA` | DEPRECATED |
| 20230314-batch-relayer-v5 | BatchRelayerLibrary / BalancerRelayer | `0xf77018c0d817dA22caDbDf504C00c0d32cE1e5C2` / `0xfeA793Aa415061C483D2390414275AD314B3F621` | DEPRECATED |
| **20231031-batch-relayer-v6** | BatchRelayerLibrary / BatchRelayerQueryLibrary / **BalancerRelayer** | `0xeA66501dF1A00261E3bB79D1E90444fc6A186B62` / `0x481Ca759BABB6fF011E11890e183bE00de3714e7` / **`0x35Cea9e57A393ac66Aaa7E25C391D52C74B5648f`** | **ACTIVE** — the only relayer kept after BIP-927 |

Cross-checks: docs-v2 mainnet deployment addresses https://docs-v2.balancer.fi/reference/contracts/deployment-addresses/mainnet.html ; repo https://github.com/balancer/balancer-deployments. Notes: v2 relayer (`20220318`) appears in `mainnet.json` but BIP-927 grants/permissions only list it on Polygon (137) — treat chain mapping with care.

---

## 7. Source list (primary first)

**Official Balancer / governance**
- Post-mortem, 2025-11-18 — https://medium.com/balancer-protocol/nov-3-exploit-post-mortem-51dcbeb6b020
- Preliminary response / guidance recap, 2025-11-05 — reported at https://dappradar.com/blog/balancer-exploit-november-2025
- BIP-887 disable v2 factories, 2025-11-10 (passed 2025-11-18) — https://forum.balancer.fi/t/bip-887-transitioning-to-balancer-v3-disabling-v2-pool-factories/6874 ; Snapshot https://snapshot.org/#/s:balancer.eth/proposal/0x098cc33fe9b03a12d6a7ea4d6bb93439c11f122aba2641f64d6f8569aef0744e
- BIP-888 rETH gauge migration — https://forum.balancer.fi/t/bip-888-migrate-mainnet-reth-gauge/6877 ; BIP-896 — https://forum.balancer.fi/t/bip-896-rocket-pool-balancer-alliance-addendum/6904 ; BIP-898 — https://forum.balancer.fi/t/bip-898-migrate-mainnet-alcx-eth-80-20-gauge-and-core-pool-status-to-new-v3-pool/6906
- BIP-892 rescued funds, 2025-11-27 (voted 2025-12-12→16) — https://forum.balancer.fi/t/bip-892-distribution-of-rescued-funds-from-balancer-v2-november-3rd-2025-attacks/6883 ; execution PR https://github.com/BalancerMaxis/multisig-ops/pull/2557
- BIP-923 claim-window extension, 2026-07-23 — https://forum.balancer.fi/t/bip-923-next-phase-decision-for-rescued-funds-distribution-from-balancer-v2-november-2025-attacks/7091
- BIP-924 quorum / BIP-918 budget / BIP-919 buyback / BIP-920 veBAL comp — referenced inside BIP-928 text: https://forum.balancer.fi/t/bip-928-orderly-winddown-of-balancer-and-distribution-of-the-treasury/7107
- BIP-927 revoke relayer permissions, 2026-08-25 — https://forum.balancer.fi/t/bip-927-revoke-unused-v2-vault-permissions-from-deprecated-relayers/7099
- BIP-928 Orderly Winddown, 2026-09-14 (passed 2026-09-29) — https://forum.balancer.fi/t/bip-928-orderly-winddown-of-balancer-and-distribution-of-the-treasury/7107
- BIP-930 Balancer V1 recovery, 2026 — https://forum.balancer.fi/t/bip-930-distribution-of-recovered-funds-from-balancer-v1-august-31st-2026-exploit/7111
- Balancer Labs shutdown, 2026-03-23 — https://forum.balancer.fi/t/on-the-future-of-balancer-shutting-down-balancer-labs-supporting-the-path-forward/7002
- BIP-794 Hypernative pause module, 2025-01-20 — https://forum.balancer.fi/t/bip-794-enable-composable-stable-pool-pause-functionality-to-hypernative/6306
- BIP-585 CSPv6 factories/pause windows, 2024-04-05 — https://forum.balancer.fi/t/bip-585-enable-composablestablepool-v6-long-pause-windows/5688
- Balancer V3 here to stay, 2025-12-18 — https://medium.com/balancer-protocol/balancer-v3-here-to-stay-9ec37439b4be
- Docs: Vault API https://docs-v2.balancer.fi/reference/contracts/apis/vault.html ; exits https://docs-v2.balancer.fi/guides/builders/exit-pool.html ; emergency pause history https://balancer.gitbook.io/balancer-v2/security/emergency-pause ; V3 vault API https://docs.balancer.fi/developer-reference/contracts/vault-api.html
- Repos: https://github.com/balancer/balancer-v2-monorepo ; https://github.com/balancer/balancer-deployments ; https://github.com/maxyz-xyz/balancer-upscale-exploit-shares ; https://github.com/balancer/frontend-monorepo
- X posts: metastable rescue 2025-11-13 — https://x.com/Balancer/status/1988685056982835470 (first-disclosure and confirmation posts from @Balancer on 2025-11-03 are quoted by news outlets; direct status URLs not captured)

**Security firms / analyses**
- Certora, 2025-11-06 — https://www.certora.com/blog/breaking-down-the-balancer-hack
- Trail of Bits, 2025-11-07 — https://blog.trailofbits.com/2025/11/07/balancer-hack-analysis-and-guidance-for-the-defi-ecosystem/
- OpenZeppelin, 2025-11-07 — https://www.openzeppelin.com/news/understanding-the-balancer-v2-exploit
- Check Point, 2025-11-05 — https://research.checkpoint.com/2025/how-an-attacker-drained-128m-from-balancer-through-rounding-error-exploitation/
- BlockSec, 2025-11-06 — https://blocksec.com/blog/in-depth-analysis-the-balancer-v2-exploit
- SlowMist, 2025-11-06 — https://slowmist.medium.com/when-small-flaws-collapse-a-giant-inside-balancers-100m-hack-85b9e92a9ae3
- CertiK, 2025-11-25 — https://www.certik.com/blog/balancer-incident-analysis
- Coinspect, 2025-11-04 — https://www.coinspect.com/blog/balancer-rate-manipulation-exploit/
- Blockscope, 2025-11-12 — https://research.blockscope.co/balancer-exploit
- anomly.rs, 2025-11-03 — https://anomly.rs/balancer-bpt-batchswap
- Olympix, 2025-11-25 — https://olympix.security/blog/the-balancer-exploit-how-olympix-could-have-prevented-the-121m-loss
- Bearby, 2025-11-04 — https://blog.bearby.io/blog/balancer-v2-stable-pool-hack-2025/
- BlockSec 2023 linear-pool write-up — https://blocksec.com/blog/tiny-rounding-down-big-fund-losses-an-in-depth-analysis-of-the-recent-balancer-incident

**Wind-down / chain-level / press**
- coinpaprika, 2026-10-02 — https://coinpaprika.com/education/balancer-wind-down-vote-result/
- The Defiant, 2026-09-29/30 — https://thedefiant.io/news/defi/balancer-holders-approve-wind-down-reject-official-fork ; https://thedefiant.io/news/defi/balancer-sets-shutdown-dates-after-bal-holders-approve-wind-down
- cryptobriefing, 2026-09-14 — https://cryptobriefing.com/balancer-proposes-shutdown-treasury-distribution/
- ETHNews, 2026-09-15 — https://ethnews.com/balancer-wind-down-hands-bal-holders-the-treasury/
- Gnosis: specs commit 2025-12-15 — https://github.com/gnosischain/specs/commit/8c846abc1b511c85fbde1eb521526413f56347d8 ; forum 2025-12-12 — https://forum.gnosis.io/t/balancer-hack-hard-fork/11884 ; crypto.news 2025-12-23 — https://crypto.news/gnosis-chain-activates-hard-fork-to-recover-9-4m-frozen-during-balancer-exploit/ ; claim portal https://gnosis-balancer-claim.eth.limo/
- The Block, 2025-11-06 — https://www.theblock.co/post/377863/balancer-identifies-rounding-error-as-root-cause-of-multi-chain-defi-exploit
- Cointelegraph, 2025-12-23 — https://cointelegraph.com/news/gnosis-hard-fork-balancer-exploit
- Bitcoinist, 2025-11-08 — https://bitcoinist.com/balancer-message-128m-hacker-offers-bounty/
- DAO Radar / caper.network (BIP-923 quorum rerun details) — https://governance.alearesearch.io/item/f3c066bb-83c3-4190-b913-006f2756924d ; https://caper.network/wiki/daos/dexs/balancer-dao

---

## 8. Open questions / uncertainty register

1. **Complete drained-pool list** was never published in the post-mortem (placeholder link). BIP-892's recovery tables are the best available proxy, not necessarily the full drain list.
2. **Total stolen**: official $94.8M vs $121.1M vs third-party $116M/$128.64M/~$130M (incl. forks). Reconciliation unclear.
3. **CSPv6 unpause status**: no governance action found; assume paused/withdrawals-only, but on-chain `getPausedState()` checks are recommended for any pool you rely on. Same for `Vault.getPausedState()` on each chain.
4. **BIP-923/BIP-927 final passage** details (exact dates/quorum mechanics) come from secondary trackers; forum threads confirm the proposals, not the final tallies.
5. **Relayer advisories**: no public post-2025 vulnerability advisory; only permission-revocation hygiene (BIP-927). Absence of evidence, not evidence of absence.
6. **Gnosis/Berachain/Sonic/Avalanche attribution** (Balancer-deployed vs forks) is not fully disambiguated; fork losses (Beets, Bex) are separate from Balancer DAO pools.
7. The **Balancer V1 exploit of 2026-08-31** is a distinct event with its own recovery (BIP-930) and should not be conflated with V2.
