#!/usr/bin/env bash
# cog/ci/run.sh — light live re-verification for the Cog (Scroll) zombie-hunt.
# - probes public Scroll RPCs and exports SCROLL_FORK_RPC for the forge step
# - re-reads the key live numbers (keyless public RPC; read-only) into ci-out/live_recheck.json
# Never prints secrets. Exits 0 on partial failure so forge tests still run.
set -uo pipefail
cd "$(dirname "$0")/.."

pick() {
  for u in "$@"; do
    [ -z "$u" ] && continue
    r=$(curl -s -m 12 -X POST -H 'Content-Type: application/json' -H 'User-Agent: Mozilla/5.0 (research; read-only)' \
          --data '{"jsonrpc":"2.0","id":1,"method":"eth_blockNumber","params":[]}' "$u" 2>/dev/null)
    case "$r" in *result*) echo "$u"; return 0;; esac
  done
  echo ""; return 1
}

RPC=$(pick "https://rpc.scroll.io" "https://scroll-rpc.publicnode.com" "https://scroll.drpc.org" || true)
if [ -z "$RPC" ]; then
  echo "WARNING: no working Scroll RPC found"
else
  echo "Scroll fork RPC selected"
  [ -n "${GITHUB_ENV:-}" ] && echo "SCROLL_FORK_RPC=$RPC" >> "$GITHUB_ENV"
  export SCROLL_FORK_RPC="$RPC"
fi

python3 - <<'PY' || echo "live recheck failed (non-fatal)"
import json, os, time, urllib.request
RPC = os.environ.get("SCROLL_FORK_RPC", "https://rpc.scroll.io")
def rpc(method, params, timeout=30):
    body = json.dumps({"jsonrpc":"2.0","id":1,"method":method,"params":params}).encode()
    req = urllib.request.Request(RPC, data=body, headers={"Content-Type":"application/json",
                              "User-Agent":"Mozilla/5.0 (research; read-only)"})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        d = json.loads(r.read().decode())
    return d.get("result") or (_ for _ in ()).throw(RuntimeError(str(d.get("error"))))
def call(to, data):
    return rpc("eth_call", [{"to": to, "data": data}, "latest"])
def w(h): 
    h=h[2:] if h.startswith("0x") else h
    return [h[i:i+64] for i in range(0,len(h)-63,64)]
def u(x): return int(x,16)
def a(x): return "0x"+x[-40:]
PAIRS = {
  "weth_crv_unpaused":   "0x0c502351461904cd9430eefdc7b9df1c30e74032",
  "reth_usdc_unpaused1": "0xaa230793737ddc517c2db9e42ca3a65178eda6d0",
  "reth_usdc_unpaused2": "0xdefebd03e8e339737f24b67737e9d002cb03f00b",
  "big_weth_usdc_paused":"0xa5832adc1e4487b635a483722e4fc34062467479",
  "usdc_weth_paused_liq":"0x63fdafa50c09c49f594f47ea7194b721291ec50f",
  "reth_usdc_brokenscale":"0x8b606e4aa85281ed1cbec2d25baa6ab8f3541450",
}
S = {"paused":"0x5c975abb","rate":"0x171ef0b2","get_rate":"0xfe9f6e24",
     "asset":"0x38d52e0f","coll":"0xd8dfeb45","balanceOf":"0x70a08231"}
out = {"checked_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()), "rpc_label": "public-scroll"}
out["block"] = int(rpc("eth_blockNumber", []), 16)
for name, pair in PAIRS.items():
    row = {"pair": pair}
    try:
        row["paused"] = u(w(call(pair, S["paused"]))[0])
        row["rate_stored"] = u(w(call(pair, S["rate"]))[0])
        gr = w(call(pair, S["get_rate"]))
        row["rate_refreshed"] = u(gr[1]); row["updated"] = u(gr[0])
        asset = a(w(call(pair, S["asset"]))[0]); coll = a(w(call(pair, S["coll"]))[0])
        row["asset"] = asset; row["collateral"] = coll
        row["asset_bal"] = u(w(call(asset, S["balanceOf"]+pair[2:].rjust(64,"0")))[0])
        row["coll_bal"] = u(w(call(coll, S["balanceOf"]+pair[2:].rjust(64,"0")))[0])
    except Exception as e:
        row["error"] = str(e)[:120]
    out[name] = row
os.makedirs("ci-out", exist_ok=True)
json.dump(out, open("ci-out/live_recheck.json","w"), indent=1)
print(json.dumps(out, indent=1)[:2000])
PY
exit 0
