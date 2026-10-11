# 10KSwap (Starknet) — L2 Phase-2 deep dive: how much can an external unprivileged attacker extract?

**Date:** 2026-10-11 · **Chain:** Starknet mainnet · **Status:** read-only; no transactions; no secrets;
all "PoC" evidence is `starknet_call` / `starknet_simulateTransactions` (state discarded) plus a CI
class-hash reproduction of the deployed code.

**Mission:** triage (L-2 Phase-1, Triage-C) flagged 10KSwap as **LIVE-FUNDED $762,255** — 15 pairs holding
~138 ETH + 285K USDC. This deep dive determines rigorously how much of that value an **external,
unprivileged attacker** (no owner/admin keys, only public contracts + own capital) can extract **today**.

**Finding ID:** `10kswap` (L2 watchlist Phase-2). Folder: `/home/heisenberg/CA/10kswap/`.

---

## 1. TL;DR

| Target | Live extractable (unprivileged) | Why closed / open | Latent risk |
|---|---|---|---|
| 10KSwap factory `0x1c0a36e2…a87a2` (15 pairs) | **$0** | Faithful Uniswap-V2 Cairo port; **deployed class hash == audited source** (CI-verified); `initialize` caller-gated (`10kSwap: FB`); actual balances == reserves on all 15 pairs (no skimmable excess); no LP stranded in any pair; swap k-check enforced | None found for external actors. Admin `feeToSetter` (Argent acct) can retarget protocol fees (P). |
| Pair LP holders (~$760.4K of reserves) | **$0** to attacker | LP is a standard OZ ERC20 held by its owners; only holders can burn their pro-rata share | — (H-O: holders can self-withdraw) |
| `feeTo` protocol-fee claim (~$7.0K LP) | **$0** to attacker | Claim belongs to the `feeTo` Argent account | P (admin-controlled) |
| Router `0x07a6f98c…` | **$0** | Holds 0.016080 ETH ($40.82) that **no function can move** (no sweep/refund) | S (stuck dust) |

### Total live extractable now: **$0** (confidence: **high**)

Live value **at risk / custody** (not attacker-extractable), at block **16,232,746** (2026-10-11 ~17:58 UTC):

| Bucket | USD | Category | Note |
|---|---|---|---|
| 15 pairs — reserves | **$767,425.94** | — | 137.25 ETH, 287.0K USDC, 29.9K DAI, 75.5K USDT, 0.2207 WBTC, 70.1K STRK (totals) |
| ├─ LP token holders | $760,443.14 | **H-O** | 99.09% of LP supply; withdrawable by holders via `burn` (router `removeLiquidity`) |
| ├─ `feeTo` protocol-fee LP | $6,982.64 | **P** | accrued `_mintFee` LP on 14/15 pairs, claimable only by `feeTo` account |
| └─ locked MINIMUM_LIQUIDITY | $0.159 | **S** | 1000 LP wei minted to address 0 on each pair (permanently locked) |
| `feeTo` admin account — own token balances | **$218,425.86** | **P** | 38.71 ETH + 82.7K USDC + 10.7K DAI + 22.6K USDT + 0.0462 WBTC + 2,419 STRK held directly by the protocol's fee/admin Argent account (outside AMM custody) |
| Router stuck ETH | $40.82 | **S** | 0.0161 ETH, no extraction function |
| DefiSpring distributor leftovers | ~$3.30 | H-O/S | merkle claim contract, 0.001 ETH + 7.21 STRK unclaimed |

> Triage row ($762,255) vs live now ($767,426): +0.7% — **state unchanged** (still live-funded; the
> difference is price drift + trading). Reserves are actively traded (arb bot activity within minutes
> of the snapshot).

---

## 2. The target in exact terms

10KSwap was Starknet's first open-source AMM (Uniswap-V2 design in Cairo 0), deployed **Sept 2022**.
The team is gone (10kswap.com is now a domain-squatter page: *"Not affiliated with prior owners"*),
the API/CDN are dead, but the contracts are immutable and permissionless, and the pools still hold
reserves and are actively arbitraged.

**Deployed contracts (all mainnet):**

| Contract | Address | Class hash | Class verified vs source? |
|---|---|---|---|
| Factory (`l0k_factory`) | `0x1c0a36e26a8f822e0d81f20a5a562b16a8f8a3dfd99801367dd2aea8f1a87a2` | `0x55373ed0e387ba6117b7bf65fa4a67af582f8de4e2a20cc75669d26ddb2df3` | **yes (CI)** |
| Pair (`l0k_pair`) ×15 | see §3 | `0x231adde42526bad434ca2eb983efdd64472638702f87f97e6e3c084f264e06f` | **yes (CI)** |
| Router (`l0k_router`) | `0x07a6f98c03379b9513ca84cca1373ff452a7462a3b61598f0af5bb27ad7f76d1` | `0x514718bb56ed2a8607554c7d393c2ffd73cbab971c120b00a2ce27cc58dd1c1` | **yes (CI)** |
| `feeTo` / `feeToSetter` | `0x98707809b39a3b14d9f5004bc1fe77721baa2d8b67fd54ed5794f60671de0` | `0x1a736d6ed154502257f02b1ccdf4d9d1089f80811cd6acad48e6b6a9d1f2003` | Argent account (Cairo 1) |
| DefiSpring distributor | `0x00dc347ea9e7dc2a307e853b97e7189dfb08679a98e8d5ba549a1872febf2e5d` | `0x6a54af2934978ac59b27b91291d3da634f161fd5f22a2993da425893c44c64` | merkle claim (frontend-referenced) |

**Source & audit:** `github.com/10k-swap/10k_swap-contracts` @ `c47f2e158687a757d0834893d5b01ba4131a55ec`
(ScaleBit audit, Sep 2023 — 3 Major issues, **0 Critical**, all "Acknowledged"). The repo's README
documents exactly the mainnet factory/router/pair-class-hash above; git history shows the pair source
changed only by comment deletion after the class hash was documented (2022-09-07).

### 2.1 Deployed == source (class-hash reproduction, CI)

We reproduced the deployed classes from source in CI (python:3.9, `cairo-lang==0.9.1`,
`openzeppelin-cairo-contracts==0.3.2`, sympy 1.11) and compared to the classes fetched read-only from
mainnet (`ci/inputs/*.json.gz`, block 16,231,151):

| Class | deployed hash (computed from RPC class) | compiled hash | match | program equality (normalized) | ABI |
|---|---|---|---|---|---|
| pair | `0x231adde4…e06f` | `0x231adde4…e06f` | ✅ | ✅ | ✅ |
| factory | `0x55373ed0…df3` | `0x55373ed0…df3` | ✅ | ✅ | ✅ |
| router | `0x514718bb…c1` | `0x514718bb…c1` | ✅ | ✅ | ✅ |

→ **The on-chain bytecode is exactly the audited source.** (Raw program JSON differs only by
whitespace inside identifier `cairo_type` strings — an RPC re-serialization artifact; the class-hash
algorithm normalizes it, hence identical hashes.) CI run:
**https://github.com/kingmariano/ca-zombie-ci/actions/runs/38155695315** ·
result JSON: `ci-out/classhash-verification.json`.

---

## 3. Live-state assessment (block 16,232,746; all reads `starknet_call`, state discarded)

Factory `allPairsLength()` = **15**; `allPairs(i)` enumerates exactly the 15 pairs below (complete graph
of the 6 tokens the frontend supported). Every pair has the same class hash; every pair's `factory()`
is the 10KSwap factory. Actual token `balanceOf(pair)` == stored reserves **exactly** on all 15 pairs
(no donations / fee-on-transfer residue → `skim()` yields 0). LP `balanceOf(pair)` == **0** on all 15
pairs (nothing for a third party to burn); LP `balanceOf(0x0)` == 1000 wei on each (locked).

| # | Pair | Reserves (token0 / token1) | USD | feeTo LP share |
|---|---|---|---|---|
| 1 | `0x23c72abd…` ETH/USDC | 100.188098 / 253,943.744363 | $508,174.79 | 1.069% |
| 2 | `0x17e9e62c…` DAI/ETH | 20,018.423399 / 8.647376 | $41,970.30 | 0.372% |
| 3 | `0x5900cfa2…` ETH/USDT | 19.585726 / 49,656.488852 | $99,327.39 | 0.951% |
| 4 | `0x22e45d94…` WBTC/USDC | 0.008504 / 708.681036 | $1,420.33 | 0.421% |
| 5 | `0xf9d8f827…` DAI/WBTC | 565.914682 / 0.007391 | $1,184.66 | 0.044% |
| 6 | `0x2e767b99…` DAI/USDC | 7,069.623362 / 7,723.178146 | $14,790.43 | 0.257% |
| 7 | `0x50031010…` WBTC/USDT | 0.009827 / 816.606030 | $1,638.46 | 0.198% |
| 8 | `0x41a708cf…` USDC/USDT | 22,481.145507 / 22,548.729204 | $45,000.88 | 0.011% |
| 9 | `0x41d52e15…` DAI/USDT | 2,256.399566 / 2,453.269428 | $4,707.50 | 0.253% |
| 10 | `0x2a6e0ecd…` WBTC/ETH | 0.194978 / 6.441353 | $32,672.94 | 0.308% |
| 11 | `0x66733193…` STRK/USDC | 18,286.859955 / 2,158.773917 | $4,317.41 | 2.115% |
| 12 | `0x4ad445ff…` STRK/ETH | 51,381.480658 / 2.388070 | $12,129.34 | 1.590% |
| 13 | `0x784a8ec6…` STRK/USDT | 331.669102 / 40.290478 | $79.42 | 2.547% |
| 14 | `0x1a4c250c…` DAI/STRK | 4.893785 / 43.723091 | $10.06 | 3.087% |
| 15 | `0x5b14037f…` WBTC/STRK | 0.000012 / 8.603085 | $2.04 | 0.000% |
| | **Total** | | **$767,425.94** | |

Prices (DefiLlama, snapshot time): ETH $2,538.44 · USDC $0.99964 · DAI $1.00005 · USDT $0.99907 ·
WBTC $83,711.81 · STRK $0.11808. Full per-pair data incl. balances, LP supplies and feeTo holdings:
`analysis/final_snapshot.json`.

**Roles / authority:**
- Pair: no admin functions at all (ABI: ERC20 + `initialize` + `mint`/`burn`/`swap`/`skim`/`sync` + views).
  `initialize` asserts `caller == factory` (error `10kSwap: FB`) — see §5.
- Factory: `createPair` permissionless (deploys via `deploy` syscall with salt `hash2(token0,token1)`;
  duplicate guarded by `10kSwap: PE`); `setFeeTo`/`setFeeToSetter` gated by `feeToSetter`
  (= the Argent account above).
- Router: stateless, no admin, no sweep.
- Pools are **actively traded and LP positions actively managed**: in the last 110k blocks
  (~2.6 days) the 15 pairs emitted **2,029 `Swap` + 2,061 `Sync` + 85 LP `Transfer` events**
  among **41 distinct non-zero addresses** (users via the router + the `feeTo` accrual); swaps
  observed minutes before the snapshot (e.g., tx `0x3687285c…` at block 16,230,885, sender
  `0x1b45c859…`). The H-O withdrawal path is exercised, not theoretical
  (`analysis/lp_recent_actors.json`).. Reserve timestamps (`blockTimestampLast`) update within hours.

---

## 4. What an attacker can and cannot do (exact call paths)

| Path | Preconditions | Result | Evidence |
|---|---|---|---|
| `pair.initialize(token0, token1)` (re-init to hostile tokens) | any caller | **Reverts `10kSwap: FB`** — asserts caller == factory; factory has no re-init path (`createPair` blocked by `10kSwap: PE` for existing pairs; pair address is deployer=factory-deterministic) | §5 T1/T2 + `analysis/recon3.json` |
| `pair.swap(amountOut>0, to)` without paying | any caller | **Reverts `10kSwap: IIA`** (amountIn == 0) — and would also fail the k-check (`10kSwap: K`); attacker pays 0.3% fee like everyone | §5 T3 |
| `pair.skim(to)` | balances > reserves required | **Transfers 0** — balances == reserves on all 15 pairs (measured at block 16,232,746; `sum_excess_raw = 0`) | §5 T4 + `final_snapshot.json` |
| `pair.burn(to)` to capture stranded LP | pair must hold LP | pair LP balance == **0** on all 15 pairs; only the burner's own transferred-in LP is burned for its pro-rata share (standard V2; the router does this for users) | `analysis/recon2.json` |
| Free LP via `mint(to)` | — | standard V2 math `liquidity = min(amount0·S/r0, amount1·S/r1)`; you must add tokens; `10kSwap: ILM` if 0 | source + class verification |
| `factory.createPair(a,b)` | — | deploys a new empty pair; no effect on existing reserves (fresh pair, new LP) | source + class verification |
| `factory.setFeeTo(x)` | feeToSetter only | P — admin can redirect future protocol fees; cannot touch reserves or LP | on-chain `feeToSetter()` |
| `router.removeLiquidity(...)` | holder's LP + approval | **H-O** — LP holders can withdraw their pro-rata reserves any time (no pause, no timelock) | source |
| Steal from router's 0.0161 ETH | — | no function moves router-held tokens/ETH (`S`) | router ABI + class verification |

**Costs:** an attempted drain has no viable path, so no capital/flash-loan analysis applies. Swaps cost
~0.002 STRK gas + 0.3% fee; LP withdrawal costs gas only.

**Known benign deviations from Uniswap V2** (checked, not exploitable here):
- `_swap_Transfer`/`skim`/`burn` ignore the ERC20 `transfer` return value ("TODO: safeTransfer").
  All 6 paired tokens revert on failure, so a silent-failure path does not exist; a silently-failing
  token would only *deny the attacker* their own output.
- `_update` OV-check enforces balances < 2^112 before `int112` cast (`10kSwap: OV`), matching uint112.
- Fee-on-transfer support router method exists; none of the 6 tokens is FoT.
- TWAP accumulators use u32 timestamps (`warp_*` int conversions) — cosmetic only.

---

## 5. Verification / PoC (read-only; nothing signed or broadcast)

**(a) `starknet_simulateTransactions` (real transaction context, `SKIP_VALIDATE`+`SKIP_FEE_CHARGE`,
state discarded)** — `analysis/sim_poc.py` → `analysis/sim_summary.json` (block 16,232,335):

| # | Simulated call (from a real deployed account `0x1b45c859…`) | Result |
|---|---|---|
| T1 | `pair.initialize(USDT, WBTC)` on ETH/USDC pair | **REVERT** — `Error message: 10kSwap: FB` at pc 0:2893; assert: `0x1c0a36e2…a87a2 (factory) != 0x1b45c859… (caller)` |
| T2 | `pair.initialize(original tokens)` | **REVERT** — same gate (caller ≠ factory) |
| T3 | `pair.swap(0 out0, 1000 USDC out1, attacker)` without paying | **REVERT** — `10kSwap: IIA` at pc 0:3590 (`0 != 1`) |
| T4 | `pair.skim(attacker)` | **SUCCEEDS** — trace shows `balanceOf(ETH,pair)`, `balanceOf(USDC,pair)` then `transfer(ETH)` and `transfer(USDC)` of **value 0** (both `Transfer` events carry `0x0`). Nothing extractable. |

**(b) `starknet_call` `initialize` re-callability probe** (`analysis/recon3.json`): 4 pairs × 2 argument
sets all revert with `An ASSERT_EQ instruction failed: 792675439340753442503309894392665475159403042210985696167998939160953653154 != 0`
— the first operand is the factory address, the second is the call-context caller (0), proving the gate
is caller-based, not argument-based.

**(c) CI class-hash reproduction** (§2.1): pair/factory/router `VERIFIED=true` — the deployed code is
the audited source. Run: **https://github.com/kingmariano/ca-zombie-ci/actions/runs/38155695315**
(earlier runs: `…/runs/38153319482`, `…/runs/38154300833`, `…/runs/38155037826`).

**(d) State invariant scan** (`analysis/final_snapshot.py`, `analysis/lp_holders.py`): balances == reserves
(sum of excess = 0 raw wei); LP(pair) = 0; LP(0x0) = 1000 wei; feeTo LP share measured per pair.

---

## 6. Verdict, residual and latent risk

- **External unprivileged extractable today: $0 (high confidence).** The AMM is a correct V2 port,
  the deployed bytecode is the audited source, the classic re-init/skim/stranded-LP vectors are all
  closed, and the only privileged surface (`feeToSetter`) cannot touch reserves.
- **Where the money actually is:** LP holders' pro-rata claim ($760.4K, H-O — live withdrawal path),
  the protocol's fee/admin Argent account ($6.98K accrued fee-LP + $218.4K in its own token balances, P),
  and $41 of permanently stuck dust (S: 1000 LP wei per pair + router ETH).
- **Latent risks (not extractable now):**
  - `feeToSetter` is a single Argent account with no timelock (audit L0K-1). If its key is lost/compromised,
    the fee recipient can be changed (attacker with the key could redirect *future* fees, but can never
    touch reserves or LP). Worth noting because the team is inactive.
  - The audit's .EN-1 (private keys in `.env.example`) is **not exploitable on mainnet**: the three
    leaked accounts (`0x058c64c1…`, `0x6f8a9a7d…`, `0x07b0c3fc…`) are **not deployed** on Starknet
    mainnet (verified `starknet_getClassHashAt` → "Contract not found"); they are devnet/testnet keys.
  - The audit's L0K1-1 (unrestricted `mint()` in `l0k_erc20.cairo`) concerns a standalone ERC20
    template; no mainnet instance is documented in the repo, and no such token is in any pair.
  - If a future holder sends LP tokens to a pair by mistake, anyone can `burn` them (standard V2
    property). None stranded today.
- **Blockers/caveats for the attacker:** none needed — no viable path exists. For us: no public holder
  index exists for LP tokens (no explorer API key), so the H-O bucket is measured in aggregate.
  A full-history LP `Transfer` replay was attempted (key-filtered, streaming): the launch-era event
  density is enormous (≈2,000 LP transfers per ~1,300 blocks in early 2022 blocks 5k–8k; 250k events
  after 50 pages for the ETH/USDC pair alone), so per-holder enumeration was dropped in favour of the
  aggregate + recent-actor sample. This does not affect the E-U verdict; it only splits H-O vs S
  within the holder bucket (no dead-holder LP identified).

---

## 7. Methodology & sources

1. **Triage re-verification** — re-read factory/pairs/reserves at block 16,229,987 (`analysis/recon1.json`),
   compared to triage (`l2-triage-c/summary.json` row: $762,254.88): consistent.
2. **Full contract surface** — `starknet_getClassHashAt`/`getClass` for factory, pairs, router, feeTo,
   distributor; ABI + entry-point extraction; verified all 26 pair externals are the documented V2 set.
3. **Source audit** — cloned `10k-swap/10k_swap-contracts` @ audited commit; reviewed `l0k_pair.cairo`,
   `l0k_factory.cairo`, `l0k_router.cairo`, `l0k_library.cairo`, `uq112x112.cairo`, warplib; read the
   ScaleBit audit PDF (Sep 2023); mapped deployed program `attributes` (error-message PCs) to source.
4. **Class-hash reproduction in CI** — `ci/run.sh` + `ci/verify.py` compile the source in a python:3.9
   container and compare hashes/programs against the vendored deployed classes (`ci/inputs/`).
5. **Live-value measurement** — per-pair `balanceOf` (tokens and LP), `totalSupply`, `feeTo`/`0x0` LP
   balances, feeTo/router/distributor token balances; USD via DefiLlama coins-api.
6. **Attack-path proof** — `starknet_call` probes + `starknet_simulateTransactions` (read-only).
7. **Web** — 10kswap.com (now squatter page), GitHub org `10k-swap` repos (contracts, frontend, SDK,
   seabed), DefiLlama adapter history.

**Caveats/limitations:** (i) reserves/balances are a snapshot — they move with trading; (ii) prices are
snapshot DefiLlama prices; (iii) LP-holder distribution is aggregated (no explorer holder API) — the
non-feeTo LP supply is treated as H-O (any dead holder share would be S instead; no evidence found of
dead-contract LP); (iv) the "10KSwap family" total includes the feeTo account's own balances, which are
outside the AMM contracts (clearly separated in §1); (v) simulation flags `SKIP_VALIDATE` mean the
traces prove *contract logic*, not signature validity of any specific user.

## 8. Files index

```
10kswap/
├── README.md                      # this file
├── summary.json                   # machine-readable summary
├── analysis/
│   ├── sn.py                      # read-only Starknet RPC helper (public endpoints only)
│   ├── recon1.py / recon1.json    # factory + 15 pairs, reserves, supplies, class hashes
│   ├── recon2.py / recon2.json    # balances vs reserves (skim check), LP of pair/factory, ABIs
│   ├── recon3.json                # starknet_call initialize re-init probes (all revert)
│   ├── recon4.json                # feeTo/address-0 LP balances per pair
│   ├── lp_holders.py / .log       # full-history replay attempt (unfiltered; local, stopped at ~1.5M events)
│   ├── lp_holders2.py / .log      # key-filtered Transfer-only streaming replay (holder reconstruction)
│   ├── sim_poc.py / sim_tests.json / sim_summary.json   # simulateTransactions PoC T1–T4
│   ├── final_snapshot.py / final_snapshot.json          # consolidated state + USD at one block
│   ├── feeto_class_abi.json / pair_class_meta.json      # feeTo account ABI; pair class meta
│   └── fetch_deployed_classes.py  # vendored deployed class JSONs -> ci/inputs/
├── ci/
│   ├── run.sh                     # CI job: compile source, reproduce class hashes
│   ├── verify.py                  # hash + program comparison
│   └── inputs/                    # deployed class JSONs (gzip) + meta
├── ci-out/
│   ├── classhash-verification.json  # pair/factory/router VERIFIED=true
│   └── compile.log
├── ci-log.txt                     # full GitHub Actions log
└── ci-artifacts/                  # downloaded CI artifacts
```
