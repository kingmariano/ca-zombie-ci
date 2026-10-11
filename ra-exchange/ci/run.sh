#!/usr/bin/env bash
# Custom CI job for ra-exchange (Fraxtal). Runs inside GitHub Actions.
# 1) bytecode equivalence check: verified source vs deployed code for the value-holding impls
# 2) live-state re-verification at a fresh block (writes ci-out/live_recheck.json)
# No secrets are used or printed here.
set -uo pipefail
cd "$(dirname "$0")/.."
mkdir -p ci-out

# --- pick a working public Fraxtal RPC (keyless) and export it for the forge tests ---
pick() {
  for u in "$@"; do
    [ -z "$u" ] && continue
    r=$(curl -s -m 12 -X POST -H 'Content-Type: application/json' \
          --data '{"jsonrpc":"2.0","id":1,"method":"eth_blockNumber","params":[]}' "$u" 2>/dev/null)
    case "$r" in *result*) echo "$u"; return 0;; esac
  done
  echo ""; return 1
}
FRAX_PICK=$(pick "https://rpc.frax.com" "https://fraxtal-rpc.publicnode.com" "https://fraxtal.drpc.org" "https://fraxtal.gateway.tenderly.co" || true)
if [ -n "$FRAX_PICK" ]; then
  echo "[ci] Fraxtal RPC: $FRAX_PICK"
  if [ -n "${GITHUB_ENV:-}" ]; then echo "FRAXTAL_RPC_URL=$FRAX_PICK" >> "$GITHUB_ENV"; fi
  export FRAXTAL_RPC_URL="$FRAX_PICK"
else
  echo "[ci] WARNING: no working Fraxtal RPC found"
fi

echo "=== [1/2] bytecode equivalence check ==="
python3 -u ci/bytecode_check.py 2>&1 | tee ci-out/bytecode_check.log || true

echo "=== [2/2] live-state recheck ==="
python3 -u - <<'PY' 2>&1 | tee ci-out/live_recheck.log
import json, urllib.request, time, os
RPC = os.environ.get("FRAXTAL_RPC_URL", "https://rpc.frax.com")
def rpc(method, params):
    req = urllib.request.Request(RPC, data=json.dumps({"jsonrpc":"2.0","id":1,"method":method,"params":params}).encode(),
                                 headers={"Content-Type":"application/json","User-Agent":"research/1.0"})
    with urllib.request.urlopen(req, timeout=60) as r:
        return json.loads(r.read())["result"]
block = int(rpc("eth_blockNumber", []), 16)
def call(to, data):
    return rpc("eth_call", [{"to":to,"data":data}, "latest"])
def du(h): return 0 if h in (None,"0x") else int(h,16)
def addr(h): return "0x"+h[-40:]
sel = {
 "ownerOf":"0x6352211e","liquidity":"0x1a686502","protocolFees":"0x1ad8b03b","getReserves":"0x0902f1ac",
 "totalSupply":"0x18160ddd","isTokenLive":"0x2a8d07b3","veSupply":"0x047fc9aa","firstPeriod":"0xc4e3a63b",
 "treasury":"0x61d027b3","balanceOf":"0x70a08231",
}
out = {"block": block, "rpc": "public"}
NFP="0xAAA78E8C4241990B4ce159E105dA08129345946A"
out["nft1086_owner"] = addr(call(NFP, sel["ownerOf"]+hex(1086)[2:].rjust(64,"0")))
out["nft36_owner"]  = addr(call(NFP, sel["ownerOf"]+hex(36)[2:].rjust(64,"0")))
out["nft38_owner"]  = addr(call(NFP, sel["ownerOf"]+hex(38)[2:].rjust(64,"0")))
for name,pool in [("poolA","0x45a51ed99e94c2b3584386009c0cccc5a7957a84"),
                  ("poolB","0x52992f0ca147f25cba0b727f281848220f6d4c24"),
                  ("poolC","0x7767861f3638dd69ad131f15eff75e7c886f89b1")]:
    out[name+"_liquidity"] = du(call(pool, sel["liquidity"]))
    pf = call(pool, sel["protocolFees"])
    out[name+"_protocolFees0"] = du(pf[2:66]); out[name+"_protocolFees1"] = du(pf[66:130])
r = call("0xaa08c24a76a1ad5de28bc56b23413d13b8be6eeb", sel["getReserves"])
out["pairA_reserve0"] = du(r[2:66]); out["pairA_reserve1"] = du(r[66:130])
out["pairA_bal0"] = du(call("0xfc00000000000000000000000000000000000001", sel["balanceOf"]+("aa08c24a76a1ad5de28bc56b23413d13b8be6eeb").rjust(64,"0")))
out["ve_totalSupply"] = du(call("0xAAAEa1fB9f3DE3F70E89f37B69Ab11B47eb9Ce6F", sel["totalSupply"]))
out["ra_totalSupply"] = du(call("0xAAA9FB3a08C13BA97Ae0F518B3AfA5C4a81498Fc", sel["totalSupply"]))
out["feeCollector_isTokenLive"] = bool(du(call("0xAAA2A49958a443Dc9d19FdDEe873B5D1d6e84A2f", sel["isTokenLive"])))
print(json.dumps(out, indent=1))
json.dump(out, open("ci-out/live_recheck.json","w"), indent=1)
PY

echo "done"
