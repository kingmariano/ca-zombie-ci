# Hord (hETH) — L2 Phase-2 deep dive (Ethereum)

**Date:** 2026-10-11 · **Chain:** Ethereum mainnet · **Status:** read-only; PoC fork-verified only; **no mainnet transactions**
**Triage row:** `l2-triage-a` — Hord, $703,265 "live", medium confidence (281.3235 hETH × $2,499.87 assumed backed by beacon validators)
**Verdict:** **$0.00 extractable by an external unprivileged attacker (E-U, high confidence).** The triage value is stale — **all 101 Hord beacon validators are fully withdrawn (0 balance)**; the hETH staking manager and withdrawal manager are **paused**, and every ETH-moving path is privileged.

---

## 1. TL;DR

| Target | Live extractable (unprivileged) | Why closed | Latent risk |
|---|---:|---|---|
| hETH token + HordETHStakingManager `0x5bBe…068B` | **$0** | `paused()` = true; transfer/deposit/burn all `whenNotPaused`; the only ETH senders are `onlyHordCongress` / `onlyMaintainer`; no public mint | if governance unpauses + upgrades, holders have a ~$80 claim at the contract's own rate (see §6) |
| HordETHStakingWithdrawalManager `0x4FdC…e8A5` (holds 12.695 ETH) | **$0** | `paused()` = true; `withdraw()`/`requestWithdraw()` are `whenNotPaused`; all sweep/pay functions are `onlyMaintainer` / `onlyHordETHStakingWithdrawalManager` / `onlyHordCongress` | the 12.695 ETH is owed to 16 users with pending requests; a maintainer can sweep it to the finance address (`transferETHtoFinance`, added 2026-07) |
| Hord beacon validators (101) | **$0** | all `withdrawal_done`, balance 0 at beacon head slot 15,409,415 | none — funds already exited |
| EigenPod `0xb1d6…4EE0` | **$0** | 0.203 ETH; pod owner = HordRestakingManager (maintainer-gated) | 0.203 ETH privileged-movable |
| hETH/WETH UniV3 pool `0x4F2c…5F32` | **$0** | 6.32 hETH frozen (transfers paused); WETH side = 0.00068 ETH | none |

**Total live extractable now (E-U): $0.00** — high confidence.
**Privileged-movable (P): $33,277.49** (12.951 ETH + $388.99 tokens). **User-latent (H-O, pause-gated): $32,236.93.**

## 2. The finding in exact terms

Hord is a 2021-vintage ETH liquid-staking protocol ("Hord ETH Staking", hETH) whose operators wound the validator set down between **2023-10-31 and 2026-01-04** (final exit wave 2025-12-28 → 2026-01-04). Reconstructing the lifecycle on-chain:

- 103 `LaunchNewValidator` events (101 unique pubkeys, 3,296 ETH launched). **Withdrawal credentials:** 95 validators → the hETH staking manager itself `0x5bBe…068B` (0x01 credentials), 5 → EigenPod `0xb1d6…4EE0`, 1 → operational EOA `0x6d09…6328`.
- Beacon state at head slot 15,409,415: **all 101 validators `withdrawal_done`, balance 0.** No live beacon-chain backing exists.
- ETH minted/burned: 1,159.31 hETH minted, 877.99 burned via 154 withdrawal requests; **138 completed requests paid out 2,306.59 ETH**; 11.83 ETH was returned to the org (`withdrawOrganizationFunds`, 2026-06-25); **12.695 ETH remains, exactly equal to `assuredClaimsBalance` for the 16 uncompleted requests.**
- The share math is broken: `getAmountOfHETHforETH(1e18)` = **8982.44** (1 hETH ≈ 0.0001113 ETH) because `totalETHInPossession` collapsed after exits. Deposits mint at the same ratio (value-neutral); the contract records `totalBalanceETHInValidators() = 0`.
- **Pause:** both the staking manager and the withdrawal manager have `_paused = 1` (storage slot `0x65`). A maintainer paused them 2026-06-25, immediately before correcting 5 broken withdrawal requests and returning 11.83 ETH to the org.
- **Current impls are newer than the corpus assumed.** The staking-manager impl `0xd98B…3F27` (set 2026-02-07, block 24,411,920) is unverified but shares 63/65 dispatcher selectors with the verified Apr-2024 impl `0xaa06…D1F0`. The Feb-2026 impl removed `whitelistLSDToken`/`removeLSDToken` and **added two functions**, both identified and proven gated in the PoC:
  - `0xef300f40` = `transferETH(address,uint256)` — **onlyHordCongress** (arbitrary ETH send from the staking manager);
  - `0xf4f4b531` = SSV-withdraw wrapper `(uint64[],uint256,Cluster)` — **onlyMaintainer + whenNotPaused**.
  The withdrawal-manager impl `0x11E4…1107` (set 2026-07-23) added **`transferETHtoFinance()` — onlyMaintainer + whenPaused**, which sweeps the *entire* balance (including users' assured claims) to `financeAddress`.
- Governance is **alive**: HordCongress `0x086A…EC14` (3 members, quorum 2) executed proposals through 2026-07-22; two maintainers remain registered (`0x37be…4665`, `0x6acb…21f3`).

There is **no unprivileged call path that moves any value**, live or after an unpause (PoC §7).

## 3. Live-state assessment (block 26,170,355, 2026-10-11)

| Contract | Address | Code | State read |
|---|---|---|---|
| hETH / HordETHStakingManager (proxy) | `0x5bBe36152d3CD3eB7183A82470b39b29EedF068B` | impl `0xd98B050d2c5A3562b19a791f88F6Ef9A7aa93F27` (set blk 24,411,920) | `paused()=true`; `totalSupply=281.323492796481011183`; ETH balance `0.053653161919910392`; `totalBalanceETHInValidators=0`; `totalETHDeposited=2008.4048…`; `totalETHOnContractRecorded=129.1955…` (stale); `lastTimeUpdatedStats=1773221939` (~2026-03-11) |
| ProxyAdmin of hETH | `0x96B90F7065e5FD7251dd1b649DE20918Ae0F3aB7` | verified | `owner() = 0x086A6d9FD61758096CF4F394AE7C1F9B6b4EEC14` (HordCongress) |
| HordETHStakingWithdrawalManager (proxy) | `0x4FdC295580287b1e3C8fa8875f0fbDc688d8e8A5` | impl `0x11E45e691feeC37E224ee1764311509f6B691107` (set blk 25,590,926) | `paused()=true`; ETH balance **`12.695109442239980950`**; `assuredClaimsBalance` = same; `unAllocatedBuffer=0`; `totalPendingDebt=0`; `withdrawalDebtsLength=0`; `totalAmountAddedByOrgForBuffer=12.0`; `totalAmountReturnedToOrg=11.8309…`; `amountTakenFromBuffer=0.16906…` |
| Roles | `hordCongress()` = `0x086A6d9FD61758096CF4F394AE7C1F9B6b4EEC14`; `maintainersRegistry()` = `0x8B7819135Fe97aBFDc0c88596509c00FA727eaDc`; `stakingConfiguration()` = `0x51B2f83aac13adB9Ed826C4cdb593C88e6B61C92`; `financeAddress()` = `0x918B80ce545ca1b8651686B705E0d42bc9190912` | — | Congress members `0xDE1C…8ABA`, `0x7027…c5A8`, `0xc0b4…1F13`; quorum 2; `proposalCount=58`; maintainers `0x37be…4665`, `0x6acb…21f3` = true |
| EigenPod | `0xb1d6Eb8893e74fd42BFd48A1007aA3F3ec064EE0` | EigenLayer pod | ETH `0.202938912`; `podOwner = 0x72B8669dC62746e27073C726E55d9062005AB45D` (HordRestakingManager) |
| Staking-manager tokens | stETH `0xae7a…fE84`, wstETH `0x7f39…2Ca0`, SSV `0x9D65…7f54` | — | stETH `0.051876519937062307`; wstETH `0.076147546760160767`; SSV `5.0`; WETH `1e-10` |
| hETH/WETH UniV3 pool | `0x4F2cBf76a491240764d3Fe4E96e48C5062075F32` | — | hETH `6.319657972804532535`; WETH `0.000679680384701787` |
| Pending claims (16) | e.g. `0x7ff0Ba5F…856eC` owes `12.461378180425370983` ETH; whale `0x456cb202…e7AF` holds `207.936815623920120849` hETH with a `0.000132914799513178` ETH claim | — | sum of active `currETHToWithdraw` = `assuredClaimsBalance` (corrections of 2026-01-21 reconciled exactly) |

**USD reference (DefiLlama, 2026-10-11):** ETH $2,539.32 · stETH $2,549.54 · wstETH $3,176.28 · SSV $2.9723.

## 4. What an attacker can / cannot do (exact call paths)

All reverts below are **verified in the fork PoC** at block 26,170,355:

| Call | Caller | Result |
|---|---|---|
| `hETH.transfer(_, _)` | anyone | `Pausable: paused` |
| `hETH.approve(_, _)` | anyone | succeeds (not pause-gated) — useless, transfers frozen |
| `WM.requestWithdraw(1e18)` | anyone | `Pausable: paused` (then `Only direct calls.` / balance check) |
| `WM.withdraw()` | anyone | `Pausable: paused` |
| `SM.userDepositETH{value}` | anyone | `Pausable: paused` |
| `SM.burn(_, _)` | anyone | `Pausable: paused` |
| `WM.transferETHtoFinance()` | anyone | `Hord: Restricted only to Maintainer` |
| `WM.unpause()` / `WM.correctWithdrawalRequests()` | anyone | `Hord: Restricted only to HordCongress` |
| `WM.withdrawOrganizationFunds(1)` / `WM.payOfDebtFromOrganization(…)` | anyone | `Hord: Restricted only to Maintainer` |
| `SM.transferETH(_, _)` (0xef300f40) | anyone | `Hord: Restricted only to HordCongress` |
| SSV wrapper (0xf4f4b531) | anyone | `Pausable: paused` (live) / `Hord: Restricted only to Maintainer` (after unpause) |
| `SM.appropriateReservesToPayDebt(…)` / `mintProtocolFees()` / `setValidatorStats(…)` | anyone | `Hord: Restricted only to Maintainer` |

**After a governance unpause** (simulated on the fork): the attacker still extracts nothing — `withdraw()` reverts `user didnt make withdrawal request`; `requestWithdraw(1)` reverts `User wants to withdraw more than he has.`; `userDepositETH{0.01 ETH}` *succeeds but is value-neutral* (mints 89.82 hETH at ratio 8,982.44, worth exactly 0.0099999 ETH at the same contract rate); the ETH sweep paths remain Congress/Maintainer-only. The only value that then becomes user-recoverable is the 16 pending claims (12.695 ETH), which belong to those users, not the attacker.

**Costs:** nothing to extract; the PoC's failed calls cost only gas. No flash-loan capital is relevant because no path exists.

## 5. Categories

| Category | USD | Detail |
|---|---:|---|
| **E-U** (external unprivileged) | **$0.00** | no live path; high confidence |
| **H-O** (holder/user self-service) | **$0.00 today** | latent $32,236.93 (12.695 ETH) for 16 pending users — blocked by `whenNotPaused`; requires governance unpause |
| **P** (privileged) | **$33,277.49** | WM 12.695 ETH ($32,236.93; maintainer sweep / congress unpause) + SM 0.0537 ETH ($136.24) + stETH/wstETH/SSV ($388.99) + pod 0.203 ETH ($515.33) |
| **S** (stuck) | $0 | 281.32 hETH + 6.32 pool hETH frozen; contract-rate value ≈ 0.0313 ETH (~$79.53) with no path |

Context (already outside protocol custody): finance EOA `0x918B80ce…0912` holds **11.836024032446690421 ETH ($30,055)** returned to the org on 2026-06-25.

## 6. Residual / latent risk

1. **Governance is live.** A 2-of-3 Congress vote can unpause (users then recover the 12.695 ETH) or upgrade impls; the ProxyAdmin of both proxies is owned by the Congress. A maintainer can also `transferETHtoFinance()` while paused and take the users' 12.695 ETH. This is a trust/governance risk (P), not an attacker path.
2. **Broken share math** (`8982.44 hETH/ETH`): if governance ever unpauses *and* funds the staking manager, deposits/withdrawals would operate at a corrupted rate — future-integrator risk, not current extractable value.
3. **Stale DefiLlama/triage inputs**: the corpus "live $703k" was API-derived (`api.hord.app` 403 since 2025-12-18). On-chain truth: validators empty, only 12.95 ETH left, all pause-gated.

## 7. PoC / fork verification

- Project: `poc/` (Foundry, solc 0.8.24, vendored forge-std). Test: `poc/test/Hord.t.sol`.
- Fork: Ethereum mainnet, **pinned block 26,170,355**; `FORK_RPC_URL` from CI env (public archive RPC; no keys in repo).
- **4/4 tests PASS** (local + CI):
  1. `test_live_state` — supply/balances/pause/impl wiring/pending-claim accounting (gas 406,528);
  2. `test_attacker_paths_paused` — all user paths revert `Pausable: paused` (gas 286,590);
  3. `test_privileged_gates` — every ETH-moving path reverts with its permission error (gas 377,151);
  4. `test_unpaused_simulation_no_extraction` — pause removed via `vm.store`, attacker still extracts $0; value-neutral deposit demonstrated (89.82 hETH for 0.01 ETH); maintainer sweep of 12.695 ETH to finance reproduces the P path (gas 780,084).
- **CI runs (GitHub Actions, public repo `kingmariano/ca-zombie-ci`):**
  - `https://github.com/kingmariano/ca-zombie-ci/actions/runs/38172233587` — 4/4 PASS (first run).
  - _latest run (with custom `ci/run.sh` writing `ci-out/`): URL in `summary.json` and `ci-log.txt`._
- Artifacts: `ci-out/ci-summary.txt`, `ci-out/test-results.txt` (pinned reads + test results), `ci-log.txt`.

## 8. Methodology & sources

- **On-chain reads** (recorded block 26,170,355): `eth_call`/`eth_getStorageAt` for state, roles, EIP-1967 slots, pause slot `0x65`; Etherscan V2 for source/ABI/logs/creation/upgrades; event reconstruction for launches, withdrawals, mints/burns (`analysis/*.json`).
- **Beacon chain**: validator status/balances via `https://ethereum-beacon-api.publicnode.com` (head slot 15,409,415); pubkeys + withdrawal credentials decoded from `launchNewValidator` calldata of the 103 launch txs (Etherscan logs + `eth_getTransactionByHash`).
- **Impl analysis**: verified Apr-2024 impl source (`analysis/impl_apr2024_src/`) + dispatcher-level selector diff vs the live Feb-2026 impl; both new selectors identified and gate-proven in the PoC.
- **Prices**: DefiLlama (`coins.llama.fi`), 2026-10-11.

**Caveats/limitations:** the live staking-manager impl is unverified — conclusions rely on the verified Apr-2024 source, exact dispatcher comparison (63/65 shared selectors), live getter reads and PoC revert-string proofs for the two new functions; beacon data comes from one public beacon API, cross-checked against on-chain restaking-manager flows; `assuredClaimsBalance` vs request-event sums reconciled to the wei (difference = the 2026-01-21 correction for user `0x1Ee9…E066`, 0.000214899859020264 ETH).

## 9. Files

```
hord/
├── README.md                  # this report
├── summary.json               # machine-readable summary
├── analysis/
│   ├── live_state.json        # curated live-state + classification evidence
│   ├── beacon_validators_live.json   # 101 validators (status/balance/withdrawal credentials)
│   ├── validators_decoded.json       # pubkeys + wc decoded from launch txs
│   ├── launch_validator_logs.json    # 103 LaunchNewValidator events
│   ├── wm_all_logs.json              # withdrawal-manager event history
│   ├── wm_requests.json              # 154 requests / 138 completions / 16 active
│   ├── heth_mint_burn.json           # mint/burn events (1,159.31 / 877.99 hETH)
│   ├── impl_apr2024_src/             # verified Apr-2024 impl sources
│   ├── impl_apr2024_abi.json, impl_*_source.json
│   └── wm_src/                       # verified withdrawal-manager sources
├── poc/                       # Foundry PoC (foundry.toml, src/, test/, lib/forge-std)
├── ci/run.sh                  # custom CI job (pinned reads + tests → ci-out/)
├── ci-out/                    # CI-produced results
├── ci-log.txt                 # CI run log (helper)
└── ci-artifacts/              # downloaded artifacts (if any)
```
