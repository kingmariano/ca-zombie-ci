#!/usr/bin/env bash
# C2-06 Chihuahua governance capture — CI evidence job.
# Runs on the public ca-zombie-ci runner. Read-only public LCD/RPC queries only.
set -uo pipefail
cd "$(dirname "$0")/.."          # finding folder (chihuahua/)
mkdir -p ci-out/raw

echo "[ci] C2-06 chihuahua — start $(date -u +%FT%TZ)"
echo "[ci] python: $(python3 --version 2>&1)"

echo "[ci] pulling raw evidence ..."
python3 ci/evidence.py ci-out/raw 2>&1 | tee ci-out/evidence.log

echo "[ci] running the governance-capture model ..."
python3 analysis/model.py --outdir ci-out 2>&1 | tee ci-out/model.log

echo "[ci] artifact listing:"
find ci-out -type f | sort

if [ -f ci-out/model.json ]; then
  python3 - <<'PY'
import json
m = json.load(open("ci-out/model.json"))
a = m["attack"]
print("== C2-06 headline ==")
print("chihuahua height:", m["chihuahua_state"].get("chihuahua_height"))
print("bonded HUAHUA:", a["bonded_huahua"])
print("solo-quorum stake:", a["solo_quorum_stake_huahua"], "USD", a["solo_quorum_stake_usd_spot"])
print("min deposit USD:", a["min_deposit_usd"])
print("huahua in osmosis pools:", a["huahua_in_osmosis_pools"])
print("osmosis liquid dump ceiling USD:", m["osmosis"]["dump_ceiling_usd_liquid_only"])
print("osmosis fractional dump estimate USD:", m["osmosis"]["dump_estimate_fractional_liquid_usd"])
print("cp nominal USD:", m["cp_totals"]["nominal_usd"])
print("cp realizable USD:", m["cp_totals"]["realizable_usd"])
print("pathB feasible:", a["pathB_solo_quorum"]["feasible"])
PY
  echo "[ci] OK"
  exit 0
else
  echo "[ci] ERROR: ci-out/model.json missing" >&2
  exit 1
fi
