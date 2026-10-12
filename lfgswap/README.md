# LFGSwap EthereumPoW (ETHW) — L2 Phase-2 deep dive

- **Date:** 2026-10-12
- **Chain:** EthereumPoW (ETHW), chain id `10001`
- **Target:** LFGSwap liquidity system — factory `0xf66cef53c518659bFA0A9a4Aa07445AF08bf9B3a` (1,581 pairs)
- **Status:** read-only; fork-verified only (Foundry on ETHW fork); **no mainnet transactions**; no secrets in this folder.
- **Triage row:** `l2-triage-b` — LIVE-FUNDED, on-chain read **$120,090.75** (block 25,236,781); DefiLlama protocol TVL **$295,728** at scan time (2026-10-12).

## TL;DR

| Surface | Live extractable by unprivileged attacker now | Why closed / open | Latent risk |
|---|---|---|---|
| UniV2 pair math (k-invariant) | **$0** | canonical `LfgSwapPair.sol` k-check present; fork test 01: 90 %-drain swap reverts, reserves unchanged | none (source + bytecode agree) |
| `initialize()` re-point | **$0** | `require(msg.sender == factory)`; fork test 02 reverts | none |
| Factory admin (`feeTo` fee hijack) | **$0** | `feeToSetter` = Gnosis-Safe-style 3/5 multisig proxy `0x67de…1A38`; `setFeeTo`/`setFeeToSetter` revert for arbitrary callers (test 03) | 5 owner EOAs; feeTo EOA `0x7872…3276` still receives protocol LP |
| `skim()` excess / one-sided reserves | **$0** (sampled) | sampled pairs balance == reserve exactly; source shows zero-reserve pairs revert on swap | bots may skim future donations; full-scan result in §5 |
| Asset minting (dump into pools) | **$0** | LFG mint disabled (0 minters); USDT/USDC/BUSD controller-gated EOA; memes not mintable; `DX` owner renounced to `0x1` | owner keys of LFG-family tokens are live EOAs |
| Cross-pool arbitrage (all 2–3 hop cycles) | **≈ $0** (dust ≤ a few $) | every closed loop (incl. WETHW-start) returns ≤ input after fees; fork-verified loss: 20 WETHW → … → 5.836 WETHW | pool depth only; see §6 |
| Face-value stable plays (conditional) | **$0 risk-free; up to ≈ $144 one-shot "if" chain-local stables redeem at par** | 226.4 WETHW ($61.7) → 15.00 USDC → 193.04 USDT (fork test 08); 20 WETHW → 18.19 USDT (test 05). USDT's realizable on-chain exit ≈ $0.0875/USDT (test 06) | issuer EOAs are active (nonces 47 / 11,203); if USDT/USDC are redeemable at ~$1 the USDC/USDT dislocation is a real ~$131 opportunity |

**Total live extractable now (risk-free, realizable value): $0.00 — confidence: high.**
Conditional (not counted in headline): ≈ **$144 face** one-shot if the chain-local stablecoins are redeemable at par — this is a bet on the issuer, not a risk-free extraction; at on-chain realizable prices the same trades are losses (−$3.9 and −$53.6 respectively).

Face value in the pools is **$120.1k (triage balance read)** / **$295.7k (DefiLlama feed)** — dominated by `vvXEN` ($113k at $4.898e-9) — but that value is **not extractable** by an unprivileged attacker (see §4–§6).

## 1. The system in exact terms

LFGSwap is a Uniswap-V2 fork deployed on ETHW (October 2022). The project's source is public: `github.com/LfgSwap/lfg-protocol` (`contracts/core/LfgSwapPair.sol`, `LfgSwapFactory.sol`, `LfgSwapRouter.sol`, `LfgToken.sol`; CertiK + LFG audits in `audit/`).

Verified identity of the deployed code:

- Factory selectors match the repo's `LfgSwapFactory.sol` (`createPair`/`getPair`/`allPairs`/`pairFor`/`initCodeHash`/`getSalt`/`sortTokens`/`feeTo`/`feeToSetter`/`setFeeTo`/`setFeeToSetter`); `pairFor(WETHW, USDT)` returns the deployed pair `0x9964ea…d1be`, i.e. the on-chain pair init code hash matches the repo's `type(LfgSwapPair).creationCode` hash.
- Deployed pair runtime (14,623 bytes) has exactly: canonical UniV2Pair selectors + `permit`/`nonces`/`DOMAIN_SEPARATOR`/`PERMIT_TYPEHASH` + `initialize(address,address)`. Source: k-invariant check `require(balance0Adjusted*balance1Adjusted >= reserve0*reserve1*1e6, 'LfgSwap: K')` is present; `initialize` is `msg.sender == factory`; `MINIMUM_LIQUIDITY = 1e3`; standard `_mintFee` (`5*rootK + rootKLast`); `swap` reverts when either reserve is 0 (`amount0Out < reserve0 && amount1Out < reserve1` ⇒ zero-reserve pairs are bricked, not drainable).
- Factory admin: `feeToSetter` is a 124-byte `masterCopy()` DELEGATECALL proxy (`0x67deFBFa85289E9a767D29ef9682a9B80Bd11A38`, impl `0xf3b5b8a82c4e42b07a5b71434b1666c3c0087899` = Gnosis MultiSig master copy; `getOwners()` = 5 EOAs, `getThreshold()` = 3, nonce 1). `feeTo` = `0x787248E6421b3045C2e7B8570A01a3c363173276` (EOA, nonce 119, funded).
- Token roles: `LfgToken` mint/blacklist admin has **0 minters** (`getMinterLength()==0`) and `owner()==0x0` — LFG mint is permanently disabled. `USDT`/`USDC`/`BUSD` are chain-local issuances with a single owner EOA `0x1e1d8d81…bc66` (nonce 47) and controller EOA `0x456325f2…e039` (nonce 11,203, live operator); `mint()` reverts for outsiders. `vvXEN` is a XEN-fork (staking/claimRank/claimMintReward). Pepe/FROG/wFire/SHIBW/DX probes: no public mint (`DX` owner is `0x…0001`, its `issue(uint256)` is owner-gated; Pepe is a taxed launch token with `_set_Fees`, `set_New_Pair_Address` owner hooks).
- No farm/MasterChef was found on ETHW: the repo router has no swap-mining hook, LFG has no minters, and the only staking contract is the XEN built-in inside `vvXEN`.

## 2. Machine-readable audit trail (local, read-only)

- Factory: `allPairsLength() = 1581` (`0x62d`); `feeTo`/`feeToSetter` as above (block 25,241,806).
- Key pools at latest block (see `analysis/key_pools_fresh.json`, block 25,242,848):

| Pair | Token0 | Token1 | Reserves (fresh) |
|---|---|---|---|
| `0x3b18525b17c9b83dc6a34bbfd60a5c680960926f` | Pepe (9 dec) | WETHW | 93,188,031.41873284 / 63.331969274897963389 |
| `0x1098da21515468f33b43b14533203f14c0b52b5b` | USDT (6 dec) | Pepe | 32.194353 / 17,125,557.984980367 |
| `0x75e43c101688ba4fb53e5f52876a3f3c995787f9` | USDT | LFG | 1,386.270495 / 31,887,922.34413017 |
| `0x03eba1aeb1b114ce767c65275f150dc23d6e84e2` | USDC | USDT | 74.519739 / 1,154.7953 |
| `0xb23396bf2191b300d1f296d1af2de20c10195a8a` | USDC | WETHW | 23.236001 / 123.876797778496608688 |
| `0xabe4cc55719012c076ee3ae578713347eb00cc27` | vvXEN | vvDXN | 23,215,892,821,991.36641977823… / 328,076.195280… |
| `0x6eeafbb814bed86dd1aba442298e59bcf88e46c8` | vvXEN | XenEthw | 165,950,948,275.861… / 5,671,521.7646… |

- All sampled pools: `balanceOf(pair) == reserves` exactly → no skimmable excess (fork test 04). Full-factory excess/one-sided scan: `ci-out/excess.json` (CI artifact).
- Price inputs: DefiLlama `/prices/current` chain key `ethpow` (WETHW $0.2726, USDT $0.9993, USDC $0.9998, BUSD $0.9990, WBTC $83,409.21, vvXEN $4.898e-9) — used only for USD labels; extraction conclusions use on-chain executable rates.
- `analysis/prices.json`, `analysis/gate_probes.json`, `analysis/factory_admin_probes.json`, `analysis/weth_copy.json`, `analysis/counter_tokens.json`, `analysis/triage_pairs_raw.json`.

## 3. Gate proofs (each claim is a fork test — `poc/test/LfgEthw.t.sol`)

| Test | Claim | Result |
|---|---|---|
| 01 | k-invariant enforced: pay 0.001 WETHW, request 90 % of Pepe reserve → must revert; reserves unchanged | PASS (revert; reserves unchanged) |
| 02 | `initialize()` closed on live pair | PASS (revert) |
| 03 | `setFeeTo`/`setFeeToSetter` revert for arbitrary EOA; `feeToSetter` is a contract (Safe) | PASS |
| 04 | No excess on 5 sampled funded pairs (`balance == reserve`) | PASS |
| 05 | Live path WETHW → Pepe → USDT executes | PASS — 20 WETHW → 22,314,463,830,623,868 Pepe → **18,191,224 USDT** (18.19) |
| 06 | Closing the loop WETHW → Pepe → USDT → USDC → WETHW is a **net loss** | PASS — 20 WETHW in → **5,836,076,960,596,908,643 wei WETHW out** (−14.16 WETHW ≈ −$3.86) |
| 07 | Ghost mainnet WETH at `0xC02aaA39…6Cc2` is a live ETHW wrapper (`deposit()` mints 1:1) | PASS |
| 08 | Biggest face-value play: WETHW →(USDC/WETHW pool) → USDC →(USDC/USDT pool) → USDT | PASS — 226.4 WETHW → 15,002,530 USDC → **193,042,079 USDT** (193.04) |

Local run: 8/8 PASS (2026-10-12, fork blocks 25,242,903–25,242,917). CI run: see §7.

## 4. What an attacker can and cannot do

- **Cannot** drain any pair: k-check present; no missing-invariant variant found in source; `amount0Out < reserve0` brick rule blocks zero-reserve games.
- **Cannot** re-point tokens via `initialize`.
- **Cannot** become `feeTo`/`feeToSetter` (3/5 Safe), so the accumulated protocol-fee LP (`kLast` growth exists on many pairs — `ci-out/fee_mint.json`) is not claimable by outsiders; it accrues to the existing `feeTo` EOA if anyone triggers mint/burn.
- **Cannot** mint LFG (0 minters), USDT/USDC/BUSD (controller EOA), Pepe/FROG/wFire/SHIBW/DX (no public mint).
- **Can** trade the pools permissionlessly. Best realistic loops:
  - *Real-asset loop*: none profitable. The optimizer over all 2- and 3-hop cycles on fresh reserves finds only dust (≤ a few $, mostly sub-$1; e.g. HEX/WETHW, WBTC/WETHW dust paths where the scarce token cannot be sourced in size).
  - *Face-value plays* (test 05/08): WETHW → Pepe → USDT (10.1× face spread) and WETHW → USDC → USDT (15.5:1 pool). These pay out chain-local `USDT`, whose only in-system exit is back through the same dislocated pools: 18.19 USDT → 5.836 WETHW ($1.59) ⇒ **USDT realizable ≈ $0.0875** (test 06). Buying via Pepe costs $0.30/USDT; the loop therefore loses money unless USDT is redeemed externally at ~par.
  - *XEN-style mint → dump*: `vvXEN` can be minted permissionlessly (XEN mechanics) but terms are ≥1 day and rewards at rank 232.2 M are small; dumping minted vvXEN into the `vvXEN` pools yields Pepe/LFG/XenEthw etc. whose only exits are the same pools — bounded to dust in real terms.
- **Capital/cost**: the only externally valuable asset on this chain is ETHW (via `WETHW` or the ghost WETH). Any attempt to convert pool balances into ETHW requires pushing a token through a WETHW pool; the cheapest acquisition route for the needed tokens (e.g. Pepe via the WETHW pool) is the pool itself, and the round trip is negative (test 06). Gas on ETHW is negligible, so costs are the swap fees/slippage, already accounted for by the fork measurements.

## 5. Live-state scan (whole factory)

`ci/full_scan.py` re-enumerates all 1,581 pairs at a pinned block via the keyless public RPC `https://mainnet.ethereumpow.org` (never a keyed URL in this repo) and reports:

- per-pair fresh `token0/token1/reserves/balances/totalSupply/kLast`,
- **excess** pairs (balance > reserve ⇒ `skim()`-able by anyone) and **one-sided reserve** pairs,
- `kLast`-based protocol-fee LP estimates (P-category),
- per-token balances & USD totals,
- an exact **2–3 hop arbitrage cycle optimizer** (golden-section over optimal input size, 0.3 % fee per hop) over the whole graph, ranked in USD.

Results: `ci-out/scan_summary.json`, `ci-out/pairs_fresh.json`, `ci-out/excess.json`, `ci-out/fee_mint.json`, `ci-out/arb_cycles.json`, `ci-out/pairs_summary.csv` (CI artifact + this folder).

## 6. Verdict

- **E-U (external unprivileged extractable, risk-free): $0.00 — high confidence.** No pair drain, no admin hijack, no mint, no profitable real-asset arbitrage; the deepest USDT route nets a loss when exited on-chain.
- **Conditional upside: ≈ $144 face, one-shot** (USDC soak $131 + Pepe route $13) — real only if the chain-local USDT/USDC/BUSD are redeemable at ~par by their issuer (owner `0x1e1d…bc66`, controller `0x4563…e039`, both active EOAs). At on-chain realizable prices these trades lose $3.9 / $53.6. Not counted in the headline.
- **H-O (holder-only):** LP holders retain normal `burn()` redemption over $120.1k nominal pool balances. The hard-asset side of all 1,581 pairs is only ≈ **$4.3k face** (WETHW 5,897.40 → $1,607.63; chain-local USDT 2,582.51 → $2,580.70; USDC 101.11; BUSD 49.76; WBTC 0.00006289 → $5.61), the rest is memes/ghost tokens/vvXEN with no external venue.
- **P (privileged):** protocol-fee rights (`feeTo`, 3/5 Safe) — no live value accessible to outsiders.
- **S (stuck):** zero-reserve/bricked pairs; the vvXEN/ghost-token sides of dislocated pools; `DX` (owner renounced to `0x1`, its $496-WETHW pool is gated behind an unsourceable token).

**Blockers that keep this closed:** canonical + audited pair source; Safe-gated admin; disabled LFG mint; controller-gated stables; no external venue for the "valuable-looking" tokens; USDC total supply ≈ 101 tokens (74.5 already inside the dislocated pool), so the USDC/USDT 15.5:1 ratio is not exploitable without new USDC.

## 7. CI

- Workflow: `poc.yml` on `kingmariano/ca-zombie-ci`, branch `lfgswap`.
- Run URL: pending (recorded below once finished).
- Artifacts: `ci-out/*` (scan) + `forge test` logs.

## 8. Methodology, caveats, files

**Method.** Fresh on-chain reads (public keyless RPC, latest block pinned per artifact); source cross-check against the project's public repo; selector/bytecode analysis; DefiLlama prices for USD labels only; Foundry fork PoCs executing the actual swaps; full-factory scan + cycle optimizer on CI.

**Caveats / uncertainty.**
1. The chain-local stables' **redeemability is the single largest uncertainty**. DefiLlama prices them at ~$1.00 (confidence 0.99), the issuer/controller EOAs are active, but there is no verifiable bridge/redeem venue inside LFG; the in-system exit value is ≈ $0.0875/USDT. If they are par-redeemable, up to ~$144 one-shot (`test_08`) becomes real, and the USDC/USDT pool would remain a standing attractor (bounded by USDC scarcity).
2. Some pools in the triage snapshot had RPC errors (429); this CI scan re-enumerates the whole factory directly.
3. `vvXEN` at $4.9e-9 drives 94 % of the triage USD; that price is feed-based, and the token's real exit liquidity is internal to these pools only.
4. Meme tokens (Pepe etc.) are owner-controlled launch tokens with fee/limiter hooks; the fork tests measure realized amounts at current settings, but the owner can change fees/pairs at will (rug risk to *traders*, not an extraction for outsiders).
5. No full holder-index scan for a hidden farm was possible without a public indexer; the source repo, minter lists, and router were checked and show none.

**Files.**
- `analysis/` — state dumps: `key_pools_fresh.json`, `pairs_top_detail2.json`, `triage_pairs_raw.json`, `prices.json`, `gate_probes.json`, `factory_admin_probes.json`, `weth_copy.json`, `counter_tokens.json`, `4byte_selectors.json`
- `poc/` — Foundry project (`test/LfgEthw.t.sol`, 8 tests) with vendored forge-std
- `ci/` — `run.sh`, `full_scan.py`
- `ci-out/`, `ci-artifacts/`, `ci-log.txt` — CI results
- `summary.json` — machine-readable verdict
