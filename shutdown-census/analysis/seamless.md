# Seamless (Seamless Protocol — Leverage Tokens V2; V1 lending pool) — Ethereum, Base

Auditor: child (H-5 census). Read-only. 2026-10-04. Baseline blocks: ETH 26,116,895 · Base 52,151,169 ("latest" reads thereafter).
**Evidence provenance:** this batch ran into repeated server restarts/time-box; the LeverageManager on-chain reconnaissance below was completed by the **parent** (marked *parent-verified*) and is incorporated per instruction. Contract/source/proxy facts marked *mine* were verified directly via Blockscout + `cast` in this session. Items NOT completed by me are explicitly marked **OPEN**.

## Status & shutdown evidence (sources, dates)
- Parent brief: Seamless Protocol "shut/consolidated Apr 2026" (Base + Ethereum). No first-party wind-down URL captured in this session (**OPEN**: fetch seamless docs/blog for the exact notice).
- Deployment state consistent with sunset: LeverageManager proxies still live (code sizes 141 ETH / 268 Base) and impls verified; DefiLlama still tracks residual collateral ($7.20M ETH / $60.7K Base).

## Contracts (address, chain, code?, verified?, proxy?, roles/owner/paused, block)
| Contract | Chain | Verified source | Proxy / impl | Roles / authority | Notes |
|---|---|---|---|---|---|
| LeverageManager `0x5C37EB148D4a261ACD101e2B997A0F163Fb3E351` | Ethereum | ✅ `src/LeverageManager.sol` (impl) | ERC-1967 proxy, **impl `0x9d04f65b58ced1fddef50aec8b0b3d64fe64220e`** (mine; slot `0x3608…` read at ~26.117M) | `AccessControlUpgradeable`; `initialize(initialAdmin, treasury, IBeaconProxyFactory)`; `UPGRADER_ROLE` gates `_authorizeUpgrade`; `DEFAULT_ADMIN_ROLE` to initialAdmin; **no `paused()` found** in manager surface | Beacon-proxy LeverageToken factory |
| LeverageManager `0x38Ba21C6Bf31dF1b1798FCEd07B4e9b07C5ec3a8` | Base | ✅ `src/LeverageManager.sol` (impl) | ERC-1967 proxy, **impl `0xfe9101349354e278970489f935a54905de2e1856`** (mine; slot read at 52.151M) | as above | Base deployment |
| LeverageTokens (10 on ETH per parent) incl. `0x98c4e43e3bde7b649e5aa2f88de1658e8d3ed1bf` ("T2") and `0x6426811ff283fa7c78f0bc5d71858c2f79c0fc3d` (RLP/USDC) | Ethereum | **parent-verified** | Beacon proxies via factory | token-level config: lendingAdapter (Morpho), rebalanceAdapter, mint/redeem fees | T2 equity 106.44 ETH; 0x6426 CR 0.025 |

Manager function surface (source, mine): `createNewLeverageToken(config,name,symbol)` (**permissionless** — caller-supplied adapters get `postLeverageTokenCreation(msg.sender, token)` hooks; creates a *new* token only), `previewDeposit/previewMint/previewRedeem/previewWithdraw`, `deposit/mint/redeem/withdraw` (ERC-4626-style, permissionless, user-supplied slippage bounds), `rebalance(...)` (permissionless, see below), `convert*`, `getLeverageToken*`, `chargeManagementFee`.

## Live balances (token, amount, USD, price source, block)
- DefiLlama (parent-supplied, 2026-10-04): **Ethereum collateral $7.20M / debt $13.16M; Base collateral $60.7K / debt $57.1K** (LeverageManager deployments). ≈ **$7.26M total collateral**.
- *Parent-verified specific equities*: **T2 `0x98c4e43e…` equity = 106.44 ETH ≈ $287K** (ETH ≈ $2,697 implied), holder-redeemable → H-O. The RLP/USDC token `0x6426811f…` has CR 0.025 (near-liquidation), RLP oracle **$1.287** vs market **$0.0929** (parent), and its Morpho market `0xe1b65304edd8ceaea9b629df4c3c926a37d1216e27900505c04f14b2ed279f33` is **100% utilized**.
- **OPEN (not completed, honesty flag):** my own per-token `totalSupply`/`convertToAssets`/`previewRedeem` re-sum over all 10 ETH tokens and the Base tokens was not executed in the time-box; the ETH collateral>debt aggregate ($7.2M vs $13.16M) was not reconciled per token, so net holder equity is only proven for T2 ($287K). Do not treat $7.26M as extractable/holder-recoverable equity.

## Permissionless paths examined (path → gates → live values → verdict; include reverts/negative results)
1. `rebalance(ILeverageToken leverageToken, RebalanceAction[] actions, IERC20 tokenIn, IERC20 tokenOut, uint256 amountIn, uint256 amountOut)` — **permissionless entry, no role gate** (source, mine). Gates, in order: caller must first transfer `amountIn` of `tokenIn` into the manager; `rebalanceAdapter.isEligibleForRebalance(token, stateBefore, msg.sender)` must pass; `_executeLendingAdapterAction(...)` per action (Morpho borrow/supply/withdraw — parent saw borrow revert `insufficient collateral`); `rebalanceAdapter.isStateAfterRebalanceValid(token, stateBefore)` must pass before manager pays `amountOut` of `tokenOut` to caller. **Verdict: value-bounded by adapter post-state checks; caller pays in. No profit path proven; parent flagged `0x6426` as the only eligible token and bounded.** *Exact call sequence for parent fork-test:* `manager.rebalance(0x6426811f…, actions[], <tokenIn>, <tokenOut>, amountIn, amountOut)` after `tokenIn.approve(manager, amountIn)`.
2. `redeem(token, shares, minCollateral)` — permissionless but burns caller's own shares; pays caller pro-rata. Holder-only value (H-O); no third-party beneficiary field. T2 redeemable (parent).
3. `mint/deposit` — permissionless, caller pays; rounding/donation/inflation path not found in source review (share math goes through preview functions + `_executeLendingAdapterAction`); **no test executed** (OPEN: ERC-4626 inflation check on empty/1-wei token).
4. `withdraw(token, collateral, maxShares)` — permissionless, burns caller shares.
5. `createNewLeverageToken` — permissionless token creation with arbitrary adapters; hooks call into caller-supplied adapters (`postLeverageTokenCreation(msg.sender, token)`). Cannot mint/redeem existing tokens; self-inflicted only. Negative for existing value.
6. `_authorizeUpgrade` → onlyRole(`UPGRADER_ROLE`); manager is UUPS-style upgradeable. Privileged (P) vector: role holders can upgrade and repoint logic; role holders **not enumerated in this session (OPEN)**.
7. Fee management: `_setLeverageTokenActionFee` / management fee via FeeManager init (`initialAdmin`, `treasury`); setters not reviewed (OPEN).

## Approvals / user-side residual risk
- Token holders hold ERC-20 shares of beacon proxies; redeem/withdraw are self-service. No third-party claim on user share balances was found in the manager surface.
- If a token's Morpho market is 100% utilized (`0xe1b65304…` for `0x6426` per parent), redemption may revert until liquidity returns → that token's holder equity is effectively **S (stuck)** rather than H-O until utilization drops; the manager has no pause found, so no admin can freeze redemptions directly.
- **OPEN:** Seamless V1 (Base Compound/Aave-fork pool; parent brief ~$586K supplied / ~$70K borrowed) was **not identified or inspected** in this session — no pool address captured, no pause/oracle/rescue check performed. Recommend follow-up (DefiLlama slug not `projects/seamless`, docs/GitHub "seamless-protocol" search pending).

## Classification: H-O — E-U $0 — confidence: medium (holder equity partially proven; RLP/USDC token risk unresolved) — what would change it
- **E-U $0**: no permissionless path that pays an outsider was proven. `rebalance` is permissionless but strictly two-sided and post-state-validated; `redeem/withdraw/mint/deposit` only move caller-owned value. Parent fork test showed Morpho borrow reverts `insufficient collateral` on the stressed token.
- **Holder equity (H-O)**: T2 = **106.44 ETH ≈ $287K** parent-verified holder-redeemable. Other tokens' net equity **not re-summed** (OPEN); ETH aggregate collateral $7.2M vs debt $13.16M means the net figure could be far smaller or negative for some tokens.
- **Caveat / would change verdict**: (a) if `isStateAfterRebalanceValid` on `0x6426` is exploitable via the RLP oracle divergence ($1.287 vs $0.0929) or via `actions` ordering, a bounded extract may exist → requires fork test (parent already flagged); (b) if Morpho market stays 100% utilized, `0x6426` holder equity trends S; (c) UPGRADER_ROLE holder could upgrade implementation (P); (d) full per-token re-sum could reveal additional recoverable equity or underwater tokens → classification per token may split H-O/S/P.

## Raw evidence index (files in /home/heisenberg/CA/shutdown-census/analysis/raw/)
- `seamless_eth_proxy_blockscout.json` (ERC1967Proxy verified), `seamless_eth_impl_blockscout.json` (+`seamless_eth_impl_source.sol`, verified `src/LeverageManager.sol`)
- `seamless_base_proxy_blockscout.json`, `seamless_base_impl_blockscout.json` (verified LeverageManager)
- Read-only slot checks recorded in this dossier text: ETH impl `0x9d04f65b…`, Base impl `0xfe910134…` (EIP-1967 slot `0x360894a1…`)
- No Seamless balance JSON owned by this child; parent balance/fork findings cited inline as *parent-verified*
