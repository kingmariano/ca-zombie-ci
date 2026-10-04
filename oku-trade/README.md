# H-34 — Oku Trade (Sonic + Scroll / Linea / Manta / Boba): live-state assessment & extractable-value determination

**Campaign:** zombie-hunt · **Chains:** Sonic (146), Scroll (534352), Linea (59144), Manta (169), Boba (288)
**Date of work:** 2026-10-04 · **Status:** read-only research; fork-verified PoC only; **no mainnet transactions sent**
**Scope:** H-34 in `zombie_hunt/FINDINGS.md` ("Oku Trade (Sonic) — Uniswap-V3 fork stack, $41K sampled, audit unknown; verify own contracts vs Uniswap core"). Extended per mission to all Oku-flagged deployments (Sonic/Scroll/Linea/Manta/Boba) and every Oku-authored contract on them.

---

## 1. TL;DR

**An external, unprivileged attacker can extract ≈ $0 from Oku Trade's deployments today.** On Sonic — the H-34 headline chain — Oku has **no router at all** and its only own contract (a `LimitOrderRegistry`) is an **empty, never-used deployment** (zero orders, zero balances, zero LP positions); the Uniswap v3 stack Oku's front-end uses there is **byte-for-byte stock Uniswap v3** (metadata-verified against Ethereum canonical). On Scroll/Linea/Boba, Oku's own `OkuRouter v2.0` has the **backend warrant-signature check disabled by design** (`validSigners[address(0)] == true`), but even with that bypass the router only ever moves **caller-supplied funds** and pays the caller — a fork test proves a victim's standing 100 WETH approval to the router cannot be pulled by a third party. The residual funds found (~$30 user-serviceable, ~$62 owner-sweepable) are in Oku's old `LimitOrderRegistry` contracts, not extractable by outsiders.

| # | Target (chain) | Live extractable (unprivileged) | Why closed/open | Latent risk |
|---|---|---|---|---|
| 1 | OkuRouter v2.0 `0xb1f3…` (Scroll) | **$0** | **No swap target has ever been whitelisted** (zero `SwapTargetAdded` events); every swap reverts `TARGET_NOT_AUTH`; 0 balance | If targets are added, the zero-signer bypass (below) re-enables unauthenticated swaps |
| 2 | OkuRouter v2.0 `0xb1f3…` (Linea) | **$0** | Live + 15 whitelisted aggregators, but warrant-bypass calls still pull only from `msg.sender` and pay `msg.sender`; router holds 0.000096 ETH, 0 WETH; fork-proven that third-party approvals are unreachable | `validSigners[address(0)] == true` → backend authorization is off-chain-only; fee-free/unauthorized routing possible; becomes extractive if any whitelisted target is ever abused or holds funds |
| 3 | OkuRouter v2.0 `0x7bf7…` (Boba) | **$0** | Same architecture; router holds 0.00030 ETH dust; only icecreamswap + Uniswap UR/SR02 whitelisted | Same as #2 |
| 4 | LimitOrderRegistry `0xeC3E…` (Scroll) | **$0** | Shutdown; 111 positions but only 3 non-empty residual orders (~21 USDC nominal), cancelable **only by their depositors** (fork-tested: third-party cancel/claim reverts) | Owner can sweep WETH/native only (0 here) |
| 5 | LimitOrderRegistry `0x63c8…` (Linea) | **$0** | Shutdown; 48 positions all empty; 0 WETH/native | none measured |
| 6 | LimitOrderRegistry `0x1b35…` (Sonic) | **$0** | **Never used**: `batchCount == 1` (no order ever created), 0 positions, 0 balances; same code as the audited Linea LOR (metadata-equal) | none measured |
| 7 | LimitOrderRegistry `0xfEFb…` (Boba) | **$0** | 25 positions all empty; only 0.0225 ETH + 0.000304 WETH dust (owner-sweepable claim fees) | owner-only |
| 8 | LimitOrderRegistry `0xFE83…` (Manta) | **$0** | Shutdown 2026-08-24; 10 positions all empty; residual 62.35 MANTA + 4.86 USDC are unclaimed outputs (claim path open) | owner can sweep only recorded swap fees (0.0508 USDC) |
| 9 | Uniswap v3 stack (Sonic, all of it) | **$0** | Stock Uniswap v3 core/periphery (verified source + canonical metadata/bytecode); pools are LP-owned | none (standard protocol risk only) |

**Total live extractable now (E-U): $0.00.** Confidence: **high** (fork-verified negative result on every Oku-authored contract; the only "bug" found — the disabled warrant check — was proven non-extractive end-to-end).
**User-serviceable (H-O): ≈ $30.4** · **Owner/privileged (P): ≈ $62.5** · **Stuck (S): ≈ $0 measured.**

---

## 2. What Oku actually deploys (own contracts vs stock Uniswap core)

Oku Trade is GFX Labs' Uniswap-v3 front-end/aggregator. Two families of Oku-authored contracts exist:

| Contract | Repo | Deployed on (this scope) | Notes |
|---|---|---|---|
| `OkuRouter` v2.0 + `BaseAggregator` | `github.com/oku-trade/oku-router` (audits: Jan-2026, Jul-2026 PDFs in repo) | Scroll `0xb1f3a7B816B0681188F54dFa400991B93ADf00ed`, Linea (same addr), Boba `0x7bf7770Ecd4fd573C32272Ef80c8818A8E8e289A` | Aggregator intermediary: pulls user tokens, approves a whitelisted aggregator, forwards signed calldata, returns output. Owner = 2-of-3 Safe `0x37333A9626E99eC2012F3cC47a062649CF741303`. **Not deployed on Sonic** (config exists; `deployments/` has no `sonic.json`; code absent at the deterministic address). |
| `LimitOrderRegistry` | `github.com/gfx-labs/uniswap-v3-limit-orders` (audited; on-chain source matches repo HEAD exactly on Linea) | Sonic `0x1b35fbA9357fD9bda7ed0429C8BbAbe1e8CC88fc`, Scroll `0xeC3E5eeC51D8C3D4f03DABB84B4Db313a739f377`, Linea `0x63c8527F670d4eb3401c80C5905cECa8727F1E74`, Manta `0xFE83E1DDa189D71093f2a716A4D01d591d6Ca66C`, Boba `0xfEFb60591cffc694C0137983a9091D64Af8Ecbac` | Chainlink-Automation range-limit-order book; custody of LP NFTs + claim payouts. |
| `Permit2Proxy` | oku-router repo | **World Chain only** — not in scope | — |
| Advanced orders (`Bracket`/`StopLimit`/`OracleLess`/`AutomationMaster`) | `gfx-labs/oku-custom-order-types` | **None of the five chains** (addresses only on OP-stack chains; `@gfxlabs/oku-chains` defines no advanced contracts for Sonic/Scroll/Linea/Manta/Boba) | — |

Everything else on these chains is **stock Uniswap v3** deployed by GFX Labs / chain foundations and listed on the Uniswap governance "Official v3 deployments" page. Verified on-chain:

| Sonic contract | Address | Verification result |
|---|---|---|
| UniswapV3Factory | `0xcb2436774C3e191c85056d248EF4260ce5f27A9D` | Explorer source = `UniswapV3Factory` (solc 0.7.6); `getPool` works |
| NonfungiblePositionManager | `0x743E03cceB4af2efA3CC76838f6E8B50B63F184c` | verified `NonfungiblePositionManager`; runtime metadata == Ethereum canonical NFPM |
| SwapRouter02 | `0xaa52bB8110fE38D0d2d2AF0B85C3A3eE622CA455` | verified `SwapRouter02`; metadata == canonical |
| UniversalRouter | `0x738fD6d10bCc05c230388B4027CAd37f82fe2AF2` | unverified on Sonic, but runtime **metadata hash identical to Ethereum canonical UniversalRouter** (`a26469706673…4ad4d90b…08110033`), same length 17,958 bytes → same source (differences are immutables only) |
| ProxyAdmin | `0x0d922Fb1Bc191F64970ac40376643808b4B74Df9` | **bytecode-identical** to Ethereum canonical ProxyAdmin |
| v3Staker | `0x6Aa54a43d7eEF5b239a18eed3Af4877f46522BCA` | metadata identical to Ethereum canonical v3Staker |
| QuoterV2 / TickLens / V3Migrator | `0x5911…` / `0xB330…` / `0x8B3c…` | verified `QuoterV2`, `TickLens`, `V3Migrator` (Elk fork of periphery; not fund-custodying) |

---

## 3. The one security-relevant finding: the warrant check is disabled on all live OkuRouters

`BaseAggregator` (oku-router, v2.0) is supposed to require a backend-signed EIP-712 "warrant" binding `(sellToken, buyToken, target, approvalTarget, keccak(swapCallData), sellAmount, feeAmount, recipient)` before executing a swap. Two code paths deliberately skip the check when `warrant.verifyingSigner == address(0)`:

```solidity
// BaseAggregator.sol
modifier onlyApprovedSigner(address signer) { require(validSigners[signer], "INVALID_SIGNER"); _; }
function verifyWarrant(...) internal view { if (warrant.verifyingSigner == address(0)) return; ... }  // CanoeHelper
```

And the deploy script **explicitly whitelists address(0)** on every deployment:

```ts
// tasks/deploy.ts (repo HEAD)
const zeroAddress = hre.ethers.ZeroAddress;
if (!isZeroAddressSigner) { ... contract.updateValidSigner(zeroAddress, true); console.log("✓ Zero address approved as valid signer"); }
// "once the backend is producing valid warrants on the correct EIP-712 version, the bypass can be removed in a separate cutover"
```

On-chain confirmation (block 34707596 Scroll / 0x1e2c8f2 Linea / 0x23bfa50 Boba): `ValidSignerAdded(0x000…)` at deployment, and `validSigners(address(0)) == true` at every measured block on **all three live routers**.

**Impact assessment (fork-proven, see §6):** the bypass lets any caller execute a swap through the router with **arbitrary, unsigned calldata** against a whitelisted aggregator, paying no Oku fee. It is *not* directly extractive:

- The router only ever pulls `sellAmount` from **`msg.sender`** (`SafeERC20.safeTransferFrom(IERC20(sellToken), msg.sender, address(this), …)`) — never from a third party;
- Output is sent to `recipient`, which with `verifyingSigner == 0` is forced to equal `msg.sender`;
- The per-call approval to `approvalTarget` is `sellAmount − feeAmount` and must be exactly consumed (`ALLOWANCE_NOT_ZERO` otherwise);
- Router-held balances (fees) are only reachable via `sweepAll` (owner) — the swap paths cannot move them.

So the realistic exposure is: **unauthorized/fee-free routing and a broken defense-in-depth control**, plus latent risk if a whitelisted target ever holds funds or if the whitelist grows to include a contract that trusts calls from the router. It does not currently enable theft.

---

## 4. Live-state assessment (all values at pinned blocks, 2026-10-04)

Prices: ETH $2,693.37, MANTA $0.0723, USDC $1 (DefiLlama, 2026-10-04).

### Sonic (block 80,326,468)
- `OkuRouter` at the deterministic v2.0 address `0xb1f3…`: **no code**.
- `LimitOrderRegistry 0x1b35fbA9357fD9bda7ed0429C8BbAbe1e8CC88fc`: owner `0xe75358526Ef4441Db03cCaEB9a87F180fAe80eb9` (EOA), `isShutdown() == false`, **`batchCount() == 1` → not a single order was ever created**, `NFPM.balanceOf(LOR) == 0`, native 0, wS 0, USDC.e 0, `LINK/registrar/fastGasFeed == 0` (no keeper ever registered). Runtime metadata equals the verified Linea `LimitOrderRegistry` → same source.
- Periphery/`v3Staker`/`ProxyAdmin`: all zero balances (native and wS); see §2 for stock verification.
- Sampled pools (GeckoTerminal): `0xCfD4…` USDC.e/WETH $25.1k, `0xEcb0…` USDC.e/wS $17.5k, `0x2104…` WETH/wS $16.7k, plus dust pools. These are **LP-owned stock-Uniswap v3 reserves**, not Oku custody; no permissionless drain exists in stock v3.

### Scroll (block 35,269,579)
- `OkuRouter 0xb1f3…`: `name/version == "Oku Router"/"2.0"`, owner Safe `0x3733…` (2-of-3: `0x5348bb63…`, `0x5227a740…`, `0x46e9CF76…`), `paused() == false`, canonical Permit2, `validSigners(0) == true`, backend signer `0xB8Cb…` true. **`SwapTargetAdded` events: none** — the whitelist is empty (Permit2/self/WETH/USDC all `false`); any swap reverts `TARGET_NOT_AUTH`. Native 0; Blockscout `has_tokens == false`.
- `LimitOrderRegistry 0xeC3E…`: `isShutdown() == true`, `batchCount() == 127`, 111 NFT positions (108 empty). Exactly 3 residual orders remain non-empty — tokenIds **1212** (batch 45, 10 USDC), **2259** (batch 62, 1 USDC), **5283** (batch 80, 10 USDC) — linked list `1212↔5283↔2259`, all direction `sell USDC → WETH` at ticks 253,250–276,320 vs current tick **197,340** (far OTM ⇒ cancelable by their owners). Nominal 21 USDC. LOR WETH/native/swap-fees = 0.

### Linea (block 32,225,716)
- `OkuRouter 0xb1f3…`: v2.0, same 2-of-3 Safe owner, `paused() == false`, `validSigners(0) == true`, backend signer true, `maxWarrantDuration == 300`. Whitelist (15 targets, from `SwapTargetAdded` logs): 1inch `0x1111…2A65`, 0x Settler `0x0000…22734` + `0x1816…`, KyberSwap `0x6131…`, Odos `0x2d88…`, OpenOcean `0x6352…`, Enso `0xA146…`, OKX ×3, IcecreamSwap `0x2fF5…`, Binance `0xB444…`, Uniswap UniversalRouter `0xD7c7…`, SwapRouter02 `0x3d4e…`, `0x8B84…`. Active (`OrderFilled` events). Balances: native 0.000096 ETH ($0.26), WETH 0, USDC 0.
- `LimitOrderRegistry 0x63c8…`: `isShutdown() == true`, `batchCount() == 51`, 48 positions **all empty** (0 liquidity, 0 owed), WETH 0, native 0, swap fees 0. **Deployed source normalized-equals repo HEAD** (`src/LimitOrderRegistry.sol`, solc 0.8.16, optimizer 200, london) → audited code.

### Manta (block 9,687,228)
- `LimitOrderRegistry 0xFE83…` (verified): shutdown since 2026-08-24; `batchCount() == 12`; 10 positions all empty. Balances: **62.347248983703240 MANTA ≈ $4.51**, **4.906544 USDC ≈ $4.91** (of which 0.050795 USDC is recorded swap fees), dust WETH/wUSDM; native 0.0015 MANTA.

### Boba (block 40,045,310)
- `OkuRouter 0x7bf7…`: v2.0, same Safe owner, `validSigners(0) == true`, targets IcecreamSwap `0xC87D…` + Uniswap UR `0x4BA6…` + SwapRouter02 `0x759E…`, active; native dust 0.0003036 ETH ($0.82), WETH 0.
- `LimitOrderRegistry 0xfEFb…`: not shutdown, `batchCount() == 27`, 25 positions all empty; native **0.0225 ETH ≈ $60.60** (claim fees) and WETH **0.0003036 ≈ $0.82**, essentially all recorded swap fees → owner-withdrawable via `withdrawNative()`.

### Approvals
- Users' standing ERC20 allowances to the OkuRouter exist (the non-permit path uses `transferFrom(msg.sender)`), but the router has **no code path that transfers from any address other than `msg.sender`** — proven on a Linea fork with a 100 WETH victim approval (§6, test 3). They are not extractable by third parties.
- LOR `newOrder` pulls from `msg.sender` only; Sonic/Scroll/Linea/Manta LORs are shut down (no new orders), Boba's LOR is open but pulls only from the caller.

---

## 5. What an attacker can and cannot do

**Can (permissionless, no keys):**
- Use the Linea/Boba OkuRouter as an unauthenticated, fee-free aggregator proxy: craft unsigned calldata for a whitelisted target (`verifyingSigner = 0`, any `sellAmount`/`feeAmount`), funded only with their own tokens. Cost: gas only. Proven end-to-end on a Linea fork (WRAP_ETH via Uniswap UniversalRouter; 1 wei round-trip, no signature).
- Trigger `performUpkeep()` on any LOR to fill an ITM order (keeper is dead on most chains; this is how users' ITM funds become claimable).
- Claim/cancel their **own** LOR orders.

**Cannot:**
- Pull any third party's funds through the OkuRouter (all pull paths are `msg.sender`-bound; output is `msg.sender`-bound under bypass).
- Move router-held balances (fees) — only owner `sweepAll`.
- Cancel or claim another user's LOR order (deposit mapping is per-sender; fork-tested revert).
- Use the Scroll router at all (no targets), or extract anything from the Sonic deployment (empty/unused).
- Drain the Sonic Uniswap v3 pools: stock contracts, LP-owned, no Oku-specific custody.

---

## 6. PoC / fork verification

Foundry project: `poc/` (forge-std vendored). Tests in `poc/test/OkuH34.t.sol`, run against pinned forks (Sonic 80,326,468; Linea 32,225,716; Scroll 35,269,579; Boba 40,045,310; Manta 9,687,228), all read-only.

**Local + CI result: 9 passed, 1 skipped (Manta public RPC flaky; auto-skip), 0 failed.**

| Test | Proves |
|---|---|
| `test_sonic_oku_router_absent_and_lor_empty` | No OkuRouter on Sonic; LOR `batchCount==1`, 0 positions, 0 wS/native balances, owner EOA |
| `test_sonic_uniswap_stack_is_stock_canonical` | NFPM/SwapRouter02/UniversalRouter metadata == Ethereum canonical; ProxyAdmin byte-identical; zero balances; factory lookup works |
| `test_lor_sonic_code_matches_verified_linea` | Unverified Sonic LOR is compiled from the same source as the verified Linea LOR (metadata + length equal) |
| `test_linea_router_warrant_bypass_is_live_and_usable` | Non-whitelisted signer reverts `INVALID_SIGNER`; `verifyingSigner=0` executes a full WRAP_ETH swap (1 wei) with **no signature** |
| `test_linea_standing_approval_not_drainable` | Victim 100 WETH approval to router survives an attacker's bypassed pull attempt; victim balance unchanged; router balance unchanged |
| `test_linea_lor_empty` | LOR shutdown; 48 positions; sampled positions 0 liquidity/owed; 0 balances |
| `test_scroll_router_dormant_no_whitelisted_targets` | v2.0, Safe owner, zero-signer live, but Permit2/WETH/aggregator not whitelisted; call reverts `TARGET_NOT_AUTH` |
| `test_scroll_lor_residual_orders_not_extractable` | 3 residual orders/21 USDC nominal; attacker cancel/claim reverts; WETH 0 |
| `test_boba_router_and_lor_state` | Targets whitelisted; zero-signer live; LOR 25 empty positions; dust only (0.000304 WETH fees) |
| `test_manta_lor_residual_balances` | Shutdown; 62.347 MANTA + 4.9065 USDC residual (skips if RPC unavailable) |

**CI:** workflow `poc.yml` in `kingmariano/ca-zombie-ci`, branch `oku-trade`; custom job `ci/run.sh` additionally **recompiles `oku-router` at repo HEAD** (Hardhat: solc 0.8.27, viaIR, optimizer 1000, hardhat-deploy literal-content metadata) and byte-compares the compiled init code with the actual Scroll deployment transaction input (`0xe0d5c0a2…`), including the CREATE2 address derivation. Run URL(s): _recorded in `ci-log.txt` / below_.

| CI run | URL | Result |
|---|---|---|
| (pending) | (pending) | — |

---

## 7. Verdict, residual & latent risk

- **E-U = $0.00 (high confidence).** Every Oku-authored contract on the five chains was enumerated from official Uniswap governance lists, the `@gfxlabs/oku-chains` package and repo deployment registries; live balances/roles were read at pinned blocks; all candidate permissionless paths were fork-tested negative.
- **H-O ≈ $30.4:** Scroll LOR 3 residual cancelable orders (~$21 USDC) + Manta LOR unclaimed outputs (62.347 MANTA ≈ $4.51; 4.86 USDC ≈ $4.86). Users must act themselves (cancel/claim); keepers are dead but `performUpkeep` is permissionless.
- **P ≈ $62.5:** Boba LOR 0.0225 ETH + 0.000304 WETH fees (owner `withdrawNative`); Linea/Boba router dust (0.000096/0.000304 ETH, owner `sweepAll`); Manta LOR 0.0508 USDC + 0.0015 MANTA.
- **S ≈ $0 measured:** no non-empty positions other than the 3 cancelable Scroll orders; no MIXED/stuck orders with funds found in the non-empty set. (Known design limitation: an in-range MIXED order cannot be cancelled until the tick moves — none with funds today.)
- **Latent risks worth monitoring:** (1) the zero-signer warrant bypass is a deliberate transitional mode — once removed, the backend signer becomes the sole authority; until then any whitelisted-target exploit surface is reachable without authorization; (2) Scroll's router is one `updateSwapTargets` call (2-of-3 Safe) away from being live with the bypass; (3) LOR owners are single EOAs on Sonic/Scroll/Boba/Manta (`0xe753…`) and Linea (`0xa6e8…`) with `withdrawNative`/`withdrawSwapFees` rights — privileged, not attacker-reachable, but a key-risk.
- **Blockers/limitations:** Manta public RPC is flaky (test auto-skips); Blockscout could not enumerate ERC20 balances for the Scroll LOR (empty per both Blockscout and RPC checks on WETH/native); the OkuRouter compile-compare depends on npm/CI network availability and is reported in `ci-out/bytecode-verification.txt`.

---

## 8. Methodology & sources

- **Target enumeration:** Uniswap governance "Official v3 deployments" list; `oku-trade/oku-router` deployment registry (`deployments/*.json`); `@gfxlabs/oku-chains` v1.13.3 (`oku.router`, `oku.limitOrderRegistry` per chain); `gfx-labs/uniswap-v3-limit-orders`; `gfx-labs/oku-custom-order-types`.
- **On-chain verification:** direct JSON-RPC (`eth_getCode`, `eth_call`, `eth_getLogs`) on `rpc.soniclabs.com`/`sonic-rpc.publicnode.com`, `rpc.scroll.io`, `rpc.linea.build`, `mainnet.boba.network`, `manta-pacific.drpc.org`; Etherscan V2 (Sonic/Linea source + logs); Blockscout (Scroll address info, Manta tokens/logs); Routescan (Boba logs); GeckoTerminal (Sonic pool sample).
- **Code analysis:** deployed sources vs repo HEAD (normalized equality for the Linea LOR), runtime metadata comparison against Ethereum canonical Uniswap deployments (stock verification), manual review of `OkuRouter`/`BaseAggregator`/`CanoeHelper`/`PermitHelper`/`LimitOrderRegistry`.
- **PoC:** Foundry 1.7.1, fork-only, no transactions broadcast.
- **Prices:** DefiLlama `coins.llama.fi` (ETH $2,693.37, MANTA $0.0723, 2026-10-04).

## 9. Files index

```
oku-trade/
├── README.md                      # this report
├── summary.json                   # machine-readable summary
├── analysis/
│   ├── scan_lor.py                # LOR position scanner (all chains)
│   ├── lor_positions_{sonic,scroll,linea,manta,boba}.json
│   ├── sonic_lor_code.hex / linea_lor_code.hex / sonic_lor_bytecode.hex
│   ├── linea_lor_source.json / linea_lor_deployed.sol   # verified source == repo HEAD
│   ├── scroll_router_creation_input.hex                 # salt+initcode of the Scroll deployment tx
│   ├── gt_oku_sonic_pools.json
│   └── oku-router/ · uniswap-v3-limit-orders/ · oku-custom-order-types/   # cloned repos (analysis)
├── poc/                           # Foundry PoC (test/OkuH34.t.sol, 9/9 pass + 1 skip)
├── ci/run.sh                      # custom CI: recompile router + byte-compare with chain initcode
├── ci-out/                        # CI results
├── ci-log.txt / ci-artifacts/     # CI logs/artifacts (populated by helper)
└── summary.json
```
