#!/usr/bin/env bash
# CI helper for the yield-millionaire deep dive.
# 1) selects a working PUBLIC Base RPC (no keyed URLs anywhere) and exports
#    BASE_FORK_URL for the foundry step.
# 2) dumps a small live-state snapshot to ci-out/live-state.json (public RPCs only,
#    multi-endpoint fallback; partial data still written).
set -uo pipefail

pick() {
  for u in "$@"; do
    [ -z "$u" ] && continue
    r=$(curl -s -m 12 -X POST -H 'Content-Type: application/json' \
          --data '{"jsonrpc":"2.0","id":1,"method":"eth_blockNumber","params":[]}' "$u" 2>/dev/null)
    case "$r" in *result*) echo "$u"; return 0;; esac
  done
  return 1
}

PICK=$(pick "https://base-rpc.publicnode.com" "https://base.drpc.org" "https://mainnet.base.org" || true)
if [ -n "$PICK" ]; then
  echo "[ci] base fork rpc selected (public)"
  if [ -n "${GITHUB_ENV:-}" ]; then echo "BASE_FORK_URL=$PICK" >> "$GITHUB_ENV"; fi
else
  echo "[ci] WARNING: no public base rpc responded; test will fall back to publicnode"
fi

mkdir -p ci-out
python3 - "${PICK:-https://base-rpc.publicnode.com}" <<'PY'
import json, sys, time, urllib.request

RPCS = [sys.argv[1]]
for u in ("https://base-rpc.publicnode.com", "https://base.drpc.org", "https://mainnet.base.org"):
    if u not in RPCS:
        RPCS.append(u)
UA = {"Content-Type": "application/json", "User-Agent": "Mozilla/5.0"}

def call(method, params):
    last = None
    for _attempt in range(2):
        for rpc in RPCS:
            try:
                req = urllib.request.Request(
                    rpc,
                    data=json.dumps({"jsonrpc": "2.0", "id": 1, "method": method, "params": params}).encode(),
                    headers=UA)
                with urllib.request.urlopen(req, timeout=60) as r:
                    d = json.loads(r.read())
                if isinstance(d, dict) and "result" in d:
                    return d["result"]
                last = d
            except Exception as exc:  # noqa: BLE001
                last = str(exc)[:100]
            time.sleep(0.5)
    raise RuntimeError("all rpc attempts failed for %s: %s" % (method, last))

def eth_call(to, data):
    return call("eth_call", [{"to": to, "data": data}, "latest"])

def dec_u(hexstr):
    return int(hexstr, 16) if hexstr and hexstr != "0x" else 0

def dec_addr(hexstr):
    return "0x" + hexstr[-40:]

def dec_string(hexstr):
    b = bytes.fromhex(hexstr[2:])
    if len(b) >= 64:
        ln = int.from_bytes(b[32:64], "big")
        return b[64:64 + ln].decode("utf-8", "replace")
    return ""

VAULT = "0xD4F3Ba2Fe4183c32A498Ad1ecF9Fc55308FcC029"
AUSDC = "0x4e65fE4DbA92790696d040ac24Aa414708F5c0AB"
USDC = "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913"
EIP1967_ADMIN = "0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103"
PAUSE_SLOT = "0xe86928725d42611a4d97f5379bd85d7fa4997f3070cc0d523b2643f8c6d82d05"

out = {"source": "public rpcs only", "vault": VAULT}

def safe(key, fn):
    try:
        out[key] = fn()
    except Exception as exc:  # noqa: BLE001
        out[key] = {"error": str(exc)[:140]}

safe("block", lambda: int(call("eth_blockNumber", []), 16))
safe("aUSDC_balanceOf_vault",
     lambda: dec_u(eth_call(AUSDC, "0x70a08231" + "0" * 24 + VAULT[2:].lower())))
safe("USDC_balanceOf_vault",
     lambda: dec_u(eth_call(USDC, "0x70a08231" + "0" * 24 + VAULT[2:].lower())))
safe("totalSupply", lambda: dec_u(eth_call(VAULT, "0x18160ddd")))          # totalSupply()
safe("totalAssets", lambda: dec_u(eth_call(VAULT, "0x01e1d114")))          # totalAssets()
safe("getAccumulatedFees", lambda: dec_u(eth_call(VAULT, "0x5df45a37")))   # getAccumulatedFees()
safe("getFee", lambda: dec_u(eth_call(VAULT, "0xced72f87")))               # getFee()
safe("VERSION", lambda: dec_string(eth_call(VAULT, "0xffa1ad74")))         # VERSION()
safe("getOwner", lambda: dec_addr(eth_call(VAULT, "0x893d20e8")))          # getOwner()
safe("pause_flags_slot", lambda: call("eth_getStorageAt", [VAULT, PAUSE_SLOT, "latest"]))
safe("proxy_admin", lambda: dec_addr(call("eth_getStorageAt", [VAULT, EIP1967_ADMIN, "latest"])))

json.dump(out, open("ci-out/live-state.json", "w"), indent=1)
print(json.dumps(out, indent=1))
PY
echo "[ci] live-state dump exit code: $? (non-fatal)"
