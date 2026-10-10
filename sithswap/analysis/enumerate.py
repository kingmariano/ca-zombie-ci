#!/usr/bin/env python3
"""Enumerate all SithSwap pairs + per-pair state at a pinned block. Resilient version.

Read-only, keyless public RPCs (plus optional env-provided keyed endpoints, never written to disk).
Writes analysis/pairs_raw.json; resumes if partially present.
"""
import json, os, sys, time, urllib.request, urllib.error, random
from concurrent.futures import ThreadPoolExecutor, as_completed
from sn import selector

FACTORY = 0xeaf728d8e09bfbe5f11881f848ca647ba41593502347ed2ec5881e46b57a32
PUBLIC_RPCS = [
    "https://api.cartridge.gg/x/starknet/mainnet",
    "https://starknet.drpc.org",
]
# Optional keyed endpoints from env (constructed at runtime; never written to files/logs)
_env_rpcs = []
if os.environ.get("ALCHEMY_API_KEY"):
    _env_rpcs.append("https://starknet-mainnet.g.alchemy.com/v2/" + os.environ["ALCHEMY_API_KEY"])
if os.environ.get("INFURA_API_KEY"):
    _env_rpcs.append("https://starknet-mainnet.infura.io/v3/" + os.environ["INFURA_API_KEY"])
RPCS = _env_rpcs + PUBLIC_RPCS

import threading
_lock = threading.Lock()
_last_call = [0.0]
MIN_INTERVAL = 0.12  # global pacing

def rpc2(method, params, tries=8):
    last = None
    for attempt in range(tries):
        url = RPCS[attempt % len(RPCS)] if attempt < len(RPCS) else random.choice(RPCS)
        with _lock:
            dt = time.time() - _last_call[0]
            if dt < MIN_INTERVAL:
                time.sleep(MIN_INTERVAL - dt)
            _last_call[0] = time.time()
        try:
            body = json.dumps({"jsonrpc": "2.0", "method": method, "params": params, "id": 1}).encode()
            req = urllib.request.Request(url, data=body, headers={"Content-Type": "application/json", "User-Agent": "Mozilla/5.0 research"})
            with urllib.request.urlopen(req, timeout=45) as r:
                j = json.loads(r.read())
            if "error" in j:
                last = j["error"]
                if "block" in str(last).lower():
                    raise RuntimeError(str(last))
                time.sleep(0.4 + attempt * 0.5)
                continue
            return j["result"]
        except urllib.error.HTTPError as e:
            last = f"HTTP {e.code}"
            time.sleep(1.0 + attempt * 1.0)
        except Exception as e:
            last = str(e)
            time.sleep(0.6 + attempt * 0.6)
    raise RuntimeError(f"{method} failed: {last}")

def call2(addr, fn, calldata=None, block="latest"):
    block_id = block if isinstance(block, (str, dict)) else {"block_number": int(block)}
    return rpc2("starknet_call", {
        "request": {"contract_address": hex(addr), "entry_point_selector": selector(fn),
                    "calldata": [hex(x) if isinstance(x, int) else x for x in (calldata or [])]},
        "block_id": block_id,
    })

def u256(felts):
    if felts is None: return None
    if len(felts) == 2:
        return int(felts[0], 16) + (int(felts[1], 16) << 128)
    return int(felts[0], 16)

def one_pair(i, block):
    p = call2(FACTORY, "allPairs", [hex(i)], block)[0]
    p = int(p, 16)
    if p == 0:
        return {"i": i, "pair": "0x0"}
    d = {"i": i, "pair": hex(p)}
    d["tokens"] = [hex(int(x, 16)) for x in call2(p, "getTokens", None, block)]
    d["reserves"] = [u256(call2(p, "getReserve0", None, block)), u256(call2(p, "getReserve1", None, block))]
    d["total_supply"] = u256(call2(p, "totalSupply", None, block))
    d["stable"] = int(call2(p, "getStable", None, block)[0], 16)
    d["fee0"] = int(call2(p, "getFee0", None, block)[0], 16)
    d["fee1"] = int(call2(p, "getFee1", None, block)[0], 16)
    d["fees_contract"] = hex(int(call2(p, "getFees", None, block)[0], 16))
    d["owner"] = hex(int(call2(p, "owner", None, block)[0], 16))
    d["pid"] = int(call2(p, "getPid", None, block)[0], 16)
    d["index0"] = u256(call2(p, "getIndex0", None, block))
    d["index1"] = u256(call2(p, "getIndex1", None, block))
    return d

def main():
    out_path = "pairs_raw.json"
    prior = {}
    if os.path.exists(out_path):
        try:
            old = json.load(open(out_path))
            for r in old.get("pairs", []):
                if "error" not in r:
                    prior[r["i"]] = r
        except Exception:
            pass
    block = rpc2("starknet_blockNumber", [])
    n = int(call2(FACTORY, "allPairsLength", None, block)[0], 16)
    print(f"block={block} allPairsLength={n} prior={len(prior)}", flush=True)
    results = dict(prior)
    todo = [i for i in range(n) if i not in results]
    with ThreadPoolExecutor(max_workers=3) as ex:
        futs = {ex.submit(one_pair, i, block): i for i in todo}
        done = 0
        for f in as_completed(futs):
            try:
                r = f.result()
            except Exception as e:
                r = {"i": futs[f], "error": str(e)[:200]}
            results[r["i"]] = r
            done += 1
            if done % 20 == 0:
                print(f"  {done}/{len(todo)}", flush=True)
                json.dump({"block": block, "n": n, "pairs": [results.get(i, {"i": i}) for i in range(n)]}, open(out_path, "w"))
    out = {"block": block, "n": n, "pairs": [results.get(i, {"i": i}) for i in range(n)]}
    json.dump(out, open(out_path, "w"), indent=1)
    errs = [r for r in out["pairs"] if "error" in r]
    print(f"written pairs_raw.json; errors={len(errs)}", flush=True)

if __name__ == "__main__":
    main()
