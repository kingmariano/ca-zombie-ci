#!/usr/bin/env python3
"""Sui JSON-RPC client for the Ferra DLMM re-verification (public endpoints only, no keys)."""
import json, sys, time, urllib.request, urllib.error

ENDPOINTS = [
    "https://sui-rpc.publicnode.com",
    "https://sui-mainnet-endpoint.blockvision.org",
    "https://mainnet.suiet.app",
    "https://sui-mainnet.nodeinfra.com",
]

def rpc(method, params=None, retries=3):
    body = json.dumps({"jsonrpc": "2.0", "id": 1, "method": method, "params": params or []}).encode()
    last = None
    for attempt in range(retries):
        for u in ENDPOINTS:
            try:
                req = urllib.request.Request(u, data=body, headers={"Content-Type": "application/json", "User-Agent": "ferra-reverify/1.0"})
                with urllib.request.urlopen(req, timeout=40) as r:
                    j = json.loads(r.read().decode())
                if "result" in j:
                    return j["result"]
                last = j.get("error")
            except Exception as e:
                last = str(e)
        time.sleep(1.5 * (attempt + 1))
    raise RuntimeError(f"RPC failed: {method} {params}: {last}")

def get_object(oid, opts=None):
    opts = opts or {"showType": True, "showContent": True, "showOwner": True}
    return rpc("sui_getObject", [oid, opts])

def pkg_summary(oid):
    o = get_object(oid)
    d = o.get("data")
    if not d:
        return {"objectId": oid, "exists": False, "error": o.get("error")}
    c = (d.get("content") or {}).get("fields", {})
    return {
        "objectId": d.get("objectId"),
        "objVersion": d.get("version"),
        "type": d.get("type"),
        "owner": d.get("owner"),
        "pkgVersion": c.get("version"),
        "upgrade_policy": c.get("upgrade_policy"),
        "modules": c.get("modules"),
        "deps": [x.split("::")[0] for x in (c.get("dependencies") or [])],
        "typeOriginCount": len(c.get("type_origin_table") or []),
        "typeOrigins": sorted({t.get("module_name") for t in (c.get("type_origin_table") or [])}),
    }

if __name__ == "__main__":
    cmd = sys.argv[1]
    if cmd == "pkg":
        for oid in sys.argv[2:]:
            print(json.dumps(pkg_summary(oid), indent=1))
    elif cmd == "call":
        method = sys.argv[2]
        params = json.loads(sys.argv[3]) if len(sys.argv) > 3 else []
        print(json.dumps(rpc(method, params), indent=1))
