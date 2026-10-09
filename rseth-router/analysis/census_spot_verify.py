#!/usr/bin/env python3
import os as _os; _os.chdir(_os.path.dirname(_os.path.abspath(__file__)))
"""CI-side verification of the shipped census: sample (safe, module) pairs from
census_current_set.json and re-check `isModuleEnabled(module)` live on-chain, plus the
critical pairs of the finding. Read-only eth_calls. Distinguishes call errors from false."""
import json, os, random, time, urllib.request
from concurrent.futures import ThreadPoolExecutor

def _env(name):
    v = os.environ.get(name)
    if v:
        v = v.strip().strip('"').strip("'")
        if v:
            return v
    try:
        for line in open("/home/heisenberg/CA/.env"):
            if line.startswith(name + "="):
                return line.strip().split("=", 1)[1].strip('"').strip("'")
    except FileNotFoundError:
        pass
    return None

RPC = _env("NODEREAL_ETH_RPC_URL") or _env("FORK_RPC_URL") or _env("RPC_URL") or "https://ethereum-rpc.publicnode.com"

def rpc_batch(calls):
    body = json.dumps([{"jsonrpc": "2.0", "id": i, "method": m, "params": p} for i, (m, p) in enumerate(calls)]).encode()
    req = urllib.request.Request(RPC, data=body, headers={"Content-Type": "application/json", "User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(req, timeout=90) as r:
        out = json.load(r)
    by = {item["id"]: item for item in out}
    return [by.get(i) for i in range(len(calls))]

def call_enabled(safe, mod):
    arg = mod.lower().replace("0x", "")
    data = "0x2d9ad53d" + arg.rjust(64, "0")[-64:]
    for attempt in range(4):
        try:
            item = rpc_batch([("eth_call", [{"to": safe, "data": data}, "latest"])])[0]
            res = (item or {}).get("result")
            if res is not None:
                return res
        except Exception:
            pass
        time.sleep(1.5 * (attempt + 1))
    return None

WHALE = "0x40e93a52f6af9fcd3b476aedadd7feabd9f7aba8"
EMPTY = "0xbbd6b5b3565e151528c44200d4ee1a6895206962"
MODULE = "0xea18b13d11f705a68f0954f637949e1eaA7AC4ca".lower()
CRITICAL = [
    (WHALE, MODULE),
    (EMPTY, MODULE),
    ("0xb8e12daf63314a9baa71b1e39baa4538637bf138", "0xd479bcc84a6f972742ff19af23acf6b0c9253200"),
    ("0x6a1fac6b3466e29421f70d6eaa91a0de0f627ea2", "0xf73a5695bd538d09999f1987cfc43fd56eca59cc"),
]

def main():
    cur_all = json.load(open("census_current_set.json"))
    cur = [c for c in cur_all if c.get("module")]
    empty = len(cur_all) - len(cur)
    print("shipped census pairs:", len(cur_all), "with module decoded:", len(cur), "empty-module entries:", empty)
    random.seed(20261008)
    sample = [(c["safe"], c["module"]) for c in random.sample(cur, min(200, len(cur)))]
    pairs = CRITICAL + [p for p in sample if p not in CRITICAL]

    out = {}
    def work(chunk):
        return [(s, m, call_enabled(s, m)) for (s, m) in chunk]

    chunks = [pairs[i:i + 20] for i in range(0, len(pairs), 20)]
    with ThreadPoolExecutor(max_workers=3) as ex:
        for part in ex.map(work, chunks):
            for s, m, res in part:
                out[(s, m)] = res

    enabled = [k for k, v in out.items() if v and v.endswith("1")]
    disabled = [k for k, v in out.items() if v is not None and not v.endswith("1")]
    errors = [k for k, v in out.items() if v is None]

    critical_out = {f"{s}:{m}": {"live_enabled": (out.get((s, m)) or "").endswith("1"),
                                  "call_ok": out.get((s, m)) is not None}
                    for s, m in CRITICAL}
    block = None
    try:
        block = int(rpc_batch([("eth_blockNumber", [])])[0]["result"], 16)
    except Exception:
        pass

    res = {"block": block, "census_pairs": len(cur_all), "empty_module_entries": empty,
           "sampled_pairs": len(pairs), "live_enabled": len(enabled),
           "live_disabled": len(disabled), "call_errors": len(errors),
           "disabled_or_drift": [{"safe": s, "module": m} for s, m in disabled],
           "critical_pairs": critical_out,
           "census_source": "shipped full census (GoldRush, run locally; rsynced with the branch)"}
    json.dump(res, open("census_verify.json", "w"), indent=1)
    print(json.dumps(res, indent=1)[:2500])
    print("DONE")

if __name__ == "__main__":
    main()
