# Veax (NEAR CLMM DEX) — read-only assessment

- Date: 2026-10-10 (UTC). Chain: NEAR mainnet. Status: **read-only**; keyless endpoints (`https://rpc.mainnet.near.org`,
  `https://api.nearblocks.io`, `https://coins.llama.fi`); no transactions.
- Pragmatic result: Veax is **live and actively used** (transactions on the day of this assessment), TVL ≈ **$78.3k**
  (matches DefiLlama `veax-clmm` $77,649). No external-unprivileged extraction path was found. E-U $0.00.

## 1. Contract set
| account | role | evidence |
|---|---|---|
| `veax.near` | the Veax CLMM DEX contract itself (single contract, 124 pools) | `view_account` block **219,325,961**: code_hash `y2kvReSMViAX7A4ediiCMP9mB3gcTNwPsYN5ARjdMXr`, wasm 1,015,987 B, balance 226.8412 NEAR, storage 2.16 MB |
| `veax.near` (same) | `metadata()` block **219,331,264**: `owner=55cc58d1725617f949dc882b78b5e7a162e71b588dc6c899ca94bc8db59a3ab3`, `pool_count=124`, `protocol_fee_fraction=2000`, fee_rates `[1,2,4,8,16,32,64,128]/10000` | live view call |
| — | `get_version()` block 219,331,253 → `"0.0.0+unknown"` | live view call |

No other custody contracts were found for Veax (the protocol is one contract). Export list (69 methods) includes
`open_position/close_position`, `swap_exact_in/out`, `withdraw`, `withdraw_protocol_fee`, `withdraw_owner_token`,
`get_pools/get_pool_info/get_positions_info`, `get_verified_tokens`, `suspend_payable_api/resume_payable_api`, `change_owner`.

## 2. Live funds (measured, block heights in dump)
`veax.near` FT balances (all `ft_balance_of` reads on 2026-10-10; raw values in `dumps/veax.near.ft_balances.json` +
`dumps/final_values.json`; headline balance re-reads at blocks **219,337,046–219,337,078** in `dumps/headline_refs.json` —
wNEAR drifted 12,513.575 → 12,523.558 within the assessment window, i.e. the contract is actively transacting;
prices DefiLlama ts 1791610xxx, NEAR $5.1934):

| token | amount | USD |
|---|---|---|
| wrap.near (wNEAR) | 12,513.5753 | $64,988.44 |
| token.stlb.near (STLB, 5 dec) | 22,214,629.5773 | $8,733.46 (@$0.0003931) |
| usdt.tether-token.near | 2,267.7511 | $2,266.01 |
| USDC.e (a0b869…factory.bridge.near) | 440.0514 | $439.94 |
| USDT.e (dac17f…) | 363.5182 | $363.24 |
| USDC (native, 17208628…) | 190.0100 | $189.96 |
| WBTC.e (2260fac5…) | 0.00051428 | $42.43 |
| stNEAR (meta-pool.near) | 5.0572 | $39.20 (@$7.75) |
| LiNEAR (linear-protocol.near) | 4.6420 | $34.07 |
| ETH (eth.bridge.near) | 0.0048844 | $12.17 |
| nBTC (nbtc.bridge.near) | 0.0000137 | $1.13 |
| **FT total** | | **$77,110.13** |
| native NEAR | 226.8412 | $1,178.09 |
| **contract total** | | **≈ $78,288** |

Notes: `aurora` token balance could not be decoded (its `ft_balance_of` returned an empty payload — dead end, state);
dust/spam tokens excluded. These balances are user deposits + protocol fees held by the DEX contract
(the contract holds deposited tokens while users trade).

## 3. Liveness
- nearblocks txs (newest first): `veax.near` has transactions on **2026-10-10** (block 219,326,876, e.g. `ftv2.nekotoken.near`
  interaction) and self-calls at 219,321,044 — actively used at assessment time.
- Access keys (`view_access_key_list`, block 219,328,4xx): **4 FullAccess + 3 FunctionCall(receiver=veax.near)** keys, the
  highest nonce 177,199,439,000,000 (recent signing). Owner is a hex implicit account (`55cc58d1…`).

## 4. Extraction audit (source-verified)
Source: `tacanslabs/veax` (`veax/dex/src/…`, Rust). Checks:
- `chain/wasm.rs:378` `withdraw(token_id, amount, unregister)` → `assert_one_yocto()`, then
  `dex.withdraw(&env::predecessor_account_id(), …)`. **Sender-scoped**; cannot withdraw another account's balance.
- `chain/wasm.rs:504` `withdraw_owner_token` → `owner_withdraw` which asserts `ensure_caller_is_owner()`
  (`dex_impl/mod.rs:591-598`) and only touches the owner's own inner account.
- `chain/wasm.rs:513` `withdraw_protocol_fee` → routed to `pool_state_ex.rs:1504` with owner check at `dex_impl/mod.rs:1061`
  (`contract.owner_id == sender_id`).
- `suspend/resume_payable_api` (`dex_impl/mod.rs:552/565`) → `ensure_caller_is_guard()` (owner + guard list) — a
  liveness/freeze capability, not value extraction. While suspended, `withdraw` reverts (`ensure_payable_api_resumed`).
- `change_owner`/config setters owner-gated; all `*_callback` methods `#[private]`.
- Candidate unprivileged paths tried: none applicable beyond attempting view-calls; write methods read
  `predecessor_account_id` and cannot be simulated (`HostError(ProhibitedInView)` observed on other Ref-family contracts).

## 5. Classification
- **E-U: $0.00** — no permissionless drain found in source (confidence: **medium-high**; source is complete but not
  independently multi-version verified against the deployed wasm).
- **H-O: ≈ $78.3k** — users' deposits are withdrawable (`withdraw`, sender-scoped) while the payable API is resumed; the
  only gate is owner/guard suspension.
- **P: owner/guards** — suspend/resume, fee settings, `withdraw_protocol_fee` (accrued protocol fees), `withdraw_owner_token`
  (owner's own inner balance only).
- **S: $0** — nothing bricked.

## 6. Blockers / caveats
- `aurora` token read failed (empty result) — not resolvable via keyless `ft_balance_of` at the time.
- Price of `token.stlb.near` ($0.0003931) is low-confidence; it is the second-largest item ($8.7k).
- DefiLlama's $77.6k differs from our $78.3k by snapshot/prices only.

## 7. Files
`scripts/probe_veax.py` (view probes), `scripts/near.py` (RPC helper), `dumps/veax.near.ft_balances.json`,
`dumps/final_values.json`.
