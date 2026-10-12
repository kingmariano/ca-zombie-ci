#!/usr/bin/env python3
"""Arb research step 2: scan Sushi factory, identify unknown tokens, fetch reserves of all relevant Ubeswap+Sushi pairs.
Outputs: analysis/_markets_raw.json
"""
import json, urllib.request, os, time

RPC = "https://forno.celo.org"
HERE = os.path.dirname(os.path.abspath(__file__))

FAC_UBE = "0x62d5b84be28a183abb507e125b384122d2c25fae"
FAC_SUSHI = "0xc35dadb65012ec5796536bd9864ed8773abc74c4"

SEL = {
    "allPairsLength()": "0x574f2ba3",
    "allPairs(uint256)": "0x1e3dd18b",
    "token0()": "0x0dfe1681",
    "token1()": "0xd21220a7",
    "getReserves()": "0x0902f1ac",
    "symbol()": "0x95d89b41",
    "name()": "0x06fdde03",
    "decimals()": "0x313ce567",
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
                for j in range(len(chunk)):
                    it = by_id.get(j)
                    out.append(it.get("result") if it and "result" in it else None)
                break
            except Exception as e:
                last = e
                time.sleep(1 + t)
        else:
            raise RuntimeError(f"rpc failed: {last}")
    return out


def a(h):
    return "0x" + h[2:][-40:].lower() if h else None


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


def main():
    prev = json.load(open(os.path.join(HERE, "_pairs_scan.json")))
    watch = {x for x in prev["watch"]}
    out = {"block_start": None, "sushi_pairs": {}, "markets": {}, "unknown_tokens": {}}

    # ---- Sushi factory scan ----
    n = 257
    calls = [(SEL["allPairs(uint256)"], )
             for _ in range(1)]
    calls = [("eth_call", [{"to": FAC_SUSHI, "data": SEL["allPairs(uint256)"] + hex(i)[2:].rjust(64, "0")}, "latest"]) for i in range(n)]
    pairs = [a(x) for x in rpc_batch(calls, batch=60)]
    calls = []
    for p in pairs:
        if not p:
            continue
        calls.append(("eth_call", [{"to": p, "data": SEL["token0()"]}, "latest"]))
        calls.append(("eth_call", [{"to": p, "data": SEL["token1()"]}, "latest"]))
    toks = rpc_batch(calls, batch=100)
    sushi = {}
    for i, p in enumerate([x for x in pairs if x]):
        t0, t1 = a(toks[2 * i]), a(toks[2 * i + 1])
        sushi[p] = {"token0": t0, "token1": t1}
    out["sushi_pairs"] = sushi

    # ---- relevant pairs: Ubeswap watch pairs + Sushi pairs touching watchlist ----
    relevant = {}
    for p, info in prev["watch_pairs"].items():
        relevant[p] = dict(info, dex="ubeswap_v2")
    sushi_hits = {}
    for p, info in sushi.items():
        if info["token0"] in watch or info["token1"] in watch:
            relevant[p] = dict(info, dex="sushiswap_v2")
            sushi_hits[p] = info
    out["sushi_watch_pairs"] = sushi_hits
    print("sushi pairs:", len(sushi), "sushi hits:", len(sushi_hits), "total relevant:", len(relevant))

    # ---- fetch reserves + token meta for relevant pairs ----
    calls = []
    keys = []
    for p in relevant:
        calls.append(("eth_call", [{"to": p, "data": SEL["getReserves()"]}, "latest"]))
        keys.append((p, "reserves"))
    res = rpc_batch(calls, batch=60)
    for (p, k), r in zip(keys, res):
        if r and len(r) >= 2 + 64 * 3:
            h = r[2:]
            relevant[p]["reserve0"] = str(int(h[0:64], 16))
            relevant[p]["reserve1"] = str(int(h[64:128], 16))
            relevant[p]["blockTimestampLast"] = int(h[128:192], 16)
    # meta for unknown tokens
    unknown = set()
    for p, info in relevant.items():
        for t in (info["token0"], info["token1"]):
            if t and t not in watch:
                unknown.add(t)
    # also token addresses inside watchlist not in tokens.json? fetch meta for all unknown
    calls = []
    keys = []
    for t in sorted(unknown):
        for meta, sel in [("symbol", SEL["symbol()"]), ("name", SEL["name()"]), ("decimals", SEL["decimals()"])]:
            calls.append(("eth_call", [{"to": t, "data": sel}, "latest"]))
            keys.append((t, meta))
    res = rpc_batch(calls, batch=60)
    for (t, meta), r in zip(keys, res):
        out["unknown_tokens"].setdefault(t, {})[meta] = dec_str(r) if meta in ("symbol", "name") else dec_uint(r)
    for t, m in out["unknown_tokens"].items():
        print("unknown token", t, m)

    # resolve dangling token0/1 in watch pairs list too (skip; covered)
    out["block_end"] = int(rpc_batch([("eth_blockNumber", [])])[0], 16)
    with open(os.path.join(HERE, "_markets_raw.json"), "w") as f:
        json.dump(out, f, indent=1)
    print("wrote _markets_raw.json; block", out["block_end"])

    # print human overview of relevant pairs w/ reserves
    print("\nRELEVANT PAIRS WITH RESERVES:")
    for p, info in sorted(relevant.items()):
        print(f"{info['dex'][:5]} {p} t0={info['token0']} r0={info.get('reserve0')} t1={info['token1']} r1={info.get('reserve1')}")


if __name__ == "__main__":
    main()
