#!/usr/bin/env bash
# C-25 custom CI job (heavy): decompile unverified implementations + static scan.
set -uo pipefail
cd "$(dirname "$0")/.."          # -> c-25/
mkdir -p ci-out

echo "== environment =="
python3 --version
pip3 --version || true
df -h / | tail -1

echo "== install decompilers (best effort, timeboxed) =="
pip3 install --quiet --disable-pip-version-check evmole 2>&1 | tail -2 || \
  pip3 install --quiet --disable-pip-version-check --break-system-packages evmole 2>&1 | tail -2 || true
pip3 install --quiet --disable-pip-version-check panoramix-decompiler 2>&1 | tail -2 || \
  pip3 install --quiet --disable-pip-version-check --break-system-packages panoramix-decompiler 2>&1 | tail -2 || true
python3 -c "import evmole; print('evmole OK', getattr(evmole,'__version__','?'))" 2>&1 || true
python3 -c "import panoramix; print('panoramix OK')" 2>&1 || true

echo "== run decompile/static analysis =="
python3 analysis/ci_decompile.py 2>&1 | tee ci-out/decompile_log.txt

echo "== registry + approvals snapshot (from precomputed analysis JSON) =="
python3 - <<'PYEOF' 2>&1 | tee ci-out/state_snapshot.txt
import json, os
out = {}
for fn in ["registry_replay.json", "approvals_current.json", "state.json"]:
    p = os.path.join("analysis", fn)
    if os.path.exists(p):
        d = json.load(open(p))
        if fn == "registry_replay.json":
            reg = d.get("final_registry", {})
            out["registered_selectors"] = {k: v for k, v in reg.items() if v and set(v) != {"0"}}
            out["unregistered_selectors"] = [k for k, v in reg.items() if not v or set(v) == {"0"}]
        elif fn == "approvals_current.json":
            live = [r for r in d if r.get("live_allowance", 0) > 0 and r.get("owner_balance", 0) > 0]
            out["approvals_with_allowance_and_balance"] = len(live)
            out["top_live_pairs"] = [
                {"symbol": r["symbol"], "owner": r["owner"], "allowance": str(r["live_allowance"]),
                 "balance": str(r["owner_balance"])} for r in sorted(
                    live, key=lambda r: -(r["owner_balance"] / (10 ** r["decimals"])))[:10]]
        elif fn == "state.json":
            out["contract_state"] = d
print(json.dumps(out, indent=2))
PYEOF
echo "== done =="
