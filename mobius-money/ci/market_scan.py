#!/usr/bin/env python3
"""Full DEX market scan for all Mobius-pool tokens.
Scans every pair of the Ubeswap V2 factory (and a few other Celo factories if present)
and reports all pairs touching Mobius-pool tokens, with reserves.
Read-only; keyless public RPCs. Output: ci-out/market-scan.json
"""
import json, os, time, urllib.request
from concurrent.futures import ThreadPoolExecutor, as_completed

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
OUT = os.path.join(ROOT, "ci-out")
os.makedirs(OUT, exist_ok=True)

RPCS = ["https://forno.celo.org", "https://celo-rpc.publicnode.com",
        "https://rpc.ankr.com/celo", "https://celo.drpc.org"]

FACTORIES = [
    ("ubeswap_v2", "0x62d5b84bE28a183aBB507E125B384122D2C25fAE"),
]

# tokens of interest: every token seen in Mobius pools + LP tokens + MOBI + rstCELO etc.
INTEREST = set(t.lower() for t in [
    "0x765de816845861e75a25fca122bb6898b8b1282a", "0x471ece3750da237f93b8e339c536989b8978a438",
    "0x2def4285787d58a2f811af24755a8150622f4361", "0x122013fd7df1c6f636a5bb8f03108e876548b455",
    "0x9906589ea8fd27504974b7e8201df5bbde986b03", "0xef4229c8c3250c675f21bcefa42f58efbff6002a",
    "0x90ca507a5d4458a4c6c6249d186b6dcb02a5bccd", "0xd629eb00deced2a080b7ec630ef6ac117e614f1b",
    "0xbaab46e28388d2779e6e31fd00cf0e5ad95e327b", "0x1bfc26ce035c368503fae319cc2596716428ca44",
    "0x2a3684e9dc20b857375ea04235f2f7edbe818fa7", "0xb70e0a782b058bfdb0d109a3599bec1f19328e36",
    "0xeadf4a7168a82d30ba0619e64d5bcf5b30b45226", "0x301a61d01a63c8d670c2b8a43f37d12ef181f997",
    "0xcd7d7ff64746c1909e44db8e95331f9316478817", "0xcfffe0c89a779c09df3df5624f54cdf7ef5fdd5d",
    "0xed193c4e69f591e42398ef54dea65aa1bb02835c", "0xbe50a3013a1c94768a1abb78c3cb79ab28fc1ace",
    "0xcc82628f6a8defa1e2b0ad7ed448bef3647f7941", "0xdc5762753043327d74e0a538199c1488fc1f44cf",
    "0x93db49be12b864019da9cb147ba75cdc0506190e", "0xe919f65739c26a42616b7b8eedc6b5524d1e3ac4",
    "0xd8763cba276a3738e6de85b4b3bf5fded6d6ca73", "0xd8761dd6c7cb54febd33add699f5e4440b62e01b",
    "0x56072d4832642db29225da12d6fd1290e4744682", "0xe74abf23e1fdf7acbec2f3a30a772ef77f1601e1",
    "0x37f750b7cc259a2f741af45294f6a16572cf5cad", "0xb4aa2986622249b1f45eb93f28cfca2b2606d809",
    "0x73a210637f6f6b7005512677ba6b3c96bb4aa44b", "0xc668583dcbd9ae6fa3ce46462758188adfdfc24",
])
# also LP tokens of mobius pools (from live-state if present)
try:
    st = json.load(open(os.path.join(ROOT, "analysis", "live-state.json")))
    for e in st["pools"].values():
        for t in e.get("tokens") or []:
            INTEREST.add(t.lower())
        if e.get("lpToken"):
            INTEREST.add(e["lpToken"].lower())
except Exception as e:
    print("live-state read:", e)

_count = {"i": 0}


def rpc(method, params, tries=8):
    body = json.dumps({"jsonrpc": "2.0", "id": 1, "method": method, "params": params}).encode()
    last = None
    for i in range(tries):
        u = RPCS[i % len(RPCS)]
        try:
            req = urllib.request.Request(u, data=body, headers={"Content-Type": "application/json",
                                                                "User-Agent": "Mozilla/5.0 (research; read-only)"})
            with urllib.request.urlopen(req, timeout=45) as r:
                d = json.loads(r.read().decode())
            if "result" in d:
                return d["result"]
            last = d.get("error")
        except Exception as e:
            last = e
        time.sleep(0.4 + 0.3 * i)
    raise RuntimeError(f"rpc failed: {method} {params}: {last}")


def call(to, data):
    return rpc("eth_call", [{"to": to, "data": data}, "latest"])


def dec_addr(s):
    if not isinstance(s, str) or len(s) < 42:
        return None
    return "0x" + s[2:][24:64]


def main():
    block = int(rpc("eth_blockNumber", []), 16)
    report = {"generated": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()), "block": block,
              "factories": {}, "pairs": []}
    for name, fac in FACTORIES:
        code = rpc("eth_getCode", [fac, "latest"])
        if code in ("0x", "0x0"):
            report["factories"][name] = {"address": fac, "exists": False}
            continue
        n = int(call(fac, "0x574f2ba3"), 16)  # allPairsLength()
        report["factories"][name] = {"address": fac, "exists": True, "pairs": n}
        print(f"{name}: {n} pairs")

        def scan(i):
            p = dec_addr(call(fac, "0x1e3dd18b" + hex(i)[2:].rjust(64, "0")))  # allPairs(uint)
            try:
                t0 = dec_addr(call(p, "0x0dfe1681"))  # token0()
                t1 = dec_addr(call(p, "0xd21220a7"))  # token1()
            except Exception:
                return None
            if t0 and t1 and (t0.lower() in INTEREST or t1.lower() in INTEREST):
                r = call(p, "0x0902f1ac")  # getReserves()
                r0 = int(r[2:66], 16)
                r1 = int(r[66:130], 16)
                ts = int(r[130:194], 16)
                return {"pair": p, "token0": t0, "token1": t1, "reserve0": r0, "reserve1": r1, "ts": ts}
            return None

        found = []
        with ThreadPoolExecutor(max_workers=12) as ex:
            futs = [ex.submit(scan, i) for i in range(n)]
            for k, f in enumerate(as_completed(futs)):
                v = f.result()
                if v:
                    found.append(v)
                if k and k % 200 == 0:
                    print(f"  ..{k}/{n}")
        report["pairs"].extend(found)
        print(f"  matched pairs: {len(found)}")
    with open(os.path.join(OUT, "market-scan.json"), "w") as f:
        json.dump(report, f, indent=1)
    print("wrote market-scan.json")


if __name__ == "__main__":
    main()
