# C-34 — Claim/locker periphery with standing authority: Hedgey, Hemi MerkleBox, Socket/Bungee

**Campaign:** zombie-hunt · **Chains:** Ethereum, Arbitrum, Optimism, Base, BSC (+ Socket gateway on Avalanche/Gnosis) · **Date of work:** 2026-10-03
**Status:** read-only research; PoC/boundary tests verified on local forks only (GitHub Actions). No mainnet transactions sent.

Scope (three surfaces from `zombie_hunt/FINDINGS.md` C-34):

1. **Socket/Bungee gateway** `0x3a23F943181408EAC424116Af7b7790c94Cb97a5` — 2024-01-16 approval sweep via the pre-review `WrappedTokenSwapperImpl` route (route 406).
2. **Hedgey `ClaimCampaigns`** `0xBc452fdC8F851d7c5B72e1Fe74DFB63bb793D511` — 2024-04-19 missing-revoke bug; same immutable bytecode on 5 chains.
3. **Hemi Genesis Drop `MerkleBox`** `0x9Ab3660ceE733332785cEa09D1a4Ff222F31aE54` — 2026-09-07 lockup-before-accounting reentrancy.

## TL;DR — external unprivileged extractable value today

| # | Surface | Chain(s) | Live extractable now (E-U) | Why closed/open | Latent risk |
|---|---|---|---|---|---|
| 1 | Socket/Bungee gateway (approval sweep) | ETH + 6 chains | **$0** | Route 406 (`WrappedTokenSwapperImpl`) disabled 15 min after the attack; every enabled route uses `msg.sender` as the transfer `from`; no live impl contains the vulnerable module bytecode | 547,194 lifetime approvals to the gateway; 129 attack victims: **39 still have a live USDC allowance, 16 with balance = $15,755.11**; owner could re-enable a bad route |
| 2 | Hedgey `ClaimCampaigns` (missing revoke) | ETH, ARB, OP, Base, BSC | **~$0.37 gross / ~$0.35 net** | Bug is fully live (immutable code, no pause); only dust-value token balances remain | Any future token sent to any of the 5 instances is instantly sweepable by anyone |
| 3 | Hemi `MerkleBox` (claim reentrancy) | Hemi | **$0** | Contract drained 2026-09-07; HEMI balance 0, holdings 15/16 empty; only a valueless "Test" token remains | Immutable, permissionless `claim`; new deposits would be re-drainable via the same reentrancy |

**Total live extractable by an external unprivileged attacker: ≈ $0.37 gross / ≈ $0.35 net (Hedgey). Confidence: medium-high on the mechanism (fork-verified), medium on the USD price of the two small tokens.**

## 1. Socket/Bungee gateway — approval sweep (closed)

### 1.1 The bug (confirmed by on-chain trace + verified source)

- Gateway `0x3a23F943181408EAC424116Af7b7790c94Cb97a5` is a non-proxy router (`SocketGateway`, verified) that `delegatecall`s into per-route implementation contracts: `executeRoute(uint32 routeId, bytes routeData)` → `routes[routeId].delegatecall(routeData)`. **No access control.**
- The pre-review module was route **406 = `0xCC5FdA5e3cA925bd0bb428C8b2669496Ee43067e` (`WrappedTokenSwapperImpl`)** added at block **18,996,162** and disabled at block **19,021,526**.
- In the wrapped→native branch, `performAction(fromToken, toToken, amount, receiver, metadata, swapExtraData)`:
  - `ERC20(fromToken).safeTransferFrom(msg.sender, socketGateway, amount)` — with `amount = 0` this moves nothing;
  - `fromToken.call(swapExtraData)` — an **arbitrary call on the token contract executed as the gateway**;
  - `require((_finalBalanceTokenOut - _initialBalanceTokenOut) == amount)` — checks only the *gateway's ETH balance*, which is unchanged (`0 == 0`);
  - `payable(receiver).transfer(amount)` — 0.
- The 2024-01-16 attack tx (`0xc6c3331fa8c2d30e1ef208424c08c039a89e510df2fb6ae31e5aa40722e28fd6`, block 19,021,454, attacker `0x50DF5a2217588772471B84aDBbe4194A2Ed39066`) called the gateway with exactly:
  - routeId **406** (`0x00000196`), selector `performAction` (`0x7899f9ed`),
  - `fromToken = USDC`, `toToken = 0xEeee…EEeE` (NATIVE), `amount = 0`, `receiver = 0x856da0ACbf…`,
  - `swapExtraData = 0x23b872dd` + `transferFrom(victim, attacker, X)`.
- The trace (`eth.blockscout.com` internal txs) shows per victim: child→gateway `transferFrom(child, gateway, 0)`, then **gateway→USDC `transferFrom(victim, attacker, X)`**, then gateway→receiver `transfer(0)`. 129 calls parsed from the raw trace, **2,570,850.82 USDC** moved in this tx.

### 1.2 Live state (2026-10-03)

| Check | Result | Block |
|---|---|---|
| `routesCount()` | 447; route 406 and 386 return `disabledRouteAddress = 0x0f34A522FF82151c90679b73211955068FD854F1` | 26,108,903 |
| `executeRoute(406, …)` simulation | reverts `RouteDisabled()` (`0x17d0b6db`) | 26,108,977 |
| Live routes / controllers | 58 live routes, 56 unique impls; 3 controllers (`RefuelSwapAndBridgeController`, `FeesTakerController` ×2) | 26,108,903 |
| Bytecode scan of all live impls | **no** impl contains the `wrappedTokenSwapperImpl` marker and **none** is byte-identical to `0xCC5FdA5e…` | CI `socket_marker_scan.json` |
| All live `transferFrom` callsites | every one uses `msg.sender` as `from`; the only user-supplied-target call is `feesTakerAddress.call{value:…}("")` (bare value, no calldata) | source review of 56 impls + 3 controllers |
| Other chains (same gateway address) | deployed on Arbitrum, Optimism, Base, BSC, Avalanche, Gnosis (48,613-byte code); route ids differ per chain; sampled impls carry no marker | see CI multi-chain scan |
| Gateway own balances | 221 wei ETH + ~387 token "balances", almost all spam/dust (largest real-looking: 721 PEPE, 1.5M XEN, 14.14 TEL, 0.44 POL); no permissionless sweep path exists | 26,108,xxx |

### 1.3 Standing authority (latent, not extractable today)

- **Full-lifetime census** (eth_getLogs, topic0 = ERC-20 `Approval`, topic2 = gateway, blocks 16,848,303 → 26,109,311, no truncation): **547,194 Approval events; 242,106 unique (token, owner) pairs; 197,372 pairs whose latest approval value > 0.** Top tokens by event count: USDC 209,284; USDT 58,106; WETH 50,300; MATIC 30,490; WBTC 4,705; DAI 4,457; PEPE 4,160.
- **Live check of the 3,000 most recent unique pairs** (latest block 26,109,311): 11 still have `allowance > 0`, 5 of those have a non-zero owner balance, worth ≈ **$220** (4 USDC pairs ≈ $205; one JESUS pair ≈ $15).
- **Targeted live check of the 129 victims parsed from the 2024 attack trace** (USDC, block 26,109,126):
  - **39/129 still have `allowance(victim → gateway) > 0`** (most infinite);
  - **16/129 have allowance > 0 *and* a non-zero USDC balance**, totalling **$15,755.11** (largest: `0xbbc02dbd…` $11,941.91, `0xed2fce39…` $5,566.12 but allowance limited to $950, `0x470785ff…` $1,594.55).
- **Verdict:** $0 extractable today. The value is gated on the route table: the owner (`0xB0BBff6311B7F245761A7846d3Ce7B1b100C1836`) re-enabling a module with the arbitrary-call pattern, or any future module with the same flaw, would instantly re-open a sweep of the standing approvals. Full raw census + live-check results are in the CI artifacts (`ci-out/socket_approvals_raw.json`, `ci-out/socket_live_approvals.json`).

## 2. Hedgey `ClaimCampaigns` — missing approval revoke (LIVE, dust)

### 2.1 The bug (present in deployed verified source)

`createLockedCampaign()` deposits `campaign.amount`, then
`SafeERC20.safeIncreaseAllowance(token, claimLockup.tokenLocker, campaign.amount)`.
`cancelCampaign()` returns the deposit to the manager **without revoking that allowance**. The caller-supplied `tokenLocker` therefore retains `allowance(ClaimCampaigns → tokenLocker) = campaign.amount` and can call `token.transferFrom(ClaimCampaigns, attacker, ≤ amount)` — draining the contract's **entire** token balance (all campaigns + donations), not just the attacker's own deposit. No privileged role is needed: `createLockedCampaign` is permissionless; the attacker only needs to temporarily hold `campaign.amount` tokens (flash-loanable).

- Bytecode is identical on Ethereum, Arbitrum, Optimism, Base and BSC — codehash `0x725bc4ce48b9a71a4fd491b1f7bdcf29c772d92f8ee7a5cd6c3264f570f70db4` — i.e. the vulnerable revision is live on all five.

### 2.2 Live balances (all tokens ever received were re-checked with `balanceOf`)

| Chain | Block | Non-zero balance | Market? | Value |
|---|---|---|---|---|
| Ethereum | 26,109,126 | BIGCAT 10,354; HDSF 34 | no DEX pair, no DefiLlama price | $0 |
| Arbitrum | 511,184,580 | TACO 100,061; Unishop.ai 0.000001 | TACO: no pair; Unishop: pair exists but balance dust | ~$0 |
| Optimism | 157,699,714 | SEAL 4,000 | no pair | $0 |
| Base | 52,104,430 | NEGED 7,920 (16 other spam tokens, no pairs) | NEGED pair ~$17.7k liq, $1.714e-5 | **$0.136** |
| BSC | 125,412,624 | USDT 0.237074968053996660 (+ DEGEN 2.0, BFK no pairs) | BSC-USD, $0.9994 | **$0.237** |

Token history: all `Transfer`-in events to the Ethereum instance were enumerated (2,471 rows, 10 distinct tokens); current non-zero balances were read directly on-chain. All four other chains were enumerated via GoldRush `balances_v2` and re-read with `balanceOf`.

### 2.3 Extractable

Gross ≈ **$0.37** (BSC USDT $0.237 + Base NEGED $0.136 + Base OOMER/USA dust ~$0.0007); gas to run the whole exploit (create + cancel + sweep, ~300k gas) is ≲ $0.03 on BSC/Base, so **net ≈ $0.35**. Tokens without a market (BIGCAT/HDSF/TACO/SEAL) cannot even be sourced to satisfy the temporary-capital requirement, and are worth $0 anyway.
**Latent:** the path is live and immutable. Any real-value token that lands in any of the five instances (airdrop, donation, a reactivated campaign) becomes permissionlessly sweepable by anyone.

### 2.4 The rest of the Hedgey periphery

- **ClaimCampaigns v2** (`0x8A2725a6f04816A5274dDD9FEaDd3bd0C253C1A6` and later deployments) is **fixed**: `createLockedCampaign` whitelists `tokenLocker` (`tokenLockers[...]`), `cancelCampaigns` requires `allowance(this, tokenLocker) == 0`, and the claim path re-checks the allowance is 0 afterwards. The live v2 instance holds campaign funds (H-O for campaign managers/claimants), but the missing-revoke path does not exist there. v1 (the five same-address instances above) remains permanently vulnerable.
- **Lockup/Vesting plan family** (e.g. `TokenLockupPlans_Bound 0xA600EC7Db69DFCD21f19face5B209a55EAb7a7C0`, holding e.g. 129.9M PUFFER, 43.5M CO, 445M DOG, 14k BIGCAT): redemption is NFT-owner-gated (`require(ownerOf(planId) == msg.sender)`) → **H-O**, no unprivileged path found. `createPlan` pulls from its own caller (`msg.sender`), so the leftover v1 allowance to a *legitimate* locker cannot be abused by calling the locker directly.
- **User approvals to ClaimCampaigns** (campaign creators) are only pullable by ClaimCampaigns inside `create*Campaign`, which the user must invoke — no attacker path; not counted.

## 3. Hemi Genesis Drop `MerkleBox` — reentrancy (drained, $0)

### 3.1 The bug (present in deployed verified source)

`claim()` calls `_createLockupFor()` **before** updating `holding.balance`/`leafClaimed`. `_createLockupFor` approves the attacker-supplied `lockupContract` and calls `ILockupContract(lockupContract).createLockFor(...)` — an external call into attacker code with the claim accounting not yet updated. Re-entering `claim()` (same group, 63 levels in the real attack) lets the attacker withdraw repeatedly against the same un-decremented `holding.balance`. Any address can create a claim group with an arbitrary `lockupContract` (`newClaimsGroup` is permissionless).

### 3.2 Live state (2026-10-03, Hemi block 5,427,470 / 5,425,545 explorer)

| Check | Result |
|---|---|
| HEMI `0x99e3dE38…` balance of `0x9Ab3…` | **0** |
| Native balance | 0 |
| Holdings 15 & 16 (attacker groups, `hemi-p8`, owner `0x695B7c64…`) | `balance = 0` (both) |
| `claimGroupCount()` | 16 |
| Second `MerkleBox` `0x112de51b…` (vanilla deployment) | HEMI 0, no token balances |
| Other tokens in `0x9Ab3…` | only `TT` ("Test", `0x80625E75…`) 4.83e42, no market, 2 holders, value $0 |
| Related Hemi airdrop/distributor contracts (`Airdrop 0x3249…`, `AirdropERC721 0xe433…`, `Distributor 0x1a23…`/`0x9182…`, `DropERC721 0xf685…`) | HEMI balance **0** in all |
| `claim()` / `newClaimsGroup()` | still permissionless and un-pausable (immutable) — but there is nothing left to extract |

### 3.3 Extractable

**$0.** The 124.5M unclaimed HEMI were sold for ~$255k and bridged out on 2026-09-07; the contract cannot be re-funded by protocol paths. The fork PoC replays the reentrancy shape with 3 nested claims and shows the maximum outcome is a round-trip of the attacker's own deposit (or a revert on the empty balance). Any future HEMI sent to this address would be instantly re-drainable by the same public path (latent risk).

## 4. PoC / fork verification

Foundry project `poc/` (vendored forge-std). Tests are read-only forks; run in CI via `bash /home/heisenberg/CA/ci/ci-run.sh c-34`.

| Test file | Test | Proves |
|---|---|---|
| `test/SocketC34.t.sol` | `test_socket_live_route406_disabled_and_reverts` | Live `executeRoute(406, sweepCalldata)` reverts `RouteDisabled()`; victim funds unmoved |
| | `test_socket_live_no_route_uses_vulnerable_impl` | No enabled route (of 447) uses the vulnerable module bytecode |
| | `test_socket_live_zeroxv2_route_cannot_sweep_victim` | Enabled ZeroxV2 route (434) cannot touch a victim's gateway allowance |
| | `test_socket_historical_route406_sweep` | On a pinned pre-disable fork (block 19,021,000), the same calldata drains 1,000 USDC from a victim's standing approval |
| `test/HedgeyC34.t.sol` | `test_hedgey_eth_live_bigcat_sweep` | Live ETH instance: locker sweeps the contract's whole BIGCAT balance |
| | `test_hedgey_arb_live_taco_sweep` | Live Arbitrum instance: same |
| | `test_hedgey_bsc_live_usdt_sweep` | Live BSC instance: sweeps 0.237 USDT (the value-bearing case) |
| | `test_hedgey_base_live_neged_sweep` | Live Base instance: sweeps 7,920 NEGED |
| | `test_hedgey_opt_live_seal_sweep` | Live Optimism instance: same |
| `test/HemiC34.t.sol` | `test_hemi_live_balances_are_zero` | HEMI 0; holdings 15/16 empty; native 0 |
| | `test_hemi_claim_roundtrips_zero_profit` | Live reentrancy setup returns only the attacker's own deposit |
| | `test_hemi_reentrancy_extracts_zero_profit` | 3-level nested replay: no profit, contract stays at 0 |

CI run URLs: _see `summary.json` / `ci-log.txt`_.

## 5. Verdict, blockers, residual risk

- **E-U total: ≈ $0.37 gross / ≈ $0.35 net** — all of it Hedgey dust on BSC + Base. Socket and Hemi are provably $0.
- Blockers that keep the numbers small: (a) Socket route table no longer contains a module with a user-controlled call; (b) Hedgey instances hold only tokens with no or negligible liquidity; (c) Hemi MerkleBox is already emptied.
- Residual/latent risks worth monitoring:
  - Socket: **$15.7k USDC of live approvals from 129 2024 victims** (39 allowances live) — a single owner action (route re-enable) or a new flawed module re-opens the sweep. All approvals are on the gateway, not the modules.
  - Hedgey: any token with real value arriving at any of the five instances is immediately drainable by anyone.
  - Hemi: any HEMI/token arriving at the MerkleBox is immediately re-drainable via the public reentrancy path.

## 6. Methodology & sources

- On-chain reads with `cast` against public + keyed RPCs, explicit blocks recorded per call; state dumps in `analysis/`.
- Source: Etherscan V2 verified sources (Socket gateway + all live route impls; Hedgey `ClaimCampaigns`); Hemi explorer verified source + ABI.
- Incident sources: Revoke.cash Socket exploit page; SolidityScan Socket analysis; CertiK Hedgey incident analysis; Halborn Hedgey analysis; Hemi Genesis Drop post-mortem (2026-09-08); Blockscout internal-tx/raw-trace of the 2024 attack tx.
- Approvals enumeration: Etherscan V2 `getLogs` (topic0 = ERC-20 `Approval`, topic2 = gateway) with recursive block-window splitting; live `allowance`/`balanceOf` checks batched in CI.
- Prices: DexScreener pair data + DefiLlama (no price for BIGCAT/HDSF/TACO/SEAL/NEGED? NEGED via DexScreener) captured 2026-10-03.

### Caveats

- The Hedgey USD figure depends on two thin-market tokens; the exploitability is proven on forks, the price is point-in-time.
- The full-gateway census (547,194 events) is complete; the *live allowance check* is sampled: the 3,000 most recent unique pairs plus all 129 known 2024 victims. Older cohorts are likely to retain a higher share of live approvals (the victims cohort showed 30% live), so the total standing-approval exposure is higher than the two checked subsets; it is latent (not extractable) either way.
- Hemi RPC is the public endpoint; balances were cross-checked with the explorer (two independent sources).

## 7. Files

```
c-34/
├── README.md
├── summary.json
├── analysis/   socket_scan.py + socket_routes_26108903.json (route table), socket_impls.json,
│               socket_impl_callsites.json (per-impl call-site audit), socket_2024_victims.json +
│               socket_2024_victims_live.json (129 victims, live allowances), socket_approvals_summary.json,
│               hedgey_enum*.py + hedgey_tokens*.json + hedgey_cc_*.json + hedgey_valuations.json,
│               dexscreener_prices_20261003.json, EVIDENCE.md
├── poc/        foundry.toml, src/C34.sol, test/{Socket,Hedgey,Hemi}C34.t.sol, lib/forge-std
├── ci/         run.sh, socket_approvals_scan.py, socket_live_check.py, socket_marker_scan.py,
│               hedgey_multichain.py, hemi_state.py
├── ci-out/     artifacts produced by CI (gitignored; also uploaded as GitHub artifacts)
└── ci-log.txt  full CI log
```
