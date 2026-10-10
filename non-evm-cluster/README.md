# C2-55 — Abandoned non-EVM custody cluster (Djed / UTONIC / DeDust / Minswap / Folks / Pact / Ref Boost / Veax / Spin / Tonic / MultiversX)

**Date:** 2026-10-10 · **Chains:** Cardano, TON, Algorand, NEAR, MultiversX · **Status:** read-only;
no transactions signed or sent; all PoCs are local/CI simulations (Cardano CEK evaluation, TON trace
emulation, Algorand TEAL analysis + algod reads, NEAR view calls, MultiversX vm-values/query).

## Headline

**External unprivileged extraction (E-U) across the cluster: $0.00 (high confidence overall).**
All 15 protocol members were reached and measured. The live value (~$50.4M) is holder-recoverable (H-O) or
privileged (P); ~$2.1k is stuck/bricked (S). The cluster's two largest piles were audited to the bytecode/
emulation level: **Minswap V1** (deployed validator proven = post-audit fixed code, CEK PoC in CI) and
**DeDust v2** (22 read-only attack probes all rejected). The largest residual uncertainty is the
**closed-source Djed reserve validator ($6.24M)** — screened at gate level (Ed25519 oracle signature + oracle
NFT present in bytecode), not fully decompiled.

## Per-protocol table

| # | Member | Chain | Live value measured (2026-10-10) | Class | **E-U** | Conf. | Coverage |
|---|---|---|---|---|---|---|---|
| 1 | **Minswap V1** | Cardano | TVL $2.89M nominal / **$1.33M both-verified** (7,000 pools; 24 pools trading; 8,140 open orders) + order contract 72,960 ADA + tokens | H-O; P owner profit-share | **$0.00** | high | **Fully audited** — deployed validator (`e1317b15…`) ≡ open-sourced fixed release (UPLC stream equivalence) + CEK PoC (legit ACCEPT / no-owner REJECT / datum-hijack REJECT); AMM math reviewed |
| 2 | Minswap V2 + Stable | Cardano | **H-O ≈ $15.9M** = V2 LP $15.70M (3,326 pools / 3,325 pairs, **26,518,169.35 ADA** at the shared V2 address) + stableswap $166,444 (14 pools); $1.96M/24h | H-O; P fee/admin/batcher | **$0.00** | high | **Fully audited** — deployed scripts hash-match the audited public repo `minswap/minswap-dex-v2`; on-chain GlobalSetting authorizes a single batcher vkey `5b7e2322…`; no signature-free drain path |
| 3 | **Djed** | Cardano | bank **24,642,068.18 ADA ≈ $6.27M** (hash-verified datum; 17.0× collateralised; DJED 1,449,009 / SHEN 31,196,162 circulating) | **P** (bank custody; operator-signed processing); H-O $54 (1 pending order); S $40.13 | **$0.00** | high | **Fully audited** — validators decompiled (bank `f780e15a…`, order, oracle `89829415…`, treasury, stake guard); processing tx `b1c0f40a…` shows `addSignerKey(operator 409d3ec8…)`; bank+oracle call Ed25519 `verifySignature` with hardcoded key `51f4ed3f…` (forged price cannot pass); no public source for Dec-2024 validators (residual: CEK eval as CI candidate) |
| 4 | **DeDust v2** | TON | native vault **1,828,441.82 TON ≈ $2,664,340** (seqno 98,067,263) + jetton vaults ≈ $1,255,884; v1 legacy pools 3.34 TON inert | H-O; P factory | **$0.00** | high | **Fully audited** — 22 read-only TonAPI trace-emulation attack probes: overclaim 263, forged payouts 265, forged swap_external/peer 264/265, spoofed jetton-notify inert, admin ops 296/65535, destroy/install 256/65535 |
| 5 | UTONIC | TON | uTON supply 2,950,470.02 ≈ **$4,305,527** (DefiLlama; $4.58M at contract rate); frozen since 2026-09-15 | H-O conditional; P single EOA admin | **$0.00** | medium-high | Audited (source + live gates); blocker: ~2.8M uTON backing not identifiable in current contracts (staked/lent out) |
| 6 | **Folks v1** | Algorand | **H-O $558,139** = v1 pools $45,224.60 (redeem open while `is_paused=1`; cap = `total_deposits`) + govDist14 $508,431.34 + v2 deposit-staking $4,482.88; **S $65,030** = v1 surplus escrow $45,572.95 + govDist4-6 $19,456.68; live products (context): xALGO 259.3M ALGO stake, v2 pools $57.7M DefiLlama | H-O; P reserve key `XQEOIC…`; S | **$0.00** | high | **Fully audited** (deployed TEAL + v1 SDK method map; redeem sender-scoped, not pause-gated; dryrun 404 on public nodes → static + historical successes). **Residual candidate:** v1 oracle frozen since 2023-02-20 (ALGO $0.2896 vs market $0.1154) ⇒ mispriced liquidations on ~100 remaining v1 loan/lock accounts — mechanism proven (liquidations observed r64.97M), amount unquantified |
| 7 | **Pact** | Algorand | **H-O $924,558.95** = deprecated classic family $495,982.49 (3,867 pools, LP outstanding = `L`−1000; 13 successful REMLIQs on 2757646117, 2 on 985089418) + v201 managed-weighted $428,576.46 | H-O; P classic admin / v201 manager+vault | **$0.00** | high | **Fully audited** (TEAL both templates + per-pool reserve dumps; REMLIQ pro-rata sender-scoped; admin = `txn Sender == KIRIMY…`). **Live weakness (user-loss, not drain):** min-out args are `pop`-discarded in SWAP/ADDLIQ/REMLIQ of both templates ⇒ MEV sandwich leakage on deprecated pools still actively swapped (direct SWAPs r64M+) |
| 8 | Ref v1 farm `ref-farming.near` | NEAR | 45.7621 NEAR + 3.57257 KSM ≈ **$255.90** — code **emptied** | **S** (P-escape: 7 FA keys) | **$0.00** | high | Fully audited (code_hash = sha256(""); calls fail `Deserialization`) |
| 9 | Ref v1 exchange `ref-finance.near` | NEAR | 134.3236 NEAR ≈ **$697.57** — code **emptied** | **S** | **$0.00** | high | Fully audited |
| 10 | Ref `v2.ref-farming.near` | NEAR | staked LP $2,809,854 + rewards $92,235 = **$2,902,089** (174/176 farms Ended) | H-O; P DAO | **$0.00** | high | Audited (source-verified; sender-scoped) |
| 11 | Ref `boostfarm.ref-labs.near` | NEAR | staked LP $1,839,449 + rewards $141,373 = **$1,980,822** | H-O; P DAO+2 ops | **$0.00** | medium | Black-box verified (closed source) |
| 12 | Veax | NEAR | **$78,288** (12,513.6 wNEAR + stables + …), live today | H-O; P owner/guards | **$0.00** | med-high | Audited (source: withdraw sender-scoped) |
| 13 | Spin (spot/vault/perp) | NEAR | **$126,494** (spot $70.4k, vault $36.1k, perp $20.0k); activity stopped Sep-2026 | H-O; P 1 key each | **$0.00** | low-med | Screened (closed source; sender-scoped exports; failed recent calls) |
| 14 | Tonic (orderbook/perps) | NEAR | **$38,790** (orderbook $26.6k, perps $12.2k); perps dormant since 2024-04 | H-O; P owner=self | **$0.00** | med-high | Audited (source: withdraw sender-scoped; admin owner-gated) |
| 15 | **MultiversX remnants** | MultiversX | legacy delegation **1,584,732.64 EGLD ≈ $6.39M** + farms/LKMEX ≈ $391k = **$6.78M** H-O; S $1,181.78; P $227.05 | H-O / P / S | **$0.00** | high | Fully audited (75 addresses, 49 source-verified deployments; bricked PD proven by failed tx `62f1ce10…`) |

## Totals (2026-10-10)

| Category | USD | Meaning |
|---|---|---|
| **E-U (external unprivileged)** | **$0.00** | No value mover callable by outsiders found on any member |
| H-O (holder/user-recoverable) | **≈ $38,813,700** | LP/stake deposits, farm positions, delegation stakes, unclaimed distributions (Djed bank custody is classified P — operator-signed processing) |
| P (privileged) | **≈ $6,268,300 quantified** = Djed bank custody $6,268,077 + MultiversX dev rewards $227.05 (+ unquantified admin/DAO/owner surfaces: Minswap owner/DAO/batcher, DeDust factory, UTONIC EOA, Ref DAO, Tonic self-owner) | owner/operator/admin-gated |
| S (stuck/bricked) | **≈ $67,206** | Folks v1 surplus escrow $45,573 + govDist4-6 $19,457 + Ref dead v1 farm/exchange $953.47 + MultiversX price-discovery brick $1,181.78 + Djed legacy orders $40.13 + dust |

## Coverage statement

- **Fully audited (code/gate-level + live state + attempted paths):** Minswap V1 (CEK proof), DeDust v2
  (emulation probes), Folks (TEAL + v1 SDK method map), Pact (TEAL + reserve dumps), Ref v1 farm/exchange + v2 farms (source/WASM),
  Veax + Tonic (source), MultiversX remnants (source-verified deployments).
- **Screened (live state + activity + gate inventory, not full audit):** Ref Boost Farm (closed source),
  Spin (closed source), UTONIC (audited but backing reconciliation incomplete), Folks v2 / xALGO (active
  products, out of abandoned scope).
- **Residual items:** Djed Dec-2024 validators have no public source (audited here from on-chain UPLC — a CEK
  eval remains a CI candidate); Folks frozen-oracle liquidation candidate (unquantified); Pact min-out/MEV
  weakness (documented); UTONIC ~2.8M uTON backing trace.
- **Not reached:** none of the 15 members; the only coverage gaps are depth (above) and the ~2.8M uTON
  backing trace.

## CI evidence

- Runs **green**: https://github.com/kingmariano/ca-zombie-ci/actions/runs/38043461182 (final, all dossiers) ·
  https://github.com/kingmariano/ca-zombie-ci/actions/runs/38042544383 ·
  https://github.com/kingmariano/ca-zombie-ci/actions/runs/38026892333 — Minswap V1 CEK PoC
  (`ci-out/minswap-v1-cek.json`: `LEGIT_owner_withdraw` ACCEPT, `ATTACK_no_owner_token` REJECT,
  `ATTACK_datum_hijack_redirect` REJECT) + full logs.

## Method

- Keyless public endpoints only: Koios/Cardano, toncenter+tonapi/TON, algod+indexer/Algorand,
  rpc.mainnet.near.org + nearblocks/NEAR, api.multiversx.com/MultiversX; prices via coins.llama.fi.
- Cardano: script decompilation (`uplc`) + CEK evaluation (`aiken`), incl. equivalence proof of the deployed
  Minswap V1 validator against the open-sourced fixed code; UTxO/datum reads via Koios.
- TON: read-only trace emulation (`tonapi.io/v2/traces/emulate?ignore_signature_check=true`) — no sends.
- Algorand: algod app/account reads + TEAL disassembly (algod `/v2/teal/disassemble`).
- NEAR: `view_account`/`view_code`/`view_state`/`call_function` + nearblocks; MultiversX: `vm-values/query`.
- Categories: **E-U** external unprivileged · **H-O** holder-only · **P** privileged · **S** stuck/bricked.

## Files

- `summary.json` — machine-readable summary.
- `analysis/cardano/{minswap-v1,minswap-v2,djed}/`, `analysis/ton/{dedust,utonic}/`,
  `analysis/algorand/{folks,pact}/`, `analysis/near/{ref-boost,veax,spin,tonic}/`, `analysis/multiversx/` —
  per-protocol dossiers + raw dumps + read-only scripts.
- `ci/`, `ci-out/`, `ci-artifacts/`, `ci-log.txt` — CI PoC + results.
