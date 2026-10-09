#!/usr/bin/env bash
# C2-32 Carbon/Demex — CI evidence job (public ca-zombie-ci runner).
# Read-only public GETs only; no keys, no transactions. Results -> ci-out/.
set -uo pipefail
cd "$(dirname "$0")/.."          # finding folder (carbon-demex/)
mkdir -p ci-out/raw

echo "[ci] C2-32 carbon-demex — start $(date -u +%FT%TZ)"
echo "[ci] python: $(python3 --version 2>&1)"

echo "[ci] pulling raw evidence ..."
python3 ci/evidence.py ci-out/raw 2>&1 | tee ci-out/evidence.log

echo "[ci] running the capture-economics model ..."
python3 analysis/model.py --inputs ci-out/raw/inputs.json --outdir ci-out 2>&1 | tee ci-out/model.log

echo "[ci] artifact listing:"
find ci-out -type f | sort

if [ -f ci-out/model.json ]; then
  python3 - <<'PY'
import json
m = json.load(open("ci-out/model.json"))
c, v, l, p = m["capture"], m["verdict"], m["liquidity"], m["proceeds"]
print("== C2-32 headline ==")
print("halted:", m["halt"]["halted"], "| last block:", m["halt"]["last_block_height"], m["halt"]["last_block_time"])
print("bonded SWTH:", f"{c['bonded_swth']:,.2f}")
print("naive quorum:", f"{c['naive_quorum_swth']:,.0f} SWTH = ${c['naive_quorum_usd']:,.0f}")
print("corrected solo quorum:", f"{c['corrected_solo_quorum_swth']:,.0f} SWTH = ${c['corrected_solo_quorum_usd']:,.0f}")
print("SWTH on osmosis:", f"{l['total_swth_on_osmosis']:,.2f} ({100*l['realistic_buy_coverage_of_corrected_quorum']:.2f}% of corrected quorum)")
print("CP nominal:", f"{p['community_pool_nominal_swth']:,.0f} SWTH = ${p['community_pool_nominal_usd']:,.0f}",
      "| realizable ~$%.0f" % p["cp_realizable_usd_dump_into_pool651"])
print("chain TVL:", f"${p['chain_tvl_usd']:,.0f}")
print("top1 validator share: %.2f%% (single veto: %s)" % (100*m["validator_bloc"]["top1_share_of_bonded"], m["validator_bloc"]["top1_can_single_veto"]))
print("verdict:", json.dumps(v["classification"]))
PY
  echo "[ci] OK"
  exit 0
else
  echo "[ci] ERROR: ci-out/model.json missing" >&2
  exit 1
fi
