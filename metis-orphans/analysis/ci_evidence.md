# CI evidence — metis-orphans fork suite

- **Run URL:** https://github.com/kingmariano/ca-zombie-ci/actions/runs/37180378111
- **Workflow:** poc.yml · branch `metis-orphans` · conclusion: **success**
- **Fork block:** 23238745 (Metis Andromeda, chain 1088) — RPC `https://andromeda.metis.io/?owner=1088`
- **Suite:** `poc/test/MetisOrphans.t.sol` — **14 passed, 0 failed, 0 skipped** (1.81s, 3.99s CPU)
- **Artifacts:** none produced (no ci-out files); full log in `../ci-log.txt`

## Key logged values (block 23238745)

| Test / log | Value |
|---|---|
| H-35 `safe_METIS_wei` | 1847552364000000000000000 (1,847,552.364 METIS) |
| H-35 `execTransaction` with empty signatures | **reverts** |
| H-36 `vault_METIS_wei` | 68713855000000000000000 (68,713.855 METIS) |
| H-36 attacker `transferEther` / `initialize` / `upgradeTo` | **all revert** |
| H-37 `mining_METIS_wei` | 13217961828430000000000 (13,217.96182843 METIS) |
| H-37 `paused` | **1 (paused)** |
| H-37 `owner` | 0x855E37b6068a44BdAb574c86C1817a374623225E |
| H-37 `poolLength` | 2 |
| H-37 attacker `deposit(...)` | **reverts** |
| H-37 attacker `emergencyWithdraw(0)` | succeeds (no stake) but attacker gains **0 METIS** |
| H-38 pairs A–D: token balances vs reserves | **exactly equal on both sides (no skim excess)**; pair self-LP = 0 |
| H-38 `burn()` without LP (A and C) | **reverts** |
| H-38 `skim()` from attacker | transfers **0** |
| H-41 `aToken_totalSupply` | 26528057592567194524852 (26,528.057592567194524852) |
| H-41 `aToken_METIS_balance` | 26448834076746246245959 (26,448.834076746246245959) |
| H-41 whale (0xA4C39Bc8…) aToken balance | 4577173943729028969480 |
| H-41 whale `withdraw(max)` | **succeeds**, receives 4,577.173943729028969480 METIS (H-O proof) |
| H-41 attacker `withdraw` (no aTokens) | **reverts** |
| H-41 largest METIS borrower 0x24a30823… | collateral $42,855.24, debt $18,196.68, **healthFactor 1.9547 (healthy)** |

*All calls executed on a local fork inside GitHub Actions; no mainnet transactions were sent.*
