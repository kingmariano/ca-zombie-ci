# C2-28 — analysis artifacts index

All data is read-only, from public endpoints only (no API keys, no secrets):

| File | Contents |
|---|---|
| `fetch_state.py` | Main fetch script: sommelier-3 LCD + ABCI store reads (module balances, gravity params/KV subspaces, cellarfees v2, cork/axelarcork managed cellar IDs, community pool, staking, supply) + Ethereum `eth_call` on the SOMM ERC-20 + DefiLlama price/TVL. Usage: `python3 fetch_state.py <outdir>`. |
| `cellar_balances.py` | Fetches token balances of the cork v2 managed cellars (Ethereum) from the keyless Blockscout v2 API. Usage: `python3 cellar_balances.py <cellar_ids.json> <out.json>`. |
| `price_cellars.py` | Prices the cellar holdings with DefiLlama (keyless) and adds native ETH balances from a public RPC. Usage: `python3 price_cellars.py [raw.json] [ids.json] [out.json]`. |
| `cellar_balances.json` | Raw token amounts for the 36 cork v2 (Ethereum) managed cellars (rates null in Blockscout's response). |
| `cellar_balances_priced.json` | The same cellars priced via DefiLlama + native ETH — total **$996,443.70** across 35/36 cellars (2026-10-09). |
| `local/state.json` | Consolidated sommelier-3 state snapshot at height 28,183,103 (2026-10-09T14:40Z). |
| `local/raw/*.json` | Raw LCD/ABCI/eth_call responses (balances, gravity subspaces, cellarfees, cork IDs, ERC-20, prices). |
| `local/raw/arbitrum_cellar_balances.json` | Arbitrum axelarcork managed-cellars token balances (Blockscout, gathered during the session; Blockscout later rate-limited CI with HTTP 403 — numbers retained). |
| `local/raw/optimism_cellar_tokens.json` | Optimism managed-cellar token list with contract addresses. |
| `local/l2_priced.json` | L2 managed-cellar totals: Arbitrum $158,016.68; Optimism $31,814.82 (DefiLlama prices). |

Key verified invariants:
- gravity module balance (36,864,615,016,774 usomm) == Ethereum ERC-20 SOMM `totalSupply` (36,864,615,016,774, 6 decimals) — the bridge collateral invariant.
- gravity store prefix `0x07` (unbatched SendToEthereum) is empty; prefix `0x06` (outgoing txs) contains only SignerSetTx entries (no pending BatchTx).
- cork v2 / axelarcork: no scheduled corks on any chain.

CI: `ci/evidence.py` re-runs all of the above on the public runner and writes `ci-out/summary_ci.json` (see `../README.md` for run URLs).
