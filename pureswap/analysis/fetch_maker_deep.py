#!/usr/bin/env python3
"""Deep-dive reads: maker LP across all pairs, bridgeFor, ownership, token metadata."""
import json, os, urllib.request, time

RPC = os.environ.get("RPC_BSC", "https://bsc-rpc.publicnode.com")

def rpc(method, params, retries=4):
    body = json.dumps({"jsonrpc": "2.0", "id": 1, "method": method, "params": params}).encode()
    for i in range(retries):
        try:
            req = urllib.request.Request(RPC, data=body, headers={"Content-Type": "application/json", "User-Agent": "Mozilla/5.0"})
            d = json.loads(urllib.request.urlopen(req, timeout=30).read().decode())
            if "result" in d:
                return d["result"]
        except Exception:
            time.sleep(1.2 * (i + 1))
    return None

def call(to, data):
    r = rpc("eth_call", [{"to": to, "data": data}, "latest"])
    return r

def batch(calls):
    out = []
    for i in range(0, len(calls), 10):
        chunk = calls[i:i+10]
        payload = [{"jsonrpc": "2.0", "id": j, "method": "eth_call", "params": [{"to": t, "data": d}, "latest"]} for j, (t, d) in enumerate(chunk)]
        body = json.dumps(payload).encode()
        res = None
        for attempt in range(4):
            try:
                req = urllib.request.Request(RPC, data=body, headers={"Content-Type": "application/json", "User-Agent": "Mozilla/5.0"})
                res = json.loads(urllib.request.urlopen(req, timeout=45).read().decode())
                break
            except Exception:
                time.sleep(1.2 * (attempt + 1))
        res = sorted(res, key=lambda x: x["id"])
        out.extend(x.get("result") for x in res)
    return out

def pad(a):
    a = a.lower()
    if a.startswith("0x"):
        a = a[2:]
    return "0" * (64 - len(a)) + a

PM1 = "0xcc93fbbfae96d2fdc562afce89f466f2996b4c95"
PM2 = "0xa7d7c06928a6a255a8e7083433f3fcea08082698"
FACTORY = "0x94b4188d143b9dd6bd7083ae38a461fcc6aad07e"

def main():
    d = json.load(open(os.path.join(os.path.dirname(__file__), "pairs-state.json")))
    tok = json.load(open(os.path.join(os.path.dirname(__file__), "tokens.json")))
    pairs = d["pairs"]

    # maker meta
    meta = {}
    for name, m in [("PM1", PM1), ("PM2", PM2)]:
        meta[name] = {
            "owner": call(m, "0x8da5cb5b"),
            "factory": call(m, "0x45a4c0c4") or None,  # factory() selector? check below
            "pureToken": None,
            "weth": None,
            "owner_addr": call(m, "0x8da5cb5b"),
        }
    # selectors from ABI
    abi1 = json.load(open("abi-PureMaker-0xcc93fbbf.json"))
    sels = {}
    for item in abi1:
        if item.get("type") == "function" and item.get("constant"):
            import eth_utils  # may not exist; fallback manual
    # manual selectors (keccak computed via cast earlier where needed)
    SEL = {
        "factory()": "0x2d3c2f12", "pureToken()": None, "bar()": "0xf0f44260", "weth()": None,
        "bridgeFor(address)": "0xa5a9d3a9", "owner()": "0x8da5cb5b",
    }
    # compute selectors with solidity keccak via cast if available
    import subprocess
    def sig(s):
        return subprocess.run(["cast", "sig", s], capture_output=True, text=True).stdout.strip()
    SEL2 = {s: sig(s) for s in ["factory()", "pureToken()", "bar()", "weth()", "bridgeFor(address)", "owner()", "convert(address,address)", "convertMultiple(address[],address[])"]}
    print("selectors:", SEL2, flush=True)

    info = {}
    for name, m in [("PM1", PM1), ("PM2", PM2)]:
        vals = {}
        for f in ["factory()", "pureToken()", "bar()", "weth()", "owner()"]:
            r = call(m, SEL2[f])
            vals[f] = r
        info[name] = vals
        print(name, json.dumps(vals), flush=True)

    # bridgeFor for all unique tokens
    tokens = sorted(set([p["token0"] for p in pairs] + [p["token1"] for p in pairs]))
    br = {}
    for name, m in [("PM1", PM1), ("PM2", PM2)]:
        res = batch([(m, SEL2["bridgeFor(address)"] + pad(t)) for t in tokens])
        br[name] = {t: ("0x" + r[-40:].lower() if r else None) for t, r in zip(tokens, res)}
    print("bridges PM1:", json.dumps(br["PM1"], indent=0), flush=True)
    json.dump({"info": info, "bridges": br}, open(os.path.join(os.path.dirname(__file__), "makers-meta.json"), "w"), indent=1)

    # LP balances of both makers for all pairs
    res = batch([(p["pair"], "0x70a08231" + pad(PM1)) for p in pairs] + [(p["pair"], "0x70a08231" + pad(PM2)) for p in pairs])
    lp1 = res[:len(pairs)]; lp2 = res[len(pairs):]
    out = []
    for p, a, b in zip(pairs, lp1, lp2):
        a = int(a, 16) if a else 0
        b = int(b, 16) if b else 0
        ts = p["totalSupply"] or 0
        out.append({"pair": p["pair"], "token0": p["token0"], "token1": p["token1"],
                    "lp_maker1": a, "lp_maker2": b, "share1": (a / ts if ts else None),
                    "share2": (b / ts if ts else None), "totalSupply": ts,
                    "reserve0": p["reserve0"], "reserve1": p["reserve1"]})
    json.dump(out, open(os.path.join(os.path.dirname(__file__), "maker-lp-all.json"), "w"), indent=1)
    for r in out:
        s0 = tok[r["token0"]]["symbol"]; s1 = tok[r["token1"]]["symbol"]
        print(f"{r['pair']} {s0}/{s1} share1={r['share1'] and round(r['share1']*100,2)}% share2={r['share2'] and round(r['share2']*100,2)}%", flush=True)

if __name__ == "__main__":
    main()
