# AbstraDEX — Phase-2 deep dive (zombie-hunt II, L2 watchlist)

**Date:** 2026-10-12 · **Chains:** X Layer (196), Morph (2818), Cronos zkEVM (388), ZetaChain (7000), ZKFair (42766), Blast (81457)
**Status:** read-only; PoC fork-verified only (Foundry fork of X Layer at block 73,036,000); **no mainnet transactions, no secrets in this folder.**
**Triage input:** `l2-triage-b` row #9 — “AbstraDEX, LIVE-FUNDED, $214,201.15” at blocks xlayer #72,945,851 / morph #28,121,408 / cronos_zkevm #2,671,971 / zeta #19,415,749 / zkfair #29,987,090 / blast #41,452,198.

---

## 1. TL;DR

| Target | Live value (re-verified) | Extractable by external unprivileged attacker? | Why closed | Latent risk |
|---|---|---|---|---|
| X Layer pools (517 pairs; ~1,700 WOKB in 12 top pools) | **$214,673** at $126.30/OKB (block 73,039,252; reserves frozen vs triage) | **$0** (max theoretical $25.2 dust, blocked) | LP burned (0xdEaD/0x0 hold ≥99.99% in top pools) → reserves unreachable via `burn()`; the only exit is `swap()` and every counterpart token is a scam meme with **no market, no mint, no faucet** (checked PotatoSwap V2/V3, IceCreamSwap, Uniswap V3 on X Layer; only OKcat has a dead external pool holding $0.005 of WOKB) | If any counterpart token ever becomes tradable or mintable, pools become drainable (holder-only ceiling $38.2k, then $176.4k stays locked) |
| Morph pool 0xdec24110 (1.134 WETH) | $2,833 | $0 | LP 99.86% burned; MKoala owner renounced to 0xdEaD; no MKoala market/mint | same |
| Cronos zkEVM pool 0xcd4527e8 (633.7 vUSD + 0.265 ETH) | $1,309 | $0 | LP 100% held by EOA 0xc42e61c6… (holder-only withdrawal); balanced real-token pool | LP holder can withdraw any time |
| Zeta pools (17 pairs) | $87 | $0 | dust-sized pools; LP not burned but values ≤ $76 | LP holders (unidentified) |
| ZKFair pool 0xc8888daa (0.948 USDC) | $0.95 | $0 | balanced ZKF/USDC; LP held by ~8 EOAs incl. project address 0x80332758… | LP holders |
| Blast | $0 | $0 | factory deployed, **0 pairs** | none |
| **Total** | **~$218,900 live** | **$0 E-U** | | |

## 2. Total live extractable now (external unprivileged): **$0.00** — confidence **high**

Closest thing to an E-U path (and it is **blocked**): three X Layer pools where the WOKB side is real money and the counterpart side is 1 wei — drainable for ~half the WOKB side with **1 wei of the counterpart token**, but the counterpart tokens (XDOG / XBONK / Duck) have no market, no mint and no other pool anywhere on X Layer:

| pool | WOKB side | counterpart needed | USD at stake |
|---|---|---|---|
| 0x3b503053e5fA1494E380395Eae993891a2a737f9 | 0.1947 WOKB | ≥1 wei XDOG (0xe8dFF65c…) | $24.58 |
| 0x425b2f37100be9a16b6b6d750ad13acb043b326c | 0.0040 WOKB | ≥1 wei Duck (0xe30ba81e…) | $0.50 |
| 0x98c21d64ffd44138de1c520a5b5ff9d7825cf8a9 | 0.0010 WOKB | ≥1 wei XBONK (0xc2b162eb…) | $0.13 |

Three zero-reserve pools (WOKB reserve = 0) are drainable by **anyone** for 1 wei of WOKB, but the extracted assets are worthless scam-token dust (TToken 1938.77 / PEPES 2.6e-11 / OKMOM 3.9e-11) — total real value ≈ $0.

## 3. The mechanism (exact)

**The code is not the bug.** AbstraDEX is a faithful UniV2 fork (“AbstraFactory” + “SwapPair”, solc 0.5.16, LP name “AbstraDEX LPs”/ABS-LP). Verified source fetched from ZetaChain Blockscout (`inspect_contract_code`, chain 7000, address 0x174c4C03DfeA09682728A5959A253bf1F7C7766F; `is_verified_via_eth_bytecode_db=true`, `is_changed_bytecode=false`). The factory runtime code hash is **identical on X Layer, Zeta, Morph, ZKFair and Blast**: `0xbf2c16339fd79fc5924cb4a35b79c12dc46dfc2af817b50574dc410d4f1322af` (Cronos zkEVM factory `0x76D1fC01…` is a **different** bytecode `0xcb3f00f9…`, unverified). Pair template check (PoC T0): the OKcat/WOKB pair address equals CREATE2(factory, keccak256(token0‖token1), factory.`INIT_CODE_PAIR_HASH()`=0xb79803c7…) — i.e. deployed pair bytecode = the verified `SwapPair` (canonical `swap`/`skim`/`sync`/`mint`/`burn` logic, 0.3% fee, `feeTo=0`).

The value is **locked, not stolen**:
1. **LP burned.** In the 12 top X Layer pools the LP supply sits in `0x…dEaD`/`0x0` (99.99–100%, e.g. OKcat pool: 1.7320508e25 of 1.7321803e25 LP in 0xdEaD + 1000 in 0x0; MUKI pool 1.94936e24 of 1.94940e24 in 0x0). Nobody can sign for those addresses → reserves can never be withdrawn via `burn()`.
2. **Counterpart tokens unobtainable.** All counterpart tokens are scam memes (OKcat, MUKI, OKDoge, BabyOKB, AIPEPE, X-MEN, XDOG, XBONK, Duck, TToken, PEPES, OKMOM, MKoala, ZKF). Verified: no `mint` selector/behaviour (probed `mint()`, `mint(uint256)`, `mint(address,uint256)` → revert; selector extraction + 4byte.directory resolution shows only owner-gated helpers such as `withdawOwner(uint256)`/`errorToken(address)` on OKcat, and OKDoge’s owner is renounced to 0x0). No DEX market: PotatoSwap V2 factory `0x630DB8E8…` has no pair for any of them vs WOKB/USDT0/USDC except OKcat, whose only external pool (0xFfb85Bc9…) holds **39,474,457,258,860 wei = $0.005 of WOKB** and last traded 2024-11-28; IceCreamSwap factory `0xC87De04e…` has none; Uniswap V3 factory `0x4B2ab38D…` has no OKcat pool at any fee.
3. **No skim excess** anywhere: the full 6-chain scan (517+40 pairs) found **0 pairs with balance > reserve**.
4. **No pool-math edge**: zero-reserve pools only yield worthless dust; 1-wei-side pools require the unobtainable counterpart.

**What the locked money can still do (holder-only, H-O):** the tokens held *outside* the pools can be dumped in. Ceiling per top pool (fee-adjusted, PoC formula `out = 998·X·R1/(1000·R0+998·X)` with X = token supply − pool reserve): OKcat $17,980 · MUKI $8,415 · OKDoge $6,018 · t158a $1,844 · AIPEPE $1,354 · BabyOKB $1,201 · X-MEN $792 · others ≤ $206 → **H-O ceiling $38,244**; the residual **$176,429 can never be extracted by anyone** (all remaining counterpart supply is already inside the pools and no mint exists) → **S**.

## 4. Live-state assessment (all reads at explicit blocks)

**X Layer (block 73,039,252; reserves unchanged from triage block 72,945,851 → pools are dormant):**
- Factory `0xA7afB6163c331DDb0845843889D6f9544328846F` — code ✓, `allPairsLength()=517`, `feeTo()=0x0`, `feeToSetter()=0xCe8Bd93A367B81d255EB2bCCAe5a98900126884C` (also the deployer, block 326,101).
- Router `0x174c4C03DfeA09682728A5959A253bf1F7C7766F` — `factory()`/`WETH()`=WOKB ✓, holds **0** WOKB/ABS/OKcat and 0 OKB native.
- WOKB `0xe538905cf8410324e03A5A23C1c177a474D59b2b` (symbol “WOKB”, 18 dec, $126.30).
- Top pools (WOKB reserve / LP burn share): 0x0b07f323 **812.903 WOKB** / 99.99% · 0xe5215e6c **652.320** / 99.998% · 0x567c19d7 **103.118** / 100% · 0xd545200f **37.906** / 100% · 0x7d7756b4 **29.201** / 99.16% · 0x09ff0722 **24.518** / LP **not** burned · 0x90c97fc6 **19.565** / 100% · 0x91797202 **5.901** / not burned · 0x852e96ac **4.218** / 83.5% · 0x28f0c72b **4.110** / 100% · 0x4ee92b18 **3.524** / 100% · 0xa6af1c8a **2.421** / 100%. Sum = 1,699.7 WOKB ≈ $214,673.
- Live-LP pools → LP holders identified on-chain: 0x09ff0722 → EOA `0xe209c2af7d5f03f94d577be34d73c12800ece64c` (99.71% of LP, $3.1k claim); 0x7d7756b4 → EOA `0x1ffcf10a8a13fc3bb66246b3cabafedbfbc9f4e4` (0.84%, $31). Pools 0x91797202 ($745) and 0x852e96ac ($530): LP moved mid-history; creation-era minters now hold 0; holder not fully identified (documented limitation).
- OKcat owner/dev `0x6405bE6EedbD9B073FB8e527DA5943aa080A5f7C` holds **0** OKcat/MUKI/OKDoge/BabyOKB/AIPEPE and 0 OKB → no privileged dump available today.
- Zero-reserve pools (re-read locally, block 73,032,000+): 0x137ca6f9 (WOKB 0 / TToken 1,938.766e18), 0xf359b4d3 (WOKB 0 / PEPES 25,832,631 wei), 0xee6bd8df (WOKB 0 / OKMOM 39,402,884 wei).
- Tiny-side pools: 7 found by the CI scan (table in §2 + 0xc91e8819, 0xce22db79, 0x5e31b8a7, 0x3b1a6cab, 0x2d6e393b — all extractable only with unobtainable dust tokens or yielding worthless dust).

**Morph (block 28,171,591):** factory 0x174c4C03… 10 pairs; WETH pool 0xdec24110 = 1.134464 WETH ($2,833) / 782.26M MKoala; LP 99.86% in 0xdEaD; MKoala `owner()=0xdEaD`, no public mint. Others are dust/1-wei-side pools.

**Cronos zkEVM (block 2,672,656):** factory 0x76D1fC01… (different code, unverified) 10 pairs; pool 0xcd4527e8 = 633.746 vUSD + 0.265098 ETH (≈$1,309); LP totalSupply 1.2690e19 **100% held by EOA `0xc42e61c68aa8941e9c3308179c022b8d6c4ecfdd`** (event replay, 7 LP events, full-range logs).

**ZetaChain (block 19,440,179):** factory 0x174c4C03… 17 pairs, all ≤ $51/pool; LP not burned in the two pools with value ($76, $11) — holders unidentified (RPC log-range limits; amounts negligible).

**ZKFair (block 29,987,098):** factory 0x174c4C03… 3 pairs; 0xc8888daa = 52,829.23 ZKF + 0.948188 USDC; LP 2.102e20 held by ~8 EOAs (largest 0xe9ab9c9f… 29.7%, includes project address 0x80332758… 17.3%).

**Blast (block 41,499,318):** factory 0xA7afb616… deployed, `allPairsLength()=0`.

## 5. What an attacker can / cannot do (exact paths)

| Path | Preconditions | Result |
|---|---|---|
| `pair.burn(to)` to withdraw reserves | hold LP | **blocked**: LP in 0xdEaD/0x0 (top pools); live-LP pools belong to EOAs |
| `pair.swap()` taking WOKB out | hold counterpart token ≥ 9·R0 for 90% | **blocked**: counterpart tokens have no market/mint; dev holds none |
| `pair.skim(to)` | pair balance > reserve | **0 pairs** (full 6-chain scan) |
| drain zero-reserve pool | 1 wei WOKB (free) | **works** — yields scam-token dust, ≈$0 |
| drain 1-wei-side pool | 1 wei XDOG/XBONK/Duck | **blocked** (token unobtainable); would yield $24.6/$0.13/$0.50 |
| buy OKcat on PotatoSwap → dump into AbstraDEX | WOKB capital | **unprofitable** (PoC T5: round-trip loses ≥2×0.3% fee; external pool holds only $0.005) |
| factory admin (`setFeeTo`, `setFeeToSetter`) | feeToSetter key `0xCe8Bd…` | privileged; `feeTo=0x0` so no protocol fees exist to steal |
| owner-gated token functions (`withdawOwner`, `errorToken`, `launch`) | token owner key | privileged; owners hold nothing (OKDoge renounced) |
| router/farm/bridge sweep | — | router holds no funds; no farm/staking/bridge contract found holding funds (docs list only Router+Factory; abstradex.xyz is now a repurposed VPN mirror) |

## 6. PoC / fork verification

Foundry fork of X Layer at **block 73,036,000** (public keyless RPC `https://rpc.xlayer.tech`; historical state works). Files: `poc/test/AbstraDEX.t.sol` (forge-std 1.9.6 vendored), run in CI via `forge test -vvv`.

| Test | Claim | Expectation |
|---|---|---|
| `test_T0_pairCodeMatchesVerifiedFactory` | pair = CREATE2 of verified factory template; feeTo=0 | PASS |
| `test_T1_zeroReserveDrain_anyoneCanDrain` | anyone drains 1,938.77 TToken for 1 wei WOKB | PASS (value ≈ $0) |
| `test_T2_tinySideGate_noCounterpart_reverts` | XDOG pool cannot be touched without XDOG | PASS (revert `Swap: INSUFFICIENT_INPUT_AMOUNT`) |
| `test_T2b_tinySideGate_withOneWei_extractsHalfWOKB` | with 1 wei XDOG, ~0.0973 WOKB extractable | PASS (demonstrates the gate is token sourcing) |
| `test_T3_topPool_noFreeExtraction` | LP burned, skim=0, swap w/o tokens reverts, reserves stay | PASS |
| `test_T4_holderOnly_extraction_quantified` | dumping ALL outside OKcat extracts ≈142.4 WOKB ($17,980) | PASS |
| `test_T5_potatoSwapArb_unprofitable` | external-market round trip is a net loss | PASS |

CI runs (public repo `kingmariano/ca-zombie-ci`):
- run 1 (scan + failing test build): https://github.com/kingmariano/ca-zombie-ci/actions/runs/38249530356 — this run produced the 6-chain scan (`ci-artifacts/…/scan_all_chains.json`: X Layer 517 pairs, **0 skim-excess**, 233 pairs ≥99.9% LP-burned, 7 tiny-side; Morph/Cronos/Zeta/ZKFair/Blast scanned).
- run 2 (fixed checksums + batched scan + LP-holder pass): https://github.com/kingmariano/ca-zombie-ci/actions/runs/38251806988 (results in `ci-out/`).

## 7. Verdict & residual risk

- **E-U = $0.00 (high confidence).** There is no unprivileged extraction path to the ~$218.9k live value: canonical UniV2 code, burned LP, zero skim excess, and counterpart tokens that cannot be acquired (no market, no mint, no faucet). The only theoretical E-U is **$25.21** of dust in three 1-wei-side pools, blocked because the required dust tokens (XDOG/XBONK/Duck) are themselves unobtainable.
- **H-O ceiling = $38,244** (scam-token holders dumping; requires holding those tokens) + identified live-LP claims ≈ $4.4k (AIPEPE $3.1k EOA, Cronos $1.3k EOA, BabyOKB $31 EOA, ZKFair $0.95 across ~8 EOAs) — total ≈ **$43k**.
- **S = $176,429** — locked forever (LP burned + all counterpart supply already in the pools + no mint).
- **P** — only theoretical: token owners (OKcat owner holds 0; OKDoge renounced; feeToSetter with feeTo=0) have no live value to take.
- Residual/latent: (a) if any counterpart token becomes mintable/tradable the pools open up (H-O first, then S shrinks only if new tokens appear — they can't without a mint); (b) the two unidentified live-LP X Layer pools ($1,275 combined) and Zeta/Morph residuals are holder-only; (c) Cronos factory bytecode differs from the verified template (unverified) — pairs behave as UniV2 and its funded pool is a balanced real-token pool with 100% of LP in one EOA; (d) first scan pass had transient 403/429 errors on 187 X Layer + 9 Zeta pairs — rerun with batched RPC closed the gaps (`ci-out/scan_all_chains.json`, `errors` field).

## 8. Methodology & sources

- On-chain reads: `eth_call`/`eth_getLogs`/`eth_getCode` via public keyless RPCs (`rpc.xlayer.tech`, `xlayer.drpc.org`, `rpc.morphl2.io`, `mainnet.zkevm.cronos.org`, `zetachain-evm.blockpi.network/v1/rpc/public`, `rpc.zkfair.io`, `rpc.blast.io`) at pinned blocks; full-pair enumeration from each factory’s `allPairs`.
- Verified source: ZetaChain Blockscout (Blockscout MCP `inspect_contract_code`, chain 7000); runtime-code-hash equality across 5 chains; CREATE2 template check.
- Market checks: PotatoSwap V2 factory `0x630DB8E8…` (`getPair` probes + the dead OKcat/WOKB pool 0xFfb85Bc9…), IceCreamSwap factory `0xC87De04e…`, Uniswap V3 factory `0x4B2ab38D…`, DexScreener/GeckoTerminal/DEXPaprika, OKX Wallet token pages (holders/risk flags: “liquidity owner concentration 100%”, “unusual airdrop activity”, honeypot: no).
- Token backdoor checks: PUSH4 selector extraction from runtime bytecode + 4byte.directory resolution; live `eth_call` probes of `mint*`, `withdawOwner`, `errorToken`, `launch`, fee setters.
- Prices: DefiLlama `coins.llama.fi` (WOKB/OKB $126.30, WETH $2,554.74, vUSD $1.073, USDC $0.9997) at 2026-10-12.
- Triage cross-check: `l2-triage-b/ci-out/results.json` row “abstradex”; prior corpus `zombie_hunt/` (protocol flagged by Holder.io warning + CoinGecko trust 0; no post-mortem found).

## 9. Caveats & limitations

- The H-O/S split assumes every token held outside the pools can be dumped; lost keys/contract-held balances would lower H-O and raise S.
- LP-holder identification used creation-window + last-25k-block log scans (public RPC range limits); two small X Layer pools’ mid-history LP transfers were not fully traced ($1,275 combined).
- Cronos zkEVM factory source unavailable; its pair logic was inferred from behaviour and reserves==balances checks only.
- The X Layer bridge advertised in 2024 was a frontend feature; no AbstraDEX bridge contract was found, and the domain now serves an unrelated VPN mirror. If a bridge contract exists elsewhere it was not part of the triage target set.
- USD figures move with OKB/WETH price; token amounts are exact on-chain values.

## 10. Files

```
abstradex/
├── README.md                      ← this report
├── summary.json                   ← machine-readable summary
├── analysis/
│   ├── ho_split.json              ← per-pool H-O/S quantification (top 12)
│   ├── ho_split_run.log           ← its output
│   ├── selectors.json             ← function selectors of key tokens
│   ├── selector_sigs.json         ← 4byte.directory resolution
│   ├── lp_holders_nonburned.json  ← LP mint/transfer scans (creation windows)
│   └── lp_scan_okcat_early.*      ← early OKcat pool LP events
├── poc/                           ← Foundry fork PoC (test/AbstraDEX.t.sol)
├── ci/run.sh                      ← 6-chain batched scan + LP-holder pass
├── ci-out/                        ← CI scan outputs (scan_all_chains.json, lp_holders.json)
├── ci-log.txt / ci-artifacts/     ← CI logs/artifacts (run 1 & 2)
└── summary.json
```
