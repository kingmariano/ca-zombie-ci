# C-33 — CI runs and fork-test evidence

Public CI repo: `github.com/kingmariano/ca-zombie-ci` (branch `c-33`, workflow `poc.yml`).

| Run | ID / URL | What it did | Result |
|---|---|---|---|
| 1 | https://github.com/kingmariano/ca-zombie-ci/actions/runs/37095018891 | first full scan (263 targets) | success; surfaced RPC batch/padding bugs (false Benqi candidate) |
| 2 | https://github.com/kingmariano/ca-zombie-ci/actions/runs/37097403813 | scan with URL rotation + verification | cancelled at 81/83 chains (superseded) |
| 3 | https://github.com/kingmariano/ca-zombie-ci/actions/runs/37098148502 | full scan + first PoC suite | scan OK (2,129 markets); PoC 4/10 (formula units bugs; Sonne gate found) |
| 4 | https://github.com/kingmariano/ca-zombie-ci/actions/runs/37099768000 | full scan + fixed PoC suite | scan OK; PoC 8/10 (Paxo borrow reverted -> implementation lacks borrow; OCP redeem shortfall) |
| 5 | https://github.com/kingmariano/ca-zombie-ci/actions/runs/37101591255 | full scan with corrected T==0 predicate + PoC v3 | scan OK; PoC 9/11 (Midas markets() 2-field decode bug + one RPC flake) |
| 6 | https://github.com/kingmariano/ca-zombie-ci/actions/runs/37102763143 | scan + PoC v4 (T=0 predicate) | 10/11 (Midas `redeem` semantics bug) |
| 7 | https://github.com/kingmariano/ca-zombie-ci/actions/runs/37104314281 | scan + PoC v5 (block-pinned) | 7/11 (pinned blocks unavailable on non-archive RPCs) |
| 8 | https://github.com/kingmariano/ca-zombie-ci/actions/runs/37105967984 | scan + PoC v6 (unpinned, multi-RPC fallback) | 6/11 (RPC head races; logic fix pending) |
| 9 | https://github.com/kingmariano/ca-zombie-ci/actions/runs/37108700155 | scan + PoC v7 (all gates, multi-RPC fallback) | 10/11 - Midas minBorrowEth gate PASSED (`cash_usd: 5`, `min_borrow: 143919681304257721877`); one redundant gate hit an RPC flake |
| 10 | https://github.com/kingmariano/ca-zombie-ci/actions/runs/3711XXXXXX | final: scan + 10-gate suite | (fill) |

Key traces captured in `ci-log.txt`:
- Sonne `redeemVerify` revert `"redeemTokens zero"` (run 3/4) — the truncation guard.
- OCP `redeemAllowed` return 4 (INSUFFICIENT_SHORTFALL) with kCake-LP balance 1, kOAT borrow 5e22
  (run 4) — proof that a 1-wei supply owned by another holder cannot be attacked.
- Paxo `borrow` delegatecall reverts in 292 gas with no sub-calls (run 4); implementation
  `0x12a92662bF3c6996a124A2bAc718729f791844E8` bytecode contains no `borrow(uint256)` (0xc5ebeaec)
  or `redeemUnderlying(uint256)` (0x852a12e3) selectors.
