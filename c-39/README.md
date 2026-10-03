# C-39 — PulseX stack (PulseChain) — live extractability deep-dive

**Campaign:** zombie-hunt · **Chain:** PulseChain (chainid 369) · **Date:** 2026-10-03
**Status:** read-only research; all exploit/boundary checks executed on local forks only (and in CI). **No mainnet
transactions were sent.** PoC fork-verified in GitHub Actions.
**Scope:** PulseX V1 + V2 + StableSwap (~$51–61M live per DefiLlama/subgraphs, `audits=0`), plus the dormant
Pulse DEXes (9mm V2/V3, 9inch, Phux, SparkSwap, EazySwap, Velocimeter, WizardSwap, Dextop, PulseGun,
Function Island, Liberty Swap, pDex.vision, Finvesta).

## TL;DR

**An external, unprivileged attacker can currently extract ≈ $0 from the PulseX stack and the dormant Pulse DEXes.**
The stack is a set of faithful Uniswap-V2/Curve/Balancer/Uniswap-V3 forks with intact access control, no
unprotected initializers, no live mispricing, and no meaningful skim-able excess. The largest residual value
(feeTo's protocol-owned LP, ~0.3–3.8% of top pools) is behind an owner/authorized-EOA gate (P/S), and the only
"permissionless money" found on-chain is dust in scam tokens.

| # | Target | Chain | Live TVL | Live extractable (E-U) | Why closed today | Latent risk |
|---|---|---|---|---|---|---|
| 1 | PulseX V1 (`0x1715a3…`) | PulseChain | ~$29M (subgraph) | **$0** | Uniswap-V2 fork; `skim` excess only dust/scam tokens (full 255k-pair scan in CI); admin roles EOA-gated; pairs have no `migrator` | `_mintFee` denominator integer-division bug over-mints feeTo LP (protocol-side, P); feeToSetter EOA key = P |
| 2 | PulseX V2 (`0x29eA75…`) | PulseChain | ~$21M (subgraph) | **$0** | same as V1; V2 router holds 18.27 PLSX ($0.00014) with no sweep → stuck (S) | feeToSetter EOA key = P |
| 3 | PulseX StableSwap 3pool (`0xe3acfa…`) | PulseChain | ~$936k | **$0** | Curve-3pool fork; `onlyOwner` admin; no re-init; invariant uses internal balances | owner EOA key = P (admin fees, A/fee) |
| 4 | feeTo / BuyAndBurn proxies (`0xD46B…`, `0xd6cA…`) | PulseChain | protocol LP ≈ 0.3–3.8% of pools | **$0** | `convertLps` requires `anyAuth \|\| isAuth`; `anyAuth=false`, sole authorized = EOA; owner EOA | owner/authorized key = P/S; if `anyAuth` toggled, outsiders earn only the 0.1% conversion bounty |
| 5 | 9mm V3 (`$1.8M`) + 9mm V2 | PulseChain | ~$1.83M | **$0 found** | Uniswap-V3/V2 fork; positions are NFTs; factory owner EOA; no permissionless drain fn | owner key = P |
| 6 | Phux (Balancer V2 fork) | PulseChain | ~$1.10M | **$0** | Nov-2025 Balancer rounding exploit needs non-unitary `_scalingFactors`; **60/60 pools return factors % 1e18 == 0** (no rate providers) ⇒ `_upscale` truncation exact | if governance attaches a non-unitary rate provider → re-opens class bug (P) |
| 7 | 9inch | PulseChain | ~$273k | **$0** | Uniswap-V2 fork + MasterChefV2: `withdraw` requires own `user.amount`; `emergencyWithdraw` self-scoped; admin `onlyOwner` (EOA) | owner key = P |
| 8 | Finvesta / SparkSwap / EazySwap / Dextop / pDex.vision / Function Island / Velocimeter | PulseChain | ~$4k–91k each | **$0 found** | V2/V3 forks; no excess; distributors/farms self-scoped | owner keys = P |
| 9 | Liberty Swap | PulseChain | apparent $28.8B (fake) | **$0 from DEX** | GT reserve is a fake-price artifact: BXUSD pools hold only 37.8 DAI + 96.6 USDC + 274.5 USDT ≈ **$410** real stable side; BXUSD is a third-party token (owner EOA) | third-party BXUSD token risk (~$410), not a DEX bug |
| 10 | WizardSwap / PulseGun | PulseChain | 0 | n/a | no live pools | — |

**Total live extractable now (E-U): ≈ $0.** Confidence: **high** for the PulseX stack (V1/V2/StableSwap/roles);
**medium-high** for the dormant venues (top pools + farms + role contracts checked; long-tail low-TVL contracts
not exhaustively enumerated).

---

## 1. What was actually audited (exact terms)

### 1.1 PulseX V1/V2 = Uniswap V2 forks with a 0.29% fee and a protocol-LP mechanism
- Factories: V1 `0x1715a3E4A142d8b698131108995174F37aEBA10D` (65,403 pairs), V2
  `0x29eA7545DEf87022BAdc76323F373EA1e707C523` (189,582 pairs); both verified (`PulseXFactory`, solc 0.5.16).
- Pair code (verified, same file): standard `PulseXPair` — `lock` modifier on `mint/burn/swap/skim/sync`;
  swap fee `amountIn*29/10000` (0.29%); **no `migrator()`** (reverts on-chain); `initialize()` factory-gated.
- `_mintFee`: both factories have `feeTo` set, so `feeOn=true`. **V1 bug:** denominator is
  `rootK.mul(uint(4998)/uint(10000)).add(rootKLast)` and `4998/10000 == 0` in Solidity, so denominator =
  `rootKLast`; feeTo is minted `totalSupply*(rootK−rootKLast)/rootKLast` instead of Uniswap's 1/6-growth rule.
  V2 fixed the expression to `rootK.mul(22)/7 + rootKLast` (7/29 growth). This transfers value from LPs to
  **feeTo** (protocol), not to an attacker — see §4.
- Routers: V1 `0x98bf93eb…`, `0xaf5e33cb…` (identical function sets; both use 9971/10000), V2 `0x165C3410…`.
  No privileged/withdraw functions; standard Uniswap-V2 router surface.

### 1.2 feeTo = PLSXBuyAndBurn (UUPS proxy), `convertLps` gate
- Both feeTo addresses are ERC-1967 proxies → impl `0x5f02fbb0f8d924e9b67c7daae523ff51175699f9`
  (`PLSXBuyAndBurnUpgradeable`, verified). `convertLps()` burns feeTo-held LP, converts to PLSX, burns it,
  pays the caller `BOUNTY_FEE=10` (0.1%).
- Live (block 27,702,157): `anyAuth=false`; `isAuth(owner)=false`; `authorized(0)=0x30e22ab6…` (EOA, code size 0).
  An arbitrary caller reverts `PLSXBuyAndBurn: FORBIDDEN`. `setDevAddr` is owner-or-current-dev gated;
  `devCut=1429` (14.29%) to devAddr EOA `0x323971…`.

### 1.3 PulseX StableSwap = Curve 3pool fork
- `PulseXStableSwapThreePool` `0xe3acfa6c40d53c3faf2aa62d0a715c737071511c` (verified, solc 0.8.10):
  USDT/USDC/DAI, `A=1000`, `fee=4e6` (0.04%), `admin_fee=5e9` (50%), near-balanced balances (336.1k/276.5k/323.9k
  ≈ $936k). `initialize` is one-shot + POOL_DEPLOYER-gated; all admin functions `onlyOwner`
  (`0x73a08E51…`, EOA). No permissionless value-moving path; invariant uses internal balances (no donation attack).

### 1.4 Dormant venues
See `analysis/dormant/README.md` for per-venue evidence. Highlights:
- **Phux** is a Balancer V2 fork (`Vault` verified). The Nov-2025 $128M Balancer rounding exploit requires a
  `ComposableStablePool` with **non-unitary** scaling factors (exchange-rate × decimals) where
  `_upscale=mulDown` truncates. All 60 live Phux pools return `getScalingFactors()` values divisible by 1e18;
  the stable pool's rate providers are all `0x0`. ⇒ The inherited bug is **not exploitable on Phux today**.
- **9inch** MasterChefV2 (`0x444775Ae…`, verified): `withdraw` checks `user.amount >= _amount`;
  `emergencyWithdraw` self-scoped; all admin fns `onlyOwner` (EOA).
- **Liberty Swap BXUSD pools**: on-chain real stablecoin side ≈ $410; GT's $9.6B is fake BXUSD pricing.

## 2. Live-state assessment (all values at pinned blocks)

Block 27,701,912–27,702,157 (2026-10-03). Full machine-readable dump: `analysis/live_state.json`.
Key addresses/roles/balances are listed in the TL;DR table and in `analysis/roles/README.md`,
`analysis/stableswap/README.md`, `analysis/pools/README.md`, `analysis/dormant/README.md`.

Top-pair sanity (balances == reserves exactly at pinned block, both factories):
V1 PLSX/WPLS, HEX/WPLS, USDC/WPLS, DAI/WPLS, WETH/WPLS; V2 DAI/WPLS, HEX/WPLS, WETH/WPLS, WPLS/PLSX.
`migrator()` reverts on all sampled pairs (function absent). Permit domain includes `chainid`.

## 3. What an attacker can/cannot do — exact call paths

| Path | Precondition | Result |
|---|---|---|
| `pair.skim(attacker)` on pairs with excess | balance > reserve on both sides | pays the excess. Top-2000 + pinned 600-pair scans: **only scam-token dust**; full 255k-pair scan in CI (`ci-out/skim_scan_full.json`) |
| `pair.swap(...)` mispricing via FOT/rebasing | balance < reserve (deficit) | **0 deficit pairs found** in top-2000 and pinned scans |
| `feeTo.convertLps(...)` | `anyAuth==true` or `isAuth[msg.sender]` | live `anyAuth=false`, isAuth=EOA ⇒ reverts `FORBIDDEN` |
| `factory.setFeeTo(...)` | `msg.sender == feeToSetter` | feeToSetter is an EOA ⇒ P |
| `stable.exchange(...)` for profit | pool mispricing | dy for 10k USDC→USDT ≈ 9,996 (fee only); no arb; fork test |
| Phux `batchSwap` rounding exploit | non-unitary scaling factors | all factors divisible by 1e18 ⇒ exact |
| 9inch MCV2 `withdraw/emergencyWithdraw` | own stake only | outsider reverts / receives 0; fork test |
| 9mm V3 pool drain | — | no permissionless drain; factory owner EOA (P) |

Costs: no flash-loan-dependent path was found at all, so gas/flash fees are moot; every candidate above either
reverts for an outsider or pays ≤ dust.

## 4. Verdict, residual & latent risk

- **E-U: ≈ $0** (headline). Nothing found that an unprivileged caller can turn into net profit.
- **P (privileged):** feeTo LP (protocol-owned, 0.3–3.8% of pools), fee config, BuyAndBurn owner/authorized,
  stable-pool admin fees, factory owners. All behind EOAs (key-risk, not permissionless).
- **S (stuck):** V2 router's 18.27 PLSX ($0.00014) — no sweep function; pairs' dust scam-token excess is
  technically skim-able but effectively worthless.
- **H-O:** LP/stakers can withdraw normally (routers, MasterChefV2, distributors).
- **Latent risk worth monitoring:**
  1. V1 `_mintFee` bug over-mints feeTo LP (LP dilution → protocol). If `anyAuth` is ever toggled, the 0.1%
     conversion bounty becomes permissionless (still not theft).
  2. feeToSetter/feeTo-owner/devAddr/stable-owner/factory-owner are single EOAs; key compromise re-routes
     protocol value (P class).
  3. Phux: attaching any non-unitary rate provider to a ComposableStablePool re-arms the Balancer rounding
     exploit class (P→E-U transition).
  4. Balancer V2 forks elsewhere on PulseChain should be checked for non-unitary scaling factors; Phux is clean.

## 5. PoC / fork verification (CI)

- Foundry project: `poc/` (vendored forge-std). Tests: `poc/test/PulseXC39.t.sol` (PulseX core, 10 tests),
  `poc/test/DormantVenues.t.sol` (Phux/9inch/9mm/Liberty, 4 tests).
- Fork: `vm.createSelectFork(vm.envOr("PULSECHAIN_RPC", "https://pulsechain-rpc.publicnode.com"))`;
  `ci/run.sh` probes `pulsechain-rpc.publicnode.com`, `rpc.pulsechain.com`, `rpc-pulsechain.g4mm4.io` and exports
  `PULSECHAIN_RPC` for the test job.
- Heavy job: `ci/full_skim_scan.py` — enumerates **all 254,985 pairs** (V1+V2) via Multicall3 at one pinned
  block, flags excess/deficit, then `ci/price_flagged.py` prices flagged tokens (DefiLlama) and simulates `skim`.
- CI runs:
  - run 1 (full scan + core tests): https://github.com/kingmariano/ca-zombie-ci/actions/runs/37115764521
  - run 2 (updated tests incl. dormant venues): _to be recorded after run 1_
- Test results / key numbers: see `ci-log.txt`, `ci-out/skim_scan_full.json`,
  `ci-out/flagged_excess_priced.json` (downloaded via `ci-artifacts/`).

## 6. Methodology & sources

1. Address discovery: DefiLlama adapter graph endpoints (`graph.pulsechain.com/subgraphs/name/pulsechain/{pulsex,pulsexv2,stableswap}`),
   GeckoTerminal `networks/pulsechain/dexes/*/pools`, Blockscout API `api.scan.pulsechain.com`
   (`/api/v2/search`, `/smart-contracts/{addr}`, `/tokens/{addr}/holders`).
2. Code verification: verified sources pulled from Blockscout (factories, routers, pair (embedded), stable pool,
   feeTo impl, MasterChefV2, Phux Vault/ComposableStablePool); compiled pair/factory sources inspected directly.
3. Live state: `cast call` at explicit pinned blocks; balances vs reserves compared in pinned-block batches;
   Multicall3 for full-population scan.
4. Pricing: DefiLlama `coins.llama.fi`, GeckoTerminal token endpoints (note: GT/Superchain prices for
   copy-tokens can be misleading — e.g. the PulseChain fork-copy "DAI" trades at $0.00165 while bridged
   "DAI from Ethereum" is $1.00; BXUSD pools show fake $9.6B reserves).
5. Incident research: Balancer Nov-2025 post-mortems (Check Point, OpenZeppelin, Trail of Bits) to derive the
   exact exploit precondition checked against Phux.

### Caveats & limitations
- Fork tests depend on public PulseChain RPC availability from GitHub runners; results pinned by block where noted.
- The full-population skim scan is CI-only; local runs covered top-2,000 by subgraph TVL + a pinned 600-pair sample.
- Dormant-venue coverage is top-pools + identified farms/gauges/distributors; low-TVL long-tail contracts
  (<$1k) were not exhaustively enumerated.
- USD values use DefiLlama/GT prices at the stated time; PulseChain copy-token prices are volatile/illiquid.
- "No permissionless path found" is not a proof of absence for un-audited code; it is a strong, documented
  negative result over the enumerated surface.

### Files index
```
c-39/
├── README.md                  ← this file
├── summary.json               ← machine-readable headline
├── analysis/
│   ├── CONTEXT.md             shared recon context
│   ├── live_state.json        pinned-block state dump (factories/roles/stable/top pairs)
│   ├── snapshot.py            generates live_state.json
│   ├── pools/                 pair excess scan (top-2000 + pinned), scripts, README
│   ├── roles/                 feeTo/BuyAndBurn/router/roles analysis
│   ├── stableswap/            Curve-3pool audit
│   └── dormant/               secondary venues: GT data, pool scan, per-venue findings
├── poc/                       Foundry project (Interfaces, PulseXC39.t.sol, DormantVenues.t.sol, forge-std)
├── ci/
│   ├── run.sh                 RPC probe + full skim scan + pricing
│   ├── full_skim_scan.py      all-pairs Multicall3 scan
│   └── price_flagged.py       price + skim-sim flagged pairs
├── ci-out/                    CI job outputs
├── ci-log.txt / ci-artifacts/ downloaded after CI runs
└── src_*.sol                  verified source dumps (factories, routers, stable, feeTo impl, pair)
```
