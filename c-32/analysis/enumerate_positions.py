#!/usr/bin/env python3
"""
Find every account that ever borrowed on a chain (Covalent topic endpoint, full history),
check live Comptroller shortfall, and (for shortfall accounts) measure exact liquidation
proceeds per market using on-chain reads.

Dependency-free. Requires GOLD_RUSH_API_KEY. Read-only.
Usage: python3 enumerate_positions.py <moonbeam|moonriver> [--max-block N]
Output: out/<chain>_positions.json
"""
import json, os, sys, time, urllib.request, urllib.error

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.environ.get("SCAN_OUTDIR", os.path.join(HERE, "out"))
os.makedirs(OUT, exist_ok=True)
KEY = os.environ.get("GOLD_RUSH_API_KEY", "")
GR = "https://api.covalenthq.com/v1"
CHUNK = 1_000_000

SEL = {
 "getAllMarkets()": "0xb0772d0b",
 "getAccountLiquidity(address)": "0x5ec88c79",
 "getAssetsIn(address)": "0xabfceffc",
 "oracle()": "0x7dc0d1d0",
 "markets(address)": "0x8e8f294b",
 "getUnderlyingPrice(address)": "0xfc57d4df",
 "balanceOf(address)": "0x70a08231",
 "borrowBalanceStored(address)": "0x95dd9193",
 "decimals()": "0x313ce567",
 "underlying()": "0x6f307dc3",
 "symbol()": "0x95d89b41",
 "exchangeRateStored()": "0x182df0f5",
 "getCash()": "0x3b1d21a2",
 "totalBorrows()": "0x47bd3718",
 "closeFactorMantissa()": "0xe8755446",
 "liquidationIncentiveMantissa()": "0x4ada90af",
}

CHAINS = {
  "moonbeam": {"id": 1284, "rpc_env": "MOONBEAM_RPC_URL", "rpc_fallback": "https://moonbeam.api.onfinality.io/public",
               "comptroller": "0x8E00D5e02E65A19337Cdba98bbA9F84d4186a180"},
  "moonriver": {"id": 1285, "rpc_env": "MOONRIVER_RPC_URL", "rpc_fallback": "https://moonriver.api.onfinality.io/public",
                "comptroller": "0x0b7a0EAA884849c6Af7a129e899536dDDcA4905E"},
}

BORROW_TOPIC = "0x13ed6866d4e1ee6da46f845c46d7e54120883d75c5ea9a2dacc1c4ca8984ab80"


def http_json(url, timeout=60, retries=4):
    last = None
    for i in range(retries):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0 c32"})
            with urllib.request.urlopen(req, timeout=timeout) as r:
                return json.loads(r.read().decode())
        except urllib.error.HTTPError as e:
            try:
                return json.loads(e.read().decode())
            except Exception:
                last = e
                time.sleep(1.5 * (i + 1))
        except Exception as e:
            last = e
            time.sleep(2 * (i + 1))
    raise RuntimeError(f"http failed: {url[:140]} {last}")


def rpc_batch(rpc, calls):
    payload = []
    for k, (to, data) in enumerate(calls):
        payload.append({"jsonrpc": "2.0", "id": k + 1, "method": "eth_call",
                        "params": [{"to": to, "data": data}, "latest"]})
    req = urllib.request.Request(rpc, data=json.dumps(payload).encode(),
                                 headers={"Content-Type": "application/json", "User-Agent": "Mozilla/5.0 c32"})
    for i in range(4):
        try:
            with urllib.request.urlopen(req, timeout=60) as r:
                out = json.loads(r.read().decode())
            m = {x["id"]: x.get("result") for x in out}
            return [m.get(k + 1) for k in range(len(calls))]
        except Exception:
            time.sleep(2 * (i + 1))
    return [None] * len(calls)


def rpc_single(rpc, to, data):
    return rpc_batch(rpc, [(to, data)])[0]


def block_number(rpc):
    req = urllib.request.Request(rpc, data=json.dumps({"jsonrpc": "2.0", "id": 1, "method": "eth_blockNumber", "params": []}).encode(),
                                 headers={"Content-Type": "application/json", "User-Agent": "Mozilla/5.0 c32"})
    with urllib.request.urlopen(req, timeout=45) as r:
        return int(json.loads(r.read().decode())["result"], 16)


def all_borrow_events(chain_id, end):
    """All Borrow events via topic endpoint, chunked <=1M blocks, with pagination."""
    events = []
    start = 1
    while start <= end:
        stop = min(start + CHUNK - 1, end)
        page = 0
        while True:
            url = (f"{GR}/{chain_id}/events/topics/{BORROW_TOPIC}/?starting-block={start}&ending-block={stop}"
                   f"&page-size=1000&page-number={page}&key={KEY}")
            d = http_json(url)
            if d.get("error"):
                msg = d.get("error_message") or ""
                if "has not yet been reached" in msg and stop - start > 2000:
                    stop -= 1000
                    print(f"    [warn] adjusting chunk end -> {stop} ({msg})")
                    continue
                print(f"    [warn] {start}-{stop} p{page}: {msg}")
                break
            data = d["data"]
            items = data.get("items") or []
            for it in items:
                dec = it.get("decoded") or {}
                params = {p.get("name"): p.get("value") for p in (dec.get("params") or [])}
                events.append({
                    "block": it.get("block_height"),
                    "market": (it.get("sender_address") or "").lower(),
                    "borrower": (params.get("borrower") or "").lower(),
                    "amount": params.get("borrowAmount"),
                })
            if not data.get("pagination", {}).get("has_more"):
                break
            page += 1
            if page > 200:
                break
        print(f"    chunk {start}-{stop}: cumulative events {len(events)}", flush=True)
        start = stop + 1
    return events


def hx(a):
    return a.lower().replace("0x", "").rjust(64, "0")


def parse_u(h):
    return int(h, 16) if h and h != "0x" else None


def main():
    chain = sys.argv[1]
    cfg = CHAINS[chain]
    rpc = os.environ.get(cfg["rpc_env"]) or cfg["rpc_fallback"]
    end = block_number(rpc)
    for i, a in enumerate(sys.argv):
        if a == "--max-block":
            end = int(sys.argv[i + 1])
    comp = cfg["comptroller"]
    print(f"{chain}: latest block {end}, comptroller {comp}", flush=True)

    raw = rpc_single(rpc, comp, SEL["getAllMarkets()"])
    raw = raw[2:]
    n = int(raw[64:128], 16)
    markets = ["0x" + raw[(2 + i) * 64 + 24:(2 + i) * 64 + 64] for i in range(n)]

    print("  fetching all Borrow events...", flush=True)
    evs = all_borrow_events(cfg["id"], end)
    borrowers = sorted({e["borrower"] for e in evs if e["borrower"]})
    print(f"  total borrow events {len(evs)}, unique borrowers {len(borrowers)}", flush=True)

    # global risk params
    g = rpc_batch(rpc, [(comp, SEL["closeFactorMantissa()"]),
                        (comp, SEL["liquidationIncentiveMantissa()"])])
    close_factor = parse_u(g[0]) / 1e18 if g[0] else None
    liq_inc = parse_u(g[1]) / 1e18 if g[1] else None

    # market metadata (symbol, underlying, decimals, oracle price, cash, exchange rate)
    meta = {}
    for m in markets:
        s = rpc_single(rpc, m, SEL["symbol()"])
        ms = bytes.fromhex(s[2:])[64:64 + int.from_bytes(bytes.fromhex(s[2:])[32:64], "big")].decode(errors="replace") if s else "?"
        u = rpc_single(rpc, m, SEL["underlying()"])
        under = None
        if u and u != "0x":
            under = "0x" + u[-40:]
        sym = None
        dec = None
        if under:
            r = rpc_batch(rpc, [(under, SEL["symbol()"]), (under, SEL["decimals()"])])
            sym = bytes.fromhex(r[0][2:])[64:64 + int.from_bytes(bytes.fromhex(r[0][2:])[32:64], "big")].decode(errors="replace") if r[0] else None
            dec = parse_u(r[1])
        else:
            sym = ms[1:] if ms.startswith("m") else ms
            dec = 18
        p = rpc_batch(rpc, [(m, SEL["exchangeRateStored()"]), (m, SEL["getCash()"]), (m, SEL["totalBorrows()"])])
        meta[m] = {"symbol": ms, "underlying": under, "underlying_symbol": sym,
                   "decimals": dec, "exchange_rate": parse_u(p[0]), "cash": parse_u(p[1]),
                   "total_borrows": parse_u(p[2])}

    # oracle per market
    oracle = rpc_single(rpc, comp, SEL["oracle()"])
    oracle = "0x" + oracle[-40:]
    for m in markets:
        pr = rpc_single(rpc, oracle, SEL["getUnderlyingPrice(address)"] + hx(m))
        meta[m]["oracle_price"] = parse_u(pr)

    # liquidity check for all borrowers
    checked = {}
    for i in range(0, len(borrowers), 25):
        chunk = borrowers[i:i + 25]
        calls = [(comp, SEL["getAccountLiquidity(address)"] + hx(a)) for a in chunk]
        res = rpc_batch(rpc, calls)
        for a, r in zip(chunk, res):
            liq = sf = None
            if r and len(r) >= 194:
                liq = int(r[2:66], 16)
                sf = int(r[130:194], 16)
            checked[a] = {"liquidity": liq, "shortfall": sf}
        time.sleep(0.2)

    shortfalls = [a for a, v in checked.items() if v["shortfall"] and v["shortfall"] > 0]
    print(f"  accounts with live shortfall: {len(shortfalls)}", flush=True)

    # detail for shortfall accounts
    details = {}
    for a in shortfalls[:600]:
        row = {"account": a, "borrows": {}, "collaterals": {}, "shortfall": checked[a]["shortfall"]}
        calls = []
        for m in markets:
            calls.append((m, SEL["borrowBalanceStored(address)"] + hx(a)))
            calls.append((m, SEL["balanceOf(address)"] + hx(a)))
        res = rpc_batch(rpc, calls)
        for j, m in enumerate(markets):
            bb = parse_u(res[j * 2])
            bal = parse_u(res[j * 2 + 1])
            if bb:
                row["borrows"][m] = bb
            if bal:
                row["collaterals"][m] = bal
        details[a] = row

    out = {"chain": chain, "latest_block": end, "comptroller": comp, "oracle": oracle,
           "close_factor": close_factor, "liquidation_incentive": liq_inc,
           "markets": meta, "total_borrow_events": len(evs), "unique_borrowers": len(borrowers),
           "checked": checked, "shortfall_accounts": shortfalls, "details": details}
    p = os.path.join(OUT, f"{chain}_positions.json")
    with open(p, "w") as f:
        json.dump(out, f, indent=1)
    print("wrote", p)


if __name__ == "__main__":
    main()
