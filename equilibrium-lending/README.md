# H-09 — Equilibrium Lending (Equilibrium parachain + Ethereum ChainBridge): live extractable-value audit

**Campaign:** zombie-hunt · **Finding:** H-09 · **Chain(s):** Equilibrium (Polkadot parachain 2011, Substrate),
Ethereum mainnet (bridge contracts) · **Date:** 2026-10-03
**Status:** read-only research; PoC fork-verified on Ethereum mainnet forks only. No mainnet transactions sent.
**Folder note:** this finding uses the protocol-named folder `equilibrium-lending/` (c-XX naming not used).

## TL;DR

| Target | Chain | Live extractable (external unprivileged) | Why closed/open | Latent risk |
|---|---|---|---|---|
| Equilibrium money market (lending pallets, last-known $1.13M) | Equilibrium parachain 2011 | **$0** (unreachable; category S ≈ $473k mark-to-market, $1.13M at 2024 freeze) | Parachain **Deregistered** on Polkadot; every public RPC/WSS endpoint dead; no node can accept a transaction | None unprivileged. If someone revives a node from a saved DB, the state (incl. funds) becomes reachable again — insider/recovery scenario |
| ChainBridge v2 + ERC20 handler (`0x267c…e1F1` / `0xe2a1…2F2F`) | Ethereum | **$0** | Handler holds **0** of all **9** registered resources (GENS/EQD/EQ burn-mint, 6 lock-release); bridge ETH **0**; admin (team EOA) and 2-of-5 relayer gates; Equilibrium deposits **disabled** | Admin could re-enable deposits / withdraw future inflows; 2-of-5 relayer quorum can mint EQ (valueless); chain-1 (Genshiro) deposits still enabled but inbound-only |
| ChainBridge v1 + handlers (`0x13D3…867F`) | Ethereum | **$0** | Bridge **paused** since 2022-09-05; handler balances **0**; admin-gated | Admin could unpause; nothing inside to take |
| EQ / EQD / GENS tokens | Ethereum | **$0** | EQ mintable only by handler via 2-of-5 relayer proposals; EQD supply 0; all tokens have no market/price | Relayer quorum can mint unlimited (valueless) EQ |

**Total live extractable now: $0 (E-U), confidence: high** (on-chain proof at Ethereum block 26,112,752).
The $1.13M DefiLlama figure is last-known value frozen on a deregistered chain; its present mark-to-market
is ≈ **$472,911**, classified **S** (stuck — nobody, privileged or not, can currently move it).

---

## 1. The target and what actually happened

Equilibrium was a Polkadot DeFi project (cross-chain money market / lending) with:
- a **Substrate parachain** on Polkadot (paraId **2011**), runtime `equilibrium-eosdt`/`eq-lab`
  (`github.com/eq-lab/equilibrium`, archived 2026-08-04) — **no EVM/Frontier pallet** (grep of
  `runtime/equilibrium/src/lib.rs`); the money market is native pallets (`eq-lending`, `eq-assets`,
  `eq-oracle`, `eq-bailsman`, …);
- a **ChainBridge (ChainSafe) deployment on Ethereum mainnet** plus custom `chainbridge` and
  `eq-bridge` pallets for native-asset transfers. The bridge is the only EVM component in the stack.

DefiLlama tracked "Equilibrium Lending" at **$1,134,428.70 last-known** (last datapoint 2024-08-21,
`deadFrom: 2024-09-01`, hallmark "Sunset of Equilibrium Network" 2024-05-01). The team pivoted to a
new token `Q`/EQ.finance (EQ→Q swap started 2023-12-20); the parachain lease ended, renewal did not
happen, and the chain is now **Deregistered** (`https://polkadot.subscan.io/parachain/2011`).

**Nothing on the Substrate side is reachable today**: all known RPC/WSS endpoints fail (table in
`analysis/chain-status.md`), `equilibrium.subscan.io` is gone, and the chain cannot finalize without a
Polkadot lease. That makes the remaining on-chain value *stuck* (S), not extractable.

The Ethereum bridge was **wound down**: deposits disabled, and the handler float was swept by the
team's admin EOA on **2025-04-08** (9 `withdraw` events, blocks 22,223,003–22,230,090).

## 2. Live-state assessment (all reads at Ethereum block 26,112,752, 2026-10-03)

### 2.1 Equilibrium chain (Substrate)
| Check | Result |
|---|---|
| Parachain 2011 status (Subscan page props) | `"status":"Deregistered"`, `first_period=14`, `last_period=14`, manager `14fhPR28…`, deposit 0 |
| Public RPC/WSS (`node.equilibrium.io`, `equilibrium-rpc.dwellir.com`, `equilibrium.api.onfinality.io`, parity endpoint) | all fail; Kong gateway returns HTTP 404 `no Route matched` |
| `equilibrium.subscan.io` | HTTP 404 |
| Genshiro sister chain (Kusama para 2024) | `Parathread`; `node.ksm.genshiro.io` DNS gone |
| Lending pallet state | unreachable — no node serves the chain |
| DefiLlama last snapshot | 2024-08-21: DOT 197,939.18 + USDC 220,865.54 + WETH 2.371 + iBTC 0.0464 + small alts = $1,134,428.70; today ≈ $472,911 |

### 2.2 Ethereum bridge — addresses, code, roles, balances

| Contract | Address | State |
|---|---|---|
| ChainBridge v2 (custom "0.1.0", `adminWithdraw` etc.) | `0x267c4d894db79a3023e266B84401e58f7434e1F1` | `paused=false`, `_relayerThreshold=2`, `_totalRelayers=5`, `_chainID=0`, ETH balance **0**, deposits **disabled** for chains 1 & 7 |
| ERC20 handler v2 | `0xe2a1D7C0c2ED4d3937bd6f93d9aCeA7498232F2F` | `_bridgeAddress=0x267c…`; balances: **0** WETH/USDT/DAI/WBTC/USDC/CRV/EQ/EQD |
| ChainBridge v1 | `0x13D3D12478044E6Ea1b76F2A52d4bb6Dd3Ec867F` | `paused=true` (since 2022-09-05), threshold 2, ETH **0** |
| ERC20 handler v1 | `0x47840AfF8b7fd9fdE5C3f11D5Ebc66e867C2f288` | balances **0** |
| EQ token | `0xA5eDE2FEE620ac3d68065EC01F26F9dd99850B82` | supply 1,846,403,069.99; MINTER_ROLE = handler only; no market price |
| EQD (new / old) | `0xfB41E1074DbE88EEb0Da01D52565774165DA03d3` / `0xf623CFC0b2067CF0976C263E83c04Cb06AaC32c7` | totalSupply **0** both |
| GENS | `0x9D9152874294aC0489eCf191376F48db99014112` | supply 4,969,962.49; no market |

Team/admin EOA (deployer, `DEFAULT_ADMIN_ROLE`): `0x81925a13D326420baEFD9f0b51bDd6309f778637`.
Relayers (2-of-5): `0xA820508a…B377`, `0xA713A672…8b87`, `0x87f4E042…5986`, `0xE0750f97…fEA3`,
`0x9FD9E20C…3dF2`. Full deployment map: `analysis/evm-bridge.md`.

### 2.3 The 2025-04-08 admin sweep (why the handler is empty)
9 `withdraw(handler,token,recipient,amount)` events, all transactions sent by the admin EOA to
recipient `0x774496dd14589ECb5ac406A4DD417293A0159a1E` (EOA, funds since moved on):
WBTC 0.02891632, WETH 9.14502475, CRV 500.97839797, DAI 1,777.121636, USDT 65,633.852016,
USDC 1,208.393462 (≈ $96k at April-2025 prices). Historical deposits: 52 on v2 (39 → Genshiro
domain 1 Oct-2022…Oct-2023; 13 → Equilibrium domain 7 EQ Jan-Feb 2024), 221 on v1.

### 2.4 Independent completeness verification (child subagent)

A child subagent independently re-enumerated the team EOA's 16 contract creations (Blockscout full tx +
internal-tx review, GoldRush balances, 221-call balance sweep) and searched for other Equilibrium/Genshiro
mainnet contracts. Result: **no missed deployment, no live unprivileged-extractable value**. The only real
token holding found was **19,568.5859 BTT (≈ $0.007)** in the v1 handler, which is not whitelisted and whose
`withdraw` reverts `sender must be bridge contract` (independently re-verified). Other nonzero entries are
fake-balance spam tokens and an unofficial EQ-clone airdrop. Details: `analysis/child-completeness.md`.

## 3. What an attacker can and cannot do (exact call paths, live results)

All simulated with `eth_call` from an arbitrary address at block 26,112,752 (full table in
`analysis/evm-bridge.md` §5; fork tests in `poc/`):

| Call path | Live result |
|---|---|
| `adminWithdraw(handler, token, attacker, amount)` | revert `sender doesn't have admin role` |
| `executeProposal(domain,nonce,data,resourceID)` | revert `sender doesn't have relayer role` |
| `voteProposal(...)` | revert `sender doesn't have relayer role` |
| `transferFunds(address[],uint256[])` | revert `sender doesn't have admin role` |
| handler `withdraw(token,recipient,amount)` | revert `sender must be bridge contract` |
| `deposit(...)` on v2, destination chain 7 (Equilibrium) | revert `deposits resource to chain with supplied chainID are disabled` |
| `deposit(...)` on v2, destination chain 1 (Genshiro) | succeeds (inbound-only: caller pays the 0.001 ETH fee, receives nothing) |
| `deposit(...)` on v1 | revert `Pausable: paused` |
| EQ `mint(attacker,1e18)` | revert `ERC20PresetMinterBurnerPauser: must have minter role to mint` |
| admin `adminWithdraw(handler,USDC,admin,0)` | succeeds (0-value no-op) |
| admin `adminWithdraw(handler,USDC,admin,1)` | revert `ERC20: call failed` — handler is empty |

There is no permissionless path that moves value out of any live Equilibrium-related contract, and
there is no value in them to move. Gas/flash-loan economics are irrelevant: **net extractable = $0**.

## 4. PoC / fork verification

Foundry project in `poc/` — forks Ethereum mainnet read-only and asserts the live state + every
gate above (no transaction is ever sent). Tests:

| Test | Proves |
|---|---|
| `test_state_v2_bridge_configuration` | threshold 2, 5 relayers, not paused, domain 0, handler bound to bridge |
| `test_state_v2_handler_balances_all_zero` | 0 balances for all 9 mapped tokens + 0 ETH |
| `test_state_v1_bridge_paused_and_empty` | v1 paused, handler empty |
| `test_state_resource_mappings` | 7 resource IDs → single handler → expected tokens |
| `test_attacker_cannot_adminWithdraw` / `…executeProposal` / `…voteProposal` / `…withdraw_from_handler` | all admin/relayer/bridge gates revert for an arbitrary caller |
| `test_admin_withdraw_path_open_but_empty` | admin gate works, but even admin cannot extract (empty handler) |
| `test_v2_deposits_disabled_for_chain7_but_enabled_for_chain1` / `test_v1_deposit_reverts_paused` | Equilibrium deposits disabled; chain-1 deposits inbound-only; v1 paused |
| `test_eq_mint_requires_minter_role` | EQ minter = handler only (2-of-5 relayer proposals); no unprivileged mint |
| `test_admin_roles_are_team_eoa` / `test_relayer_set` | privileged set = team EOA + 5 relayers |
| `test_emit_summary` | prints fork block + verdict |

**CI run:** `<PENDING>` — see `ci-log.txt` / `ci-out/evm-state-dump.txt` and
`ci-artifacts/` for the artifact of the latest run (`kingmariano/ca-zombie-ci`).

## 5. Verdict and residual/latent risk

- **E-U (external unprivileged): $0. Confidence: high** for the Ethereum contracts (direct on-chain
  proof); **medium-high** for the overall headline because the Substrate state cannot be read live
  (no node) — but that is exactly why nothing is extractable from it.
- **S (stuck): ≈ $472,911 today** (DefiLlama last-known $1,134,428.70 on 2024-08-21), held in the
  deregistered chain's state. Upper bound: users may have withdrawn during the 2023–24 wind-down;
  no public post-mortem state snapshot exists.
- **P (privileged):** team admin can re-enable deposits and withdraw future inflows; the 2-of-5
  relayer quorum can mint EQ (no market) and execute proposals. The 2025-04-08 sweep (~$96k) was
  exactly such a privileged extraction — it already happened.
- **Latent risks worth noting:** (a) the relayer EOAs are still live accounts and their keys remain
  a mint authority over EQ; (b) if any inbound transfer ever reaches the handler (e.g. a user
  mistakenly deposits), only the admin could retrieve it; (c) the EQ token remains a mintable
  ERC-20 with a 1.846B supply and no market — any future re-listing makes the relayer-gated mint
  economically relevant; (d) reviving the Equilibrium chain from a saved node database would make
  the ~$473k of frozen assets reachable again (recovery, not unprivileged extraction).

## 6. Methodology, sources, caveats

- Endpoint liveness: HTTP/WSS `system_chain` probes from a clean host; Polkadot control probe.
- Chain status: Subscan page props (`polkadot.subscan.io/parachain/2011`), Polkadot.js apps endpoint
  removals, DefiLlama protocol JSON (`api.llama.fi/protocol/equilibrium-lending`), project Medium
  feed (EQ→Q swap, xDOT2 claim/parachain renewal posts).
- Contract discovery: team SDK `equilibrium-eosdt/eq-networks`
  (`packages/network/src/config/chains/ethereum.ts`: bridge `0x267c…e1F1`, spender `0xe2a1…2F2F`,
  EQ token + resource ID) + Etherscan v2 API (`getcontractcreation`, `txlist`, `getLogs`) for the
  complete contract set and history; `eq-lab/equilibrium` runtime for the bridge pallets and the
  absence of an EVM.
- Balances/roles/simulations: `eth_call` at block 26,112,752 via public RPCs (BlastAPI/publicnode/
  drpc/BlockPi), cross-checked with `cast`; all results reproduced in the CI job and fork tests.
- Caveats: (1) the Substrate snapshot is DefiLlama's last-known figure — not a live read;
  (2) Etherscan log pages are complete for v2 (695 logs) and v1 (1,104 logs), but resource maps are
  not enumerable, so an undiscovered resource ID cannot be fully excluded — however any registered
  handler would only hold value if deposits occurred, and all deposit events are accounted for;
  (3) the v2 bridge has six unidentified selectors (custom functions) — the value-moving ones
  (`adminWithdraw`, `transferFunds`, deposits) were identified and simulated; the rest revert for
  arbitrary callers or are views; (4) EQ has no price feed, so its mintability is valued at $0.

## 7. Files index

```
equilibrium-lending/
├── README.md                      ← this file
├── summary.json                   ← machine-readable verdict
├── analysis/
│   ├── chain-status.md            ← Substrate chain deadness + TVL valuation + timeline
│   ├── evm-bridge.md              ← full EVM deployment map, roles, balances, logs, simulations
│   ├── deployer-contracts.md      ← contract-by-contract table of the team EOA deployments
│   └── raw/                       ← DefiLlama JSON, bridge log dumps, Medium feed
├── poc/                           ← Foundry fork tests (Ethereum mainnet, read-only)
│   ├── foundry.toml
│   ├── lib/forge-std (vendored)
│   └── test/EquilibriumH8009.t.sol
├── ci/run.sh                      ← CI live-state dump + endpoint probes → ci-out/
├── ci-out/                        ← CI artifacts (state dumps)
└── ci-log.txt / ci-artifacts/     ← CI logs/artifacts (after run)
```
