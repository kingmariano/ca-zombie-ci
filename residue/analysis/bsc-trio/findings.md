# H2-03 BSC trio — SKYDAO controller · FIST · MSN — live extractability determination

**Date:** 2026-10-10 (UTC) · **Chain:** BSC (chain id 56)
**Status:** read-only; no mainnet transactions sent or signed. All behavioural tests ran on a **local anvil fork** (fork RPC read-only); no keys used.
**Author:** H2-03 child subagent (bsc-trio)
**Scope note:** this file covers only the three BSC residue items assigned to this subagent. Work products live in `residue/analysis/bsc-trio/` (`findings.md`, `evidence.json`, `sources.md`, `raw/`, `logs/`).

---

## TL;DR

| # | Target | Address | Live USDT (verified) | E-U now | Class | Why | Confidence |
|---|---|---|---|---|---|---|---|
| 1 | SKYDAO controller (post-exploit residue) | `0xEe5fDff6364dDe0A3C66dD38A4303cDd3D10730c` | **29,774.225000 USDT** ≈ $29,752.57 | **$0.00** | **S** (no mover found for anyone; owner side unproven) | Only `sellToken`/`register` move USDT; both are gated to the token / config contracts and distribute **freshly-deposited or just-swapped flow** to **fixed config addresses**, never the contract balance. Sells are bricked today (controlburn needs 2×amount SKYDAO from a pair that holds 1 wei). 43/43 public selectors probed from a fresh EOA → zero USDT movement. | E-U $0: **high** · whole-fund: **medium-high** |
| 2 | FIST token contract | `0xc9882def23bc42d53895b8361d0b1edc7570bc6a` | **152,672.621511 USDT** ≈ $152,561.57 | **$0.00** | **S** (stuck) | `FistStandard` = plain BEP20 + Ownable, **zero external calls**, no USDT interface, no rescue/withdraw; bytecode contains no USDT address constant; `owner()` renounced (`0x0`). Nobody (not even an owner — there is none) can move it. | **high** |
| 3 | MSN token contract | `0xd8b3ef86afce18edba91fed481abe22f173597c1` | **3,762.282749 USDT** ≈ $3,759.55 | **$0.00** | **S** (stuck) | `MSNToken` verified source: no USDT interface, no generic call, no rescue; child `LPBonus` handles FIST only; `owner()` renounced (`0x0`). USDT history is 13 incoming legs from EOAs, 0 outgoing. | **high** |

**Total live extractable by an external unprivileged attacker across the three items: $0.00 (high confidence).**
**Total nominal value examined: 186,209.129261 USDT ≈ $186,073.68 — all classified stuck (S), none attacker-extractable.**

USDT price used: **$0.9992725850746348** (DefiLlama `coins.llama.fi`, BSC USDT `0x55d398…7955`, ts 1791638276, confidence 0.99).

Latest balance-read block: **126,834,398** (also pinned at 126,828,153 and 126,833,981 during the work; all reads agree). Fork used for tests: anvil fork pinned at block 126,832,930–126,832,934 (state reads only).

---

## 1. SKYDAO controller — `0xEe5fDff6364dDe0A3C66dD38A4303cDd3D10730c`

### 1.1 What this contract is

SKYDAO (`0x7eBa33c7a0e555D115277BA4Af04DFbB4F4Fa70c`, verified, symbol `SKYDAO`) is a BSC token with a 35 % sell tax whose `_transfer` calls a **pool controller** contract every time a sale hits the PancakeSwap V2 pair (`IPancakeFactory(results[8]).sellToken(amount,_swapLock)` where `results = config.getAllConfig()`).

The controller was exploited on **2026-09-30** (block 124,921,242, tx `0x8e3016674ea8e5d2ad3af422ae5328f5a1f448e6b5a93d5d773e358bd2e440eb`): 183,482.88 USDT left the SKYDAO/USDT pair; the attacker (0x5C92…6EBC) kept ~59,914 USDT. The controller **retains 29,774.225 USDT residue today** (the lead figure is confirmed exactly).

| Role | Address | Evidence |
|---|---|---|
| Token | `0x7eBa33c7a0e555D115277BA4Af04DFbB4F4Fa70c` | verified source (`SKYDAO`); `config()` → config |
| Config contract (unverified) | `0x85870c50677c142f5e37930915d8984cce7623e1` | `getAllConfig()` returns 27 addresses (saved `raw/config_getAllConfig_126828153.json`, `raw/config_array.json`) |
| Controller (`results[8]`) | `0xEe5fDff6364dDe0A3C66dD38A4303cDd3D10730c` | config[8]; holds the USDT |
| SKYDAO/USDT pair (`results[16]`) | `0x096e08ddA1E18625fFdfBae4BB65a414Aa7eC2c8` | config[16]; reserves 21.813338 USDT / 1 wei SKYDAO |
| USDT | `0x55d398326f99059fF775485246999027B3197955` | config[12] |
| Owner (controller) | `0x6390ef00953dd0e0c5b15c50b28da36c2944d5d9` | `owner()` call |
| Owner delegate (EIP-7702) | `0x63c0c19a282a1b52b07dd5a65b58948a07dae32b` | owner's account code = `0xef0100…` designator; delegate verified as MetaMask **`EIP7702StatelessDeleGator`** |
| `results[25]` (secondary sellToken caller) | `0xa210a12e4417ce53b3cd745e865e62b361d0796d` | contract (7,810-byte code), holds 2.9 B SKYDAO |
| `results[20]` (releaseToken caller) | `0xffa467ebb29be842b0898e7dccbb1a70a9cf2672` | caller-gate test |

### 1.2 Live balance (raw proof)

```
USDT.balanceOf(0xEe5fDff6364dDe0A3C66dD38A4303cDd3D10730c)
  block 126,828,153 : 0x…064e10606ee522ee8124 = 29,774.225000000000000292
  block 126,834,398 : 29,774.225000000000000292  (raw 29774225000000000000292)
GoldRush archive read (balances_v2, block-height 124,932,859 = 2026-09-30 15:30 UTC):
  USDT = 29,774.225000  → residue present immediately after the last protocol activity and unchanged to-date
```

The GoldRush USDT transfer history of the controller (1,002 txs spanning Aug 19 – Sep 30; `raw/gr_ctrl_p0.json`, `raw/gr_ctrl_p1.json`, `raw/controller_usdt_ledger.json`) shows the newest USDT movement involving the controller at block **124,932,859** (2026-09-30 15:30:38 UTC). The residue has been **static for ~10 days** at the time of writing. (The ledger parse is imperfect — its running balance ends at 12,652.375 USDT vs the true 29,774.225, i.e., some legs are not captured by the API — which is why the archive balance read at block 124,932,859 is the authoritative check and confirms the residue already existed then.)

### 1.3 What the controller can actually do with USDT (full reverse-engineering)

The controller is **unverified** (40,298-hex-byte runtime). It was fully enumerated by disassembly (`raw/controller_0xEe5f_disasm.txt`), decompilation cross-checks (heimdall, `raw/heimdall_controller2/`), a config-index map, a call-graph of all **26 `USDT.transfer` (a9059cbb) call sites**, and behavioural probes on an anvil fork.

**Dispatcher:** exactly 43 public selectors (`cast disassemble` → PUSH4 dispatch chain), all accounted for (`raw/sel2body.json`).

**USDT transfer sites (26) map to exactly two public entry points:**

1. **`sellToken(uint256,bool)` (`0x473a9ad9`)** — caller gate (verified empirically + in disasm): `msg.sender == config[1]` (the SKYDAO token) **OR** `msg.sender == config[25]` (`0xa210a12e…`). From a random EOA it reverts with no data; from the token it proceeds to the Uniswap library (revert with `PancakeLibrary: INSUFFICIENT_INPUT_AMOUNT` for zero amounts). It takes the tax tokens received from the sale, swaps `35 %·arg0` for USDT via the Pancake router (`0x10ED43C7…`, `swapExactTokensForTokens`), and distributes the swap output to **six fixed config addresses** with weights out of 35: `[16]` pair 15/35, `[6]` `0x8e97f479…` 10/35, `[14]` `0x34d36a5c…` 3/35, `[21]` `0xdebb963f…` 3/35, `[19]` `0x6c526c40…` 2/35, `[4]` `0x9f9785aa…` 2/35. It then calls `token.controlburn(2×arg0)` (selector `0xa94485a3`, input decoded from trace = `4000e18` for `arg0=2000e18`) and `pair.sync()`.
   - **The amounts are derived from the fresh swap output, not from `balanceOf(controller)`**: in every distribution transaction observed, the USDT outflow equals the fresh inflow, while the standing balance (which grew to 29,774 USDT) was never distributed. Example: tx `0xb0558d…` (block 124,932,859) moved 0.126642 USDT total out of a contract holding ~29.7k. Across the whole observation window no transaction ever drained a balance-sized amount.
   - **Sells are currently bricked:** `controlburn(2×arg0)` moves SKYDAO from the pair to `0xdEaD`; the pair holds **1 wei SKYDAO**, so the call succeeds only if `pair_sky + 0.35·A ≥ 2A` ⇔ `A ≤ 0.6 wei`. For any economically meaningful A the sell reverts (fork trace `raw/probe_full_results.json`, tx `0xba50bc…` reverted at `token.controlburn`); `A=0` reverts earlier in the router. The pair is also unbuyable (amountOut rounds to 0 wei for a 1-wei reserve). Net: no sell can complete → `sellToken` cannot even be triggered from the token path today.

2. **`register(address,uint256)` (`0x6d705ebb`)** — caller gate: `msg.sender == config[1]` (token). Triggered by `token.register(uint256)` (`0xf207564e`), which first pulls the user's **own** USDT deposit into the controller (`USDT.transferFrom(user → controller)`) and then calls `controller.register(user, amount)`. Distribution (decoded from a fork trace of a 100 USDT deposit): 5 % → `[5]` `0x41132d84…`, 3 % → `[14]`, 2 % → `[15]` `0xa7c972e6…`, 2 % → `[4]`, 0.5 % → `[19]`, **65 % → pair `[16]`**, remainder retained by the controller; plus `token.mintToken(pair, …)`, `pair.sync()` and a final `token.transfer(referrer, …)`. Deposit-based percentages — **never the standing balance**. In the fork test the flow reverted at the final `token.transfer` (`amount = 0`, token requires `amount > 0`) because the attacker has no referrer, which is also why the controller's residue accumulated (retained portions of past registrations, not distributable by re-triggering).

**Everything else:** (a) plain views/accounting; (b) owner-gated functions. Function-level caller-gate matrix (fork, `raw/gate_matrix.json`): `0e35201b` → cfg[4] only; `updateUserLevel` → cfg[19] only; `releaseToken` → cfg[20] only (currently reverts inside the token with “Transfer amount must be greater than zero”); `register`/`sellToken` → token (sellToken also cfg[25]); `87d8d643`, `53fe7d7e`, `f4c6aa92`, `fa302aec`, `714e4b9b` → owner only (“Ownable: caller is not the owner” for everyone else); `df526413`, `6f016bc8`, `2c4e3db0` → callable by anyone but pure accounting/queries (return 0/`0x0`, **zero USDT movement** in all tests).

**Exhaustive fork probe (local anvil, all 43 selectors, fresh EOA caller):** no call succeeded that moved any USDT to the caller or anywhere else; the only successes were views/accounting (`raw/probe_full_results.json`, `raw/controller_callgraph.json`).

### 1.4 Owner side

- The controller owner is an **EOA `0x6390ef00…`** whose account has an EIP-7702 delegation designator (`0xef0100…63c0…`) pointing at `0x63c0c19a282a1b52b07dd5a65b58948a07dae32b` — **verified** as the MetaMask **`EIP7702StatelessDeleGator`**. All its raw execution entry points are gated: `execute(...)` on `onlyEntryPointOrSelf`, `executeFromExecutor(...)` on `onlyDelegationManager`. **No third party can act as the owner** through the delegate without an EIP-712 delegation signed by the owner EOA (none observed).
- Owner-only functions were exercised **on the fork as the owner**: `fa302aec` (array-shaped calldata; several shapes execute, status 1), `f4c6aa92(A,0)`, `53fe7d7e(0,1)`, `87d8d643()` — **all moved 0 USDT** (controller balance unchanged at 29,774.225 after each). No owner-reachable USDT transfer site exists other than `sellToken`/`register` (both token-gated).
- USDT allowances from the controller: `allowance(controller → Pancake router) = 0`, `→ pair = 0`, `→ FstSwap router = 0` (block 126,834,398).
- **Conclusion:** no demonstrated path for the owner either. If the project still controls `0x6390ef00…`, in principle the owner could operate protocol functions, but nothing tested (and no code path identified) moves the residue. The honest classification of the whole 29,774.225 USDT is **S (stuck / no mover demonstrated)**, with the caveat that an owner-side operational path not covered by the selector set is impossible (selector set is complete) — the only residual uncertainty is semantic (e.g., `fa302aec` reaching its USDT loop under states we could not construct), hence medium-high rather than absolute confidence.

### 1.5 Attacker call-path attempts (summary of the proof of $0)

| Attempt | Result |
|---|---|
| `sellToken` from random EOA / owner / config[0] | revert (no data) |
| `sellToken` from token, 35 SKYDAO, status 0/1 | proceeds past gate, reverts in router/controlburn (bricked flow) |
| `sellToken` from token with controller pre-funded 10,000 SKYDAO, arg0=2,000 | full flow executes to swap + USDT transfer, then reverts at `token.controlburn(4000e18)` (pair has 700 SKYDAO + 1 wei) — **residue untouched in every variant** |
| `register` via `token.register(100 USDT)` (attacker deposits) | reverts at final referrer transfer; USDT distributions it did attempt are fixed-percentage of the 100 deposit (5/3/2/2/0.5 % + 65 % to pair); **residue untouched** |
| All 43 selectors from fresh EOA | no USDT movement (0 balance deltas) |
| Owner functions (fa302aec/f4c6aa92/53fe7d7e/87d8d643) as owner | 0 USDT movement |
| Steal via USDT allowance | allowances are 0; no approved spender besides transient router approvals (reset each swap) |
| EIP-7702 delegate abuse | gated by EntryPoint/self/DelegationManager; no delegation signed |

**What would change the verdict:** (a) any mainnet tx from `0x6390ef00…` calling the controller and moving USDT — would reclassify from S to P (and start from a state change, not possible read-only); (b) SKYDAO liquidity revival making sells possible — even then `sellToken` distributes only new swap flow to fixed addresses, so the residue stays S unless an internal path we priced as flow-based turns out balance-based (contradicted by 1,000+ historical txs); (c) discovery of a USDT transfer site reachable from a public function outside our 26-site set (disassembly says there are none — every `PUSH4 0xa9059cbb` occurrence was mapped).

---

## 2. FIST — `0xc9882def23bc42d53895b8361d0b1edc7570bc6a`

- **Identity:** `FistToken` / symbol `FIST`, 6 decimals, totalSupply 200,000,000,000,000 (raw 2e14), verified source (`FistStandard`, Solidity 0.5.16). FstSwap ecosystem token (factory `0x9A272d…6dce`, router `0x1b6c9c…2d`).
- **USDT balance (raw):**
  ```
  USDT.balanceOf(0xc9882def…0bc6a)
    block 126,833,981 : 152,672.621511870269780419  (raw 152672621511870269780419)
    block 126,834,398 : 152,672.621511870269780419
  ```
- **Code audit (verified source read in full):** the contract is a pure BEP20 + Ownable: `transfer/transferFrom/approve/allowance/balanceOf/decimals/symbol/name/totalSupply/increaseAllowance/decreaseAllowance/owner/getOwner/renounceOwnership/transferOwnership`. There are **no external calls of any kind** (no IERC20 imports, no USDT interface, no router/pair interaction), **no rescue/withdraw/sweep**, no fallback, no delegatecall, no selfdestruct, no mint. Bytecode selector scan matches the ABI exactly — no hidden selectors (`raw/0xc9882def…_code.txt`, disasm).
- **Bytecode contains no USDT address constant** (grep for `55d398326f99059ff775485246999027b3197955` in the deployed code = 0 matches). The contract literally cannot call USDT.
- **Owner:** `owner()` = `0x0000000000000000000000000000000000000000` — ownership renounced; even the two owner functions (transferOwnership/renounce) are dead.
- **USDT history:** the GoldRush/Covalent `transfers_v2` endpoint returned empty payloads for this address on repeated attempts, and Etherscan V2 free tier does not cover BSC logs/token transfers, so the inflow history could not be enumerated; it is immaterial — no outgoing transfer is possible from the contract (code proof above).
- **Classification: S (stuck / bricked).** 152,672.621511 USDT ≈ **$152,561.57** is unreachable by anyone (attacker, owner — there is none, users). **E-U $0 (high).**
- **What would change the verdict:** nothing short of a protocol-level intervention (e.g., the BSC-USD issuer minting/burning or a hard-fork state change). The contract is not upgradeable; no function can move USDT.

---

## 3. MSN — `0xd8b3ef86afce18edba91fed481abe22f173597c1`

- **Identity:** `MSNToken` / symbol `MSN`, 18 decimals, totalSupply 5,000e18, verified source (multi-file: `MSNToken.sol` + child `LPBonus`). FstSwap ecosystem (constructor takes `_Fist` = FIST token; creates pairs on Pancake factory `0xcA143Ce3…` and FstSwap factory `0x9A272d…`).
- **USDT balance (raw):**
  ```
  USDT.balanceOf(0xd8b3ef86…97c1)
    block 126,833,981 : 3,762.282749482632647712  (raw 3762282749482632647712)
    block 126,834,398 : 3,762.282749482632647712
  ```
  This matches the lead's "3,762 USDT held by the token contract" exactly.
- **USDT history (GoldRush `transfers_v2`, full):** 13 legs, **13 IN / 0 OUT**, all plain transfers from unrelated EOAs, sum = the current balance:
  2,000.0 (0x2e1b…def9), 415.325646 (0x3fb0…7de4), 207.792051 (0xf615…069d), 200.0 (0xeb2d…a0bb), 196.785915 (0xb702…0eab), 174.657675 (0x3112…2e77), 140.145899 (0x1481…db70), 118.232475 (0x5051…0152), 113.420782 (0x6dcb…bd36), 91.046389 (0xf32a…87bf), 86.87 (0x9706…5f45), 67.529015 (0xdeb7…2df1), 50.476902 (0xfa3b…73ea). Signature of users sending USDT to the token contract address by mistake; no outgoing transfer ever.
- **Code audit (verified source read in full):**
  - `MSNToken` interacts only with: Pancake/FstSwap factories (`createPair`), the FstSwap pair (`getReserves`), the FIST token (`balanceOf`), and its `LPBonus` child (`cutter`). **There is no USDT interface, no IUSDT/IERC20-generic call, no rescue/withdraw/sweep, no low-level call, no fallback.** Bytecode contains **no USDT address constant** (grep = 0 matches); it contains the Pancake **router** constant only for the child `LPBonus`'s MSN→FIST swap.
  - `LPBonus` child (deployed by permissionless `createLPBonus()` once) manipulates **FIST only** (`IBEP20(fist).transfer`, router swaps MSN→FIST). It can never touch USDT.
  - Owner: `owner()` = `0x0000000000000000000000000000000000000000` (renounced) → `OpenAddLiquidity/CreatePair/setWhiteList/setStartTradeTime/setNoTradeLp` are permanently dead; the permissionless functions left (`transfer`, `transferFrom`, `approve`, `burn`, `burnFrom`, `createLPBonus`) cannot move USDT (code proof).
- **Classification: S (stuck / bricked).** 3,762.282749 USDT ≈ **$3,759.55** unreachable by anyone. **E-U $0 (high).**
- **What would change the verdict:** nothing available on-chain; non-upgradeable contract with no USDT code path.

### 3.1 Out-of-scope sibling observation (same "MSN" ticker, different contract)

`0xaf51951df5782fa6eb529c173b10a973e4871f92` (different `MSN`, verified 48 KB source) holds **6,297.097599 USDT** (block 126,834,398). It has `rescueToken(address,uint256)` **onlyOwner** and `donateDust(address,uint256)` **onlyDever**. Its `owner()` is `0x0` (renounced) so `rescueToken` is dead; `_dever` is a private deployer address with no getter/setter (set to `msg.sender` in the constructor), so `donateDust` is at most **P** (deployer-privileged). Not part of this task's three items; recorded for the parent's awareness. E-U: nothing found.

---

## 4. Consolidated numbers

| Item | Amount (USDT) | USD (@0.9992726) | E-U | P | H-O | S |
|---|---|---|---|---|---|---|
| SKYDAO controller `0xEe5fDff6…` | 29,774.225000 | $29,752.57 | $0 | $0 (no path proven) | $0 | **$29,752.57** |
| FIST `0xc9882def…` | 152,672.621511 | $152,561.57 | $0 | $0 (owner renounced) | $0 | **$152,561.57** |
| MSN `0xd8b3ef86…` | 3,762.282749 | $3,759.55 | $0 | $0 (owner renounced) | $0 | **$3,759.55** |
| **Total** | **186,209.129261** | **$186,073.68** | **$0** | $0 | $0 | **$186,073.68** |

## 5. Method & limitations

- All mainnet interactions were `eth_call`/`eth_getCode`/`eth_getBalance` reads plus Covalent-GoldRush/DefiLlama/Etherscan-V2 HTTP reads (no signing, no `eth_sendRawTransaction` anywhere).
- Behavioural verification ran on a **local anvil fork** of BSC (state read-only from the fork RPC); local impersonation (`--auto-impersonate`) was used to exercise gated callers, and all resulting state existed only in the local fork. Transaction traces (`debug_traceTransaction`) were used to decode call arguments and revert locations.
- Unverified controller contract: analysed via disassembly (`cast disassemble`), heimdall decompilation cross-checks, PUSH4 selector enumeration (43/43 mapped to the dispatch table), config-array index mapping, a 26-transfer-site call graph, and fork behaviour. This is a best-effort static+dynamic analysis; residual risk is limited to decompiler-level misreads, mitigated by the empirical probes and historical flow data.
- Confidences: E-U $0 for all three = **high**. "Nobody can move" for FIST/MSN = **high** (complete source, no external calls, renounced owners). "Nobody can move" for SKYDAO = **medium-high** (no mover found; owner-side semantic gap noted).
- **What would change the verdicts:** any future tx from the SKYDAO owner EOA moving controller USDT (S→P); protocol-level intervention on BSC-USD for FIST/MSN (not reasonably possible); impossible otherwise.

## 6. Files

- `findings.md` — this document
- `evidence.json` — machine-readable evidence (addresses, raw balances, blocks, verdicts, key calls/traces)
- `sources.md` — URLs/sources
- `raw/` — bytecode, disassembly, decompilations, config arrays, transfer ledgers, fork probe results, traces (`probe_full_results.json`, `gate_matrix.json`, `controller_callgraph.json`, `sel2body.json`, `controller_usdt_ledger.json`, `final_balances.json`, …)
- `probe_controller.py`, `probe_full.py` — fork probe scripts (no secrets; read keys from env when needed)
- `logs/` — local tool logs (no secrets)
