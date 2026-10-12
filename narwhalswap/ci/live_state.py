#!/usr/bin/env python3
"""
CI-side live-state re-verification for Narwhalswap (BSC).
Read-only. Writes ci-out/live-state.json. Never logs secrets/RPC URLs.
Uses BSC_RPC_URL from CI env, falling back to keyless public endpoints.
"""
import json, os, sys, time, re, urllib.request

OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "ci-out")
os.makedirs(OUT, exist_ok=True)
UA = {"User-Agent": "Mozilla/5.0 zombie-ci"}
URL_RE = re.compile(r"https?://\S+")

def redact(s):
    """Never let an RPC URL (which may carry a key in CI) reach logs/artifacts."""
    return URL_RE.sub("<url-redacted>", str(s))[:120]

RPCS = [os.environ.get("BSC_RPC_URL") or "", "https://bsc-rpc.publicnode.com",
        "https://bsc-dataseed.bnbchain.org", "https://1rpc.io/bnb"]
RPCS = [u for u in RPCS if u]

def rpc(method, params, timeout=25):
    body = json.dumps({"jsonrpc": "2.0", "id": 1, "method": method, "params": params}).encode()
    errs = []
    for url in RPCS:
        try:
            req = urllib.request.Request(url, data=body, headers={**UA, "Content-Type": "application/json"})
            with urllib.request.urlopen(req, timeout=timeout) as r:
                d = json.loads(r.read().decode())
            if "result" in d:
                return d["result"]
            errs.append(redact(d.get("error")))
        except Exception as e:
            errs.append(redact(e))
        time.sleep(0.2)
    raise RuntimeError("rpc fail: " + " | ".join(errs[-2:]))

def call(to, data, block="latest"):
    return rpc("eth_call", [{"to": to, "data": data}, block])

def addr(h):
    return "0x" + h[-40:] if h and h != "0x" else None

def w(a): return a.lower().replace("0x", "").rjust(64, "0")
def num(h): return int(h, 16) if h and h != "0x" else None

SEL = {
    "allPairsLength": "0x574f2ba3", "allPairs": "0x1e3dd18b", "feeTo": "0x017e7e58",
    "feeToSetter": "0x094b7415", "token0": "0x0dfe1681", "token1": "0xd21220a7",
    "getReserves": "0x0902f1ac", "totalSupply": "0x18160ddd", "balanceOf": "0x70a08231",
    "lpToken": "0x5fcbd285", "nar": "0x86c2ef68", "rnlp": "0x4c738a5e",
    "_powerStrategy": "0xee631881", "_governance": "0x1c2f3e3d",
    "_emergencyStop": "0x68612782", "_hasStart": "0xe45a98dd",
    "_rewardRate": "0x68fd25cd", "_periodFinish": "0x1407c664",
    "owner": "0x8da5cb5b", "unlockTime": "0x251c1aa3", "convert": "0xbd1b820c",
    "threshold": "0x42cde4e8", "minter": "0x07546172",
}
FACTORY = "0xb9fa84912ff2383a617d8b433e926adf0dd3fea1"
COLLECTER = "0x7f8a46ec48442d9ebf28fbc1144a83f8bc53f7e9"
NAR = "0xa1303e6199b319a891b79685f0537d289af1fc83"
WBNB = "0xbb4cdb9cbd36b01bd1cbaebf2de08d9173bc095c"
LOCKER = "0x07f1b50d5ae24ec41aa7269d65a5e23e8401542a"
FARMS = {
    "V1_narwbnb": "0x186be2a9f0e9c92b880bbd3ec1f35f422f0d8835",
    "V1_wbnb_busd": "0xbb38f7551025a433f36590be85271110212655de",
    "V2_narwbnb": "0x1D227F7e283D653a60F94d2350CAB7a49bB85C6f",
    "V2_wbnb_busd": "0x6dA9Ee0c0571b63e38950D1e12e835D5343f601B",
    "V3_narwbnb": "0xbe85812237741d75f81aebf1d9af52d544542168",
    "V3_btcb_nar": "0x268a2c1acbeee3b74616b9fe3f07c1bf80841e5d",
    "DIV_v3_2": "0xf7a36c87c3a8909949638120f23cd721bf572032",
}

def main():
    blk = num(rpc("eth_blockNumber", []))
    out = {"block": blk, "factory": {}, "pairs": {}, "farms": {}, "locker": {}, "collecter": {}, "prices": {}}
    print("block", blk)
    out["factory"] = {
        "addr": FACTORY,
        "allPairsLength": num(call(FACTORY, SEL["allPairsLength"])),
        "feeTo": addr(call(FACTORY, SEL["feeTo"])),
        "feeToSetter": addr(call(FACTORY, SEL["feeToSetter"])),
    }
    n = out["factory"]["allPairsLength"]
    pairs = [addr(call(FACTORY, SEL["allPairs"] + w(format(i, "x")))) for i in range(n)]
    # top pairs + a full excess scan
    tokens = set()
    rows = []
    skipped = []
    for p in pairs:
        t0 = addr(call(p, SEL["token0"])); t1 = addr(call(p, SEL["token1"]))
        r = call(p, SEL["getReserves"])
        if not r or not t0 or not t1:
            skipped.append(p); continue
        b = bytes.fromhex(r[2:])
        r0 = int.from_bytes(b[0:32], "big"); r1 = int.from_bytes(b[32:64], "big")
        try:
            b0 = num(call(t0, SEL["balanceOf"] + w(p)))
            b1 = num(call(t1, SEL["balanceOf"] + w(p)))
        except Exception:
            b0 = b1 = None
        if b0 is None or b1 is None:
            skipped.append(p); continue
        rows.append({"pair": p, "token0": t0, "token1": t1, "r0": r0, "r1": r1, "b0": b0, "b1": b1,
                     "lp": num(call(p, SEL["totalSupply"]))})
        tokens.add(t0); tokens.add(t1)
    total_excess = sum(max(0, x["b0"] - x["r0"]) for x in rows) + sum(max(0, x["b1"] - x["r1"]) for x in rows)
    out["all_pairs_checked"] = len(rows)
    out["pairs_skipped_dead"] = skipped
    out["total_raw_excess_units"] = total_excess
    out["excess_pairs"] = [x["pair"] for x in rows if x["b0"] > x["r0"] or x["b1"] > x["r1"]]
    # record all pairs (full excess scan) + top-20 by raw reserve for readability
    out["pairs"] = {x["pair"]: x for x in rows}
    big = sorted(rows, key=lambda x: -(x["r0"] + x["r1"]))[:20]
    out["pairs_top20"] = [x["pair"] for x in big]
    # farms
    for name, f in FARMS.items():
        d = {}
        for k in ("lpToken", "nar", "rnlp", "_powerStrategy", "_governance", "owner"):
            try: d[k] = addr(call(f, SEL[k]))
            except Exception: d[k] = None
        for k in ("_emergencyStop", "_hasStart"):
            try: d[k] = num(call(f, SEL[k])) != 0
            except Exception: d[k] = None
        for k in ("_rewardRate", "_periodFinish", "totalSupply"):
            try: d[k] = num(call(f, SEL[k]))
            except Exception: d[k] = None
        try:
            if d["lpToken"]:
                d["lp_held"] = num(call(d["lpToken"], SEL["balanceOf"] + w(f)))
                d["lp_totalSupply"] = num(call(d["lpToken"], SEL["totalSupply"]))
            if d["nar"]:
                d["nar_held"] = num(call(d["nar"], SEL["balanceOf"] + w(f)))
            if d["rnlp"]:
                d["rnlp_totalSupply"] = num(call(d["rnlp"], SEL["totalSupply"]))
                d["rnlp_minter"] = addr(call(d["rnlp"], SEL["minter"]))
        except Exception as e:
            d["err"] = str(e)[:80]
        out["farms"][name] = d
        print(name, d.get("lp_held"), d.get("nar_held"))
    # locker + collecter
    out["locker"] = {"addr": LOCKER, "owner": addr(call(LOCKER, SEL["owner"])),
                     "unlockTime": num(call(LOCKER, "0x251c1aa3")),
                     "lp_held": num(call("0xb6b0ba4e208ab93602be7a81f1400a7c7daad1f2", SEL["balanceOf"] + w(LOCKER)))}
    out["collecter"] = {"addr": COLLECTER, "wbnb": num(call(WBNB, SEL["balanceOf"] + w(COLLECTER))),
                        "threshold": num(call(COLLECTER, SEL["threshold"]))}
    # prices
    try:
        url = "https://coins.llama.fi/prices/current/bsc:" + WBNB + ",bsc:" + NAR + ",bsc:0xe9e7cea3dedca5984780bafc599bd69add087d56,bsc:0x7130d2a12b9bcbfae4f2634d864a1ee1ce3ead9c,bsc:0x55d398326f99059ff775485246999027b3197955"
        req = urllib.request.Request(url, headers=UA)
        with urllib.request.urlopen(req, timeout=25) as r:
            out["prices"] = json.loads(r.read()).get("coins", {})
    except Exception as e:
        out["prices_err"] = str(e)[:100]
    with open(os.path.join(OUT, "live-state.json"), "w") as fh:
        json.dump(out, fh, indent=1)
    print("wrote ci-out/live-state.json")

if __name__ == "__main__":
    main()
