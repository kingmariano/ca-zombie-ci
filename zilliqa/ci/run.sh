#!/usr/bin/env bash
# C2-58 Zilliqa deep-dive — custom CI job.
# Read-only; keyless public RPC only (https://api.zilliqa.com). No secrets used.
# Runs the evidence collector and writes artifacts to ci-out/.
set -uo pipefail

mkdir -p ci-out

echo "== C2-58 Zilliqa evidence collector =="
python3 analysis/scripts/collect_evidence.py ci-out/zilliqa_evidence.json
rc=$?

echo
echo "== summary =="
python3 - <<'EOF'
import json
r = json.load(open('ci-out/zilliqa_evidence.json'))
s = r.get('summary', {})
head = r['reads']['head']
lines = []
lines.append(f"head block: {head['block']} ({head['utc']})")
lines.append(f"ZIL price: ${r['reads'].get('zil_price_usd')}")
lines.append(f"legacy SSNList staking: {s.get('legacy_ssnlist_zil'):,.2f} ZIL = ${s.get('legacy_ssnlist_usd'):,.2f}")
lines.append(f"Z2 deposit contract:    {s.get('z2_deposit_zil'):,.2f} ZIL = ${s.get('z2_deposit_usd'):,.2f}")
lines.append(f"escrow claim vault:     {s.get('escrow_zil'):,.2f} ZIL = ${s.get('escrow_usd'):,.2f}")
lines.append(f"total:                  {s.get('total_zil'):,.2f} ZIL = ${s.get('total_usd'):,.2f}")
lines.append(f"E-U extractable:        ${s.get('eu_extractable_usd'):,.2f}")
passed = sum(1 for c in r['checks'] if c['pass'])
lines.append(f"checks: {passed}/{len(r['checks'])} passed")
open('ci-out/zilliqa_summary.txt', 'w').write("\n".join(lines) + "\n")
print("\n".join(lines))
EOF

exit "$rc"
