#!/usr/bin/env python3
"""Task 4: count OpenOrders (3228B, flags=5) globally via byte0 chunks,
plus zeroed/other-flag 3228B and 1476B MarketStateV2 accounts."""
import json, os, sys, time, urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from rpc import bytes_to_b58, u64le

PROGRAM = "srmqPvymJeFKQ4zGQed1GFppgkRHL9kaELCbyksJtPX"
RPC = "https://api.mainnet-beta.solana.com"
OUT = os.path.join(HERE, "openorders_counts.json")

def rpc(method, params, timeout=240, tries=8):
    body = json.dumps({"jsonrpc": "2.0", "id": 1, "method": method, "params": params}).encode()
    last = None
    for a in range(tries):
        try:
            req = urllib.request.Request(RPC, data=body, headers={
                "Content-Type": "application/json",
                "User-Agent": "Mozilla/5.0 (X11; Linux x86_64) zombie-hunt/1.0"})
            with urllib.request.urlopen(req, timeout=timeout) as r:
                j = json.loads(r.read().decode())
            if "error" in j:
                raise RuntimeError(str(j["error"])[:200])
            return j["result"]
        except Exception as e:
            last = e
            sleep = min(45, 2 * (2 ** a))
            print(f"  retry {a+1}/{tries}: {str(e)[:90]} sleep {sleep}s", flush=True)
            time.sleep(sleep)
    raise RuntimeError(str(last))

def gpa(filters, slen=0, offset=53):
    p = [PROGRAM, {"filters": filters, "encoding": "base64",
                   "dataSlice": {"offset": offset, "length": slen}, "commitment": "finalized"}]
    res = rpc("getProgramAccounts", p)
    return res

def f_dataSize(n):
    return {"dataSize": n}

def f_flags(v):
    return {"memcmp": {"offset": 5, "bytes": bytes_to_b58(u64le(v))}}

def f_byte0(off, b):
    return {"memcmp": {"offset": off, "bytes": bytes_to_b58(bytes([b]))}}

def main():
    t0 = time.time()
    state = {"openorders_flags5_per_byte": {}, "slot_start": rpc("getSlot", [])}
    if os.path.exists(OUT):
        try:
            state = json.load(open(OUT))
            state.setdefault("openorders_flags5_per_byte", {})
        except Exception:
            pass
    per_byte = state["openorders_flags5_per_byte"]
    for b in range(256):
        if str(b) in per_byte:
            continue
        res = gpa([f_dataSize(3228), f_flags(5), f_byte0(13, b)], slen=0)
        per_byte[str(b)] = len(res)
        if b % 16 == 0:
            print(f"  b={b} count={len(res)} total_so_far={sum(per_byte.values())}", flush=True)
        with open(OUT + ".tmp", "w") as f:
            json.dump(state, f)
        os.replace(OUT + ".tmp", OUT)
        time.sleep(0.15)
    state["openorders_flags5_total"] = sum(per_byte.values())
    print("OpenOrders flags=5 total:", state["openorders_flags5_total"], flush=True)

    # disabled OpenOrders (5|128 = 133)
    try:
        res = gpa([f_dataSize(3228), f_flags(133)], slen=0)
        state["openorders_flags133_total"] = len(res)
        print("OpenOrders flags=133 total:", len(res), flush=True)
    except Exception as e:
        state["openorders_flags133_error"] = str(e)[:150]

    # zeroed 3228 shells
    try:
        res = gpa([f_dataSize(3228), f_flags(0)], slen=0)
        state["zeroed_3228_count"] = len(res)
        print("zeroed 3228 count:", len(res), flush=True)
    except Exception as e:
        state["zeroed_3228_error"] = str(e)[:150]

    # MarketStateV2 1476: flags histogram
    try:
        res = gpa([f_dataSize(1476)], slen=8, offset=5)
        hist = {}
        for acc in res:
            d = acc["account"]["data"][0]
            import base64
            raw = base64.b64decode(d) if len(d) > 4 else b""
            v = int.from_bytes(raw[:8], "little") if len(raw) >= 8 else -1
            hist[str(v)] = hist.get(str(v), 0) + 1
        state["marketsv2_1476_flags_hist"] = hist
        state["marketsv2_1476_total"] = len(res)
        print("1476B flags hist:", hist, flush=True)
    except Exception as e:
        state["marketsv2_1476_error"] = str(e)[:150]

    # 388B flags anomalies
    anomalies = {}
    for v in (0, 1, 2, 131):
        try:
            res = gpa([f_dataSize(388), f_flags(v)], slen=0)
            anomalies[str(v)] = len(res)
            print(f"388B flags={v}: {len(res)}", flush=True)
        except Exception as e:
            anomalies[str(v)] = f"ERR {str(e)[:80]}"
    state["flags388_counts"] = anomalies
    state["slot_end"] = rpc("getSlot", [])
    state["elapsed_s"] = time.time() - t0
    with open(OUT, "w") as f:
        json.dump(state, f, indent=1)
    print("wrote", OUT)

if __name__ == "__main__":
    main()
