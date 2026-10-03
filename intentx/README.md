# H-04 — IntentX (SYMMIO perp DEX): live-state assessment & unprivileged-extraction audit

**Date:** 2026-10-03 · **Chains:** Base, Arbitrum, Mantle, Blast · **Status:** read-only; PoC fork-verified only; no mainnet transactions.
**Finding:** H-04 — IntentX, DefiLlama last-known ~$5.67M, stale 322d, 0 audits, "dead" 2026-01-08. Corpus hypothesis: unaudited perp/derivatives; vault contracts + oracle paths (spot-price manipulation class).

---

## TL;DR

| target | live extractable (unprivileged) | why closed/open | latent risk |
|---|---|---|---|
| SYMMIO core diamonds (Base/Arb/Mantle/Blast) | **$0** | all value-moving entries are self-scoped, role-gated or Muon-signature-bound; no forgery/replay path | two unverified PartyB facets; Muon key trust root |
| IntentX `SymmioPartyB` "instant-layer" auth bug | **$0 today** | gate (`callFromInstantLayer`) is `false` on all chains; the only vulnerable proxy was never used (1 tx = deployment, no positions, 0 balance) | **real bug** — patched in GitHub 2026-09-22 but still live on-chain; would be exploitable by any code running during a future InstantLayer batch |
| MultiAccount / SymmExecutor / NoxPartyB / TargetRebalancer | **$0** | deployed code has `onlyOwner` on `depositAndAllocateForAccount`; selector-scoped delegation; upgrade keys behind 3-day timelocks / Safe | GitHub `main` has the owner check commented out (not deployed) |
| OnChainSymmioVaultV2 (Arb `0x40423eF1…`) | **$0** | withdrawals need signer EIP-712 + BALANCER acceptance; payout receiver-bound (signature replay = griefing only) | 2 compromised keys would drain; $401,425.17 LP funds sit in solver account |
| SolverVault (Arb `0xAdBb55b3…`) | **$0** | deposit permissionless, withdrawals/`rebalance` role-gated (SIGNER EOA / EXECUTOR Safe) | privileged-key risk only |
| INTX token / xINTX / claim contracts | **$0** | no staking/merkle/claim contract holding INTX found | — |

**Total live extractable by an external unprivileged attacker now: $0.00** (confidence: **high** for the checked vectors; medium overall — see caveats).

Owner-recoverable custody in the live diamonds: **$1,671,489.65** (Base $1,018,722.78 + Arbitrum $591,107.97 + Mantle $61,658.90). Blast's **$40.52** is **stuck (S)** — `accountingPaused = true` reverts deposits/withdrawals/allocations.

---

## 1. What IntentX actually is (and what happened)

- IntentX was **SYMMIO's flagship perp frontend**: intent-based OTC perpetuals where users (PartyA) trade against solver/hedger quotes (PartyB) settled by the SYMMIO diamond. Not an AMM, not a spot-oracle protocol: **prices come from Muon TSS-signed oracle messages**, so the corpus hypothesis "spot-price manipulation" does not apply to the core.
- Shut down **2026-01-08** (in-app banner: *"IntentX is shutting down… Please withdraw all funds from your account before this date."*); DefiLlama `deadFrom: 2026-01-08`. Successor brand **Carbon** (intentx.io → "Try out Carbon NOW!"). Team still operates the contracts (role grants and liquidations observed through 2026-10-03).
- Audits: SYMMIO core via Sherlock contests (v0.8/0.8.2/0.8.3/0.8.4/0.8.5); INTX token/xINTX via Quantstamp (2023-12). No public hack of IntentX or SYMMIO was found.

## 2. Deployment map (all verified on-chain at the stated blocks)

### Base (chainid 8453)
| role | address | notes |
|---|---|---|
| SYMMIO diamond (collateral USDC) | `0x91Cf2D8Ed503EC52768999aA6D8DBeA6e52dbe43` | 29 facets / 382 selectors; balance **1,018,722.777883 USDC** @ block 52,127,402 |
| MultiAccount proxy | `0x8Ab178C07184ffD44F0ADfF4eA2ce6cFc33F3b86` | impl `0x54a870306b2ed367d135c43f2c2dafa9061bb887` (owner check present) |
| Muon signature verifier | `0x0Ae899A702b9a7E6fbAd661117F0b1B002eD18F1` | `MuonSignatureVerifier` (Schnorr Muon-v0.4 + gateway ECDSA + per-function key permissions) |
| InstantLayer | `0x0825435285ac0E5c02c7a7c443F631f3e07fE375` | 46,427 B; `nextTemplateId=7`; never executed a batch (all observed calls = `grantDelegation`) |
| AccountLayer diamond | `0x56caf00c6C5cB5478570Bb23807B9d1D697863DC` | `setSigner` gated by SIGNER_SETTER_ROLE (InstantLayer only) |
| Solver vault v1 (`OnChainSymmioVault`) | `0x7785fE35F6510D111063579AA14F7D28aD84512A` | **empty** (0 USDC, LP supply 0) |
| Registered PartyBs (14) | e.g. `0x6015e7e0…`, `0x9206d9d8…`, `0xf49d0089…`, `0xb49cae38…` (vault solver) | none run the vulnerable instant-layer check |

### Arbitrum (chainid 42161)
| role | address | notes |
|---|---|---|
| SYMMIO diamond (collateral USDC) | `0x8F06459f184553e5d04F07F868720BDaCAB39395` | balance **591,107.969626 USDC** @ block 511,351,957 |
| MultiAccount proxy | `0x141269E29a770644C34e05B127AB621511f20109` | impl `0x1cb4b1dcee1ebde41c272c7c14bf55d565e2830c` |
| Muon verifier | `0x1423d1bb78fbea2b0980611f6319844fa7063caf` | same code |
| InstantLayer | `0x4a6A866e62b38EEDFd4d99599F7E2baA35336d1c` | 46,427 B; 2,445 lifetime txs — **all `grantDelegation`; zero batches** |
| AccountLayer diamond | `0xA60AC54e18739f1C4681409383DCF881De3eFAbE` | `setSigner` = SIGNER_SETTER_ROLE → InstantLayer (+`0xc9b7e07e…`) |
| **Vulnerable PartyB proxy** | `0x0b5B3f9b727656A254ec1203D8b2A86b4540F5F5` | impl `0x556f255e0e671c760e21e01cd7c3a4fb4722ed3a` = old `isCallFromInstantLayer()` check; **1 lifetime tx (deployment)**; no positions; 0 allocated balance |
| Patched PartyB proxy | `0xE72284fc2D56bE2C1649742FD131BceA41A94a6a` | impl `0x25547278…` = `hasRole(msg.sender, INSTANT_LAYER_ROLE)`; holds ~401k USDC of solver deposits |
| OnChainSymmioVaultV2 proxy | `0x40423eF1FdCc21738A9031d0295b7Ce6739cD1Ae` | USDC=1.000000 (locked); `currentDeposit=401,425.170314`; solver `0xE72284fc…`; signer `0xD6ADf61f…`; BALANCER EOA `0x441ee70b…`; withdrawalPeriod 0 |
| SolverVault proxy | `0xAdBb55b3d7f93A6c213754e8B7a89996Cd009179` | holds **409,161.893001 USDC**; SIGNER EOA `0x751CFA90…`, EXECUTOR Safe `0x14622475…` |

### Mantle (5000) / Blast (81457)
| chain | diamond | collateral | balance | pause |
|---|---|---|---|---|
| Mantle | `0x2Ecc7da3Cc98d341F987C85c3D9FC198570838B5` | USDe `0x5d3a1Ff2…` | **61,658.902999059175503421 USDe** | none |
| Blast | `0x3d17f073cCb9c3764F105550B0BCF9550477D266` | USDB `0x43000000…03` | **40.5175384338934146 USDB** | **`accountingPaused = true`** (deposit/withdraw/allocate revert `Pausable: Accounting paused`) |

Base/Arbitrum/Mantle run the **same IntentX-forked SYMMIO v0.8.5 build** (identical 382-selector sets); Blast runs an older 15-facet build with inline Muon verification.

## 3. The one real code bug found — and why it is not extractable today

`contracts/solver/SymmioPartyB.sol` (IntentX repo) gates `adlClose()` / `_call()` on
`hasRole(MANAGER_ROLE) || hasRole(TRUSTED_ROLE) || ISymmio(symmioAddress).isCallFromInstantLayer()`.
`isCallFromInstantLayer()` is a **global flag** that is true for the whole duration of any InstantLayer batch — so *any contract called during such a batch* could impersonate the PartyB and execute arbitrary diamond calls as it, including `adlClose(quoteId, amount, price)` which **settles PnL at an attacker-chosen price with no Muon signature** (verified in the deployed `PartyBEmergencyActionsFacetImpl`).

The team fixed this on **2026-09-22** (commit `0def5ea` "Fix Party B") by checking the caller against the core `INSTANT_LAYER_ROLE`. On-chain state today:

- `isCallFromInstantLayer()` = **false** on Base, Arbitrum, Mantle (Blast lacks the getter).
- The only proxy still running the vulnerable implementation (`0x0b5b3f9b…`) has **one lifetime transaction (its deployment)**, no open positions and zero allocated balance.
- Both InstantLayers have **never executed `executeBatch`/`executeTemplate`** (Arbitrum: 2,445/2,445 txs are `grantDelegation`; Base: same pattern) — so the flag has no on-chain window.
- The AccountLayer confused-deputy variant (`setSigner` poisoning) is blocked: each op wraps its call in `setSigner(owner)` … `setSigner(0)`; batch entry is OPERATOR_ROLE-gated.

**Verdict: latent, not live.** If Carbon/IntentX ever runs an InstantLayer batch while the vulnerable PartyB is funded/positioned, the path opens immediately.

## 4. Live-state measurements (read-only)

| metric | Base | Arbitrum | Mantle | Blast |
|---|---|---|---|---|
| diamond collateral balance | 1,018,722.777883 USDC | 591,107.969626 USDC | 61,658.902999059175503421 USDe | 40.5175384338934146 USDB |
| lifetime deposits (event-sum) | 25,397,915.60 | 1,692,999.02 | n/a | n/a |
| lifetime withdrawals | 16,902,105.08 | 815,958.71 | n/a | n/a |
| registered PartyBs | 14 | 6 | 5 | 1 |
| accounts created | 10,394 | 2,864 | n/a | n/a |
| accounting paused | no | no | no | **yes** |
| top historical depositors' current balance | ~0 (they exited; top-8 all ≈0) | ~0 (sampled partyAs ≈ dust) | n/a | n/a |
| PartyB free balances measured | ≈103,961.7 USDC (largest: `0x6015e7e0…` 34,985.57; `0x9206d9d8…` 51,999.13; `0xf49d0089…` 9,993.14) | vault solver holds ~401,425 in allocated balance | n/a | n/a |

Interpretation: the diamonds' remaining value is not idle retail free balance — the large users withdrew. It is mostly **allocated balances** (PartyA/PartyB) that require a Muon-signed `deallocate` to move back to free balance, plus the hedger's own funds.

## 5. What an attacker can / cannot do

**Cannot (verified):**
- Forge/replay Muon signatures: verification is bound to `muonAppId, address(this), method string, party nonces, values, timestamp, chainid` and requires both a Schnorr TSS signature (registered key + per-function permission) and a gateway ECDSA signature; verifier setters are role-gated.
- Liquidate healthy accounts: liquidation requires a Muon liquidation signature and LIQUIDATOR_ROLE; `settlePartyALiquidation` is permissionless but precondition-locked (needs an active liquidation) and pays no outsider value.
- Steal via MultiAccount: `depositAndAllocateForAccount` retains `onlyOwner` in all deployed copies; `_call` is selector-scoped via `delegatedAccesses`; `apiExecutor`/`trasnferAccount` exist only in GitHub `main`, not deployed.
- Drain solver vaults: signature + role gated; signature replay is receiver-bound (griefing only).
- Impersonate via the InstantLayer flag: flag false everywhere; no batch execution window exists.
- Set roles/pause/upgrade: all role-gated; upgrades behind 3-day TimelockControllers (Base/Arb/Mantle) or a 3-of-6 Safe (Blast).

**Can:**
- Anyone can `depositFor`/`depositAndAllocateForAccount` into accounts (donation/griefing only).
- Anyone can call `settlePartyALiquidation` / `liquidatePendingPositionsPartyA` (no value accrues to the caller unless they are a registered liquidator).
- Users/hedgers can withdraw **free** balances (cooldowns: 12h/150s/150s/90s; no Muon signature for `withdraw`); **allocated** balances need a Muon-signed `deallocate`.

## 6. PoC / fork verification

Foundry project `poc/` (vendored forge-std), 10 tests, all passing in CI:
`https://github.com/kingmariano/ca-zombie-ci/actions/runs/37136544374` (first green run, 9 tests; the Blast-pause test was added after — see the final run URL in `summary.json`).

- Live-state forks (Base/Arb/Mantle/Blast): balances + collateral + flag/pause assertions.
- `test_arb_vuln_partyB_gate_closed`: attacker `_call`/`adlClose` on the vulnerable PartyB revert `SymmioPartyB: Invalid access` **today**.
- `test_arb_vuln_partyB_accepts_anyone_when_flag_true`: with the flag forced via `vm.store` (slot `keccak("diamond.standard.storage.global")+10`, byte 21), the same attacker call **succeeds** — proves the latent bug.
- `test_arb_fixed_partyB_rejects_when_flag_true`: the patched PartyB rejects even with the flag true — proves the fix.
- `test_blast_accounting_paused`: `deposit`/`withdraw` revert `Pausable: Accounting paused`.
- `test_base_solver_vault_is_empty`: vault USDC 0, LP supply 0.

## 7. Categories (explicit)

| category | USD | notes |
|---|---|---|
| **E-U** (external unprivileged extractable) | **$0.00** | headline; no open path found |
| **H-O** (holder/user-only recoverable) | **$1,671,489.65** | Base $1,018,722.78 + Arb $591,107.97 + Mantle $61,658.90; free balances directly withdrawable, allocated balances require Muon co-sign (team still active). Includes $401,425.17 vault-LP deposits (additional signer+BALANCER requirement) and hedger PartyB funds |
| **P** (privileged-only incremental) | $0.00 | privileged keys can unpause/upgrade/expedite but do not unlock extra attacker value |
| **S** (stuck/bricked) | **$40.52** | Blast USDB behind `accountingPaused`; only a privileged unpause can free it |

## 8. Verdict, residual & latent risk

- **Headline: $0 E-U, high confidence.** The deployment is a heavily-audited SYMMIO fork with an intact Muon trust root; the IntentX-specific periphery is role/signature gated; the one real IntentX code bug (PartyB instant-layer auth) is latent because the flag is false, no batches run, and the vulnerable PartyB is an unused shell.
- **Latent risks to monitor:** (1) the vulnerable PartyB proxy `0x0b5b3f9b…` (Arbitrum) if it ever gets positions and an InstantLayer batch runs; (2) two **unverified** diamond facets (PartyB position/batch actions) — live probes show partyB gating, but source is unavailable; (3) Muon signing-key compromise (trust root); (4) privileged-key risk on the vaults ($810k combined TVL).
- **Blast funds are S** while accounting is paused.

## 9. Methodology, sources, caveats, files

- Read-only RPC/`cast` reads, Etherscan V2 verified sources, Ankr archive `eth_getLogs`, GoldRush, Blockscout; fork tests on GitHub Actions (Foundry 1.8.4). No transactions signed/sent; no secrets committed.
- Sources of truth: deployed verified facet sources (Base/Arb/Mantle/Blast), `SYMM-IO/protocol-core` upstream, `Intent-X/intentx-SmartContracts` (incl. commit `0def5ea`), `Intent-X/solver-deposit-vault`, DefiLlama, app banner, Sherlock/Quantstamp audit records.
- Caveats: exact user/hedger/protocol split of allocated balances not fully enumerated (top depositors verified exited; PartyB free balances measured); off-chain operator behaviour (when/if InstantLayer batches run) is not observable on-chain; Muon service liveness inferred from continued admin/liquidation activity; two unverified facets.
- Evidence: `analysis/core/REPORT.md` (diamond audit), `analysis/periphery/REPORT.md` (periphery/vaults), `analysis/research/REPORT.md` (history/incidents), `analysis/state/raw/agg_*.json` (account/deposit aggregations), `analysis/arbitrum/` (InstantLayer/PartyB forensics), `poc/` (tests), `ci/run.sh` (live-state dump), `ci-out/state.{txt,json}`.
