# ODOS — multi-chain EVM (Ethereum, Arbitrum, Base, Optimism, Polygon, Avalanche, BSC, Linea, Scroll, Mantle, Sonic, Fantom, zkSync Era, Mode, Fraxtal, Gnosis)

## Status & shutdown evidence (sources, dates)
- odos.xyz landing page (fetched 2026-10-04 via search index): "Odos trading and API services have shut down". Lists **Smart Order Router V3** (Ethereum, Optimism, Base, Arbitrum — status "Unsupported") and **Smart Order Router V2** (Ethereum, Optimism, Base, Arbitrum — status "Historical"). (https://odos.xyz/)
- GitHub `odos-xyz/odos-router-v2` README (fetched 2026-10-04): V2 router address per chain (full list below); audited by Zellic June 2023.
- GitHub `odos-xyz/odos-router-v3` README (fetched 2026-10-04): "deployed at 0x0D05a7D3448512B78fa8A9e46c4872C88C4a0D05 on all supported EVM chains"; adds `liquidatorAddress` role and hook calls.
- DefiLlama `api.llama.fi/protocol/odos` (fetched 2026-10-04): chains=["Ethereum"], tvl=[] (0).
- V1 router `OdosRouter` 0x76f4eeD9fE41262669D0250b2A97db79712aD855 discovered via Blockscout contract name on early Odos txs (e.g. tx 0x85c35986c5e625ad8a7802e0c78c5d634f8eafa073b8d72ef3cc3891621beea3). Still holds a large token basket; owner is a Gnosis Safe.

## Contracts (address, chain, code?, verified?, proxy?, roles/owner/paused, block)
| Router | Address | Chains | Code verified | Owner/liquidator | Notes |
|---|---|---|---|---|---|
| V1 `OdosRouter` | 0x76f4eeD9fE41262669D0250b2A97db79712aD855 | Ethereum | yes (Blockscout, solc 0.8.8) | owner = Safe 0x47E2D28169738039755586743E2dfCF3bd643f86, **threshold 1/2**, v1.3.0 | `transferFunds` onlyOwner (live-test from burn addr reverts "Ownable: caller is not the owner", block 26117403) |
| V2 `OdosRouterV2` | per chain (table below) | 15 chains | yes (Ethereum/Blockscout; Mode verified; zkSync unverified but selector+gate tested) | owner = EOA 0x498020622CA0d5De103b7E78E3eFe5819D0d28AB (nonce 2272, code=0x) | `transferRouterFunds`/`swapRouterFunds`/`setSwapMultiFee`/`writeAddressList` onlyOwner; live-test reverts "Ownable: caller is not the owner" (Ethereum block 26117403; Mode; zkSync) |
| V3 `OdosRouterV3` | 0x0D05a7D3448512B78fa8A9e46c4872C88C4a0D05 | 15 chains (same address) | yes (Blockscout, solc 0.8.20) | owner = Safe 0x498292DC123f19Bdbc109081f6CF1D0E849A9daF (**threshold 1**, 6 owners, v1.4.1) on most chains; owner = EOA on sonic 0x6cc5e417A1Cd4498C4b947EeDA6E91a99e9287a8, fantom 0x000636843C30b6B10d3DC9aF803E7A7956aa994C, zksync 0x5E1c87A1589BCC4325Db77Be49874941b2297a7B, mode 0x296C61BB5C87c3B178205BE89BbE238C0e9CE035; **liquidator = EOA 0x49802062...** | `transferRouterFunds`/`swapRouterFunds` gate `msg.sender == liquidatorAddress || owner()`; live-test reverts "Address not allowed" (Ethereum block 26117403) |

- **Bytecode equality:** V3 runtime code hash `0x6311ea382fb055699f2647a9dd51faf137aa2f81a2f9494686f2e9d76e554f0e` (34,170 hex chars) on all chains tested. V2 hash `0xfec807efa83bc06687c0fadc523dbdf9a5c32a467a69346352c87ce42614e538` (29,444) on all EVM chains tested; **Mode** has a different hash (0x6b2a1a50…) but its Blockscout verified source is `OdosRouterV2` with identical `onlyOwner` gates; **zkSync Era** code format differs (159,426 hex chars), verified-source unavailable, but all key selectors present and `transferRouterFunds` live-reverts Ownable (this variant lacks `swapRouterFunds`). No `paused()` function exists in any version (not pausable).
- V2 addresses per chain (block of read / native bal in raw): Ethereum 0xCf5540fFFCdC3d510B18bFcA6d2b9987b0772559; Arbitrum 0xa669e7A0d4b3e4Fa48af2dE86BD4CD7126Be4e13; Base 0x19cEeAd7105607Cd444F5ad10dd51356436095a1; Optimism 0xCa423977156BB05b13A2BA3b76Bc5419E2fE9680; Polygon 0x4E3288c9ca110bCC82bf38F09A7b425c095d92Bf; Avalanche 0x88de50B233052e4Fb783d4F6db78Cc34fEa3e9FC; BSC 0x89b8AA89FDd0507a99d334CBe3C808fAFC7d850E; Linea 0x2d8879046f1559E53eb052E949e9544bCB72f414; Scroll 0xbFe03C9E20a9Fc0b37de01A172F207004935E0b1; Mantle 0xD9F4e85489aDCD0bAF0Cd63b4231c6af58c26745; Sonic 0xaC041Df48dF9791B0654f1Dbbf2CC8450C5f2e9D; Fantom 0xD0c22A5435F4E8E5770C1fAFb5374015FC12F7cD; zkSync 0x4bBa932E9792A2b917D47830C93a9BC79320E4f7; Mode 0x7E15EB462cdc67Cf92Af1f7102465a8F8c784874; Fraxtal 0x56c85a254DD12eE8D9C04049a4ab62769Ce98210.

## Live balances (token, amount, USD, price source, block)
Method: per-chain `eth_getBalance` via public RPC (block recorded in `raw/odos_chains_out.txt`); token lists from Ankr multichain (balanceUsd ≥ $1 filter), Blockscout `/tokens` (scroll/zksync/mode), and Etherscan V2 `tokentx`+`tokenbalance` (mantle/sonic/fraxtal V3). USD from DefiLlama `coins.llama.fi/prices/current` (2026-10-04); a few small tokens fall back to explorer/Ankr rates (marked "fallback" in `analysis/raw/odos_token_totals.json`). Blocks: Ethereum 26,116,947; Arbitrum 511,523,468; Base 52,151,492; Optimism 157,746,784; Avalanche 96,716,607; BSC 125,621,915; Linea 32,225,692; Scroll 35,269,423; Mantle 101,481,074; Sonic 80,323,818; Fantom 123,546,636; zkSync 72,326,508; Mode 45,462,494 (~2026-10-04).

**Measured token value (DefiLlama-priced, balances > $1 threshold):**

| Chain | V1 | V2 | V3 |
|---|---|---|---|
| Ethereum | $1,205.61 | $4,020 | $1,929 |
| Base | — | $57 | $1,162 |
| BSC | — | $24 | $886 |
| Arbitrum | — | $21 | $378 |
| Polygon | — | n/a (Ankr ~$0.22) | $329 |
| Optimism | — | — | $314 |
| Avalanche | — | — | $294 |
| Fantom | — | $1 | $261 |
| Linea | — | — | $235 |
| Mantle | — | native only | $146 |
| Fraxtal | — | native only | $96 |
| Sonic | — | native only | $66 |
| **Token total** | **$1,206** | **$4,121** | **$6,099** |

Top positions: V1 TURBO $160.50 / cbETH $82.71 / TUSD $73.18 / rETH $64.16 / DPI $54.64 / GUSD $53.29 / EURA $53.10 (154k TURBO, 0.0269 cbETH, 73.2 TUSD, 0.0204 rETH…); V2 ETH OPSEC $84.90, ANYONE $78.93, NEAR $63.11, NPC $57.78; V3 ETH wstETH $64.21, AMPL $61.34, cbBTC $51.67, SOL $51.47; V3 Base DRB $61.18, DRV $45.98, AERO $40.34; V3 BSC WETH $67.81, SOL $58.70, MPLX $43.93.

**Native balances** (cast, same blocks; not double-counted for Ankr-covered chains): ETH-chain sum ≈ 0.15 ETH (~$409); AVAX 1.45 ($16 — AVAX $11.03); BNB 0.071 ($56 — BNB $787); MNT 56.09 ($36); S 122.76 ($5); FTM 333 + POL small. Natives ≈ **$0.5K**, of which ~$0.32K (scroll/zksync/mode/mantle/sonic/avax-v2) is additive to the token table (Ankr already includes natives on eth/arb/base/op/polygon/fantom/linea/bsc/gnosis).

**Total live value held by Odos routers ≈ $11.4K tokens + ~$0.5K native ≈ ~$11.9K (order-of-magnitude $10–15K).** All of it is, by contract design, accumulated swap fee/positive-slippage revenue "owned by" the owner role.

## Permissionless paths examined (path → gates → live values → verdict; include reverts/negative results)
1. **`swap`/`swapMulti` (V2/V3) and V1 `swap` input pulling** — all input tokens are pulled only `safeTransferFrom(msg.sender, …)` (V2 line 250, V3 line 236, V1 line 651). `inputReceiver`/`receiver` is a *destination*, not a source. An arbitrary caller cannot make the router pull from another user **with or without** live approvals. VERDICT: no path.
2. **Router-held balances during swaps** — `balanceBefore` delta accounting throughout (V1 lines 661–705, V2 325–352, V3 373–411). Only tokens that enter during the nested executor call can leave; pre-existing router revenue is excluded. Reentrancy via arbitrary caller-chosen `executor`/`hookTarget` cannot escape the delta bound. VERDICT: no path.
3. **`transferRouterFunds` / `swapRouterFunds` (V2/V3) / `transferFunds` (V1)** — gated. Live `eth_call` from 0x…bEEF: V2 reverts `Ownable: caller is not the owner`; V3 reverts `Address not allowed`; V1 reverts `Ownable: caller is not the owner` (Ethereum block 26,117,403; same on Mode/zkSync). VERDICT: privileged only (P).
4. **Permit2** — V2/V3 call only `ISignatureTransfer.permitTransferFrom` (selector `0x30f28b7a`, present in bytecode) with `owner = msg.sender`; requires a user signature and cannot be replayed by a third party (Permit2 checks signer == owner arg). The persistent **AllowanceTransfer** approvals users granted to the V2 router (`Approval` topic3=router; only **3 events total** full-range on Ethereum, owners 0x4128c062… (max USDC + 0xe2fc85bf…) and 0xbceb1b70… (max USDT); `Permit2.allowance()` now returns amount=max-uint160/expiration=max for 0x4128c062…USDC) **cannot be consumed**: selector `0x36c78516` (`AllowanceTransfer.transferFrom`) is **absent** from both V2 and V3 runtime bytecode. VERDICT: residual approvals inert.
5. **V1 `_permit` arbitrary call** — V1 accepts an arbitrary `permit` blob and does `token.call(permit-selector+data)` against a caller-supplied token. Fixed selector `0xd505accf`/Dai-style; needs the owner's valid permit signature and even then the allowance is never consumed (transferFrom is from msg.sender). VERDICT: no path.
6. **V3 `swapWithHook`/`swapMultiWithHook`** — arbitrary `hookTarget.executeOdosHook(...)` call from the router after the swap. Caller can make the router call arbitrary contracts, but with fixed selector and no router approvals granted to anyone; verified funding paths above stay closed under reentrancy. VERDICT: no value extraction found (contrived selector-collision scenarios only).
7. **Referral fee paths (V2 `registerReferralCode`; V3 caller-supplied `feeRecipient`)** — fees are charged out of the caller's own swap output only (V2 335–348, V3 383–399); max 2%. No router/user third-party funds move to the fee recipient. Caller-supplied `feeRecipient` cannot be pointed at another user's tokens. VERDICT: no path.
8. **Compact Yul decoders (`swapCompact`/`swapMultiCompact`)** — arbitrary storage reads near `addressListStart` only return owner-written cache values; cannot elect arbitrary source funds. VERDICT: no path.
9. **`receive()`/donations** — anyone can send ETH in; nothing comes out except via owner-gated functions and swap deltas.

**E-U: no unprivileged extraction path found. E-U = $0.** The entire ~$11.9K is extractable only by the live privileged roles (P).

## Approvals / user-side residual risk
- Direct ERC20 approvals to the V2/V3 router addresses: Etherscan V2 `getLogs` (topic0=Approval, topic2=padded router, full range to latest, Ethereum) returned no records; may partly reflect the fact Odos used Permit2 signature transfers per swap. Not fully exclusive (API range limits) — flagged.
- Permit2 AllowanceTransfer approvals with spender = V2 router: exactly 3 (Ethereum, full-range getLogs; 0x4128c062…: USDC + 0xe2fc85bfb48c4cf147921fbe110cf92ef9f26f94, 0xbceb1b70…: USDT); all granted ~April 2026 with max amount/expiration. They remain live but **unusable by anyone** because no Odos contract calls AllowanceTransfer.transferFrom. Recommended user action: revoke (defense-in-depth), not because an attacker path exists.
- Permit2 approvals with spender = V3 router: none found.
- V1-era direct approvals to 0x76f4eeD9… could not be enumerated in the time box (pre-2024 full-range log scans); V1 call surface cannot consume them either (transferFrom always from msg.sender).

## Classification: P — $11.9K live held (E-U $0) — confidence: high on path analysis (source-verified V1/V2/V3 + live gate reverts + bytecode selector checks), medium on total (indexer-derived token lists, $1 dust threshold, some fallback prices) — what would change it: finding a deployed variant whose swap pulls from a caller-supplied source address, or a live bug in the compact decoders; loss of the owner/liquidator keys would flip the funds to S (stuck), not to E-U.
- Note: V2 owner and V3 liquidator are the same single EOA (0x49802062…), making ~all chains' funds single-key extractable; V1 and V3-owner Safes are **threshold 1**. This is a privilege-concentration risk, not an external-attacker path.

## Raw evidence index (files in analysis/raw/)
- `odos_chains_out.txt` — per-chain RPC reads (code present, owner, liquidatorAddress, swapMultiFee, native balances, block numbers).
- `odos_codehash_out.txt` — runtime bytecode hashes/lengths per chain (V2/V3).
- `odos_token_totals.json` — all priced token rows + per-chain totals (source fields).
- `odos_prices_cache.json` — DefiLlama price responses (with decimals/symbols).
- `odos_v1_contract.json`, `odos_v1_tokens_p1..p5.json` — V1 verified metadata + full 241-token holding list.
- `odos_permit2_approvals_v2_p1.json` — the only 3 Permit2 AllowanceTransfer approvals to V2 router.
- `odos_v3_contract_blockscout.json` — V3 verified source (analysis in /tmp, copied key parts).
- Etherscan V2 log queries + Blockscout token pages: results embedded/noted above; raw JSON retained for eth/arb/base/op/polygon/scroll/zksync/mode and `ethtok_*` for mantle/sonic/fraxtal in the working set.
