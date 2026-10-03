# H-09 — Equilibrium chain status (Substrate side)

Read-only evidence gathered 2026-10-03. No transactions sent.

## 1. Parachain 2011 on Polkadot is DEREGISTERED

Source: `https://polkadot.subscan.io/parachain/2011` (page props, fetched 2026-10-03):

```json
{"para_id":2011,"status":"Deregistered",
 "manager":"14fhPR28n9EHZitNyf6wjYZVBPwKgcgogVjJPTzvCcb8qi9G",
 "first_period":14,"last_period":14,"auction_index":12,
 "validators":[5 collators],"deposit":"0", ...}
```

Register Status in the rendered table = `Deregistered`. The chain is not an active parachain
(no lease), so it cannot produce finalized blocks through Polkadot. The Polkadot.js apps endpoint
list has also removed the Equilibrium RPC entries (github.com/polkadot-js/apps issues #9977, #10174),
which is consistent with the endpoints being dead.

## 2. No public RPC/WSS endpoint serves the chain

Probed 2026-10-03 (HTTP `system_chain` POST and WSS `system_chain`; WSS tested with Node 24 WebSocket):

| Endpoint | Result |
|---|---|
| `wss://node.equilibrium.io` | connection error |
| `wss://equilibrium-rpc.dwellir.com` | connection error |
| `wss://equilibrium.api.onfinality.io/public-ws` | connection error |
| `wss://equilibrium.maartenn.endpoint.parity.io` | connection error |
| `https://node.equilibrium.io` (Kong gateway) | HTTP 404 `no Route matched with those values` |
| `https://rpc.equilibrium.io` (Kong gateway) | HTTP 404 `no Route matched with those values` |
| `https://api.equilibrium.io` (Kong gateway) | HTTP 404 `no Route matched with those values` |
| `wss://node.ksm.genshiro.io` (sister chain) | DNS does not resolve |
| `wss://genshiro-rpc.dwellir.com`, `wss://genshiro.api.onfinality.io/public-ws` | connection error |

Control: `wss://rpc.polkadot.io` answered `system_chain = "Polkadot"`, so the WSS probe method is valid.
`equilibrium.subscan.io` returns HTTP 404 (no explorer for the chain).

Kusama sister chain Genshiro (para 2024) is now a **Parathread** (`https://kusama.subscan.io/parachain/2024`,
page props `"status":"Parathread"`).

## 3. Last-known value on the chain (DefiLlama "Equilibrium Lending", frozen snapshot)

DefiLlama protocol `equilibrium-lending` (`https://api.llama.fi/protocol/equilibrium-lending`):
- `deadFrom: 2024-09-01`, hallmark `[2024-05-01, "Sunset of Equilibrium Network"]`
- last TVL datapoint: **2024-08-21**, `$1,134,428.70`
- last token snapshot (amounts) and current mark-to-market (prices via `coins.llama.fi`, 2026-10-03):

| Asset | Amount | Price now | USD now |
|---|---|---|---|
| DOT | 197,939.18 | $1.2101 | $239,525 |
| USDC | 220,865.54 | $1.0000 | $220,860 |
| WETH | 2.371 | $2,680.73 | $6,356 |
| Bitcoin (iBTC) | 0.0464 | $84,821.07 | $3,936 |
| Astar | 96,255.65 | $0.00743 | $715 |
| USDT | 1,462.97 | $0.9999 | $1,463 |
| Moonbeam | 4,126.85 | $0.01167 | $48 |
| BNB / BUSD | 0.009 / 0.49 | — | ~$7 |
| Interlay / CRU | 6,314.41 / 0.2721 | no price | — |
| **Total** | | | **≈ $472,911** |

At the 2024-08-21 freeze the same basket was worth **$1,134,428.70** (DOT ≈ $4.53 then).
These assets were held in the Equilibrium chain's lending/money-market state; with the chain
deregistered and no node reachable, **no transaction can be submitted to it by anyone** — the
funds are frozen in an unreachable state (category S), not attacker-extractable.

Caveat: this is the last DefiLlama snapshot. Users may have withdrawn part of these balances during
the 2023–2024 wind-down (the adapter was still updating until Aug 2024), and no post-mortem state
snapshot of the chain is publicly available. The figure is an upper bound on what remains.

## 4. Timeline (public statements + on-chain)

- 2023-11-03/20: team announces `Q` token and EQ.finance crowdloan (EQ → Q strategic shift).
- 2023-12-20: **EQ → Q swap started** (Jan 2–16, 2024 window; also accepted GENS at 4000 GENS = 1 Q).
- 2024-01-16: "xDOT2 claim and next steps towards our parachain renewal" — "the lease for the second
  batch of parachains has ended on Polkadot … the former Equilibrium parachain"; 563,693 DOT claimable
  by xDOT2 holders; renewal still planned.
- 2024-01/02: last bridge activity to the Equilibrium bridge domain (EQ deposits, Ethereum blocks
  18,820,785–19,017,430 = Jan–Feb 2024).
- 2024-05-01: DefiLlama hallmark "Sunset of Equilibrium Network".
- 2024-08-21: last DefiLlama TVL datapoint ($1,134,428.70).
- 2024-09-01: DefiLlama `deadFrom`.
- 2025-04-08: team admin sweeps the Ethereum bridge handlers (blocks 22,223,003–22,230,090).
- 2026-10-03: parachain status "Deregistered"; all RPC endpoints dead (this audit).

## 5. Runtime facts relevant to the finding

- Production runtime (`eq-lab/equilibrium`, archived 2026-08-04): **no EVM/Frontier pallet** in
  `construct_runtime!` (grep for `evm|ethereum|frontier` in `runtime/equilibrium/src/lib.rs` returns
  nothing). The money market is native Substrate pallets (`eq-lending`, `eq-assets`, `eq-oracle`, …).
- The only EVM contracts in the Equilibrium stack are the **Ethereum-side ChainBridge contracts**
  (see `evm-bridge.md`).
- Bridge pallets in the runtime: `pallets/chainbridge` (ChainSafe ChainBridge port) and
  `pallets/eq-bridge` (native-asset transfer wrapper). `DestinationId = 0` (Ethereum),
  `AdminOrigin = EnsureRoot`, `BridgeManagementOrigin = EnsureRootOrTwoThirdsTechnicalCommittee`.
- Chain spec genesis: `chain_bridge: Default::default()` (relayers/resources were set by governance
  after genesis; not recoverable without a node).
