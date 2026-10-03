# C-25 — TrustedVolumes RFQ settlement (Ethereum): live extractable-value determination

**Campaign:** zombie-hunt deep-dive · **Chain:** Ethereum · **Date of work:** 2026-10-03
**Status:** read-only research. No mainnet transactions sent. All PoC/replay work ran on local mainnet forks
(GitHub Actions CI, `poc/` Foundry suite). `cast call`/`eth_call` reads only.

**Targets:** RFQ proxy `0xeEeEEe53033F7227d488ae83a27Bc9A9D5051756` · RFQ implementation `0x88eb28009351Fb414A5746F5d8CA91cdc02760d8` (unverified) ·
InventoryVault `0x9bA0CF1588E1DFA905eC948F7FE5104dD40EDa31` (the victim resolver, holds standing approvals).

---

## TL;DR

| Item | Value |
|---|---|
| Live extractable by an external unprivileged attacker **today** | **$0.00** |
| Why closed | The vulnerable RFQ selectors (`0x4112e1c2` fill-order, `0xea7faa61` `registerAllowedOrderSigner`) were **rolled back by the owner on 2026-06-22** (5 `rollback(bytes4,address)` txs). Live `getFunctionImplementation(0x4112e1c2) == address(0)`; calling it reverts `NotImplementedError(0x4112e1c2)`. All registry/admin functions are owner-gated (`Unauthorized(0x1de45ad1)` for non-owner). Proxy/impls hold 0 ETH and 0 tokens. |
| Absolute ceiling if *some* registered selector could spend approvals | **$1.15** — the total balance behind every live approval to the proxy (mostly the drained vault's dust + USDC $1.00). No registered selector can spend them (verified). |
| Latent risk | **HIGH.** The broken auth primitive is fully intact in the still-registered impl `0x88eb2800`: (1) self-service signer registration, (2) authorization checked against `order.receiver` while tokens are pulled from `order.inventory`, (3) broken replay protection. The owner is a **single EOA** `0xBa5b79EdBbAFf849F8e754B8d3C107a06fA2921a`; one `extend(0x4112e1c2, 0x88eb2800)` call restores the $5.87M-class drain path (fork-proven). The InventoryVault still holds **infinite ERC-20 approvals** for ~20 tokens to the proxy. |
| Historical loss | **$5.87M** in a single tx `0xc5c61b3a…` on 2026-05-07 (1,291.16110521587917927 WETH + 206,282.446876 USDT + 16.93910519 WBTC + 1,268,771.488879 USDC); replayed verbatim on a pre-exploit fork (fork-proven). |
| Confidence | **High** for $0 live extractable (direct on-chain proof + fork tests). |

**Total live extractable now: $0.00 (E-U).** Confidence: high. Not one wei of value can be moved by an
unprivileged caller through the current proxy state; every path that could move value is either unregistered,
owner-gated, or read-only.

---

## 1. The bug / mechanism, in exact terms

TrustedVolumes operated a custom RFQ settlement system built on the **0x Exchange Proxy architecture**
(selector→implementation mapping, `extend`/`rollback` admin, native `getFunctionImplementation(bytes4)`,
plus upstream 0x feature forks). The RFQ feature (`impl 0x88eb2800`, still unverified) contained three chained
defects that any external caller could abuse:

1. **`registerAllowedOrderSigner(address,bool)` (selector `0xea7faa61`) had no access control.**
   It wrote `_allowedOrderSigner[msg.sender][signer] = allowed` (see darknavy/Verichains analyses; the
   selector maps into the RFQ impl). An attacker deployed a helper and registered their own EOA as a valid
   signer for the helper (as "receiver"/maker).
2. **Authorization/source mismatch in the fill-order function `0x4112e1c2`.** The function recovered the
   signer and checked `_allowedOrderSigner[order.receiver][signer]`, but pulled the sold tokens with
   `transferFrom(order.inventory, receiver, amount)` — `order.inventory` was an independent,
   attacker-supplied field. The check and the debit referred to different addresses.
3. **Broken replay protection** (read key ≠ write key) let the same forged order be filled repeatedly; the
   attacker used four distinct orders in one transaction, one per asset.

The InventoryVault (`0x9ba0cf15…`) had granted the proxy unlimited approvals on ~20 tokens — the blast radius.

**Attack (2026-05-07, block 25,039,670, tx `0xc5c61b3ac39d854773b9dc34bd0cdbc8b5bbf75f18551802a0b5881fcb990513`):**
attacker EOA `0xc3ebddea…` → helper `0xd4d5db5e…` (created in-tx) → `registerAllowedOrderSigner(attacker,true)`
→ helper approves 4 wei USDC to the proxy → four `0x4112e1c2` calls, each pulling one asset from the vault to
the helper and returning 1 wei USDC as nominal payment. Helper unwraps WETH and forwards everything to the
attacker EOA. Total: **$5.87M**.

**Fix applied by the team (2026-06-22, blocks 25,374,066–72):** five `rollback(bytes4,address)` transactions
from the owner EOA unregistered `0x4112e1c2`, `0xea7faa61`, `0x06c1f431`, `0xdcbbc8d4`, `0x01e480ab`.
No further owner action since (deployer EOA's last tx: 2026-06-22).

---

## 2. Live-state assessment (all reads at block 26,108,8xx–26,109,04x, 2026-10-03)

### 2.1 Registry — every selector ever registered, replayed from 55 events and verified live

The proxy emits a registry event (topic `0x2ae221083467de52078b0096696ab88d8d53a7ecb44bb65b56a2bab687598367`)
on every `extend`/`rollback`. All 55 historical events were replayed; the resulting map matched the live
`getFunctionImplementation()` result for **all 37 selectors (0 mismatches)**. Current state:

| Selector | Function | Current impl | Live? |
|---|---|---|---|
| `0x4112e1c2` | RFQ fill-order (**the drain**) | `address(0)` since 2026-06-22 | **NO** |
| `0xea7faa61` | `registerAllowedOrderSigner` | `address(0)` since 2026-06-22 | **NO** |
| `0x06c1f431` / `0xdcbbc8d4` / `0x01e480ab` | RFQ admin helpers | `address(0)` since 2026-06-22 | **NO** |
| `0x240028e8` | `isSupportedToken(address)` → (bool, feed) | `0x88eb2800` | yes (view) |
| `0x2ba8d939` | `removeTokenSupport(address)` | `0x88eb2800` | yes, `Rfq: onlyOwner` for non-owner |
| `0x5d4d8fe7` | `isAllowedOrderSigner(address,address)` → bool (decompiled; live-verified: `[helper][attacker] == true` persists) | `0x88eb2800` | yes (view) |
| `0x5df4fd38` | `getOrderStatus(address,bytes32)` | `0x88eb2800` | yes (view) |
| `0x9227b794` | config getter → (nativeToken `0xeeee…`, WETH) | `0x88eb2800` | yes (view) |
| `0x8da5cb5b` | `owner()` → `0xBa5b79Ed…` | `0x88099Fcf` | yes (view) |
| `0xf2fde38b` | `transferOwnership(address)` | `0x88099Fcf` | yes, owner-gated |
| `0x261fe679` | `migrate(address,bytes,address)` | `0x88099Fcf` | yes, owner-gated |
| `0x6eb224cb` | `extend(bytes4,address)` (**re-register**) | `0x6831d0e0` | yes, owner-gated |
| `0x9db64a40` | `rollback(bytes4,address)` | `0x6831d0e0` | yes, owner-gated |
| `0xdfd00749` / `0x6ba6bbc2` | rollback-history views | `0x6831d0e0` | yes (view) |
| `0xe2a7c86f` / `0x1770400e` / `0x171a2517` / `0x78a9f28b` | `SailUniswapFeature` (custom 0x fork; pulls from `msg.sender`) | `0x51429f2e` | yes |
| `0x4d54cdb6` / `0x287b071b` / `0xf028e9be` / `0x87c96419` / `0x56ce180a` / `0x9f1ec78b` / `0x415565b0` / `0x8aa6539b` | TransformERC20 fork (quote-signer version; `_transformERC20` is `onlySelf`) | `0x1dfc3511` | yes |
| `0xf35b4733` / `0x77725df6` / `0x7a1eb1b9` / `0x5161b966` / `0x9a2967d2` / `0x0f3b31b2` | Multiplex (0x upstream fork; caller-sourced) | `0x1be28e78` | yes |
| `0x5b4a250f` | custom bridge router (Connext deprecated / Stargate / deBridge; pulls from `msg.sender`) | `0xc971d920` | yes |
| `0x972fdd26`, `0xfa461e33`, `0x0000006e/cf/f8` | native proxy functions (`getFunctionImplementation`, Uniswap V3 callback, internal handlers) | native | yes |

### 2.2 Controls

| Check | Result |
|---|---|
| `owner()` | `0xBa5b79EdBbAFf849F8e754B8d3C107a06fA2921a` — **EOA, no code, single key** |
| `extend` from a random EOA | reverts `Unauthorized(0x1de45ad1)` (fork-verified) |
| `rollback` / `migrate` / `transferOwnership` from random EOA | reverts `Unauthorized(0x1de45ad1)` |
| `removeTokenSupport` from random EOA | reverts `Rfq: onlyOwner` |
| `0x4112e1c2` from any caller | reverts `NotImplementedError(0x4112e1c2)` |
| `getFunctionImplementation(0x4112e1c2)` | `address(0)` |
| `isAllowedOrderSigner(helper, attacker)` | **`true`** — the attacker's June-2026 signer authorization persists in storage today (harmless while the selectors are unregistered, dangerous if they return) |
| Pause state | no pause mechanism reachable; not needed (drain selector is gone) |

### 2.3 Balances and approvals

| Check | Result |
|---|---|
| Proxy ETH / WETH / USDT / USDC / WBTC / DAI | 0 / 0 / 0 / 0 / 0 / 0 |
| Impl `0x88eb2800`, `0x88099Fcf`, `0x6831d0e0`, `0x51429f2e`, `0x1dfc3511`, `0x1be28e78`, `0xc971d920` | 0 ETH and **no token transfers ever** (Etherscan tokentx = 0 rows each) |
| Proxy token history | only 4 transfers ever (2024-11 → 2025-02), all dust |
| `Approval` events with spender = proxy | **90 events across 27 tokens** |
| Permit2 allowances (canonical Permit2 `0x000000000022D473030F116dDEE9F6B43aC78BA3`) to proxy/impls | **none** (0 Approval events; the RFQ flow used direct ERC-20 approvals) |
| Pairs with live allowance > 0 **and** balance > 0 | 14, total **$1.1531** (USDC 1.00 + 0.0968 + dust) |
| InventoryVault `0x9ba0cf15…` live allowances to proxy | **infinite (max)** for USDC, USDT, WETH, WBTC, DAI, PEPE, APE, AAVE, stETH, CRV, LDO, LINK, SHIB, POL, EIGEN, cbETH, cbBTC, ZRO, ENS, SPELL, OM, UNI … |
| InventoryVault current balances (real tokens) | **~0** (drained 2026-05-07; leftovers ≤ 1 wei). Remaining "balances" are spam-token dust. |

### 2.4 Sibling deployments

* Same addresses on Arbitrum / Base / Optimism / Polygon / BSC / Gnosis: **no code**.
* Deployer EOA `0xba5b79ed…`: contract creations only on Ethereum (13 contracts, Aug-2024 → Jan-2025);
  no txs on Arbitrum (checked); no evidence of cross-chain deployments of this code.
* Versions: four earlier RFQ impls (`0x51429f2e`→…→`0x626784d4`→`0x88eb2800`) all live only in this one
  proxy's registry. Orphaned deployments never registered anywhere (`0x83443928`, `0x5d5c3382`, `0xdd3191a4`,
  `0xceb107a8`, `0x3f39120e`, `0xaa5b04a3`) — unreachable through the proxy.
* The same custom features (`SailUniswapFeature`, bridge router, TransformERC20/Multiplex forks) are not
  registered on the canonical 0x Exchange Proxy except the upstream 0x ones (TransformERC20/Multiplex).

---

## 3. What an attacker can / cannot do — exact call paths

**Cannot:**
* Call the drain function: `0x4112e1c2` → `NotImplementedError` (no impl registered).
* Self-register a signer: `0xea7faa61` → `NotImplementedError`.
* Register any implementation: `extend(bytes4,address)` → `Unauthorized(msg.sender, owner)`.
* Change owner/migrate: owner-gated.
* Spend any third-party approval via a registered selector:
  * RFQ read/admin selectors: no `transferFrom` path (disassembled/decompiled: `isSupportedToken`,
    `getOrderStatus`, `isAllowedOrderSigner`, `9227b794`, `removeTokenSupport`).
  * `SailUniswapFeature`: all ERC-20 pulls are `transferFrom(caller, …)` or `transferFrom(this, …)`
    (tokens previously pulled from the caller) — decompiled evidence in `analysis/`.
  * TransformERC20 fork: `_transformERC20` is `onlySelf`; `transformERC20` spends the caller's own tokens.
  * Multiplex: caller-sourced (upstream 0x design).
  * Bridge router `0x5b4a250f`: helper calls pass `CALLER` as the transfer source; Connext path reverts
    `connext protocol is deprecated`.
* Take anything from the contracts themselves: balances are zero.

**Cost/preconditions:** none exist today; a would-be attacker's only path is to convince the owner EOA to
re-register the selector (a privileged action), after which the historical exploit repeats for free
(no capital, no flash loan — gas only).

**Fork-verified call results (see `poc/`):**

| Call | Result |
|---|---|
| `PROXY.call(0x4112e1c2 …)` at latest | revert `NotImplementedError(0x4112e1c2)` |
| `extend/rollback/migrate/transferOwnership` from `0x1111…` | revert `Unauthorized(0x1de45ad1)` |
| `removeTokenSupport(USDC)` from `0x1111…` | revert `Rfq: onlyOwner` |
| `_transformERC20(taker=vault)` from `0x1111…` with vault funded 10k USDC | reverts; vault balance unchanged |
| `0x5b4a250f(protocol=1,…)` | revert `connext protocol is deprecated` |
| **Historical replay at block 25,039,669** | four original drain blobs execute; vault loses 1,291.16 WETH + 206,282.45 USDT + 16.9391 WBTC + 1,268,771.49 USDC |

---

## 4. PoC / fork verification

`poc/test/TrustedVolumesC25.t.sol` — Foundry suite, mainnet forks, `FORK_RPC_URL` (archive for the
historical test via `NODEREAL_ETH_RPC_URL`). Tests:

1. `test_current_drainSelectorUnregistered` — registry is 0 for both exploit selectors; drain calldata reverts `NotImplementedError`.
2. `test_current_adminOwnerGated` — every registry/owner function reverts for a random EOA; `owner()` unchanged.
3. `test_current_residualApprovalsAndBalances` — vault approvals still infinite; balances dust; drain still reverts; contracts hold nothing.
4. `test_historical_exploitReplay` — pre-exploit fork (block 25,039,669); helper self-registers; the four
   verbatim exploit calldata blobs drain the vault; asserts the four asset deltas (≈ $5.87M).
5. `test_latent_ownerReRegister_reenablesPrimitive` — re-`extend(0xea7faa61, 0x88eb2800)` as owner makes
   self-service signer registration succeed again for any caller (latent-risk proof).
6. `test_latent_transformERC20_onlySelf` — funded vault + attacker `_transformERC20` cannot move vault funds.
7. `test_latent_bridgeFeature_connextDeprecated` — bridge feature reachable but Connext path dead.

CI runs (workflow `poc.yml` of `kingmariano/ca-zombie-ci`):

* Run 1 (expectation bugs in tests 1/3/4; 2 passed): https://github.com/kingmariano/ca-zombie-ci/actions/runs/37092108674
* Run 2 (final, all tests): see `summary.json` → `poc.ci_run_urls` / `ci-log.txt`
* Custom heavy job `ci/run.sh` decompiled the unverified impls (panoramix) and ran a static token-pull scan;
  outputs in `ci-artifacts/` and copied to `analysis/` (impl_A = `SailUniswapFeature`, impl_D = bridge router,
  registry/owner features, RFQ feature).

---

## 5. Verdict and residual / latent risk

**E-U = $0.00 (high confidence).** The exploit path is closed by registry state, not by balance exhaustion:
the team's June-22 rollback removed the vulnerable selectors, and every remaining selector is read-only,
owner-gated, or sources tokens from `msg.sender`. The proxy and all implementations are empty.

* **P (privileged):** the owner EOA can re-register the drain selector at any time (`extend`), instantly
  re-enabling the primitive. This is not extractable by an unprivileged attacker but is a single-key risk.
* **Latent standing authority (the real residual risk):** the InventoryVault still grants the proxy
  **unlimited allowances** on ~20 tokens. If the protocol ever refills that vault (it is the same vault the
  team still controls) **and** re-registers the RFQ selectors, the entire balance is drainable by anyone in
  one transaction. Recommendation: `approve(proxy, 0)` from the vault for all tokens, or transfer the
  vault's holdings and abandon it.
* **S (stuck):** none. **H-O:** none (no user-facing claim path in this system).
* **Partial recovery (context, not extractable):** public reporting (NewsBTC, 2026-07-18) says the attacker
  returned 1,122 ETH (~$2M) keeping ~$2M as a bounty; on-chain, 1,122.11586 ETH moved between
  attacker-linked wallets on 2026-07-17 (tx `0x2406411a…`) and onward; the team-side recovery flow was not
  fully reconstructed. Fireblocks' "~85 transactions / $6.7M" refers to the attacker's cash-out/movement
  trail; the drain itself was a single tx with 4 fills.

**What would change the verdict:** any new `extend(bytes4,address)` from the owner registering
`0x4112e1c2`/`0xea7faa61` (watch the registry event topic `0x2ae22108…`), or new deposits into the
InventoryVault while approvals remain. Both are monitorable with a single `getFunctionImplementation` call
and `Approval`/transfer watch.

---

## 6. Methodology & sources

* On-chain reads: Ethereum RPC (`eth_getCode`, `eth_getStorageAt`, `eth_call`, `debug`-less), Etherscan V2
  (`getsourcecode`, `getcontractcreation`, `txlist`, `tokentx`, `getLogs`), GoldRush (balances/approvals),
  DefiLlama prices. Exact blocks: registry replay/approvals at 26,108,8xx; CI fork at 26,109,04x.
* Unverified code: runtime bytecode disassembly + `panoramix` decompilation (CI) + selective selector
  extraction; `getFunctionImplementation` registry replay (55 events, 0 mismatches).
* Exploit evidence: darknavy trace artifacts (verbatim drain calldata, funds flow), Verichains analysis
  (three-bug chain), rekt.news, QuillAudits, Fireblocks Q2-2026 report, NewsBTC partial-return report.
* The corpus entry (FINDINGS.md C-25) was re-verified; the resolver is the victim vault `0x9ba0cf15…`, not
  a user-facing escrow.

**Caveats / limitations**

* The RFQ implementation `0x88eb2800` remains unverified; its reconstructed logic is inferred from the
  trace + decompilation (medium confidence on exact arg order, high confidence on the auth/source split).
* The "no registered selector can move third-party approvals" conclusion rests on decompiled bytecode of
  unverified contracts (SailUniswapFeature/bridge/TransformERC20/Multiplex forks). It is corroborated by
  the fork tests and by upstream 0x source for the forked features, but is not a formal proof.
* Cross-chain clone deployments at *different addresses* cannot be excluded with certainty; direct address
  checks on six major chains found nothing, and the deployer shows no cross-chain activity.
* The $1.15 dust ceiling uses DefiLlama prices at work time; token prices move.

## 7. Files index

```
c-25/
├── README.md                     (this file)
├── summary.json
├── analysis/
│   ├── state.json                proxy/impl code, EIP-1967 slots (zero), balances
│   ├── registry_replay.json      all 55 registry events + final selector→impl map
│   ├── function_impl_registry.json  live getFunctionImplementation() for 37 selectors
│   ├── selector_registry.json    registered/unregistered classification per selector
│   ├── approvals_spender_proxy.json  90 Approval events, 27 tokens
│   ├── approvals_current.json    current allowance + balance per (token, owner)
│   ├── approval_dust_valuation.json  $1.1531 live-approval ceiling
│   ├── exploit_calldata.json     4 verbatim drain blobs + register call
│   ├── proxy.hex / impl*.hex     runtime bytecode of proxy + 8 impls
│   ├── darknavy/                 exploit tx artifacts (trace, funds flow, recovered.sol)
│   ├── disasm.py / dispatch_scan.py / probe.py / getimpl.py …  analysis scripts
│   └── implA_decomp.txt, decompiled outputs (also in ci-artifacts/)
├── poc/                          Foundry project (vendored forge-std) — 7 fork tests
├── ci/run.sh                     heavy CI job: decompile + static scan
├── ci-out/                       job outputs (code, decompiled .sol, reports)
├── ci-artifacts/                 downloaded CI artifacts
└── ci-log.txt                    full CI log
```
