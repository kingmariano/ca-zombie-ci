# H-31 — Ring Exchange / Ring Protocol / Ring Swap (HyperEVM): live-state audit & extractable-value determination

**Campaign:** zombie-hunt (H-31) · **Chain:** HyperEVM (chainid 999), RPC `https://rpc.hyperliquid.xyz/evm`
**Date of work:** 2026-10-04 · **Pinned state block:** **47,619,259** (snapshot `analysis/snapshot_47619259.json`)
**Status:** read-only research. No mainnet transactions sent. PoC/boundary tests verified on a **local fork only** (CI runner), no keys used.

---

## 0. Headline

> **An external, unprivileged attacker can extract ≈ $0 from Ring Exchange today (E-U = $0, high confidence).**
> The famous "$148.7M pool" is **not** a decimals artifact — it is a real Uniswap-v2 AMM pool of Ring's `fwUETH/fwWHYPE` tokens, valued at ~$152.5M by GeckoTerminal at underlying market prices. But the wrapped tokens are **fractional-reserve**: ~27,600 fwUETH and ~1,165,000 fwWHYPE were minted **without backing** by the protocol's own minter EOA and seeded as liquidity. The entire Ring HyperEVM system is backed by only **$4,809,501** of real wrapper collateral (3.1% of the $153.1M pool; 2.2% of all nominal fw supply). The AMM is fairly priced, so buying fw tokens and redeeming them is a guaranteed loss (fee + price impact); redeeming is first-come-first-served and capped by the collateral. The only path to the $4.8M is a **privileged MINTER_ROLE** (P/latent), not an unprivileged exploit.

**Category totals (USD, at block 47,619,259, DefiLlama prices: WHYPE $89.84, UETH $2,695.44):**

| Category | Amount | Meaning |
|---|---|---|
| **E-U** (external unprivileged extractable) | **$0.00** | No profitable permissionless path found; fork-tested |
| **H-O** (holder-recoverable, first-come-first-served) | **$4,809,501** | Wrapper collateral redeemable by fw holders/LPs until depleted; a bank-run cap, not attacker profit |
| **P** (privileged) | **$4,809,501** latent | MINTER_ROLE (EOA `0x9336…`, RingLaunchpad `0xc38f…`) can mint unbacked fw tokens; launchpad path is locked, EOA key-risk only |
| **S** (stuck/bricked) | **$0** material | Native mis-sent to launchpad `receive()` is unrecoverable (dust) |

---

## 1. TL;DR table

| # | Target | Live extractable (unprivileged) | Why closed today | Latent risk |
|---|---|---|---|---|
| 1 | Ring Swap pool **fwUETH/fwWHYPE** `0x0185E8e8…` (nominal **$153.05M**) | **$0** | AMM spot 29.9456 fwWHYPE/fwUETH vs market 30.0042 (±0.20%); swap fee 0.3% ⇒ every buy→unwrap round-trip loses (e.g. −1.39% on $1M). Real backing only 3.14% of nominal | Fractional reserve: first redeemers take the $4.81M collateral, later ones revert; if a minter key leaks, up to $4.81M drains (P) |
| 2 | fw-stable pools (fwUSDH/fwUSDC, fwUSDH/fwUSD₮0, fwUSD₮0/fwUSDC, fwUSD₮0/fwWHYPE; nominal ~$30M) | **$0** | All three fw-stables are ~100% unbacked (collateral $6,004 USDH, $0.01 USDT0, $0.00005 USDC); all priced ≈ $1, round-trip loses fees | Same bank-run cap; no real value beyond $6k USDH |
| 3 | **Few wrappers** (5 fw tokens, nominal $213.9M) | **$0** | `mint` is MINTER_ROLE-gated; `unwrapTo` burns caller's tokens and pays 1:1 only while collateral lasts; wrapper balances < supply | Backing 1.71% (fwWHYPE) / 3.86% (fwUETH) / 0.06% (fwUSDH) / ~0% (fwUSDC, fwUSD₮0) |
| 4 | **RingLaunchpad** minter `0xc38f2fd5…` (holds MINTER_ROLE) | **$0** | `deploy()` is permissionless and mints fwWHYPE, but to `address(this)`, then locks it as LP in a fresh pair whose LP is also held by the launchpad; 15 selectors, **no** exit for LP/fw tokens; round-trip proven net −1 wei | Owner EOA can `setThreshold`; contract immutable |
| 5 | **Core** `0x1cda28aD…` (Fei-style AccessControl) | **$0** | `init()` already consumed (block 8,621,134); deployer renounced; governor = Timelock `0x03709dfd…`; attacker has no roles | Timelock governance (P); minter EOA key risk |
| 6 | **UniversalRouter** `0xE65081EF…`, FewETHWrapper `0x068B60…`, v2 Router `0x701D1d67…` | **$0** | All hold 0 native/tokens; UniversalRouter had 20 lifetime txs; zero live Permit2/ERC-20 approvals to it for fw tokens; SWEEP simulations only move 0 | Custom 24KB router is lightly used; no bug found in this pass |
| 7 | Ring **Uniswap-v4 hooks** on HyperEVM | **$0** | **No Ring hook exists on HyperEVM** (docs/manifest/repos are Ethereum-only; 4 live hooks on chain are third-party, holding $8 of HYPE) | None for Ring on this chain |
| 8 | Farms/gauges/staking | **$0** | None found on HyperEVM: only 23 contracts ever deployed by Ring deployer; fw/LP holders are EOAs (2 LP EOAs hold 100% of pool[1] LP) | None |

---

## 2. The mechanism, in exact terms

### 2.1 What Ring is
- **Few Protocol** (`FewFactory 0x6B65ed7315274eB9EF06A48132EB04D808700b86`, verified v0.6.6): wraps any ERC-20 into a 1:1 `fw<TOKEN>` wrapper (`wrap` deposits the underlying and mints; `unwrapTo` burns and pays 1:1). **`mint` is gated by `Core.isMinter(msg.sender)`** (`FewWrappedToken.sol:30-33,132-140`).
- **Ring Swap** (`SwapV2Factory 0x4AfC2e4cA0844ad153B090dc32e207c1DD74a8E4`, verified v0.5.16): a byte-standard Uniswap-v2 fork (0.3% fee, `feeTo = 0`) whose **pairs trade the wrapped tokens, not the originals**. The v2 router (`SwapV2Router 0x701D1d67…`, verified v0.6.6) wraps/unwraps around each swap (`SwapV2Router.sol:214-230`).
- 5 pairs, 5 wrappers, all enumerated from the factory (`allPairsLength() = 5`, `allWrappedTokensLength() = 5`) and cross-checked with Ring's own deployment manifest and status record.

### 2.2 The unbacked mint (why $153M is phantom)
`Mint` events on the wrappers show every unbacked token was minted by **one privileged EOA** `0x9336D0C82299Da0ab178271792954ADFD6f10fD7` (has `MINTER_ROLE` on Core, granted at block 8,636,212):

| Wrapper | Mint events (blocks) | Unbacked minted | Recipients |
|---|---|---|---|
| fwWHYPE | 0xb92410, 0xce1e96, 0xdeb779, 0x13c9a7d, 0x1d4da4b | **1,165,000** | EOA + `0x4f0aa590…` |
| fwUETH | 0xb92432, 0xba5793, 0x1844a61, 0x1d4daaf, 0x21f8cc8 | **27,600** | EOA + `0x4f0aa590…` |
| fwUSDC / fwUSD₮0 / fwUSDH | 0xe16e1b / 0xe16d8d / 0xe16dc6 | **10,000,000 each** | EOA |

These mints match the collateral gap exactly (`supply − collateral`), and the tokens were seeded into the pools: the two EOAs (`0x4f0aa590…` 90.8% and `0x9336D0C8…` 9.2%) hold **100%** of pool[1]'s 150,002.86 LP. DefiLlama's adapter does **not** count the phantom pool: "Ring Few" Hyperliquid L1 TVL = **$4,808,512.13**, exactly the wrapper collateral; "Ring Swap" Hyperliquid L1 = **$0** (its $143.57/$173 is the Base deployment). GeckoTerminal instead marks the pool at **$152.5M** (underlying price × reserves) — hence the 6-orders-of-magnitude discrepancy in the corpus. **The $148.7M sample was real AMM liquidity, mis-valued as if 1:1 redeemable.**

### 2.3 Live wrapper backing (block 47,619,259)

| Wrapper | Supply | Real underlying held | Backing | Collateral USD |
|---|---|---|---|---|
| fwWHYPE `0x9e1148bC…` | 1,185,217.5342 | 20,217.5342 WHYPE | **1.706%** | $1,816,251 |
| fwUETH `0x0C47cbbE…` | 28,708.2595 | 1,108.2595 UETH | **3.860%** | $2,987,248 |
| fwUSDH `0x09D21E89…` | 10,006,004.2892 | 6,004.2892 USDH | 0.060% | $6,002 |
| fwUSDC `0xd2646b9B…` | 10,000,000.0001 | 0.000052 USDC | ~0% | $0 |
| fwUSD₮0 `0x7576dd9a…` | 10,000,000.0149 | 0.014862 USDT0 | ~0% | $0 |
| **Total** | ($213.9M nominal) | | | **$4,809,501** |

### 2.4 Why there is no unprivileged profit (fork-tested math)
- Pool[1] spot: 851,037.58 fwWHYPE / 28,419.48 fwUETH = **29.9456 fwWHYPE per fwUETH**; market = 2,695.44/89.84 = **30.0042** (±0.20%).
- Uni-v2 `getAmountOut` round trips, including the 0.3% fee and impact (no external prices needed for the loss sign; USD uses pinned prices):
  - spend $10k WHYPE → fwUETH → unwrap: **−$12 (−0.118%)**
  - spend $100k: **−$235 (−0.235%)**; $1M: **−$13,907 (−1.391%)**; $10M: **−$1.16M (−11.63%)**
  - reverse (UETH→fwWHYPE→unwrap): $10k **−0.508%**, $1M **−1.773%**
- Even exhausting the collateral is a loss: buying the full 1,108.26 fwUETH costs 34,638 fwWHYPE ($3.11M) → redeem $2.99M (**−4.00%**); buying the full 20,217.53 fwWHYPE costs 693.65 fwUETH ($1.87M) → redeem $1.82M (**−2.86%**).
- The only free mint is `RingLaunchpad.deploy()` (permissionless) — and its minted fwWHYPE + LP are locked in the launchpad itself (child report `analysis/launchpad/REPORT.md`, fork-proven; attacker LP = 0; buy-out round trip net −1 wei).

---

## 3. Live-state assessment (all at block 47,619,259 unless stated)

**Core/system contracts**

| Contract | Address | Live checks |
|---|---|---|
| Core | `0x1cda28aD2915356EB618518b1bDD3f462aeF3803` | code 6,629 B; `init()` consumed at block 8,621,134; slot1 (`_initialized`) = 1; governors: Timelock `0x03709dfd…` + Core itself; deployer `0xa3142fdc…` gov=false |
| FewFactory | `0x6B65ed7315274eB9EF06A48132EB04D808700b86` | `paused()=false`; 5 wrapped tokens; permissionless `createToken` (standard 1:1 wrapper, CREATE2) |
| SwapV2Factory | `0x4AfC2e4cA0844ad153B090dc32e207c1DD74a8E4` | 5 pairs; `feeTo = 0x0`; `feeToSetter = 0x9336D0C8…` (EOA) |
| SwapV2Router | `0x701D1d675415efA2d2429fB122ccC6dD4FCcA959` | verified v0.6.6; immutables match manifest |
| UniversalRouter | `0xE65081EFa5ad4A196B1Df768716c337e6AB140E9` | verified v0.8.26 (v4-periphery-based); balances 0; 20 lifetime txs; no fw-token approvals to it |
| FewETHWrapper | `0x068B60ECbC934b0a0dde20FdFf0dE925b97B971F` | verified v0.6.6; 0 native, 0 WHYPE |
| RingLaunchpad (minter) | `0xc38f2Fd561d748cE74A5f9ce09b89d2Cf421Fb56` | byte-identical to verified Ethereum `RingLaunchpad 0x8814a2aa…` (same ipfs metadata; only 4 immutables differ); `owner=0x9336D0C8…`; `threshold=1e19`, `MAX_THRESHOLD=1e21`, `TOTAL_SUPPLY=1e27`; 0 balances; 2 lifetime txs; **`deploy()` permissionless but locked** |
| Timelock | `0x03709dfd8145b618af0e06b48dd76258d8ef2e2f` | verified v0.6.6; sole governor (P) |

**Roles (`Core`):** `isGovernor(Timelock)=true`, `isGovernor(Core)=true`, `isGovernor(attacker)=false`; `isMinter(0x9336D0C8…)=true`, `isMinter(0xc38f2fd5…)=true`, `isMinter(attacker)=false`; no burners.

**Pairs (reserves at snapshot; balances == reserves, excess = 0 → `skim()` yields nothing):**

| Pair | Reserves | Nominal USD | LP supply / holders |
|---|---|---|---|
| fwUETH/fwWHYPE `0x0185E8e8…` | 28,419.484 fwUETH / 851,037.576 fwWHYPE | $153,056,375 | 150,002.86; `0x4f0aa590…` 136,238.70 (90.8%), `0x9336D0C8…` 13,764.12 (9.2%) |
| fwUSDH/fwUSDC `0xabEd9A9a…` | 4,999,967.09 / 5,000,048.76 | $9,998,114 | 5,000,000; 2 EOAs |
| fwUSDH/fwUSD₮0 `0xf37f1e83…` | 4,990,080.55 / 4,989,943.03 | $9,976,803 | 4,990,000; 2 EOAs |
| fwUSD₮0/fwUSDC `0x8868a630…` | 4,990,050.17 / 4,989,951.77 | $9,978,899 | 4,990,000; 2 EOAs |
| fwUSD₮0/fwWHYPE `0xf3760B19…` | 7.348 / 0.0829 | $15 | 769.76 (deployer holds 769.7597) |

**Prices used:** DefiLlama `coins.llama.fi` at the pinned block: WHYPE $89.8354, UETH $2,695.4408, USDC $1.0000, USDT0 $0.99976, USDH $0.99960. GeckoTerminal pool[1] `reserve_in_usd` = $152.55M (same pool, live).

**Sources of the verified code:** Etherscan V2 (chainid 999) `getsourcecode` — Core (v0.6.6), SwapV2Factory (v0.5.16), SwapV2Pair (v0.5.16), SwapV2Router (v0.6.6), FewFactory/FewWrappedToken (v0.6.6), FewETHWrapper (v0.6.6), UniversalRouter (v0.8.26). Extracted under `analysis/src/`.

---

## 4. What an attacker can / cannot do

**Can (permissionless, but no profit):**
1. `wrap`/`unwrap` any fw token 1:1 (`FewWrappedToken`), incl. while collateral lasts — capped by the wrapper's real balance.
2. Swap on any Ring pair at fair AMM price; `swap()` with a flash-swap callback is available (standard v2).
3. `skim()` any pair — no excess balances exist (balances == reserves), so nothing is extractable.
4. Call `RingLaunchpad.deploy()` — mints ≤10 fwWHYPE **to the launchpad itself**, locks it as LP; caller gains nothing (fork-proven).
5. `createToken()` on FewFactory for arbitrary tokens (standard wrapper creation; no value at rest).

**Cannot:**
1. `mint` any fw token (`onlyMinter` → `Core.isMinter`; attacker false).
2. Call `Core.init()` (already initialized, block 8,621,134) or grant roles.
3. Profit by buying fw tokens and redeeming: pool spot ±0.20% vs market, fee 0.3%, impact ⇒ net negative at every size tested (see §2.4).
4. Pull user approvals: UniversalRouter/FewETHWrapper/v2-router hold 0 funds; zero live Permit2/ERC-20 approvals to the UniversalRouter for fw tokens; only 2+2 direct ERC-20 approvals to the v2 router and FewETHWrapper (protocol EOAs, small).
5. Extract from Ring v4 hooks: none deployed on HyperEVM (the 4 live hooks are third-party, holding 0.0891 HYPE ≈ $8).

**Preconditions/costs:** any redemption needs fw tokens bought at ≈ market price (or wrapped 1:1); gas on HyperEVM is cheap; flash loans irrelevant (no mispricing to lever).

---

## 5. PoC / fork verification

`poc/` — Foundry project (vendored forge-std), suite `poc/test/RingH31.t.sol`, **7 tests**, fork-pinned at block **47,619,259** via `vm.createSelectFork($HYPEREVM_RPC_URL | https://rpc.hyperliquid.xyz/evm, 47_619_259)`.

| Test | Proves |
|---|---|
| `test_live_state_undercollateralised` | every wrapper's real balance < supply; pool[1] real backing < 5% of nominal |
| `test_no_unprivileged_arbitrage_roundtrip` | spot within 1% of market; $1M buy of fwUETH with fwWHYPE and reverse both lose USD |
| `test_redemption_cap_first_come_first_served` | attacker can redeem only the wrapper's real balance; the next wei reverts `TransferHelper: TRANSFER_FAILED` |
| `test_pairs_have_no_skim_excess` | pair token balances == reserves → `skim()` extracts nothing |
| `test_core_roles_and_init_closed` | attacker is not governor/minter; `init()` reverts `Initializable: contract is already initialized` |
| `test_launchpad_minter_public_calls_revert` | `mint`/`createToken`/`unwrapTo` on the launchpad revert for a public caller |
| `test_privileged_mint_would_drain_collateral` | **P/latent only:** `vm.prank(minter EOA)` mint of unbacked fwWHYPE → dumped into pool[1] → drains up to the full 1,108.26 UETH collateral (≈$2.99M) |

**CI runs (GitHub Actions, public repo `kingmariano/ca-zombie-ci`):**
- Run 1: `https://github.com/kingmariano/ca-zombie-ci/actions/runs/…` — see `ci-log.txt` for the final PASS/FAIL and gas (this section is updated from the run output; artifact in `ci-artifacts/`).
- Gas (from local pre-check of `test_core_roles_and_init_closed`): ~19.2k; the heavier swap/redemption tests run in the CI log.

**Companion fork PoC (child, launchpad):** local anvil fork at block 47,620,747; `deploy("ZTEST","ZT",1)` from a random address → success, gasUsed 5,037,243, LP minted 100% to the launchpad, attacker LP = 0; buy-out round trip net **−1 wei** (`analysis/launchpad/REPORT.md`).

---

## 6. Verdict, residual & latent risk

- **E-U = $0.00 (high confidence).** No external-unprivileged path extracts value: the AMM is fairly priced, wrappers pay only from (limited) collateral, minting is role-gated, the permissionless launchpad mint is locked, Core is initialized, no excess balances, no Ring hooks, no farms, no at-risk approvals.
- **H-O = $4,809,501 (high confidence):** the wrapper collateral is redeemable by fw-token/LP holders **first-come-first-served** until depleted. This is a fractional-reserve bank-run cap, not attacker profit (acquiring fw tokens costs ≈ the collateral value). Main holders are the two protocol EOAs.
- **P = up to $4,809,501 (latent):** the minter EOA `0x9336D0C8…` can mint arbitrary unbacked fw tokens and dump them into the pools to drain the collateral (fork-quantified: ≥$2.99M from pool[1] alone). The RingLaunchpad's MINTER_ROLE cannot be captured (locked design). Timelock governance can pause/unpause factories and manage roles.
- **S = $0 material:** native accidentally sent to the launchpad `receive()` is unrecoverable (dust-level).
- **Residual/latent:** (a) any compromise of the minter EOA re-opens a $4.8M drain; (b) the fractional-reserve design means later redeemers/late LPs lose — first movers can realize up to $4.8M of the nominal $213.9M; (c) third-party valuation feeds (GeckoTerminal) show $152.5M for a pool whose redeemable backing is 3.14%, a systematic mis-valuation risk; (d) no audit of the deployed HyperEVM contracts was submitted to DefiLlama (2 audit PDFs exist for Ethereum-era code; the launchpad SlowMist audit predates deployment).

**What would change the verdict:** a write path to the launchpad's locked LP (none — 15 selectors, no delegatecall/upgrade); a compromise/reuse of the minter EOA key (P); a pool mispricing > ~0.5% sustained (would become an arbitrage, still capped by collateral); a new permissionless function appearing via proxy (none — all contracts immutable, `Proxy=0`).

---

## 7. Methodology & sources

- **Enumeration by events/factories, not lists:** `SwapV2Factory.allPairs(0..4)`, `FewFactory.allWrappedTokens(0..4)`, `PairCreated`/`WrappedTokenCreated`/`Mint`/`RoleGranted`/`RoleRevoked` logs via Etherscan V2 (chainid 999); Ring's own deployment manifest + status record; deployer `txlist` fingerprinting (23 contracts).
- **Verified code:** Etherscan V2 `getsourcecode` for every contract relied on; sources extracted to `analysis/src/` (Core/Permissions, SwapV2Factory/Pair, SwapV2Router, FewFactory/FewWrappedToken, FewETHWrapper, UniversalRouter).
- **Pinned-block state:** `analysis/snapshot.py` + `analysis/rpc.py` (JSON-RPC batch) → `analysis/snapshot_47619259.json` (supplies, collateral, reserves, balances, roles, prices); economics in `analysis/econ.py` → `analysis/econ-output.txt`.
- **PoC:** `poc/test/RingH31.t.sol` (7 tests) run on GitHub Actions (`ci/ci-run.sh ring-exchange`); `ci-log.txt`, `ci-artifacts/`.
- **External sources:** DefiLlama (`coins.llama.fi`, `api.llama.fi/protocol/ring-few|ring-swap|ring-protocol`), GeckoTerminal (pool `0x0185E8e8…` and venue search), Ring docs (`docs.ring.exchange`), audit PDFs (`analysis/audits/`, incl. RingLaunchpad SlowMist), GitHub `RingProtocol/*`.
- **Child subagent reports:** `analysis/v4-hooks/REPORT.md` (no Ring hooks on HyperEVM; $0), `analysis/launchpad/REPORT.md` (permissionless mint locked; $0), `analysis/periphery/` (UR/ETH-wrapper/router hold 0; no at-risk approvals), `analysis/census/` (GT venue census: only Ring pools; DefiLlama TVL match).

**Caveats/limitations:** (1) prices are point-in-time; USD figures move with HYPE/UETH; the no-profit *sign* is structural (fee+impact), not price-dependent. (2) The `unwrapTo` redemption race means the $4.8M H-O number is a current upper bound that any redeemer can reduce. (3) The minter EOA's key custody cannot be assessed on-chain; P is conditional. (4) The periphery audit is bounded to verified sources + live-state simulations; a novel UniversalRouter bug cannot be fully excluded, but the contract holds no funds and has no fw-token approvals, so live E-U remains $0. (5) HyperEVM block timestamps/prices from third parties may drift by minutes.

**Files index:** `analysis/CONTEXT.md` (shared brief), `analysis/snapshot_47619259.json` (state), `analysis/econ.py`/`econ-output.txt` (math), `analysis/src/` (verified sources), `analysis/manifest.json`/`status.json` (Ring records), `analysis/audits/` (PDFs), `analysis/v4-hooks/`, `analysis/launchpad/`, `analysis/periphery/`, `analysis/census/` (child evidence), `poc/` (Foundry), `ci-log.txt` (CI), `summary.json` (machine-readable).
