#!/usr/bin/env bash
# BaseSwap V2 full pair enumeration (heavy job, GitHub Actions).
# Read-only RPC + DefiLlama calls. No secrets written to outputs.
# If ci-out/scan_summary.json is present (synced from a previous artifact), skip re-scanning.
set -uo pipefail
cd "$(dirname "$0")/.."   # folder root

echo "[baseswap-v2] start $(date -u +%FT%TZ)"
python3 --version
RC=0
if [ -s ci-out/scan_summary.json ] && [ "${FORCE_SCAN:-0}" != "1" ]; then
  echo "[baseswap-v2] cached scan present; skipping enumeration (set FORCE_SCAN=1 to rescan)"
  python3 - <<'EOF'
import json
d=json.load(open('ci-out/scan_summary.json'))
print('[baseswap-v2] cached block', d.get('block'), 'pairs', d.get('pair_count'),
      'excess_usd', d.get('skim_excess_usd'))
EOF
else
  python3 ci/enumerate_pairs.py
  RC=$?
  echo "[baseswap-v2] enumerate_pairs.py rc=$RC"
fi
ls -la ci-out/ 2>/dev/null || true
du -sh ci-out/* 2>/dev/null || true
echo "[baseswap-v2] end $(date -u +%FT%TZ)"
exit $RC
