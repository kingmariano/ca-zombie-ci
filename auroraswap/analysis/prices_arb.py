#!/usr/bin/env python3
"""Identify tokens in the AuroraSwap factory, fetch DefiLlama prices, compute
implied pool prices and rough arb-profit estimates vs market. Read-only."""
import json
import os
import time
import urllib.request

RPC = os.environ.get("AURORA_RPC", "https://mainnet.aurora.dev")
BASE = os.path.dirname(__file__)

SEL = {
    "symbol": "0x95d89b41",
    "decimals": "0x313ce567",
    "totalSupply": "0x18160ddd",
    "balanceOf": "0x70a08231",
}


def rpc(method, params, rpc_url=RPC):
    payload = {"jsonrpc": "2.0", "id": 1, "method": method, "params": params}
    req = urllib.request.Request(
        rpc_url,
        data=json.dumps(payload).encode(),
        headers={"Content-Type": "application/json", "User-Agent": "Mozilla/5.0"},
    )
    for attempt in range(5):
        try:
            with urllib.request.urlopen(req, timeout=40) as r:
                out = json.load(r)
            if "result" in out:
                return out["result"]
        except Exception:  # noqa: BLE001
            pass
        time.sleep(1 + 2 * attempt)
    return None


def rpc_batch(calls, block="latest", chunk=50):
    results = []
    for i in range(0, len(calls), chunk):
        part = calls[i : i + chunk]
        payload = [
            {"jsonrpc": "2.0", "id": j, "method": "eth_call", "params": [{"to": to, "data": data}, block]}
            for j, (to, data) in enumerate(part)
        ]
        req = urllib.request.Request(
            RPC,
            data=json.dumps(payload).encode(),
            headers={"Content-Type": "application/json", "User-Agent": "Mozilla/5.0"},
        )
        out = None
        for attempt in range(5):
            try:
                with urllib.request.urlopen(req, timeout=60) as r:
                    out = json.load(r)
                break
            except Exception:  # noqa: BLE001
                time.sleep(1 + 2 * attempt)
        if out is None:
            raise RuntimeError("batch fail")
        by_id = {item["id"]: item.get("result") for item in out}
        results.extend(by_id.get(j) for j in range(len(part)))
        time.sleep(0.15)
    return results


def dec_str(hexstr):
    if not hexstr or hexstr == "0x":
        return None
    b = bytes.fromhex(hexstr[2:])
    if len(b) < 64:
        return None
    try:
        off = int.from_bytes(b[0:32], "big")
        ln = int.from_bytes(b[off : off + 32], "big")
        return b[off + 32 : off + 32 + ln].decode("utf-8", "replace")
    except Exception:  # noqa: BLE001
        return None


def dec_uint(hexstr):
    if not hexstr or hexstr == "0x":
        return None
    return int(hexstr, 16)


def main():
    scan = json.load(open(os.path.join(BASE, "pairs_scan.json")))
    block = scan["block"]
    toks = set()
    for p in scan["pairs"]:
        toks.add(p["token0"])
        toks.add(p["token1"])
    toks = sorted(toks)
    print(f"distinct tokens: {len(toks)}")

    calls = []
    for t in toks:
        calls += [(t, SEL["symbol"]), (t, SEL["decimals"]), (t, SEL["totalSupply"])]
    res = rpc_batch(calls, hex(block))
    meta = {}
    for i, t in enumerate(toks):
        sym = dec_str(res[i * 3])
        dec = dec_uint(res[i * 3 + 1])
        ts = dec_uint(res[i * 3 + 2])
        meta[t] = {"symbol": sym, "decimals": dec, "totalSupply": ts}
    json.dump(meta, open(os.path.join(BASE, "tokens_meta.json"), "w"), indent=1)

    # DefiLlama prices
    ids = ",".join(f"aurora:{t}" for t in toks)
    ids += ",coingecko:ethereum,coingecko:near,coingecko:tether,coingecko:usd-coin,coingecko:aurora-near"
    try:
        req = urllib.request.Request(
            f"https://coins.llama.fi/prices/current/{ids}",
            headers={"User-Agent": "Mozilla/5.0"},
        )
        with urllib.request.urlopen(req, timeout=60) as r:
            prices = json.load(r)["coins"]
    except Exception as e:  # noqa: BLE001
        print("llama fail", e)
        prices = {}
    json.dump(prices, open(os.path.join(BASE, "prices.json"), "w"), indent=1)

    def price_of(tok):
        for k, v in prices.items():
            if k.lower() == f"aurora:{tok}".lower():
                return v.get("price")
        return None

    # implied prices + arb estimate
    out = []
    for p in scan["pairs"]:
        t0, t1 = p["token0"], p["token1"]
        m0, m1 = meta.get(t0, {}), meta.get(t1, {})
        d0, d1 = m0.get("decimals"), m1.get("decimals")
        if d0 is None or d1 is None:
            continue
        a0 = p["reserve0"] / 10**d0
        a1 = p["reserve1"] / 10**d1
        px0, px1 = price_of(t0), price_of(t1)
        row = {
            "pair": p.get("pair"),
            "token0": t0,
            "sym0": m0.get("symbol"),
            "token1": t1,
            "sym1": m1.get("symbol"),
            "res0": a0,
            "res1": a1,
            "px0": px0,
            "px1": px1,
            "totalSupply": p["totalSupply"],
            "kLast": p["kLast"],
            "excess0": p["excess0"],
            "excess1": p["excess1"],
            "reserveValueUsd": None,
        }
        if px0 is not None and px1 is not None and a0 > 0 and a1 > 0:
            # pool price of token0 in token1
            pool_p0_in_t1 = a1 / a0
            mkt_p0_in_t1 = px0 / px1
            row["pool_price0_in_1"] = pool_p0_in_t1
            row["mkt_price0_in_1"] = mkt_p0_in_t1
            row["deviation_pct"] = (pool_p0_in_t1 / mkt_p0_in_t1 - 1) * 100
            row["reserveValueUsd"] = a0 * px0 + a1 * px1
        out.append(row)

    out.sort(key=lambda r: -(r["reserveValueUsd"] or 0))
    json.dump(out, open(os.path.join(BASE, "pairs_priced.json"), "w"), indent=1)
    print(f"{'pair':<45}{'sym0':<10}{'sym1':<10}{'value$':>12}{'dev%':>10}")
    for r in out[:40]:
        v = r["reserveValueUsd"]
        dv = r.get("deviation_pct")
        print(
            f"{str(r['pair']):<45}{str(r['sym0'])[:9]:<10}{str(r['sym1'])[:9]:<10}"
            f"{(f'{v:,.0f}' if v else '-'):>12}{(f'{dv:+.2f}' if dv is not None else '-'):>10}"
        )
    # unpriced tokens with meaningful raw balances
    print("\nunpriced tokens with largest balance-side value unknown:")
    for r in out:
        if r["px0"] is None and r["res0"] > 0:
            pass
    # print junk token metas
    for t in ["0xe24c7f50a9f514db6ccf151ff9a9411de2110740", "0xb9636d074c3e8550449feba3be63fe95a582e876",
              "0x631edd14bb0b2505c91176feedc5f082d27dd5b8", "0xc4bdd27c33ec7daa6fcfd8532ddb524bf4038096",
              "0x12c87331f086c3c926248f964f8702c0842fd77f"]:
        print("META", t, meta.get(t))


if __name__ == "__main__":
    main()
