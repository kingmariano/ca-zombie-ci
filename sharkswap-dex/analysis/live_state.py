#!/usr/bin/env python3
"""SharkSwap DEX (Base) — live state enumeration at latest block.
Read-only. Public RPC only. Never writes secrets/URLs with keys.
Outputs: analysis/live_state.json
"""
import json, os, time, urllib.request

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "live_state.json")
FACTORY = "0x57592d44eb60011500961ef177bff8d8691d5a8b"
RPCS = [
    "https://base-rpc.publicnode.com",
    "https://mainnet.base.org",
]
UA = {"User-Agent": "Mozilla/5.0 (X11; Linux x86_64) research"}

def rpc_batch(url, calls, timeout=90):
    payload = [{"jsonrpc": "2.0", "id": i, "method": m, "params": p}
               for i, (m, p) in enumerate(calls)]
    body = json.dumps(payload).encode()
    req = urllib.request.Request(url, data=body,
                                 headers={**UA, "Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        d = json.loads(r.read().decode())
    out = [None] * len(calls)
    if isinstance(d, list):
        for item in d:
            i = item.get("id")
            if isinstance(i, int) and 0 <= i < len(calls):
                out[i] = item.get("result", {"error": item.get("error")})
    return out

def batches(seq, n):
    for i in range(0, len(seq), n):
        yield seq[i:i + n]

def call_num(url, to, sig):
    return int(rpc_batch(url, [("eth_call", [{"to": to, "data": sig}, "latest"])])[0], 16)

def call_addr(url, to, sig):
    r = rpc_batch(url, [("eth_call", [{"to": to, "data": sig}, "latest"])])[0]
    return "0x" + r[-40:]

def sel(sig):
    # keccak via cast is external; use precomputed map instead
    return SIGS[sig]

SIGS = {
    "allPairsLength()": "0x574f2ba3",
    "allPairs(uint256)": "0x1e3dd18b",
    "feeTo()": "0x017e7e58",
    "feeToSetter()": "0x094b7415",
    "token0()": "0x0dfe1681",
    "token1()": "0xd21220a7",
    "getReserves()": "0x0902f1ac",
    "totalSupply()": "0x18160ddd",
    "balanceOf(address)": "0x70a08231",
    "kLast()": "0x7464fc3d",
    "factory()": "0xc45a0155",
    "symbol()": "0x95d89b41",
    "decimals()": "0x313ce567",
    "name()": "0x06fdde03",
}

def main():
    url = None
    for u in RPCS:
        try:
            rpc_batch(u, [("eth_blockNumber", [])], timeout=15)
            url = u
            break
        except Exception as e:
            print("rpc fail", u, str(e)[:80])
    assert url, "no working base rpc"
    bn = int(rpc_batch(url, [("eth_blockNumber", [])], timeout=15)[0], 16)
    print("base block", bn)

    n = call_num(url, FACTORY, SIGS["allPairsLength()"])
    print("pairs:", n)
    feeTo = call_addr(url, FACTORY, SIGS["feeTo()"])
    feeToSetter = call_addr(url, FACTORY, SIGS["feeToSetter()"])
    print("feeTo", feeTo, "feeToSetter", feeToSetter)

    pairs = []
    for chunk in batches(list(range(n)), 10):
        calls = [("eth_call", [{"to": FACTORY,
                                "data": SIGS["allPairs(uint256)"] + hex(i)[2:].rjust(64, "0")},
                               "latest"]) for i in chunk]
        res = rpc_batch(url, calls)
        for i, r in zip(chunk, res):
            pairs.append("0x" + r[-40:])
    print(json.dumps(pairs, indent=0))

    data = {"factory": FACTORY, "block": bn, "feeTo": feeTo, "feeToSetter": feeToSetter,
            "n_pairs": n, "pairs": {}}

    for idx, p in enumerate(pairs):
        c = [
            ("token0()", p, "eth_call"),
        ]
        # batch per pair: token0,token1,reserves,totalSupply,kLast,factory
        calls = [
            ("eth_call", [{"to": p, "data": SIGS["token0()"]}, "latest"]),
            ("eth_call", [{"to": p, "data": SIGS["token1()"]}, "latest"]),
            ("eth_call", [{"to": p, "data": SIGS["getReserves()"]}, "latest"]),
            ("eth_call", [{"to": p, "data": SIGS["totalSupply()"]}, "latest"]),
            ("eth_call", [{"to": p, "data": SIGS["kLast()"]}, "latest"]),
            ("eth_call", [{"to": p, "data": SIGS["factory()"]}, "latest"]),
        ]
        r0, r1, rres, rts, rk, rf = rpc_batch(url, calls)
        t0 = "0x" + r0[-40:]
        t1 = "0x" + r1[-40:]
        reserves_raw = rres[2:] if rres.startswith("0x") else rres
        res0 = int(reserves_raw[0:64], 16)
        res1 = int(reserves_raw[64:128], 16)
        ts = int(rts, 16)
        klast = int(rk, 16)
        fac = "0x" + rf[-40:]
        # balances of pair
        b0 = int(rpc_batch(url, [("eth_call", [{"to": t0, "data": SIGS["balanceOf(address)"] + p[2:].rjust(64, "0")}, "latest"])])[0], 16)
        b1 = int(rpc_batch(url, [("eth_call", [{"to": t1, "data": SIGS["balanceOf(address)"] + p[2:].rjust(64, "0")}, "latest"])])[0], 16)
        # token meta
        s0r = rpc_batch(url, [("eth_call", [{"to": t0, "data": SIGS["symbol()"]}, "latest"])])[0]
        s1r = rpc_batch(url, [("eth_call", [{"to": t1, "data": SIGS["symbol()"]}, "latest"])])[0]
        d0 = rpc_batch(url, [("eth_call", [{"to": t0, "data": SIGS["decimals()"]}, "latest"])])[0]
        d1 = rpc_batch(url, [("eth_call", [{"to": t1, "data": SIGS["decimals()"]}, "latest"])])[0]
        def dec_str(r):
            try:
                if not r or r == "0x":
                    return None
                b = bytes.fromhex(r[2:])
                if len(b) >= 64:
                    ln = int.from_bytes(b[32:64], "big")
                    return b[64:64 + ln].decode("utf-8", "replace")
                return b.decode("utf-8", "replace").strip("\x00")
            except Exception:
                return None
        entry = {
            "pair": p, "index": idx, "factory_ok": fac.lower() == FACTORY.lower(),
            "token0": t0, "token1": t1,
            "symbol0": dec_str(s0r), "symbol1": dec_str(s1r),
            "dec0": int(d0, 16) if d0 and d0 != "0x" else None,
            "dec1": int(d1, 16) if d1 and d1 != "0x" else None,
            "reserve0": res0, "reserve1": res1,
            "balance0": b0, "balance1": b1,
            "excess0": b0 - res0, "excess1": b1 - res1,
            "lp_totalSupply": ts, "kLast": klast,
        }
        data["pairs"][p] = entry
        print(idx, p, entry["symbol0"], entry["symbol1"],
              "reserves", res0, res1, "excess", b0 - res0, b1 - res1, "lp", ts)

    with open(OUT, "w") as f:
        json.dump(data, f, indent=1)
    print("wrote", OUT)

if __name__ == "__main__":
    main()
