#!/usr/bin/env python3
"""Arb step 2b: rebuild relevant markets from scans, fetch reserves + token meta.
Inputs: _pairs_scan.json (ubeswap), _markets_raw.json (sushi pairs)
Output: _markets_raw.json (rewritten with full data)
"""
import json, urllib.request, os, time

RPC = "https://forno.celo.org"
HERE = os.path.dirname(os.path.abspath(__file__))

WATCH = {a.lower() for a in [
    "0x765de816845861e75a25fca122bb6898b8b1282a","0xed193c4e69f591e42398ef54dea65aa1bb02835c",
    "0xb4aa2986622249b1f45eb93f28cfca2b2606d809","0xeadf4a7168a82d30ba0619e64d5bcf5b30b45226",
    "0x56072d4832642db29225da12d6fd1290e4744682","0xd8761dd6c7cb54febd33add699f5e4440b62e01b",
    "0xe74abf23e1fdf7acbec2f3a30a772ef77f1601e1","0x301a61d01a63c8d670c2b8a43f37d12ef181f997",
    "0x1bfc26ce035c368503fae319cc2596716428ca44","0x2a3684e9dc20b857375ea04235f2f7edbe818fa7",
    "0xb70e0a782b058bfdb0d109a3599bec1f19328e36","0xd629eb00deced2a080b7ec630ef6ac117e614f1b",
    "0xbaab46e28388d2779e6e31fd00cf0e5ad95e327b","0xbe50a3013a1c94768a1abb78c3cb79ab28fc1ace",
    "0x471ece3750da237f93b8e339c536989b8978a438","0xd8763cba276a3738e6de85b4b3bf5fded6d6ca73",
    "0x2def4285787d58a2f811af24755a8150622f4361","0x122013fd7df1c6f636a5bb8f03108e876548b455",
    "0x90ca507a5d4458a4c6c6249d186b6dcb02a5bccd","0x37f750b7cc259a2f741af45294f6a16572cf5cad",
    "0xef4229c8c3250c675f21bcefa42f58efbff6002a","0xdc5762753043327d74e0a538199c1488fc1f44cf",
    "0xcc82628f6a8defa1e2b0ad7ed448bef3647f7941","0xcd7d7ff64746c1909e44db8e95331f9316478817",
    "0xcfffe0c89a779c09df3df5624f54cdf7ef5fdd5d","0x93db49be12b864019da9cb147ba75cdc0506190e",
    "0xe919f65739c26a42616b7b8eedc6b5524d1e3ac4","0x48065fbbe25f71c9282ddf5e1cd6d6a887483d5e",
    "0xe8537a3d056da446677b9e9d6c5db7046f052ab8",
]}

SEL = {"token0()": "0x0dfe1681", "token1()": "0xd21220a7", "getReserves()": "0x0902f1ac",
       "symbol()": "0x95d89b41", "name()": "0x06fdde03", "decimals()": "0x313ce567"}


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


def main():
    ps = json.load(open(os.path.join(HERE, "_pairs_scan.json")))
    mr = json.load(open(os.path.join(HERE, "_markets_raw.json")))
    ube = ps["watch_pairs"]; sushi = mr.get("sushi_watch_pairs") or {}
    relevant = {}
    for p, info in ube.items():
        relevant[p] = dict(info, dex="ubeswap_v2")
    for p, info in sushi.items():
        relevant[p] = dict(info, dex="sushiswap_v2")

    calls, keys = [], []
    for p in relevant:
        calls.append(("eth_call", [{"to": p, "data": SEL["getReserves()"]}, "latest"])); keys.append((p, "res"))
    res = rpc_batch(calls)
    for (p, _), r in zip(keys, res):
        if r and len(r) >= 2 + 192:
            h = r[2:]
            relevant[p]["reserve0"] = str(int(h[0:64], 16))
            relevant[p]["reserve1"] = str(int(h[64:128], 16))

    unknown = set()
    for p, info in relevant.items():
        for t in (info.get("token0"), info.get("token1")):
            if t and t not in WATCH: unknown.add(t)
    calls, keys = [], []
    for t in sorted(unknown):
        for meta, sel in [("symbol", SEL["symbol()"]), ("name", SEL["name()"]), ("decimals", SEL["decimals()"])]:
            calls.append(("eth_call", [{"to": t, "data": sel}, "latest"])); keys.append((t, meta))
    res = rpc_batch(calls)
    umeta = {}
    for (t, meta), r in zip(keys, res):
        umeta.setdefault(t, {})[meta] = dec_str(r) if meta in ("symbol", "name") else dec_uint(r)

    out = dict(mr); out["markets"] = relevant; out["unknown_tokens"] = umeta
    with open(os.path.join(HERE, "_markets_raw.json"), "w") as f:
        json.dump(out, f, indent=1)
    print("markets:", len(relevant), "unknown:", len(umeta))
    for t, m in sorted(umeta.items()):
        print(" unknown", t, m)

    tgt = {
        "atUST": "0xed193c4e69f591e42398ef54dea65aa1bb02835c",
        "pUSD_b4aa": "0xb4aa2986622249b1f45eb93f28cfca2b2606d809",
        "pUSD_eadf": "0xeadf4a7168a82d30ba0619e64d5bcf5b30b45226",
        "pEUR_5607": "0x56072d4832642db29225da12d6fd1290e4744682",
        "pEUR_d876": "0xd8761dd6c7cb54febd33add699f5e4440b62e01b",
        "pCELO_e74a": "0xe74abf23e1fdf7acbec2f3a30a772ef77f1601e1",
        "pCELO_301a": "0x301a61d01a63c8d670c2b8a43f37d12ef181f997",
        "USDCold_1bfc": "0x1bfc26ce035c368503fae319cc2596716428ca44",
        "USDCet_2a36": "0x2a3684e9dc20b857375ea04235f2f7edbe818fa7",
        "aaUSDC_b70e": "0xb70e0a782b058bfdb0d109a3599bec1f19328e36",
        "BTC_d629": "0xd629eb00deced2a080b7ec630ef6ac117e614f1b",
        "WBTC_baab": "0xbaab46e28388d2779e6e31fd00cf0e5ad95e327b",
        "WBTCold_be50": "0xbe50a3013a1c94768a1abb78c3cb79ab28fc1ace",
    }
    print("\n=== target token pairs ===")
    for name, addr in tgt.items():
        print(f"-- {name}")
        for p, info in sorted(relevant.items()):
            if addr in (info.get("token0"), info.get("token1")):
                other = info["token1"] if info["token0"] == addr else info["token0"]
                om = umeta.get(other, {})
                osym = om.get("symbol")
                print(f"   {info['dex']} {p} r0={info.get('reserve0')} r1={info.get('reserve1')} other={other} ({osym})")


if __name__ == "__main__":
    main()
