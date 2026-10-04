#!/usr/bin/env bash
# KiiChain (GHSA-7g4w-cg88-2cq2) CI evidence job — read-only.
#
# 1. Downloads the exact live v7.4.2 binary (public S3), verifies its SHA256
#    against governance proposal 13, extracts its embedded module versions and
#    greps for the compiled-in guard strings.
# 2. Runs ci/live_probes.py against KiiChain mainnet (eth_call only; no tx).
# 3. Clones KiiChain/evm v0.6.2-fork.2 (the fork the live binary replaces
#    cosmos/evm with) and runs the two guard unit tests.
#
# Results land in ci-out/. Exits non-zero if a core assertion fails.

set -uo pipefail
cd "$(dirname "$0")/.." || exit 1
mkdir -p ci-out
: > ci-out/run.log

FAIL=0
note() { echo "[$(date -u +%FT%TZ)] $*" | tee -a ci-out/run.log; }
assert_contains() { # file needle label
  if grep -q -- "$2" "$1"; then note "PASS: $3"; else note "FAIL: $3 (missing '$2' in $1)"; FAIL=1; fi
}

note "KiiChain GHSA-7g4w-cg88-2cq2 CI evidence job starting"
echo "KII_RPC_URL=https://json-rpc.kiivalidator.com" >> "${GITHUB_ENV:-/dev/null}" 2>/dev/null || true

# ---------------------------------------------------------------- 1. binary --
BIN=/tmp/kiichaind-v7.4.2-linux-amd64
BIN_URL="https://kiichain-snapshots-public.s3.us-east-2.amazonaws.com/releases/v7.4.2/kiichaind-v7.4.2-linux-amd64"
EXPECTED_SHA="e99e145379c65b9a1b8dae1a799d9a359a16740c07d0c3684820e6729ab34513"

if [ ! -s "$BIN" ]; then
  note "downloading live v7.4.2 binary"
  curl -sL --retry 5 --retry-delay 3 -C - -o "$BIN" "$BIN_URL" || note "WARN: binary download had errors"
fi
ls -la "$BIN" | tee -a ci-out/run.log
sha256sum "$BIN" | tee ci-out/binary_sha256.txt
if grep -q "$EXPECTED_SHA" ci-out/binary_sha256.txt; then
  note "PASS: binary SHA256 matches governance proposal 13"
else
  note "FAIL: binary SHA256 mismatch (want $EXPECTED_SHA)"; FAIL=1
fi

GO=$(command -v go || true)
[ -z "$GO" ] && [ -x /usr/local/go/bin/go ] && GO=/usr/local/go/bin/go
if [ -n "$GO" ]; then
  "$GO" version -m "$BIN" > ci-out/binary_buildinfo.txt 2>&1 || true
  grep -E "path|mod|=>|vcs.revision|vcs.time" ci-out/binary_buildinfo.txt | tee -a ci-out/run.log
  assert_contains ci-out/binary_buildinfo.txt "KiiChain/evm-private" "live binary replaces cosmos/evm with KiiChain/evm-private"
  assert_contains ci-out/binary_buildinfo.txt "v0.6.2-fork.2" "live binary pins fork v0.6.2-fork.2"
  assert_contains ci-out/binary_buildinfo.txt "v7.4.2" "live binary is v7.4.2"
else
  note "FAIL: go toolchain not found; cannot extract build info"; FAIL=1
fi

# guard strings compiled into the live binary
: > ci-out/guard_strings.txt
while IFS= read -r s; do
  c=$(grep -a -o -F "$s" "$BIN" | wc -l)
  echo "$c  $s" | tee -a ci-out/guard_strings.txt
  if [ "$c" -ge 1 ]; then note "PASS: guard string present: $s"; else note "FAIL: guard string missing: $s"; FAIL=1; fi
done <<'STRINGS'
state balance underflow for %s
state balance overflow for %s
cannot deploy EVM contract on top of non-base account
vesting account creation is disabled
Enabling bank send restriction for incident addresses
EMERGENCY FIX: starting funds recovery
IsBaseAccountOrEmpty
AddOverflow
STRINGS

# ------------------------------------------------------------ 2. live probes --
if python3 ci/live_probes.py 2>&1 | tee -a ci-out/run.log; then
  note "PASS: live probes completed"
else
  note "FAIL: live probes errored"; FAIL=1
fi

if [ -s ci-out/live_probes.json ]; then
  python3 - <<'PY' | tee -a ci-out/run.log
import json
d = json.load(open("ci-out/live_probes.json"))
ok = True
def check(cond, msg):
    global ok
    print(("PASS: " if cond else "FAIL: ") + msg)
    if not cond: ok = False
check(d.get("chain_id") == "0x6f7", "chain id is 1783 (0x6f7)")
check(d.get("app_version") == "v7.4.2", "app version is v7.4.2")
check((d.get("latest_block") or 0) > 10_600_000, "chain is producing blocks (height > 10.6M)")
s = d.get("blocklist_probe_summary", {})
check(s.get("blocked", 0) >= 17, f"incident-address blocklist fires on exploit call ({s.get('blocked')}/{s.get('total')})")
check(s.get("underflow_guard", 0) >= 1, f"underflow guard fires on the non-blocked vesting account ({s.get('underflow_guard')})")
addrs = d.get("attacker_addresses", {})
check(all(v.get("balance_akii") == 0 for v in addrs.values()), "all attacker/helper EVM balances are zero")
rec = d.get("recovery", {})
check(rec.get("staging", {}).get("balance_akii") == 0, "recovery staging account drained back to zero")
check((rec.get("remainder", {}).get("balance_akii") or 0) > 0, "recovery remainder wallet funded")
raise SystemExit(0 if ok else 1)
PY
  [ "${PIPESTATUS[0]}" -eq 0 ] || FAIL=1
else
  note "FAIL: no live_probes.json"; FAIL=1
fi

# ------------------------------------------------- 3. fork guard unit tests --
if [ -n "$GO" ]; then
  note "cloning KiiChain/evm v0.6.2-fork.2 and running StateDB guard tests"
  rm -rf /tmp/kii-evm
  if git clone --quiet --depth 1 --branch v0.6.2-fork.2 https://github.com/KiiChain/evm /tmp/kii-evm 2>>ci-out/run.log; then
    ( cd /tmp/kii-evm && "$GO" test ./x/vm/statedb/ \
        -run 'TestStateDBTestSuite/(TestSubBalanceUnderflowPanics|TestAddBalanceOverflowPanics)' -v ) \
        > ci-out/statedb_guard_tests.txt 2>&1
    tail -20 ci-out/statedb_guard_tests.txt | tee -a ci-out/run.log
    assert_contains ci-out/statedb_guard_tests.txt "PASS: TestStateDBTestSuite/TestSubBalanceUnderflowPanics" "SubBalance underflow guard test passes"
    assert_contains ci-out/statedb_guard_tests.txt "PASS: TestStateDBTestSuite/TestAddBalanceOverflowPanics" "AddBalance overflow guard test passes"
  else
    note "FAIL: clone of KiiChain/evm failed"; FAIL=1
  fi
fi

# ------------------------------------------------------------------ summary --
if [ "$FAIL" -eq 0 ]; then
  note "ALL CORE ASSERTIONS PASSED"
  echo "result: PASS" > ci-out/ci_summary.txt
else
  note "CORE ASSERTIONS FAILED"
  echo "result: FAIL" > ci-out/ci_summary.txt
fi
exit "$FAIL"
