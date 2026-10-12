#!/usr/bin/env python3
"""Robust chunked eth_getLogs scanner (keyless public fallbacks; ALT_RPC env optional).
Checkpoints results to a jsonl file so restarts skip completed chunks."""
import json, os, sys, time, urllib.request

UA = {"User-Agent": "Mozilla/5.0", "Content-Type": "application/json"}
ALT = os.environ.get("ALT_RPC")
FALLBACKS = ["https://bsc.rpc.blxrbdn.com"]

def _post(url, payload, timeout=40):
    req = urllib.request.Request(url, data=json.dumps(payload).encode(), headers=UA)
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return json.loads(r.read())

def get_logs_paced(address, topics, fromb, tob, chunk, ckpt=None, pace=0.25, url=None):
    """Scan in chunks with node rotation + backoff. If ckpt given, resume from checkpoint."""
    urls = ([url] if url else ([ALT] if ALT else [])) + FALLBACKS
    done_until = None
    out = []
    if ckpt and os.path.exists(ckpt):
        state = json.load(open(ckpt))
        done_until = state.get("done_until")
        out = state.get("logs", [])
        if done_until is not None:
            print(f"[resume] ckpt at {done_until}", flush=True)
    b = fromb if done_until is None else done_until + 1
    while b <= tob:
        e = min(b + chunk - 1, tob)
        got = None
        for attempt in range(10):
            for u in urls:
                try:
                    d = _post(u, {"jsonrpc": "2.0", "id": 1, "method": "eth_getLogs",
                                  "params": [{"address": address, "topics": topics,
                                              "fromBlock": hex(b), "toBlock": hex(e)}]}, timeout=40)
                    if "result" in d:
                        got = d["result"]; break
                    err = str(d.get("error"))
                    if "range" in err or "exceed" in err:
                        continue  # next url
                    # rate limit etc -> backoff
                except Exception:
                    pass
            if got is not None:
                break
            time.sleep(min(1.0 * (attempt + 1), 8))
        if got is None:
            if ckpt:
                json.dump({"done_until": b - 1, "logs": out}, open(ckpt, "w"))
            raise RuntimeError(f"logs failed at {hex(b)}")
        out.extend(got)
        if ((b - fromb) // chunk) % 25 == 0:
            print(f"[scan] {hex(b)} n={len(out)}", flush=True)
        b = e + 1
        if ckpt:
            json.dump({"done_until": e, "logs": out}, open(ckpt, "w"))
        time.sleep(pace)
    return out

def code_size_rpc(addr, url):
    d = _post(url, {"jsonrpc": "2.0", "id": 1, "method": "eth_getCode", "params": [addr, "latest"]})
    return (len(d["result"]) - 2) // 2

def find_deploy_block(addr, lo, hi, url, pace=0.2):
    while lo < hi:
        mid = (lo + hi) // 2
        if code_size_rpc(addr, url) > 0:
            hi = mid
        else:
            lo = mid + 1
        time.sleep(pace)
    return lo
