#!/usr/bin/env bash
# C2-47 Carmine (Starknet) — CI job: read-only state proofs + full claims enumeration.
# Keyless public RPC only (no secrets). Results -> ci-out/.
set -uo pipefail
cd "$(dirname "$0")/.."   # finding root
mkdir -p ci-out

export SN_RPC_URL="${STARKNET_RPC_URL:-${SN_RPC_URL:-}}"
if [ -n "${INFURA_API_KEY:-}" ]; then
  # keyed URL is only used at runtime from the CI secret env; never written to files/logs
  export SN_RPC_URL="https://starknet-mainnet.infura.io/v3/$INFURA_API_KEY,https://starknet-rpc.publicnode.com"
fi
export SN_RPC_URL="${SN_RPC_URL:-https://starknet-rpc.publicnode.com}"
echo "[ci] rpc host: $(echo "$SN_RPC_URL" | cut -d, -f1 | sed -E 's#(https?://[^/]+).*#\1#')"
echo "[ci] block: $(python3 analysis/sn.py 2>/dev/null | tail -1)"

echo "[ci] === state proofs ==="
python3 analysis/state_proofs.py > ci-out/state-proof.json 2> ci-out/state-proof.err
echo "[ci] state-proof exit=$? size=$(wc -c < ci-out/state-proof.json)"

echo "[ci] === claims enumeration (full) ==="
python3 analysis/enumerate_claims.py > ci-out/claims.json 2> ci-out/claims.log
rc=$?
echo "[ci] claims exit=$rc size=$(wc -c < ci-out/claims.json)"
tail -40 ci-out/claims.log || true
if [ "$rc" != "0" ] || [ ! -s ci-out/claims.json ]; then
  echo "[ci] FAIL: claims enumeration did not complete"
  exit 1
fi

echo "[ci] === math self-check ==="
python3 - <<'PY' > ci-out/math-check.txt 2>&1
import json, sys
sys.path.insert(0, "analysis")
from sn import call, u256
# Verify Python Fixed/2**61 math vs on-chain views for legacy pools.
L = "0x076dbabc4293db346b0a56b29b6ea9fe18e93742c73f12348c8747ecfc1050aa"
lpt = 0x07aba50fdb4e024c1ba63e2c60565d0fd32566ff4b18aa5818fc80c30e749024
lpool = u256(call(L, "get_lpool_balance", [lpt]))
locked = u256(call(L, "get_pool_locked_capital", [lpt]))
supply = u256(call(lpt, "totalSupply", []))
onchain = u256(call(L, "get_underlying_for_lptokens", [lpt, supply & (2**128 - 1), supply >> 128]))
py = (lpool - locked) * supply // supply  # value_of_position = 0 (all pool positions zero)
print("lpool", lpool, "locked", locked, "supply", supply)
print("onchain_get_underlying_for_all_lpt", onchain)
print("python_free_capital", py)
assert abs(onchain - py) <= 2, (onchain, py)
print("MATH CHECK PASS (within 2 wei)")
PY
cat ci-out/math-check.txt
grep -q "MATH CHECK PASS" ci-out/math-check.txt || { echo "[ci] FAIL: math check"; exit 1; }

echo "[ci] === summary ==="
python3 - <<'PY' | tee ci-out/summary.txt
import json
try:
    d = json.load(open("ci-out/claims.json"))
    print("block:", d["block"])
    for name in ("legacy", "new"):
        for lp, p in d.get("amms", {}).get(name, {}).get("pools", {}).items():
            print(name, lp[:14], "n_opts", p.get("n_options"), "lp_claim", p.get("lp_claim_total"),
                  "opt_claims", p.get("claim_total"), p.get("underlying_symbol"),
                  "blocked", p.get("blocked", {}).get("n_blocked_maturities"))
    print("balances:", json.dumps(d.get("balances", {})))
except Exception as e:
    print("summary error:", e)
PY
echo "[ci] done"
