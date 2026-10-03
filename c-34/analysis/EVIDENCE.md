# C-34 raw evidence index

All reads are read-only. Block numbers are in each file/note.

## Socket / Bungee

| What | Where |
|---|---|
| Gateway route/controller table at block 26,108,903 (447 routes, 3 controllers, 58 live routes) | `socket_routes_26108903.json`, produced by `socket_scan.py` |
| Verified source of every live route impl / controller (59 addresses) + names | `socket_impls.json`, `socket_impls/` |
| Per-impl main-contract external call sites (`call`, `safeTransferFrom`) | `socket_impl_callsites.json`, produced by `socket_callsites.py` |
| 2024-01-16 attack victims parsed from the raw call trace (129 calls, 2,570,850.82 USDC) | `socket_2024_victims.json` (source: `eth.blockscout.com` raw trace of tx `0xc6c3331fa8c2d30e1ef208424c08c039a89e510df2fb6ae31e5aa40722e28fd6`) |
| Live `allowance`/`balanceOf` for those 129 victims (39 live allowances, 16 with balance, $15,755.11) | `socket_2024_victims_live.json` |
| Full-lifetime approval census + live check (CI) | `../ci-out/socket_approvals_raw.json`, `../ci-out/socket_live_approvals.json` |
| Multi-chain route/marker scan (CI) | `../ci-out/socket_marker_scan.json` |

Key calls (reproduce with `cast`):
- `routesCount()` = 447; `routes(406)` = `0x0f34A522FF82151c90679b73211955068FD854F1` (disabled sentinel); `disabledRouteAddress()` = same.
- `executeRoute(406, …)` reverts `RouteDisabled()` = `0x17d0b6db`.
- Route 406 was `0xCC5FdA5e3cA925bd0bb428C8b2669496Ee43067e` (`WrappedTokenSwapperImpl`), added block 18,996,162, disabled block 19,021,526.
- Historical gateway calldata (block 19,021,454): `0x00000196` + `0x7899f9ed` + `(USDC, 0xEeee…, 0, receiver, 0x1b3b, 0x64, 0x23b872dd(victim, attacker, X))`.

## Hedgey

| What | Where |
|---|---|
| Ethereum token-in history + current balances for `ClaimCampaigns 0xBc452fdC…` (2,471 rows, 10 tokens) | `hedgey_tokens_received.json`, `hedgey_tokens.json` |
| Arbitrum / Optimism / Base / BSC enumerations (GoldRush) | `hedgey_cc_arbitrum.json`, `hedgey_cc_optimism.json`, `hedgey_cc_base.json`, `hedgey_cc_bsc.json`, `gr_*.json` |
| Direct on-chain balances + DexScreener pricing of every non-zero token | `hedgey_valuations.json` |
| Deployed codehash equality across chains | `0x725bc4ce48b9a71a4fd491b1f7bdcf29c772d92f8ee7a5cd6c3264f570f70db4` (ETH/ARB/OP/Base/BSC) |
| v2 (fixed) contract source | fetched from `hedgey-finance/ClaimCampaigns` (locker whitelist + `allowance == 0` checks) |

## Hemi

| What | Where |
|---|---|
| MerkleBox verified source + ABI | `hemi_0x9Ab3660c….sol` (in /tmp during analysis; fetched from `explorer.hemi.xyz/api?module=contract&action=getabi`) |
| Live state (HEMI 0, holdings 15/16 = 0, claimGroupCount 16, TT token only) | `../ci-out/hemi_state.json` |
| Related airdrop/distributor contracts all hold 0 HEMI | checked at Hemi block 5,427,470 |

## Exact blocks used

| Chain | Block |
|---|---|
| Ethereum (Socket route scan) | 26,108,903 |
| Ethereum (Hedgey balances / victims live check) | 26,109,126 |
| Arbitrum | 511,184,580 |
| Optimism | 157,699,714 |
| Base | 52,104,430 |
| BSC | 125,412,624 |
| Hemi | 5,427,470 |
