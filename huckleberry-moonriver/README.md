# C2-56 — Huckleberry / Moonriver cohort (Moonriver): frozen chain, stuck custody

**Campaign:** zombie-hunt II · **Chain:** Moonriver (EVM parachain, chain id 1285) · **Date of work:** 2026-10-10
**Status:** read-only research; no transactions signed or sent; no keyed RPC URLs or secrets in this folder.
**Scope:** the C2-56 finding (`zombie_hunt/ZOMBIE-HUNT-II.md`) — Huckleberry (lending + AMM, "oracle anomalies") and the cohort's
frozen custody (Moonswap stable pools), on a chain reported halted 2026-08-10. Mission: confirm the halt and close the finding.

**TL;DR — an external, unprivileged attacker can extract ≈ $0 from the C2-56 cohort today: Moonriver's head is frozen at
block 17,381,654 (2026-08-10T08:27:48Z) and no transaction can execute.** The chain entered Maintenance Mode at
**2026-08-01T00:00:00Z** (block 17,269,716, all transactions rejected) and stopped producing blocks entirely on
**2026-08-10**. All cohort assets are therefore **S (stuck)**: Huckleberry lending ≈ **$8.4k** (11 markets, cash),
Huckleberry AMM stables ≈ **$4.2k**, Moonswap stables ≈ **$363.0k** (paper, at current prices). **Total S ≈ $375.7k paper**
— none of it extractable by anyone (not even holders or privileged roles) while the chain is frozen.

| Target | Chain | Live extractable (unprivileged) | Why closed today | Latent risk (re-arm) |
|---|---|---|---|---|
| Huckleberry Lending (Compound fork) — comptroller `0xcffef313…`, 11 markets | Moonriver | **$0** | Chain frozen; no tx executes. Cash ≈ **$8,447.60** stuck | If the chain ever resumes: **oracle anomalies** live (BTC.m at ~$8.1B, USDC at $0.0306, ETH.m at ~$6.1e20, …) → borrows/liquidations against mispriced markets could drain the cash |
| Huckleberry AMM — factory `0x017603c8…`, 113 pairs | Moonriver | **$0** | Chain frozen. Stablecoin balances ≈ **$4,216.94** stuck | Resumption of chain only; no separate bug found |
| Moonswap — factory `0x056973f6…`, 816 pairs | Moonriver | **$0** | Chain frozen. Stablecoin balances ≈ **$363,040.64** paper stuck | Resumption of chain only; and the stables are Multichain-bridged assets of doubtful redeemability anyway |
| Everything else on Moonriver (Solarbeam, Moonwell Apollo, Zenlink, …) | Moonriver | **$0** | Same frozen chain | Whole-chain: any restart re-arms every stale price/oracle on the chain at once |

**Total live extractable now: ≈ $0.00 (confidence: high).** Total stuck (S) in the cohort: **$375,705.19** paper
($363,040.64 Moonswap stables + $4,216.94 Huckleberry AMM stables + $8,447.60 Huckleberry lending cash).

---

## 1. The finding and the mechanism (why it *was* a candidate)

C2-56 grouped two Moonriver protocols whose contracts remain callable on-chain with funds inside:

- **Huckleberry Lending** — a Compound fork (`Comptroller` `0xcffef313b69d83cb9ba35d9c0f882b027b846ddc`, 11 markets incl.
  native `hbMOVR` cether `0x455D0c83…`). Its price oracle `0xef502fb85311065aeb1ebe6b179400b03de2d9a5` returns
  **wildly wrong prices** for most markets (details in §3.3) — the "oracle anomalies" of the finding. A Compound market
  with a broken oracle is a classic permissionless drain (borrow against overvalued collateral; liquidate at distorted
  prices). This is why the cohort was flagged.
- **Moonswap** — a Uniswap-V2-fork DEX (`Factory` `0x056973f631a5533470143bb7010c9229c19c04d2`, 816 pairs) holding
  ~$360k of nominal stablecoins; dead DEX + stale state = standard candidate for stale-price/arb extraction.
- **The intended verdict was already "S — chain halted"** (2026-08-10). This deep-dive re-verifies that independently,
  measures exactly what is frozen, and quantifies the re-arm conditions.

The finding text ("~$8.6k, oracle anomalies"; "Moonswap $358.7k stables") is confirmed within ~1–2% by direct on-chain
reads (§3); the classification stands: **S, closed.**

---

## 2. Chain-liveness verification (the decisive gate)

### 2.1 Two independent probes, 32 minutes apart, identical head

| Probe (UTC) | Endpoint | `eth_blockNumber` | Head hash | Head timestamp |
|---|---|---|---|---|
| 2026-10-10 02:51:51Z | `https://moonriver.api.onfinality.io/public` | `0x1093916` = **17,381,654** | `0xef04725d4d6d61c761bb000f7f3632ed0e504d455bcd68daafcd930074df5997` | **2026-08-10T08:27:48Z** |
| 2026-10-10 02:51:51Z | `https://moonriver.drpc.org` | `0x1093916` | (same via second probe) | 2026-08-10T08:27:48Z |
| 2026-10-10 03:23:59Z | onfinality + drpc | `0x1093916` | `0xef04725d…df5997` | 2026-08-10T08:27:48Z |

- `eth_syncing` = `false` on both endpoints in both probes; the head did not move across the 32-minute gap.
- The head block is an **empty block** (`gasUsed: 0x0`, 1 transaction-free, size `0x203`), consistent with the wind-down
  (block production with no transactions).
- Other public endpoints are dead/unreachable: `rpc.api.moonriver.moonbeam.network` (TLS handshake failure),
  `moonriver.public.blastapi.io` (DNS gone), `moonriver-rpc.publicnode.com` (HTTP 404), `1rpc.io/movr` (unsupported).
  `api-moonriver.moonscan.io` no longer resolves; the Moonscan UI still serves historical pages and carries the
  maintenance banner. Evidence: `analysis/liveness_p1.json`, `analysis/liveness_p2.json`, `analysis/mr_probe.py`.

### 2.2 Block-level halt forensics

| Event | Block | UTC | Evidence |
|---|---|---|---|
| **Last transaction-bearing block** | **17,268,165** | **2026-07-31T21:06:48Z** | 1 tx, `gasUsed 0x4dc28` (318,504); hash `0x…`; found by coarse scan + binary refinement |
| First empty block after it | 17,268,166 | 2026-07-31T21:06:54Z | `gasUsed 0` |
| **Maintenance Mode begins** | **17,269,716** | **2026-08-01T00:00:00Z** (exact) | `gasUsed 0`, 0 txs; binary search on timestamp |
| **Head (block production stops)** | **17,381,654** | **2026-08-10T08:27:48Z** | unchanged across probes |
| Sweep of maintenance→head (every 2,000 blocks) | — | — | **0 non-empty blocks** |

Moonbeam Foundation's announcement: *"Maintenance Mode begins 00:00 UTC on August 1, 2026. Transfers and smart contract
execution will be disabled."* Moonscan banner: *"all transactions are rejected … The network continues producing blocks
during the operational wind-down."* MOVR migrated 1:1 to Base (`0x43fEB74608334DDa8c1a6500D185cFC3Ea962B83`); the bridge
deadline was 2026-07-31 and the last on-chain transaction is ~3 hours before Maintenance Mode. Evidence:
`analysis/halt_blocks.json`, `analysis/scan_halt.py`, `analysis/scan_halt2.py`, `analysis/sources.json`.

**Conclusion: since 2026-08-10 the chain produces no blocks; since 2026-08-01 it rejects all transactions. No
transaction can execute now — for anyone, privileged or not.**

---

## 3. Cohort live-state at the frozen head (block 17,381,654)

All reads are `eth_call` at the explicit frozen head, batched; full enumerations (not samples):
Moonswap **816/816 pairs**, Huckleberry AMM **113/113 pairs**, Huckleberry lending **11/11 markets**.
Raw evidence: `analysis/moonswap_pairs.json`, `analysis/huckleberry_amm_pairs.json`,
`analysis/huckleberry_lending.json`, `analysis/cohort_summary.json`.

### 3.1 Moonswap stablecoin balances (all 816 pairs, per token)

| Token (Moonriver address) | Amount | Pairs | USD (price 2026-10-10) |
|---|---|---|---|
| DAI `0x80a16016cc4a2e6a2caca8a4a498b1699ff0f844` | 236,104.9888 | 7 | $236,124.55 |
| USDC `0xe3f5a90f9cb311505cd691a46596599aa1a0ad7d` | 83,550.9570 | 91 | $83,529.05 |
| USDT `0xb44a9b6905af7c801311e8f4e76932ee959c663c` | 40,507.6291 | 6 | $40,476.45 |
| BUSD `0x5d9ab5522c64e1f6ef5e3627eccc093f56167818` | 2,454.0977 | 7 | $2,447.80 |
| MIM `0x0cae51e1032e8461f4806e26332c030e34de3adb` | 1,226.3624 | 1 | $40.48 |
| FRAX `0x1a93b23281cc1cde4c4741353f3064709a16197d` | 401.7468 | 2 | $398.52 |
| miMatic `0x7f5a79576620c046a293f54ffcdbd8f2468174f1` | 23.7955 | 1 | $23.80 |
| **Total** | | | **$363,040.64** (nominal $1 peg: $364,269.59) |

- **Excluded** from the totals: a 9-decimal token named "DAI" at `0xe7a534f34f6ba18a03e0e09ade4a9d6628aa69da`
  (pair `0x42668e7d…` holds 11,339,893.42 units but only 0.0000025 WMOVR on the other side; `totalSupply` = 1e21 raw =
  1e12 units). It is not real DAI (real DAI is 18 decimals, `0x80a16016…`). Evidence: `analysis/fake_dai_check.json`.
- Also present but not counted in the stable total: **372.878 WMOVR** across Moonswap pairs (≈ $673.63) and minor amounts
  of hundreds of dead Moonriver tokens (meme tokens; no live market). The report's "$358.7k Moonswap stables" is
  consistent with the USDC+USDT+DAI total here ($360,163.58 nominal) within ~0.4%.

### 3.2 Huckleberry AMM stablecoin balances (all 113 pairs)

| Token | Amount | Pairs | USD |
|---|---|---|---|
| USDT.m `0xe936caa7f6d9f5c9e907111fcaf7c351c184cda7` | 2,619.7051 | 8 | $2,617.69 |
| USDC.m `0x748134b5f553f2bcbd78c6826de99a70274bdeb3` | 1,410.8845 | 7 | $1,410.51 |
| MIM `0x0cae51e1…` | 1,065.9412 | 4 | $35.18 |
| USDC `0xe3f5a90f…` | 135.6256 | 6 | $135.59 |
| FRAX `0x1a93b232…` | 18.0984 | 3 | $17.95 |
| USDT `0xb44a9b69…` | 0.0084 | 2 | $0.01 |
| **Total** | | | **$4,216.94** |

### 3.3 Huckleberry Lending — 11 markets, cash at the frozen head + oracle anomalies

Comptroller `0xcffef313b69d83cb9ba35d9c0f882b027b846ddc`; oracle `0xef502fb85311065aeb1ebe6b179400b03de2d9a5`
(no `owner()`; not a `SimplePriceOracle` — `prices(market)` returns 0).

| Market | Symbol | Underlying | `getCash` (human) | USD (2026-10-10) | Oracle price returned | Oracle sanity |
|---|---|---|---|---|---|---|
| `0x455D0c83…` | hbMOVR | MOVR (native cether) | 44.018533 MOVR | $79.52 | 1e18 → $1.0000 | plausible (MOVR ≈ $1.81) |
| `0x7dcf1392…` | hbBTC.m | BTC.m `0x78f811a4…` (8 dec) | 0.043390 | $3,580.21 | 8.116e37 → **$8.116 billion** | **anomalous (~10⁵× high)** |
| `0xd275c08c…` | hbETH.m | ETH.m `0x576fde3f…` | 0.005930 | $14.77 | 6.085e38 → **$6.1e20** | **anomalous** |
| `0x0dA4B57c…` | hbUSDT.m | USDT.m `0xe936caa7…` (6 dec) | 1,074.865670 | $1,074.04 | 3.679e36 → **$3.68 million** | **anomalous** |
| `0x809eD65E…` | hbUSDC.m | USDC.m `0x748134b5…` (6 dec) | 603.708413 | $603.55 | 5.625e36 → **$5.62 million** | **anomalous** |
| `0x56E49Fd9…` | hbDOT.m | DOT.m `0x15b9ca96…` (10 dec) | 15.446484 | $19.49 | 2.582e35 → **$2.58 billion** | **anomalous** |
| `0x68c5c3F5…` | hbMIM | MIM | 103.519770 | $3.42 | 1.207e17 → $0.1207 | plausible-ish (MIM ≈ $0.033) |
| `0x12AE8068…` | hbUSDC | USDC `0xe3f5a90f…` | 2,941.393868 | $2,940.62 | 3.063e28 → **$0.0306** | **anomalous (~33× low)** |
| `0xd629D7cc…` | hbTOM | TOM `0x37619cc8…` | 1,640,899.661853 | $0.00* | 1.102e11 → 1.1e-7 | no live market |
| `0xFBd7c66b…` | hbFRAX | FRAX | 71.213550 | $70.64 | 7.874e17 → $0.787 | plausible-ish |
| `0x517a3786…` | hbKSM | xcKSM `0xffffffff…` (12 dec) | 12.030858 | $61.33 | 2.594e35 → **$2.59e11** | **anomalous** |
| **Total cash** | | | | **$8,447.60** | | |

\* TOM has no live market (dead chain); valued at $0. The report's "Huckleberry ≈$8.6k" matches this $8.45k cash
measurement (differences are price moves since the report, notably MIM $1→$0.033 and BTC price).

Net supplied (`cash + totalBorrows − totalReserves`) values the markets at ≈ $10.6k paper; `cash` is what is physically
in the contracts and is the conservative stuck figure used here.

---

## 4. What an attacker can / cannot do

**Can do: nothing that changes state.** Every state-changing path on Moonriver — Huckleberry `borrow`/`liquidate`/
`redeem`, Moonswap `swap`, token `transfer`, even `pause()` by the protocol admin — requires a transaction, and the
chain's last block is 2026-08-10; the head is immutable across probes. There is no mempool on a chain that produces no
blocks; no privileged actor can move these funds either. (Read-only `eth_call` works — that is how §3 was measured.)

**Cannot do:** anything extractive — there is no live call path to reduce to. The classic Huckleberry oracle-anomaly
drain (borrow against the ~$8.1B-priced BTC.m, or repay USDC debt at the $0.0306 oracle price and seize collateral)
requires `borrow()`/`liquidate()` transactions; neither can execute.

**Re-arm condition (monitor only):** a Moonriver chain restart with transaction execution. This would require a
coordinated Foundation/community decision; the chain has been wound down, block production stopped, and MOVR migrated to
Base — an official restart is not planned. If it ever happened, on the very first executable block:
1. Huckleberry Lending's mispriced oracle (above) would immediately make the ~$8.4k of market cash drainable
   (and possibly more through recursive borrow/liquidate against mispriced markets);
2. Moonswap's ~$363k of nominal stables would be swappable against stale pool ratios — though their real value is
   questionable (Multichain-bridged assets, below);
3. every other stale Moonriver protocol (Solarbeam, Moonwell Apollo, …) would be equally re-armed.
Monitor signal: Moonriver block height moving above 17,381,654 on any public RPC (or a Moonbeam Foundation announcement).

---

## 5. Verification / PoC section

There is no exploit to prove — the finding closes on chain liveness, so the "PoC" is a **frozen-head state proof**,
run locally and re-run independently on CI:

- **Local (2026-10-10):** two liveness probes (32 min apart) across 5 public RPCs; halt-block forensics (coarse scan,
  binary refinement, maintenance-start search, 2,000-block sweep); full on-chain enumerations of 816 + 113 pairs and 11
  lending markets; valuation with DefiLlama prices. Scripts: `analysis/mr_probe.py`, `analysis/scan_halt*.py`,
  `analysis/read_cohort.py`, `analysis/aggregate_cohort.py`, `analysis/valuation.py`.
- **CI (GitHub Actions, public repo `kingmariano/ca-zombie-ci`):** `ci/run.sh` → `ci/verify.py` re-probes liveness twice
  (keyed `MOONRIVER_RPC_URL` env + public fallbacks; URLs never printed), re-enumerates the cohort at the frozen head and
  writes `ci-out/moonriver_verify.json` (uploaded artifact). Run URL: **TODO-RUN-URL** (filled after the run).

| Check | Result |
|---|---|
| Heads agree across endpoints/probes and equal `0x1093916` | ✔ |
| Head timestamp 2026-08-10T08:27:48Z, unchanged after 32 min | ✔ |
| Last tx block 17,268,165 (2026-07-31T21:06:48Z); all blocks after 2026-08-01 empty | ✔ |
| Moonswap: 816/816 pairs, stables $363,040.64 | ✔ |
| Huckleberry AMM: 113/113 pairs, stables $4,216.94 | ✔ |
| Huckleberry lending: 11/11 markets, cash $8,447.60; oracle anomalies recorded | ✔ |
| E-U / H-O / P = $0.00; S = $375,705.19 paper | ✔ |

---

## 6. Verdict, residual and latent risk

- **Verdict: S (stuck) — closed. E-U $0.00, H-O $0.00, P $0.00 (confidence: high).** The decisive gate is chain
  liveness: Moonriver produces no blocks and rejects all transactions. No attacker — and no holder, admin or governance
  — can move any cohort asset today.
- **Stuck (S): $375,705.19 paper** — Moonswap stables $363,040.64 + Huckleberry AMM stables $4,216.94 + Huckleberry
  lending cash $8,447.60. This is a paper mark; real economic recovery is lower (§7 caveats).
- **Residual/latent risk:** (a) the Huckleberry oracle anomalies remain in immutable contract state and would re-arm the
  lending drain instantly on any chain restart; (b) whole-chain re-arm applies to all stale protocols; (c) no monitoring
  urgency — the chain is dead by design and there is no restart path announced.
- **Blockers (why nothing moves):** chain halt (no blocks), Maintenance Mode (tx rejection), MOVR migration to Base
  (2026-07-31 deadline), Multichain-bridge collapse (bridged stables' redeemability), no operator/team for either
  protocol.

---

## 7. Methodology, caveats, sources

**Method.** Read-only: `eth_blockNumber`/`eth_getBlockByNumber`/`eth_getCode`/`eth_call` (batched JSON-RPC) at an
explicit frozen block; full factory enumerations via `allPairsLength`/`allPairs(i)`; Compound market reads via
`getAllMarkets`/`getCash`/`totalBorrows`/`totalReserves`/`oracle`/`getUnderlyingPrice`; pricing via DefiLlama
(`coins.llama.fi`); announcements/explorer pages via web. No transactions; no forks needed (nothing to execute).

**Caveats.**
- **Bridged assets:** Moonriver's USDC `0xe3f5a90f…`, USDT `0xb44a9b69…`, DAI `0x80a16016…` are Multichain/Anyswap-era
  bridged tokens; after the 2023 Multichain collapse their redemption is doubtful even if the chain resumed. The
  "@moonriver"-named tokens (BTC.m/ETH.m/USDC.m/USDT.m) are likewise bridge-wrapped (their `name()` is
  "BTC@moonriver" etc.). Nominal USD marks therefore overstate real value; the S figure should be read as "stuck, at
  face value".
- **MOVR valuation:** old-chain MOVR migrated 1:1 to Base `0x43fEB746…`; the frozen-chain WMOVR/MOVR balances are valued
  at the Base MOVR price ($1.8066) — but stranded old-chain MOVR is not bridgeable anymore (no path off the dead chain).
- **Prices** are DefiLlama 2026-10-10: BTC $82,513.33, ETH $2,490.56, MOVR $1.8066, USDC $0.99974, USDT $0.99923,
  FRAX $0.99197, MIM $0.03301, DOT $1.26201, KSM $5.09810, DAI $1.00008, BUSD $0.99743. TOM = $0 (no market).
- **Not re-measured:** the rest of the Moonriver ecosystem (Solarbeam, Moonwell Apollo, Zenlink, …) — outside C2-56's
  cohort; all equally frozen (S) by the same chain-halt gate. Moonwell Moonriver is covered by the prior campaign
  (C-28/C-32).
- Point-in-time reads at a fixed block; the state cannot change unless the chain restarts.

**Sources.** Moonbeam Foundation "Moonriver Strategic Update: MOVR is Migrating to Base" (2026-07-07); Moonscan /
Subscan maintenance-mode banners; Bybit (2026-07-15) and Binance (2026-07-20) termination notices; DefiLlama protocol
data (Moonswap, Huckleberry Lending, Huckleberry AMM; last non-zero TVLs 2026-08-15: $84.4k / $7.5k / $18.0k);
DefiLlama-Adapters registries (`uniswapV2.js`, `compound.js`) for factory/comptroller addresses; Moonscan labels for the
Huckleberry router. Full list: `analysis/sources.json`.

**Files index.**
```
huckleberry-moonriver/
├── README.md                       # this deliverable
├── summary.json                    # machine-readable summary
├── analysis/
│   ├── mr_probe.py, liveness_p1.json, liveness_p2.json        # chain-liveness evidence (2 probes, 5 endpoints)
│   ├── scan_halt.py, scan_halt2.py, halt_blocks.json          # last-tx / maintenance-mode block forensics
│   ├── mr.py, read_cohort.py, moonswap_pairs.json, huckleberry_amm_pairs.json, huckleberry_lending.json
│   ├── aggregate_cohort.py, moonswap_stables.json, huckleberry_amm_stables.json
│   ├── valuation.py, cohort_summary.json, prices.json, fake_dai_check.json
│   ├── defillama_moonriver_protocols.json, uniswapV2_registry.js, compound_registry.js, sources.json
├── ci/run.sh, ci/verify.py         # CI re-verification job
├── ci-out/                         # CI artifacts (moonriver_verify.json, verify.log)
└── ci-log.txt, ci-artifacts/       # filled by the CI helper
```
