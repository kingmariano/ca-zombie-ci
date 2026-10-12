# PureSwap (BSC) — L2 Phase-2 zombie deep-dive

**Date:** 2026-10-12 · **Chain:** Binance Smart Chain (chain id 56, BSC) · **Status:** read-only; PoC fork-verified only; **no mainnet transactions**.

**Finding source:** L2-triage-A row `pureswap` — "LIVE-FUNDED, $179,744 (CI full pair enumeration), DefiLlama $260,753"; protocol marked dead (`deadUrl`), ~4.6 years since launch.
**Mission:** quantify rigorously what an **external, unprivileged attacker** can extract from PureSwap **live, right now**.

---

## TL;DR

| Target | Live extractable (unprivileged) | Why closed / open | Latent risk |
|---|---|---|---|
| PureMaker protocol fee-LP (~94–100% of every major pair, ≈ **$250.0k nominal / $173.7k llama-priced**) | **$0.00** | `convert()` — the only function that can move the fee-LP — is **permanently bricked**: it must send PURE to its immutable `bar = address(0)`, and `PureToken._transfer` rejects the zero address. 96/96 (48 pairs × 2 makers) simulated calls revert; the LP has no other exit (no transfer/sweep/approve). ⇒ **stuck (S)** | none — nobody (not even the owner) can move it |
| Pair reserves (LP-held) | **$0.00** | Pairs are canonical, verified `PureSwapPair` (single runtime code hash `0x050a6eff…`); balances == reserves (no skimmable excess); swap prices track market (largest single-pair one-way arb ≈ **$0.22**, all of it MX internal-price artifact; real-token pairs < $0.01); FoT k-check uses actual balance deltas | none |
| `skim()` excess on junk pairs | ≈ **$0.00** | largest excess is 5.86e14 wei of LTRBT (fee-on-transfer, ~10% tax on skim; unpriced). Total priced excess = **$0.00** | none |
| PureChef / SingleChef farms | **$0.00** | Standard Sushi-MasterChef clones; PureChef PURE balance **0** ⇒ pending rewards unbacked; SingleChef withdrawals pull only `msg.sender`'s pending from the dispatcher EOA. Users can withdraw stakes (H-O) | owner-key risk only |
| Admin keys | **$0.00** | `feeToSetter`, maker owner, MX minter, token owners are **EOAs** (code len 0). They can change *future* fee config/migrator (and MX minter can mint up to cap) but **no function moves existing maker LP** | P: MX dilution; fee routing |

**Total live extractable by an unprivileged attacker now: $0.00** (high confidence; largest theoretical swap-dust $0.22, no opcode path to the protocol's own LP).
**Holder-recoverable (H-O): ≈ $15.4k nominal / ≈ $7.6k llama-priced** (farm-user stakes + non-maker LP).
**Stuck/bricked (S): ≈ $250.0k nominal / ≈ $173.7k llama-priced** (protocol fee-LP) + 1000 wei/pair minimum liquidity.
**Privileged-only (P): $0 effective** (keys exist but nothing of value is reachable).

Value vs triage: essentially unchanged — triage CI $179,744 ≈ our **$180,491** llama-priced pool total at block 127,187,717; triage DefiLlama $260,753 ≈ our **$262,127** nominal total (MX/PURE valued at on-chain internal mids).

---

## 1. The finding, in exact terms

PureSwap is a SushiSwap-style fork on BSC (verified contracts, solc 0.6.12):

* `PureSwapFactory` `0x94b4188d143b9dd6bd7083ae38a461fcc6aad07e` — 48 pairs, `feeTo()` = (**feeToPure**, **feeToMx**).
* `feeToPure` = `PureMaker` `0xcc93fbbfae96d2fdc562afce89f466f2996b4c95`
* `feeToMx` = `PureMaker` `0xa7d7c06928a6a255a8e7083433f3fcea08082698`
* Both makers: `bar()` = `address(0)` (**immutable**, set in constructor), `owner()` = EOA `0xe195cbb2c2dc59c50421d433a6cb89d5078e6016`, `factory()` correct, PURE balance 0.

Every `mint`/`burn` on fee-on pairs calls `_mintFee()` which mints the protocol fee **to both makers** (`PureSwapPair._mintFee`, double-mint is the fork's design). Over ~4.6 years of the dead farm era every k-growth crystallized fee LP to the two makers, so today they own ~94–100% of every major pair.

**The brick.** `PureMaker.convert(token0, token1)` is the *only* function that moves the maker's LP: it transfers the maker's entire LP balance into the pair and calls `pair.burn(address(this))`, then routes the underlying toward PURE and **sends the PURE to `bar`**, i.e. `address(0)`:

* direct path: `IERC20(pureToken).safeTransfer(bar, amount0)`
* swap path: `_toPURE(...)` → `pair.swap(amountOut, 0, to = bar, "")`

`PureToken` (`0x481f0557fb3bb5ee461fd47f287b1ca944ad89bc`, verified, OZ 3.1-based) rejects zero-address transfers:

```solidity
function _transfer(address sender, address recipient, uint256 amount) internal virtual {
    require(sender != address(0), "ERC20: transfer from the zero address");
    require(recipient != address(0), "ERC20: transfer to the zero address");
    ...
```

On-chain proof (eth_call at block 127,152,782+):
* `PURE.transfer(0x0, 1e18)` from a PURE holder → revert `ERC20: transfer to the zero address`.
* `PM1.convert(WBNB,BUSD)` / `PM2.convert(WBNB,BUSD)` from an EOA → revert `PureSwap: TRANSFER_FAILED` (the pair's `_safeTransfer` to `to = bar = 0x0` fails).
* **All 96 (48 pairs × 2 makers) combinations revert** (CI matrix): 32 `TRANSFER_FAILED` (PURE → 0x0 inside the pair swap), 16 `SafeERC20: Transfer failed` (direct PURE → 0x0), 24 `INSUFFICIENT_LIQUIDITY_BURNED` (maker holds no LP in empty pairs), 24 `PureMaker Cannot convert` (missing bridge pair, e.g. FIL→WBNB). **0 succeed.** `convertMultiple()` takes the same path.

There is no other exit: PureMaker has no `transfer`/`sweep`/`approve`; nobody else can `pair.transferFrom(maker, …)` (allowance never granted); `pair.permit` needs a maker signature the contract cannot produce; factory `setMigrator` only affects first mints of pairs with `totalSupply == 0` (none exist; every pair has ≥1000 wei of MINIMUM_LIQUIDITY).

⇒ **The protocol fee-LP is permanently stuck. Nobody — attacker, holder, or owner — can move it.** This is the dominant correction to the triage "live" figure: ~96–99% of the counted TVL is bricked, not live.

## 2. Live-state assessment (all values re-read on-chain)

Audit snapshot block **127,152,782** (local full dump) and CI re-scan at blocks **127,187,367–127,187,717** (GitHub-hosted runner, `ci/scan.py`); both agree.

| Contract | Check | Value |
|---|---|---|
| Factory `0x94b4…aD07E` | `allPairsLength` | 48 |
| | `feeTo()` | `(0xcc93…4c95, 0xa7d7…2698)` both `PureMaker` |
| | `feeToSetter()` | `0xe195cbb2…6016` — EOA (code len 0) |
| | `migrator()` | `0x0` |
| Makers | `bar()` | `0x0` (immutable) |
| | `owner()` | `0xe195cbb2…6016` (EOA) |
| | PURE balance | 0 |
| Pairs | code | verified `PureSwapPair`; runtime hash `0x050a6effa82df4866c96ad3011b0e2fc6e4135932e3736f2125dd12e2f063929` on all sampled pairs (one canonical impl; factory `pairCodeHash 0x8e9f3777…`) |
| | balances vs reserves | equal on all real pairs (no excess); max excess = junk pair `0x0773ae59…` (LTRBT/BNBTigerR) 5.86e14 wei LTRBT — fee-on-transfer junk, ~10% skim tax, no market → $0 |

**Top pairs and protocol ownership** (makers' LP share; value at snapshot prices):

| Pair | Reserves (human) | Pool $ | Maker share | Maker $ (S) | Chef/user LP (H-O) |
|---|---|---|---|---|---|
| MX/WBNB `0x984648bd…` | 23,903.4 MX + 60.64 WBNB | 91,437 | 94.34% | 86,269 | 5,112 (Chef) |
| WBNB/BUSD `0xca7a9690…` | 48.41 WBNB + 36,436.7 BUSD | 73,028 | 98.21% | 71,721 | 1,307 (Chef+EOA) |
| MX/BUSD `0xefb83ba7…` | 17,185.6 MX + 32,819.6 BUSD | 65,829 | 98.72% | 64,980 | 849 |
| BTCB/WBNB `0xdbb13ef5…` | 0.0594 BTCB + 6.60 WBNB | 9,930 | 99.6% | 9,892 | 38 |
| ETH/WBNB `0xe69e6a6e…` | 1.853 ETH + 6.29 WBNB | 9,492 | 99.6% | 9,457 | 36 |
| USDT/BUSD `0x37126fdd…` | 1,853.0 USDT + 1,852.5 BUSD | 3,710 | 81.9% | 3,038 | 672 |
| PURE/WBNB `0xe079424a…` | 11.87M PURE + 1.635 WBNB | 2,456 | 31.1% (Chef holds 58.4%) | 763 | 1,693 |
| WBNB/XVS `0x45b19669…` | 1.490 WBNB + 352.07 XVS | 2,253 | 88.7% | 1,997 | 256 |
| PURE/BUSD `0x451a1ffa…` | 6.26M PURE + 646.05 BUSD | 1,294 | 10.1% | 131 | 1,163 |
| PURE/MX `0xfdbf0a62…` | 5.39M PURE + 294.52 MX | 1,120 | 21.0% | 235 | 884 |
| …41 more (mostly junk-token pairs) | | | | | |

Totals over all 48 pairs (block 127,187,717, coingecko/DefiLlama snapshot prices; MX at Pancake MX/BUSD mid, PURE at PURE/BUSD mid):

* pool total **$262,127** nominal / **$180,491** llama-priced only
* **maker fee-LP $250,033 nominal / $173,718 llama-priced → S (bricked)**
* PureChef-staked LP **$10,308 / $5,999 → H-O**; other EOA LP **$1,787 / $773 → H-O**
* skimable excess **$0.00**

SingleChef (single-staking, user stakes — all H-O): 9,678,432.9 PURE ($998), 778.0 MX ($1,489), 0.5146 WBNB ($388), 465.1 BUSD ($467), BTCB dust. Total ≈ **$3.34k**. Its rewards are pulled from dispatcher EOA `0xe195cbb2` via `transferFrom` (allowance ≈ 2^256−9.19e24; spent 9.19M PURE historically); only the caller's own pending can be pulled — no unprivileged drain.

## 3. What an attacker can / cannot do

| Path | Preconditions | Result |
|---|---|---|
| `PureMaker.convert()` / `convertMultiple()` to sweep the protocol fee-LP | only a funded EOA + gas | **reverts 100%** (PURE → 0x0). No state change. |
| Sandwich/arb around `convert()` | mempool position | impossible — there is no successful `convert()` to sandwich. |
| LP-positioning "harvest" (mint LP, force convert, redeem) | capital | dead at the convert step. |
| Steal maker LP via `transferFrom`/`permit` | allowance / maker signature | impossible (allowance 0; contract cannot sign). |
| `skim()` excess | gas | only dust: real pairs 0; junk pairs fee-on-transfer junk (worth $0). |
| Stale-price arb vs market | flash loan | pools track market within ~0.3% (active bots: 4–7 swaps/10h on top pairs); best single-pair one-way arb across all 48 pairs ≈ **$0.22** total (MX internal-mid artifact; real-token pairs < $0.01) — less than gas. |
| Farm exploit | LP/PURE stake | MasterChef clones are standard; PureChef is unfunded (PURE balance 0, claims transfer 0); SingleChef pays only `msg.sender`'s pending. No drain. |
| Admin abuse (P) | `0xe195cbb2`/`0x4982085c` keys | can change future fee config/migrator and mint MX up to cap — cannot push existing maker LP out (no function). |

## 4. PoC / fork verification

`poc/` (Foundry, forked BSC; runs in CI `.github/workflows` → `forge test -vvv`; also `ci/run.sh` re-runs the 96-call convert matrix + live valuation + arb scan and writes `ci-out/ci-live-scan.json`):

* `test_convert_is_bricked_on_all_pairs` — loops **all 48 pairs × both makers** from an attacker EOA; asserts **0 successes**; asserts `bar()==0`, and exact revert data `Error("PureSwap: TRANSFER_FAILED")` on WBNB/BUSD; asserts `PURE.transfer(0x0,1e18)` reverts `Error("ERC20: transfer to the zero address")`.
* `test_maker_fee_lp_is_permanently_stuck` — maker LP balances unchanged after attacker+owner convert attempts; allowance 0; `transferFrom` from attacker reverts; makers hold 0 PURE (`burn()` is a no-op).
* `test_external_lp_can_mint_and_burn` — non-maker LP mint/burn works (H-O exit): got back 0.4037 WBNB + 297.81 BUSD.
* `test_skim_excess_is_dust` — real pairs excess 0; junk pair excess 5.8626e14 wei LFT/BNBTigerR, skim returns 5.2764e14 (10% fee-on-transfer tax) → $0.
* `test_swap_prices_track_market` — WBNB/BUSD implied/market ratio 1.00296; best grid arb = $0.

Local run: **5/5 PASS** (fork block 127,187,076).
CI run: `bash /home/heisenberg/CA/ci/ci-run.sh pureswap` → **run URL/status recorded in `ci-log.txt` + `summary.json` (see below)**; CI also lands `ci-out/ci-live-scan.json` (convert matrix 96/96 reverts, valuation, arb scan).

## 5. Verdict, residual & latent risk

* **E-U = $0.00 (high confidence).** The protocol's own LP — the overwhelming majority of the triage value — is provably un-movable (bricked `convert()`, no alternative path). Remaining surfaces (skim, arb, farms) are dust, market-priced, or holder-scoped.
* **H-O ≈ $15.4k nominal / $7.6k llama-priced**: PureChef user LP $10.3k + other EOA LP $1.8k + SingleChef stakes $3.3k. All withdrawable via standard functions; PureChef PURE rewards are unfunded (unclaimed rewards ≈ $0 realizable).
* **S ≈ $250.0k nominal / $173.7k llama-priced**: maker fee-LP (permanent) + 1000 wei/pair minimum liquidity + unbacked farm reward debt (accounting-only).
* **P = $0 effective**: EOA `feeToSetter`/`maker owner`/`MX minter` can alter *future* protocol params (and MX supply up to its 300M cap) but cannot reach existing LP; no privileged value withdrawal exists.
* **Latent risks (not extractable now):** none for E-U; MX minter EOA can dilute MX (affects nominal MX pricing); occasional arb bots keep pools near market, which would keep any future dislocation small.

## 6. Methodology & sources, caveats, files

**Method.** Findings were re-derived from deployed code, not from lists: factory → `allPairs()` → 48 pairs; every claimed address read at pinned blocks via JSON-RPC (`eth_call`/`getCode`/`getLogs`), cross-checked on ≥2 providers (a public node transiently served stale zeroes for `balanceOf` — all readings were re-verified against a keyed provider and Ankr/DRPC). Sources for all contracts pulled from Etherscan V2 (chain 56) and stored under `analysis/`. Prices: DefiLlama `coins.llama.fi` snapshot (2026-10-12), MX at Pancake `MX/BUSD` mid, PURE at the `PURE/BUSD` pool mid (both flagged as non-externally-liquid). Conversions verified by direct `eth_call` (no state change) and by fork PoC.

**Caveats.** (1) MX and PURE have no real external market; the nominal "$262k" prices them at internal/thin pool mids — the llama-priced subset ($180.5k) is the sounder number. (2) The fork PoC runs at CI-run latest block; structural revert behavior is block-independent, verified at three blocks. (3) Residual/junk tokens are priced at $0 when unpriced. (4) `PureChef` pending-reward figure is accounting-only — the contract holds 0 PURE, so it is S, not H-O.

**Files.** `analysis/fetch_state.py` (pair state dump), `analysis/final_valuation.py` (E-U/H-O/P/S split), `analysis/scan_events.py` (recent Swap/Mint/Burn/Sync), `analysis/*.json` (raw dumps incl. `pairs-state.json`, `maker-lp-all.json`, `chef-pools.json`, `external-pairs.json`, `valuation-split.json`, sources `.sol`/ABIs), `ci/scan.py` (fresh CI scan + convert matrix), `poc/` (Foundry tests), `ci-out/ci-live-scan.json` (CI evidence), `ci-log.txt` (CI log), `summary.json`.
