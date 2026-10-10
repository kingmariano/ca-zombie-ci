# H2-03 (residue) — CI runs (public repo `kingmariano/ca-zombie-ci`)

| Run | What it did | Result | URL |
|---|---|---|---|
| #1 | First PoC dispatch (7 tests, `forge test -vvv`), no `ci/run.sh` | **FAILED (infra)** — the job-level `POLYGON_RPC_URL` secret could not serve state reads ("header for hash not found" even at the tip); all 7 fork tests aborted before executing. No test-logic failure. | https://github.com/kingmariano/ca-zombie-ci/actions/runs/38058027565 |
| #2 | Added `ci/run.sh` archive-RPC selector (strict archive requirement) | **FAILED (infra)** — none of the injected providers has archive access (all keys tip-only/expired), so the selector exited. | https://github.com/kingmariano/ca-zombie-ci/actions/runs/38058197554 |
| #3 | Archive-free suite (incident reconstructed at latest block) + selector fallback | **5/7 PASS** — the two failures were transient state-read errors from the flaky secret endpoint, not logic. Full exploit + re-arm + closed-path tests passed. | https://github.com/kingmariano/ca-zombie-ci/actions/runs/38058448789 |
| #4 | Hardened selector (4-probe state check, public-endpoint preference) | **1/7 PASS** — the selected public endpoint raced on the newest block hash under the CI network path ("header for hash not found"); all failures were RPC-side. | https://github.com/kingmariano/ca-zombie-ci/actions/runs/38058975159 |
| #5 | Shallow block pin: `ci/run.sh` computes and verifies `POLYGON_FORK_BLOCK = tip − 48` (within the non-archive state window), tests fork at that block | **SUCCESS — 7/7 PASS** at pinned block 95,291,408 (all exploits, closures and re-arm tests green) | https://github.com/kingmariano/ca-zombie-ci/actions/runs/38059644991 |
| #6 | Final validation run after documentation updates (same pinned-block suite) | see the latest run on the `residue` branch | (this run) |

**PoC files:** `poc/src/NimiqH203.sol`, `poc/test/NimiqH203.t.sol` (vendored `forge-std`).

**Modes.** The historical fork reproduction at block 93,930,000 (pre-attack) was run locally against
an archive RPC and passes (7/7): the full-hub exploit drains the victim's real pre-attack balances
(24,332.489269 USDT + 26,130.641710 USDC). Because the CI provider set has no archive access, the
CI suite reconstructs the identical attack at a shallow recent block — the single owner
`setRelayHub()` flip plus injection of the exact drained amounts onto the still-live allowances —
and also proves the current closure (`execute` reverts `Base: illegal msg.sender`; the full relay
path moves no funds) and the one-call re-arm. Local runs with both Foundry 1.7.1 and 1.8.5 pass
7/7 against the public endpoint.
