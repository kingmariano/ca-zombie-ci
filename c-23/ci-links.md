# C-23 CI runs

Public CI repo: `kingmariano/ca-zombie-ci` (branch `c-23`).

| Run | Purpose | URL | Result |
|---|---|---|---|
| 1 | Full PoC (`forge test -vvv`) + heavy enumeration (`ci/run.sh`) | https://github.com/kingmariano/ca-zombie-ci/actions/runs/37099199777 | **success** — forge: 4 passed / 0 failed; enumeration: 14 top-level senders, 749 token senders, 763 code scans, same 14 `resolveOrders` contracts, Blockscout total $1,813.20 |

The workflow runs, in order: `c-23/ci/run.sh` (enumerate all Settlement senders, scan for the
`resolveOrders` selector, value every resolver contract; results uploaded from `ci-out/`), then
`forge test -vvv` from `c-23/poc/` (4 tests: historical repro, candidate screen, live extraction, approvals).
