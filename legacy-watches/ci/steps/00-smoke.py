#!/usr/bin/env python3
"""H2-09 legacy-watches smoke step: chain liveness + block pinning.
Read-only. Public RPCs only (env vars used if set; never printed).
"""
import json, os, urllib.request, concurrent.futures, datetime, sys

PUBLIC = {
    "ethereum": ["https://ethereum-rpc.publicnode.com", "https://eth.drpc.org"],
    "bsc": ["https://bsc-dataseed.binance.org", "https://bsc.publicnode.com"],
    "hedera": ["https://mainnet.hashio.io/api"],
    "wanchain": ["https://gwan-ssl.wandevs.org:56891"],
    "astar": ["https://evm.astar.network", "https://rpc.astar.network"],
    "moonbeam": ["https://moonbeam.drpc.org", "https://moonbeam.api.onfinality.io/public"],
    "flow-evm": ["https://mainnet.evm.nodes.onflow.org"],
    "flare": ["https://flare-api.flare.network/ext/C/rpc"],
    "polygon": ["https://polygon-bor-rpc.publicnode.com"],
    "blast": ["https://rpc.blast.io"],
    "arbitrum": ["https://arb1.arbitrum.io/rpc"],
}
ENV = {
    "bsc": "BSC_RPC_URL", "polygon": "POLYGON_RPC_URL", "flare": "FLARE_RPC_URL",
    "ethereum": "RPC_URL", "arbitrum": "ARB_RPC_URL",
}

def rpc(url, method, params):
    req = urllib.request.Request(
        url,
        data=json.dumps({"jsonrpc": "2.0", "id": 1, "method": method, "params": params}).encode(),
        headers={"Content-Type": "application/json", "User-Agent": "Mozilla/5.0"})
    return json.load(urllib.request.urlopen(req, timeout=25))

def probe(chain):
    urls = []
    ev = ENV.get(chain)
    if ev and os.environ.get(ev):
        urls.append(("env:" + ev, os.environ[ev]))
    urls += [("public", u) for u in PUBLIC.get(chain, [])]
    for tag, u in urls:
        try:
            r = rpc(u, "eth_blockNumber", [])
            blk = int(r["result"], 16)
            blk2 = rpc(u, "eth_getBlockByNumber", ["latest", False])["result"]
            ts = datetime.datetime.utcfromtimestamp(int(blk2["timestamp"], 16)).isoformat() + "Z"
            return chain, {"block": blk, "block_ts_utc": ts, "src": tag, "url": "(redacted)" if tag.startswith("env") else u}
        except Exception as e:
            last = f"{tag}: {type(e).__name__}"
    return chain, {"error": last}

res = {"fetched_utc": datetime.datetime.utcnow().isoformat() + "Z", "chains": {}}
with concurrent.futures.ThreadPoolExecutor(8) as ex:
    for ch, info in ex.map(probe, list(PUBLIC.keys())):
        res["chains"][ch] = info
# Stacks via Hiro
try:
    r = json.load(urllib.request.urlopen(urllib.request.Request(
        "https://api.hiro.so/v2/info", headers={"User-Agent": "Mozilla/5.0"}), timeout=25))
    res["chains"]["stacks"] = {"block": r["stacks_tip_height"], "block_ts_utc": r.get("stacks_tip_time"), "src": "public", "url": "https://api.hiro.so"}
except Exception as e:
    res["chains"]["stacks"] = {"error": type(e).__name__}

os.makedirs("ci-out", exist_ok=True)
json.dump(res, open("ci-out/00-smoke.json", "w"), indent=1)
for ch, info in sorted(res["chains"].items()):
    print(f"{ch:10s} {info.get('block','ERR')} {info.get('block_ts_utc','')} {info.get('src','')}")
print("smoke OK")
