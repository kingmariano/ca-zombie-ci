# Orbit Chain / Silicon Network — live unprivileged-extraction assessment (L-1)

**Date:** 2026-10-04 (UTC) · **Chains:** Silicon Network L2 (chain id 2355, Polygon CDK validium) + Ethereum L1
**Status:** read-only; fork-verified only; no mainnet transactions. All state read at explicit blocks below.

---

## 1. TL;DR

| Target | Live value | E-U extractable by unprivileged attacker | Why closed / open | Latent risk |
|---|---|---|---|---|
| Silicon canonical bridge (wrapped assets on L2 + L1 shared pool) | **≈ $10.45M** on L2 (priced) | **$0** | Claims require a GlobalExitRoot present in the GER manager (aggregator-posted) + two merkle proofs + nullifier; forged claims revert (`GlobalExitRootInvalid`). Deposits/mints gated the same way. | Exits depend on the permissioned aggregator; if it stops before 2026-12-31, unexited value becomes S. Shared L1 pool must cover all chains' claims. |
| Orbit Chain ORC staking on Silicon (`OrbitVoting` proxy) | **40.23M ORC ≈ $20.2K** staked+pending (article's 94.91M double-counts delegated power) | **$0** | `unvoting()` checks the caller's own delegated stake; `claimUnvoting()` pays only `msg.sender`'s own queue after a 7-day lockup. Attacker calls revert (`amount is too big` / `all claimed`). | Holder-side UI gap only; 7-day lockup + network shutdown timing. |
| OrbitGovernor (ORC treasury) | 100,000 ORC ≈ $50 | **$0** | `emergencyTransfer`/`execute`/setters are `not owner` (owner = 2-of-4 multisig via proxy admin). | Multisig compromise = P path. |
| Inflation contract | 877,927 ORC ≈ $441 | **$0** | `distribute()` is permissionless but transfers only inflation→Voting; caller receives nothing (traced). | None found. |
| Native (L2-issued) Silicon tokens | unquantified, mostly illiquid | **$0** | Not bridgeable; depend on in-network DEX liquidity. | Holder value can evaporate (S) as liquidity dies. |

**Total live extractable by an external unprivileged attacker: $0.00** (headline confidence: **high** for the two named targets; medium-high overall pending the Orbit Bridge side-check).

**Holder-recoverable (H-O) during the forced-exit window: ≈ $10.45M** (Silicon wrapped assets + net ETH) + **≈ $20.2K** (ORC staking) — all self-service, deadline-bound (2026-12-31 12:00 KST).

---

## 2. What this finding actually is

The lead ("$9.75M forced exit by 2026-12-31; 94.91M ORC staked, no UNVOTE path; MED-HIGH") resolves, on live state, to:

1. **A dying but still-live CDK chain.** Silicon L2 is producing blocks (~2 s) and the canonical exit pipeline works in both directions as of 2026-10-04 (see §5.4). The $9.75M is user-owned wrapped value, not protocol-owned funds. It is recoverable by holders through the canonical bridge, not extractable by attackers.
2. **A UI gap, not a contract lock.** `OrbitVoting.unvoting(address delegatedVoter, uint256 amount)` and `claimUnvoting()` exist and work; a real user unvoted 209,527 ORC on 2026-10-04 via a direct contract call (tx `0x20112650b68c…`). The Seoul Economic Daily complaint ("no UNVOTE function on the ORC governance site") is a front-end/UX problem. On-chain, the staked ORC is **H-O** (holder self-service, 7-day lockup), not S.
3. **No unprivileged extraction path was found** in either target. Every candidate was tested on a fork and reverts or pays nothing to the caller.

---

## 3. Deployments (verified)

### Silicon L2 (chain id 2355, gas token ETH)
| Role | Address | Code | Notes |
|---|---|---|---|
| Canonical bridge (proxy) | `0x2a3DD3EB832aF982ec71669E178424b10Dca2EDe` | 2,515 B proxy | EIP-1967 impl `0x5ac4182a1dd41aeef465e40b82fd326bf66ab82c`; admin `0x0F99738B2Fc14D77308337f3e2596b63aE7BCC4A`; `networkID()=10` |
| GlobalExitRoot L2 | `0xa40d5f56745a118d0906a34e69aec8c0db1cb8fa` | 2,227 B | older `PolygonZkEVMGlobalExitRootL2` (child-confirmed) |
| Wrapped ORC (canonical) | `0x37908ffdEf18aDD36518e781a9a77C2C6f4A4260` | 5,802 B | `TokenWrapped::onlyBridge` — mint/burn only by the L2 bridge |
| OrbitVoting (proxy) | `0x33fa9a4f2C06de9bD80A34663C72C797E257D3d9` | 1,255 B proxy | impl `0x9472fd47b29d364b286c1d5e0e6032fbd921f60b`; proxy admin `0x21941c8e8b376248b91f53f3b2660592852082ed` |
| OrbitGovernor (proxy) | `0x3d0FD4bB3eA78657727eD7d20d9195288EaBC7dF` | 1,255 B proxy | impl `0x15c7b8357152a36bb4165f6a79a95cf5c1108195`; version `Governance20250523`; admin `0x6563e80f3d5576369f9a30988e69d224d0004bac` |
| Inflation | `0xd4B19CaA9d2817930402FF60666d41377B411D9c` | proxy→`0xd6fc1782…` | holds 877,927 ORC |
| Extension | `0x68EAF006D3420887De399EB8BA5A531279e7F59C` | — | holds 0 |
| Timelock | `0xBBa0935Fa93Eb23de7990b47F0D96a8f75766d13` | 9,920 B | OZ TimelockController, `getMinDelay()=864000` (10 d); holds 0 |
| Proxy admins' owner | `0xFCf517857EFE85c780fD5DB9a0F63cbF844d7b33` | 17,333 B | **2-of-4 multisig** (`required()=2`; owners `0xD6645fA1…`, `0x6048cF52…`, `0x935fBC2E…`, `0xdF6eD5C2…`) |
| Sequencer / Admin / Aggregator (docs) | `0x47ed9538…` (Silicon), `0xef5D7af5…` (Silicon), `0x20A53dCb…` (Polygon Labs) | EOAs | aggregator posts exit roots |

### Ethereum L1
| Role | Address | Notes |
|---|---|---|
| Canonical bridge (shared, proxy) | `0x2a3DD3EB832aF982ec71669E178424b10Dca2EDe` | impl = **AgglayerBridge** `0x66E0120e3c965552a89AcC37b03f762624baC5Ad`; shared by all CDK chains |
| RollupManager | `0x5132A183E9F3CB7C848b0AAC5Ae0c4f0491B7aB2` | Silicon rollupID = 10 |
| GlobalExitRoot L1 | `0x580bda1e7a0cfae92fa7f6c20a3794f169ce3cfb` | continuously updated |
| Silicon validium proxy | `0x419dcd0f72ebafd3524b65a97ac96699c7fbebdb` | PolygonTransparentProxy |

---

## 4. Live state (blocks)

**Silicon block 21,251,675** (2026-10-04 ≈21:44 UTC; earlier capture 21,251,421/21,251,631/21,251,242 — all consistent) · **Ethereum block 26,121,900**.

### 4.1 L2 wrapped-token supply (canonically bridged, origin network 0 = Ethereum)
| Token | Wrapped address | Supply | Price (DefiLlama, 2026-10-04) | USD |
|---|---|---|---|---|
| USDC | `0xa8ce8aee…c035` | 2,653,285.47 | $0.99997 | $2,653,207 |
| USDT | `0x1e4a5963…d41d` | 1,821,645.27 | $0.99989 | $1,821,445 |
| WBTC | `0xea034fb0…08e1` | 32.1584 | $86,231.26 | $2,773,059 |
| DAI | `0xc5015b9d…1fd4` | 567,525.06 | $0.99998 | $567,514 |
| ORC | `0x37908ffd…4260` | 327,435,741.47 | $0.0005026 | $164,562 |
| HANDY | `0x4E9FC4b5…FC9D` | 21,423,826.20 | $0.00155 | $33,215 |
| ORBS | `0x10E04Ae9…5740` | 2,802,219.01 | $0.00739 | $20,717 |
| BiFi | `0xC47a18ba…6Ea1` | 21,531,853.48 | $0.000844 | $18,176 |
| MATIC | `0xa2036f05…18d0` | 139,979.06 | $0.10995 | $15,391 |
| TON | `0x09E11b5E…3F23` | 38,889.57 | $0.38320 | $14,902 |
| GALA | `0xd3131E4A…311c` | 4,609,629.88 | $0.00252 | $11,618 |
| + 63 smaller/illiquid Ethereum-origin wrapped tokens | — | — | — | ≈ $59,000 priced; rest unpriced |
| **Priced subtotal** | | | | **$8,102,804** |
| Net ETH bridged (CDK gas pool delta) | L2 bridge `0x2a3D…2EDe` | 864.876 ETH | $2,718.99 | $2,351,609 |
| **Total live (priced)** | | | | **≈ $10,454,413** |

Cross-check: L2Beat reported TVS $8.97M on 2026-10-04 (and $9.75M at the Sep-2 shutdown notice); our higher figure is explained by live ETH/WBTC prices and includes small tokens. 75 wrapped tokens were deployed by the bridge; 74 are Ethereum-origin (one is origin network 13). *(Note: the L2 bridge's raw `eth_getBalance` is `0xffffffffffffffd1…` = 2^128 − 864.876 ETH, the standard CDK gas-token pre-mint at genesis; the delta is the net bridged ETH and matches L2Beat's $2.08M at the shutdown price.)*

### 4.2 L1 shared bridge (all CDK chains, not Silicon-only)
USDC 4,621,571 · USDT 7,058,188 · WBTC 47.04 · ETH 4,477.77 · DAI 1,214,011 · ORC 331,239,726. Silicon's claims are fully covered by this pool today (USDC 2.65M ≤ 4.62M, USDT 1.82M ≤ 7.06M, WBTC 32.2 ≤ 47.0, ETH 865 ≤ 4,478, DAI 0.57M ≤ 1.21M).

### 4.3 OrbitVoting (ORC staking)
- `totalStaking()` = 37,985,788.546 ORC · `totalPending()` = 2,246,622.663 ORC → **40,232,411 ORC locked**; contract holds 42,089,910 ORC (≈1.86M ORC undistributed rewards).
- `lockupPeriod()` = 604,800 s (7 d) · `minUnvotingAmount()` = 0 · `stakingToken = rewardToken` = wrapped ORC.
- 9+ delegated voters; voters with live stakes (5.1M, 201.9K, 33.76K ×5 …).
- The article's "94.91M ORC deposited" is the sum of per-validator displayed stakes, which double-counts delegated voting power. On-chain locked ORC = **40.23M ≈ $20.2K** at $0.0005026 (not $70.5K).

### 4.4 Governor / inflation
- Governor holds 100,000 ORC; `proposalCount()=1`; `proposalFee()=100,000 ORC`; `quorumVotesRate=4000`, `proposalThresholdRate=1000`.
- Inflation holds 877,927 ORC. `distribute()` trace: inflation → `transfer(Voting, …)`; caller receives nothing.

### 4.5 Exit-pipeline status (child-verified, `analysis/child_bridge/bridge_pipeline.md`)
- L2→L1: withdrawal #2523 claimed on L1 at block 26,118,655 (2026-10-04 11:21 UTC); #2522 at 11:31.
- L1→L2: deposit #264466 claimed on L2 at block 21,237,509 (08:48 UTC).
- Invariant: L2 bridge `getRoot()` == L1 manager `lastLocalExitRoot(10)` → all 2,524 recorded L2 bridge leaves are anchored on L1.
- GER updates continuous: 32 `UpdateL1InfoTree` events in ~24 h, last 22:14 UTC; last Silicon pessimistic certificate 11:06 UTC.
- No emergency state on L1 bridge, L2 bridge, or manager.
- 31 withdrawals in 7 d, 3 in 24 h; 9/600 recent withdrawals pending user-side claim (claimable, not stuck).

---

## 5. Attack-surface analysis (E-U)

### 5.1 Canonical bridge — forged claims (closed)
`AgglayerBridge.claimAsset/claimMessage` (L1 impl source read in full):
1. `destinationNetwork == networkID` (L1 = 0, L2 = 10);
2. `globalExitRootManager.globalExitRootMap(keccak(mainnetExitRoot, rollupExitRoot)) != 0` — GER must have been posted by the RollupManager (aggregator role `0x20A53dCb…`, Polygon Labs);
3. double merkle proof (local exit root + rollup exit root) and nullifier `_setAndCheckClaimed`.
A forged claim with zero roots/proofs reverts `GlobalExitRootInvalid` (PoC tests D2/D3). Creating a valid leaf requires burning/locking real assets in `bridgeAsset`. **No unprivileged forgery.**

### 5.2 Governance — ORC theft (closed)
- `unvoting(account, amount)` reverts `amount is too big` for any caller with no stake delegated to `account` (PoC B1) — it is self-only; a victim's stake cannot be touched.
- `claimUnvoting()` reverts `all claimed` for an attacker (PoC B2); the Yul shows it iterates `_voters[caller()]`'s queue and `transfer(caller(), amount)` only after `timestamp() >= record.ts + lockupPeriod`.
- `claimUnvoting(uint256)` / `claimUnvotingAll()` operate on the same caller-owned queue.
- `emergencyTransfer` / `emergencyTransferNative` / `execute` / `cancel` / setters revert `not owner` (PoC B3/B4). Owner = 2-of-4 multisig `0xFCf5…` via the proxy admins.
- `mint`/`burn` on wrapped ORC revert for non-bridge callers (`TokenWrapped::onlyBridge`) (PoC B5).
- `distribute()` is permissionless but pays the caller nothing (PoC C2; trace in `analysis/distribute_trace.json`).

### 5.3 Holder exit path (open, H-O)
PoC C1 proves the full lifecycle on a fork: registered staker → `unvoting(DV, 100 ORC)` → `vm.warp(+7 d)` → `claimUnvoting()` → ORC returned. This directly contradicts the "funds stuck, no UNVOTE" framing at the contract level; the gap is the official UI. (Real-world evidence: user `0x76f88c…` unvoted 209,527 ORC on 2026-10-04, tx `0x20112650…`.)

### 5.4 Forced-exit window — attacker paths (none)
- Withdrawals are paid to the `destinationAddress` fixed in the leaf; an attacker cannot redirect a victim's claim.
- The aggregator updates exit roots; front-running/sandwiching exit-root updates yields no profit.
- Buying discounted wrapped tokens and exiting is market arbitrage against panic sellers, not protocol extraction (and requires the exit pipeline to keep working).
- Residual systemic risk: the shared L1 pool must cover all chains' exits; the aggregator must keep posting until the deadline.

---

## 6. PoC / fork verification

Project: `poc/` (Foundry 1.7.1, solc 0.8.24). Vendored `lib/forge-std`. Fork-only; no mainnet writes.

| Test | What it proves | Result |
|---|---|---|
| `test_A1_l2_live_state` | chain live, networkID 10, wrapped ORC canonical, staking live | PASS |
| `test_B1_attacker_cannot_unvote_victim` | attacker `unvoting` reverts `amount is too big` | PASS |
| `test_B2_attacker_cannot_claim_unvoting` | attacker `claimUnvoting` reverts `all claimed` | PASS |
| `test_B3_attacker_cannot_emergency_transfer` | Governor `emergencyTransfer` reverts `not owner` | PASS |
| `test_B4_attacker_cannot_execute_governor` | Governor `execute` reverts `not owner` | PASS |
| `test_B5_attacker_cannot_mint_orc` | wrapped ORC `mint` reverts for attacker | PASS |
| `test_C1_holder_unvote_claim_lifecycle` | unvote → +7 d lockup → claim returns 100 ORC | PASS |
| `test_C2_distribute_permissionless_no_profit` | `distribute()` pays attacker nothing | PASS |
| `test_D1_l1_bridge_live_and_not_emergency` | L1 bridge holds USDC/USDT/WBTC/ETH; no emergency | PASS |
| `test_D2_l1_forged_claim_reverts` | forged L1 claim reverts | PASS |
| `test_D3_l2_forged_claim_reverts` | forged L2 claim reverts | PASS |

Local validation: B1/C1 PASS (gas 26,885 / 744,764). CI run: **see `ci-log.txt` and the run URL recorded below** (workflow `poc.yml`, repo `kingmariano/ca-zombie-ci`, branch `orbit-silicon`). CI also captures a timestamped state snapshot to `ci-out/live_state.json`.

```
CI run URL: <recorded in ci-log.txt / below>
```

---

## 7. Verdict

- **E-U: $0.00** (high confidence). No unprivileged caller can take bridge assets or staked ORC. All candidate paths are gated by GER proofs, self-only accounting, or owner checks, and were fork-tested.
- **H-O: ≈ $10.45M** Silicon wrapped assets + net ETH, plus ≈ $20.2K ORC staking — holder self-service, expiring 2026-12-31 12:00 KST.
- **P:** 2-of-4 multisig `0xFCf5…` can upgrade Voting/Governor and (via the proxy admin) change staking rules; the Agglayer bridge is upgradeable by the Polygon admin/security council (shared pool ≈ $28M+ across all CDK chains). Not attacker-reachable.
- **S:** anything not exited by the deadline (network termination), plus native L2 tokens with no exit liquidity. If the aggregator stops posting before the deadline, pending exits freeze (forward risk, not attacker profit).
- **Blockers to extraction:** aggregator-gated GER, self-only staking accounting, owner-gated admin, bridge-only mint.

## 8. Methodology, sources, caveats

- On-chain reads at pinned blocks (Silicon 21,251,675; Ethereum 26,121,900) via `rpc.silicon.network`, `silicon-mainnet.nodeinfra.com`, `ethereum-rpc.publicnode.com`; explorer API `api-scope.silicon.network` (swagger) and Blockscout for verified source; DefiLlama for prices (2026-10-04).
- Decompilation: heimdall-rs 0.9.2 (Voting impl, Governor impl, ORC token) + `debug_traceCall` traces (distribute, claimUnvoting).
- Caveats: ORC price is thin/volatile (Eulerpool ~$0.0005, Forbes/CMC differ); some wrapped tokens are unpriced (total may be slightly understated); `claimUnvoting` behavior verified via Yul + prestate trace; the child bridge report is incorporated in §4.5; Orbit Bridge (Ozys) side-check pending (see `analysis/child_orbitbridge/` when complete).
- The corpus claim "94.91M ORC staked" is corrected to **40.23M ORC** on-chain; "no UNVOTE" is corrected to **contract path works, UI gap**.

## 9. Files

- `analysis/read_state.py`, `state_dump_*.txt` — governance state
- `analysis/l1_bridge.py`, `l1_bridge_state.txt` — L1 balances/state
- `analysis/l2_bridge.py`, `l2_bridge_state.txt`, `tvs.py`, `tvs_out.txt` — L2 bridge + TVS
- `analysis/wrapped_tokens_explorer.json`, `wrapped_resolved.json` — 75 wrapped tokens
- `analysis/decompiled/voting_impl2/decompiled.yul`, `decompiled/gov_impl/decompiled.yul`, `decompiled/orc_token/decompiled.yul`
- `analysis/distribute_trace.json`, `claimunvoting_trace.json`, `claimunvoting_prestate.json`
- `analysis/child_bridge/bridge_pipeline.md` (+59 evidence files) — exit pipeline
- `poc/` — Foundry fork tests; `ci/run.sh` — CI state snapshot; `ci-out/`, `ci-log.txt`, `ci-artifacts/`
