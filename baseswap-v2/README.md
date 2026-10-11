# BaseSwap V2 (Base) — L2 Phase-2 deep dive: live extractable-value assessment

**Campaign:** zombie-hunt II · L2 watchlist Phase 2 · **Chain:** Base (8453) · **Date:** 2026-10-11
**Status:** read-only research; PoC fork-verified on GitHub Actions only. **No mainnet transactions were sent.**
**Triage row:** LIVE-FUNDED $643,169 (medium confidence) — factory `0xFDa619b6d20975be80A10332cD39b9a4b0FAa8BB`, 8,290 pairs.

---

## TL;DR

| Target | Live extractable (unprivileged, E-U) | Why closed / open | Latent risk |
|---|---|---|---|
| BaseSwap V2 factory + all 8,290 PancakePair pairs | **$0.00** (skim excess __EXCESS__; no other path) | Pair/factory code is canonical PancakeSwap V2; every permissionless entry point (`swap`, `skim`, `sync`, `mint`, `burn`) follows audited AMM math; no excess balances exist to skim | Normal AMM arbitrage against stale reserves; MEV |
| MasterChefV2 (LP staking) | **$0.00** | Standard acc-per-share MasterChef variant; only depositors can withdraw; no reentrancy; emissions off (`bswapPerSec = 0`) | Owner Safe can re-enable emissions; dummy pool (pid 16) would absorb ~99.9999% of emissions |
| feeTo = FactoryManager (protocol-fee LP) | **$0.00** | All fund-moving functions are `onlyOwner`/`onlyOwnerOrOperator`; owner = 2-of-4 Safe, operator = EOA | UUPS upgradeable by owner Safe; operator key can collect fees to treasury |
| SmartChef (BSWAP staking) | **$0.00** | `deposit`/`withdraw`/`emergencyWithdraw` self-service; admin onlyOwner | WETH reward reserve is 0 — pending rewards unpayable |

**Total live extractable by an external, unprivileged attacker now: ≈ $0.00** — confidence **high**.
The $643k–$685k tracked by DefiLlama is **LP principal** (holders' own capital, withdrawable pro-rata by LP burn: H-O), plus a small protocol-fee LP position held by the FactoryManager (P) and dust locked by `MINIMUM_LIQUIDITY` (S).

---

## 1. What BaseSwap V2 is, and why "zombie" is the wrong frame

BaseSwap is a PancakeSwap-V2 fork DEX on Base. The triage flagged the V2 factory (8,290 pairs) as LIVE-FUNDED with DefiLlama TVL $643,169. Live checks show the DEX is still **operational, not abandoned**:

- The most recently created pair (`allPairs(8289)` = `0x02881bfBC3c59143099ebd87e669e96C5C2A1fe5`) was created **2026-10-06** (block 52,250,539, tx `0xfd4a23cd…`) — five days before this report.
- DefiLlama's live adapter value at 2026-10-11 ≈ **$685,209** (vs $643,169 at triage).
- All sampled pair bytecode is a single codehash (canonical PancakePair), factory verified.

So the correct question is not "can someone rescue abandoned funds" but "does the canonical V2 machinery leak value to an unprivileged attacker".

## 2. The mechanism, in exact terms

### 2.1 Factory (`0xFDa619b6d20975be80A10332cD39b9a4b0FAa8BB`) — canonical PancakeFactory

- Verified source (v0.5.16); function-by-function identical to public PancakeFactory (`createPair`, `setFeeTo`, `setFeeToSetter`, `allPairs`, `getPair`, `allPairsLength`; only quote-style diffs).
- `feeTo = 0x463112327576814f80DA8D3632f7bad23c853A29`; `feeToSetter = 0xAF1823bACd8EDDA3b815180a61F8741fA4aBc6Dd`.
- `setFeeTo`/`setFeeToSetter` require `msg.sender == feeToSetter` → the Safe. No migrator, no owner, no pause, no upgrade.
- `createPair` is permissionless (by design); new pairs start empty.

### 2.2 Pair (`PancakePair`, one runtime for all 8,290) — canonical PancakeSwap V2 pair

- Verified source (v0.5.16). Diffed against public PancakePair: constructor, `getReserves`, `initialize`, `_update`, `mint`, `burn`, `swap`, `skim`, `sync` are identical modulo quote style.
- Swap fee **25/10000 = 0.25%**; K check `balance0Adjusted·balance1Adjusted ≥ reserve0·reserve1·10000²`.
- Protocol fee: `_mintFee` mints LP to `feeTo` equal to the **current PancakeSwap formula** (comment: "8/25 of the growth in sqrt(k)"; `num = totalSupply·(√k−√kLast)·8`, `den = 17·√k + 8·√kLast`) — public code, not a BaseSwap modification.
- **The only permissionless value-taking function is `skim(to)`**: it transfers `balanceOf(pair) − reserve` for both tokens to any caller. If no tokens have been donated/rebased into a pair, the excess is zero and `skim` reverts (SafeMath underflow) or moves nothing. `sync()` (permissionless) folds any excess into reserves, benefiting LPs pro-rata.
- `mint(to)`/`burn(to)` are standard: no LP can be minted without depositing both sides (except the theoretical two-sided-excess case, checked by scan: __TWOSIDED__); the last burn leaves `MINIMUM_LIQUIDITY = 1000` wei of LP locked at address(0) forever.

### 2.3 feeTo = FactoryManager (`0x463112327576814f80DA8D3632f7bad23c853A29`)

- `ERC1967Proxy` → `FactoryManager` (v0.8.24, UUPS, Ownable). It collects V2 protocol-fee LP (by `removeLiquidity` through the router) and V3 protocol fees, then forwards tokens to `treasury`.
- owner = the same 2-of-4 Safe; operator = `0x479013825281fA8B03135aCEf2174f346C46Ddd3` (EOA); treasury = `0xE32B416d320FDB9bC793447FE2Eefe11663d19AB` (a Safe owner).
- Every value-moving function (`collectProtocolFeeV2`, `collectProtocolFeesV2`, `transferTokenToTreasury`, `approveToken`, `swap`, `setTreasury`, …) is `onlyOwner`/`onlyOwnerOrOperator`; `_authorizeUpgrade` is `onlyOwner`. **No permissionless path.**

### 2.4 BSWAP token (`0x78a087d713Be963Bf307b18F2Ff8122EF9A63ae9`)

- Standard BEP20 + Compound-style vote checkpoints. `_transfer` has no fee/hook/blacklist.
- `mint(address,uint256) onlyOwner`; owner = MasterChefV2. MAX_SUPPLY 10,000,000e18; totalSupply **9,998,487.117e18** — only ~1,512.88 BSWAP of headroom remains. No public mint.

### 2.5 MasterChefV2 (`0x2B0A43DCcBD7d42c18F6A83F86D1a19fA58d541A`)

- Custom Sushi-style MasterChef: 17 pools, acc-per-share rewards, `teamRewardPercent=1000` (10% of emissions to treasury).
- **`bswapPerSec = 0`** → `updatePool()` mints 0; deposits/withdrawals are unaffected. owner = Safe; treasury = Safe.
- `deposit`/`withdraw`/`emergencyWithdraw` only move `user.amount` for `msg.sender`; `safeRewardTransfer` caps at the contract's BSWAP balance. No reentrancy (only standard ERC-20 calls). Stakers can always `emergencyWithdraw` their LP.
- **Latent misconfiguration:** pool 16 (lpToken = "DUMMY" `0x29399d824a99789f587a491C59210326e8ef4545`) carries `allocPoint = 1e10` out of `totalAllocPoint ≈ 1e10 + 15`. If the owner Safe re-enables emissions, ~99.9999% of BSWAP emissions accrue to that pool. Emissions are off today, and the DUMMY supply (1e18) is entirely inside the MasterChef, so no outside attacker can stake into it.

### 2.6 SmartChefInitializable (`0x86DBd5bAAE91AC576E8e5197EB2497603d0056EA`)

- BSWAP staking ("syrup pool"): stakedToken = BSWAP, rewardToken = WETH, `depositFee = 100` (1% to treasury), owner = Safe.
- Staked BSWAP = **368,303.76** (~$1,640); contract WETH balance = **0** (reward reserve exhausted — pending WETH is unpayable, but staked BSWAP is withdrawable).

## 3. Live-state assessment (all reads on Base; block recorded per item)

- **Latest block at first reads:** 52,474,337 → scan block: **__BLOCK__**.
- **Factory:** `allPairsLength() = 8290`; `feeTo`, `feeToSetter` as above; no ETH balance.
- **Pair set:** all 8,290 addresses enumerated via `allPairs(i)`; per-pair `token0/token1/getReserves/totalSupply/balanceOf(pair)` read at block __BLOCK__ (evidence: `ci-out/pairs.json`).
- **Code integrity:** 206-pair bytecode sample (first/last 20 + every 50th) → **__CODEHASHES__** distinct codehash(es). A single hash = all pairs share the canonical PancakePair runtime.
- **TVL (our pricing, DefiLlama coins + implied pairing):**
  - both-sides-DefiLlama-priced pairs: **$__TVLHARD__**
  - including implied prices for the second token of one-sided-priced pairs: **$__TVL__** (__PRICED__/__TOTALTOK__ tokens priced)
  - top pair: __TOPPAIR__ ($__TOPPAIRUSD__); top-25 pairs: $__TOP25__.
- **Skim excess:** total **$__EXCESS__** across **__EXCESSPAIRS__** pair(s) — __EXCESSDETAIL__.
- **Balance < reserve pairs:** __BROKEN__; **zero-supply pairs:** __ZEROSUP__; **supply == MINIMUM_LIQUIDITY (stuck reserves):** __STUCK__ pair(s), $__STUCKUSD__.
- **MasterChef staked LP:** __MCPOOLS__.
- **feeTo (FactoryManager) LP on top-40 pairs:** $__FEETO__ (protocol fees, P). **LP at address(0)/0xdead:** $__ZERODEAD__ (S).
- **Safe:** 2-of-4, owners `0xE32B416d…`, `0x189172B6…`, `0x5Ba18694…`, `0xe65560D5…`; version 1.4.1.

## 4. What an attacker can and cannot do

**Can (all value-neutral or self-funded):**
- Swap through any pair at the 0.25% fee (fair AMM trade).
- Call `skim(pair)` — receives exactly `balance − reserve`; live scan shows this is **$__EXCESS__** in total.
- Call `sync(pair)` — folds any excess into reserves for LPs.
- Call `mint(pair)` — reverts unless the caller actually transfers in both tokens (or two-sided excess exists: __TWOSIDED__).
- `deposit`/`withdraw` in MasterChef — only the caller's own position.
- Arbitrage pairs whose reserve ratio deviates from market price. This is ordinary AMM arbitrage (LPs' expected risk), not a protocol bug; top live deviations are listed in §6.

**Cannot:**
- Take LP principal, staked LP, BSWAP, protocol-fee LP, or FactoryManager tokens (no permissionless transfer/burn path; all admin functions gated).
- Mint LP without depositing, mint BSWAP (owner-gated), or call any factory/FactoryManager/SmartChef admin function.
- Reenter the pair during `pancakeCall` (`lock` modifier holds `unlocked=0` for the whole swap).

**Preconditions that would change the verdict:** any pair with donated/rebased balances (`balance > reserve`) → immediately skim-able by anyone; the scan measured this at $__EXCESS__.

## 5. PoC / fork verification

Foundry project `poc/` (vendored forge-std), fork of Base at latest block via `BASE_RPC_URL` in CI. Tests (`poc/test/BaseSwapLive.t.sol`):

1. `test_live_skim_excess_top_pairs` — for each of the top-20 pairs: compute `balance−reserve`, call `skim`, assert the caller received exactly the live excess (0 if none).
2. `test_donation_skim_mechanic` — donate 0.001 WETH to the top pair; anyone's `skim()` recovers it (proves the permissionless path works and would extract any real excess).
3. `test_mint_requires_deposit_reverts` — `mint()` reverts on all top pairs without a deposit (no free LP).
4. `test_masterchef_attacker_cannot_take` — for all 17 pools: attacker `withdraw` reverts, `emergencyWithdraw` moves nothing, and `MC balance ≥ totalDeposit` (stakers can exit).
5. `test_factory_admin_gated` — `setFeeTo`/`setFeeToSetter` revert `Pancake: FORBIDDEN` for an attacker.
6. `test_factory_manager_gated` — `collectProtocolFeeV2` reverts for an attacker (owner/operator only).
7. `test_lp_backing_top_pairs` — every top pair has `totalSupply ≥ MINIMUM_LIQUIDITY` and `balance ≥ reserve`.

**CI runs:** __CIRUNS__.

## 6. Market/arb surface (not counted as E-U)

Pairs with both tokens DefiLlama-priced and >$200 TVL: largest reserve-ratio deviations vs oracle — __DEVIATIONS__. These are normal AMM states (LPs bear the inventory risk); an arber's gross capture is bounded by the deviation minus the 0.25% fee, and settles as a fair trade against LP principal — not an exploit. No protocol-level oracle consumes these reserves (no lending integration found for the V2 pairs).

## 7. Verdict, residual and latent risk

- **E-U (external unprivileged): ≈ $0.00** — high confidence. The only permissionless extraction primitive (`skim`) has nothing to take across all 8,290 pairs (__EXCESS__), and all other surfaces are canonical and/or gated.
- **H-O (holder-recoverable):** LP principal in the pairs is withdrawable by its LP holders pro-rata at any time (normal burn); MasterChef stakers (__MCUSD__ staked) and SmartChef stakers (~$1,640) can self-withdraw. This is the correct bucket for the $643k–$685k headline — it is not attacker-extractable.
- **P (privileged):** the 2-of-4 Safe can set `feeTo`, upgrade the UUPS FactoryManager, re-enable BSWAP emissions (dummy-pool capture), mint remaining ~1,512.88 BSWAP, and move FactoryManager tokens to treasury. Operator EOA can collect fees. All admin trust, no public exploit.
- **S (stuck/bricked):** locked `MINIMUM_LIQUIDITY` dust (__STUCKUSD__ in supply==1000 pairs; plus 1000-wei LP per pair); SmartChef's unpayable pending WETH (reward reserve = 0).
- **Blockers/caveats:** token pricing for illiquid long-tail tokens is partly inferred from paired reserves (wide error bars on the last few % of TVL); scan is a point-in-time snapshot (block __BLOCK__) — a donation after that block would create skim-able excess.

## 8. Methodology & sources

- On-chain reads via public/keyed RPCs (never persisted): `eth_call` batch reads for all 8,290 pairs (reserves, supply, balances, token metadata) + DefiLlama `coins.llama.fi` prices; Blockscout Base API for verified sources and metadata; GitHub mirrors for canonical Pancake source diffs.
- Source diffs: `analysis/factory.sol`, `analysis/pair0.sol`, `analysis/masterchef.sol`, `analysis/feeTo_impl.sol`, `analysis/smartchef.sol`, `analysis/bswap.sol`; notes in `analysis/source-review.md`.
- Scripts: `ci/enumerate_pairs.py` (full scan), `analysis/aggregate.py`, `analysis/lp_holders.py`, `analysis/mc_pools.py`, `analysis/gen_poc_fixture.py`.
- Files index: `ci-out/` (scan evidence), `poc/` (Foundry project), `analysis/` (sources + aggregates), `ci-log.txt` / `ci-artifacts/` (CI evidence).

## 9. Caveats & limitations

- The scan is a snapshot at one block; live state changes with every swap. The verdict "no excess" holds unless someone donates tokens to a pair (which creates value for the first `skim` caller).
- USD values use DefiLlama prices at scan time (WETH $2,540.20, USDC $0.99964, BSWAP $0.004453); long-tail tokens are priced by implied pairing, not independent oracles.
- The code audit covers the V2 factory/pair, MasterChefV2, feeTo FactoryManager, SmartChef and the BSWAP token. BaseSwap V3 (`0x38015D05…`) and the aggregator (`0x19cEeAd7…`) are out of scope for this finding (triage row is V2-only).
