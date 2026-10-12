#!/usr/bin/env python3
"""PureSwap (BSC) live-state dump — read-only.

Enumerates the factory and all pairs at a pinned block, and dumps raw hex results.
No secrets in this file; RPC endpoint comes from env RPC_BSC or defaults to a
keyless public endpoint.
"""
import json, os, sys, time, urllib.request

RPC = os.environ.get("RPC_BSC", "https://bsc-rpc.publicnode.com")
FACTORY = "0x94b4188d143b9dd6bd7083ae38a461fcc6aad07e"

def rpc(method, params, retries=4):
    body = json.dumps({"jsonrpc": "2.0", "id": 1, "method": method, "params": params}).encode()
    for i in range(retries):
        try:
            req = urllib.request.Request(RPC, data=body, headers={"Content-Type": "application/json", "User-Agent": "Mozilla/5.0"})
            with urllib.request.urlopen(req, timeout=30) as r:
                d = json.loads(r.read().decode())
            if "result" in d:
                return d["result"]
            if "error" in d:
                raise RuntimeError(d["error"])
        except Exception as e:
            if i == retries - 1:
                raise
            time.sleep(1.5 * (i + 1))
    raise RuntimeError("unreachable")

def eth_call(to, data, block="latest"):
    return rpc("eth_call", [{"to": to, "data": data}, hex(block) if isinstance(block, int) else block])

def batch_calls(calls, block):
    """calls: list of (to, data). Batches of 10."""
    out = []
    for i in range(0, len(calls), 10):
        chunk = calls[i:i+10]
        payload = [{"jsonrpc": "2.0", "id": j, "method": "eth_call",
                    "params": [{"to": t, "data": d}, hex(block)]} for j, (t, d) in enumerate(chunk)]
        body = json.dumps(payload).encode()
        for attempt in range(4):
            try:
                req = urllib.request.Request(RPC, data=body, headers={"Content-Type": "application/json", "User-Agent": "Mozilla/5.0"})
                with urllib.request.urlopen(req, timeout=45) as r:
                    res = json.loads(r.read().decode())
                break
            except Exception:
                if attempt == 3:
                    raise
                time.sleep(1.5 * (attempt + 1))
        res = sorted(res, key=lambda x: x["id"])
        out.extend(x.get("result") for x in res)
    return out

def int_of(hexstr, default=None):
    if hexstr is None or hexstr == "0x":
        return default
    return int(hexstr, 16)

def addr_of(word):
    if word is None:
        return None
    return "0x" + word[-40:].lower()

def dec_of(word):
    return int_of(word)

SEL = {
    "allPairsLength": "0x574f2ba3",
    "allPairs_": "0x1e3dd18b",   # allPairs(uint)
    "feeToPure": "0x265c215e",
    "feeToMx": "0xfe1982f5",
    "feeTo": "0x017e7e58",       # feeTo() -> (address,address)
    "feeToSetter": "0x094b7415",
    "migrator": "0x7cd07e47",
    "pairCodeHash": "0x9aab9248",
    "token0": "0x0dfe1681",
    "token1": "0xd21220a7",
    "getReserves": "0x0902f1ac",
    "totalSupply": "0x18160ddd",
    "kLast": "0x7464fc3d",
    "balanceOf": "0x70a08231",
    "symbol": "0x95d89b41",
    "decimals": "0x313ce567",
    "name": "0x06fdde03",
}

def pad(addr):
    return "0" * 24 + addr[2:].lower()

def main():
    block = int_of(rpc("eth_blockNumber", []))
    print(f"[block] {block}", file=sys.stderr)

    # factory reads
    f = {}
    f["feeTo"] = eth_call(FACTORY, SEL["feeTo"], block)
    f["feeToPure"] = eth_call(FACTORY, SEL["feeToPure"], block)
    f["feeToMx"] = eth_call(FACTORY, SEL["feeToMx"], block)
    f["feeToSetter"] = eth_call(FACTORY, SEL["feeToSetter"], block)
    f["migrator"] = eth_call(FACTORY, SEL["migrator"], block)
    n = int_of(eth_call(FACTORY, SEL["allPairsLength"], block))
    f["allPairsLength"] = n
    code = rpc("eth_getCode", [FACTORY, hex(block)])
    f["code_len"] = (len(code) - 2) // 2
    print(f"[factory] pairs={n} feeToSetter={addr_of(f['feeToSetter'])}", file=sys.stderr)

    pairs = []
    data = batch_calls([(FACTORY, SEL["allPairs_"] + format(i, "064x")) for i in range(n)], block)
    pair_addrs = [addr_of(x) for x in data]

    calls = []
    meta = []
    for p in pair_addrs:
        calls += [
            (p, SEL["token0"]),
            (p, SEL["token1"]),
            (p, SEL["getReserves"]),
            (p, SEL["totalSupply"]),
            (p, SEL["kLast"]),
            (p, "0x" + "dd62ed3e" + pad("0" * 40)),  # placeholder replaced below
        ]
        meta.append(p)
    # fetch token0/token1 first (simple pass)
    toks = batch_calls([(p, SEL["token0"]) for p in pair_addrs] + [(p, SEL["token1"]) for p in pair_addrs], block)
    t0 = [addr_of(x) for x in toks[:n]]
    t1 = [addr_of(x) for x in toks[n:]]

    # pair state: getReserves, totalSupply, kLast, and ACTUAL token holdings via token.balanceOf(pair)
    res = batch_calls(
        [(p, SEL["getReserves"]) for p in pair_addrs]
        + [(p, SEL["totalSupply"]) for p in pair_addrs]
        + [(p, SEL["kLast"]) for p in pair_addrs]
        + [(a, SEL["balanceOf"] + pad(p)) for p, a in zip(pair_addrs, t0)]
        + [(a, SEL["balanceOf"] + pad(p)) for p, a in zip(pair_addrs, t1)],
        block,
    )
    rs = res[:n]; ts = res[n:2*n]; kl = res[2*n:3*n]; b0 = res[3*n:4*n]; b1 = res[4*n:5*n]

    # token meta
    tok_calls = []
    for a in t0 + t1:
        tok_calls += [(a, SEL["symbol"]), (a, SEL["decimals"])]
    tm = batch_calls(tok_calls, block)
    tmeta = {}
    toks_all = t0 + t1
    for i, a in enumerate(toks_all):
        sym_raw = tm[2*i]; dec_raw = tm[2*i+1]
        sym = None
        try:
            if sym_raw and len(sym_raw) > 130:
                ln = int(sym_raw[130:194], 16)
                sym = bytes.fromhex(sym_raw[194:194+ln*2]).decode("utf-8", "replace") if ln < 64 else None
            elif sym_raw and len(sym_raw) == 66:
                sym = bytes.fromhex(sym_raw[2:]).decode("utf-8", "replace").strip("\x00")
        except Exception:
            sym = None
        tmeta[a] = {"symbol": sym, "decimals": dec_of(dec_raw) if dec_raw else None}

    pairs = []
    for i, p in enumerate(pair_addrs):
        r = rs[i]
        r0 = int_of("0x" + r[2:66]) if r and len(r) >= 130 else None
        r1 = int_of("0x" + r[66:130]) if r and len(r) >= 130 else None
        ts_ = int_of("0x" + r[130:194]) if r and len(r) >= 194 else None
        pairs.append({
            "pair": p,
            "token0": t0[i], "token1": t1[i],
            "reserve0": r0, "reserve1": r1, "tsLast": ts_,
            "totalSupply": dec_of(ts[i]),
            "kLast": dec_of(kl[i]),
            "bal0": dec_of(b0[i]), "bal1": dec_of(b1[i]),
            "excess0": (dec_of(b0[i]) - r0) if (b0[i] is not None and r0 is not None) else None,
            "excess1": (dec_of(b1[i]) - r1) if (b1[i] is not None and r1 is not None) else None,
            "tmeta": {t0[i]: tmeta.get(t0[i]), t1[i]: tmeta.get(t1[i])},
        })

    out = {"block": block, "factory": FACTORY, "factory_state": f,
           "factory_feeTo_raw": f["feeTo"],
           "pairs": pairs}
    fn = os.path.join(os.path.dirname(__file__), "pairs-state.json")
    with open(fn, "w") as fh:
        json.dump(out, fh, indent=1)
    print(f"[dump] wrote {fn}", file=sys.stderr)

    # summary print
    for p in pairs:
        print(f"{p['pair']} ts={p['totalSupply']} r0={p['reserve0']} r1={p['reserve1']} "
              f"b0={p['bal0']} b1={p['bal1']} exc0={p['excess0']} exc1={p['excess1']} "
              f"t0={p['token0']}({p['tmeta'][p['token0']].get('symbol') if p['tmeta'][p['token0']] else '?'}) "
              f"t1={p['token1']}({p['tmeta'][p['token1']].get('symbol') if p['tmeta'][p['token1']] else '?'})")

if __name__ == "__main__":
    main()
