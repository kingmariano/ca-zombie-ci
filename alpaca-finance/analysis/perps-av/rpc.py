#!/usr/bin/env python3
"""Batch JSON-RPC eth_call helper for read-only Alpaca perps/AV audit.

Usage: python3 rpc.py <calls.json> <out.json>
calls.json: [{"id": "...", "to": "0x..", "data": "0x.."} or {"to":..,"sig":"fn(types)","args":[...]}]
Outputs: {"block": N, "results": {id: {"ok": bool, "raw": "0x...", "decoded":[...], "error": "..." }}}
"""
import json, sys, time
import requests
from eth_utils import keccak
from eth_abi import encode as abi_encode, decode as abi_decode

RPC = "https://bsc-rpc.publicnode.com"

def sel(sig):
    return keccak(text=sig)[:4]

def enc_call(c):
    if "data" in c:
        return c["data"]
    sig = c["sig"]
    args = c.get("args", [])
    in_types = c.get("in_types", [])
    data = sel(sig) + abi_encode(in_types, args)
    return "0x" + data.hex()

def send_batch(calls):
    reqs = []
    for i, c in enumerate(calls):
        if "slot" in c:
            reqs.append({"jsonrpc": "2.0", "id": i, "method": "eth_getStorageAt",
                         "params": [c["to"], c["slot"], c.get("block", "latest")]})
        else:
            reqs.append({"jsonrpc": "2.0", "id": i, "method": "eth_call",
                         "params": [{"to": c["to"], "data": enc_call(c)}, c.get("block", "latest")]})
    r = requests.post(RPC, json=reqs, timeout=120)
    r.raise_for_status()
    j = r.json()
    if isinstance(j, dict):
        raise RuntimeError("non-batch response: " + json.dumps(j)[:300])
    return j

def main():
    calls = json.load(open(sys.argv[1]))
    out = {"rpc": RPC, "results": {}}
    # latest block
    try:
        rb = requests.post(RPC, json={"jsonrpc":"2.0","id":1,"method":"eth_blockNumber","params":[]}, timeout=30).json()
        out["block"] = int(rb["result"], 16)
    except Exception as e:
        out["block_error"] = str(e)
    idx = {}
    for i, c in enumerate(calls):
        idx[i] = c
    CH = 50
    for s in range(0, len(calls), CH):
        chunk = calls[s:s+CH]
        for attempt in range(4):
            try:
                resp = send_batch(chunk)
                byid = {x["id"]: x for x in resp}
                break
            except Exception as e:
                if attempt == 3:
                    byid = {}
                    for i in range(len(chunk)):
                        byid[i] = {"error": {"message": str(e)}}
                time.sleep(1.5 * (attempt + 1))
        for i, c in enumerate(chunk):
            rid = c["id"]
            x = byid.get(i, {"error": {"message": "missing"}})
            if "error" in x:
                out["results"][rid] = {"to": c["to"], "ok": False, "error": x["error"].get("message", str(x["error"]))[:200]}
                continue
            raw = x.get("result", "")
            rec = {"to": c["to"], "ok": True, "raw": raw}
            if c.get("types") is not None and raw and raw != "0x":
                try:
                    vals = abi_decode(c["types"], bytes.fromhex(raw[2:]))
                    rec["decoded"] = [str(v) if not isinstance(v, bytes) else "0x"+v.hex() for v in vals]
                except Exception as e:
                    rec["decode_error"] = str(e)
            out["results"][rid] = rec
        time.sleep(0.25)
    json.dump(out, open(sys.argv[2], "w"), indent=1)
    print("block", out.get("block"), "calls", len(calls), "ok", sum(1 for r in out["results"].values() if r.get("ok")), "err", sum(1 for r in out["results"].values() if not r.get("ok")))

if __name__ == "__main__":
    main()
