# H2-02 — V3-fork / small-chain cluster dossier (parent-owned)

**Status:** read-only; fork-verified gates only; no mainnet transactions.
**Date:** 2026-10-10. **Chains:** HyperEVM (999), BSC (56), MegaETH (4324→4326), Flow EVM (747), Abstract (2741), XDC (50).
**Scope:** HyperSwap V3, Kinza, Kumbaya, KittyPunch, Aborean, Fathom — the "V3-fork pools on under-monitored
chains, $1–3.6M each" group of H2-02. Coverage for all six is **screened** (live state + admin gates +
representative math checks); HyperSwap V3 pool code additionally source-audited against canonical Uniswap
v3-core v1.0.0. None of these were exhaustively position/liquidation-enumerated — that is stated per protocol.

---

## 1. HyperSwap V3 (HyperEVM) — DefiLlama TVL $11.08M

**Live state** (HyperEVM block 48,164,311–48,167,000):
- Factory `0xB1c0fa0B789320044A6F623cFe5eBda9562602E3` (verified source, solc 0.7.6, `HyperswapV3Factory`).
- Factory **owner = `0xBC7e493fd3ed834eD563f9597AAAED94e446bBc7` — an EOA (zero code)**. Can `setOwner`,
  `enableFeeAmount`, and (as pool `onlyFactoryOwner`) `setFeeProtocol`/`collectProtocol`.
- Pools are created per `PoolCreated`; major sampled pools and balances at the block above:
  | Pool | Pair / fee | token0 | token1 |
  |---|---|---|---|
  | `0xe712D505…23c9` | WHYPE/USDC 0.30% | 4,675.30 WHYPE | 348,538.13 USDC |
  | `0x337b56d8…0C30` | WHYPE/USD₮0 0.05% | 3,752.60 WHYPE | 233,872.83 USD₮0 |
  | `0x56aBfaf4…4508` | WHYPE/USD₮0 0.30% | 532.85 WHYPE | 51,902.44 USD₮0 |
  | `0x55443b2A…5356` | USDC/USD₮0 0.01% | 15,866.57 USDC | 45,106.85 USD₮0 |
- **Pool source audit:** deployed pool `0xe712D505…` source diffed against canonical `Uniswap/v3-core`
  v1.0.0 (comment-stripped, name-normalized): **26/33 files byte-identical; 7 diffs all cosmetic**
  (pragma upper bounds `<0.8.0`, license header, removed doc comments, import order, one added
  `NewPoolDeployed` event in the deployer). **No swap/mint/burn/oracle math change.**
- `slot0().feeProtocol = 102 (0x66 → 6/64 per side)` on all sampled pools → protocol fee switch is ON.
- Accrued `protocolFees()` sampled: `0xe712D505…`: **1.2187 WHYPE ($3,038)** + 118.34 USDC ($118) — re-read in
  the CI run at 1.2562 WHYPE + 120.21 USDC (~$3.25k, block advancing);
  `0x337b56d8…`: 0.0475 WHYPE + 4.45 USD₮0; `0x56aBfaf4…`: 0.00046 WHYPE; `0x55443b2A…`: 0.10 USD;
  `0x7f63aC9b…`: ~$2.36. **Sampled P ≈ $3.3k collectable by the owner EOA right now** (all pools would be more).

**Verdict:** **E-U $0.00** (high — pool math is stock Uniswap v3; the only value-moving admin paths are
`onlyFactoryOwner`). **H-O $11.08M** (LP principal + 90.6% of swap fees, holder-owned). **P ≈ $3.28k sampled**
accrued protocol fees + full fee-switch authority on the owner EOA. **S $0.**
**Coverage:** pool code fully audited (representative pool; all pools are created from the same verified
factory/deployer). Periphery (routers, position manager, staking/booster `0x0B7ce14c…`, limit-order/DCA
contracts) **screened only** — not audited line-by-line; not material to E-U (no pooled custody in periphery).

## 2. Kinza Finance (BSC deployment; also opBNB/ETH/Mantle) — DefiLlama $2.94M

Per-chain (DefiLlama 2026-10-10): **BSC $2,894,552 (97%)**, opBNB $31,708, Ethereum $15,294, Mantle $2,876 —
the BSC deployment screened below is the material one; the other three were not individually audited.

**Live state** (BSC block 126,853,064; Aave v3 fork, repo `Kinza-Finance/KZA-lending`):
- Pool proxy `0xcB0620b181140e57D1C0D8b724cde623cA963c8C`; oracle `0xec203E7676C45455BF8cb43D28F9556F014Ab461`;
  25 reserves; **total supplied $4,031,565, borrowed $1,112,984** → net $2.92M ≈ DefiLlama.
- **All major reserves are FROZEN** (`frozen=1`: USDC, USDT, BTCB, ETH, WBNB, wBETH, FDUSD, …): no new
  supply/borrow; repay/withdraw/liquidate still possible. Only the 5 `p*` reserves are unfrozen but have
  **borrowing disabled**. No reserve is paused.
- Oracle prices sane vs market: USDC $0.999905, USDT $0.99906, BTCB $82,933, ETH $2,507.71, WBNB $750.53,
  ezETH $2,715 (≈1.083× ETH), SolvBTC $82,891. One stale-ish outlier: **STONE $2,012.73 (−19.8% vs ETH)
  but supply is $18, market frozen + borrow disabled** → inert.
- Admin: `PoolAddressesProvider` owner → Timelock `0x7a085A60…` / Governance `0x9808330D…` (P).

**Verdict:** **E-U $0.00 found** (screened; high on the no-new-borrow path — every major market is frozen
and p-markets cannot borrow). **H-O $4.03M** supplied (withdrawable by suppliers). **P** admin/timelock.
Liquidation surface (HF<1 positions) **not exhaustively enumerated** — the only unprivileged value path
left, bounded by existing borrows $1.11M; no mispriced live market found among the sampled feeds.
**S $0.**

## 3. Kumbaya (MegaETH mainnet 4326) — DefiLlama $1.91M

**Live state** (MegaETH block 28,849,478):
- Factory `0x68b34591f662508076927803c567Cc8006988a09` — **now source-verified** (`UniswapV3Factory`, solc 0.7.6).
- Factory owner = `0xC2F467A2d602172E1d4113bd2C4b77De5634Ae4a` = **Gnosis Safe v1.4.1, threshold 3**,
  owners `0x8565FEBA…, 0x77B57B71…, 0x2C238018…, 0x1976473C…, 0x32E27D06…` (3-of-5). Fee tiers standard
  (3000→tickSpacing 60 etc.).
- Pool `0x2809696f…4125` (WHYPE/USD₮0 0.30%) source diffed vs canonical v3-core: **the only logic diff in
  the whole pool source is `setFeeProtocol` bound `feeProtocol0 >= 2` instead of `>= 4`** (2/64 = 3.125%
  minimum protocol cut). Everything else identical. Custom init-code hash is explained by pragma/metadata.
- Sampled pools: `0x2809696f…` 0.44 WHYPE + 1,025 USD₮0; `0x587f6eea…` 5.70 WHYPE + 35,683 USDm;
  `0x6c8e5d46…` 64,700 USD₮0 + 44,999 USDm. TVL is spread over many small pools.

**Verdict:** **E-U $0.00** (screened; pool math stock modulo the fee-protocol bound). **H-O $1.91M** (LP).
**P** = 3-of-5 Safe (fee switch + collect, min cut 3.125%/side). **S $0.** Coverage: one representative
pool source-audited; full pool census not enumerated.

## 4. KittyPunch (Flow EVM) — DefiLlama $1.78M StableKitty + $496k PunchSwap + $42k PunchSwap V3

**Live state** (Flow block 81,323,287):
- StableKitty (Curve-NG fork) factory `0x4412140D…6dB7`, 9 pools. Sampled live balances:
  | Pool | Balances |
  |---|---|
  | `0x20ca5d1C…2B57` | 198,588.23 USDF + 190,842.62 stgUSDC ≈ $389k |
  | `0x6ddDFa51…f030` | 301,544.11 USDF + 273,946.79 PYUSD0 ≈ $575k |
  | `0x0e9712Ad…f717` | 215,649.58 PYUSD0 + 202,941.35 stgUSDC ≈ $419k |
  | `0x073D6f03…F88c` | 11,687.31 USDF + 82,190.74 USDC.e ≈ $94k |
  | (5 other pools empty) | — |
  ≈ **$1.48M sampled** (matches DefiLlama $1.78M incl. farms).
- PunchSwap V2 factory `0x29372c22…4A71`; PunchSwap V3 factory `0xf3319593…4Af0` owner
  `0x6AC1b2a5A1f9d05A895302736AC1FDf21FbF31EC` (contract, 172 bytes — Safe-proxy sized).
- Corpus cross-ref: this cluster was already closed as **L2-03 "StableKitty (Curve NG fork) — audited
  lineage; no bug found"** at ~$390k+$59k; balances re-verified here and now larger.

**Verdict:** **E-U $0.00** (screened; curve-NG math closure inherited from L2-03, balances re-verified).
**H-O ≈ $2.3M** (LP/user-owned). **P** = factory admins (fee receivers). **S $0.**

## 5. Aborean (Abstract) — DefiLlama $123.5k AMM + $178.6k CL (≈$302k; was $461k earlier in the day)

**Live state** (Abstract block 87,353,014):
- Ve(3,3)/Aerodrome-style: FactoryRegistry `0x5927E0C4…4B49` (owner = **Gnosis Safe v1.3.0, threshold 3**,
  `0x4B3E171F…F18f`), PoolFactory `0xF6cDfFf7…39a6B` (246 pools), CL factory `0x8cfE21F2…6eEf27`,
  Voter `0xC0F53703…29c9`, VotingEscrow `0x27B04370…6bB63`.
- Sampled pools hold small balances (e.g. `0x13058D2b…` 7.08e18 ABX-side + 17.7e9 token1; `0xb560B29f…`
  3.49e18 + 1.061e24 meme token).

**Verdict:** **E-U $0.00** (screened; standard Aerodrome/Velodrome lineage, governance behind 3-of-N Safe).
**H-O $0.46M** (LP). **P** Safe. **S $0.**

## 6. Fathom (XDC) — DefiLlama $364k lending + $265k CDP + $51k AMM

**Live state** (XDC block 108,203,387):
- Lending (Aave v3 fork, `Into-the-Fathom` repo): Pool proxy `0x70d8005E…449F`, oracle `0x54348d95…355A`.
  6 reserves; **2 live borrow markets**: WXDC (LTV 80%/LT 82.5%) supplied 12,374,932 WXDC ≈ $439k,
  borrowed 2,283,723 WXDC ≈ $81k; USDC (LTV 80%) supplied 158,426 ≈ $158k. Other 4 reserves (incl. FXD)
  frozen with LTV 0. Oracle fresh: WXDC $0.0354533 vs market $0.0354732 (0.06%), USDC $0.99917.
- CDP (MakerDAO GEB fork): BookKeeper `0x6FD3f049…03CE`; **`getTotalDebtShare` = 0 for both XDC and CGO
  pools → zero open debt → no liquidation path**. FXD supply 779,734 (price $0.948); XDC Vault
  `0x9B4aCeFE…0aA3a` holds 7,471,325 XDC ≈ $265k (position-owner-scoped; DefiLlama's CDP TVL).
  Note: FXD outstanding ≈ $739k vs CDP collateral ≈ $265k is an accounting mismatch worth monitoring,
  but with debt = 0 it is not an attacker path.

**Verdict:** **E-U $0.00** (screened; no liquidation surface — zero CDP debt; lending markets standard
with fresh oracle). **H-O ≈ $862k** (lending supply + vault collateral). **P** admin. **S $0.**

---

## Cluster summary

| Protocol | Chain | Live funds (verified) | E-U | H-O | P | S | Confidence | Coverage |
|---|---|---|---|---|---|---|---|---|
| HyperSwap V3 | HyperEVM | $11.08M LP TVL | **$0.00** | $11.08M | ~$3.28k protocol fees (sampled) + fee switch (EOA) | $0 | high (pool code) | code-audited (pool) / periphery screened |
| Kinza | BSC (+3) | $4.03M supplied / $1.11M borrowed | **$0.00** | $4.03M | admin timelock | $0 | medium-high | screened |
| Kumbaya | MegaETH | $1.91M LP TVL | **$0.00** | $1.91M | 3-of-5 Safe (fee switch) | $0 | medium-high | representative pool audited / screened |
| KittyPunch | Flow | ≈$1.48M sampled (DD $2.3M) | **$0.00** | ≈$2.3M | factory admins | $0 | medium (inherits L2-03) | screened |
| Aborean | Abstract | ≈$0.30M LP TVL | **$0.00** | ≈$0.30M | 3-of-N Safe | $0 | medium | screened |
| Fathom | XDC | $597k supplied + $265k vault | **$0.00** | ≈$862k | admin | $0 | medium-high | screened |

**Cluster E-U total: $0.00.** Residual unprivileged paths not exhaustively enumerated: Kinza/Fathom
liquidation surfaces (HF<1 books), HyperSwap/KittyPunch periphery contracts, Kumbaya full pool census.

## Negative results / closed candidate paths (evidence)

- HyperSwap V3 pool math: **stock** (source diff) → no swap/burn/oracle drain; `collectProtocol` from a
  fresh address reverts (fork test `test_HyperSwapV3_OwnerIsEOA_And_AttackerCannotCollectProtocolFees`).
- Kumbaya: `setOwner` from a fresh address reverts; owner is a 3-of-5 Safe (fork test).
- Kinza: supply into frozen USDC market reverts (fork test); no unpaused borrow market with borrow enabled.
- Fathom: supply into frozen FXD reverts; CDP debt = 0 (no `bite`/liquidation).
- Aborean: `setManagedRewardsFactory` from a fresh address reverts; owner is a 3-of-N Safe (fork test).
- KittyPunch: pool balances verified; math closure per corpus L2-03 (Curve-NG fork, no bug found).

## Files

- `analysis/v3cluster/kinza_bsc_reserves.py` + `kinza_bsc_reserves.json` — Kinza BSC full reserve scan.
- `analysis/v3cluster/kittypunch_stablekitty_pools.json` — StableKitty pool balances.
- `poc-v3cluster/test/ClusterGates.t.sol` — fork gate tests (CI log `ci-out/poc-v3cluster.log`).
- Source-diff artifacts produced under `/tmp/opencode` (hs_src/, km_src/) — method reproducible from the
  verified sources on Etherscan V2 (`chainid=999` for `0xe712D505…`, `chainid=4326` for `0x2809696f…`).
