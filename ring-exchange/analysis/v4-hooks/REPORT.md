# Ring Protocol — Uniswap-v4 hooks on HyperEVM: live value check (H-31 sub-task)

**Date:** 2026-10-04
**Chain:** HyperEVM (chainid 999), RPC `https://rpc.hyperliquid.xyz/evm`
**Head block used:** 47,621,152
**Status:** read-only; no transactions sent, no keys used; all state read via `eth_call`/`eth_getCode`/Etherscan V2 (chainid 999). PoC not applicable because the target set is empty.

---

## 1. TL;DR

**Ring Protocol has no Uniswap-v4 hook deployment on HyperEVM.** Every v4 hook contract live on HyperEVM belongs to a third party (Purr ecosystem and an NFT-strategy hook), and none of Ring's HyperEVM contracts is a hook or holds hook-related value.

| Question | Answer |
|---|---|
| Ring v4 hooks deployed on HyperEVM | **0** |
| Value held by Ring v4 hooks (drainable or not) | **$0.00** |
| Live v4 hooks on HyperEVM (any project) | 4 (3 Purr-ecosystem, 1 NFTStrategyHook) |
| Value held by those non-Ring hooks | 0.0891 HYPE ≈ **$8.00** (PurrHook `0x13d4a4e2…`) |
| Ring contracts on HyperEVM with any token/native balance | **none** (24/24 all-zero at block 47,621,152) |
| Ring UniversalRouter v2 on HyperEVM supports v4? | **No** — `v4PoolManager` is an always-revert stub |

### Total live extractable by an external unprivileged attacker (E-U)
**$0.00 — confidence: high** (Ring-owned scope). The only theoretical hook-held value on the chain is a third-party PurrHook's 0.0891 HYPE; it is not Ring's and is excluded from the headline.

---

## 2. Enumeration of Ring v4 hook deployments on HyperEVM

### 2.1 Documentation (all fetched 2026-10-04)

| Source | Result |
|---|---|
| `docs.ring.exchange/contracts/v4/overview` | v4 section is about FewToken + Uniswap v4 on **Ethereum mainnet**. HyperEVM only appears as a Ring Swap v2 network. |
| `docs.ring.exchange/contracts/v4/guides/fewtoken-liquidity-aggregation` | Lists 25 Ethereum pools; 9 Ethereum wrapper hooks (`FewTokenHook`, `FewUSDTHook`, `FewETHHook`) on chainid 1. Explicitly says the package is Ethereum-specific. |
| `docs.ring.exchange/contracts/v4/deployments` | Upstream Uniswap v4 addresses; Ring hook addresses only on Ethereum. No HyperEVM hook addresses. |
| `docs.ring.exchange/contracts/v4/concepts/hooks` | Generic hook docs; points to the Ethereum integration page for deployed hooks. |
| `docs.ring.exchange/assets/files/ring-swap-v2-c72e1274662d3d414b1434f00f33f038.json` | Ring Swap **v2** deployment manifest (Ethereum, BNB, HyperEVM, MegaETH). Contains no hook addresses for any chain. |

### 2.2 GitHub repositories (cloned 2026-10-04, `RingProtocol/*`)

| Repo | Deployment target found | HyperEVM refs |
|---|---|---|
| `RingV4JitHook` | Deploy script header: “Usage (Ethereum mainnet) … `$MAINNET_RPC_URL`” | none |
| `FewV4ShellHook` | Mainnet hook `0xADEf200B8E8b66e27D5bd11C87D789D4D6E82088` (Ethereum), Sepolia tests | none |
| `RingFallbackHook` | Scripts use `$ETH_RPC_URL`; hook flag mask `0x88` | none |
| `RingShareLiqHook` | Sepolia deployment & acceptance records | none |
| `ring-v4-aggregator-hook-audit` | `script/DeployMainnet.s.sol` (Ethereum mainnet); flag mask `0x2888` | none |
| `v4-periphery` (Ring fork) | `FewTokenHook`, `FewUSDTHook`, `FewETHHook`, WETH hooks; no deploy configs | none |
| `hooklist` | Uniswap hooks registry: chain dirs include ethereum, arbitrum, base … **no `hyperevm` dir** | none |

### 2.3 On-chain deployer enumeration (Etherscan V2 chainid 999)

Known Ring EOAs/timelock, checked exhaustively via `txlist` (startblock 0 → endblock 99,999,999):

| Address | Role | Txs | Contract creations | CREATE2-deployer calls |
|---|---|---|---|---|
| `0xa3142fdc1050289a95858799aa921cb1d6ace65d` | Ring deployer EOA | 42 | 23 | 0 |
| `0x9336D0C82299Da0ab178271792954ADFD6f10fD7` | minter EOA | 186 | 0 | 0 |
| `0x4f0aa5900b8292273b2f9a178d5468f8048bb9a9` | LP EOA | 111 | 0 | 0 |
| `0x03709dfd8145b618af0e06b48dd76258d8ef2e2f` | Timelock (governor) | 1 | 0 | 0 |

The 23 contracts deployed by `0xa3142fdc…` (all fingerprinted; code size + verified name + address flag bits):

| # | Address | Size | Verified name | Notes |
|---|---|---|---|---|
| 1 | `0x65ad6336abf9cefbfd6b6afda318dcf102025ea4` | 1,765 | — | 1 lifetime tx; dead |
| 2 | `0x65f49e58b8b6a630acd43d13d42697fc2631c2c0` | 6,629 | Core | early Core |
| 3 | `0x9200dc65b47c55060cf527ec7505975deda85cd5` | 1,765 | — | 1 lifetime tx; dead |
| 4 | `0x1cda28ad2915356eb618518b1bdd3f462aef3803` | 6,629 | Core | live Core |
| 5 | `0x6b65ed7315274eb9ef06a48132eb04d808700b86` | 11,754 | FewFactory | live |
| 6 | `0x068b60ecbc934b0a0dde20fdff0de925b97b971f` | 2,371 | FewETHWrapper | live |
| 7 | `0x4afc2e4ca0844ad153b090dc32e207c1dd74a8e4` | 13,833 | SwapV2Factory | live |
| 8 | `0xcdcc42ec0ecb7b5f9e4a5fe1df99eeb1bdf46a00` | 18,841 | UniswapV2Router02 | helper |
| 9 | `0x701d1d675415efa2d2429fb122ccc6dd4fcca959` | 19,758 | SwapV2Router | live |
| 10 | `0xc38f2fd561d748ce74a5f9ce09b89d2cf421fb56` | 10,507 | — | RingLaunchpad minter (known from CONTEXT) |
| 11 | `0x03709dfd8145b618af0e06b48dd76258d8ef2e2f` | 6,727 | Timelock | live |
| 12 | `0x24e743cce93235641f2be8ce7ffc6330903ab96f` | 1,780 | Multicall | helper |
| 13 | `0x793b1b0111ba64673f983ea7d7c0af15a1161bed` | 1,424 | XSwapMulticall | helper |
| 14 | `0x89ee5204f5439b7eb6b94e7646cb10744eea315f` | 101 | — | always-revert stub |
| 15 | `0x3073bdf14b10463abd2f4bd982b6e36bb8a4b8eb` | 24,083 | UniversalRouter | v2 router |
| 16 | `0x8ee2e94405b800d8689dc8e4ec3bd36141a3ddbc` | 101 | — | always-revert stub |
| 17 | `0x6cc41bd3765ca1d11b8d7d88df1da6b6b9365cb3` | 24,083 | UniversalRouter | v2 router |
| 18 | `0x5eb3ab764e7789d09b9088e7e988970e15061a17` | 101 | — | always-revert stub |
| 19 | `0xf3f503d3ec86b43d3da41c8a4dbcef77a4deb825` | 24,083 | UniversalRouter | v2 router |
| 20 | `0x69099cc542aa0f6b08367d99a5a01f48bed61122` | 101 | — | always-revert stub (`v4PoolManager`) |
| 21 | `0xe65081efa5ad4a196b1df768716c337e6ab140e9` | 24,083 | UniversalRouter | live manifest router |
| 22 | `0xe6012dcbd3864ceee87943a0e7b05d6b24aed6a0` | 21,744 | — | 1 lifetime tx; dead |
| 23 | `0x7d3d28dee339c17452a4d6b53c71b2557278b530` | 22,073 | — | `execute(bytes,bytes[],uint256)` router; holds 0 |

**None of the 23 is a v4 hook.** No pool on HyperEVM references any of them (see §3), and none matches the hook flag masks mined by Ring's repos (`0x88`, `0x2088`, `0x2888`, `0x2AC0`).

Additionally, no Ring address ever called the canonical deterministic CREATE2 deployer `0x4e59b44847b379578588920cA78FbF26c0B4956C` (which Ring's own hook deploy scripts use). So no hook was deployed through that route either.

### 2.4 Ring's HyperEVM UniversalRouter cannot use v4 at all

Constructor args of `UniversalRouter` `0xE65081EFa5ad4A196B1Df768716c337e6AB140E9` (from verified source `ConstructorArguments` and creation tx `0x1c24dde6…`):

| Param | Value |
|---|---|
| permit2 | `0x000000000022D473030F116dDEE9F6B43aC78BA3` |
| weth9 | `0x5555555555555555555555555555555555555555` (WHYPE) |
| fewFactory | `0x6B65ed7315274eB9EF06A48132EB04D808700b86` |
| uniswapV2Factory | `0x69099cc542aa0f6b08367d99a5a01f48bed61122` (stub) |
| ringSwapV2Factory | `0x4AfC2e4cA0844ad153B090dc32e207c1DD74a8E4` |
| uniswapV3Factory | `0x69099cc5…` (stub) |
| fwrng | `0x69099cc5…` (stub) |
| **v4PoolManager** | **`0x69099cc5…` (stub)** |
| v3NFTPositionManager | `0x69099cc5…` (stub) |
| **v4PositionManager** | **`0x69099cc5…` (stub)** |

`0x69099cc542aa0f6b08367d99a5a01f48bed61122` is a 101-byte contract whose entire runtime either reverts with custom error `0xea3559ef` or halts (`CALLVALUE; PUSH1 0x2b; JUMPI; … REVERT`). Any v4 command routed through Ring's HyperEVM `UniversalRouter` reverts. This is a v2-only build.

---

## 3. Every v4 hook live on HyperEVM (census, block 47,621,152)

Method: Etherscan V2 `logs/getLogs` on the canonical Uniswap v4 `PoolManager` `0x12D4Fd9C5DeDd00ab8a0bCe2CF0167bbf94b6B1F` (verified name `PoolManager`, 24,009 bytes), topic0 `0xdd466e674ea557f56295e2d0218a125ea4b4f0f6f3307b95f85e6110838d6438` = `Initialize(bytes32,address,address,uint24,int24,address,uint160,int24)`, from block 0 to 47.6M. **Complete result: 8 pools**, each poolId recomputed from its `PoolKey` and matched.

| Pool (currencies) | Init block | Hook | Hook flags (low 14 bits) | Hook identity |
|---|---|---|---|---|
| SMK4 / WHYPE, fee 3000, ts 60 | 46,002,209 | `0x0000…0000` | — | — |
| HYPE / TEST, fee 3000, ts 60 | 46,018,191 | `0x0000…0000` | — | — |
| HYPE / PAPER, fee 10000, ts 200 | 46,765,851 | `0x0000…0000` | — | — |
| HYPE / YARN, fee 0, ts 200 | 46,835,818 | `0x893ffcbb4476f31a4a22a241513f00d5f84820cc` | `0x20cc` | unverified, 8,563 B, creator `0x0f9ed9c0…`, "Yarn/YARN" ctor args |
| HYPE / YARN, fee 0, ts 200 | 46,837,831 | `0x13d4a4e22e5c65a7567ca78c1a03487e0e94a0cc` | `0x20cc` | verified **PurrHook**, 8,492 B, creator `0x0f9ed9c0…` |
| HYPE / YARN, fee 0, ts 200 | 46,960,360 | `0x315fd47e1f5ce6188e457a97c588230842c060cc` | `0x20cc` | verified **PurrHook**, 9,072 B, creator `0x0f9ed9c0…` |
| HYPE / HFAXSTR, fee 0, ts 60 | 47,499,304 | `0xea456a0bf66a888cd1c614516496d02608cf2444` | `0x2444` | verified **NFTStrategyHook**, 8,181 B, creator `0xd63dce…` |
| HYPE / THCSTR, fee 0, ts 60 | 47,507,708 | `0xea456a0bf66a888cd1c614516496d02608cf2444` | `0x2444` | same NFTStrategyHook |

- `0x20cc` = `beforeInitialize | beforeSwap | afterSwap | beforeSwapReturnDelta | afterSwapReturnDelta`.
- `0x2444` = `beforeInitialize | afterAddLiquidity | afterSwap | afterSwapReturnDelta`.
- **No Ring fw token (`0x9e11…`, `0x0C47…`, `0xd264…`, `0x7576…`, `0x09D2…`) or underlying appears as a currency in any pool.**

### Balances of the four live hooks (block 47,621,152)

| Hook | Native HYPE | ERC-20s |
|---|---|---|
| `0x893ffcbb…` | 0 | none |
| `0x13d4a4e2…` (PurrHook) | 89,100,000,000,000,000 wei = 0.0891 HYPE ≈ **$8.00** | none |
| `0x315fd47e…` (PurrHook) | 0 | none |
| `0xea456a0b…` (NFTStrategyHook) | 0 | none |

WHYPE price used: **$89.78** (DefiLlama, 2026-10-04, `hyperevm:0x5555…5555`).

### PoolManager reserves (foreign pools, same block)

| Token | PM balance |
|---|---|
| YARN `0xceade168…` | 3,199,999,999,999,999,999,999,955 wei |
| YARN `0xb1e0307f…` | 3,199,999,999,999,999,999,999,955 wei |
| YARN `0xf87349fb…` | 3,199,999,611,916,156,401,328,234 wei |
| HFAXSTR `0x8593b70c…` | 999,999,999,999,999,999,999,994,637 wei |
| THCSTR `0x76325990…` | 999,999,999,999,999,999,999,994,637 wei |
| SMK4 `0x1c5a08a1…` | 1,000,050,000,000,000,000 wei |
| WHYPE `0x5555…5555` | 2,507,396,828 wei (dust) |
| TEST / PAPER | 1 wei each |
| native HYPE | 80,423,020,816,050 wei |

### Hook-collected fees / permissionless claim (step 4 of the task)

The HyperEVM `PoolManager` is the stock verified Uniswap v4 `PoolManager`; it exposes no `withdraw`/`sweep`/permissionless claim for hook fees. Hook-collected value lives in the hook contract and is moved only through the hook's own `take`/`collect` paths during pool operations. Since **no Ring hook exists**, there are **no Ring-attributable hook fees** anywhere — neither in hooks nor in the PoolManager.

---

## 4. Ring contracts on HyperEVM hold nothing

At block **47,621,152**, all 23 deployer-created Ring contracts plus the Timelock (`0x03709dfd…`) were checked for native HYPE and the 10 relevant ERC-20s (WHYPE, USDC, USDT0, USDH, UETH, fwWHYPE, fwUETH, fwUSDC, fwUSDH, fwUSDT0):

**24/24 addresses: zero balance in every asset (native and tokens).** (Raw result: `ring_balances_at_47621152.json`.)

For context, the non-zero balances found in the wider sweep are all non-Ring or non-hook: Purr creator EOA (0.00084 HYPE + ~0.003 WHYPE), NFT-strategy creator EOA (0.117 HYPE), PoolManager dust, PurrHook 0.0891 HYPE.

---

## 5. Verdict per candidate

| Candidate (task list + on-chain finds) | Deployed on HyperEVM? | Hook? | Holds value? | Classification |
|---|---|---|---|---|
| `RingV4JitHook` | No (Ethereum-targeted repo) | — | No | N/A |
| `FewV4ShellHook` | No (Ethereum `0xADEf…2088`; Sepolia tests) | — | No | N/A |
| `RingFallbackHook` | No (Ethereum scripts) | — | No | N/A |
| `RingShareLiqHook` | No (Sepolia) | — | No | N/A |
| `ring-v4-aggregator-hook-audit` | No (DeployMainnet, Ethereum) | — | No | N/A |
| All 23 contracts deployed by Ring deployer on chain 999 | Yes | **No** (none referenced by any pool; no hook flag masks) | No | S (inert) / helper contracts |
| 4 live HyperEVM v4 hooks | Yes | Yes, but **not Ring** | Only PurrHook `0x13d4a4e2`: 0.0891 HYPE ≈ $8.00 | Not Ring scope |

**E-U (external unprivileged, Ring v4 hooks): $0.00**
H-O: $0.00 · P: $0.00 · S: 0 value stuck (the inert/unused contracts hold nothing).
Confidence: **high**.

What would change the verdict: discovery of a Ring-mined hook address on HyperEVM that (a) is not referenced by any of the 8 live pools, but (b) holds tokens. The four EOAs/timelock exhaustively show no such deployments, the canonical CREATE2 deployer was never called by Ring, and all live pool hooks are third-party. A hook deployed through an unknown third-party factory with zero balance would still be E-U $0.

---

## 6. Negatives / dead ends (do not re-investigate)

1. **Docs v4 pages are Ethereum-only** — no HyperEVM hook addresses exist in Ring's docs or the v2 manifest.
2. **All five hook repos + v4-periphery fork + hooklist**: no HyperEVM deployment references; deploy scripts are Ethereum/Sepolia.
3. **Ring deployer `0xa3142fdc…`**: 23 creations, none a hook; last activity at block 9,273,064.
4. **Minter EOA `0x9336D0C8…`, LP EOA `0x4f0aa59…`, Timelock**: zero contract creations, zero CREATE2-deployer calls.
5. **Ring `UniversalRouter` `0xE65081EF…`**: `v4PoolManager` = always-revert stub `0x69099cc5…`; v4 path is disabled.
6. **Uniswap v4 on HyperEVM**: only 8 pools have ever been initialized; the only hooks are Purr-ecosystem (`0x20cc` flags) and NFTStrategyHook (`0x2444`). None is Ring.
7. **All Ring HyperEVM contracts hold zero** of native + 10 relevant tokens.
8. **No permissionless claim of hook fees** in the v4 PoolManager; moot for Ring since no Ring hook exists.

---

## 7. Evidence files (same folder)

| File | Content |
|---|---|
| `deployer_txlist.json` | All 42 txs of Ring deployer `0xa3142fdc…` (23 creations) |
| `ring_deployer_contracts.json` | Fingerprint of all 23 creations (size, verified name, address flag bits) |
| `txlist_minterEOA.json`, `txlist_lpEOA.json`, `txlist_timelock.json` | Full tx lists (0 creations, 0 factory calls) |
| `chain999_uniswap_deployments.json` | Uniswap registry chain-999 extract (PoolManager, PositionManager, …) |
| `pm_initialize_logs_p1.json` | Raw `Initialize` logs of the HyperEVM PoolManager (all 8) |
| `hyperevm_v4_pools.json` | Decoded pools: PoolId (recomputed & matched), currencies, fee, tickSpacing, hook |
| `pool_tokens_fixed.json` | Pool currency symbols/decimals + PM/hook balances at block 47,621,152 |
| `ring_balances_at_47621152.json` | Ring 24-address balance sweep (all zero) |
| `balances_sweep.json` | Wider first-pass sweep (Ring + hooks + PM) |
| `code_0x69099cc5.hex` (+ 3 sibling stubs) | Runtime bytecode of the always-revert stubs |
| `rpctools.py` | Read-only RPC/Etherscan helper used for every call |

Raw calls (for reproduction):
- PoolManager code: `eth_getCode(0x12D4Fd9C5DeDd00ab8a0bCe2CF0167bbf94b6B1F, 0x2D68200)` → 24,009 bytes.
- Hook balances: `eth_getBalance` + `balanceOf(address)` for the 9 pool currencies at block 47,621,152.
- Ring balances: `balanceOf(address)` for the 10 tokens × 24 addresses at block 47,621,152.
- Hook identity: Etherscan V2 `contract/getsourcecode` + `contract/getcontractcreation` + creation tx input (`eth_getTransactionByHash`).

## 8. Caveats

- The unverified hook `0x893ffcbb…` was not bytecode-decompiled; its identity is inferred from its CREATE2 deployer (`0x0f9ed9c0…`, the Purr deployer), its "Yarn/YARN" constructor strings, and its `0x20cc` permission mask matching the adjacent PurrHook. It holds zero value and is definitively not Ring (not deployed or referenced by any Ring address, repo, or doc).
- The census covers the canonical Uniswap v4 PoolManager on HyperEVM (the only one in Uniswap's registry). Any fork PoolManager would not be a "Ring Protocol hook deployment" either, and Ring's own router points at a revert stub.
- No transactions were sent; everything is `eth_call`/`eth_getCode`/Etherscan reads. "E-U $0 with proof" is the result.
