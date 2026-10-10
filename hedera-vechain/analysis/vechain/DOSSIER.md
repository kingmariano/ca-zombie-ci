# DOSSIER — VeChain StarGate (H2-06 child scope: staking protocol)

**Date:** 2026-10-10 · **Chain:** VeChain mainnet (VeChainThor, chain id 100009, genesis `0x00000000851caf3cfdb6e899cf5958bfb1ac3413d346d43539627e6be7ec1b4a`)
**Status:** READ-ONLY. No transaction was signed or sent, no keys used, no deployments. Every "call" below is either a public RPC read or a Thor *clause simulation* (`POST /accounts/*`), which is not a transaction. Keyless public endpoints only.
**Blocks of record:** first best block 26,109,881 (11:20:46Z) · pinned state block 26,110,363 · last best seen 26,110,364.

---

## 1. TL;DR

| Question | Answer | Confidence |
|---|---|---|
| **E-U — extractable by external unprivileged attacker, live now** | **$0** | **high** |
| H-O — holder/self-service (NFT owners via `requestDelegationExit` + `unstake`) | **7,589,050,000 VET + 1,041,201,129 VTHO pool ≈ $59.78M** | high (amounts high; claimable VTHO is pro-rata entitlement, upper-bounded by the pool) |
| P — privileged (admin EOA can pause/grant UPGRADER and upgrade both UUPS proxies) | same custody via upgrade authority | high |
| S — stuck | **20,864.14 VTHO** on the StargateNFT contract (no code path can move it) ≈ $14.70 | medium-high |
| Historical (pre-fix) double-claim exploitation, 2025-12-02 → 2026-01-16 | **1,672,220.57 VTHO ≈ $1,178.57** excess payouts (58 re-claim events); **fixed** in the live impl | medium-high |

**Campaign-number correction:** H2-06 quoted "701.24M VET ≈ $6.22M" custody. That figure is only the **StarGate contract's liquid VET balance**. In addition, **6,890,600,000 VET is currently delegated by StarGate into the native protocol staker** (18,590 live delegations; exact reconciliation from `DelegationInitiated`/`DelegationWithdrawn` events). Total attributable VET ≈ **7.589B ($59.04M)**, plus a **1.0412B VTHO** reward pool in the StarGate contract. All of it is owner-redeemable (H-O), not extractable (E-U).

---

## 2. Contracts, reconstruction, and bytecode verification

| Contract | Address | Type | Verification |
|---|---|---|---|
| Stargate (orchestrator) | `0x03c557be98123fdb6fad325328ac6eb77de7248c` | ERC-1967 proxy (**StargateProxy**, OZ fork) | Sourcify `100009` exact match, verified 2025-12-02; live proxy runtime code == verified code (170 bytes, keccak match) |
| Stargate impl (LIVE) | `0x987f2ebfd1c0e3490962b270488dc94a7d687a0f` | UUPS impl, EIP-1967 slot live | **keccak(runtime) `0x5f0357ff…` == compile of repo commit `b8b695b` (`fix: vulnerability … #27`) with solc 0.8.20, optimizer runs=1, evmVersion paris** |
| StargateNFT proxy | `0x1856c533ac2d94340aaa8544d35a5c1d4a21dee7` | ERC-1967 proxy | Sourcify exact match; live code keccak `0x2293e8a9…` (170 bytes) |
| StargateNFT impl (LIVE) | `0xce31931f42099cb5b0a19f565d976084785cde2f` | UUPS impl | Sourcify exact match 10612847; **live runtime code byte-identical to verified onchain code** (23,702 bytes) |
| VTHO token (native) | `0x0000000000000000000000000000456E65726779` | native ERC-20 | name() = "VeThor" read live |
| Protocol Staker (native) | `0x00000000000000000000000000005374616b6572` ("Staker") | native staking contract | via `IProtocolStaker` ABI; `firstActive()` ≠ 0 (Hayabusa live) |

**Upgrade history** (from `Upgraded(address)` logs on the proxy; all txs originated by `0x78508681…`):

| Block | Timestamp | Implementation | Note |
|---|---|---|---|
| 23,415,257 | 2025-12-02 | `0xccfe678b…` | v1 deploy (creation tx `0x2ef33be1…`) |
| 23,543,191 | 2025-12-17 | `0xcd2d50c1…` | v2 (Sourcify match 10956162) |
| 23,805,346 | 2026-01-16 | `0x987f2ebf…` | **v1-hotfix (F-2026-14785), live** — tx `0x6a0bc1b0…` called `upgradeToAndCall(0x987f2ebf…, 0x)` |

**Reproduction of the bytecode proof** (`scripts/verify_bytecode.py`): takes Sourcify's standard-JSON input for the verified v2 impl, recompiles with solc 0.8.20, substitutes the Clock library link references (2×20 bytes) and the UUPS `__self` immutable (3×32 bytes) read from on-chain code → keccak matches the verified v2 bytecode exactly (toolchain validated), then swaps in the hotfixed `Stargate.sol` from commit `b8b695b` → keccak `0x5f0357ff…` matches the **live** impl at block 26.1M. So the live business logic equals that source.

Key getters confirming links (read through the live proxy, keyless sim):
- `getStargateNFTContract()` → `0x1856c533…` (matches docs)
- `getProtocolStakerContract()` → `0x…5374616b6572` (native Staker)
- `version()` = 1 · `paused()` = false · `getMaxClaimablePeriods()` = 832 · `UPGRADE_INTERFACE_VERSION()` = "5.0.0"

---

## 3. Live value (pinned block 26,110,363; prices fetched 2026-10-10 12:21Z)

| Address | VET | VTHO |
|---|---|---|
| StarGate `0x03c5…48c` | 698,450,000.00 ($5,433,996.65) | 1,041,201,128.98 ($733,834.54) |
| StargateNFT `0x1856…ee7` | 0 | 20,864.1423 ($14.70) |
| impls `0x987f…`, `0xce31…` | 0 | 0 |
| Native Staker (network-wide) | 14,875,126,538.00 (of which `totalStake()` 14,404,756,538 across 101 active validators) | – |

Delegated-by-StarGate reconciliation (live = `DelegationInitiated` without matching `DelegationWithdrawn`):

| Metric | Value |
|---|---|
| `DelegationInitiated` events / Σ | 41,703 / 16,415,040,000 VET |
| `DelegationWithdrawn` events / Σ | 23,113 / 9,524,440,000 VET |
| **Live delegations / current delegated VET** | **18,590 / 6,890,600,000 VET** |
| Stake tiers (top counts) | 10,000 VET ×8,525 · 50,000 ×4,639 · 200,000 ×2,959 · 1,000,000 ×1,358 · 600,000 ×232 · 5,000,000 ×232 · 15,600,000 ×108 … |
| StargateNFT `totalSupply()` / id high-water | 20,745 / 49,600 |

Prices (DefiLlama): VET $0.007780079671758719 · VTHO $0.0007047961392074626. **Total attributable custody ≈ $59,777,262.87.**

Read commands (examples):
```bash
curl -s https://mainnet.vechain.org/accounts/0x03c557be98123fdb6fad325328ac6eb77de7248c
# {"balance":"0x241be8a5e5e35ba4f400000","energy":"0x35ce35a439281e647339fb8","hasCode":true}
# pinned-block balanceOf via keyless RPC proxy:
curl -s -X POST https://rpc-mainnet.vechain.energy -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","id":1,"method":"eth_call","params":[{"to":"0x0000000000000000000000000000456E65726779","data":"0x70a0823100000000000000000000000003c557be98123fdb6fad325328ac6eb77de7248c"},"0x18e67e7"]}'
# EIP-1967 impl slot (live):
curl -s -X POST https://rpc-mainnet.vechain.energy -H 'Content-Type: application/json' -d '{"jsonrpc":"2.0","id":1,"method":"eth_getStorageAt","params":["0x03c557be98123fdb6fad325328ac6eb77de7248c","0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc","latest"]}'
# → 0x…987f2ebfd1c0e3490962b270488dc94a7d687a0f
```

---

## 4. Extraction-path audit (all paths, with live simulation evidence)

All simulations use `POST https://mainnet.vechain.org/accounts/*` with `caller` = `0x…0001` (attacker) except where noted; raw request/response pairs are in `raw/live_gate_simulations.json`. Revert selectors decoded against the verified sources.

| # | Path | Gate in live code | Attacker simulation result | Category |
|---|---|---|---|---|
| E1 | `Stargate.unstake(43203)` (someone else's EXITED token) | `onlyTokenOwner` (`ownerOf == msg.sender`) | **revert `UnauthorizedUser(0x…01)`** `0xea93ab6d…` | H-O |
| E2 | `Stargate.delegate(43203, validator)` | `onlyTokenOwner` | revert `UnauthorizedUser` | H-O |
| E3 | `Stargate.requestDelegationExit(43203)` | `onlyTokenOwner` | revert `UnauthorizedUser` | H-O |
| E4 | `Stargate.migrateAndDelegate(1, validator)` (legacy node not owned) | `onlyLegacyTokenOwner` (`legacyNodes().idToOwner == msg.sender`) | revert `UnauthorizedUser` | H-O |
| E5 | `Stargate.claimRewards(48863)` (someone else's token) | **none — permissionless by design**; payout `VTHO_TOKEN.safeTransfer(ownerOf(tokenId), amount)` | **success**: VTHO Transfer StarGate→`0xa556…20a4` (=owner) 975,116.83 VTHO; `DelegationRewardsClaimed(receiver=owner, …)` | trigger-only; funds→owner |
| E6 | `Stargate.upgradeToAndCall(attacker, 0x)` | UUPS + `UPGRADER_ROLE` | revert `AccessControlUnauthorizedAccount(0x…01, UPGRADER_ROLE)` `0xe2517d3f…` | P |
| E7 | `StargateNFT.transferBalance(1)` | `DEFAULT_ADMIN_ROLE` | revert `AccessControlUnauthorizedAccount` | P |
| E8/E9 | `StargateNFT.mint / burn` | `onlyStargate` | revert `UnauthorizedCaller(0x…01)` `0xd86ad9cf` | P |
| E10 | `StargateNFT.boost(otherToken)` | pays VTHO **from the caller** (`safeTransferFrom(_sender, 0x0, fee)`); no owner check (selfless) | revert `MaturityPeriodEnded(43203)`; for immature tokens demands caller's own balance+allowance | grief/H-O |
| E11 | native `Staker.withdrawDelegation(37920)` — StarGate's delegation | native requires `msg.sender == delegator` | **revert `Error("staker:only delegator")`** | H-O (via StarGate only) |
| E12 | same call, `caller = StarGate` | – | **success** → proves the delegation is withdrawable *and* caller-identity-gated | H-O proof |
| – | `initialize(...)` re-init | `initializer` | revert `InvalidInitialization()` `0xf92ee8a9` | P |
| – | `receive()` forced VET | only NFT/Staker | revert `OnlyStargateNFTAndProtocolStaker` | – |

**H-O path proven end-to-end** (`raw/unstake_owner_sim.json`): `unstake(43203)` with `caller = owner 0x7e6eed59…` on an EXITED delegation → success: native `DelegationWithdrawn`, VET `10000e18` Staker→StarGate→owner, `DelegationRewardsClaimed` 115.72 VTHO (range 9..9) StarGate→owner, NFT burned (`TokenBurned`), gas ≈ 407,738.

**Owner payout is always `ownerOf(tokenId)`** — verified in source (`_claimRewards`, `unstake`) and by live event simulation. No path pays `msg.sender`. No delegatecall exists in business logic (only the proxy). All mutating value paths are `nonReentrant`; VTHO is a native token without callbacks. `SafeERC20` is used; the VET out-transfer checks success. `boostOnBehalfOf` cannot transfer anyone's funds but the caller's.

**Manager roles:** `addTokenManager` requires token owner; managers have **no** value-moving role in the current Stargate/NFT (value paths check `ownerOf`, not manager). `migrateTokenManager` is gated by `TOKEN_MANAGER_MIGRATOR_ROLE` (unassigned). No `setManager` exists.

**Live role state** (from `RoleGranted/RoleRevoked` logs + live `hasRole` sims):
- Stargate proxy: `DEFAULT_ADMIN_ROLE` + `PAUSER_ROLE` held by **EOA `0xba04313060012a2c8623b2b3cb6d4c5e2b1becea`** (no code, 0 VET). `UPGRADER_ROLE` **unassigned** (deployer renounced at block 23,805,347). Admin can grant UPGRADER and upgrade → P risk.
- StargateNFT proxy: same EOA holds ADMIN + PAUSER; UPGRADER, MANAGER, TOKEN_MANAGER_MIGRATOR, LEVEL_OPERATOR unassigned.
- Both contracts unpaused.

### Verdict
**E-U = $0 (high confidence).** Every value transfer out of the system is gated by ERC-721 ownership (H-O) or by admin/UPGRADER roles (P), and the native staker rejects any withdrawal not originating from the delegator (StarGate). The one known permissionless-callable function with a write side-effect (`claimRewards`) pays the NFT owner.

---

## 5. The known vulnerability: F-2026-14785 ("Rewards Drain due to Invalid Last Claimed Period Update")

The **live** impl is the hotfix. The pre-fix code (`_claimRewards`) set `lastClaimedPeriod = 0` whenever `lastClaimablePeriod == 0` (i.e., nothing new to claim), enabling an infinite claim/re-claim loop: claim → no-op reset → re-claim the same periods. `claimRewards(tokenId)` is permissionless, so even a third party could trigger payouts (to the owner) that overdrew the StarGate VTHO pool. Vulnerable window: **v1+v2 impls, blocks 23,415,257 → 23,805,346 (2025-12-02 → 2026-01-16)**.

**Observed exploitation in the vulnerable window** (24,190 `DelegationRewardsClaimed` events scanned; overlap detection = a later claim on the same delegation whose `firstPeriod ≤ previous lastPeriod`, which pre-fix is only possible via the reset bug):

- **58 regression claim events across 53 token/delegation groups**
- **Excess payouts ≈ 1,672,220.57 VTHO ≈ $1,178.57** (fraction-weighted; upper bound by full amounts 1,673,320.88)
- Largest: token 6087 del 5548 — `(1..2)` re-claimed for **881,523.89 VTHO** in tx `0x590472146c…` (block 23,601,167, origin `0x2bb20ea4…`, 6 clauses hitting 6 tokens); token 3815 del 2815 — `(1..5)` re-claimed for **588,667.90 VTHO** in tx `0xc3a5d5c5…` (block 23,777,314, origin `0x1d054374…`, 6 clauses). Payouts went to the respective token owners (event receivers).
- **Fix verified on live code**: bytecode-equal to the hotfix source (early return `if (lastClaimablePeriod == 0) return;`); post-fix claims scanned = **107,996 events (blocks 23,805,347 → 26,000,000), zero regressions.**

So today the drain is closed; remaining live attack surface = none found.

---

## 6. Negative results (dead ends — do not re-investigate)

- `owner()` / `name()` do not exist on Stargate (earlier "revert" was selector absence, not a gate).
- `claimableRewards(tokenId)` on non-existent tokens reverts `ERC721NonexistentToken` (token 49262 "2.45e77" was a misparse of that revert payload — not a bug).
- `claimRewards` on a non-delegated token: success, no-op (fixed early-return), no events.
- Third-party delegation withdrawal: impossible (`staker:only delegator`).
- `boostOnBehalfOf` is `onlyStargate` on the NFT; user `boost()` spends the caller's own VTHO.
- Migration whitelist logic was removed in the deployed V3; migration eligibility is enforced against the legacy TokenAuction contract (`idToOwner`, auction/upgrade state, lead time), and migration is owner-only.
- No proxy-upgrade path for outsiders (`UPGRADER_ROLE` empty; UUPS `__self` check).
- No VTHO rescue function on StargateNFT (its 20,864 VTHO is stuck — S).

## 7. Coverage, caveats, and what would change the verdict

- **Covered:** both Stargate contracts (source↔bytecode exact), all 43 Stargate entry points + full StargateNFT ABI reviewed; every VET/VTHO-moving path simulated with an unprivileged caller; full claim/initiate/withdraw event history scanned; native staker gating tested; roles enumerated from logs + live reads.
- **Not fully covered:** post-fix claim scan stops at block 26,000,000 (last ~110k blocks unscanned; source-level fix + 108k zero-regression sample); the 6.89B delegated figure relies on StarGate's own event pairs (internally consistent, cross-checked on samples); USD varies with price; claimable-VTHO entitlement per token not summed (18.6k tokens — pool value stated instead).
- **What would change the verdict:** an upgrade of either proxy (new UPGRADER assigned + bytecode change) → re-audit; a new native-staker bug letting non-delegators withdraw; any newly discovered class of reward-accounting regression producing overlapping claims for non-owners (none found; regression detector = exact overlap check).
- Note: the admin is a **single EOA** (`0xba0431…`) — a compromise would hand over full upgrade authority (P). This is operational risk, not unprivileged extraction.

## 8. Files

```
analysis/vechain/
├── DOSSIER.md                       # this report
├── state.json                       # machine-readable state dump
├── scripts/
│   ├── sim.sh                       # Thor clause-simulation helper
│   ├── verify_bytecode.py           # source↔bytecode keccak prover (validated on verified v2); needs solc (download cmd in header)
│   ├── live_gates.py                # all live gate simulations (E1..E12) w/ raw evidence
│   ├── fetch_claims.py              # DelegationRewardsClaimed paginator
│   ├── fetch_events.py              # DelegationInitiated/Withdrawn paginator
│   ├── fetch_native_delegations.py  # native staker event paginator (alternative method; superseded by exact DI/DW reconciliation)
│   └── make_state.py                # pinned-block balance snapshot
├── tools/                           # (solc_list.json only; solc binary not committed — see verify_bytecode.py header)
└── raw/                             # raw JSON evidence (simulations, sourcify records, code hex, event datasets)
    ├── live_source/                 # the live Stargate.sol / StargateNFT.sol / MintingLogic.sol / interfaces (sources matching the deployed bytecode)
    └── *.jsonl.gz                   # large event datasets are gzip-compressed (gunzip before re-analysis)
```

Reproduce the key gate (read-only; simulates, never sends):
```bash
curl -s -X POST 'https://mainnet.vechain.org/accounts/*' -H 'Content-Type: application/json' \
  -d '{"clauses":[{"to":"0x03c557be98123fdb6fad325328ac6eb77de7248c","data":"0x2e1a7d4d000000000000000000000000000000000000000000000000000000000000a8c3","value":"0x0"}],"caller":"0x0000000000000000000000000000000000000001","gas":30000000,"gasPrice":"0x0"}'
# → [{"data":"0xea93ab6d0000000000000000000000000000000000000000000000000000000000000001",...,"reverted":true}]  (UnauthorizedUser)
```
