#!/usr/bin/env python3
"""Price + rank live Balancer V2 pools from scan_chain.py output.

- Fetches token symbol/decimals via batched eth_call.
- Fetches USD prices from DefiLlama coins API.
- Computes per-pool non-BPT value, flags CSPs with rate providers / Linear / MetaStable.
Writes pool-table-<chain>.csv and prints the top candidates.
"""
import json, sys, time, urllib.request, urllib.parse, csv, os

CHAIN_LLAMA = {
    "ethereum": "ethereum", "arbitrum": "arbitrum", "polygon": "polygon",
    "base": "base", "optimism": "optimism", "gnosis": "gnosis",
    "avalanche": "avalanche", "mode": "mode", "fraxtal": "fraxtal",
}
SEL_SYMBOL = "0x95d89b41"
SEL_DECIMALS = "0x313ce567"


def rpc_batch(url, calls, chunk=25):
    out = []
    for i in range(0, len(calls), chunk):
        part = calls[i:i + chunk]
        payload = [{"jsonrpc": "2.0", "id": j, "method": m, "params": p}
                   for j, (m, p) in enumerate(part)]
        body = json.dumps(payload).encode()
        for attempt in range(4):
            try:
                req = urllib.request.Request(url, data=body, headers={
                    "Content-Type": "application/json", "User-Agent": "Mozilla/5.0 bal-scan"})
                with urllib.request.urlopen(req, timeout=60) as r:
                    res = json.load(r)
                break
            except Exception:
                time.sleep(1 + attempt)
        else:
            raise RuntimeError("rpc batch failed")
        by_id = {x.get("id"): x for x in res}
        for j in range(len(part)):
            x = by_id.get(j, {})
            out.append(x.get("result") if "result" in x else None)
        time.sleep(0.03)
    return out


def decode_string(hexstr):
    if not hexstr or hexstr == "0x":
        return None
    h = hexstr[2:]
    try:
        if len(h) >= 128:
            off = int(h[0:64], 16) * 2
            ln = int(h[off:off + 64], 16)
            data = h[off + 64: off + 64 + ln * 2]
            return bytes.fromhex(data).decode("utf-8", "replace")
        # bytes32 symbol
        return bytes.fromhex(h[:64]).decode("utf-8", "replace").strip("\x00")
    except Exception:
        return None


def main():
    chain = sys.argv[1]
    rpc = sys.argv[2]
    path = sys.argv[3]
    d = json.load(open(path))
    pools = d["pools"]

    # distinct tokens
    tokens = set()
    for p in pools:
        for t, b in zip(p["tokens"], p["balances"]):
            if b > 0:
                tokens.add(t)
    tokens = sorted(tokens)
    print(f"{chain}: {len(tokens)} distinct tokens with balances")

    # symbols/decimals
    calls = []
    for t in tokens:
        calls.append(("eth_call", [{"to": t, "data": SEL_SYMBOL}, "latest"]))
        calls.append(("eth_call", [{"to": t, "data": SEL_DECIMALS}, "latest"]))
    res = rpc_batch(rpc, calls, chunk=50)
    meta = {}
    for i, t in enumerate(tokens):
        sym = decode_string(res[2 * i])
        dec = int(res[2 * i + 1], 16) if res[2 * i + 1] and res[2 * i + 1] != "0x" else None
        meta[t] = {"symbol": sym, "decimals": dec}
    # fix tokens whose symbol() failed: check name() maybe; leave as None
    # prices
    llama = CHAIN_LLAMA.get(chain, chain)
    prices = {}
    addrs = [t for t in tokens if meta[t]["decimals"] is not None]
    for i in range(0, len(addrs), 40):
        batch = addrs[i:i + 40]
        key = ",".join(f"{llama}:{a}" for a in batch)
        url = "https://coins.llama.fi/prices/current/" + urllib.parse.quote(key, safe=":,")
        for attempt in range(3):
            try:
                with urllib.request.urlopen(urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"}), timeout=45) as r:
                    pd = json.load(r)
                break
            except Exception:
                time.sleep(2)
        else:
            pd = {"coins": {}}
        for k, v in pd.get("coins", {}).items():
            addr = k.split(":")[-1]
            prices[addr.lower()] = v.get("price")
        time.sleep(0.3)

    rows = []
    for p in pools:
        pool_addr = p["address"].lower()
        pr = p.get("probe") or {}
        rates = [r for r in (pr.get("rateProviders") or []) if r != "0x0000000000000000000000000000000000000000"]
        usd = 0.0
        missing = []
        for t, b in zip(p["tokens"], p["balances"]):
            if t.lower() == pool_addr:
                continue  # BPT
            m = meta.get(t, {})
            dec = m.get("decimals")
            if dec is None:
                missing.append(t)
                continue
            px = prices.get(t.lower())
            if px is None:
                missing.append(t)
                continue
            usd += (b / 10 ** dec) * px
        rows.append({
            "chain": chain,
            "pool": p["address"],
            "type": p.get("type"),
            "usd_non_bpt": round(usd, 2),
            "rates": ";".join(rates),
            "n_rates": len(rates),
            "recovery": pr.get("recoveryMode"),
            "swap_fee": pr.get("swapFee"),
            "bpt_index": pr.get("bptIndex"),
            "supply": pr.get("totalSupply"),
            "tokens": ";".join(f"{t}:{meta.get(t,{}).get('symbol')}:{b}" for t, b in zip(p["tokens"], p["balances"])),
            "missing_prices": ";".join(missing),
        })
    rows.sort(key=lambda r: -r["usd_non_bpt"])
    outcsv = f"pool-table-{chain}.csv"
    with open(outcsv, "w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=list(rows[0].keys()))
        w.writeheader()
        w.writerows(rows)
    print(f"wrote {outcsv}")
    print("\nTop 25 by non-BPT USD:")
    for r in rows[:25]:
        flag = "CSP+rates" if r["type"] == "ComposableStable" and r["n_rates"] > 0 else r["type"]
        print(f"  ${r['usd_non_bpt']:>12,.2f} {flag:14s} rec={str(r['recovery'])[:5]:5s} {r['pool']} rates={r['n_rates']}")


if __name__ == "__main__":
    main()
