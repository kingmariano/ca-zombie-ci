#!/usr/bin/env python3
"""LuaSwap (Viction) factory pair scanner.
Read-only eth_call/getLogs against public Viction RPC.
Outputs: analysis/pairs_raw_latest.json, analysis/pairs_summary_latest.csv
"""
import json, time, sys, csv
from urllib.request import Request, urlopen

RPC = "https://rpc.viction.xyz"
FACTORY = "0x28c79368257CD71A122409330ad2bEBA7277a396"
UA = {"Content-Type": "application/json", "User-Agent": "Mozilla/5.0"}

def rpc(method, params, retries=6):
    payload = {"jsonrpc": "2.0", "id": 1, "method": method, "params": params}
    for a in range(retries):
        try:
            req = Request(RPC, data=json.dumps(payload).encode(), headers=UA)
            with urlopen(req, timeout=90) as r:
                j = json.load(r)
            if "result" in j:
                return j["result"]
            if "error" in j:
                raise RuntimeError(j["error"])
        except Exception as e:
            if a == retries - 1:
                raise
            time.sleep(1.5 * (a + 1))
    return None

def rpc_batch(items, retries=6, chunk=10):
    """items: list of (to, data). Returns list of hex results (or None)."""
    out = []
    for i in range(0, len(items), chunk):
        part = items[i:i + chunk]
        payload = [{"jsonrpc": "2.0", "id": k, "method": "eth_call",
                    "params": [{"to": to, "data": data}, "latest"]}
                   for k, (to, data) in enumerate(part)]
        for a in range(retries):
            try:
                req = Request(RPC, data=json.dumps(payload).encode(), headers=UA)
                with urlopen(req, timeout=120) as r:
                    j = json.load(r)
                byid = {x["id"]: x for x in j}
                ok = all(k in byid and "result" in byid[k] for k in range(len(part)))
                if not ok:
                    raise RuntimeError("batch error: %s" % json.dumps(j)[:300])
                out.extend([byid[k]["result"] for k in range(len(part))])
                break
            except Exception as e:
                if a == retries - 1:
                    raise
                time.sleep(1.5 * (a + 1))
        if i % 200 == 0:
            print("batch progress %d/%d" % (i, len(items)), file=sys.stderr, flush=True)
        time.sleep(0.05)
    return out

def dec(h):
    return int(h, 16) if h and h != "0x" else 0

def pad_addr(a):
    return a.lower().replace("0x", "").rjust(64, "0")

PAIR_CREATED = "0x0d3648bd0f6ba80134a33ba9275ac585d9d315f0ad8355cddefde31afa28d0e9"

def main():
    blk = dec(rpc("eth_blockNumber", []))
    print("block", blk, file=sys.stderr)
    # PairCreated logs
    logs = rpc("eth_getLogs", [{"address": FACTORY, "fromBlock": "0x0", "toBlock": hex(blk),
                                "topics": [PAIR_CREATED]}])
    print("pair logs:", len(logs), file=sys.stderr)
    pairs = []
    for lg in logs:
        t0 = "0x" + lg["topics"][1][-40:]
        t1 = "0x" + lg["topics"][2][-40:]
        pair = "0x" + lg["data"][2:66][-40:]
        idx = dec(lg["data"][66:130])
        pairs.append({"pair": pair, "token0": t0, "token1": t1, "index": idx,
                      "created_block": dec(lg["blockNumber"])})
    # sort by index
    pairs.sort(key=lambda p: p["index"])
    print("pairs enumerated:", len(pairs), "max index:", pairs[-1]["index"] if pairs else None,
          file=sys.stderr)

    # getReserves for each pair (pinned block not supported uniformly; use latest)
    res = rpc_batch([(p["pair"], "0x0902f1ac") for p in pairs])
    for p, r in zip(pairs, res):
        if r and r != "0x":
            p["reserve0"] = dec(r[2:66])
            p["reserve1"] = dec(r[66:130])
            p["blockTimestampLast"] = dec(r[130:194]) if len(r) >= 194 else 0
        else:
            p["reserve0"] = p["reserve1"] = None

    # token symbols/decimals for unique tokens
    toks = sorted({p["token0"] for p in pairs} | {p["token1"] for p in pairs})
    print("unique tokens:", len(toks), file=sys.stderr)
    symres = rpc_batch([(t, "0x95d89b41") for t in toks])
    decres = rpc_batch([(t, "0x313ce567") for t in toks])
    tokmeta = {}
    for t, s, d in zip(toks, symres, decres):
        # decode string
        sym = None
        try:
            if s and s != "0x":
                b = bytes.fromhex(s[2:])
                if len(b) >= 64:
                    ln = int.from_bytes(b[32:64], "big")
                    if 0 < ln <= 32 and 64 + ln <= len(b):
                        sym = b[64:64 + ln].decode("utf-8", "replace")
                    else:
                        sym = b[:32].split(b"\x00")[0].decode("utf-8", "replace")
                else:
                    sym = b.split(b"\x00")[0].decode("utf-8", "replace")
        except Exception:
            sym = None
        try:
            dm = int(d, 16) if d and d != "0x" else None
        except Exception:
            dm = None
        tokmeta[t] = {"symbol": sym, "decimals": dm}
    print(json.dumps({k: v for k, v in list(tokmeta.items())[:5]}, indent=1), file=sys.stderr)

    out = {"block": blk, "factory": FACTORY, "pair_count": len(pairs),
           "pairs": pairs, "tokens": tokmeta}
    with open("pairs_raw_latest.json", "w") as f:
        json.dump(out, f, indent=1)
    with open("pairs_summary_latest.csv", "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["index", "pair", "token0", "sym0", "dec0", "reserve0", "token1", "sym1",
                    "dec1", "reserve1", "created_block"])
        for p in pairs:
            m0 = tokmeta.get(p["token0"], {}); m1 = tokmeta.get(p["token1"], {})
            w.writerow([p["index"], p["pair"], p["token0"], m0.get("symbol"), m0.get("decimals"),
                        p["reserve0"], p["token1"], m1.get("symbol"), m1.get("decimals"),
                        p["reserve1"], p["created_block"]])
    print("done", file=sys.stderr)

if __name__ == "__main__":
    main()
