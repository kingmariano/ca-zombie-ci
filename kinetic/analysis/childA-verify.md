# childA — Independent verification of Kinetic (Flare) C2-12 claims

**Date:** 2026-10-08 · **Chain:** Flare mainnet (chain id 14) · **Status:** read-only; no transactions signed/sent; all values read via `eth_call`/`cast call` at pinned blocks.
**Verifier:** childA (verification child of the C2-12 Kinetic subagent).

---

## 0. Block numbers used

| Purpose | RPC | Block | Note |
|---|---|---|---|
| Primary full sweep (all raw state) | `https://14.rpc.thirdweb.com` | **71639731** (ts 1791486380) | `childA-state.json` |
| Exact same-block re-read (independent provider) | `https://flare.public-rpc.com` | **71639731** | **0 diffs** vs primary (all 19 markets: totalSupply, getCash, exchangeRateStored, markets(), pause flags; oracle prices; exchange rates; FTSO feeds) |
| Second-provider sweep (counts/order/flags) | `https://flare.public-rpc.com` | 71640139 | identical market sets, order, oracle, verifier, CF, flags |
| Direct `cast` citations | `https://14.rpc.thirdweb.com` | 71640282 | `childA-cast-citations.txt` |
| `allMarkets(i)` completeness check | `https://14.rpc.thirdweb.com` | 71640371 | index 0..n-1 match, index n reverts |
| RPC tips at start | thirdweb / public / ankr / flare-api | 71639242 / 71639244 / 71639246 / 71639251 | all 4 RPCs reachable |

All four listed RPCs work; `flare-api.flare.network/ext/C/rpc` has no historical state, so only `latest` was used there. No historical state was needed anywhere else (thirdweb and public-rpc both served block 71639731).

**Method:** hand-rolled JSON-RPC batcher with explicit ABI encode/decode (`childA_verify.py`), all calls pinned to one block; direct `cast` spot-checks; source review of verified implementations (`ProtocolFTSOV3Oracle`, `ProtocolFTSOV2Oracle`, `ComptrollerV2`, `Comptroller`/TToken); second-provider byte-for-byte re-read. The parent's `markets(address)` decode error was reproduced and explained: the getter returns **2** values `(bool,uint256)`, not 3 (see claim 4).

---

## 1. Full 19-market table (raw values, block 71639731)

Source file: `childA-market-table.md` (generated from `childA-state.json`).

| # | C | market (cToken) | symbol | underlying | totalSupply (raw) | getCash (raw) | totalBorrows | totalReserves | exchangeRateStored | isListed | collateralFactor (raw) | mintGuardianPaused | borrowGuardianPaused |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | C1 | `0xad7e7989796414c9572da9854deb1b920724fd09` | isoUSDT0 | `0xe7cd86e13ac4309349f30b3435a9d337750fc82d` | 24923585599787538 | 404827237673 | 4933705570924 | 5893116065 | 213959571393991 | true | 800000000000000000 | false | false |
| 2 | C1 | `0xd1b7a5efa9bd88f291f7a4563a8f6185c0249cb3` | isoFXRP | `0xad552a648c74d49e10027ab8a618a3ad4901c5be` | 100072633345918761 | 18637413455285 | 1389610520512 | 563897271 | 200119247479987 | true | 700000000000000000 | false | false |
| 3 | C1 | `0x870f7b89f0d408d7ca2e6586df26d00ea03aa358` | isoSTXRP | `0x4c18ff3c89632c3dd62e796c0afa5c07c4c1b2b3` | 130458976110340 | 26091795243 | 0 | 0 | 200000000160448 | true | 0 | true | true |
| 4 | C2 | `0xdeebabe05bda7e8c1740873abf715f16164c29b8` | kUSDC.E | `0xfbda5f676cb37624f28265a144a48b0d6e87d3b6` | 3423748532204458 | 147843932689 | 639121479407 | 625146754 | 229672319081126 | true | 800000000000000000 | false | false |
| 5 | C2 | `0x1e5bbc19e0b17d7d38f318c79401b3d16f2b93bb` | kUSDT | `0x0b38e83b86d491735feaa0a791f65c2b99535396` | 23685209541139 | 2566060727 | 3678008002 | 2678393 | 263514254546040 | true | 800000000000000000 | false | false |
| 6 | C2 | `0x291487bec339c2fe5d83dd45f0a15efc9ac45656` | kSFLR | `0x12e605bc104e93b45e1ad99f9e555f659051c2bb` | 1982897483953182460 | 380937822859594552008562249 | 17221613179889257595853836 | 1493218668778602828421 | 200796030073643387189552592 | true | 708200000000000000 | false | false |
| 7 | C2 | `0x5c2400019017ae61f811d517d088df732642dbd0` | kWETH | `0x1502fa4be69d526124d453619276faccab275d3d` | 3655418300142 | 200141501488949010357 | 574775005090859225347 | 374487096153325279 | 211888751405979093480314132 | true | 625000000000000000 | false | false |
| 8 | C2 | `0x40ee5dfe1d4a957ca8ac4dd4adaf8a8fa76b1c16` | kFLRETH | `0x26a1fab310bd080542dc864647d05985360b16a5` | 4381722767150 | 877966458789034672855 | 3394791628123000390 | 473949963076834 | 201144806119365076547549462 | true | 625000000000000000 | false | false |
| 9 | C2 | `0x76809abd690b77488ffb5277e0a8300a7e77b779` | kUSDT0 | `0xe7cd86e13ac4309349f30b3435a9d337750fc82d` | 12551208226870278 | 524422912617 | 2142027245483 | 2926912935 | 212212497555637 | true | 800000000000000000 | false | false |
| 10 | C2 | `0xb84f771305d10607dd086b2f89712c0ced379407` | kFLR | native (0x0) | 1148812978247862982 | 176535449143932362778376148 | 55241981510591530998168299 | 21860670315428621778116 | 201734811820872268317668744 | true | 702700000000000000 | false | false |
| 11 | C3 | `0x1bb34a8360a09f3166574a331b941cd7e4463ab7` | isoUSDC | `0xfbda5f676cb37624f28265a144a48b0d6e87d3b6` | 95867902873539 | 2354624864 | 19336373714 | 24628480 | 226002337055192 | true | 835000000000000000 | true | true |
| 12 | C3 | `0x7b6fcf27e6fc63aaee93295b8d116eeff11983d3` | isoJOULE | `0xe6505f92583103af7ed9974dec451a7af4e3a3be` | 5471899184614387 | 1094379836922868545510770 | 0 | 0 | 199999999999998381825225344 | true | 0 | true | true |
| 13 | C3 | `0xd7291d5001693d15b6e4d56d73b5d2cd7ecfe5c6` | isoFLR | native (0x0) | 20785422193529979 | 4283839257624146237915844 | 7448092606215656 | 528607080665 | 206098256036635632143726400 | true | 702700000000000000 | true | true |
| 14 | C4 | `0x02350987093a804556d65be52063e85eaf80c806` | tFLR | `0x0000000000000000000000000000000000000000` | 1367265938677213265770138 | 0 | 1456439173223542745817650 | 8797804106981778255021 | 1058785513604696683 | true | 600000000000000000 | true | false |
| 15 | C4 | `0x0abca7776d419dbc1e5548df25748b7463f6428e` | tsFLR | `0x12e605bc104e93b45e1ad99f9e555f659051c2bb` | 852710677521750665148840 | 0 | 396932233492022576778296 | 1483266793946373830802 | 463755148284734853 | true | 600000000000000000 | true | true |
| 16 | C4 | `0x7003bbe5e1ace5dee22992d2a643f7de0daaae6e` | tUSDC.e | `0xfbda5f676cb37624f28265a144a48b0d6e87d3b6` | 24354210705 | 0 | 19418314616 | 1587995 | 797263637741857994 | true | 800000000000000000 | true | true |
| 17 | C4 | `0x5b685f1ed80d2ed16667ce5bd3db884d29964797` | tUSDT0 | `0xe7cd86e13ac4309349f30b3435a9d337750fc82d` | 30798135945 | 0 | 25157623073 | 32444058 | 815801938788409358 | true | 800000000000000000 | true | true |
| 18 | C4 | `0xe0fd00bb4a4938dacee59d814e9d346854721fa3` | tWETH | `0x1502fa4be69d526124d453619276faccab275d3d` | 9668713610721900700 | 0 | 5558700124685598835 | 865543718931257 | 574826683748646040 | true | 700000000000000000 | true | true |
| 19 | C4 | `0x7fa5559a01dc358e9bc9a2aa10300ba229ff3c7e` | tflrETH | `0xa060ffda1cd92851b1c24499effa16c07c262108` | 100000000000000000000 | 99000000000000000000 | 1000000000000000000 | 0 | 1000000000000000000 | true | 600000000000000000 | false | false |

Every market's `comptroller()` returns its enumerating comptroller (no cross-wiring). Global `_mintGuardianPaused()` / `_borrowGuardianPaused()` on C1/C2/C3 = `false` / `false` (C4 impl has no such getters).

---

## 2. Claim-by-claim verdicts

### Claim 1 — complete enumeration 3/7/3/6 — **CONFIRMED**

Calls (block 71639731 and 71640282):
`getAllMarkets()` on each comptroller returns:

| Comptroller | n | symbols (in array order) |
|---|---|---|
| C1 `0x15F6…4abB` | **3** | isoUSDT0, isoFXRP, isoSTXRP |
| C2 `0x8041…D7c8` | **7** | kUSDC.E, kUSDT, kSFLR, kWETH, kFLRETH, kUSDT0, kFLR |
| C3 `0xDcce…eAdd` | **3** | isoUSDC, isoJOULE, isoFLR |
| C4 `0xEBf6…651f` | **6** | tFLR, tsFLR, tUSDC.e, tUSDT0, tWETH, tflrETH |

Completeness cross-check: the public `allMarkets(i)` getter returns exactly these addresses for `i = 0..n-1` and reverts at `i = n` (block 71640371), so the array length equals the returned list. Each market's `symbol()` was read on-chain (table above). **No missing/extra markets found.**

### Claim 2 — no market with totalSupply()==0 while getCash()>0; smallest totalSupply — **CONFIRMED**

All 19 markets have `totalSupply() > 0`; zero violations of the stated condition. Smallest raw `totalSupply` across all 19:

- **24,354,210,705** — C4 `tUSDC.e` `0x7003bbe5e1ace5dee22992d2a643f7de0daaae6e` (cash = 0).
- next smallest: 30,798,135,945 — C4 `tUSDT0`; then 3,655,418,300,142 — C2 `kWETH`; 4,381,722,767,150 — C2 `kFLRETH`; 23,685,209,541,139 — C2 `kUSDT`; 95,867,902,873,539 — C3 `isoUSDC`.

Full raw `totalSupply`/`getCash` pairs are in the table above (also `childA-state.json` → `markets.*.totalSupply/getCash`).

### Claim 3 — cash>0 markets in C1/C2/C3 either mint-open or otherwise closed — **CONFIRMED (as worded; exact flags below)**

All 13 markets of C1/C2/C3 have `getCash() > 0` (table). Exact flags (comptroller `mintGuardianPaused(address)` / `borrowGuardianPaused(address)`):

- **mintGuardianPaused == false (9):** C1 isoUSDT0, C1 isoFXRP, C2 all 7 (kUSDC.E, kUSDT, kSFLR, kWETH, kFLRETH, kUSDT0, kFLR).
- **mintGuardianPaused == true (4), all "otherwise closed":**
  - C1 isoSTXRP: `mint=true, borrow=true`, collateralFactor = **0**, borrowCap = 1 → deprecated/closed.
  - C3 isoUSDC (`mint=true, borrow=true`, CF=0.835), isoJOULE (`true/true`, CF=0), isoFLR (`true/true`, CF=0.7027) → closed for new mint/borrow (redeem/repay remain open, as in Compound pause semantics).
- Global pause getters `_mintGuardianPaused()`/`_borrowGuardianPaused()` = false/false on C1/C2/C3, so per-market flags are the effective ones.

If the intended reading was "every cash>0 market is open for minting", that would be false for 4 markets — but as literally worded (…**or the market is otherwise closed**), the claim holds.

### Claim 4 — collateral factors for all 19 — **CONFIRMED**

`markets(address)` returns exactly **2 values** `(bool isListed, uint256 collateralFactorMantissa)` — the parent's earlier `(bool,uint256,bool)` decode failure was an ABI arity error, not a contract issue. Raw CFs (all `isListed = true`): C1 8e17 / 7e17 / 0; C2 8e17, 8e17, 7.082e17, 6.25e17, 6.25e17, 8e17, 7.027e17; C3 8.35e17 / 0 / 7.027e17; C4 6e17, 6e17, 8e17, 8e17, 7e17, 6e17. Exact values per market in the table above; `cast` citation at block 71640282: `markets(kSFLR) → (true, 708200000000000000)`.

### Claim 5 — oracle assetPrices == 0 and price legs — **PARTIALLY FALSIFIED (1 counterexample)**

Oracle addresses confirmed on-chain via `oracle()`: C1 `0x61f77Ef0064736Ffa68c31D960E55BAf67F79A4b`, C2 `0xC1d7029C970d9B683Da9d37b49d84D081dbeD54c`, C3 `0x30eDf82B2B75BbBf8e0b04b0F59086d321af964D`.

`assetPrices(underlying)`:
- **C1:** isoUSDT0 0; isoFXRP 0; isoSTXRP 0 → all zero.
- **C2:** kUSDC.E 0; kUSDT 0; kSFLR 0; kWETH 0; kFLRETH 0; kUSDT0 0; native `assetPrices(0x0)` 0 → all zero.
- **C3:** USDC.e 0; native `assetPrices(0x0)` 0; **JOULE = `10000000000000` (1e13) ≠ 0 → counterexample.** `getPrice(JOULE)` = 1e13 and `getUnderlyingPrice(isoJOULE)` = 1e13 (JOULE has 18 decimals → $0.00001/JOULE). Context: C3's oracle is a **different implementation** (`ProtocolFTSOV2Oracle`, verified source fetched) whose `tokenConfigs` is keyed by symbol and whose `assetPrices` still reads the owner-set override mapping (`OverridablePriceOracle`). The configured JOULE/USD feed `0x014a4f554c452f555344…` **does not exist on FTSO** (`getFeedById` reverts `"feed does not exist"` on both FTSO contracts), so the manual override is load-bearing for that market. Oracle owner: `0x37C6C7c719DB93085678cE72981CDd96219C9B72`.

`getUnderlyingPrice(market)` = FTSO price × exchange-rate leg (exact integer checks at block 71639731):
- **kSFLR (C2):** `floor(675738 × 1e10 × 1889606220349440147 / 1e18)` = **12,768,787,281,264,899** = `getUnderlyingPrice` exactly.
- **kFLRETH (C2):** `floor(2448477 × 1e15 × 1070476743418981828 / 1e18)` = **2,621,037,685,296,278,369,275** = `getUnderlyingPrice` exactly.
- C1 and C3 have no sFLR/flrETH markets, so the exchange-leg part applies only to C2; it is N/A for C1/C3 (C3's markets are isoUSDC/isoJOULE/isoFLR).
- All other market prices matched exactly too (e.g. isoUSDT0/kUSDT/kUSDT0 = 99938e10×1e12; isoFXRP/isoSTXRP = 1362549e12×1e12; kUSDC.E/isoUSDC = 99986e13×1e12; kWETH = 2448477e15; kFLR/isoFLR = 675738e10).

### Claim 6 — FTSO freshness and 420s maxStalePeriod — **CONFIRMED**

`getFeedById` on `0x7BDE3Df0624114eDB3A67dFe6753e62f4e7c1d20` at block 71639731 (ts 1791486380):

| Feed | feed id | value | decimals | timestamp | age |
|---|---|---|---|---|---|
| FLR/USD | `0x01464c522f555344…` | 675738 | 8 | 1791486380 | **0 s** |
| USDT/USD | `0x01555344542f555344…` | 99938 | 5 | 1791486380 | **0 s** |
| ETH/USD | `0x014554482f555344…` | 2448477 | 3 | 1791486380 | **0 s** |

All ≤ 420 s (in fact equal to the block timestamp). `maxStalePeriod` from `tokenConfigs`: **420** for every C1/C2 market token (address-keyed getter) and for C3's tokens via the symbol-keyed getter (`tokenConfigs("USDC.e")`, `tokenConfigs("JOULE")`, `tokenConfigs("isoFLR")` all 420). Caveats: (a) C2 and C3 oracles point at FTSO `0xb18d3a5e5a85c65ce47f977d7f486b79f99d3d32`, not `0x7BDE…` (C1 uses `0x7BDE…`); both were called and return identical values/timestamps. (b) On C3, `tokenConfigs(underlying-address)` reverts by design — the correct call is `tokenConfigs(symbol)`. C4's oracle has no `ftsoV2()`/`tokenConfigs` at all (unverified, different stack).

### Claim 7 — liquidation gate — **CONFIRMED**

- C1/C2/C3 `liquidatorsWhitelistVerifier()` = **`0x5fa1B6Cdc8E46BfFEed066E1ECd92F90C663e8CC`** (identical on all three; contract has code).
- `allowed(0x00000000000000000000000000000000DeaDBeef)` on that verifier = **false** (also `allowed(0x0)` = false). `cast` citation block 71640282: `allowed(DeaDBeef) → false`.
- C4: `liquidatorsWhitelistVerifier()` **does not exist** (`eth_call` reverts). C4 instead exposes `liquidatorWhiteList(address)` = **false** and `isInLiquidateWhiteList(address)` = **false** for `0x…DeaDBeef` (both exist; `updateLiquidateWhiteList` is owner-only). The C1–C3 implementation's `liquidateBorrowAllowed` gates on `IAllowList(liquidatorsWhitelistVerifier).allowed(liquidator)`.

### Claim 8 — no zero/absurd exchangeRateStored — **CONFIRMED**

- Zero rates: **none** (all 19 > 0).
- Min raw: **200,000,000,160,448** — C1 `isoSTXRP` `0x870f…a358`.
- Max raw: **211,888,751,405,979,093,480,314,132** — C2 `kWETH` `0x5c24…2dbd0`.
- Absurdity check: for **every** market, `exchangeRateStored == (getCash + totalBorrows − totalReserves) × 1e18 / totalSupply` **exactly** (integer division, 0 mismatches), i.e. each stored rate is fully consistent with its own accounting at the pinned block; large values (≈2e26) are simply 8-dec cTokens over 18-dec underlyings, not corruption.

---

## 3. Counterexamples & anomalies

1. **FALSIFIED (claim 5, C3/isoJOULE):** `assetPrices(0xE6505f92583103AF7ed9974DEC451A7Af4e3A3bE) = 10,000,000,000,000` (1e13) — a live owner price override, used because the JOULE/USD FTSO feed does not exist. No other underlying of C1/C2/C3 has a non-zero `assetPrices`.
2. **C3's oracle is not the same contract as C1/C2's:** `ProtocolFTSOV2Oracle` (symbol-keyed `tokenConfigs(string)`) vs `ProtocolFTSOV3Oracle` (address-keyed `tokenConfigs(address)`). Claim 6's suggested `tokenConfigs(underlying)` call reverts on C3; values (420) are still correct when called correctly.
3. **C4 is a different generation:** TToken/TEther markets (`TErc20Delegator`, `TEther`), Comptroller impl `0xa43b4b6934cbfe1f2afdbfdad668410b99c4410c`; no `liquidatorsWhitelistVerifier` (uses `liquidatorWhiteList`); oracle `0x4d309754eb1ae09e94bfc2b5cb3178a317e76273` is **unverified** and has no `ftsoV2()`/`assetPrices()`/`tokenConfigs()`.
4. **C4 "tflrETH" underlying is not the canonical flrETH:** `0xa060ffda1cd92851b1c24499effa16c07c262108` (symbol/name "flrETH", 18 dec, unverified) ≠ `0x26a1fab310bd080542dc864647d05985360b16a5` (C2's kFLRETH). C4's oracle prices it as plain ETH (`2,448,477e18`, no sETH exchange-rate leg) vs C2's kFLRETH (`2,621,037.685e18` with leg). C4 also has dust markets (tUSDC.e totalSupply 24,354,210,705 raw; tFLR cash=0 with borrows>supply; tflrETH cash=99e18, caps=0, mintPaused=false — C4 only, outside claims 2/3 scope).
5. **Parent-side ABI error (not a contract anomaly):** `markets(address)` returns `(bool,uint256)`; the earlier 3-value decode produced `DECODE_ERR` rows in the parent's `state.json`. Correct values are in §1/§4.

---

## 4. Evidence index (all under `kinetic/analysis/`)

| File | Contents |
|---|---|
| `childA_verify.py` | full raw-JSON-RPC verifier (encoder/decoder, pinned block) |
| `childA-state.json` | raw results: 19 markets, comptroller/flags/oracle/feeds/exchange assets, block 71639731 |
| `childA_crosscheck.py`, `childA-crosscheck.json` | second-RPC sweep (block 71640139) + same-block probe |
| `childA-run.log` | sweep console log |
| `childA-cast-citations.txt` | direct `cast` calls at blocks 71640282 / 71640371 |
| `childA-market-table.md` | generated raw table (§1) |
| `src/0x30edf82b…json`, `src/c3_oracle_ProtocolFTSOV2Oracle.sol` | fetched verified C3 oracle source |

**Bottom line:** claims 1, 2, 3 (as worded), 4, 6, 7, 8 **CONFIRMED**; claim 5 **partially falsified** — the C3 isoJOULE market has a live 1e13 owner price override (all C1/C2 `assetPrices` are zero and the sFLR/flrETH price legs match exactly). No other counterexamples.
