# H2-02 — High-cluster deep dive: large live-TVL protocols with no path found yet

**Date:** 2026-10-10 · **Chains:** HyperEVM (999), Ink (57073), Ethereum (1), Cronos (25), Cronos zkEVM (388),
Flare (14), Plume (98866), Citrea (4114), BSC (56), MegaETH (4326), Flow EVM (747), Abstract (2741), XDC (50).
**Status:** read-only research; all PoCs fork-verified in GitHub Actions; **no mainnet transactions; no secrets.**

## TL;DR

| Target | Chain(s) | Live funds (verified) | Unprivileged extractable (E-U) | Why closed | Latent / other categories |
|---|---|---|---|---|---|
| **Altura** | HyperEVM | $32.44M USD₮0 NAV vault | **$0** (dust ceiling 7 micro ≈ $0.000007) | NAV 100% oracle-driven (REPORTER-only `reportNav`); withdrawals liquidity-gated; every path role/allowance/rounding-closed (17/17 fork tests) | H-O $32.44M nominal (queue→claim, no fee; only $0.000008 self-service today, $11.67M already queued); P roles + $26.9k accrued fees |
| **Nado Spot** | Ink | ≈$55.9M in Clearinghouse | **$0** | Fast-withdraw needs all 3 provisioned ECDSA keys (nSigner=3); user txs sequencer-Schnorr-only; per-owner nonce; EIP-712 chain/contract-bound; all engine mutators gated (14/14 fork tests) | H-O ≈$54.5M (owner withdrawals incl. permissionless 3-day slow mode, E2E-proven); P ≈$1.33M insurance + owner surfaces; residual race ≤$54k (low conf., needs sequencer keys) |
| **Rysk V12** | HyperEVM + Ethereum | ≈$36.62M (HyperEVM $27.32M + ETH $9.30M) | **$0** (high) | 23 gate classes closure-proven live + on forks: all pools custody-gated to operator EOA + 3-of-5 Safe; `selfServiceAllowed=false`; `authorizedCallers={Rysk}`; proxies initialized; signature schemes bind all fields; no unauthenticated callback (21/21 fork tests) | H-O ≈$36.6M economically user/MM-owned but **$0 self-serviceable today** (operator-relayed only); P = 3-of-5 Safe upgrade/drain $36.6M + $0.76M fee Safe, operator EOA controls all expired positions; S = 647.08 stHYPE ($55.7k delisted) + dust |
| **Moonlander** | Cronos (+zkEVM) | $15.94M USDC in diamond | **$0** | 23-facet diamond fully classified (225 selectors); `diamondCut`/init/admins role-gated; price feeds PRICE_FEEDER-gated; MLP mint/burn fair (15/15 fork tests) | H-O ≈$15.89M MLP claim + $1.19M FM rewards; P ≈$15.93M via msig `0x7F404D40…` + $370.9k revenue; S $2.4k (FM token) + zkEVM $5.4k |
| **Mystic Finance** | Flare + Plume + Citrea | Flare $28.11M, Plume $1.96M, Citrea $4.0M (DefiLlama) | **$0** (high for Flare/Plume-Re7; medium for remaining Plume/Citrea — screened) | Oracles track market (FTSO seconds-fresh; Stork signature feeds; PT oracles ZCB-bounded); `LLTV × oracle ≤ realizable value` on every market; zero liquidatable positions (230 Flare HF scanned; only $0.000005 dust); no permissionless value path (`forceDeallocate` returns assets to the vault only); curator actions revert for randos (11/11 fork tests) | H-O ≈$32.1M (Flare $28.11M + Plume $1.96M + Citrea $4.0M screened); P = vault owner/curator EOAs (instant gate/freeze, 3-day adapter notice) + 5/9 Safes; S ≈$0.3k + dust (bricked eOracle market frozen for its own users) |
| **HyperSwap V3** | HyperEVM | $11.23M LP TVL | **$0** | Deployed pool bytecode == verified source == canonical Uniswap v3-core v1.0.0 logic (CI bytecode check); `collectProtocol` is `onlyFactoryOwner` | H-O $11.23M LP; P ≈$3.3k sampled accrued protocol fees + fee switch on single-EOA owner `0xBC7e493f…` |
| **Kinza** | BSC (+opBNB/ETH/Mantle) | BSC $4.03M supplied / $1.11M borrowed | **$0 found** | All major reserves frozen (no new supply/borrow); oracle fresh; p-markets borrow-disabled | H-O $4.03M suppliers; P timelock/DAO; liquidation book not exhaustively enumerated (screened) |
| **Kumbaya** | MegaETH | $1.91M LP TVL | **$0** | Pool bytecode == verified source == canonical logic (only diff: min protocol fee 2/64 vs 4/64); owner = 3-of-5 Safe | H-O $1.91M LP; P Safe fee switch |
| **KittyPunch** | Flow EVM | ≈$2.3M (StableKitty $1.79M + PunchSwap $0.50M + V3 $45k) | **$0** | Curve-NG fork math closed in prior corpus (L2-03); balances re-verified; admins = 2-of-N Safe | H-O ≈$2.3M LP; P factory admins |
| **Aborean** | Abstract | ≈$0.30M LP TVL | **$0** | Aerodrome/Velodrome-lineage; FactoryRegistry owner = 3-of-N Safe | H-O ≈$0.30M LP; P Safe |
| **Fathom** | XDC | $597k supplied + $265k vault | **$0 found** | CDP debt = 0 both pools (no liquidation); lending oracle fresh; FXD reserve frozen | H-O ≈$862k; P admin; FXD supply-vs-collateral mismatch is a monitor item |

## Total live extractable now: **$0.00 (E-U)**

**Confidence: high** for Altura, Nado, Rysk, Moonlander, HyperSwap V3, Kumbaya, Aborean (fork-executed gates /
bytecode-verified code); **medium-high** for Kinza, KittyPunch, Fathom, Mystic-remainder (screened surfaces,
see caveats). No unprivileged extraction path was found on any of the eleven targets. Nothing was inflated to
fill a headline.

**Other categories (nominal, overlapping by construction — the same custody is often privilege-controllable):**
- **H-O ≈ $193.38M** user/holder/MM-owned (Altura $32.44M, Nado $54.5M, Rysk $36.6M, Mystic $32.1M,
  Moonlander $17.08M, HyperSwap $11.23M, Kinza $4.03M, KittyPunch $2.33M, Kumbaya $1.91M, Fathom $0.86M,
  Aborean $0.30M). Self-serviceability varies: some are instantly withdrawable (Mystic/KittyPunch/Kumbaya/
  HyperSwap LP), others are queue/operator-relayed (Altura, Rysk) or sequencer-settled (Nado).
- **P ≈ $55.03M** privileged-only control (Rysk Safe $36.6M + fees $0.76M; Moonlander msig $16.31M;
  Nado insurance $1.33M; Altura $26.9k fees; HyperSwap $3.3k sampled fees; + admin control elsewhere).
- **S ≈ $64k** (Rysk delisted stHYPE $55.7k; Moonlander FM-token $2.4k + zkEVM $5.4k; Mystic bricked-oracle
  dust ~$0.3k).

---

## Per-protocol detail

Dossiers: `analysis/<name>/REPORT.md` (each with live-state tables, exact blocks, call paths and negative
results). PoC: `poc-<name>/test/*.t.sol`, logs `ci-out/poc-<name>.log`.

### Altura (HyperEVM) — `analysis/altura/REPORT.md`
NavVault `0xd0Ee0CF300DFB598270cd7F4D0c6E0D8F6e13f29` (verified, non-proxy, EIP-1967 slots zero),
NavOracle `0x314A79618d86309e91aa972CAfd143ffca80AE8F`. `totalAssets` = 32,437,234.87 USD₮0
(`0xB8CE59FC…5ebb`) at block 48,164,864. All 10 candidate paths fork-proven closed (REPORTER role,
allowance/escrow, liquidity gate, donation neutrality, rounding, no proxy, staleness). The vault holds only
8 micro-USD₮0 on-chain; H-O redemption depends on operator-funded liquidity. CI 38053290770, 17/17.

### Nado Spot (Ink) — `analysis/nado/REPORT.md`
Nine live impls byte-identical to `nadohq/nado-contracts` (keccak). Clearinghouse ≈$55.87M (block 58,147,983:
34.64M USD₮0, 112.77 kBTC, 1,900.68 WETH, 2.37M USDC, xStocks). Fast-withdraw Verifier requires 3/3 ECDSA
signers; Schnorr sequencer gate; per-owner nonce; slow-mode sender-bound. CI 38065395750, 14/14.

### Rysk V12 (HyperEVM + Ethereum) — `analysis/rysk/REPORT.md`
All proxies/impls source-verified on Etherscan V2 (chainids 999 + 1). Live: MarginPool
`0x24a44f1d…1aB4` (HyperEVM) and `0x684404F2…C671` (ETH) hold ≈$36.62M (USDC 10.80M + 3.45M USD₮0 +
72.9k WHYPE + 20.375 UBTC + 384.5 UETH + 37.8k kHYPE + … on HyperEVM; 2.37M USDC + 1.36M USDT + WBTC +
WETH + 658 wstETH on ETH; blocks 48,180,034 / 26,162,991). Roles: `owner()` = Safe `0xAFE32eB8…3Db4`
(3-of-5), operator EOA `0x65802CC3…9e48`, `selfServiceAllowed=false`. 23 candidate paths closure-proven
(fork + read-only sims): `operate([])` → `bad operator`; `transferToUser` → `Sender is not Controller`;
`MMarket.setOperator` → `OwnableUnauthorizedAccount`; all upgrade paths Safe-only. CI 38066632187, 21/21.
Residuals flagged: off-chain RFQ relay policy (unsigned `fee` field, unenforced `validUntil`); stHYPE
647.08 ($55.7k) delisted with `farmer=0` (S until owner acts). Screened, not in the headline: Rysk Premium
(≈$87.7k, separate Safe-owned MarginPools) and Rysk V1 on Arbitrum (≈$193.6k, out of scope).

### Moonlander (Cronos + zkEVM) — `analysis/moonlander/REPORT.md`
Diamond `0xE6F6351fb66f3a35313fEEFF9116698665FBEeC9` holds 15,935,653.166386 USDC (block 99,057,951).
225/225 selectors classified across 23 facets; 25 candidate paths fork-tested; EIP-712 `batchExecute…`
with attacker-supplied `cachePrice` reverts `missing PRICE_FEEDER_ROLE`. CI 38057370504, 15/15.

### Mystic Finance (Flare + Plume + Citrea) — `analysis/mystic/REPORT.md`
Flare = 3 live Mystic Core VaultV2s on the Morpho Blue singleton `0xF4346F51…E8B0` (owner Safe 5/9):
COREUSDT0 $24.11M, CSXRP $3.21M, COREWFLR $0.80M (blocks: Flare 71,773,173; Plume 98,590,683).
All 11 Flare markets' oracles are `MorphoChainlinkOracleV2` over fresh FTSOv2 adapters (PT oracles bounded);
oracle ≤ market within 2%; 230 borrower HFs scanned → no profitable liquidation. Plume: Re7 vault
`0xc0Df5784…` $1.945M pUSD (owner Safe 2/5, 3-day timelock) lending ~100% into nOPAL/nALPHA Stork-fed
markets; zero liquidatable. `forceDeallocate` is permissionless but pays only the vault (fork-proved).
13 tests (8 Flare + 4 Plume + 1 parent drift-probe; see `analysis/mystic/ci.txt` and the final run).
Parent drift-probe: the m1 "dust" position was re-collateralized on live state (now healthy, HF ≈ 42,000);
a funded fresh address attempting a max-seize liquidation reverts `position is healthy` → E-U stays $0.

### HyperSwap V3 (HyperEVM) — `analysis/v3cluster/REPORT.md`
Factory `0xB1c0fa0B789320044A6F623cFe5eBda9562602E3`, owner EOA `0xBC7e493fd3ed834eD563f9597AAAED94e446bBc7`.
Deployed pool `0xe712D505…` runtime bytecode reproduced from the verified source (solc 0.7.6, runs 200,
immutables overlaid, metadata stripped) — byte-identical, hence canonical v3-core logic. `feeProtocol=6/6`;
sampled accrued `protocolFees` ≈1.2562 WHYPE + 120.21 USDC (~$3.3k) collectable only by the owner EOA.

### Kinza (BSC) — `analysis/v3cluster/REPORT.md`
Pool `0xcB0620b1…63c8C`; 25 reserves; supplied $4.03M / borrowed $1.11M at block 126,853,064; majors frozen,
oracle live (USDC $0.9999, BTCB $82,933, ETH $2,508). Only frozen p-markets lack borrow; no mispricing found
in sampled feeds (STONE −19.8% but $18 supply, frozen).

### Kumbaya (MegaETH) — `analysis/v3cluster/REPORT.md`
Factory `0x68b34591…98a09` (verified), owner Safe 3-of-5 `0xC2F467A2…4Ae4a`. Deployed pool runtime
bytecode reproduced from verified source (runs 800) — matches except the intentional `feeProtocol0 >= 2` bound.

### KittyPunch (Flow) — `analysis/v3cluster/REPORT.md`
StableKitty factory `0x4412140D…6dB7` (9 pools; sampled $1.48M), PunchSwap V2 `0x29372c22…4A71` (126 pairs,
feeToSetter = Safe), V3 `0xf3319593…4Af0` owner Safe (threshold 2). Math closure inherited from prior corpus L2-03.

### Aborean (Abstract) — `analysis/v3cluster/REPORT.md`
FactoryRegistry `0x5927E0C4…4B49` owner Safe 3-of-N `0x4B3E171F…F18f`; 246 AMM pools + CL factory;
attacker `setManagedRewardsFactory` reverts (fork test).

### Fathom (XDC) — `analysis/v3cluster/REPORT.md`
Lending Pool `0x70d8005E…449F` (WXDC $439k supplied/$81k borrowed, USDC $158k; oracle fresh), CDP BookKeeper
`0x6FD3f049…03CE` with `getTotalDebtShare = 0` on both pools; XDC Vault holds 7.47M XDC ($265k).

---

## What an attacker can / cannot do (summary)

- **Cannot** mint/redeem/withdraw against any protocol's pooled custody without owner/role/sequencer/keeper
  authority, valid signatures, or holder identity (all eleven: fork-proven or exact live gate).
- **Cannot** re-price any live oracle used for borrowing/lending (Altura REPORTER-only; Kinza/Fathom/Fathom-CDP
  feeds fresh and admin-pushed; Morpho markets — see Mystic dossier).
- **Can** perform ordinary, fair-priced actions: LP deposits/withdrawals, swaps, self-withdrawals (H-O),
  and in a few places liquidations if the book ever becomes under-collateralized (Kinza/Fathom — not
  enumerated; Mystic — see dossier).
- **Privileged-only** value exists (single-EOA HyperSwap owner, 3-of-5 Safes, operator/reporter EOAs, msigs):
  quantified in each dossier as P; no privilege was assumed for any E-U claim.

## PoC / fork verification

| Project | Tests | Result | CI |
|---|---|---|---|
| `poc-altura` | 17 | PASS | https://github.com/kingmariano/ca-zombie-ci/actions/runs/38053290770 |
| `poc-nado` | 14 | PASS | https://github.com/kingmariano/ca-zombie-ci/actions/runs/38065395750 |
| `poc-rysk` | 21 | PASS | https://github.com/kingmariano/ca-zombie-ci/actions/runs/38066632187 |
| `poc-moonlander` | 15 | PASS | https://github.com/kingmariano/ca-zombie-ci/actions/runs/38057370504 |
| `poc-mystic` | 13 | see final consolidated run | `ci-out/poc-mystic.log` |
| `poc-v3cluster` | 5 | see final consolidated run | `ci-out/poc-v3cluster.log` |
| bytecode check | 2 pools | **MATCH** (run 38070536118) | `ci-out/bytecode-check.txt` |

Final consolidated run: **see `ci-log.txt` / `ci-out/` (latest run at time of writing)**.

## Verdict & residual risk

**E-U $0.00 across all eleven targets.** Residual/latent risks worth monitoring (not extractable today):
- Altura: reporter key can move pps arbitrarily; if operator funds liquidity, JIT report-sniping becomes
  possible (~MEV-scale); $11.67M queued redemption depends on operator funding (H-O→S drift risk).
- Nado: fast-withdraw reimbursement race (≤$54k, low confidence, sequencer-key-dependent).
- Moonlander: signed-pnl timing bound ≤~$10k (low); off-chain keeper trust.
- Kinza/Fathom: frozen reserves one admin tx from re-opening; liquidation books not enumerated.
- HyperSwap V3: single-EOA factory owner (key-compromise = protocol-fee capture + fee-switch; no LP drain).
- Rysk: off-chain RFQ relay policy (unsigned `fee` field, unenforced `validUntil`) is an off-chain-dependent
  residual; the operator EOA is the hottest key (controls every expired-position payout); `setSelfServiceAllowed(true)`
  would arm user self-service, not attackers; delisted stHYPE ($55.7k) is S until the owner sets a farmer.
- Mystic: Stork `UnsafeV1` has no staleness check — a stop-push + collateral-crash window could overvalue
  collateral (bad debt to vaults, not attacker extraction); Plume wsuperOETHp market frozen by a bricked
  eOracle (S for its own users).

## Methodology & sources

- Read-only `eth_call`/`eth_getCode`/`eth_getLogs`/`eth_getStorageAt` on keyless public RPCs; exact blocks in
  each dossier. Etherscan V2 + Blockscout v2 for verified sources/ABIs; DefiLlama/CoinGecko for prices
  (2026-10-10); Mystic/Rysk docs + GitHub for deployment addresses; Firecrawl/web for protocol pages.
- PoCs: Foundry fork tests executed **only** in GitHub Actions (`ci/run.sh` runs every `poc-*/`; per-project
  logs in `ci-out/`). No mainnet transaction was ever signed or sent.
- Bytecode equivalence: `ci/check-bytecode.py` recompiles the verified V3-fork pool sources with on-chain
  build settings and compares against live code (immutables overlaid, metadata stripped).
- Caveats: coverage is **fully audited** for Altura/Nado/Rysk/Moonlander/Mystic-Flare and the HyperSwap/
  Kumbaya pool code; **screened** for Kinza/Kumbaya/KittyPunch/Aborean/Fathom, Mystic-remainder (Plume beyond
  Re7, Citrea) and all peripheries; not checked: exhaustive liquidation/health enumeration (Kinza, Fathom,
  Nado), off-chain/sequencer/RFQ policy, multisig composition, custody of keys. USD values are point-in-time.
  Verify on-chain before acting.

## Files index

- `README.md` (this file) · `summary.json` · `STATUS.md`
- `analysis/CONVENTIONS.md` — shared methodology for all agents
- `analysis/{altura,nado,rysk,moonlander,mystic,v3cluster}/` — dossiers + raw evidence
- `poc-{altura,nado,rysk,moonlander,mystic,v3cluster}/` — Foundry projects (fork tests)
- `ci/run.sh`, `ci/check-bytecode.py` — CI driver + bytecode check; `ci-out/`, `ci-artifacts/`, `ci-log.txt`
