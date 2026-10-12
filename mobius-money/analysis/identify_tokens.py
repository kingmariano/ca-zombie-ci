#!/usr/bin/env python3
"""Identify all tokens in Mobius pools: symbol/decimals on-chain + DefiLlama price.
Read-only; keyless RPC. Output: analysis/tokens.json
"""
import json, urllib.request, os, time

RPC = "https://forno.celo.org"
HERE = os.path.dirname(os.path.abspath(__file__))
STATE = json.load(open(os.path.join(HERE, "live-state.json")))

tokens = set()
for p, e in STATE["pools"].items():
    for t in e.get("tokens") or []:
        tokens.add(t.lower())
tokens = sorted(tokens)
print(f"{len(tokens)} distinct tokens")

SEL_SYMBOL = "0x95d89b41"
SEL_NAME = "0x06fdde03"
SEL_DEC = "0x313ce567"
SEL_SUPPLY = "0x18160ddd"


def rpc_batch(calls, tries=5):
    """Chunk into <=10-call batches."""
    out = []
    for i in range(0, len(calls), 10):
        out.extend(_rpc_batch(calls[i:i + 10], tries))
    return out


def _rpc_batch(calls, tries=5):
    body = json.dumps([{"jsonrpc": "2.0", "id": i, "method": m, "params": p}
                       for i, (m, p) in enumerate(calls)]).encode()
    last = None
    for t in range(tries):
        try:
            req = urllib.request.Request(RPC, data=body,
                                         headers={"Content-Type": "application/json",
                                                  "User-Agent": "Mozilla/5.0 (research; read-only)"})
            with urllib.request.urlopen(req, timeout=60) as r:
                d = json.loads(r.read().decode())
            by_id = {item["id"]: item for item in d}
            out = []
            for i in range(len(calls)):
                it = by_id.get(i)
                out.append(it.get("result") if it and "result" in it else None)
            return out
        except Exception as e:
            last = e
            time.sleep(1 + t)
    raise RuntimeError(f"rpc failed: {last}")


def dec_str(s):
    if not s or not isinstance(s, str) or s == "0x":
        return None
    h = s[2:]
    try:
        off = int(h[0:64], 16) * 2
        ln = int(h[off:off + 64], 16) * 2
        return bytes.fromhex(h[off + 64:off + 64 + ln]).decode("utf-8", "replace")
    except Exception:
        return None


def dec_uint(s):
    if not s or not isinstance(s, str) or s == "0x":
        return None
    try:
        return int(s[2:66], 16)
    except Exception:
        return None


out = {}
calls = []
keys = []
for t in tokens:
    for k, sel in [("symbol", SEL_SYMBOL), ("name", SEL_NAME), ("decimals", SEL_DEC), ("totalSupply", SEL_SUPPLY)]:
        calls.append(("eth_call", [{"to": t, "data": sel}, "latest"]))
        keys.append((t, k))
res = rpc_batch(calls)
meta = {}
for (t, k), r in zip(keys, res):
    meta.setdefault(t, {})[k] = dec_str(r) if k in ("symbol", "name") else dec_uint(r)
# fetch llama prices
addrs = ",".join(f"celo:{t}" for t in tokens)
pr = {}
for chunk_start in range(0, len(tokens), 25):
    ch = tokens[chunk_start:chunk_start + 25]
    url = "https://coins.llama.fi/prices/current/" + ",".join(f"celo:{t}" for t in ch)
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
        with urllib.request.urlopen(req, timeout=45) as r:
            d = json.loads(r.read().decode())
        for k2, v in (d.get("coins") or {}).items():
            pr[k2.split(":")[1].lower()] = v
    except Exception as e:
        print("llama err", e)
    time.sleep(0.3)

for t in tokens:
    m = meta.get(t, {})
    p = pr.get(t, {})
    out[t] = {"symbol": m.get("symbol"), "name": m.get("name"), "decimals": m.get("decimals"),
              "totalSupply": m.get("totalSupply"),
              "llama_price": p.get("price"), "llama_symbol": p.get("symbol"), "llama_conf": p.get("confidence")}

with open(os.path.join(HERE, "tokens.json"), "w") as f:
    json.dump(out, f, indent=1)
for t, v in out.items():
    print(f"{t} {v['symbol']!r} dec={v['decimals']} supply={v['totalSupply']} price={v['llama_price']}")
print("wrote tokens.json")
