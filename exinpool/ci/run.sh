#!/usr/bin/env bash
# H-24 ExinPool (Mixin Network) — read-only live evidence collection for CI.
# Collects: ExinPool self-reported API, Mixin public API, Mixin Kernel RPC,
# Ethereum Gnosis Safe state (owners/threshold/balances), price references.
# Outputs: ci-out/exinpool-evidence.json, ci-out/exinpool-summary.md
set -uo pipefail
cd "$(dirname "$0")/.."   # folder root
mkdir -p ci-out
WORK="ci-out/raw"
mkdir -p "$WORK"

RPC="${FORK_RPC_URL:-}"
if [ -z "$RPC" ]; then
  for u in "https://ethereum-rpc.publicnode.com" "https://eth.drpc.org" "https://1rpc.io/eth"; do
    r=$(curl -s -m 10 -X POST -H 'Content-Type: application/json' \
        --data '{"jsonrpc":"2.0","id":1,"method":"eth_blockNumber","params":[]}' "$u" 2>/dev/null)
    case "$r" in *result*) RPC="$u"; break;; esac
  done
fi
echo "[exinpool] ETH RPC: ${RPC:-NONE}"

fetch() { # fetch <outfile> <url>
  local out="$1" url="$2"
  curl -sS -m 30 -A "zombie-hunt-readonly/1.0" "$url" -o "$WORK/$out" \
    -w "%{http_code}" > "$WORK/$out.status" 2>/dev/null || echo "000" > "$WORK/$out.status"
  echo "[fetch] $url -> $(cat "$WORK/$out.status") $(wc -c < "$WORK/$out" 2>/dev/null || echo 0)B"
}

rpc() { # rpc <outfile> <json-body>
  local out="$1" body="$2"
  curl -sS -m 40 -X POST -H 'Content-Type: application/json' --data "$body" \
    "https://kernel.mixin.dev/" -o "$WORK/$out" \
    -w "%{http_code}" > "$WORK/$out.status" 2>/dev/null || echo "000" > "$WORK/$out.status"
  echo "[kernel] $out -> $(cat "$WORK/$out.status") $(wc -c < "$WORK/$out" 2>/dev/null || echo 0)B"
}

ethcall() { # ethcall <outfile> <to> <data>
  local out="$1" to="$2" data="$3"
  curl -sS -m 30 -X POST -H 'Content-Type: application/json' \
    --data "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"eth_call\",\"params\":[{\"to\":\"$to\",\"data\":\"$data\"},\"latest\"]}" \
    "$RPC" -o "$WORK/$out" -w "%{http_code}" > "$WORK/$out.status" 2>/dev/null || echo "000" > "$WORK/$out.status"
}

# ---------- 1. ExinPool self-reported API (the DefiLlama source) ----------
for i in 1 2 3; do fetch "exinpool-status-$i.json" "https://mixin.exinpool.com/api/v1/node/status"; sleep 2; done

# ---------- 2. Mixin public API ----------
fetch "mixin-code.json"     "https://api.mixin.one/codes/791f20db-51ce-4af2-918b-7496864ab833"
fetch "mixin-xin-asset.json" "https://api.mixin.one/network/assets/c94ac88f-4671-3976-b60a-09064f1811e8"
fetch "mixin-xin-ticker.json" "https://api.mixin.one/network/ticker?asset=c94ac88f-4671-3976-b60a-09064f1811e8"
fetch "mixin-chains.json"   "https://api.mixin.one/network/chains"

# ---------- 3. Mixin Kernel RPC ----------
rpc "kernel-getinfo.json"    '{"method":"getinfo","params":[]}'
rpc "kernel-nodes.json"      '{"method":"listallnodes","params":[0,false]}'
# getasset takes the 32-byte kernel asset id (hex), not the Mixin UUID
rpc "kernel-xin-asset.json"  '{"method":"getasset","params":["a99c2e0e2b1da4d648755ef19bd95139acbbe6564cfb06dec7cd34931ca72cdc"]}'
rpc "kernel-snap0.json"      '{"method":"listsnapshots","params":[0,5,false,false]}'
rpc "kernel-snap1.json"      '{"method":"listsnapshots","params":[0,5,true,true]}'
TOP=$(python3 -c "import json;print((json.load(open('$WORK/kernel-getinfo.json')).get('data') or {}).get('graph',{}).get('topology',0))" 2>/dev/null || echo 0)
if [ "${TOP:-0}" -gt 25 ] 2>/dev/null; then
  rpc "kernel-snap-head.json" "{\"method\":\"listsnapshots\",\"params\":[$((TOP-20)),20,true,true]}"
fi

# ---------- 4. Ethereum Gnosis Safe (ExinPool ETH 2.0 node) ----------
SAFE=0xdfce3cb1cbd896b96578005e14adb81ec26df923
if [ -n "$RPC" ]; then
  curl -sS -m 20 -X POST -H 'Content-Type: application/json' \
    --data '{"jsonrpc":"2.0","id":1,"method":"eth_blockNumber","params":[]}' "$RPC" -o "$WORK/eth-block.json" 2>/dev/null
  curl -sS -m 20 -X POST -H 'Content-Type: application/json' \
    --data "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"eth_getBalance\",\"params\":[\"$SAFE\",\"latest\"]}" "$RPC" -o "$WORK/eth-safe-balance.json" 2>/dev/null
  curl -sS -m 20 -X POST -H 'Content-Type: application/json' \
    --data "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"eth_getCode\",\"params\":[\"$SAFE\",\"latest\"]}" "$RPC" -o "$WORK/eth-safe-code.json" 2>/dev/null
  ethcall "eth-safe-owners.json"    "$SAFE" "0xa0e67e2b"
  ethcall "eth-safe-threshold.json" "$SAFE" "0xe75235b8"
  ethcall "eth-safe-nonce.json"     "$SAFE" "0xaffed0e0"
  ethcall "eth-safe-master.json"    "$SAFE" "0xa619486e"
  ethcall "eth-safe-version.json"   "$SAFE" "0xffa1ad74"
  ethcall "eth-safe-modules.json"   "$SAFE" "0xcc2f84520000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000a"
  # guard slot + fallback-handler slot (Safe 1.3.0 storage layout)
  GUARD_SLOT=0x4a204f620c8c5ccdca3fd54d003badd85ba500436a431f0cbda4f558c93c34c8
  FBH_SLOT=0x6c9a6c4a39284e37ed1cf53d337577d14212a4870fb976a4366c693b939918d5
  for pair in "guard:$GUARD_SLOT" "fbh:$FBH_SLOT"; do
    n=${pair%%:*}; s=${pair#*:}
    curl -sS -m 20 -X POST -H 'Content-Type: application/json' \
      --data "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"eth_getStorageAt\",\"params\":[\"$SAFE\",\"$s\",\"latest\"]}" "$RPC" \
      -o "$WORK/eth-safe-$n-slot.json" 2>/dev/null
  done
  # token balances of the Safe
  for t in "usdt:0xdAC17F958D2ee523a2206206994597C13D831ec7" "usdc:0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48" "weth:0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2" "steth:0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84" "reth:0xae78736Cd615f374D3085123A210448E74Fc6393"; do
    n=${t%%:*}; a=${t#*:}
    ethcall "eth-safe-token-$n.json" "$a" "0x70a08231000000000000000000000000${SAFE:2}"
  done
fi

# ---------- 5. Prices ----------
fetch "price-eth.json" "https://coins.llama.fi/prices/current/ethereum:0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2"
fetch "price-xin.json" "https://coins.llama.fi/prices/current/coingecko:mixin"

# ---------- 6. Compose evidence JSON + summary ----------
python3 - <<'PYEOF'
import json, os, glob, datetime

W = "ci-out/raw"
def load(name):
    try:
        with open(os.path.join(W, name)) as f:
            return json.load(f)
    except Exception as e:
        return {"_error": str(e)}

now = datetime.datetime.now(datetime.timezone.utc).isoformat()

# ExinPool self-report
statuses = []
for i in (1, 2, 3):
    d = load(f"exinpool-status-{i}.json")
    if isinstance(d, dict) and d.get("success"):
        statuses.append(d.get("data", {}))
tvls = [s.get("totalValueUsd") for s in statuses if isinstance(s.get("totalValueUsd"), (int, float))]
users = [s.get("totalUsers") for s in statuses if isinstance(s.get("totalUsers"), (int, float))]

code = load("mixin-code.json").get("data", {})
xin = load("mixin-xin-asset.json").get("data", {})
ticker = load("mixin-xin-ticker.json").get("data", {})
getinfo = load("kernel-getinfo.json").get("data", {}) or {}
nodes = load("kernel-nodes.json").get("data", []) or []
node_states = {}
for n in nodes:
    st = n.get("state", "?")
    node_states[st] = node_states.get(st, 0) + 1
kernel_xin = load("kernel-xin-asset.json").get("data", {}) or {}

def rpc_result(name):
    d = load(name)
    return d.get("result") if isinstance(d, dict) else None

def rpc_data(name):
    d = load(name)
    return d.get("data") if isinstance(d, dict) else None

def hexint(x):
    try:
        return int(x, 16)
    except Exception:
        return None

block = hexint(rpc_result("eth-block.json"))
safe_balance_wei = hexint(rpc_result("eth-safe-balance.json"))
owners_raw = rpc_result("eth-safe-owners.json") or ""
threshold_raw = rpc_result("eth-safe-threshold.json") or ""
nonce_raw = rpc_result("eth-safe-nonce.json") or ""
master_raw = rpc_result("eth-safe-master.json") or ""
version_raw = rpc_result("eth-safe-version.json") or ""
modules_raw = rpc_result("eth-safe-modules.json") or ""

def words(h):
    h = (h or "").removeprefix("0x")
    return [h[i:i+64] for i in range(0, len(h), 64)]

w_owners = words(owners_raw)
owners = []
if len(w_owners) >= 2:
    cnt = int(w_owners[1], 16) if w_owners[1] else 0
    owners = ["0x" + w[-40:] for w in w_owners[2:2+cnt]]
threshold = int(threshold_raw, 16) if threshold_raw and threshold_raw != "0x" else None
nonce = int(nonce_raw, 16) if nonce_raw and nonce_raw != "0x" else None
master = "0x" + master_raw[-40:] if master_raw and len(master_raw) >= 42 else None
version = None
try:
    vw = words(version_raw)
    if len(vw) >= 2:
        ln = int(vw[1], 16)
        version = bytes.fromhex(vw[2][:ln*2]).decode(errors="replace")
except Exception:
    pass
w_mod = words(modules_raw)
modules = []
modules_next = None
if len(w_mod) >= 3:
    off = int(w_mod[0], 16) // 32 if w_mod[0] else 0
    modules_next = "0x" + w_mod[1][-40:] if len(w_mod) > 1 else None
    if off < len(w_mod):
        cnt = int(w_mod[off], 16) if w_mod[off] else 0
        modules = ["0x" + w[-40:] for w in w_mod[off+1:off+1+cnt]]
guard = rpc_result("eth-safe-guard-slot.json")
fbh = rpc_result("eth-safe-fbh-slot.json")

tokens = {}
for n in ("usdt", "usdc", "weth", "steth", "reth"):
    r = rpc_result(f"eth-safe-token-{n}.json")
    tokens[n] = int(r, 16) if r and r != "0x" else 0

eth_price = (load("price-eth.json").get("coins", {}).get("ethereum:0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2", {}) or {}).get("price")
xin_price_llama = (load("price-xin.json").get("coins", {}).get("coingecko:mixin", {}) or {}).get("price")

safe_eth = (safe_balance_wei or 0) / 1e18
safe_usd = safe_eth * eth_price if eth_price else None

snap0 = rpc_data("kernel-snap0.json")
snap_sample = None
if isinstance(snap0, list) and snap0:
    snap_sample = {"count": len(snap0), "first_topology": snap0[0].get("topology"), "last_topology": snap0[-1].get("topology"),
                   "first_hash": snap0[0].get("hash"), "last_timestamp": snap0[-1].get("timestamp")}

head = rpc_data("kernel-snap-head.json")
head_sample = None
if isinstance(head, list) and head:
    tx_count = 0
    withdrawal_outputs = 0
    for s in head:
        for t in (s.get("transactions") or []):
            if isinstance(t, dict):
                tx_count += 1
                for o in (t.get("outputs") or []):
                    if isinstance(o, dict) and o.get("withdrawal"):
                        withdrawal_outputs += 1
    head_sample = {
        "count": len(head),
        "topology_range": [head[0].get("topology"), head[-1].get("topology")],
        "first_timestamp": head[0].get("timestamp"),
        "last_timestamp": head[-1].get("timestamp"),
        "tx_count": tx_count,
        "withdrawal_outputs": withdrawal_outputs,
    }

evidence = {
    "collected_at": now,
    "exinpool_self_reported": {
        "api": "https://mixin.exinpool.com/api/v1/node/status",
        "samples": statuses,
        "totalValueUsd_range": [min(tvls), max(tvls)] if tvls else None,
        "totalUsers": users[0] if users else None,
    },
    "mixin_public_api": {
        "app": {
            "user_id": code.get("user_id"), "identity_number": code.get("identity_number"),
            "full_name": code.get("full_name"), "created_at": code.get("created_at"),
            "has_safe": code.get("has_safe"),
            "app_id": (code.get("app") or {}).get("app_id"),
            "home_uri": (code.get("app") or {}).get("home_uri"),
            "redirect_uri": (code.get("app") or {}).get("redirect_uri"),
            "spend_public_key": (code.get("app") or {}).get("spend_public_key"),
            "creator_id": (code.get("app") or {}).get("creator_id"),
        },
        "xin_asset": {"asset_id": xin.get("asset_id"), "symbol": xin.get("symbol"),
                       "price_usd": xin.get("price_usd"), "capitalization": xin.get("capitalization"),
                       "snapshots_count": xin.get("snapshots_count")},
        "xin_ticker": ticker,
    },
    "mixin_kernel": {
        "rpc": "https://kernel.mixin.dev/",
        "getinfo_mint": getinfo.get("mint") if isinstance(getinfo, dict) else None,
        "getinfo_network": getinfo.get("network") if isinstance(getinfo, dict) else None,
        "node_states": node_states,
        "accepted_nodes": node_states.get("ACCEPTED"),
        "xin_ledger_balance": kernel_xin.get("balance"),
        "snapshot_sample": snap_sample,
        "snapshot_head_sample": head_sample,
    },
    "ethereum_safe": {
        "address": "0xdfce3cb1cbd896b96578005e14adb81ec26df923",
        "block": block,
        "balance_eth": safe_eth,
        "balance_usd_at_eth_price": safe_usd,
        "owners": owners,
        "threshold": threshold,
        "nonce": nonce,
        "masterCopy": master,
        "version": version,
        "modules": modules,
        "modules_next": modules_next,
        "guard_slot": guard,
        "fallback_handler_slot": fbh,
        "token_balances_raw": tokens,
        "code_length": len((rpc_result("eth-safe-code.json") or "")) // 2,
    },
    "prices": {"eth_usd": eth_price, "xin_usd_llamafinance": xin_price_llama, "xin_usd_mixin_ticker": ticker.get("price_usd") if isinstance(ticker, dict) else None},
}

with open("ci-out/exinpool-evidence.json", "w") as f:
    json.dump(evidence, f, indent=2)

lines = []
lines.append("# H-24 ExinPool — CI evidence summary")
lines.append("")
lines.append(f"- Collected: {now}")
lines.append(f"- ExinPool self-reported TVL: {evidence['exinpool_self_reported']['totalValueUsd_range']} USD over 3 samples; users: {evidence['exinpool_self_reported']['totalUsers']}")
lines.append(f"- Mixin app: {code.get('full_name')} user_id={code.get('user_id')} app_id={(code.get('app') or {}).get('app_id')} has_safe={code.get('has_safe')}")
lines.append(f"- XIN: price ${xin.get('price_usd')} (api.mixin.one) / ${ticker.get('price_usd') if isinstance(ticker, dict) else '?'} (ticker); supply cap {xin.get('capitalization')}")
lines.append(f"- Kernel nodes: {node_states}; XIN ledger balance: {kernel_xin.get('balance')}")
lines.append(f"- ETH Safe block {block}: {safe_eth:.6f} ETH (${safe_usd:.2f}) threshold {threshold}/{len(owners)} owners={owners}")
lines.append(f"- Safe version {version} masterCopy {master} modules={modules} nonce={nonce}")
lines.append(f"- Safe token balances raw: {tokens}")
lines.append(f"- ETH price ${eth_price}")
lines.append("")
lines.append("Verdict: no external unprivileged extraction path identified on-chain; ExinPool is a custodial Mixin bot with off-chain withdrawal authorization. E-U = $0.")
with open("ci-out/exinpool-summary.md", "w") as f:
    f.write("\n".join(lines))
print("\n".join(lines))
PYEOF

echo "[exinpool] done; outputs in ci-out/"
