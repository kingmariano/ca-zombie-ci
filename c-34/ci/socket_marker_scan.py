#!/usr/bin/env python3
"""CI job: for every chain where the Socket gateway is deployed, enumerate the live route table
and bytecode-scan all live route/controller impls for the vulnerable WrappedTokenSwapperImpl
marker ("wrappedTokenSwapperImpl"). Output: ci-out/socket_marker_scan.json
Env: RPC_URL, ARB_RPC_URL, OP_RPC_URL, BASE_RPC_URL, BSC_RPC_URL, GNOSIS_RPC_URL.
"""
import json, os, time, urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "ci-out")
os.makedirs(OUT, exist_ok=True)
UA = {"User-Agent": "zombie-hunt/read-only", "Content-Type": "application/json"}
GW = "0x3a23F943181408EAC424116Af7b7790c94Cb97a5"
SEL = {"RC": "0xfd326921", "DR": "0x42cf3527", "CC": "0x15b9a8b8",
       "ROUTE": "0x263af8e8", "CTRL": "0x90ea7413"}
MARKER = "77726170706564546f6b656e53776170706572496d706c"  # ascii "wrappedTokenSwapperImpl"

CHAINS = [
    ("ethereum", os.environ.get("FORK_RPC_URL") or os.environ.get("RPC_URL") or "https://ethereum-rpc.publicnode.com"),
    ("arbitrum", os.environ.get("ARB_RPC_URL", "https://arb1.arbitrum.io/rpc")),
    ("optimism", os.environ.get("OP_RPC_URL", "https://mainnet.optimism.io")),
    ("base", os.environ.get("BASE_RPC_URL", "https://mainnet.base.org")),
    ("bsc", os.environ.get("BSC_RPC_URL", "https://bsc-dataseed.binance.org")),
    ("avalanche", "https://api.avax.network/ext/bc/C/rpc"),
    ("gnosis", os.environ.get("GNOSIS_RPC_URL", "https://rpc.gnosischain.com")),
]

def rpc(rpc_url, batch):
    req = urllib.request.Request(rpc_url, data=json.dumps(batch).encode(), headers=UA)
    for i in range(6):
        try:
            with urllib.request.urlopen(req, timeout=60) as r:
                out = json.load(r)
            res = out if isinstance(out, list) else [out]
            if any("error" in v for v in res):
                raise RuntimeError([v["error"] for v in res if "error" in v][0])
            return res
        except Exception:
            time.sleep(1.5 * (i + 1))
    raise RuntimeError("rpc failed")

def call_many(rpc_url, calls):
    out = []
    for i in range(0, len(calls), 40):
        chunk = calls[i:i + 40]
        batch = [{"jsonrpc": "2.0", "id": j + 1, "method": "eth_call",
                  "params": [{"to": t, "data": d}, "latest"]} for j, (t, d) in enumerate(chunk)]
        res = rpc(rpc_url, batch)
        m = {v["id"]: v["result"] for v in res}
        out.extend(m.get(j + 1) for j in range(len(chunk)))
    return out

def code_many(rpc_url, addrs):
    out = {}
    for i in range(0, len(addrs), 30):
        chunk = addrs[i:i + 30]
        batch = [{"jsonrpc": "2.0", "id": j + 1, "method": "eth_getCode",
                  "params": [a, "latest"]} for j, a in enumerate(chunk)]
        res = rpc(rpc_url, batch)
        m = {v["id"]: v["result"] for v in res}
        for j, a in enumerate(chunk):
            out[a] = m.get(j + 1) or "0x"
    return out

def addr(w):
    return "0x" + (w or "0x" + "0" * 64)[-40:]

def scan_chain(name, rpc_url):
    res = {"rpc": rpc_url}
    rc, dr, cc = call_many(rpc_url, [(GW, SEL["RC"]), (GW, SEL["DR"]), (GW, SEL["CC"])])
    if not rc or rc == "0x":
        return {"error": "no gateway"}
    n_routes, disabled, n_ctrl = int(rc, 16), addr(dr), int(cc, 16)
    route_vals = call_many(rpc_url, [(GW, SEL["ROUTE"] + i.to_bytes(32, "big").hex()) for i in range(n_routes)])
    ctrl_vals = call_many(rpc_url, [(GW, SEL["CTRL"] + i.to_bytes(32, "big").hex()) for i in range(n_ctrl)])
    routes = {str(i): addr(v) for i, v in enumerate(route_vals)}
    controllers = {str(i): addr(v) for i, v in enumerate(ctrl_vals)}
    zero = "0x" + "0" * 40
    live_routes = {k: v for k, v in routes.items() if v not in (disabled, zero)}
    live_ctrls = {k: v for k, v in controllers.items() if v not in (disabled, zero)}
    impls = sorted(set(live_routes.values()) | set(live_ctrls.values()))
    codes = code_many(rpc_url, impls)
    marker_hits = [a for a, c in codes.items() if MARKER in c.lower()]
    res.update({"routesCount": n_routes, "disabledRouteAddress": disabled,
                "live_routes": len(live_routes), "live_route_impls": sorted(set(live_routes.values())),
                "live_controller_impls": sorted(set(live_ctrls.values())),
                "impls_scanned": len(impls), "marker_hits": marker_hits})
    return res

def main():
    out = {}
    for name, rpc_url in CHAINS:
        try:
            out[name] = scan_chain(name, rpc_url)
            print(name, json.dumps(out[name])[:400], flush=True)
        except Exception as e:
            out[name] = {"error": str(e)[:160]}
            print(name, "ERROR", e, flush=True)
        time.sleep(0.5)
    json.dump(out, open(os.path.join(OUT, "socket_marker_scan.json"), "w"), indent=1)
    print("saved")

if __name__ == "__main__":
    main()
