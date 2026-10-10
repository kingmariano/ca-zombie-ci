# H2-09 · hedera-other-amm — legacy-custody watches (zombie-hunt II)

Group scope: **SaucerSwap V1 (Hedera)**, **WanSwap (Wanchain)**, **ArthSwap V2 (Astar)**, **Beamswap V2 (Moonbeam)**.
All work is read-only (`eth_call` / `eth_blockNumber` / mirror-node REST); no transactions were signed or sent.

| Protocol | Chain | Verdict | Class | E-U (USD) | Claimed | Confidence |
|---|---|---|---|---|---|---|
| SaucerSwap V1 | Hedera 295 | no extractable excess; claim = measurement artifact (USDC excess $0) | — (custody) | **$0.008** (dust) | $314.6k USDC | high |
| WanSwap | Wanchain 888 | live, zero excess; claim = total wanUSDT liquidity, not excess | — (custody) | **$0.00** | $168k | high |
| ArthSwap V2 | Astar 592 | live; excess dust in dead memecoins (XMN/LAND) | — (custody) | **$0.00004** | $117.9k | high |
| Beamswap V2 | Moonbeam 1284 | **chain halted 2026-08-10 11:36 UTC** — custody frozen, no tx can execute | **S** | n/a (frozen) | $96.5k | high |

Classes: E-U = external unprivileged extractable, H-O = holder-only, P = privileged-only, S = stuck.

---

## Method (common)

1. Locate factory/router/roles from official docs + DefiLlama registries; confirm on-chain (`chain-id`, mirror node contract IDs).
2. Pin an explicit block per chain; enumerate `allPairsLength()` → `allPairs(i)`.
3. Per pair: `token0()`, `token1()`, `getReserves()`, `token.balanceOf(pair)` for both tokens.
   **excess_i = balanceOf(pair) − reserve_i** — exactly what permissionless Uniswap-V2 `skim(pair)` transfers (source-verified for SaucerSwap; standard V2 elsewhere).
4. Skim simulation: `eth_call pair.skim(recipient)` from an existing account, recipient must be a Hedera account associated with both pair tokens (HTS constraint).
5. Cross-check Hedera balances against the authoritative mirror node (`/api/v1/accounts/{evm}/tokens?token.id=`).
6. USD via DefiLlama coins API / CoinGecko / cross-pool implied prices.

Negative results are recorded with raw numbers below.

---

## 1. SaucerSwap V1 (Hedera mainnet 295) — top verification item

**Contracts (all confirmed via mirror node)**

| Contract | Hedera ID | EVM address |
|---|---|---|
| V1 Factory | 0.0.1062784 | `0x0000000000000000000000000000000000103780` |
| V1 RouterV3 (current) | 0.0.3045981 | `0x00000000000000000000000000000000002e7a5d` |
| V1 RouterV1 (deprecated) | 0.0.1062787 | `0x0000000000000000000000000000000000103783` |
| FeeTo | 0.0.1062785 | `0x0000000000000000000000000000000000103781` |
| WHBAR token (current) | 0.0.1456986 | `0x0000000000000000000000000000000000163b5a` |
| WHBAR token (legacy) | 0.0.1062664 | `0x0000000000000000000000000000000000103708` |
| USDC | 0.0.456858 | `0x000000000000000000000000000000000006f89a` |

**State measured at pinned block 100,951,927 (`0x6046777`)**; hashio latest at write-up: 100,955,169 (`0x6047421`).
RPC: `https://mainnet.hashio.io/api` (fallback `https://295.rpc.thirdweb.com`).

**Enumeration result (complete, 0 errors)**
- Factory `allPairsLength() = 2798` pairs (campaign text said ~800; full set is 2798).
- 5,596 token sides; **5,555 measured**; 41 sides unmeasurable (dissociated/deleted/non-standard HTS token; e.g. pair accounts auto-dissociated after balance hit 0). 0 token-parse errors.
- **Positive excess: 8 entries only.** **Negative (deficit): 2 entries.**
- **USDC: 81 sides. Total `balanceOf` = 315,765.304805 USDC; total reserves = 315,765.304805 USDC; excess = 0.000000.**

| pair idx | pair | token | excess (raw) | value |
|---|---|---|---|---|
| 1922 | 0xbe7e31e5…4f8a | SMACKM | 532,624,999 (5.326 SMACKM) | $0.000478 |
| 461 | 0x91e35385…101d | LIZ | 50,000,000 | ~$0 (transfer blocked by HTS custom fee) |
| 1120 | 0x9e7d13ee…ecc0 | HBARbarian | 1,751 | $0.00745 |
| 846 | 0xd1a2bc18…41c7 | SAUCE | 777 raw (0.000777 SAUCE) | $0.0000095 |
| 1130 / 817 / 676 / 751 | — | UNLUCKY / PEP / FROGRE / stickbug | 624 / 269 / 200 / 3 | ~$0 |

**Total E-U (positive excess, priced) ≈ $0.008** (SMACKM $0.000478 + HBARbarian $0.007451 + SAUCE $0.0000095; LIZ/PEP/UNLUCKY/FROGRE/stickbug unpriced ≈ $0). Deficit entries (skim reverts `ds-math-sub-underflow`): veMOUTH pair `0xa66f04c4…f483` (−49,908,814,415 raw), Ph-PCC pair `0xce8a145c…5f3d` (−23,518 raw).

**Independent cross-check (parent's separate sweep, different code path):** `ci-out/hedera-saucerswap-independent.json` (block ~100,953,291) reports the **same 8 positive entries, same pairs and amounts, same 2 deficit pairs**, total ≈ $0.008. Two independent enumerations agree.

**Skim simulations (read-only `eth_call`)** — saved in `raw/saucerswap-v1/skim_sims.json`
- USDC/WHBAR top pair `0xdb34c1ef…d31d` (265,544.12 USDC side): skim OK → **0 transferred**.
- USDC/SAUCE `0xb4e267d9…f712`, SAUCE/RDANCE `0xd1a2bc18…41c7`, SMACKM/BSLD `0xbe7e31e5…4f8a`: skim OK (callable, not paused).
- LIZ/WHBAR: reverts `Safe token transfer failed!, INSUFFICIENT_SENDER_ACCOUNT_BALANCE_FOR_CUSTOM_FEE` (LIZ has 1 fixed + 1 fractional custom fee).
- veMOUTH: reverts (deficit underflow).

**Why the claim is an artifact — resolved definitively**
- Live full-state scan: **USDC excess is exactly 0 on all 81 USDC sides / all 2798 pairs.**
- The claimed "$314.6k USDC" cannot be reproduced from correct per-pair accounting (`balanceOf − reserve`). Candidate mechanisms (exact original bug unprovable, both documented):
  1. **Token0/token1 index mix-up** on pairs with asymmetric reserves: the index-flipped sums on the same factory are large (Σ max(0, bal0−reserve1) = 1.185e18 raw; Σ max(0, bal1−reserve0) = 7.867e19 raw — independent sweep), which would fabricate large fake "excess".
  2. **Total USDC custody mislabeled as excess**: Σ USDC `balanceOf` over all pairs = **315,765.30 ≈ claimed $314.6k** (drift with trades). The "~800 pairs" in the original text may date the snapshot (factory now has 2798 pairs).
- Either way: actual USDC excess = $0; the earlier note "skim excess = measurement artifact" is **confirmed**.
- Mirror-node cross-check at the same block: top pair 266,284,855,007 raw = EVM `balanceOf` = `getReserves().reserve0` (exact match; also idx-1 pair 1,792,085,136).
- `skim()` source (`saucerswaplabs/saucerswaplabs-core`, `contracts/UniswapV2Pair.sol`): transfers `balanceOf − reserve`; `safeTransferToken` requires HTS `transferToken` SUCCESS (custom-fee/freeze/association failures revert).

**WHBAR-specific checks:** both WHBAR generations have **no custom fees**; V3 router uses current WHBAR `0x…163b5a` (93 legacy pairs still use `0x…103708`; not exploitable). Pairs have no pause/freeze functions; USDC token has no custom fees; HTS `balanceOf` on pairs works (not frozen).

**Counterparty-mint check (top USDC pairs):** WHBAR (deposit-backed), SAUCE (keyed supply), BTC.ℏ (0.0.4873177: **no supply key → fixed 21M supply**), HBARX (Stader, keyed), USDC[hts] 0.0.1055459 (keyed; $1.2k exposure), AuBAR (**no supply key**). No public-mint drain vector identified.

**Context:** DefiLlama SaucerSwap V1 TVL ≈ $9.8M; USDC custody $315.8k. **Verdict: no E-U ($0.008 dust proven at block); no H-O/P path found; confidence high.**

---

## 2. WanSwap (Wanchain 888)

**Contracts:** Factory `0x1125C5F53C72eFd175753d427aA116B972Aa5537`; Router02 `0xeA300406FE2eED9CD2bF5c47D01BECa8Ad294Ec1`; WASP `0x8B9F9f4aA70B1B0d586BE8aDFb19c1Ac38e05E9a`; WWAN `0xdabd997aE5E4799BE47d6E69D9431615CBa28f48`; wanUSDT `0x11e77E27Af5539872efEd10abaA0b408cfd9fBBD`; wanUSDC `0x52a9CEA01c4CBDd669883e41758B8eB8e8E2B34b`; farm `0x7E5fE1e587A5c38B4A4A9ba38a35096F8EA35aaC`; feeTo `0xAD105d96f7fB7e6D0fcD0ED4C04557833786aA88`; feeToSetter `0xCb3c7d0a64386ed83148585D8001002AE449F7E7`.

**State at block 46,766,791 (`0x2c99ac7`);** chain live (46,767,660 at write-up; ~10 s blocks).
- 222 pairs; 443/444 sides measured; **0 positive, 0 negative excess** (balance == reserve everywhere).
- **wanUSDT total across pairs = 167,528.993753 — exactly the campaign's "$168k"** (it is total liquidity, not excess). 98.5% sits in two balanced, par-priced pools:
  - `0x22d41262…920d` wanUSDT/wanUSDC: 120,887.42 wanUSDT + 120,467.67 wanUSDC (last swap 2026-10-10 09:08 UTC).
  - `0x0a886dc4…ec0e` wanUSDT/WWAN: 44,110.90 wanUSDT + 789,021.14 WWAN (last swap 2026-10-10 11:30 UTC).
- Router holds **0** (WAN, WASP, wanUSDT, WWAN). Farm holds LP: 98.05% of the USDT/USDC LP, 77.4% of the USDT/WWAN LP; plus 6.21M WASP + 1 wanUSDT.
- **Pools are live, not abandoned:** 7 pairs swapped <1 d, 33 <7 d. Note: a second "WASP" token `0x924fd608…cb02` (52M units in pairs) appears to be an impostor of the official `0x8B9F…`.
- **Verdict: no E-U ($0); normal LP custody; confidence high.**

---

## 3. ArthSwap V2 (Astar 592)

**Contracts:** Factory (PancakeSwap-style; DefiLlama registry `arthswap`/`arthswap-v2`) `0xA9473608514457b4bF083f9045fA63ae5810A03E`; Router `0xE915D2393a08a00c5A463053edD31bAe2199b9e7`; feeTo `0xf0e5C12A53d45005B4C346cd2E223f040fEd24fD`; feeToSetter `0x32c2B282BD5aAA08424b10ce48A5462C88E25Fd3`.

**State at block 15,020,315 (`0xe5311b`);** chain live (15,020,978 at write-up).
- 313 pairs; 14 positive excess entries (13 × XMN `0xcf153fc7…e214`, 1 × LAND `0x5b196de3…2b96`), **0 negative**; 108 sides unmeasurable (dead non-standard tokens; retried where possible).
- Excess totals: XMN 52,023,533,602,983,678,255 raw; LAND 8,811,183,181,023,910,319,615 raw. Implied prices from cross-pools (XMN/WASTR ≈ $1.25 pool, LAND/WASTR ≈ $0.005 pool) → **total ≈ $0.00004**.
- Skim simulations: 10/10 callable (no reverts) — but transfer value ≈ $0.
- Router balances: 0 WASTR, 0.366 USDT, 3.18 ASTR native — empty.
- TVL estimate at block: WASTR 14,969,954.63 × $0.006965 = $104,271.69 + USDT $1,085.65 ≈ **$105.4k** (campaign claim $117.9k; DefiLlama current $524.8k). Pools: 26 pairs traded <7 d, majority dead.
- **Verdict: no E-U ($0); no FoT/deficit pairs; confidence high for measured sides.**

---

## 4. Beamswap V2 (Moonbeam 1284) — S (chain halted)

- **Moonbeam is halted.** Last block **16,796,699 (`0x1004c1b`) @ 2026-08-10T11:36:12Z**, unchanged across five checks 2026-10-10 11:29→14:00 UTC (drpc). GoldRush: latest 16,796,698 @ 2026-08-10T11:36:06Z. Matches H2-04 (wind-down 2026-07-31; Moonriver halted same date).
- Factory `0x985BcA32293A7A496300a48081947321177a86FD` readable at the halt block: `allPairsLength() = 246`.
- No tx can execute → nominal $96.5k is **frozen, not exploitable**. `raw/beamswap-v2/moonbeam_halt_evidence.json`.
- **Verdict: S; confidence high.** Re-run `other_amm_chain_enum.py` if the chain resumes.

---

## Call paths considered (all protocols)

`skim()` (permissionless excess extraction) · `sync()` drift · swap-k drain via fee-on-transfer tokens (checked via balance-vs-reserve deficits) · public-mint counterparty tokens against real assets · router/factory/feeTo custody · LP locks (farm holdings) · WHBAR dual-generation routing · HTS custom-fee/freeze/association failure modes.

## Evidence index

- `raw/saucerswap-v1/{pairs,pairdata,tokens,excess,skim_sims}.json` — full 2798-pair dataset, block 100,951,927.
- `raw/wanswap/{pairs,pairdata,tokens,excess,skim_sims}.json` — block 46,766,791.
- `raw/arthswap-v2/{pairs,pairdata,tokens,excess,skim_sims}.json` — block 15,020,315.
- `raw/beamswap-v2/moonbeam_halt_evidence.json` — halt evidence + RPC matrix.
- Cross-check: `../saucerswap-independent/README.md` + `ci-out/hedera-saucerswap-independent.json` (parent's independent sweep; agrees).
- CI scripts (`ci/steps/`): `hedera_saucerswap_v1_excess.py` (full Hedera enumeration, ~2.2k RPC posts), `other_amm_chain_enum.py` (generic V2 fork), `hedera_beamswap_moonbeam_liveness.py` (Moonbeam halt monitor).
- External: SaucerSwap docs (contract IDs), `saucerswaplabs/saucerswaplabs-core` `UniswapV2Pair.sol` skim, Hedera mirror node, DefiLlama coins/registry, GoldRush (Moonbeam), drpc Moonbeam RPC.

## Limitations

- SaucerSwap/ArthSwap pinned measurements are point-in-time; excess is dynamic (donations), but USDC excess = 0 and positive entries are sub-cent dust.
- Hashio `debug_traceCall` callTracer does not expose event logs; skim transfer amounts were validated via source code + mirror-node balances instead.
- 41 (SaucerSwap) and 108 (ArthSwap) token sides were unmeasurable (dead/dissociated tokens on dead pairs); residual risk there is bounded by those pairs' negligible value.
