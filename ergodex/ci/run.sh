#!/usr/bin/env bash
# ErgoDEX (Ergo) Phase-2 CI job — chain-native verification suite (read-only, public endpoints only).
# Runs from the finding folder root. Writes results to ci-out/ (uploaded as artifacts).
set -uo pipefail
cd "$(dirname "$0")/.."

echo "[ergodex] python: $(python3 --version)"
echo "[ergodex] running chain-native evaluation suite..."
python3 ci/evaluate.py 2>&1 | tee ci-out/scan.log

echo
echo "[ergodex] validating expectations..."
python3 - <<'EOF'
import json, sys
res = json.load(open('ci-out/eval_results.json'))
bad = []
for r in res['results']:
    label, got = r['label'], r['result']
    if label.endswith('_expect_true'):
        want = True
    elif label.endswith('_expect_false'):
        want = False
    elif label.endswith('_expect_unspendable'):
        want = 'ERROR'   # script evaluation error -> box cannot be spent
    else:
        continue
    ok = (got == want)
    print(f"  {'PASS' if ok else 'FAIL'}  {label:44} got={got!r} want={want!r}")
    if not ok:
        bad.append(label)
print()
if bad:
    print(f"[ergodex] {len(bad)} expectation(s) FAILED: {bad}")
    sys.exit(1)
print(f"[ergodex] all {len(res['results'])} scenarios match expectations")
EOF
rc=$?
echo "[ergodex] exit=$rc"
exit $rc
