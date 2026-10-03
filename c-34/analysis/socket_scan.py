#!/usr/bin/env python3
"""Read-only scan of the Socket Gateway route/controller tables (Ethereum mainnet).
Batched JSON-RPC eth_call. No transactions. Run: python3 socket_scan.py [rpc]
Writes socket_routes_<block>.json next to this file.

Selectors (cast sig):
  routesCount() 0xfd326921 | disabledRouteAddress() 0x42cf3527 | controllerCount() 0x15b9a8b8
  routes(uint32) 0x263af8e8 | controllers(uint32) 0x90ea7413
"""
import json, sys, urllib.request, time

RPC = sys.argv[1] if len(sys.argv) > 1 else "https://ethereum-rpc.publicnode.com"
GW = "0x3a23F943181408EAC424116Af7b7790c94Cb97a5"
SEL = {"RC": "0xfd326921", "DR": "0x42cf3527", "CC": "0x15b9a8b8",
       "ROUTE": "0x263af8e8", "CTRL": "0x90ea7413"}

def rpc(batch):
    req = urllib.request.Request(
        RPC, data=json.dumps(batch).encode(),
        headers={"Content-Type": "application/json", "User-Agent": "zombie-hunt/read-only"})
    last = None
    for attempt in range(6):
        try:
            with urllib.request.urlopen(req, timeout=60) as r:
                out = json.load(r)
            res = out if isinstance(out, list) else [out]
            if any(("error" in v) for v in res):
                raise RuntimeError([v["error"] for v in res if "error" in v][0])
            return res
        except Exception as e:
            last = e
            time.sleep(1.5 * (attempt + 1))
    raise RuntimeError(f"rpc failed: {last}")

def call_many(calls):
    """calls: list of (to, data). returns list of results in order."""
    out = []
    for i in range(0, len(calls), 35):
        chunk = calls[i:i + 35]
        batch = [{"jsonrpc": "2.0", "id": j + 1, "method": "eth_call",
                  "params": [{"to": t, "data": d}, "latest"]} for j, (t, d) in enumerate(chunk)]
        res = rpc(batch)
        m = {v["id"]: v["result"] for v in res}
        out.extend(m[j + 1] for j in range(len(chunk)))
    return out

def addr(word):
    return "0x" + word[-40:]

def main():
    bn = int(rpc([{"jsonrpc": "2.0", "id": 1, "method": "eth_blockNumber", "params": []}])[0]["result"], 16)
    print("block", bn)
    rc, dr, cc = call_many([(GW, SEL["RC"]), (GW, SEL["DR"]), (GW, SEL["CC"])])
    n_routes, disabled, n_ctrl = int(rc, 16), addr(dr), int(cc, 16)
    print("routesCount", n_routes, "disabledRoute", disabled, "controllersCount", n_ctrl)

    route_vals = call_many([(GW, SEL["ROUTE"] + i.to_bytes(32, "big").hex()) for i in range(n_routes)])
    ctrl_vals = call_many([(GW, SEL["CTRL"] + i.to_bytes(32, "big").hex()) for i in range(n_ctrl)])
    routes = {str(i): addr(v) for i, v in enumerate(route_vals)}
    controllers = {str(i): addr(v) for i, v in enumerate(ctrl_vals)}
    zero = "0x" + "0" * 40
    live_routes = {k: v for k, v in routes.items() if v not in (disabled, zero)}
    live_ctrls = {k: v for k, v in controllers.items() if v not in (disabled, zero)}
    out = {"block": bn, "gateway": GW, "disabledRouteAddress": disabled,
           "routesCount": n_routes, "controllersCount": n_ctrl,
           "routes": routes, "controllers": controllers,
           "live_route_ids": sorted(live_routes, key=int),
           "live_route_impls": sorted(set(live_routes.values())),
           "live_controller_ids": sorted(live_ctrls, key=int),
           "live_controller_impls": sorted(set(live_ctrls.values()))}
    p = __file__.replace("socket_scan.py", f"socket_routes_{bn}.json")
    json.dump(out, open(p, "w"), indent=1)
    print("live routes:", len(live_routes), "of", n_routes)
    print("live route impls:", len(out["live_route_impls"]))
    print("live controllers:", len(live_ctrls), "of", n_ctrl, out["live_controller_impls"])
    print("saved", p)

if __name__ == "__main__":
    main()
