#!/usr/bin/env python3
"""Live (balance - reserve) re-check for the 12 top_excess pairs + top-10 reserve pairs.
Read-only. Public RPCs only. No secrets.
"""
import json, os, urllib.request

RPC = os.environ.get("BSC_RPC_URL") or "https://bsc-rpc.publicnode.com"
FALLBACKS = ["https://bsc.drpc.org", "https://1rpc.io/bnb"]
UA = {"User-Agent": "Mozilla/5.0 (X11; Linux x86_64) child-audit", "Content-Type": "application/json"}

PAIRS = [
    "0xb9efbd2bb41f7a2136bf2b21e8b26641651adef9",
    "0x9a4682cf610d49688d520e32996cf6cdfb14b0c8",
    "0x030ebc2465d4003d52841043d47e636beeb07ce0",
    "0xd948d34ce937d9d6b7d54741e33030d4dae3f700",
    "0x4e5f1ae9ffca3dd201fe1a222abf35441e265788",
    "0x05e80920cc8a51d0e3f98983c954a9611667d67a",
    "0x299c91fc4ff0cc596be7ece2aab676e7b7c21246",
    "0x510fa68a99bd3ca6845d4394f16ed8a75c764d77",
    "0xb15365734227a96f8c61d64e5dd1040ddaa3fcdd",
    "0x76f33b7b2af0ba9af6cd59c6873f031d1933b58a",
    "0xa4890c45be913c7fe9967543b07dfe753e459fa6",
    "0x6c723ba7991895741de4ac537d64f469d0b4eac2",
    # top reserve pairs
    "0xf4e58b13f7e847111c120a7258e8e2164294c261",
    "0x61c960d0337f1efe46bc7b1110ba8c4e60dd2017",
    "0x2e4bae64cc33ec8a7608930e8bd32f592e8a9968",
    "0xa6e72521f19babeb1defff1f5a36024302303897",
    "0x5cce01ada9aa19552571be68204126cc00576b3d",
    "0x1c02a798ea49d78eeb35840b481992a871608feb",
    "0x5ab38077e9c5f9980bbabf68679b7e34137a51af",
    "0xf39fd80c0bf774beebc8803c2d9161a1678879e7",
    "0xb390f799ba5f75e0bb15014a9a34a0dec6760e1e",
    "0xc4dbfe8860bd39f0f8281b7de8ee53730c9a44e1",
]

def rpc_batch(calls, timeout=60):
    payload = [{"jsonrpc": "2.0", "id": i, "method": m, "params": p} for i, (m, p) in enumerate(calls)]
    body = json.dumps(payload).encode()
    last = None
    for url in [RPC] + FALLBACKS:
        try:
            req = urllib.request.Request(url, data=body, headers=UA)
            with urllib.request.urlopen(req, timeout=timeout) as r:
                d = json.loads(r.read().decode())
            if isinstance(d, list):
                out = [None] * len(calls)
                for it in d:
                    out[it["id"]] = it.get("result", {"error": it.get("error")})
                return out
            last = d
        except Exception as e:
            last = f"{type(e).__name__}: {e}"
    raise RuntimeError(f"batch fail: {last}")

def address_of(hexres):
    if not isinstance(hexres, str) or len(hexres) < 42:
        return None
    a = "0x" + hexres[-40:]
    return a

def main():
    # 1) token0/token1 for each pair
    calls = []
    for p in PAIRS:
        calls.append(("eth_call", [{"to": p, "data": "0x0dfe1681"}, "latest"]))
    for p in PAIRS:
        calls.append(("eth_call", [{"to": p, "data": "0xd21220a7"}, "latest"]))
    rs = rpc_batch(calls)
    L = len(PAIRS)
    toks = []
    for i, p in enumerate(PAIRS):
        t0, t1 = address_of(rs[i]), address_of(rs[L + i])
        toks.append((t0, t1))

    # 2) reserves + balances + totalSupply
    calls = []
    for p in PAIRS:
        calls.append(("eth_call", [{"to": p, "data": "0x0902f1ac"}, "latest"]))
    for i, (t0, t1) in enumerate(toks):
        calls.append(("eth_call", [{"to": t0, "data": "0x70a08231" + "0" * 24 + PAIRS[i][2:]}, "latest"]))
        calls.append(("eth_call", [{"to": t1, "data": "0x70a08231" + "0" * 24 + PAIRS[i][2:]}, "latest"]))
    for p in PAIRS:
        calls.append(("eth_call", [{"to": p, "data": "0x18160ddd"}, "latest"]))
    rs = rpc_batch(calls)
    n = len(PAIRS)
    print(f"block={json.loads(urllib.request.urlopen(urllib.request.Request(RPC, data=json.dumps({'jsonrpc':'2.0','id':1,'method':'eth_blockNumber','params':[]}).encode(), headers=UA), timeout=20).read())['result']}")
    print(f"{'pair':42s} {'reserve0':>18s} {'bal0':>18s} {'exc0':>8s} {'reserve1':>18s} {'bal1':>18s} {'exc1':>8s} {'lpSupply':>12s}")
    for i, p in enumerate(PAIRS):
        rr = rs[i]
        if not isinstance(rr, str) or len(rr) < 130:
            print(f"{p} reserve-read-fail: {rr}")
            continue
        r0 = int(rr[2:66], 16); r1 = int(rr[66:130], 16)
        b0h = rs[n + 2 * i]
        b1h = rs[n + 2 * i + 1]
        b0 = int(b0h, 16) if isinstance(b0h, str) else -1
        b1 = int(b1h, 16) if isinstance(b1h, str) else -1
        ts = rs[3 * n + i]
        tsi = int(ts, 16) if isinstance(ts, str) else -1
        e0 = b0 - r0 if b0 >= 0 else "?"
        e1 = b1 - r1 if b1 >= 0 else "?"
        print(f"{p} r0={r0} b0={b0} e0={e0} r1={r1} b1={b1} e1={e1} lp={tsi}")
        print(f"    t0={toks[i][0]} t1={toks[i][1]}")

if __name__ == "__main__":
    main()
