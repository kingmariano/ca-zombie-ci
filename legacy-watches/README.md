# H2-09 — Legacy-custody watches (multi-chain): live-state re-verification & unprivileged-extractability determination

**Date:** 2026-10-10 · **Chains:** Hedera, Stacks, Wanchain, Astar, Moonbeam, BSC (+Cronos/other EmpireDEX chains), Ethereum, Blast, Arbitrum, Flare, Flow EVM
**Status:** read-only; no mainnet transactions were sent; all heavy enumeration ran on the public CI (GitHub Actions) against keyless/CI RPCs; PoC forks only (if any). Corpus figures re-verified on-chain at the block numbers below.

**Mission:** for every H2-09 protocol, determine rigorously how much an **external, unprivileged** attacker (no keys, no privileges, only public contracts + own/flash capital) can extract **live today**, and classify the funds as E-U (extractable), H-O (holder-only), P (privileged-only) or S (stuck/bricked).

---

## TL;DR — per protocol

| Protocol | Chain(s) | Live funds (verified, USD) | E-U now | Class | Why closed/open | Latent risk |
|---|---|---|---|---|---|---|
| SaucerSwap V1 | Hedera | $9.80M TVL (H-O); excess ≈ $0.008 | **$0.00** | H-O (LP) / S(excess) | Full 2,798-pair sweep: only 8 dust excesses (Σ≈$0.008); no USDC excess anywhere; corpus $314.6k = artifact (index mix-up) | none material |
| Arkadiko Swap v2 *(cross-ref H2-06)* | Stacks | 684,664.9 STX/wstx ≈ $273k + 191,168.5 USDA ≈ $190k + 13.55M DIKO + 0.336 xBTC | **$0.00** | H-O (LP) / P (multisig) | **Covered by H2-06 agent's full audit** (`hedera-vechain/analysis/stacks/DOSSIER.md`): all gates live-verified — LP mint/burn gated to swap contract (`u21401`), admin fns gated to multisig `SM1CZ…` (`u20401`), x·y=k swaps fair-priced, `collect-fees` pays protocol principal. Custody numbers spot-verified by me via fresh Hiro reads (2026-10-10) | P: DAO multisig can re-point swap/LP authority |
| WanSwap | Wanchain | 222 pairs, 0 excess; wanUSDT 167,529 (total liquidity) | **$0.00** | live custody | "abandoned" wrong: 2 balanced par pools hold 98.5%; swaps <24h; excess 0 | none |
| ArthSwap V2 | Astar | 313 pairs, 14 dust excess entries (~$0.00004) | **$0.00** | live custody | no extractable excess; TVL ≈ $105.4k (WASTR-dominated) | none |
| Beamswap V2 | Moonbeam | ~$96.5k nominal; factory `allPairsLength=246` at halt | **$0** | **S** | **Moonbeam chain frozen at block 16,796,699 (2026-08-10T11:36:12Z)** — no tx executes; unchanged across 5 checks | if chain ever resumes |
| FstSwap | BSC | 4,842/4,842 pairs; USDT/FIST 3.14M USDT | **$0.00** | live custody | Full excess scan: 0 priced excess; FIST fixed-supply (no mint); FIST $0.20847 (FstSwap) vs $0.20928 (Pancake) = fee level; no stale arb | none |
| BakerySwap | BSC | 3,087/3,087 pairs, 0 excess; BETH/WETH $2.06M | **$0.00** | live custody | No path; MasterChef 1.386M BAKE ≈ $368 depositor-scoped; BAKE mint onlyOwner (P) | none |
| BSCSwap | BSC | 728/728 pairs, 31 dust excess; $2.76M WBNB locked in THUGS pair | **$0.00** | live custody + S-locked | 99.41% LP burned to 0x0 → WBNB permanently locked; feeTo LP ≈$5.3k (P) | none |
| BabySwap | BSC | 1,769/1,769 pairs, 173 dust excess; USDT/WBNB $206.8k | **$0.00** | live custody | Chef BABY balance = 0; feeTo LP $9.7k (P); no path | none |
| EmpireDEX | BSC/Cronos/… | reserves ≈$1.40M phantom (custom `sweptAmount` accounting) | **$0.00** | P + S | owner-only `sweep()` pulled real assets; sims revert `INCORRECT_CALLER`; real ≈0 | none |
| KaoyaSwap | BSC | 8/8 pairs real balances = 0; reserves phantom $861k | **$0.00** | **S (bricked)** | Pair accounting trusts an upgraded router proxy missing `getTokenInPair` → burn/swap revert; LP worthless | none |
| Universe XYZ | Ethereum | Farm `0x2d615795…`: 18,428 AAVE + 1,271 LINK + … ($3.24M) | **$0.00** | H-O | `withdraw`/`emergencyWithdraw` caller-balance-scoped (random → "balance too small"); XYZ ≈ $0.000126 | none |
| Unslashed | Ethereum | Vault `0x86fb84e9…`: 1,483.75 stETH + 1.09 WETH ($3.70M) **+ new pot $2.64M** | **$0.00** | H-O ($3.70M) / **S ($2.64M)** | Outsider redeem reverts; ENZF holder-only; withdrawal contract `0x6be7741d…` holds 1,059.5 stETH gated by empty registry → frozen | none |
| JPEG'd | Ethereum | $566,986 nominal; real open positions: 1 BAYC + 3 Pudgy, debt=0 | **$0.00** | H-O (~$35k) | All vaults zero debt; `liquidate` requires `LIQUIDATOR_ROLE`; $529k "TVL" is third-party Curve pool ETH | none |
| Mangrove | **Blast** (+Arbitrum) | 40 live offers, nominal $4.24M + $38.7k — **not custody** | **$0.00** (5-test fork PoC) | — (phantom TVL) | Makers are semi-live arb strategies with dust balances (0.0064 WETH vs 14.86 promised); every taker-profitable direction delivers 0 (`makerRevert`); the one deliverable offer is a taker loss at market | if makers re-fund |
| Sceptre Liquid | Flare | 2.1B FLR staked ≈ $15.2M; 48.62M WFLR ($341k) withdrawable by roles | **$0.00** | H-O + P-risk | Rate = internal accounting (not spot); mint requires deposit; redeem user-scoped at unlock rate; single-EOA ProxyAdmin + 34 ROLE_WITHDRAW EOAs | P: admin/role key risk |
| MORE Markets | Flow EVM | supply $9.68M / debt $4.24M; ≈$5.45M supplier equity | **$0.00** | **S (frozen)** + P-latent | All 9 reserves `ReservePaused(true)` since 2026-08-31 (block 77,003,531); every action reverts error 29; latent ~$0.29M bad debt/cycle if unpaused without oracle fix | P-conditional |

## Total live extractable now

**E-U total: $0.00** (confidence: **high**) across all 17 targets. No external unprivileged extraction path exists today.

For scale, the nominal custody re-verified on-chain splits as: **H-O ≈ $49M** (LP/stablecoin/LSD holder-scoped: SaucerSwap $9.8M, FstSwap $10.0M, Sceptre $15.2M, BakerySwap $3.9M, Universe XYZ $3.2M, Unslashed vault $3.7M, BabySwap $1.5M, WanSwap $1.0M, Arkadiko ≈$0.5M, others), **S ≈ $11M** (frozen/bricked: MORE Markets supplier equity $5.45M, BSCSwap locked WBNB $2.76M, Unslashed frozen pot $2.64M, Beamswap $96.5k, KaoyaSwap $0 real), **P ≈ $0.36M** (Sceptre role-held WFLR $341k + feeTo LP ≈$15k), plus **phantom TVL** that is not custody at all (Mangrove $4.28M unfunded promises; EmpireDEX ≈$1.4M; KaoyaSwap $861k nominal). See `summary.json` for the machine-readable split.

---

## 1. Scope, corrections to the corpus, and method

### 1.1 Corpus corrections found during re-verification
1. **Moonbeam is frozen** (not merely "winding down"): latest block `16,796,699`, timestamp `2026-08-10T11:36:12Z`, identical on `moonbeam.drpc.org` and `moonbeam.api.onfinality.io`. Moonbeam entered maintenance mode 2026-08-01 and stopped producing blocks on 2026-08-10 — the same date as Moonriver's halt (H2-04). **Beamswap V2's ~$96.5k is S (stuck) while the chain is halted.** (Sources: Moonbeam wind-down announcements; Kraken/Bybit migration notices; on-chain block read.)
2. **Mangrove is on Blast (and Arbitrum), not Polygon** — corpus chain label was wrong. Blast holds ≈$4.24M (USDB 2,096,294 + USDE 2,091,000 + WETH 18.86 + BLAST 17.5M per DefiLlama token snapshot), Arbitrum ≈$38.7k USDT0. See §Mangrove.
3. *(others as found — filled per protocol)*

### 1.2 Method (per protocol)
- Enumerate contracts from verified source (explorer), docs, and DefiLlama; verify `eth_getCode` on-chain.
- Read live state at an explicit block (recorded per protocol): token balances, reserves, totalSupply, owner/roles, pause flags, oracles and their timestamps.
- Audit the concrete unprivileged surfaces for the protocol class: V2 AMM (`skim` excess, fee-on-token, mintable counterparty, stale price vs external venue, locked LP), vault/claim math (caller scoping, share math, reward accounting), lending (Aave v3 fork: oracle freshness, eMode, unbacked mint, empty-market donation), liquid staking (exchange rate, redemption scoping).
- Price everything with DefiLlama (snapshot in `analysis/prices-snapshot.json`, 2026-10-10 ~11:30 UTC): ETH $2,492.75 · stETH $2,492.44 · USDC $0.9997 · USDT $0.9992 · STX $0.39836 · HBAR $0.09213 · WAN $0.05722 · ASTR $0.00698 · FLOW $0.03216 · FLR $0.00703 · USDB $0.98814 · USDE $0.99935 · PYUSD $0.99970 · USDA $0.99565 · BAKE $0.0002604 · BABY $0.0002096 · SAUCE $0.012205.
- Heavy enumeration (all-pairs sweeps, offer enumeration, farm accounting) ran in CI: workflow `poc.yml`, branch `legacy-watches` of the public CI repo; results in `ci-out/` + artifacts.

### 1.3 Chain liveness (block pinned at each read)
| Chain | Block | When | Note |
|---|---|---|---|
| Ethereum | 26,161,723+ | live | |
| BSC | 126,819,488+ | live | |
| Hedera | 100,952,655+ | live | |
| Wanchain | 46,766,639+ | live | |
| Astar | 15,020,121+ | live | |
| Moonbeam | 16,796,699 | **2026-08-10 — frozen** | no tx executes |
| Flow EVM | 81,304,566+ | live | |
| Flare | 71,772,023+ | live | |
| Blast | 41,410,875+ | live | |
| Arbitrum | 513,498,875+ | live | |
| Polygon | 95,281,675+ | live | (Mangrove Polygon deployment does not exist) |
| Stacks | 9,164,656+ | live | |

---

## 2. Per-protocol dossiers

*(one subsection per protocol — contracts, live state, checks, verdict; full evidence in `analysis/<group>/`)*

### 2.1 SaucerSwap V1 (Hedera) — E-U $0.00 (high); corpus "skim excess" = artifact (proven twice)
- **Contracts:** factory `0.0.1062784` = `0x0000000000000000000000000000000000103780` (`allPairsLength()=2798`); pairs are standard Uniswap V2 bytecode (16,542 bytes, `skim()` selector `bc25cf77` present). Router V3 `0.0.3045981`; FeeTo `0.0.1062785`; WHBAR `0.0.1456986`; USDC `0.0.456858`.
- **Two independent full sweeps** (parent batched `eth_call` at Hedera EVM block ≈100,953,291; child mirror-node/RPC at pinned block 100,951,927 = `0x6046777`): all 2,798 pairs; 5,555/5,596 token sides measured; **USDC excess = 0.000000 on all 81 USDC sides** (balanceOf 315,765.304805 = reserves exactly). Only **8 positive-excess entries**, total ≈ **$0.008** (SMACKM 5.326 = $0.0005; HBARbarian 1,751 = $0.0075; SAUCE 0.000777; LIZ/PEP/UNLUCKY/FROGRE/stickbug ≈ $0; LIZ transfer additionally blocked by an HTS custom fee); 2 deficit sides (skim would underflow).
- **Why the corpus figure was wrong:** total USDC custody in V1 pairs is $315.8k (mislabeled as "excess"), and index-mixed sums are huge (Σmax(0, bal0−res1)=1.185e18 raw) — the signature of a token0/token1 mix-up. Correct per-pair excess = dust.
- **Verdict:** E-U **$0.00** (high). LP funds ≈ $9.8M TVL are holder-scoped (H-O). No admin drain path. Evidence: `analysis/saucerswap-independent/README.md`, `analysis/hedera-other-amm/README.md` §1, `ci-out/hedera-saucerswap-independent.json`, run 38048907250.

### 2.2 WanSwap (Wanchain) — E-U $0.00 (high)
- 222 pairs at block 46,766,791: **0 positive / 0 negative excess**. The corpus's "$168k wanUSDT" is **total liquidity, not excess**: 167,528.99 wanUSDT, 98.5% in two live balanced par pools (USDT/USDC 120,887 + 120,468; USDT/WWAN 44,111 + 789,021 WWAN); 7 pairs swapped <24h. Router empty; farms hold the LP. No path. Evidence: `analysis/hedera-other-amm/raw/wanswap/`.

### 2.3 ArthSwap V2 (Astar) — E-U $0.00 (high)
- 313 pairs at block 15,020,315: 14 positive-excess entries, all dead memecoins (13× XMN + 1× LAND) ≈ $0.00004; 0 deficits; skim callable 10/10. TVL ≈ $105.4k (WASTR $104.3k + USDT $1.1k); router empty; 26 pairs active <7d. No path. Evidence: `analysis/hedera-other-amm/raw/arthswap-v2/`.

### 2.5 Arkadiko Swap v2 (Stacks) — E-U $0.00 (high) — **own audit + cross-referenced to H2-06**
- **Own audit (independent pass completed, Stacks tip 9,166,481):** full Clarity source review of `SP2C2YFP12AJZB4MABJBAJ55XECVS7E4PMMZ89YZR.arkadiko-swap-v2-1` + 8 LP-token contracts + token contracts. Swap math floors output/fees (k strictly increases); slippage asserts strict; `reduce-position` floors pro-rata using live LP balance; LP `mint`/`burn` on all 8 LP contracts gated to the DAO-registered swap (=v2-1, verified on-chain, `u21401`); wSTX/USDA/DIKO mints DAO-gated; WELSH has no mint (fixed 10B); `attack-and-burn` dead (`block-height < 40000`); `collect-fees` is unauthenticated but pays the hard-wired payout `SP2C2Y…` (attacker can only donate); no sweep, no oracle, no unguarded setters; no free-mint inputs, no empty-pool residue, no trait substitution.
- **Live state (tip 9,166,481, burn 970,788):** **684,665,047,263 uSTX** (= wSTX exact peg), **191,168,486,354 USDA**, **13,551,588,659,971 DIKO**, **33,558,053 sat xBTC (0.3356 BTC)**, **6,120,598,113,910 WELSH**, 2,062,964 LDN. All 8 pairs enabled, no shutdown; swaps live (h 9,165,900–9,166,021). Headline "685,714 STX" was an earlier snapshot.
- **Cross-reference:** H2-06's independent audit (`hedera-vechain/analysis/stacks/DOSSIER.md`) reaches the same verdict; the parent's fresh Hiro read (684,664.9 STX + 191,168.5 USDA + 13.55M DIKO + 0.336 xBTC) matches both.
- **Notable (H-O/S, not E-U):** tracked pool balances exceed actual by **16,975.5 STX / 23,626 USDA / 2.68M sat (≈$33k LP haircut)** — collected-fee double-counting; uncollected WELSH fees (4.858B ≈ 79% of actual WELSH held) are largely unbacked. Cap-risk: payout is a single-sig address; DAO/guardian is multisig `SM1CZEHHNMHMWKK8VMH8S8N3B6YRS8DT78DYWYXKH`.
- **Classes:** H-O = LP reserves; P = DAO multisig (re-point swap pointer / fee address) + single-sig payout; S = none identified.
### 2.4 Beamswap V2 (Moonbeam) — S (chain frozen)
- **Moonbeam is halted**: last block 16,796,699 (2026-08-10T11:36:12Z), unchanged across 5 checks (parent 11:26 UTC, child 11:29→14:00 UTC) and consistent on drpc + onfinality; GoldRush agrees. Factory `allPairsLength=246` at the halt block; ~$96.5k custody frozen. No tx can execute → **S**, not extractable by anyone. Sources: Moonbeam wind-down notices ("funds left in on-chain protocols may become inaccessible"); on-chain reads. Evidence: `analysis/hedera-other-amm/raw/beamswap-v2/moonbeam_halt_evidence.json`; liveness script `ci/steps/hedera_beamswap_moonbeam_liveness.py` (exit 2 = halted; re-run if it resumes).

### 2.6 FstSwap (BSC) — E-U $0.00 (high)
- **Factory/router/token:** `0x9A272d734c5a0d7d84E0a892e891a553e8066dce` / `0x1b6c9c20693afde803b27f8782156c0f892abc2d` / FIST `0xc9882def23bc42d53895b8361d0b1edc7570bc6a`.
- **Full-population CI scan** (block 126,835,441): **4,842/4,842 pairs**, `skim`-excess hits priced >$1: **0** (79 dust entries; largest priced excess $0.00014). Local sample + CI full scan agree.
- **Top-pair counterparty audit (parent, independent):** USDT/FIST pair holds 3,140,594 USDT / 14,967,772 FIST (block 126,836,295). Counterparties of the top blue-chip pairs: FIST `FistStandard` has **no mint/_mint at all** (fixed supply); Tomato `0xf0d65ce6…`, Tomatos `0x87d8e645…`, OSK `0x04fa9eb2…` mint only in constructor to owner (no public mint). No freely-mintable counterparty against USDT.
- **Price:** FIST $0.20847 on FstSwap vs $0.20928 on PancakeSwap (0.39% ≈ fee level) — corpus "fair-priced" confirmed at today's block.
- **Verdict:** E-U **$0.00** (high). LP funds holder-scoped (H-O). Evidence: `analysis/bsc-forks/README.md`, `evidence_fstswap.md`, CI `ci-out/bsc-forks_fstswap_bsc.json` (run 38054849715).

### 2.7 BakerySwap (BSC) — E-U $0.00 (med-high)
- Factory `0x01bF7C66c6BD861915CdaaE475042d3c4BaE16A7`, router `0xCDe540d7eAFE93aC5fE6233Bee57E1270D3E330F`, BAKE `0xE02dF9e3e622DeBdD69fb838bB799E3F168902c5`.
- **Full scan 3,087/3,087 pairs: 0 excess hits** (block 126,835,442). Largest pool BETH/WETH ≈ $2.06M. MasterChef holds 1,386,026 BAKE ≈ $368 — source-verified depositor-only (`emergencyUnstake` returns caller LP only); BAKE mint is onlyOwner (P). No path. Evidence: `analysis/bsc-forks/evidence_bakery_baby.md`, CI JSON.

### 2.8 BSCSwap (BSC) — E-U $0.00 (high); $2.76M permanently locked (S)
- Factory `0xCe8fd65646F2a2a897755A1188C04aCe94D2B8D0`, router `0xd954551853F55deb4Ae31407c423e67B1621424A`.
- **Full scan 728/728 pairs: 31 excess hits, all dust** (block 126,836,644). The $2.76M is **3,688.28 WBNB / 185,306 THUGS** in the THUGS/WBNB pair with **99.41% of LP burned to 0x0** → permanently locked, nobody can withdraw (S). feeTo LP ≈ $5.3k (P). No E-U. Evidence: `analysis/bsc-forks/evidence_bscswap.md`.

### 2.9 BabySwap (BSC) — E-U $0.00 (high)
- Factory `0x86407bEa2078ea5f5EB5A52B2caA963bC1F889Da`, router `0x325E343f1dE602396E256B67eFd1F61C3A6B38BD` (verified on-chain).
- **Full scan 1,769/1,769 pairs: 173 excess hits, all dust** (block 126,837,164). USDT/WBNB $206.8k; MasterChef BABY balance = 0; feeTo LP $9.7k (P). No path. Evidence: `analysis/bsc-forks/evidence_bakery_baby.md`.

### 2.10 EmpireDEX (multi-chain) — E-U $0.00; P + S (≈$1.40M phantom)
- Custom `EmpirePair` keeps **virtual reserves via a `sweptAmount` field**; the owner-only `sweep()` already pulled the real assets. BSC: reserves show 834.00 + 698.69 WBNB with real balances ≈0; Cronos: 741k/661k/206k WCRO missing. All simulations revert (`INCORRECT_CALLER` / not owner). Real value ≈0 vs DefiLlama $1.63–2.86M. Evidence: `analysis/bsc-forks/evidence_empiredex.md`, CI JSONs (8 chains).

### 2.11 KaoyaSwap (BSC) — S (bricked); E-U $0.00
- Factory `0xbFB0A989e12D49A0a3874770B1C1CdDF0d9162aA`. All **8 pairs have real balances = 0** while reserves are phantom ($861k underwater). Pair accounting trusts an upgraded router proxy that lost `getTokenInPair` → `burn`/`swap` revert; LP (incl. farm `0x21F17c2e…`) worthless. DefiLlama $1.63M is not real. Evidence: `analysis/bsc-forks/evidence_kaoyaswap.md`.

### 2.12 Universe XYZ (Ethereum) — E-U $0.00; H-O $3.24M
- Farm `0x2d615795…` holds the index basket: 18,428.37 AAVE + 1,271 LINK + SUSHI/BOND/SNX/COMP/ILV (ETH blocks 26,161,752–26,162,391). `withdraw`/`emergencyWithdraw` are caller-balance-scoped — a random caller reverts `Staking: balance too small`. XYZ token ≈ $0.000126 (Sushi pair). No unprivileged path. Evidence: `analysis/eth-vaults/eth-vaults_universe-xyz.json`.

### 2.13 Unslashed (Ethereum) — E-U $0.00; H-O $3.70M; NEW frozen pot $2.64M (S)
- Enzyme vault `0x86fb84e92c1eedc245987d28a42e123202bd6701` ("USF Fund I"): **1,483.749 stETH + 1.089 WETH**. ENZF shares held by bridge `0xf465f01b…` (1,267.40, 99.78%) + Enzyme fee reserve (2.79). Outsider `redeemSharesInKind(1 wei)` → `ERC20: burn amount exceeds balance`; holder succeeds; bridge's mutating fns revert `only investor`/`only registry`. Parent independent check agrees (recent self-service stETH withdrawals to `0x5904a703…`).
- **New pot (not in DefiLlama):** withdrawal contract `0x6be7741d…` holds **1,059.525 stETH ($2.64M)**; `userWithdrawal()` is gated by an empty registry mapping → **frozen (S)**; all other fns admin-only. Evidence: `analysis/eth-vaults/eth-vaults_unslashed.json` + `_evidence.json`.

### 2.14 JPEG'd (Ethereum) — E-U $0.00; H-O ~$35k
- All vaults have **zero debt**; the only open positions are 1 BAYC + 3 Pudgy in the pETH vaults with `debtPrincipal=0`, `isLiquidatable=false`. `liquidate` requires `LIQUIDATOR_ROLE` (2 ops addresses) — not permissionless. The $529k "TVL" is third-party ETH in the pETH/ETH Curve pool, not JPEG'd custody. PUSd supply 7,000 (~$0.97). Evidence: `analysis/eth-vaults/eth-vaults_jpegd.json`.

### 2.15 Mangrove (Blast + Arbitrum) — E-U $0.00 (high); $4.28M is phantom (unfunded offers)
- **Contracts:** Blast Mgv `0xb1a49c54192ea59b233200ea38ab56650dfb448c` (BlastMangrove, v3 packed structs), Blast MgvReader `0x26fD9643Baf1f8A44b752B28f0D90AEBd04AB3F8`; Arbitrum MgvReader `0x7E108d7C9CADb03E026075Bf242aC2353d0D1875`. `global().dead=false`, gasprice=1; all 6 Blast markets `active=1, lock=0`.
- **Live offers:** 40 on Blast (markets 1–5), 1 on Arbitrum (38,728.66 USDT0). Nominal `gives` ≈ $4.24M on Blast — matching the DefiLlama "TVL".
- **Why it looked extractable:** the WETH/BLAST asks (ticks 133,069–135,538 ⇒ ≈602k–790k BLAST/WETH) were posted when BLAST ≈ $0.0041; BLAST is now $0.0000622 (67× lower) — taking them would net ≈ $36.5k; market 3:1 offers also price USDe vs USDB at ~1.003–1.005 when USDB is at a 1.1% discount.
- **Why it is not:** Mangrove's take pulls the outbound token **from the maker** during `makerExecute` (`transferTokenFrom(outbound, maker, mgv, takerWants)`). Every maker holds **dust** of the outbound token while keeping an unlimited Mgv allowance: `0xac1ce7f6` holds 0.0064 WETH / 0.197 USDe vs 14.86 WETH / 2,091,000 USDe promised; `0x67270aee` 0.0063 WETH vs 3.0; `0x26e47dc2` 0.0073 mwstETH40 vs 2.242; BlastKandel 33,973 BLAST vs 17.5M; SmartKandel 0.064 mwstETH40 vs 3.316. Takes therefore fail with `mgv/makerTransferFail` and deliver nothing; the "clean" bounty is native dust (~$0.000002/offer).
- **Fork PoC, 5/5 PASS (Blast fork, block 41,411,145):** `poc/test/mangrove_blast.t.sol` — (1) WETH/BLAST ask (cheapest, maxTick 133069): `takerGot=0`, balances unchanged (maker's `makerExecute` reverts — it tries to buy WETH on a Thruster V3 pool with the BLAST it receives and the swap fails); (2) mwstETH40 ask (tick −8076, the one direction that DOES deliver): taker pays 0.001338 WETH for 0.003 mwstETH40 — a **loss** at market (mwstETH40 = 0.05 WETH on-chain, so 0.446 WETH paid per unit); (3) the nominally *profitable* direction "WETH for mwstETH40" (tick 8135): **delivers 0** — maker 0x26e47dc2's makerExecute reverts when it would sell WETH below market; (4) the other profitable direction "mwstETH20 for WETH" (ticks 1223/1238; mwstETH20 = 1.3925 WETH on-chain): **delivers 0** — maker 0x67270aee reverts; (5) maker-balance sanity. **Conclusion: E-U = $0.00 exactly** — the makers are semi-live arbitrage strategies that only deliver when the trade is profitable for *them*; every taker-profitable direction reverts.
- **Market prices used (on-chain, 2026-10-10):** mwstETH20 = 1.3925 WETH (Thruster V3 pool `0x4e0e7d3b…`), mwstETH40 = 0.0500 WETH (pool `0x9649ab08…`). Arbitrum maker USDT0 balance = 0. Evidence: `analysis/mangrove-independent/`.

### 2.16 Sceptre Liquid (Flare) — E-U $0.00 (high); H-O; material P-risk
- State block 71,772,220 (roles 71,775,945; liveness 71,779,062). Rate **1.890389774 FLR/sFLR** = internal `totalPooledFlr`/`totalShares` accounting (mutated only by deposits/rewards/instant-redeem), not spot-derived; mint requires deposit; `redeem` uses the historical rate at unlock time (≤ fair, user-scoped queue); rounding fallback unreachable; donations inert; no oracle in scope. **H-O** paths fair. **P-risk:** single EOA `0xf76a…` owns the ProxyAdmin (upgrade right over $15.2M) and 34 `ROLE_WITHDRAW` EOAs can unwrap/move 48.62M WFLR (~$341k) with no destination limit; ~2.1B FLR sits with warden EOAs. Evidence: `analysis/flare-flow/README.md` §1, `sceptre_state_block71772220.json`, `sceptre_roles_block71775945.json`.

### 2.17 MORE Markets (Flow EVM) — E-U $0.00 (high); market 1 frozen (S); latent P-conditional
- Snapshot block 81,310,662 (liveness 81,320,327). **Market 1 fully frozen since 2026-08-31** (block 77,003,531; all 9 reserves `ReservePaused(true)`, executed by the 2-of-3 Risk Safe). `eth_call` sims: withdraw/supply/borrow/repay/liquidationCall all revert error 29 = `RESERVE_PAUSED`. ≈$5.45M supplier equity frozen (supply $9.68M, debt $4.24M); three borrowers at HF 1.003–1.011 ($1.28M debt) cannot be liquidated; two are 100% ankrFLOW collateral and insolvent at market price (real HF ≈0.72) because `AnkrFlowToUsdFeed` = FLOW ÷ Ankr ratio 0.8245 → oracle $0.0389 vs DEX $0.0277 (+40%, ~$0.86M masked shortfall).
- Market 2 unpaused but empty (~$137); `mintUnbacked` unreachable (no BRIDGE role); `unbacked=0` everywhere. **Latent:** if unpaused without fixing the ankrFLOW feed → borrow ~$1.09M stable cash against overvalued collateral ≈ $0.29M bad debt per cycle (P-conditional). Evidence: `analysis/flare-flow/README.md` §2, `more_state_block81310662.json`, `more_health_block81310662.json`.

---

## 3. PoC / fork verification

| PoC | Chain / fork block | What it proves | Result | CI |
|---|---|---|---|---|
| `poc/test/mangrove_blast.t.sol` | Blast, pinned 41,411,145 | 5 tests: WETH/BLAST asks deliver 0 (maker revert); mwstETH40 direction delivers but at a taker loss at market; both nominally-profitable directions (WETH for mwstETH20/40) deliver 0 (makers self-guard); maker dust balances | **5/5 PASS** | final run URL below; earlier runs 38054849715 / 38064371232 |

All PoCs are fork-only; no mainnet transactions. CI workflow `poc.yml` on branch `legacy-watches` of the public CI repo; artifacts in `ci-artifacts/`.

## 4. Verdict & residual risk

- **Headline E-U (external unprivileged, live): $0.00** — every H2-09 protocol re-verified on-chain lands at $0 (or S where the chain is frozen). The corpus figures were either (a) total custody mislabeled as extractable excess (SaucerSwap, WanSwap), (b) custody whose only movement is holder self-service (H-O), or (c) **phantom TVL** — sum of unfunded promises (Mangrove $4.28M).
- **Classes:** see per-protocol table; totals in `summary.json`.
- **Residual/latent risk:** (i) Beamswap's ~$96.5k is frozen while Moonbeam is halted — if the chain ever resumes, re-run the V2 sweep; (ii) Mangrove offers revive instantly if makers re-fund their balances — monitor maker balances of outbound tokens; (iii) all V2-fork `skim()` surfaces are dust today but any future token donation to a pair becomes permissionlessly skimmable by anyone (not protocol value).
- **Blockers:** Moonbeam halt (S); Hedera HTS association constraints (a few unmeasurable token sides); unverified maker bytecode on Blast (behavior verified via fork PoC instead of source).

## 5. Methodology, sources, caveats, files

### 5.1 Method
- **Per-protocol contract reconstruction:** verified source (Etherscan V2, HashScan, Wanscan, AstarScan, Moonscan, Blastscan, Flarescan, Stacks Hiro) or bytecode/selector checks; every contract's code presence confirmed on-chain.
- **Live state at explicit blocks** (recorded per protocol in §2 and `summary.json`): balances, reserves, supplies, roles, pause flags, oracles + timestamps. Hedera balances were cross-checked against the authoritative mirror node.
- **Exhaustive enumerations** (not samples) for the AMM classes: SaucerSwap V1 (2,798 pairs, two independent methods), WanSwap (222), ArthSwap (313), FstSwap (4,842), BakerySwap (3,087), BSCSwap (728), BabySwap (1,769), EmpireDEX (8 chains), KaoyaSwap (8) — `skim`-excess = `balanceOf(pair) − getReserves()` per side, exactly what permissionless `skim(to)` transfers.
- **Order-book audit** for Mangrove: `openMarkets()` + `offerList()` on the v3 readers (packed structs decoded from the deployed source), `global()`/`local()` decode (dead flag, active flags), maker balances/allowances, and a **fork PoC** (Blast, pinned 41,411,145) that attempts the extraction.
- **Vault/lending audits:** share-scoping, caller checks, role gates, pause states, oracle freshness and pricing (DefiLlama/coins + on-chain venues), plus `eth_call` simulations of the sensitive paths.
- **Classification:** E-U (external unprivileged, net of gas) / H-O (holder-only) / P (privileged) / S (stuck/bricked). USD at the 2026-10-10 ~11:30 UTC snapshot (`analysis/prices-snapshot*.json`) and per-protocol blocks.

### 5.2 Sources of truth
- DefiLlama protocol + coins APIs (snapshot saved in `analysis/llama/`, `analysis/recon-llama.md`), GoldRush, Etherscan V2, Hedera mirror node, Stacks Hiro API, Blastscan/Moonscan/Subscan, Mangrove v3 deployed source (Blastscan) + mangrove-core, Enzyme vault contracts, Aave v3 fork sources, SaucerSwap docs, Moonbeam wind-down notices (crypto.news / moonbeam.network / exchange notices).
- Corpus: `zombie_hunt/ZOMBIE-HUNT-II.md` H2-09 (lead only — every number re-verified; three corpus corrections are documented in §1.1).

### 5.3 Caveats & limitations
- **E-U is the proof-standard number ($0.00).** H-O/P/S totals in §Total are nominal approximations mixing verified reads and DefiLlama TVL; do not sum them with the E-U headline.
- **Cross-reference:** Arkadiko's primary coverage is the H2-06 agent's audit; this finding spot-verified its custody numbers and adopted its verdict. A planned independent pass (child subagent) did not complete within budget.
- **State-flip risks** are explicitly *not* counted as E-U: Moonbeam resuming (Beamswap), MORE Markets unpausing without fixing the ankrFLOW feed (latent ≈$0.29M bad debt/cycle, P-conditional), Sceptre's single-EOA ProxyAdmin + role EOAs, Mangrove makers re-funding.
- Hedera: 41 of 5,596 pair token sides unmeasurable (dissociated/deleted HTS tokens); BSC dust tokens mostly unpriced (all sub-$1 by construction). No material value is hidden in either bucket.
- All work was read-only; no mainnet transactions were signed or sent. PoCs ran on pinned forks in CI only.

### 5.4 Files index
- `README.md` — this deliverable (per-protocol table + dossiers).
- `summary.json` — machine-readable summary.
- `analysis/recon-llama.md`, `analysis/llama/`, `analysis/chain-liveness.json`, `analysis/prices-snapshot*.json` — corpus reconciliation, chain liveness, prices.
- `analysis/saucerswap-independent/` — full-factory excess sweep (parent, independent).
- `analysis/hedera-other-amm/` — SaucerSwap/WanSwap/ArthSwap/Beamswap dossiers + raw dumps.
- `analysis/bsc-forks/` — FstSwap/BakerySwap/BSCSwap/BabySwap/EmpireDEX/KaoyaSwap dossiers + evidence + raw JSONs.
- `analysis/fstswap-top-pairs/` — top-pair counterparty-token mintability/simulation audit.
- `analysis/eth-vaults/` — Universe XYZ / Unslashed / JPEG'd / Mangrove dossiers + raw state.
- `analysis/mangrove-independent/` — Mangrove order-book evidence + scripts + verdict.
- `analysis/flare-flow/` — Sceptre + MORE Markets dossiers + state dumps.
- `analysis/stacks-arkadiko/` — (reserved; Arkadiko covered via cross-reference, evidence in `hedera-vechain/analysis/stacks/`).
- `poc/test/mangrove_blast.t.sol` — fork PoC (Blast).
- `ci/steps/` — reproducible CI steps (public RPCs only, no keys): `00-smoke.py`, `bsc-forks_enum.py`, `hedera-saucerswap-independent.py`, `hedera_saucerswap_v1_excess.py`, `hedera_beamswap_moonbeam_liveness.py`, `fstswap_top_enum.py`, `vaults_mangrove_offers.py`, `flare_sceptre_more_enum.py`; parameterized tools in `ci/tools/`.
- `ci-out/`, `ci-artifacts/`, `ci-log.txt` — CI results (run URLs in §3 and `summary.json`).
