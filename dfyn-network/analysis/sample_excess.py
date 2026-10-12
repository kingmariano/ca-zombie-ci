#!/usr/bin/env python3
"""Quick local sample: pair excess (balance - reserve) on Dfyn factories. Read-only."""
import json, urllib.request

UA = {"User-Agent": "Mozilla/5.0 (X11; Linux x86_64) dfyn-research", "Content-Type": "application/json"}
RPCS = {
    "polygon": ["https://polygon-bor-rpc.publicnode.com", "https://polygon.llamarpc.com"],
    "fantom":  ["https://fantom-rpc.publicnode.com"],
}

def rpc_batch(chain, calls):
    payload = [{"jsonrpc": "2.0", "id": i, "method": m, "params": p} for i, (m, p) in enumerate(calls)]
    body = json.dumps(payload).encode()
    for url in RPCS[chain]:
        try:
            req = urllib.request.Request(url, data=body, headers=UA)
            with urllib.request.urlopen(req, timeout=60) as r:
                d = json.loads(r.read().decode())
            if isinstance(d, list):
                out = [None] * len(calls)
                for item in d:
                    i = item.get("id")
                    if isinstance(i, int) and 0 <= i < len(calls):
                        out[i] = item.get("result") or item.get("error")
                return out
        except Exception as e:
            err = str(e)[:100]
    raise RuntimeError(f"batch fail {chain}: {err}")

def addr_pad(a): return a.lower().replace("0x", "").rjust(64, "0")
def dec_addr(h): return "0x" + h[-40:] if h and len(h) >= 42 else None
def dec_int(h):
    try: return int(h, 16)
    except: return None

FAC = {
    "polygon": "0xe7fb3e833efe5f9c441105eb65ef8b261266423b",
    "fantom":  "0xd9820a17053d6314b20642e465a84bf01a3d64f5",
}

SEL = {"allPairs": "0x1e3dd18b", "token0": "0x0dfe1681", "token1": "0xd21220a7",
       "getReserves": "0x0902f1ac", "totalSupply": "0x18160ddd", "balanceOf": "0x70a08231"}

def scan(chain, n_sample):
    fac = FAC[chain]
    # read allPairsLength
    res = rpc_batch(chain, [("eth_call", [{"to": fac, "data": SEL["allPairs"] + hex(i)[2:].rjust(64, "0")}, "latest"]) for i in range(n_sample)])
    pairs = [dec_addr(r) for r in res]
    out = []
    for p in pairs:
        if not p: out.append(None); continue
        r = rpc_batch(chain, [
            ("eth_call", [{"to": p, "data": SEL["token0"]}, "latest"]),
            ("eth_call", [{"to": p, "data": SEL["token1"]}, "latest"]),
            ("eth_call", [{"to": p, "data": SEL["getReserves"]}, "latest"]),
            ("eth_call", [{"to": p, "data": SEL["totalSupply"]}, "latest"]),
        ])
        t0, t1 = dec_addr(r[0]), dec_addr(r[1])
        res_raw = r[2]
        r0 = r1 = None
        if isinstance(res_raw, str) and len(res_raw) >= 130:
            r0 = int(res_raw[2:66], 16); r1 = int(res_raw[66:130], 16)
        ts = dec_int(r[3]) if isinstance(r[3], str) else None
        b = rpc_batch(chain, [
            ("eth_call", [{"to": t0, "data": SEL["balanceOf"] + addr_pad(p)}, "latest"]),
            ("eth_call", [{"to": t1, "data": SEL["balanceOf"] + addr_pad(p)}, "latest"]),
        ])
        b0 = dec_int(b[0]) if isinstance(b[0], str) else None
        b1 = dec_int(b[1]) if isinstance(b[1], str) else None
        ex0 = (b0 - r0) if (b0 is not None and r0 is not None) else None
        ex1 = (b1 - r1) if (b1 is not None and r1 is not None) else None
        out.append({"pair": p, "t0": t0, "t1": t1, "r0": r0, "r1": r1, "ts": ts,
                    "b0": b0, "b1": b1, "ex0": ex0, "ex1": ex1})
    return out

if __name__ == "__main__":
    n = int(__import__("sys").argv[2]) if len(__import__("sys").argv) > 2 else 30
    chain = __import__("sys").argv[1]
    rows = scan(chain, n)
    nonzero = [r for r in rows if r and ((r["ex0"] or 0) > 0 or (r["ex1"] or 0) > 0)]
    print(f"{chain}: scanned {len(rows)} pairs, {len(nonzero)} with positive excess")
    for r in nonzero[:20]:
        print(json.dumps(r))
    json.dump(rows, open(f"/home/heisenberg/CA/dfyn-network/analysis/sample-{chain}-{n}.json", "w"), indent=1)
