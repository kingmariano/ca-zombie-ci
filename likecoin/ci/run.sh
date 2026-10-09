#!/usr/bin/env bash
# C2-29 LikeCoin governance-capture — CI evidence job.
# Runs on the public ca-zombie-ci runner. Read-only public LCD/RPC queries only.
# No secrets are used or printed; all endpoints are keyless public ones.
set -uo pipefail
cd "$(dirname "$0")/.."          # finding folder (likecoin/)
mkdir -p ci-out

echo "[ci] C2-29 likecoin — start $(date -u +%FT%TZ)"
echo "[ci] python: $(python3 --version 2>&1)"

echo "[ci] pulling raw evidence ..."
python3 ci/evidence.py ci-out 2>&1 | tee ci-out/evidence.log

echo "[ci] running the governance-capture model ..."
python3 analysis/model.py --rawdir ci-out/raw --outdir ci-out 2>&1 | tee ci-out/model.log

echo "[ci] artifact listing:"
find ci-out -type f | sort

if [ -f ci-out/model.json ]; then
  python3 - <<'PY'
import json
m = json.load(open("ci-out/model.json"))
c = m["capture"]
print("== C2-29 headline ==")
print("likecoin height:", m["likecoin_height"], m.get("likecoin_block_time"))
print("bonded LIKE:", c["bonded_like"])
print("CP accounting LIKE:", c["cp_accounting_like"], "| nominal USD:", c["cp_nominal_usd_at_v3_price"])
print("dist extra (unreachable):", c["distribution_extra_unreachable_like"], "| escrows:", c["escrow_total_like"])
print("bonded validators:", m["validators"]["bonded_count"], "of", m["validators"]["all_count"])
print("solo-quorum stake LIKE:", c["solo_quorum_stake_like"], "| USD:", c["solo_quorum_cost_usd_at_v3_price"])
print("dex LIKE inventory:", c["dex_like_inventory_all_pools"], "| ratio:", c["solo_quorum_x_dex_inventory"])
print("min-deposit acquisition USD:", c["min_deposit_acquisition_cost_usd"], "(refundable; burned only on veto)")
print("CP realizable dump USD:", c["cp_realizable_dump_usd"])
print("veto-proof stake LIKE:", c["veto_proof_stake_like"])
print("solo quorum feasible on public markets:", c["solo_quorum_feasible_on_public_markets"])
PY
  echo "[ci] OK"
  exit 0
else
  echo "[ci] ERROR: ci-out/model.json missing" >&2
  exit 1
fi
