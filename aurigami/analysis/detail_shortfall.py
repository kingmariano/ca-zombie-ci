#!/usr/bin/env python3
"""Detail scan: per-market snapshots for accounts with shortfall; compute liquidation profitability."""
import json
import time
import urllib.request

RPC = "https://mainnet.aurora.dev"
UNIT = "0x817af6cfAF35BdC1A634d6cC94eE9e4c68369Aeb"
ORACLE = "0x5A7B8E3CDc6ee2E0E6Ad0d4fab8dCD70990157EE"

MARKETS = {
    "auUSDC": "0x4f0d864b1ABf4B701799a0b30b57A22dFEB5917b",
    "auETH": "0xca9511B610bA5fc7E311FDeF9cE16050eE4449E9",
    "auWBTC": "0xCFb6b0498cb7555e7e21502E0F449bf28760Adbb",
    "auUSDT": "0xaD5A2437Ff55ed7A8Cad3b797b3eC7c5a19B1c54",
    "auDAI": "0xCE4166363E3a584DAc84A47bCD3414B43EfCDd1c",
    "auWNEAR": "0xaE4fac24dCdAE0132C6d04f564dCf059616E9423",
    "auSTNEAR": "0x3195949f267702723bc614cAE037cdc8D1E94786",
    "auAURORA": "0x8888682E24dd4Df7B7Ff2B91fccB575737E433bf",
    "auTRI": "0x6Ea6C03061bDdCE23d4Ec60B6E6e880c33d24dca",
    "auPLY": "0xC9011e629c9d0b8B1e4A2091e123fBB87B3A792c",
    "auUSN": "0x5cCAD065400341db391FD3a4B7F50087B678D7CC",
    "auNEARX": "0xC7ea819ebf08E5FF481D4708a602f92380AFbB0a",
    "auUSDCNative": "0x10D56d6E5968016dF5930E8Ce50d2d08EC59774c",
    "auUSDTNative": "0xdDfd0407220026c6566979B5be6A4983d1247a3E",
}
DEC = {"auUSDC": 6, "auETH": 18, "auWBTC": 8, "auUSDT": 6, "auDAI": 18,
       "auWNEAR": 24, "auSTNEAR": 24, "auAURORA": 18, "auTRI": 18, "auPLY": 18,
       "auUSN": 18, "auNEARX": 24, "auUSDCNative": 6, "auUSDTNative": 6}
PRICE = {"auUSDC": 0.99961, "auETH": 2474.63, "auWBTC": 81727.37, "auUSDT": 0.99927,
         "auDAI": 1.00006, "auWNEAR": 4.52201, "auSTNEAR": 6.73006, "auAURORA": 0.058850,
         "auTRI": 0.00012557, "auPLY": 0.0, "auUSN": 0.0, "auNEARX": 5.24332,
         "auUSDCNative": 0.99961, "auUSDTNative": 0.99927}
CF = {"auUSDC": 0.80, "auETH": 0.70, "auWBTC": 0.60, "auUSDT": 0.75, "auDAI": 0.0,
      "auWNEAR": 0.60, "auSTNEAR": 0.40, "auAURORA": 0.40, "auTRI": 0.0, "auPLY": 0.0,
      "auUSN": 0.0, "auNEARX": 0.40, "auUSDCNative": 0.70, "auUSDTNative": 0.70}


def rpc_batch(calls):
    payload = json.dumps([{"jsonrpc": "2.0", "id": i, "method": "eth_call",
                           "params": [{"to": t, "data": d}, "latest"]}
                          for i, (t, d) in enumerate(calls)]).encode()
    req = urllib.request.Request(RPC, data=payload,
                                 headers={"Content-Type": "application/json", "User-Agent": "Mozilla/5.0"})
    for _ in range(4):
        try:
            out = json.load(urllib.request.urlopen(req, timeout=90))
            res = {}
            for item in out:
                res[item["id"]] = item.get("result") if "error" not in item else None
            return [res.get(i) for i in range(len(calls))]
        except Exception as e:
            print("retry", e, flush=True)
            time.sleep(3)
    return [None] * len(calls)


def enc_addr(a):
    return a.lower().replace("0x", "").rjust(64, "0")


def main():
    hs = json.load(open('/home/heisenberg/CA/aurigami/analysis/health_scan.json'))
    short = [a for a, r in hs.items() if isinstance(r.get('shortfall'), int) and r['shortfall'] > 0]
    print("accounts:", len(short), flush=True)
    detail = {}
    B = 20
    calls, meta = [], []
    for a in short:
        for name, m in MARKETS.items():
            calls.append((m, "0xc37f68e2" + enc_addr(a)))
            meta.append((a, name))
    for i in range(0, len(calls), B):
        outs = rpc_batch(calls[i:i + B])
        for (a, name), o in zip(meta[i:i + B], outs):
            if isinstance(o, str) and len(o) >= 194:
                tok = int(o[2:66], 16)
                bor = int(o[66:130], 16)
                er = int(o[130:194], 16)
                if tok or bor:
                    detail.setdefault(a, {})[name] = {"tokens": tok, "borrow": bor, "er": er}
        if i % 200 == 0:
            print(f"  {i}/{len(calls)}", flush=True)
    json.dump(detail, open('/home/heisenberg/CA/aurigami/analysis/shortfall_detail.json', 'w'), indent=1)

    print()
    print("== per-account position analysis (USD) ==")
    rows = []
    for a, mkts in detail.items():
        debt = 0.0
        coll = 0.0
        coll_cf = 0.0
        info = []
        for name, s in mkts.items():
            if s['borrow']:
                d = s['borrow'] / 10 ** DEC[name] * PRICE[name]
                debt += d
                info.append(f"debt {name}={s['borrow'] / 10 ** DEC[name]:.6f} (${d:.2f})")
            if s['tokens']:
                c = s['tokens'] * s['er'] / 1e18 / 10 ** DEC[name] * PRICE[name]
                coll += c
                coll_cf += c * CF[name]
                info.append(f"coll {name}={s['tokens']} (${c:.2f})")
        if debt > 0:
            rows.append((a, debt, coll, coll_cf, info))
    rows.sort(key=lambda r: -r[1])
    for a, debt, coll, ccf, info in rows[:25]:
        print(f"\n{a} debt=${debt:.2f} coll=${coll:.2f} coll*CF=${ccf:.2f} shortfall=${max(0, debt - ccf):.2f}")
        for s in info:
            print("   ", s)
    json.dump(rows, open('/home/heisenberg/CA/aurigami/analysis/shortfall_positions.json', 'w'), indent=1)


if __name__ == "__main__":
    main()
