# C2-02 CI runs (public repo `kingmariano/ca-zombie-ci`)

| Run | What it did | Result | URL |
|---|---|---|---|
| #1 | First full PoC suite (14 tests) + `ci/run.sh` independent state dump | **14/14 PASS** (fork block 52,214,672); state dump: max borrow 8,289.798958759297 aWETH = $22,325,983.56 at block 52,214,619, `next_fail_revert_prefix=0x6679996d`, fresh paths `REVERT:!W` | https://github.com/kingmariano/ca-zombie-ci/actions/runs/37343140462 |
| #2 | Final suite (15 tests incl. `test_residual_full_equity_path`) + `ci/run.sh` | **15/15 PASS** (fork block 52,215,826); full-equity: 11,736.315821863511 aWETH taken, gross $31,671,722.81, repaid $7,760,536.88 → **net $23,911,185.93**; state dump: max borrow 8,296.719572667618 aWETH = $22,389,598.79 at block 52,215,770 | https://github.com/kingmariano/ca-zombie-ci/actions/runs/37347998019 |
| #3 | Re-validation after the external folder wipe; re-syncs the complete deliverable (restored `poc/`, `ci/`, README, summary, analysis) to the CI branch | see `ci-log.txt` (overwritten by the latest run) | recorded in the run output above / `ci-run-stdout3.log` |

Artifacts:
- `ci-artifacts/result-base-vault-d189/ci-out/state.json` — run #2 state dump (re-downloaded after the wipe).
- `analysis/ci_run2_state.json` — run #2 state recovered from the log.
- `analysis/live_state_final.json` — post-wipe live re-measurement (block 52,218,505).

Note: the working folder was externally wiped on 2026-10-05 ~19:12 mid-run; deliverables were restored from the CI snapshot (branch `base-vault-d189`), the downloaded run logs/artifacts, and session records. Run #3 re-validates the restored PoC.
