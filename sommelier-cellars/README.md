# C2-28 — Sommelier cellars / gravity module "dust": live-state assessment

**Campaign:** zombie-hunt II (C2-28, bounded "context" entry) · **Chain:** `sommelier-3` (Cosmos) + Ethereum/L2 cellar contracts · **Date of work:** 2026-10-09
**Status:** read-only research. No transactions signed or sent on any network. No fork PoC is applicable (this is a Cosmos module-balance question); verification is live LCD/ABCI state + exact-version source + a reproducible CI evidence run. No secrets used — all endpoints are keyless public.

---

## 1. TL;DR

| Target | Live extractable (unprivileged, E-U) | Why closed / not a prize | Latent risk |
|---|---|---|---|
| **Gravity module escrow** `somm16n3lc7cywa68mg50qhp847034w88pntq22vzye` | **$0.00** | Holds **36,864,615.016774 SOMM** (only denom) — exactly equal to the Ethereum ERC-20 SOMM total supply: it is the 1:1 bridge collateral for the wrapped token, not residual cash. 0 unbatched sends, 0 pending batches; only senders can cancel (none pending); no gov sweep message exists. The one relevant bridge bug (GHSA-4vf2-m5pw-3r3r, batch-timeout double-spend race) is fixed in the live v10.0.2. | None live. Outgoing bridge dormant since send ID 858 (~height 24.59M) |
| **Cellarfees module** `somm1hqf42j6zxfnth4xpdse05wpnjjrgc864vwujxx` | **$0.00** | **$2,169.00** in USDC/FRAX/stETH/USDT — below the $10,000 auto-auction threshold. `proceeds_portion = 1.0` sends the whole balance to a hard-coded 2-of-2 multisig (`somm1rvu9w27sstm2z7jgyq7kll0hfj4fdhsgnw0tat`) once triggered; not redirectable by gov, not takeable by anyone. | None |
| **Community pool** (distribution module) | **$0.00** | **110,069,732.502057 SOMM ≈ $37,882.02 paper** — gov-only (`MsgCommunityPoolSpend`); capture closed per C2-08 corrected economics + live refresh (solo capture ≥ bonded 71,464,846.36 SOMM ≈ $24,596 paper; public DEX float 2,094,342 SOMM = 2.93% of need; v10 PoA bloc veto-proof). CP dump exits ~$0.5–1k. | Foundation validator exit → ~$7.7k capture (C2-08) |
| **Cork-managed cellars** (strategy contracts) | **$0.00** | **≈$1,186,275 gross** live (Ethereum 36 cellars $996,443.70 + Arbitrum $158,016.68 + Optimism $31,814.82 + Scroll dust) — depositor funds in Sommelier Cellar vaults (self-service withdrawals, H-O), not protocol residual. Scheduling is authority-gated to a single EOA (`somm1lcsjy2d5s33h0sddd8lpuqvwyz5ruz7ju4aeqa`); no scheduled corks pending. No unprivileged drain path demonstrated. | CorkAuthority single-key compromise (P) |
| Other module accounts (auction, axelarcork, pubsub, fee_collector, gov) | **$0.00** | Empty at the pinned height. | — |

**Total live extractable by an external unprivileged attacker now: $0.00 (high confidence).**
The corpus's "gravity module dust" note is directionally right about there being no prize, but the balance itself is not dust: **36.86M SOMM is the live backing of the entire circulating ERC-20 SOMM supply** (§3.1). Nothing in this finding is unprivileged-extractable; the only value a *captured governance* could reach remains the community pool (closed in C2-08), and the only real key risk is the CorkAuthority EOA over depositor vaults (P, not E-U).

---

## 2. Scope, endpoints and heights

| Item | Value |
|---|---|
| sommelier-3 latest height at snapshot | **28,183,103** (2026-10-09T14:40:24Z); gov store read at 28,183,210; CI refresh 28,183,408 |
| LCD used | `https://sommelier-api.polkachu.com` (keyless) |
| CometBFT RPC used | `https://sommelier-rpc.polkachu.com` (ABCI store queries) |
| Ethereum RPC used | `https://ethereum-rpc.publicnode.com` (block 26,155,618 for the ERC-20 reads) |
| sommelier-3 node version | **v10.0.2** (commit `9788f65d3cb0`), Cosmos SDK v0.47.15, ibc-go v7.10.0, no wasm (verified in C2-26/C2-08) |
| SOMM price | **$0.0003441638** (DefiLlama `coingecko:sommelier`, 2026-10-09) |

All sommelier-3 queries were pinned with the `x-cosmos-block-height` header where the endpoint supports it; gravity store reads were taken at the RPC's latest committed height (recorded in `ci-out/state.json`).

---

## 3. Live-state assessment (exact reads)

### 3.1 Gravity module — the "dust" is actually bridge collateral

`somm16n3lc7cywa68mg50qhp847034w88pntq22vzye` (module account `gravity`, permissions `minter,burner`):

- Balance: **36,864,615,016,774 usomm = 36,864,615.016774 SOMM** — the *only* denom held (h 28,183,103; stable across 28.17M–28.18M).
- **The invariant:** the Ethereum ERC-20 SOMM `0xa670d7237398238de01267472c6f13e5b8010fd1` (6 decimals, symbol "somm") `totalSupply()` = **36,864,615,016,774** — an exact 1:1 match with the module balance (eth_call at block 26,155,618; Blockscout shows the same supply, 1,208 holders).
- Meaning: `x/gravity` maps `usomm ↔ 0xa670…0fd1` (store prefix `0x10`: `1075736f6d6d → a670d7237398238de01267472c6f13e5b8010fd1`). Cosmos-originated bridge-outs **lock** the usomm in the module account (`createSendToEthereum`, `x/gravity/keeper/pool.go`); bridge-ins **release** it to the recipient (`SendToCosmosEvent` handler). The module balance is therefore the outstanding wrapped-supply backing, not leftover fees or unclaimed residue.
- Pending state: unbatched `SendToEthereum` store prefix `0x07` is **empty (0 entries)**; outgoing-tx prefix `0x06` holds **only 72 `SignerSetTx` entries — no `BatchTx` (0x02) and no `ContractCallTx` (0x03)**. Counters: last send ID **858**, last batch nonce **805**. Last SOMM batch was created at Cosmos height **23,353,970** (nonce 803, send 856); last WETH batches at heights 24,586,090/140 (nonces 804/805, sends 857/858) — the outgoing path has been dormant for ~3.6M blocks. There is nothing pending for a sender to cancel and nothing for a third party to touch.
- The one live bridge risk in this area — **GHSA-4vf2-m5pw-3r3r**: outgoing-transaction timeout cleanup could read a height advanced by `MsgEthereumHeightVote` consensus independently of attestation, cancel and re-queue transactions already paid out on Ethereum (escrow double-spend). It is **fixed in gravity-bridge v6.1.0, shipped in the live v10.0.2** (v10 release notes; chain runs v10.0.2). No pre-fix path remains.
- Governance movability: none. A governance proposal cannot spend a module account directly; the only CP-related bridge message (`CommunityPoolEthereumSpendProposal`, `x/gravity/keeper/proposal_handler.go`) spends the **community pool** (feePool) — it does not touch the gravity escrow. Even a captured gov gets $0 from this account.
- Note: `gravity` params read `bridge_ethereum_address = 0x000…0` (unset; used only for event attributes in v6.1.0 — it does not gate bridge accounting).

### 3.2 Cellarfees module

`somm1hqf42j6zxfnth4xpdse05wpnjjrgc864vwujxx` (cellarfees "fees account", from `QueryModuleAccounts`):

| Denom | Amount | USD (module's own valuation) |
|---|---:|---:|
| `gravity0xA0b869…eB48` (USDC) | 1,551.368029 | $1,551.37 |
| `gravity0xae7ab9…7fE84` (stETH) | 0.15 | $611.68 |
| `gravity0x853d95…b99e` (FRAX) | 5.805927 | $5.81 |
| `gravity0xdAC17F…1ec7` (USDT) | 0.143044 | $0.14 |
| **Total** | | **$2,169.00** |

Module params (v2, h 28,183,103): `auction_interval = 15000`, `auction_threshold_usd_value = 10000`, `proceeds_portion = 1.000000000000000000`, `last_reward_supply_peak = 0`, `apy = 0`.

Mechanics (`x/cellarfees/keeper/abci.go`, v10.0.2): every 15,000 blocks the BeginBlocker checks each non-usomm fee balance; if its USD value ≥ $10,000 it sends `proceeds_portion` (here: **all of it**) to the hard-coded `proceedsAddress = somm1rvu9w27sstm2z7jgyq7kll0hfj4fdhsgnw0tat` (`x/cellarfees/keeper/cellarfees.go`). That address is a **2-of-2 LegacyAmino multisig** (account 61-adjacent; pubkeys on file in `ci-out/raw`), currently holding 99.993555 SOMM. Below threshold the balance simply accumulates. Not gov-redirectable (the destination is a code constant), not callable by an attacker.

### 3.3 Community pool, distribution and governance

- Community pool (`/cosmos/distribution/v1beta1/community_pool`): **110,069,732.502057 SOMM** ≈ **$37,882.02 paper**. (An IBC denom of 2 units is dust.)
- Distribution module account balance: 113,514,090.60 SOMM = CP + ~3.44M SOMM of outstanding validator rewards not yet withdrawn; `MsgCommunityPoolSpend` is bounded by the feePool DecCoins (`DistributeFromFeePool` SafeSub), not the account balance — the excess is unreachable.
- Live gov params (ABCI `/store/gov/key` `0x30`, h 28,183,210): `min_deposit 5,000 SOMM`, `max_deposit_period/voting_period 2 days`, **`quorum = 0.5`**, `threshold = 0.5`, `veto_threshold = 0.334`, `burn_vote_veto = true`. This independently confirms C2-08's quorum.
- **Capture economics (reuse C2-08 corrected, refreshed live):** solo capture stake ≥ current bonded = **71,464,846.361922 SOMM ≈ $24,595.61 paper** (the attacker's own stake enters the quorum denominator); the entire public DEX float is **2,094,342 SOMM = 2.93% of that need** (no CEX listing); the v10 PoA bloc (Foundation + 3 validators, power floor 0.67) holds ~73.94% of bonded → veto-proof; June-2026 prop 173 was rejected (22.1% turnout, 14.62M vetoed). If a capture did pass, the CP's realistic DEX exit is ~$0.5–1k (C2-08). Net: **executable capture value $0**.
- Other module accounts at the pinned height: `auction` (empty), `axelarcork` (empty), `pubsub` (empty), `fee_collector` (empty), `gov` (empty).

### 3.4 Cork-managed cellars (strategy contracts) and the CorkAuthority

The cork v2 module (Ethereum) manages **36 cellar IDs**; axelarcork (Axelar-routed) manages **1 on Optimism (10), 4 on Arbitrum (42161), 1 on Scroll (534352)**. Live values (Blockscout balances + DefiLlama prices + on-chain spot checks):

| Venue | Cellars | Live value | Top holdings (on-chain verified where noted) |
|---|---:|---:|---|
| Ethereum (cork v2) | 36 (35 funded) | **$996,443.70** | Real Yield USD `0x97e6E0a4…` **$450.0k** (450,719.32 aEthUSDT, balanceOf-verified); YieldETH `0xb5b29320…` $151.1k (60.652 WETH verified); Turbo RSETH `0x1dffb366…` $89.0k (32.457 rsETH); `0xfd6db501…` $77.9k (31.264 WETH verified); FeesAndReserves `0xF4279E93…` $65.7k (25,797.05 USDC verified); Real Yield BTC $39.9k; Real Yield USD-2 `0x991Fc0B9…` $29.0k; + 28 smaller vaults |
| Arbitrum (axelarcork) | 4 | **$158,016.68** | `0xC47bB288…` aWETH 53.81 = $133.7k; `0x392B1E69…` aTokens/stables ≈ $24.3k |
| Optimism (axelarcork) | 1 | **$31,814.82** | rETH 10.832 = $31.5k; wstETH 0.0858 |
| Scroll (axelarcork) | 1 | dust | WETH 0.0001 |
| **Total** | 42 | **≈ $1,186,275** | DefiLlama Sommelier TVL cross-check: $970,724 |

These are **user deposits in Sommelier Cellar vaults** (verified names/implementations on Blockscout, e.g. `CellarInitializableV2_2`; share-holder withdrawals are self-service — H-O). The protocol-side lever is the **`cork_authority`** param (`/sommelier/cork/v2/params` → `somm1lcsjy2d5s33h0sddd8lpuqvwyz5ruz7ju4aeqa`), rotatable only by `ParameterChangeProposal`. It is a **single-key secp256k1 EOA** (BaseAccount #61, sequence 191, 173,054.65 SOMM). In v10 both cork modules **fail closed** and only accept `signer == params.CorkAuthority` (`x/cork/keeper/msg_server.go:31`; `x/axelarcork/keeper/msg_server.go:38,84,177`); the legacy validator-supermajority path was removed. No corks are currently scheduled on any chain (`scheduled_corks` empty for cork v2 and chains 42161/10/534352).

Corpus correction: C2-08's "$209,492 cork cellars" prior figure is **not reproducible from the live managed list** — the live gross is ~$1.19M (see §5 caveats). Either way it is depositor-owned vault value reachable only by the vault code and, at most, the CorkAuthority key (P) — no E-U path is demonstrated.

---

## 4. What an attacker can / cannot do

**Cannot (all verified live):**
- Take anything from the gravity module: no public entry point moves its funds; outflows are only (a) valid `SendToCosmosEvent` bridge-ins, which require an observed, attested Ethereum lock event, or (b) sender-only refunds of *unbatched* sends (`cancelSendToEthereum` checks `sender == send.Sender`) — **there are zero pending sends/batches**.
- Spend the community pool without passing governance (50% quorum / 50% threshold / 33.4% veto with the v10 PoA bloc holding ~74% of bonded — veto-proof) and without finding ~71.5M SOMM of float that does not exist on any venue (2.09M total = 2.93%).
- Redirect or trigger the cellarfees: balance $2,169 < $10,000 threshold; destination is a code constant.
- Schedule calls to the managed cellars: authority-only, fail-closed, single-EOA gated; nothing queued.
- Exploit the fixed bridge race (GHSA-4vf2-m5pw-3r3r) — patched in the running v10.0.2.

**Could (privileged, not E-U):**
- Governance (P): spend the community pool to any address (~$37.9k paper; realistically ~$0.5–1k exit) — economically closed.
- CorkAuthority key-holder (P key risk): schedule arbitrary corks against managed cellars (~$1.19M gross exposure), bounded by each cellar's own code; a full per-cellar drainability audit was out of scope for this bounded entry (C2-08 did not claim one either).
- ERC-20 SOMM holders (H-O, self-service): bridge back to release usomm from the gravity escrow 1:1 — the bridge working as intended, not a residual.

**Costs:** none relevant — there is no positive-value path to cost out. (Gas/fees would only make any hypothetical capture worse.)

---

## 5. Verification & CI evidence

No fork PoC applies (Cosmos module balances, not an EVM exploit; and there is no candidate path to prove). Verification is:

1. **Live state reads** at pinned sommelier-3 heights (all raw JSON in `analysis/local/raw/` and `ci-out/raw/`): bank balances of every module account, gravity params + raw KV subspaces (`0x06`, `0x07`, `0x10`, `0x11`, `0x15` + counter keys), cellarfees v2 params/balances, cork v2 + axelarcork cellar IDs and scheduled corks, community pool, staking pool, supply; gov params via ABCI gov store.
2. **Cross-chain invariant check:** Ethereum `eth_call` `totalSupply()`/`decimals()` on `0xa670d723…0fd1` == gravity module escrow (boolean `gravity_escrow_equals_erc20_supply: true` in `ci-out/summary_ci.json`).
3. **Source review** of `github.com/peggyjv/sommelier v10.0.2` (cellarfees, cork v2, axelarcork, incentives, upgrade handler) and `github.com/PeggyJV/gravity-bridge module/v6.1.0` (pool/batch/proposal handler + GHSA-4vf2-m5pw-3r3r fix), plus the v10.0.2 release notes.
4. **On-chain spot checks** of the top cellar holdings (balanceOf calls, §3.4).
5. **CI evidence run** (public runner, keyless endpoints): `ci/evidence.py` regenerates everything into `ci-out/` — run URLs recorded below.

```
CI run(s):  https://github.com/kingmariano/ca-zombie-ci/actions/runs/37951763164   (conclusion: success; artifact result-sommelier-cellars)
```

---

## 6. Verdict and residual / latent risk

**Verdict: E-U $0.00 (high confidence).** The gravity module balance is bridge collateral whose Ethereum-side counterpart (the ERC-20 total supply) matches it 1:1; it is not extractable, not gov-movable, and nothing is pending. Cellarfees are $2.2k below their auto-flow threshold and destined to a fixed multisig. The community pool is gov-only and the capture is closed (C2-08 corrected economics, re-verified quorum/float/bloc). The managed cellars hold ~$1.19M of depositor funds with a single-EOA authority that is dormant and fail-closed. There is no unprivileged extraction path anywhere in this finding.

**Residual / latent risk (all P, none E-U):**
- CorkAuthority EOA key compromise → arbitrary scheduled calls against managed cellars (~$1.19M gross depositor value; impact bounded by cellar code — not audited here).
- Foundation validator exit (breaks the 73.94% PoA bloc) → capture becomes feasible at ~$7.7k (C2-08 latent estimate; float still 2.93% of solo need unless liquidity appears).
- Future bridge activity re-activates the escrow's operational surface; the live version is patched (GHSA-4vf2-m5pw-3r3r) but any *new* gravity vulnerability would be a fresh review target.

**Blockers for further extraction:** none needed — there is no path.

---

## 7. Methodology, caveats, files

**Method:** enumerate module accounts from `/cosmos/auth/v1beta1/module_accounts`; read balances; read gravity state from the raw KV store via ABCI `subspace` queries (decoded `kv.Pairs` protobuf) rather than the unserved gRPC-gateway routes; verify the bridge invariant cross-chain; price with DefiLlama + Blockscout; review the exact deployed source versions; cross-check the cork/axelarcork managed lists and authority gating in source.

**Caveats:**
1. **C2-08 figure discrepancy:** the tracker's "$209,492 cork cellars" is not reproducible from the live cork v2/axelarcork managed list; live gross is ~$1.19M. My number counts *all* managed cellars' token balances (including vaults C2-08 may have excluded, e.g. Real Yield USD $450k). Both are depositor funds; neither is E-U.
2. **USD paper values** use the live DefiLlama SOMM price $0.0003441638; the *realizable* value of large SOMM balances is far lower (DEX float 2.09M SOMM — C2-08).
3. **Cellar value ≠ drainable value:** the ~$1.19M is vault TVL; what the CorkAuthority key could actually move depends on each cellar's code (not audited in this bounded entry).
4. **Blockscout rate limits** blocked the CI re-scan of Arbitrum cellars (HTTP 403); the Arbitrum/Optimism figures come from the session-time scan saved in `analysis/local/raw/` (consistent with DefiLlama per-chain TVL: Arbitrum $158.3k, Optimism $31.9k).
5. sommelier-3 public LCDs do not serve `/cosmos/gov/v1/params`; gov params were read from the gov store via ABCI (h 28,183,210) and are consistent with C2-08.
6. Historical sommelier-3 state is pruned on public nodes; all balances are single-height snapshots (heights recorded).

**Files:** `analysis/` (scripts + raw state + priced cellar tables), `ci/` (`evidence.py`, `run.sh`), `ci-out/` (CI evidence: `state.json`, `summary_ci.json`, `cellar_balances_priced.json`, `raw/`), `summary.json` (machine-readable).

*Research is informational; verify all data on-chain before acting.*
