#!/usr/bin/env python3
"""Local scan of Dfyn farm/vault addresses (read-only, public RPC)."""
import json, urllib.request, time, sys

UA = {"User-Agent": "Mozilla/5.0 (X11; Linux x86_64) dfyn-research", "Content-Type": "application/json"}
RPCS = ["https://polygon-bor-rpc.publicnode.com", "https://polygon.drpc.org"]
CUR = [0]

def rpc_batch(calls, timeout=60):
    payload = [{"jsonrpc": "2.0", "id": i, "method": m, "params": p} for i, (m, p) in enumerate(calls)]
    body = json.dumps(payload).encode()
    last = None
    for attempt in range(6):
        url = RPCS[CUR[0] % len(RPCS)]
        try:
            req = urllib.request.Request(url, data=body, headers=UA)
            with urllib.request.urlopen(req, timeout=timeout) as r:
                d = json.loads(r.read().decode())
            if isinstance(d, list):
                out = [None] * len(calls)
                for item in d:
                    i = item.get("id")
                    if isinstance(i, int) and 0 <= i < len(calls):
                        out[i] = item.get("result") if "result" in item else {"error": item.get("error")}
                return out
        except Exception as e:
            last = str(e)[:100]
            CUR[0] += 1
            time.sleep(1.0 + attempt)
    raise RuntimeError(f"batch fail: {last}")

def addr_pad(a): return a.lower().replace("0x", "").rjust(64, "0")
def dec_addr(h): return "0x" + h[-40:] if isinstance(h, str) and len(h) >= 42 else None
def dec_int(h):
    try: return int(h, 16)
    except: return None

SEL = {"stakingToken": "0x72f702f3", "rewardsToken": "0xd1af0c7d", "periodFinish": "0xebe2b12b",
       "totalSupply": "0x18160ddd", "balanceOf": "0x70a08231", "token": "0xfc0c546a",
       "rewardRate": "0x7b0a47ee", "owner": "0x8da5cb5b", "vestingToken": "0x4a6f5a1b"}

def scan(addrs):
    res = {}
    import os
    path = "/home/heisenberg/CA/dfyn-network/analysis/farms-scan.json"
    if os.path.exists(path):
        try: res = json.load(open(path))
        except Exception: res = {}
    addrs = [a for a in addrs if a not in res or "code_len" not in res[a]]
    CH = 10
    for i in range(0, len(addrs), CH):
        chunk = addrs[i:i+CH]
        code = rpc_batch([("eth_getCode", [a, "latest"]) for a in chunk])
        for a, c in zip(chunk, code):
            live = isinstance(c, str) and len(c) > 4
            res[a] = {"live": live, "code_len": (len(c)//2 if isinstance(c, str) else 0)}
        live_addrs = [a for a, c in zip(chunk, code) if isinstance(c, str) and len(c) > 4]
        if not live_addrs:
            continue
        calls = []
        for a in live_addrs:
            calls += [
                ("eth_call", [{"to": a, "data": SEL["stakingToken"]}, "latest"]),
                ("eth_call", [{"to": a, "data": SEL["rewardsToken"]}, "latest"]),
                ("eth_call", [{"to": a, "data": SEL["periodFinish"]}, "latest"]),
                ("eth_call", [{"to": a, "data": SEL["totalSupply"]}, "latest"]),
                ("eth_call", [{"to": a, "data": SEL["rewardRate"]}, "latest"]),
                ("eth_call", [{"to": a, "data": SEL["owner"]}, "latest"]),
            ]
        r = rpc_batch(calls)
        for j, a in enumerate(live_addrs):
            o = res[a]
            o["stakingToken"] = dec_addr(r[j*6])
            o["rewardsToken"] = dec_addr(r[j*6+1])
            o["periodFinish"] = dec_int(r[j*6+2]) if isinstance(r[j*6+2], str) else None
            o["totalSupply"] = dec_int(r[j*6+3]) if isinstance(r[j*6+3], str) else None
            o["rewardRate"] = dec_int(r[j*6+4]) if isinstance(r[j*6+4], str) else None
            o["owner"] = dec_addr(r[j*6+5])
        print(f"scanned {i+len(chunk)}/{len(addrs)}", flush=True)
    return res

if __name__ == "__main__":
    addrs = list(json.load(open("/home/heisenberg/CA/dfyn-network/analysis/farms-addresses.json")).keys())
    extra = ["0x75455c3de45dd32cbe9a5ad5e518d3d50823c976",  # vDfyn vault
             "0x150b4fd25c7c0c65301e86b599822f2feecc29e7",  # prediction market
             "0xa102072a4c07f06ec3b4900fdc4c7b80b6c57429",  # router
             "0xc168e40227e4ebd8c1cae80f7a55a4f0e6d66c97",  # DFYN token
             "0x16eccfdbb4ee1a85a33f3a9b21175cd7ae753db4"]  # ROUTE token
    for e in extra:
        if e not in addrs: addrs.append(e)
    out = scan(addrs)
    json.dump(out, open("/home/heisenberg/CA/dfyn-network/analysis/farms-scan.json", "w"), indent=1)
    live = {a: v for a, v in out.items() if v["live"]}
    print("live:", len(live), "dead:", len(out)-len(live))
    # summary of live ones with periodFinish
    for a, v in live.items():
        if v.get("stakingToken") or v.get("periodFinish"):
            print(a, "stk", v.get("stakingToken"), "rew", v.get("rewardsToken"), "pf", v.get("periodFinish"), "ts", v.get("totalSupply"), "owner", v.get("owner"))
