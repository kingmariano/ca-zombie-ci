#!/usr/bin/env python3
"""SuiDex (C2-52) read-only Sui helpers.

Keyless public endpoints only (never keyed URLs in files):
  JSON-RPC : https://sui-rpc.publicnode.com  (fallback: https://rpc-mainnet.suiscan.xyz, https://mainnet.sui.rpcpool.com)
  GraphQL  : https://graphql.mainnet.sui.io/graphql
Read-only: only *_get*, *_query*, devInspect (dry-run) methods are used. No tx is ever signed/sent.
"""
import json, sys, urllib.request, urllib.error, time, os

# Keyless public Sui JSON-RPC endpoints (rotate on 429/5xx/timeouts). Never keyed URLs.
ENDPOINTS = [u for u in [
    os.environ.get("SUI_RPC_URL"),
    "https://sui-rpc.publicnode.com",
    "https://rpc-mainnet.suiscan.xyz",
    "https://sui.blockpi.network/v1/rpc/public",
    "https://1rpc.io/sui",
    "https://sui-mainnet-endpoint.blockvision.org",
    "https://sui.api.onfinality.io/public",
    "https://mainnet.sui.rpcpool.com",
] if u]
RPC = ENDPOINTS[0]
RPC_SLEEP = float(os.environ.get("SUIDEX_RPC_SLEEP", "0.06"))
_state = {"idx": 0}
GQL = "https://graphql.mainnet.sui.io/graphql"
PKG = "0xbfac5e1c6bf6ef29b12f7723857695fd2f4da9a11a7d88162c15e9124c243a4a"

def rpc(method, params, retries=None):
    body = json.dumps({"jsonrpc": "2.0", "id": 1, "method": method, "params": params}).encode()
    n = retries or max(6, len(ENDPOINTS) * 2)
    last = None
    for i in range(n):
        url = ENDPOINTS[_state["idx"] % len(ENDPOINTS)]
        if RPC_SLEEP > 0:
            time.sleep(RPC_SLEEP)
        req = urllib.request.Request(url, data=body, headers={"Content-Type": "application/json", "User-Agent": "zombie-hunt-research/1.0"})
        try:
            with urllib.request.urlopen(req, timeout=60) as r:
                out = json.loads(r.read())
            if "error" in out:
                raise RuntimeError(json.dumps(out["error"]))
            return out["result"]
        except urllib.error.HTTPError as e:
            last = e
            _state["idx"] += 1
            time.sleep(min(2 ** i * 0.5, 20))
        except Exception as e:  # noqa
            last = e
            _state["idx"] += 1
            time.sleep(min(2 ** i * 0.5, 20))
    raise RuntimeError(f"{method} failed on all endpoints: {last}")

def gql(query, variables=None, retries=3):
    body = json.dumps({"query": query, "variables": variables or {}}).encode()
    req = urllib.request.Request(GQL, data=body, headers={"Content-Type": "application/json", "User-Agent": "zombie-hunt-research/1.0"})
    last = None
    for i in range(retries):
        try:
            with urllib.request.urlopen(req, timeout=60) as r:
                out = json.loads(r.read())
            if "errors" in out:
                raise RuntimeError(json.dumps(out["errors"]))
            return out["data"]
        except Exception as e:  # noqa
            last = e
            time.sleep(1.5 * (i + 1))
    raise RuntimeError(f"gql failed: {last}")

def get_object(obj_id, **opts):
    o = {"showType": True, "showOwner": True, "showContent": True, "showBcs": False}
    o.update(opts)
    return rpc("sui_getObject", [obj_id, o])

def objects_by_type(type_str, limit=50):
    q = """
    query($t: String!, $n: Int!) {
      objects(filter: {type: $t}, first: $n) {
        nodes { address version digest
          asMoveObject { contents { type { repr } json } } }
      }
    }"""
    return gql(q, {"t": type_str, "n": limit})

def dynamic_fields(parent, limit=50, cursor=None):
    # positional form: [parent, cursor|null, limit]
    return rpc("suix_getDynamicFields", [parent, cursor, limit])

def dynamic_field_object(parent, name_bcs_b64):
    return rpc("suix_getDynamicFieldObject", [parent, {"type": "0x2::dynamic_field::Field", "value": {"bcs": name_bcs_b64}}]) if False else rpc("suix_getDynamicFieldObject", [parent, name_bcs_b64])

def balance(obj_id, coin_type="0x2::sui::SUI"):
    return rpc("suix_getBalance", [obj_id, coin_type])

def query_events(event_type, limit=50, descending=True, cursor=None):
    params = [{"MoveEventType": event_type}, cursor, limit, descending]
    return rpc("suix_queryEvents", params)

if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "help"
    if cmd == "obj":
        print(json.dumps(get_object(sys.argv[2]), indent=2))
    elif cmd == "type":
        print(json.dumps(objects_by_type(sys.argv[2], int(sys.argv[3]) if len(sys.argv) > 3 else 50), indent=2))
    elif cmd == "df":
        print(json.dumps(dynamic_fields(sys.argv[2], int(sys.argv[3]) if len(sys.argv) > 3 else 50, sys.argv[4] if len(sys.argv) > 4 else None), indent=2))
    elif cmd == "bal":
        print(json.dumps(balance(sys.argv[2], sys.argv[3] if len(sys.argv) > 3 else "0x2::sui::SUI"), indent=2))
    elif cmd == "ev":
        print(json.dumps(query_events(sys.argv[2], int(sys.argv[3]) if len(sys.argv) > 3 else 50), indent=2))
    else:
        print("usage: sui_rpc.py obj|type|df|bal|ev ...")
