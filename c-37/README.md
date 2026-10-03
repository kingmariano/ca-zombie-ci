# C-37 — DeadDeFi.com recovery adapters + 13 underlying "recoverable value" protocols (Ethereum)

**Campaign:** zombie-hunt · **Chain:** Ethereum mainnet · **Date of work:** 2026-10-03
**Status:** read-only research; PoC fork-verified only; **no mainnet transactions sent**.
**Snapshot block:** 26,111,363 (live-state) / 26,111,266–26,112,297 (protocol measurements).

**Scope:** the C-37 finding as corrected in the corpus — the 13 DeadDeFi "recovery adapter" contracts
(`AaveV1Adapter`, `IndexCoopAdapter`, `SetV1Adapter`, `RariFuseAdapter`, …), the shared
`DeadDeFiRouter`, the anonymous deployer's two earlier (paused) redemption contracts, **and** the 13
underlying native protocols whose value the adapters route (Index Coop, Aave V1, Set Protocol V1,
Rari Fuse, dForce Lending, PieDAO, Pickle, BasketDAO, PowerPool, Yam Degenerative, Indexed Finance,
Domani, Cook Finance).

---

## TL;DR

| # | Surface | Live extractable now (unprivileged) | Why closed / open | Latent risk |
|---|---|---|---|---|
| 1 | **DeadDeFi v2 adapters + router** (13 adapters, `0x121D5A…01aF`) | **$0** | All 14 contracts hold 0 ETH and 0 ERC-20 (verified). The sweep primitive is live but unfunded | **HIGH** — any value that lands in any adapter or in the router is instantly permissionlessly stealable (fork-proven); any incomplete user redemption leaves value behind that a back-runner takes |
| 2 | Index Coop (DPI et al.) | $0 | Holder redemption via `BasicIssuanceModule`; DPI components $7.01M measured | None found |
| 3 | Aave V1 | $0 | aToken holder redeem; core $8.04M backs ~$7.66M aToken claims | aSUSD is 100% unbacked (114.2k); ~$150k of residual borrows not position-enumerated |
| 4 | Set Protocol V1 vault | $0 | Holder redeem via module; vault $1.675M; owner is a contract with a 7-day timelock | Owner-authorized drainer could be added after timelock (privileged) |
| 5 | Rari Fuse (201 pools / 787 markets) | $0 | **0** markets with `totalSupply==0` that are listed, mintable and CF>0 | fToken holder redemptions subject to pool liquidity |
| 6 | dForce Lending (32 iTokens) | $0 | Empty markets are supply-capped at 0; `iTokenV2BLP` rounds `redeemUnderlying` **up** and enforces a min-supply threshold | None found |
| 7 | PieDAO / PowerPool / BasketDAO / Pickle / Yam / Indexed / Domani / Cook | $0 | Holder-only exit/burn/claim paths; no non-holder path found | Pickle jars (~$407k est.) not individually measured |

**Total live extractable by an external unprivileged attacker: ≈ $0.00.**
**Confidence: HIGH** for the adapters/router (direct state reads + fork proofs) and for the two
Compound-fork scans (exhaustive); **MEDIUM** for the protocol-side negative results (Domani/Indexed
pool enumeration and Pickle jars are incomplete).

**Holder-recoverable (H-O) value mapped on-chain ≈ $19.9M** (measured components below) — i.e. the
DeadDeFi $20.2M marketing figure is real value, but it is *holder redemption*, not an attacker path.

---

## 1. The adapter/router mechanism in exact terms

### 1.1 Architecture (all verified source)

- **Router** `0x121D5A2791791A62d0bE62C51459b1d3777701aF` = `DeadDeFiRouter` (verified, v0.8.20):
  `redeem(address adapter, address inputToken, uint256 amount, address[] outputTokens, uint256[] minAmountsOut)`.
  It pulls `inputToken` from the caller, sends it to the adapter, calls `adapter.redeem(...)`,
  then pays out `balanceOf(outputTokens[i])` deltas (fee to `feeRecipient`, currently 0 bps).
- **Adapters** (all deployed 2026-03-06 by EOA `0xD9319dD23c3d0E37949CCFFB98764A1B4B095C38`,
  blocks 24,595,467–24,595,650; all registered by the deployer on the router):
  `IndexCoopAdapter`, `AaveV1Adapter`, `SetV1Adapter`, `RariFuseAdapter`, `dForceAdapter`,
  `PieDAOAdapter`, `PickleAdapter`, `BasketDAOAdapter`, `PowerPoolAdapter`*, `DegenerativeAdapter`
  (Yam), `IndexedFinanceAdapter`*, `DomaniAdapter`, `CookFinanceAdapter`. (*unverified source;
  decompiled: both are `exitPool(uint256,uint256[])` + `_sweep(outputTokens)` variants.)
- Every adapter inherits `BaseAdapter`:
  ```solidity
  function _sweep(address[] calldata tokens) internal {
      for (uint256 i = 0; i < tokens.length; i++) {
          uint256 bal = IERC20(tokens[i]).balanceOf(address(this));
          if (bal > 0) IERC20(tokens[i]).safeTransfer(msg.sender, bal);   // msg.sender = Router
      }
  }
  ```
- **There is no output-token allowlist in v2.** The earlier (now `paused`) v1 contracts
  `DeadDeFiRedemption 0xd8cd4ee1…` and `AaveV1Redemption 0xa013e840…` *did* validate outputs
  against a per-protocol allowlist (`_validateOutputTokens`, `isProtocolOutput`, `strictOutputs`).
  The v2 redesign dropped it — a security regression.

### 1.2 The live permissionless primitive

Any external caller can invoke `router.redeem` with:

- `adapter` = any of the 13 registered adapters;
- `inputToken` = **any address** — for the direct-call adapters (PieDAO, Pickle, AaveV1, RariFuse,
  dForce, PowerPool, IndexedFinance) a caller-deployed contract exposing a no-op
  `exitPool(uint256)` / `redeem(uint256)` / `withdraw(uint256)` is sufficient; for the module
  adapters (Index Coop, SetV1, Domani, Cook, Degenerative, BasketDAO) ≥1 wei of the real protocol
  token (or, for BasketDAO, real BDI) is needed to satisfy the module;
- `amount` = 0 (direct-call adapters) or 1 wei;
- `outputTokens` = **any list** (no on-chain allowlist) — the adapter's `_sweep` then transfers its
  **entire balance** of every listed token to the router, which pays the caller (0% fee).

Two further leaks:

- `DeadDeFiRouter._forwardETH()` sends the router's **whole ETH balance** to the caller of *any*
  `redeem` call, including a zero-amount one.
- `AaveV1Adapter` and `dForceAdapter` wrap their **whole ETH balance** to WETH (`IWETH.deposit`)
  before sweeping, so any ETH that lands in those adapters is converted and swept.

**Net: any token/ETH that lands in any adapter or the router — by user error, a donation, dust, or
an incomplete/partial redemption — is claimable by anyone, immediately.** This is the only live
permissionless bug on the surface; today the contracts hold nothing, so the extractable value is $0.

### 1.3 Roles / admin (not attacker-reachable)

| Contract | `owner()` | Notes |
|---|---|---|
| Router | `0xD931…5C38` (EOA) | can register/remove adapters, set fee ≤500 bps, pause, `rescueToken`/`rescueETH` |
| All 13 adapters | **none** (ownerless) | `router` is immutable; `redeem` is `onlyRouter` |
| v1 `DeadDeFiRedemption` / `AaveV1Redemption` | `0xD931…5C38` | both `paused = true` since block 24,596,248/254 |

`feeBps` was 300 (3%) until block 25,174,832, then set to **0**; `feeRecipient` is
`0x9a38Da81C1f6380dECd2b22A06Fad41E379F85B1` (EOA, holds ~$20 of residual fee dust).

### 1.4 Live activity (router txlist, all time)

23 transactions total: 13 `registerAdapter` + 1 `setFeeBps(0)` by the deployer; **4 successful
redemptions by 3 users** (RariFuse fgOHM-6 → 0.1186 gOHM; IndexCoop 0.004827 DPI → 8 components;
PowerPool 4.6917 PIPT → 8 components; PieDAO DEFI++ dust) and **4 failed attempts**. Total user
flow to date is only a few hundred dollars — the site's $20.2M is a claim about the underlying
protocols, not about adapter throughput.

---

## 2. Live-state assessment — adapters & router

All 13 adapters and the router were read at blocks 26,111,005 → 26,111,363:

| Contract | ETH | ERC-20 (DPI/COMP/WETH/USDC + full history scan) | Code | Registered |
|---|---|---|---|---|
| `DeadDeFiRouter 0x121D5A…01aF` | 0 | 0 | yes | — |
| IndexCoop / AaveV1 / SetV1 / RariFuse / dForce / PieDAO / Pickle / BasketDAO / PowerPool / Yam / IndexedFinance / Domani / CookFinance adapters | **0 each** | **0 each** | yes (11 verified, 2 decompiled) | all `true` |

Etherscan `tokentx` for each adapter confirms balances return to 0 after every redemption;
GoldRush portfolio scans returned empty for all 17 addresses; the only non-zero balances in the
whole system are the feeRecipient's accumulated 3% fees (gOHM 0.003558, LINK 0.0266, CVP 2.61, …,
≈ $20–30 total) — a private EOA, not attacker-reachable.

---

## 3. Underlying native protocols — measured live value and classification

Prices: DefiLlama `coins.llama.fi` at 2026-10-03 (ETH $2,683, LINK $13.93, WBTC $84,551,
wstETH $3,340, DPI NAV computed). Classes: **E-U** external-unprivileged / **H-O** holder-only /
**P** privileged / **S** stuck.

| Protocol | Native contract(s) | Live value (measured unless noted) | Class | E-U |
|---|---|---|---|---|
| **Aave V1** | `LendingPoolCore 0x3dfd23a6c5e8bbcfc9581d2e864a68feb6a076d3`; aTokens (`aETH 0x3a3A65aA…`) | Core ≈ **$8.04M**: 926.0015 ETH ($2.485M), 238,905 LINK ($3.33M), 545,285 DAI, 510,621 USDC, 766,025 USDT, 315,169 BAT, 72,333 ZRX, 48,512 SNX, 64,492 MANA, 2.6243 WBTC, 49,491 KNC, 36.36 MKR, …; aToken claims ≈ **$7.66M** (aETH 933.08) | **H-O** | $0 found |
| **Index Coop** | DPI `0x1494CA1F11D487c2bBe4543E90080AeBa4BA3C2b`; `BasicIssuanceModule 0xd8EF3cAC…` | **DPI components $7,010,418** (MKR $1.46M, AAVE $2.21M, UNI $1.99M, ENA $0.49M, LDO, PENDLE, COMP, RPL; DPI supply 93,204.80, NAV ≈ $75.2 vs market $79.1); DefiLlama Ethereum aggregate $16.4M | **H-O** | $0 found |
| **Set Protocol V1** | Vault `0x5b67871c3a857de81a1ca0f9f7945e5670d986dc`; module `0xcEDA8318…` | **$1,675,407** (WETH 497.22 $1.334M, WBTC 2.76 $233k, LINK 4,526 $63k, cUSDC/cDAI ≈ $29.8k, COMP 333, USDC/DAI/SAI) | **H-O** | $0 found |
| **Rari Fuse** | 201 pools (FusePoolDirectory `0x835482FE…`), 787 markets | DefiLlama rari-capital $1.06M; **scan: 0 empty-market candidates** (no `totalSupply==0` market that is listed, mintable and CF>0) | **H-O** | $0 found |
| **dForce Lending** | Controller `0x8B53Ab2c…`; 32 iTokens (General Pool) | General-pool cash ≈ **$1.90M** (iwstETH 303.26 $1.01M, iUSDT $351k, isUSX $310k, iWBTC $107k, iETH $64k, iDAI $38k, …) | **H-O** | $0 found |
| **PieDAO** | DEFI++ `0x8D1ce361…` | **$236,072** (LINK $67k, MKR $65k, AAVE $56k, UNI $34k, YFI, SNX, …); DefiLlama piedao $441k | **H-O** | $0 found |
| **BasketDAO** | BDI `0x0309c98B…` (impl `Root 0xf75c5733…`) | ≈ **$120,890 priced** (yvUNI $37.3k, AAVE $43.7k, MKR $34.0k, yvYFI, xSUSHI, ZRX, KNC, LRC, … + ~$4k unpriced); burns live (components paid out through 2026-09) | **H-O** | $0 found |
| **Pickle Finance** | `PickleDistribution 0x63a9Fd263688BB3B7c79305cdD5D91Fb064D7865` | **100,200.35 USDC unclaimed** (of 170,280; 568 leaves); Merkle root recomputed and verified; jars (~$407k est.) not individually measured | **H-O** | $0 found (owner EOA can `emergencyWithdraw` = P) |
| **Yam Degenerative** | uSTONKS EMP `0x4F1424Cef6AcE40c0ae4fc64d74B734f1eAF153C` | **95,837.56 USDC** collateral in the expired (2021-04-30) EMP; 117,054,602 raw synth outstanding | **H-O/P** (sponsors settle/withdraw) | $0 found |
| **Indexed Finance** | CC10 `0x17ac188e…`, DEGEN `0x126c121f…` | checked pools nearly empty (≈$3 of REN; CC10 dust); DefiLlama $147k unverified — pool enumeration incomplete | **H-O** (unverified) | $0 found |
| **Domani** | module `0xBa1030459e75f6041F938c5470F4E0f6468d5253` | module **never used** (0 token transfers); DEXTF `0x5F64Ab…` exists; est. $40k unverified | **H-O** (unverified) | $0 found |
| **Cook Finance** | CLI `0xA6156492…`; module `0x59E799B5…` | **$30,674** (0.3031 WBTC + 1.881 WETH; CLI supply 51.94, NAV ≈ $590) | **H-O** | $0 found |

**H-O measured subtotal:** 7.664 + 7.010 + 1.675 + 1.897 + 0.236 + 0.121 + 0.100 + 0.096 + 0.047 +
0.031 = **$18.88M**; + Rari Fuse DefiLlama $1.06M = **$19.94M** — the DeadDeFi $20.2M claim is
substantiated as *recoverable-by-holders*, with E-U = $0.

### 3.1 Why the lending forks are closed (the main E-U hypothesis)

The C-37 surface includes the two most notorious Compound-v2-fork bug classes: the **empty-market
donation/inflation attack** (Hundred→Sonne→Onyx lineage). Both were exhaustively scanned in CI:

- **Rari Fuse:** all 201 pools / 787 markets read (`getAllMarkets`, `totalSupply`, `getCash`,
  `totalBorrows`, `markets()`, mint/borrow pause flags). **Zero** markets satisfy
  `totalSupply==0 ∧ isListed ∧ CF>0 ∧ mintable`. (Two pools failed to enumerate; both are
  long-dead with no DefiLlama TVL.)
- **dForce:** all 32 iTokens read (`marketsV2`). The empty markets (`iHBTC`, `ixBTC`, `ixETH`,
  `iMUSX`, `iMEUX`, `iMxBTC`, `iMxETH`, `iFEI`, `irenFIL`) all have **`supplyCapacity == 0`**, so
  `beforeMint` blocks the first deposit. The two tiny-supply markets with open caps
  (`icbBTC` 42,776 raw, `iXAUt` 78,504 raw, CF 0.8) are additionally protected by the custom
  `iTokenV2BLP` implementation: `redeemUnderlying` uses `rdivup` (**rounds up**, not the Sonne
  truncation) and `_redeemInternal` enforces `totalSupply >= TOTAL_SUPPLY_THRESHOLD || totalSupply == 0`.

---

## 4. What an attacker can / cannot do

**Can (all fork-proven):**

1. Sweep any ERC-20 balance held by any adapter: `router.redeem(adapter, fakeToken, 0, [targetToken], [0])`
   for direct-call adapters — zero capital, no real protocol token.
2. Same for module adapters with 1 wei of the real token: `router.redeem(IndexCoopAdapter, DPI, 1, [DPI], [0])`.
3. Grab any ETH in the router: send it 1 wei via any `redeem` (the `_forwardETH` path pays the caller).
4. Grab ETH in the AaveV1/dForce adapters: they wrap it to WETH and the sweep pays it out.
5. **Steal an incomplete redemption's leftovers**: a user redemption whose `outputTokens` list omits
   components leaves those components in the adapter; an unprivileged back-runner then sweeps them
   with 1 wei of input. (The current frontend simulates outputs, so this needs user/front-end error.)

**Cannot:**

- Take anything from the currently-empty adapters/router (all balances are 0).
- Pull a third party's tokens through their standing router allowance — `redeem` always transfers
  from `msg.sender`; the router has no third-party pull path, and adapters only spend what the
  router sends them.
- Forge Merkle claims in `PickleDistribution` (root recomputed from `distribution.json`; OZ
  `MerkleProof` + per-address `claimed` flag).
- Mint into dForce's empty markets (`supplyCapacity=0`) or exploit the Sonne rounding (round-up).
- Reach any Rari Fuse empty market (none exist).

**Costs:** the sweep calls are plain mainnet transactions (~150–250k gas, no flash loan needed for
direct-call adapters; 1 wei of token + gas for module adapters). The value captured is whatever is
sitting in the adapter at that moment.

---

## 5. PoC / fork verification

`poc/` — Foundry project, vendored `forge-std`, tests on a mainnet fork
(`vm.createSelectFork(FORK_RPC_URL)`), **7/7 PASS**:

| Test | Proves |
|---|---|
| `test_live_state_adapters_and_router_empty` | All 13 adapters + router hold 0 ETH / 0 DPI / 0 COMP / 0 WETH / 0 USDC live |
| `test_A_piedaoAdapter_fakeToken_sweeps_adapter_balance` | Zero-capital fake-input sweep of 1 DPI placed in the PieDAO adapter |
| `test_B_indexCoopAdapter_dustInput_sweeps_adapter_balance` | Module adapter: 1 wei real DPI input sweeps the adapter's full 2 DPI balance |
| `test_C_router_eth_donation_is_grabbed_by_any_redeem` | 1 ETH in the router is forwarded to the caller of any `redeem` |
| `test_D_aaveAdapter_eth_is_wrapped_and_swept` | 1 ETH in the AaveV1 adapter is wrapped to WETH and swept to the caller |
| `test_E_partial_redemption_leftovers_are_stolen_by_backrun` | 10 DPI redeemed with 1-of-8 outputs → attacker captures the MKR/UNI/… leftovers with 1 wei |
| `test_F_complete_redemption_leaves_nothing` | Negative control: a complete output list leaves 0 behind |

**CI runs** (public repo `kingmariano/ca-zombie-ci`):

- ✅ **Final green run (scan + 7/7 tests):** https://github.com/kingmariano/ca-zombie-ci/actions/runs/37117319119
- ❌ First run (2 assertion-precision failures: 1–2 wei; scan RPC User-Agent bug): https://github.com/kingmariano/ca-zombie-ci/actions/runs/37117094077

CI heavy jobs (`ci/run.sh` → `ci/scan.py`) produced `ci-out/fuse_scan.json` (201 pools, 787
markets, 2 dead-pool errors), `ci-out/fuse_candidates.json` (`[]`), `ci-out/dforce_scan.json`
(32 iTokens + oracle prices), `ci-out/dforce_candidates.json` (`[]`). Copies in `analysis/ci/`.

---

## 6. Verdict, residual/latent risk, blockers

**Verdict.** An external unprivileged attacker can extract **$0.00 today** from the C-37 surface.
The only live permissionless bug is the **adapter output-token sweep primitive** in the DeadDeFi v2
router — real, reproducible, and a regression from v1's allowlist — but every adapter and the
router are empty, so there is nothing to take. The ~$20.2M of "recoverable value" is real and sits
in the native protocols as **holder-redemption (H-O)** claims; no non-holder extraction path was
found, and the two Compound-fork empty-market hypotheses were exhaustively falsified.

**Residual / latent risk.**

1. **Adapter dust/donation capture (HIGH likelihood, unbounded per-event):** any value arriving at
   any adapter or the router is instantly claimable by anyone. This includes back-running an
   incomplete redemption. There is no allowlist, no min-amount guard, and the owner cannot pause a
   single adapter (only the whole router).
2. **In-flight value is safe only if the caller's `outputTokens` list is complete** — the router
   does not verify it against `getExpectedOutputs`. A front-end regression or a hand-crafted
   Etherscan call that omits outputs donates the remainder to the next back-runner.
3. **Owner powers (P, not E-U):** EOA `0xD931…5C38` can pause redemptions, raise fees to 5%, and
   `rescueToken`/`rescueETH` anything left in the router; Set V1's owner (a contract, 7-day
   timelock) could authorize a drainer for the $1.675M vault; the Pickle distribution owner EOA can
   `emergencyWithdraw` the 100.2k unclaimed USDC.
4. **Anomalies worth monitoring:** aSUSD 114,213 is unbacked in the Aave V1 core (sUSD reserve cash
   = 0; either fully borrowed or migrated); Aave V1's ~$150k of residual borrows were not
   position-enumerated (permissionless liquidation may exist if any position is unhealthy).

**Blockers / limitations.**

- Alchemy MCP is over its monthly quota; GoldRush `token_balances` returned empty for all addresses
  (verified bug — known-funded addresses also returned `[]`), so all balances were read directly via
  JSON-RPC `balanceOf`.
- Fuse per-pool cash aggregates contain scam-token decimal artifacts (e.g. "PebbleDAO $203M"); the
  Rari figure quoted is DefiLlama's, not the raw sum.
- Indexed Finance's full pool set and Pickle's jar set were not exhaustively enumerated (low value,
  low activity); Domani's product set is unknown (module never used).
- Aave V1 borrower positions (liquidation path) were not enumerated.
- Fork tests are simulations on forked state; no mainnet transaction was ever sent.

---

## 7. Methodology & sources

- **Corpus:** `zombie_hunt/FINDINGS.md` C-37 + correction, `non_llama_and_directories.md` §2A,
  `verification_live_funds.md`. All corpus leads were re-verified on-chain.
- **Contract sources:** Etherscan V2 `getsourcecode`/`getabi` (11/13 adapters verified; PowerPool +
  IndexedFinance decompiled with heimdall: `exitPool(uint256,uint256[])` + `_getCurrentTokens` +
  `_sweep`). Deployer history from `txlist`; adapter registrations from router `txlist`.
- **State:** `eth_call`/`eth_getBalance`/`eth_getCode` against public RPCs
  (`ethereum-rpc.publicnode.com`, `eth.drpc.org`) at recorded blocks; Etherscan `tokentx` for
  complete ERC-20 histories; DefiLlama `coins.llama.fi` for prices; DefiLlama `/tvl/{slug}` and
  `/protocol/{slug}` for cross-checks.
- **Heavy enumeration:** GitHub Actions (`c-37/ci/scan.py`) — 201 Fuse pools / 787 markets and 32
  dForce iTokens, with pause flags, collateral factors, capacities and oracle prices.
- **PoC:** Foundry 1.7.1 on GitHub Actions runners, mainnet fork, 7/7 tests.

### Files index

```
c-37/
├── README.md                     # this deliverable
├── summary.json                  # machine-readable summary
├── analysis/
│   ├── adapters.txt              # the 13 adapter addresses
│   ├── adapter_registry.txt      # registeredAdapters() + adapter.router()
│   ├── adapter_recon_initial.txt # code size / ETH balances
│   ├── balances_scan.json        # direct token balance scan (all zero)
│   ├── aave_v1_scan.json         # Aave V1 core reserves + aToken supplies
│   ├── native_scan2.json         # SetV1/DPI/PieDAO/PIPT/BDI/Yam/Indexed/Cook reads
│   ├── prices.json               # DefiLlama prices used
│   ├── measure.py / measure2.py / valuate.py
│   ├── dforce_itokens.json, dforce_market_scan.json
│   ├── fuse_pools.json           # 201 Fuse pools
│   ├── router_txlist.json, tokentx/*.json
│   ├── sources/                  # verified + decompiled contract sources
│   └── ci/                       # CI scan outputs (fuse/dforce scans + candidates)
├── poc/
│   ├── foundry.toml
│   ├── lib/forge-std/            # vendored
│   └── test/C37.t.sol            # 7 fork tests
├── ci/
│   ├── run.sh                    # heavy scan entry point
│   └── scan.py                   # Fuse + dForce empty-market scanner
├── ci-log.txt                    # CI log (final run)
└── ci-artifacts/                 # CI artifacts (final run)
```
