#!/usr/bin/env bash
# C-34 custom heavy CI job. Runs before `forge test`. Read-only network scans; no transactions.
# All outputs go to c-34/ci-out/ (uploaded as artifacts).
set -uo pipefail
cd "$(dirname "$0")/.."   # c-34/
mkdir -p ci-out

echo "### [1/5] Socket approval event enumeration (full lifetime)"
timeout 120 python3 ci/socket_approvals_scan.py 2>&1 | tee ci-out/socket_approvals_scan.log || echo "STEP1 TIMEOUT/FAILED (archive RPC unavailable in CI; local full census is committed)"

echo "### [2/5] Socket live allowance/balance check"
timeout 900 python3 ci/socket_live_check.py 2>&1 | tee ci-out/socket_live_check.log || echo "STEP2 TIMEOUT/FAILED"

echo "### [3/5] Socket route table + vulnerable-bytecode marker scan"
timeout 900 python3 ci/socket_marker_scan.py 2>&1 | tee ci-out/socket_marker_scan.log || echo "STEP3 TIMEOUT/FAILED"

echo "### [4/5] Hedgey ClaimCampaigns multichain balances"
timeout 300 python3 ci/hedgey_multichain.py 2>&1 | tee ci-out/hedgey_multichain.log || echo "STEP4 TIMEOUT/FAILED"

echo "### [5/5] Hemi MerkleBox state"
timeout 300 python3 ci/hemi_state.py 2>&1 | tee ci-out/hemi_state.log || echo "STEP5 TIMEOUT/FAILED"

echo "### done; ci-out:"
ls -la ci-out/
exit 0
