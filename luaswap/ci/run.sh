#!/usr/bin/env bash
# =============================================================================
# C2-04 LuaSwap (Viction) — CI helper
# - probes for a working Viction RPC and exports VICTION_RPC_URL for the
#   forge test step (the workflow only auto-probes an Ethereum fork RPC)
# - records a small read-only state snapshot into ci-out/
# No transactions are signed or sent; no secrets are printed.
# =============================================================================
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p ci-out

pick() {
  for u in "$@"; do
    [ -z "$u" ] && continue
    r=$(curl -s -m 15 -X POST -H 'Content-Type: application/json' \
          --data '{"jsonrpc":"2.0","id":1,"method":"eth_getCode","params":["0x347f551eaba062167779c9c336aa681526857b81","latest"]}' "$u" 2>/dev/null || true)
    # require a real contract code response (not a CF challenge / error)
    case "$r" in *'"result":"0x60806040'*) echo "$u"; return 0;; esac
  done
  return 1
}

PICK=$(pick "${VICTION_RPC_URL:-}" "https://viction.drpc.org" "https://rpc.viction.xyz" || true)
if [ -z "$PICK" ]; then
  echo "ERROR: no working Viction RPC found" >&2
  exit 1
fi
echo "[ci] Viction RPC selected: $PICK"
if [ -n "${GITHUB_ENV:-}" ]; then
  echo "VICTION_RPC_URL=$PICK" >> "$GITHUB_ENV"
fi

# read-only snapshot of the frozen LuaSwap state
python3 - "$PICK" <<'PY'
import json, sys
from urllib.request import Request, urlopen
RPC = sys.argv[1]
UA = {"Content-Type": "application/json", "User-Agent": "Mozilla/5.0"}
def call(to, data):
    payload = {"jsonrpc": "2.0", "id": 1, "method": "eth_call", "params": [{"to": to, "data": data}, "latest"]}
    req = Request(RPC, data=json.dumps(payload).encode(), headers=UA)
    j = json.load(urlopen(req, timeout=60))
    if "result" not in j:
        raise RuntimeError(j)
    return j["result"]
def block_number():
    payload = {"jsonrpc": "2.0", "id": 1, "method": "eth_blockNumber", "params": []}
    req = Request(RPC, data=json.dumps(payload).encode(), headers=UA)
    return int(json.load(urlopen(req, timeout=60))["result"], 16)
def dec(h):
    return int(h, 16) if h and h != "0x" else 0
WTOMO = "0xb1f66997a5760428d3a87d68b90bfe0ae64121cc"
pairs = {
    "pair1_USDT_WTOMO": "0x347f551eaba062167779c9c336aa681526857b81",
    "pair2_USDT_LUA": "0x08975663ac228c6d208fa32c968569e5939fb634",
    "pair4_LUA_WTOMO": "0x810a21afe69fe356697a9824930904383930bd96",
    "pair18_ETH_LUA": "0x54a12b95a207e7db77cac8b7cdfcd5e90168187d",
    "pair19_BTC_WTOMO": "0x4fbd8ba72262665dae92f69b48e939839654771e",
}
res = {"block": block_number(), "rpc": RPC, "pairs": {}, "wtomo": {}}
for name, addr in pairs.items():
    r = call(addr, "0x0902f1ac")
    res["pairs"][name] = {"address": addr, "reserve0": dec(r[2:66]), "reserve1": dec(r[66:130])}
def native_balance(addr):
    payload = {"jsonrpc": "2.0", "id": 1, "method": "eth_getBalance", "params": [addr, "latest"]}
    req = Request(RPC, data=json.dumps(payload).encode(), headers=UA)
    return int(json.load(urlopen(req, timeout=60))["result"], 16)
res["wtomo"]["totalSupply"] = dec(call(WTOMO, "0x18160ddd"))
res["wtomo"]["vicBacking"] = native_balance(WTOMO)
res["wtomo"]["backed_1to1"] = res["wtomo"]["totalSupply"] == res["wtomo"]["vicBacking"]
with open("ci-out/viction-state.json", "w") as f:
    json.dump(res, f, indent=1)
print(json.dumps(res, indent=1))
PY

echo "[ci] snapshot written to ci-out/viction-state.json"
