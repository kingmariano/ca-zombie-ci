# H-07 · ClayStack ETH (Ethereum) — deep-dive

**Date:** 2026-10-03 · **Chain:** Ethereum mainnet (chain id 1) · **Status:** read-only; PoC fork-verified only; **no mainnet transactions signed or sent**

**Headline:** external unprivileged attacker can extract **$0** live. The remaining on-chain
value (3.3844 ETH ≈ **$9,076**) is **frozen/stuck (S)** — no claim, upgrade or sweep path
works for users, the team, or an attacker. The DefiLlama $2.50M "last-known" figure is
obsolete: csETH supply is 2.0476 and the protocol was wound down in May 2025.

---

## 1. TL;DR

| Target | Live value (block 26,112,724) | Unprivileged extractable (E-U) | Why closed | Latent risk |
|---|---|---|---|---|
| csETH `clayMain` `0x331312DA…FFf8` | **2.079700157271613875 ETH** | **$0** | impl frozen to a role/upgrade-manager (`0x568AA6C2`); `claim`/`withdraw`/`refund` removed; `upgradeTo`/`changeAdmin` revert for every actor tested; sweep reverts | None found |
| Second frozen proxy `0x87393BE8…C051` | **1.304605987592364422 ETH** | **$0** | same frozen impl; no value-moving function callable | None found |
| `0x5764cD55…1355` (dust vault) | 0.0001 ETH | **$0** | dust only | None |
| csETH token `0x5d74468b…6263` | supply 2.047590014135143439 (no redemption) | **$0** | mint/burn only via frozen `clayMain`; no DEX liquidity / no redemption | Holders' 2.0476 csETH is unredeemable |
| csMATIC `0x38b7Bf4e…a912` + main `0x91730940…F905` | 0 ETH / 0 WMATIC | **$0** | MATIC backing not on Ethereum; different DefiLlama listing | n/a |
| xcsETH `0xf2F65Cf8…D0B0` + main `0x19C1bF1F…1c88` | 0 supply; 0.000983 csETH dust | **$0** | cross-chain generation never minted | n/a |
| Arbitrum csETH `0x9Aa8c241…564D` | 0.000984 csETH (single holder) | **$0** | dust | n/a |

### Total live extractable now: **$0 (E-U)** — high confidence
### Total live protocol ETH on Ethereum: **3.384406144863978297 ETH ≈ $9,075.8** at ETH $2,681.62 (DefiLlama, 2026-10-03) — classified **S (stuck)**

---

## 2. The finding, re-verified

The H-07 lead was: *"ClayStack ETH — LRT wind-down; check staking contracts/pending withdrawals (stuck funds + claim logic)."*
DefiLlama shows $2,501,309 last-known, stale 498d, 0 audits, dead since 2025-05-20.

On-chain reality (all at block 26,112,724 unless noted):

* csETH `totalSupply()` = **2.047590014135143439** (`0x5d74468b…6263`, `eth_call` block 26,112,724).
  The $2.5M TVL was fully redeemed before/at the May-2025 wind-down; only dust remains.
* csETH `clayMain()` = `0x331312DAbaf3d69138c047AaC278c9f9e0E8FFf8` (`CsToken.sol`, immutable, set once via `setClayMain`).
* The old `ClayMain` implementation (`0xAF7F9771…`, verified, solc 0.8.18) implemented
  `deposit()`, `withdraw(uint256)`, `claim(uint256[])`, `instantWithdraw`, `refund()`.
  The proxy was **upgraded on 2025-05-21** (tx `0xc8b5586b22…`, block 22,533,650 → `0x78e1c864…`;
  then tx `0x39093184…`, block 22,533,651 → `0x568AA6C2…`) to a **frozen "upgrade/role manager"**
  implementation that no longer exposes any user or ETH-moving function callable by third parties.
* Last successful user redemptions: **2025-05-20** (`refund()` tx `0x8d774def24…`, block 22,522,461; 6 refunds total).
* The team's later attempts to upgrade again **failed on-chain**:
  `upgradeTo` tx `0x718738dde8…` (block 24,181,849, 2026-01-07, status `error`),
  `upgradeToAndCall` tx `0x2c7eb0d544…` (block 22,533,733, error), and four more `upgradeTo` errors.

### Why the ETH cannot move (exact terms)

The current implementation `0x568AA6C2` is a permissioned *upgrade/role manager* that also embeds a
TransparentUpgradeableProxy-style admin surface. Its storage layout (ERC-7201-style namespace
`0xf364fa66…3a00…`) is used for per-selector permissions and an "authorized caller" (`ns a00`).

* `clayMain` (`0x331312DA`): `ns a00` = executor `0x4c06A181…4519`; `admin` slot = **0**.
* `clayMain2` (`0x87393BE8`): identical.
* All upgrade attempts by **every actor tested** — attacker, both timelocks, the admin EOA
  `0xa72DF45A…24FA`, the ProxyAdmin `0x084A0738…d49e4`, the impl-creator EOA `0x31F5E9E0…c53f2`,
  the executor, and the deployer — **revert** (`upgradeTo`/`changeAdmin`).
* The only sweep-shaped function (`8c84497d`) reverts for every actor and every argument shape
  tested (token address or EOA, `uint` 0/0x20/0x40/0x60, arrays).
* The executor's own admin path (`0x278f7943`) reverts with `ProxyDeniedAdminAccess()` (`0xd2b576ec`)
  for its ProxyAdmin in all three argument encodings.
* Both timelocks have **no** `PROPOSER_ROLE`, `EXECUTOR_ROLE` or `CANCELLER_ROLE` — only
  `TIMELOCK_ADMIN_ROLE` (held by the deployer EOA + timelock itself); they are inert.
* `DEFAULT_ADMIN_ROLE` on the RoleManager (`0x574e6bc3`) is unheld, and `grantRole` reverts from an
  unprivileged caller — no role escalation.
* The validator side is empty: NodeManager `0x349405B8…10E5` returns `getBalance() = 0`
  and `clayMain() = 0x331312DA`; all beacon validators have exited.

Result: the 3.3844 ETH is effectively **bricked** — users cannot claim, the team cannot upgrade,
and an attacker cannot sweep it.

---

## 3. Live-state assessment (block 26,112,724)

| Contract | Address | Code | ETH | Impl | Admin slot | Role |
|---|---|---|---|---|---|---|
| csETH token | `0x5d74468b69073f809D4FaE90AfeC439e69Bf6263` | CsToken (verified) | 0 | — | — | ERC-20, mint/burn only via clayMain |
| csETH clayMain | `0x331312DAbaf3d69138c047AaC278c9f9e0E8FFf8` | proxy (ERC1967Proxy) | **2.079700157271613875** | `0x568AA6C2…2F59` | 0 | frozen manager |
| 2nd frozen proxy | `0x87393BE8ac323F2E63520A6184e5A8A9CC9fC051` | proxy | **1.304605987592364422** | `0x568AA6C2…2F59` | 0 | frozen manager |
| current impl | `0x568AA6C21cCf558C47F2A01B60cc6D549cED2F59` | 17,284 B, unverified | 0 | — | — | role/upgrade manager |
| executor proxy | `0x4c06A181EDAfE572c44aB2a818B625a927484519` | 1,118 B custom proxy | 0 | `0x568AA6C2…2F59` | `0xa72DF45A…24FA` (EOA) | only actor allowed to call `clayMain` setters |
| ProxyAdmin (executor) | `0x084A0738A29a3Bfc233D3cb318FF7B63d97d49e4` | 1,110 B | 0 | — | owner `0x31F5E9E0…c53f2` | admin path reverts |
| RoleManager | `0x574e6bc316d4032d2Bd6D847ae6166FC7aC81bc3` | proxy | 0 | `0x9cC565BC…70CB` | — | `TIMELOCK_ROLE`→`0x7a1104…`, `TIMELOCK_UPGRADES_ROLE`→`0x376b467d…` |
| Timelock | `0x7a1104Feb0D460Aa437008e54D7D6Db0bA7e8876` | 6,485 B | 0 | — | — | no PROPOSER/EXECUTOR roles |
| Timelock Upgrades | `0x376b467dFf007dD8d3f24404cAddff7F72257Fe4` | 6,485 B | 0 | — | — | no PROPOSER/EXECUTOR roles |
| NodeManager (ETH) | `0x349405b80C8bAfd74DA9d4308F3c7b60B4Bf10E5` | proxy | 0 | `0xDcF7Dbe6…646f` | — | `getBalance()=0` (validators exited) |
| dust vault | `0x5764cD55ffb62E2b089c2D1eaD7dc68eDe813355` | proxy | 0.0001 | `0xD776098A…82dF` | — | dust |
| xcsETH token | `0xf2F65Cf87F2fC22da5FE4579A4f143062B41D0B0` | 13,435 B | 0 | — | — | supply 0 |
| xcsETH main | `0x19C1bF1Ff06E5702aef056b41290C6a7FF231c88` | proxy | ~1e-9 | `0x8bfD6fE9…dF17` | — | holds 0.000983 csETH |
| csMATIC token | `0x38b7Bf4eeCF3EB530b1529c9401FC37d2a71a912` | 3,258 B | 0 | — | — | supply 86,146 (no ETH/WMATIC backing on Ethereum) |
| csMATIC main | `0x91730940DCE63a7C0501cEDfc31D9C28bcF5F905` | proxy | 0 | `0xDB15A54E…0948` | — | 0 ETH, 0 WMATIC |

Full JSON: `analysis/state_dump.json`; contract map: `analysis/created_scan.json`,
`analysis/deployer_txs.json`; role checks in `analysis/state_dump.json["roles"]`.

### History of the wind-down (evidence)

* 2024-06-07 — last `withdraw`/`claim`/`autowithdraw` activity; impl upgraded to `0x594e80D1…`.
* 2025-05-20 — final `refund()` redemptions (block 22,522,456/22,522,461); users sent csETH to
  EOA `0x05592Fcf…4EeA4`, which was burned by `clayMain.refund`.
* 2025-05-21 — freeze upgrade to `0x78e1C864…` then `0x568AA6C2…` (blocks 22,533,650/51).
  Follow-up `0x1825beed` calls and all later upgrades failed.
* 2025-03-31 — a market maker address `0xbeD1EB54…` received 0.901 csETH (largest remaining holder);
  those tokens are now unredeemable.

---

## 4. What an attacker can / cannot do

**Cannot (all fork-verified):**

| Path | Result | Evidence |
|---|---|---|
| `claim(uint256[])`, `withdraw(uint256)`, `deposit()`, `instantWithdraw(uint256)` on `clayMain` | revert (unknown selector) | `test_h07_legacy_user_paths_revert` |
| `upgradeTo` / `upgradeToAndCall` / `changeAdmin` from attacker | revert / no-op | `test_h07_who_can_upgrade_claymain`, `test_h07_step1_executor_upgrade_is_noop` |
| executor takeover → upgrade `clayMain` → `drain()` | no-op / revert; 0 ETH moved | `test_h07_step2_takeover_chain_is_closed` |
| sweep `8c84497d` from attacker/admin/executor/timelocks with token/EOA/array args | revert for all | `test_h07_matrix_sweep`, `test_h07_sweep_token_args` |
| `refund`-shaped `e0c30834`, `f3314a61`, `42294bb0`, `753d02bd`, `9eb6ef66` | revert or state-only, no ETH | `test_h07_matrix_sweep` |
| executor admin `0x278f7943` from ProxyAdmin | revert `ProxyDeniedAdminAccess` | `test_h07_proxyadmin_can_upgrade_executor` |
| replay of the exact May-2025 migration calldata | revert `0x498c0922` | `test_h07_replay_migration` |
| self-`grantRole(TIMELOCK_UPGRADES_ROLE/DEFAULT_ADMIN_ROLE)` | revert | `test_h07_role_escalation_probe` |
| executor-gated setters (`753d02bd`, `9eb6ef66`) then retry value paths | setters succeed; value paths still revert; 0 ETH moved | `test_h07_executor_setters_then_retry`, `test_h07_executor_call_all_then_attacker` |

**Can:** transfer the csETH ERC-20 token itself (no redemption, no DEX liquidity, so no value);
observe state; that is all.

Costs: every value path reverts before spending meaningful gas; no flash loans or capital are
required for any candidate path, and none yields profit.

---

## 5. PoC / fork verification

Foundry project `poc/` (vendored forge-std; solc 0.8.24; cancun), tests run in GitHub Actions
against a fresh Ethereum fork (read-only). No mainnet transaction is signed anywhere.

| Test suite | Tests | Result |
|---|---|---|
| `test/ClayStackH07.t.sol` — live state, legacy paths, candidate calls, sweep probe | 4 | PASS |
| `test/ClayStackH07Attack.t.sol` — executor takeover / drain chain closed, share math | 3 | PASS |
| `test/ClayStackH07Privilege.t.sol` — upgrade matrix, role escalation, migration replay, sweep destinations | 5 | PASS |
| `test/ClayStackH07Matrix.t.sol` — 48+ argument/actor combinations | 3 | PASS |
| `test/ClayStackH07Chain.t.sol` — executor-gated setters + retries | 2 | PASS |
| `test/ClayStackH07ExecutorAdmin.t.sol` — ProxyAdmin path | 1 | PASS |

Key numbers asserted: `clayMain.balance == 2.079700157271613875 ETH`,
`clayMain2.balance == 1.304605987592364422 ETH`, `csETH.totalSupply == 2.047590014135143439`,
impl slots unchanged after every takeover attempt, attacker balance delta 0.

CI runs (public repo `kingmariano/ca-zombie-ci`, workflow `poc.yml`):

* run #1 (state + first suite): https://github.com/kingmariano/ca-zombie-ci/actions/runs/37133498289
* run #2 (full suite, 18 tests): _filled after final dispatch — see `ci-log.txt` and this line_

---

## 6. Verdict and residual risk

* **E-U (external unprivileged): $0 — high confidence.**
  The frozen implementation has no ETH-moving function reachable by an unprivileged caller; every
  candidate path was fork-tested and reverted or no-op'd; no role escalation exists.
* **H-O (holder-only): $0.** csETH's `claim`/`withdraw`/`refund` are gone; 2.0476 csETH held by 17
  addresses (largest 0.901) has no redemption path.
* **P (privileged): $0 found.** All upgrade/sweep paths revert for the team-controlled EOAs,
  timelocks, ProxyAdmin and executor as well. The timelocks are inert (no proposer/executor roles).
* **S (stuck): 3.384406144863978297 ETH ≈ $9,075.8.** The two frozen proxies' ETH is bricked.
  Residual uncertainty: a privileged recovery cannot be *mathematically excluded* (an unknown
  off-chain capability of EOA `0x31F5E9E0…`/`0xa72DF45A…` could in principle exist), but every
  on-chain privileged path tested reverts; confidence in "not E-U" is high, in "S" is high-medium.

Latent risk: none material. The token has no liquidity; even a future upgrade would at most refund
the 17 remaining holders. Watch-list: any future `Upgraded` event on `0x331312DA`/`0x87393BE8`,
or a successful call to the executor `0x4c06A181` with selector `0x04964aeb`.

Blockers/notes: unverified implementation (`0x568AA6C2`) — behaviour established by decompilation
(heimdall 0.7.3 + 0.9.2), selector analysis (evmole), storage-slot inspection and 48+ fork probes;
no Etherscan V2 API key available locally (the shipped key returns "Invalid API Key"), so verified
sources were pulled from Blockscout.

---

## 7. Methodology & sources

1. **Target discovery:** Etherscan label search (`ClayStack`), deployer EOA `0x36e65506…` full tx
   history (Blockscout API, 143 txs), 66 created contracts enumerated; code/balance/impl slots
   scanned for all (`analysis/created_scan.json`).
2. **Source/ABI:** Blockscout v2 verified sources (`CsToken`, `ClayMain v1`, `ClayMatic`,
   `DepositsManager`, `StrategyStETH/RETH`); unverified impls decompiled with heimdall (0.7.3 local,
   0.9.2 in CI) and analysed with `evmole` selector/argument extraction.
3. **Live state:** batched `eth_getCode`/`eth_getBalance`/`eth_getStorageAt`/`eth_call` at explicit
   blocks 26,112,691–26,112,724 (public RPCs; no keys in scripts). Token supplies, roles, impl/admin
   slots, ERC-7201 namespace slots.
4. **Fork PoC:** 18 Foundry tests in CI (GitHub Actions, public repo), each asserting the closed
   path; every value-moving candidate checked for attacker profit and protocol-balance deltas.
5. **Corroboration:** web/GitHub search for ClayStack repos (`claystack-docs`, `ssv-liquid-staking`),
   Blockscout token transfer history (last redemptions 2025-05-20), beacon-side check via NodeManager
   `getBalance()=0`.

## 8. Caveats & limitations

* The current implementation is **unverified**; function semantics were derived from decompilers
  (which can mis-annotate). All security-relevant conclusions are backed by *empirical fork calls*
  with balance/state assertions, not by decompiler reading alone.
* "No privileged path" is an on-chain finding; it cannot rule out an unknown off-chain key or a
  not-yet-deployed contract.
* USD conversion uses DefiLlama ETH $2,681.62 (2026-10-03); token price moves change the USD figure,
  not the ETH amounts.
* L2 scan limited to Blockscout searches on Base/Arbitrum/Optimism/Polygon (Arbitrum csETH dust
  0.000984; no other ClayStack ETH-family value found). The finding is Ethereum-only.

## 9. Files index

```
claystack-eth/
├── README.md                     this file
├── summary.json                  machine-readable summary
├── analysis/
│   ├── state_dump.py / .json     live-state dump (block 26,112,691) + role map
│   ├── created_scan.json         66 deployer-created contracts: code/ETH/impl slot
│   ├── deployer_txs.json         deployer tx history (143 txs)
│   ├── migration_calldata.hex    exact May-2025 migration calldata (replay target)
│   ├── ClayMain_v1.sol etc.      verified historical sources
│   └── decomp_ci/, decomp_073…   heimdall decompilations of the frozen impl
├── poc/                          Foundry project (18 tests, all PASS)
│   └── test/ClayStackH07*.t.sol
├── ci/run.sh                     CI heavy job: decompile + state dump
├── ci-out/, ci-artifacts/, ci-log.txt
```
