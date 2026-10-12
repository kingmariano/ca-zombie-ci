#!/usr/bin/env python3
"""Arb step 3: fresh pool state + calculateSwap vs balance-fraction grid, both directions.
Outputs: analysis/_quotes.json
"""
import json, urllib.request, os, time, urllib.error

RPC = "https://forno.celo.org"
HERE = os.path.dirname(os.path.abspath(__file__))

POOLS = [
    "0x9f4adbd0af281c69a582eb2e6fa2a594d4204cae",
    "0x02db089fb09fda92e05e92afcd41d9aafe9c7c7c",
    "0xa2f0e57d4ceacf025e81c76f28b9ad6e9fbe8735",
    "0x382ed834c6b7dbd10e4798b08889eaed1455e820",
    "0x23c95678862a229fac088bd9705622d78130bc3e",
    "0x413ffcc28e6cdde7e93625ef4742810fe9738578",
    "0xfc9e2c63370d8deb3521922a7b2b60f4cff7e75a",
    "0xcce0d62ce14fb3e4363eb92db37ff3630836c252",
    "0xa5037661989789d0310ac2b796fa78f1b01f195d",
    "0x0986b42f5f9c42feeef66fc23eba9ea1164c916d",
    "0xaefc4e8cf655a182e8346b24c8abce45616ee0d2",
    "0x19260b9b573569ddb105780176547875fe9feda3",
]

FRACS = [1e-6, 1e-5, 1e-4, 3e-4, 1e-3, 3e-3, 0.01, 0.03, 0.05, 0.1, 0.15, 0.2, 0.3, 0.5, 0.7, 0.9, 1.0]
SEL = {
    "getToken(uint8)": "0x82b86600",
    "getTokenBalance(uint8)": "0x91ceb3eb",
    "calculateSwap(uint8,uint8,uint256)": "0xa95b089f",
    "paused()": "0x5c975abb",
    "decimals()": "0x313ce567",
    "symbol()": "0x95d89b41",
}


def rpc_batch(calls, tries=6, batch=60):
    out = []
    for i in range(0, len(calls), batch):
        chunk = calls[i:i + batch]
        body = json.dumps([{"jsonrpc": "2.0", "id": j, "method": m, "params": p}
                           for j, (m, p) in enumerate(chunk)]).encode()
        last = None
        for t in range(tries):
            try:
                req = urllib.request.Request(RPC, data=body,
                                             headers={"Content-Type": "application/json",
                                                      "User-Agent": "Mozilla/5.0 (research; read-only)"})
                with urllib.request.urlopen(req, timeout=90) as r:
                    d = json.loads(r.read().decode())
                if isinstance(d, dict):
                    raise RuntimeError(str(d)[:200])
                by_id = {it["id"]: it for it in d}
                out.extend((by_id.get(j) or {}).get("result") for j in range(len(chunk)))
                break
            except Exception as e:
                last = e
                time.sleep(1 + t)
        else:
            raise RuntimeError(f"rpc failed: {last}")
    return out


def a(h): return "0x" + h[2:][-40:].lower() if h else None
def dec_str(s):
    if not s or not isinstance(s, str) or s == "0x": return None
    h = s[2:]
    try:
        off = int(h[0:64], 16) * 2; ln = int(h[off:off + 64], 16) * 2
        return bytes.fromhex(h[off + 64:off + 64 + ln]).decode("utf-8", "replace")
    except Exception: return None
def dec_uint(s):
    if not s or not isinstance(s, str) or s == "0x": return None
    try: return int(s[2:66], 16)
    except Exception: return None


def call(pool, sel, args=""):
    return {"to": pool, "data": sel + args}


def main():
    out = {"rpc": RPC}
    r = rpc_batch([("eth_blockNumber", [])])
    blk = int(r[0], 16); out["block"] = blk
    print("block", blk)

    # pool basics
    calls, keys = [], []
    for p in POOLS:
        for i in (0, 1):
            a1 = hex(i)[2:].rjust(64, "0")
            calls.append(("eth_call", [call(p, SEL["getToken(uint8)"], a1), "latest"])); keys.append((p, f"token{i}"))
            calls.append(("eth_call", [call(p, SEL["getTokenBalance(uint8)"], a1), "latest"])); keys.append((p, f"bal{i}"))
        calls.append(("eth_call", [call(p, SEL["paused()"]), "latest"])); keys.append((p, "paused"))
    res = rpc_batch(calls)
    pools = {}
    for (p, k), r in zip(keys, res):
        pools.setdefault(p, {})
        if k.startswith("token"):
            pools[p][k] = a(r)
        elif k.startswith("bal"):
            _v = dec_uint(r)
            pools[p][k] = str(_v) if _v is not None else None
        else:
            pools[p][k] = bool(dec_uint(r))
    # token meta
    tok = set()
    for p, e in pools.items():
        for i in (0, 1):
            if e.get(f"token{i}"): tok.add(e[f"token{i}"])
    calls, keys = [], []
    for t in sorted(tok):
        calls.append(("eth_call", [call(t, SEL["decimals()"]), "latest"])); keys.append((t, "decimals"))
        calls.append(("eth_call", [call(t, SEL["symbol()"]), "latest"])); keys.append((t, "symbol"))
    res = rpc_batch(calls)
    meta = {}
    for (t, k), r in zip(keys, res):
        meta.setdefault(t, {})[k] = dec_str(r) if k == "symbol" else dec_uint(r)
    out["tokens"] = meta

    # quote grids
    qkeys, qcalls = [], []
    for p in POOLS:
        e = pools[p]
        for i in (0, 1):
            bal = int(e.get(f"bal{i}") or 0)
            if bal == 0:
                continue
            for fr in FRACS:
                dx = int(bal * fr)
                if dx <= 0:
                    continue
                for j in (1 - i,):
                    args = hex(i)[2:].rjust(64, "0") + hex(j)[2:].rjust(64, "0") + hex(dx)[2:].rjust(64, "0")
                    qcalls.append(("eth_call", [call(p, SEL["calculateSwap(uint8,uint8,uint256)"], args), "latest"]))
                    qkeys.append((p, i, j, str(dx)))
    res = rpc_batch(qcalls, batch=50)
    quotes = {}
    for (p, i, j, dx), r in zip(qkeys, res):
        v = dec_uint(r)
        d = quotes.setdefault(p, {}).setdefault(f"{i}->{j}", {})
        if v is not None:
            d[dx] = v
    out["pools"] = pools
    out["quotes"] = quotes
    with open(os.path.join(HERE, "_quotes.json"), "w") as f:
        json.dump(out, f, indent=1)
    print("wrote _quotes.json")
    for p in POOLS:
        e = pools[p]
        s0 = meta.get(e.get("token0") or "", {}).get("symbol")
        s1 = meta.get(e.get("token1") or "", {}).get("symbol")
        print(p, f"paused={e.get('paused')}", f"{s0}({e.get('token0')}) {e.get('bal0')}", f"{s1}({e.get('token1')}) {e.get('bal1')}")


if __name__ == "__main__":
    main()
