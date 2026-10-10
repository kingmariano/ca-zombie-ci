# bsc-forks dossier — legacy custody watches (H2-09, zombie-hunt II)

Group: **FstSwap, BakerySwap, BSCSwap, BabySwap, EmpireDEX, KaoyaSwap** (BSC + EmpireDEX side chains).
All work **read-only** (eth_call / simulations only). Final BSC block for state reads: **126,837,245** (2026-10-10).
Per-file scan blocks are recorded in each JSON (`block`, `block_start`).

## Executive summary

| protocol | live value found | headline finding | class | confidence |
|---|---|---|---|---|
| FstSwap | $6.28M in FIST/USDT pair alone (TVL ~$10M) | No excess/skim money (sampled 161/4,842 pairs: 2 hits ≈ $0.0000002); FIST price fair vs Pancake (0.39%, fee-level); FIST not mintable | H-O (LP-held) | high (sampled); full scan → CI |
| BakerySwap | BETH/WETH pair $2.06M | 0 excess hits (sampled 160/3,087); MasterChef 1.386M BAKE (~$368) depositor-claimable only | H-O; BAKE inflation P | med-high |
| BSCSwap | $2.76M WBNB **locked** in THUGS/WBNB pair | Full scan 728 pairs: 31 excess hits all dust; 99.41% LP burned to 0x0 → $2.76M permanently locked liquidity; feeTo LP ≈$5.3k | S/L + P (feeTo) | high |
| BabySwap | USDT/WBNB pair $206.8k | Full scan 1,769 pairs: 173 excess hits all dust (FEG etc. ≈$0); MasterChef holds 0 BABY; feeTo LP ≈$9.7k | H-O; BABY inflation P | high |
| EmpireDEX | pairs ≈ $0 real | Custom EmpirePair keeps **virtual reserves** via `sweptAmount`; owner-only `sweep()` pulled WBNB/WCRO/WETH out (now absent from token contracts too) → **≈$1.40M of reserves are phantom** | P + S | high |
| KaoyaSwap | **$0 real** | All 8 pairs drained (real balances 0, reserves phantom, underwater $861k); pair accounting calls an upgradeable router proxy that no longer has `getTokenInPair` → pairs bricked; LP worthless; DefiLlama $1.63M is phantom | S + historical P | high |

**No external, unprivileged extraction path (E-U) with material value was found.** Every "excess" hit was verified at a pinned
end block and is economically nil. The two real stories are **phantom reserves** (EmpireDEX, KaoyaSwap — DefiLlama overstates
both) and **permanently locked liquidity** (BSCSwap THUGS pool).

## Method (applied to every factory)
1. Factory from DefiLlama registry (`registries/uniswapV2.js`), cross-checked with docs/explorer; router verified on-chain via `router.factory()`.
2. Enumerate `allPairsLength`/`allPairs`, then per pair: `token0`, `token1`, `getReserves` (multicall3, `0xcA11bde05977b3631167028862bE2a173976CA11`), then `token.balanceOf(pair)` for both tokens.
3. `excess = balance − reserve` (>0 = permissionless `skim(to)` money); negative = tokens already removed vs reserves ("underwater"/phantom).
4. Decimals per token, USD prices from `coins.llama.fi` (keyless). Every excess hit re-verified at a single end block.
5. Token mint analysis for top counterparties (Etherscan V2 sources); chef/farm claim logic read from verified sources; router/factory/feeTo balances checked.
6. Simulations via `eth_call` only (never sent transactions).

Script (public RPCs, no keys; env overrides `BSC_RPC_URL`/`RPC_URL`, etc.): **`ci/steps/bsc-forks_enum.py`**
(`PROTOCOLS=`, `MAX_PAIRS=0` full / `N` sample, `OUT_DIR=`). Outputs `bsc-forks_<protocol>_<chain>.json`.

---

## 1) FstSwap (BSC)

- Factory [`0x9A272d734c5a0d7d84E0a892e891a553e8066dce`](https://bscscan.com/address/0x9A272d734c5a0d7d84E0a892e891a553e8066dce) — **4,842 pairs**, `feeTo = 0x0` (no feeToSetter/owner functions).
- Router [`0x1b6c9c20693afde803b27f8782156c0f892abc2d`](https://bscscan.com/address/0x1b6c9c20693afde803b27f8782156c0f892abc2d) (factory verified). Old router [`0xf817c41c...`](https://bscscan.com/address/0xf817c41c7FF5E55FadC4afBb22B88b2108F0E4f3) holds 5.040 USDT + dust FIST + 0.018 BNB (S ≈ $5).
- FIST [`0xc9882def...`](https://bscscan.com/address/0xc9882def23bc42d53895b8361d0b1edc7570bc6a) — owner renounced, **no mint function** (verified source).
- FIST/USDT pair [`0xb4ec801a...`](https://bscscan.com/address/0xb4ec801aed8c92f2e69589518aaa127afb37d8c9): at block **126,836,295** reserves = **3,136,579.13 USDT / 14,987,036.92 FIST** ($6.28M); real balances == reserves (excess 0/0); LP 1.316e18, 0% burned.
- Report's "$3.54M USDT in 4,839 pairs": live pair count 4,842 ✓; DefiLlama USDT snapshot 2026-10-10 = **$3.92M**; the FIST/USDT pair alone holds $3.14M USDT.
- **(a) excess scan** — sampled 161 pairs (first 80 + last 80 + FIST pairs): 2 hits, verified: FEG 153.159714664 (≈$1.8e-7) + PG 5.32e-7. Full 4,842-pair scan → **CI**.
- **(b) top pairs** — counterparties checked: fake-"WBNB" 0x0efb5fd2 is a WETH clone (no free mint), BETH (Binance), 0xf8069273 "Token" (no mint), FIST (no mint). No freely-mintable token vs USDT found in sample.
- **(c) FIST price** — block 126,837,245: `getAmountsOut(1 FIST)` FstSwap **0.2084716 USDT** vs PancakeSwap **0.2092834 USDT** (Δ 0.39% ≈ fee level) → **no stale arb**; the $0.2259 claim is stale (live ≈ $0.208–0.209).
- **(d)** router/factory token balances: dust only. **(e)** LP not burned/locked; held by users (H-O).
- Evidence: `evidence_fstswap.md`, `bsc-forks_fstswap_bsc.json`.

## 2) BakerySwap (BSC)

- Factory [`0x01bF7C66...`](https://bscscan.com/address/0x01bF7C66c6BD861915CdaaE475042d3c4BaE16A7) — 3,087 pairs; feeTo `0x5f19cb3b...` holds 0.2943 LP of BETH/WETH = 0.078% ≈ **$1.6k** (P).
- Router [`0xCDe540d7...`](https://bscscan.com/address/0xCDe540d7eAFE93aC5fE6233Bee57E1270D3E330F) (factory verified).
- BAKE [`0xE02dF9e3...`](https://bscscan.com/address/0xE02dF9e3e622DeBdD69fb838bB799E3F168902c5): price **$0.0002659**; `mint/mintTo` onlyOwner (owner `0x20ec291bb8459b6145317e7126532ce7ece5056f`) → P inflation risk.
- Top pair BETH/WETH [`0xfb72d7c0...`](https://bscscan.com/address/0xfb72d7c0f1643c96c197a98e5f36ebcf7597d0e3): block **126,836,301** reserves 411.81 WETH / 370.08 BETH ≈ **$2.06M**; excess 0; no burn.
- Excess scan (160/3,087 sampled): **0 hits**; full → CI. Router/factory empty.
- MasterChef [`0x6a8dbbfb...`](https://bscscan.com/address/0x6a8dbbfbb5a57d07d14e63e757fb80b4a7494f81) ("CommonMaster"): holds **1,386,025.86 BAKE ≈ $368**; source-verified that `emergencyUnstake` returns only the caller's own LP and rewards are computed from `userInfo` → **depositors-only** ✓. (The often-quoted `0x20eC291b...` MasterChef address has **no code**.)
- Evidence: `evidence_bakery_baby.md`, `bsc-forks_bakeryswap_bsc.json`.

## 3) BSCSwap (BSC)

- Identity: bscswap.com / BSWAP (v1→v2 1:1 swap). Factory [`0xCe8fd656...`](https://bscscan.com/address/0xCe8fd65646F2a2a897755A1188C04aCe94D2B8D0) — 728 pairs; router [`0xd9545518...`](https://bscscan.com/address/0xd954551853F55deb4Ae31407c423e67B1621424A) (factory verified).
- BSWAP v2 `0xf388ee04...`; live v2/WBNB pool price ≈ **$1.02** (BscScan's $35.23 quote is the stale v1 market).
- **FULL scan (728 pairs, block 126,836,644): 31 excess hits, all verified, all dust/unpriced** (NCT 45.7M, MZI, MZIT, PG, ...; spot-checks: MZI pool empty, NCT/MZIT ≈ 1e-18 WBNB/token). `excess_usd_total ≈ $0`.
- Largest value: pair [`0x71c1b630...`](https://bscscan.com/address/0x71c1b6302c7f9c49ee3e675224b22cde34ab5ac7) WBNB/THUGS: **3,688.277 WBNB / 185,305.67 THUGS ≈ $2.76M**, balances == reserves; **99.41% of LP burned to 0x0** (LP total 21,778.26) → liquidity permanently locked; THUGS has no mint.
- feeTo `0xc26c62cb...`: 5.46% of WBNB/BUSD pair ≈ **$5.0k** + 0.0099% of THUGS/WBNB ≈ $272 → protocol-owned (P).
- Evidence: `evidence_bscswap.md`, `bsc-forks_bscswap_bsc.json`.

## 4) BabySwap (BSC)

- Given addresses **verified on-chain**: factory [`0x86407bEa...`](https://bscscan.com/address/0x86407bEa2078ea5f5EB5A52B2caA963bC1F889Da) (1,769 pairs) and router [`0x325E343f...`](https://bscscan.com/address/0x325E343f1dE602396E256B67eFd1F61C3A6B38BD) (`router.factory()` == factory ✓).
- BABY `0x53E562b9...`: `mint/mintFor` onlyOwner (owner `0x5da29e4a...`) → P.
- Top pair USDT/WBNB `0x04580ce6...`: block **126,837,164** reserves 103,526.09 USDT / 138.14 WBNB ≈ **$206.8k**; excess 0.
- **FULL scan (1,769 pairs): 173 excess hits, all verified, all dust** — e.g. FEG hits total ≈ $1.7e-7 (FEG = $8e-11). Underwater total $15.54 (normal post-swap drift).
- MasterChef [`0xdfAa0e08...`](https://bscscan.com/address/0xdfAa0e08e357dB0153927C7EaBB492d1F60aC730) (poolLength 200): **BABY balance = 0** → nothing unclaimed; claim logic depositors-only.
- feeTo `0x6bef4238...`: 102.71 LP of USDT/WBNB = 4.69% ≈ **$9.7k** (P).
- Evidence: `evidence_bakery_baby.md`, `bsc-forks_babyswap_bsc.json`.

## 5) EmpireDEX (BSC + Cronos + Ethereum + Polygon + xDai + Avalanche + Fantom + Kava)

- Factory `0x06530550A48F990360DFD642d2132354A144F31d` (all chains except ETH `0xd674b01E...`); routers: BSC `0xdADaae6c...` (verified), ETH `0xe7A50431...`, Polygon `0xB2855A6d...`.
- **Custom pair**: verified source of `0x3af4cf79...` shows `_balanceOfSelf(token) = sweptAmount + real balance` for the "sweepableToken", and `sweep(amount)` can only be called by the pair's own token contracts; token-side `sweep()/unsweep()/extractLegacyEmpire()/extractFutureRewards()` are **onlyOwner**.
- **Phantom reserves (live)**: BSC pair `0x3af4cf79` reserve 834.000000066 WBNB, **real 0.000000066**; documented EMPIRE/WBNB LP `0xf3114cb3` reserve 698.692164984 WBNB, **real 0.00000073**; Cronos pairs missing 741k / 661k / 206k WCRO; ETH pair missing 13.19 WETH. Underwater: **BSC $1,171,658; Cronos $146,180; ETH $36,406; xDai $22,328; avax $12,187; fantom $5,872; polygon $3,084 → ≈ $1.40M**.
- Swept assets are **not** in the token contracts either (WBNB @wROOTSat/EmpireDex = 0; WCRO @CRODEX/EMPIRE = 0; WETH @ROOTDEX = 0; escrow = 0) → owner-extracted.
- Simulations: `EmpirePair.sweep` from EOA → `Empire: INCORRECT_CALLER`; `wROOTSat.sweep` from EOA → `Ownable: caller is not the owner`. Excess hits (BSC 6, Cronos 1, ETH 1, Polygon 1) all dust (ADMC sell-sim = $0.000000316).
- Verdict: **P (owner-only) + S (real value gone / virtual reserves)**; DefiLlama TVL overstated ≈$1.4M. Evidence: `evidence_empiredex.md`, `bsc-forks_empiredex_*.json`.

## 6) KaoyaSwap (BSC)

- Factory `0xbFB0A989e12D49A0a3874770B1C1CdDF0d9162aA` (8 pairs, feeTo 0x0). Router proxy `0x879EAD67...` (admin `0x21079de6e13a5c7dbb0e3e2c9aad60135c30c01d`, current impl `0x498206af...`). The UI `.env` actually routes to **PancakeSwap's factory**.
- **Modified pair**: `_getBalance()` calls `IUniswapV2Router02(router).getTokenInPair(pair, token)` — accounting trusts the upgradeable proxy; no `skim()`.
- Live at block **126,834,965**: **all 8 pairs have real balances 0/0** while reserves are phantom (e.g. 40,986.28 KY + 891.09 WBNB; 128.71 WBNB + 1,919.49 BUSD; 405,636.63 KY + 97,126.33 BUSD). Underwater **$861,278**.
- Pair `burn()`/`swap()` simulations revert (impl no longer has `getTokenInPair`) → **bricked**; LP (6,022 + 494 + 198,005 + … incl. farm `0x21F17c2e` holding 2,372 / 478 / 103,223 LP) is worthless and unburnable. Farm holds 0 WBNB/BUSD. MasterChef holds 188.5 KY (stakers-only).
- DefiLlama $1.63M = phantom reserves; real value **$0**. Evidence: `evidence_kaoyaswap.md`, `bsc-forks_kaoyaswap_bsc.json`.

---

## Cross-cutting checks (all protocols)
- **Router/factory retained balances**: empty everywhere except FstSwap old router ($5.04 USDT dust) and feeTo LP tokens (protocol-owned, see above).
- **feeTo/treasury LP**: BSCSwap ≈$5.3k, BabySwap ≈$9.7k, BakerySwap ≈$1.6k, EmpireDEX ≈$331 (0.0634% of EMPIRE/WBNB); FstSwap feeTo = 0x0.
- **Unguarded rescue/emergencyWithdraw**: none found; chefs' emergency paths return only the caller's own stake (verified source).
- **Ownerless public mint**: none found (FIST, THUGS, "Token", Milk: no mint; BABY/BAKE/KY/ROOT/EMPIRE: onlyOwner/onlyOperator).
- **Excess (skim) money across all protocols**: total verified ≈ **$0.000001** (dust tokens only).

## Limits / next steps
- FstSwap (4,842) and BakerySwap (3,087) were **sampled locally** (161/160 pairs); full-population scans are in `ci/steps/bsc-forks_enum.py` for the parent CI run (outputs `ci-out/bsc-forks_*.json`; underwater + excess lists + top pairs included).
- BSCSwap/BabySwap/KaoyaSwap/EmpireDEX were scanned **fully** locally.
- Unpriced tokens limit USD precision; dead/unpriced excess tokens were spot-checked by sell simulation where a market existed.
