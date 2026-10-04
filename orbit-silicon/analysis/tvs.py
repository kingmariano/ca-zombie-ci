#!/usr/bin/env python3
"""Resolve wrapped-token origins on Silicon bridge and price the canonically-bridged set."""
import json, urllib.request, time

SILICON = "https://rpc.silicon.network"
BRIDGE = "0x2a3DD3EB832aF982ec71669E178424b10Dca2EDe"

def rpc(method, params, url=SILICON, timeout=30):
    for attempt in range(3):
        try:
            req = urllib.request.Request(url, data=json.dumps({"jsonrpc":"2.0","method":method,"params":params,"id":1}).encode(),
                                         headers={"Content-Type":"application/json","User-Agent":"Mozilla/5.0"})
            return json.load(urllib.request.urlopen(req, timeout=timeout))["result"]
        except Exception as e:
            err = e; time.sleep(1)
    raise err

def call(to, data):
    return rpc("eth_call", [{"to": to, "data": data}, "latest"])

def u(r):
    return int(r, 16) if r and r != "0x" else 0

def llama_prices(addrs):
    out = {}
    for i in range(0, len(addrs), 40):
        chunk = addrs[i:i+40]
        keys = ",".join(f"ethereum:{a}" for a in chunk)
        url = f"https://coins.llama.fi/prices/current/{keys}"
        d = json.load(urllib.request.urlopen(urllib.request.Request(url, headers={"User-Agent":"Mozilla/5.0"}), timeout=60))
        for k, v in d.get("coins", {}).items():
            out[k.split(":")[1].lower()] = v
    return out

if __name__ == "__main__":
    toks = json.load(open("wrapped_tokens_explorer.json"))
    print(f"{len(toks)} wrapped tokens")
    resolved = []
    for t in toks:
        addr = t["address"]
        r = call(BRIDGE, "0x318aee3d" + addr[2:].lower().rjust(64, "0"))
        if r and r != "0x" and len(r) >= 130:
            origin_net = u("0x" + r[2:66])
            origin_tok = "0x" + r[2:][64:128][-40:]
        else:
            origin_net, origin_tok = None, None
        supply = u(call(addr, "0x18160ddd"))
        dec = int(t.get("decimals") or 18)
        resolved.append({"wrapped": addr, "symbol": t.get("symbol"), "decimals": dec,
                         "supply": supply, "origin_network": origin_net, "origin_token": origin_tok})
    json.dump(resolved, open("wrapped_resolved.json", "w"), indent=1)
    eth_origin = [r for r in resolved if r["origin_network"] == 0]
    print(f"origin=ethereum(0): {len(eth_origin)}")
    others = {}
    for r in resolved:
        if r["origin_network"] != 0:
            others[r["origin_network"]] = others.get(r["origin_network"], 0) + 1
    print("other origin networks:", others)
    prices = llama_prices([r["origin_token"] for r in eth_origin if r["origin_token"]])
    total = 0.0
    print("\n== Ethereum-origin wrapped tokens (canonical) ==")
    rows = []
    for r in eth_origin:
        p = prices.get((r["origin_token"] or "").lower())
        usd = (r["supply"] / 10**r["decimals"]) * p["price"] if p else None
        if usd is None and r["supply"] > 0:
            # try wrapped token address price
            p2 = prices.get(r["wrapped"].lower())
            if p2:
                usd = (r["supply"] / 10**r["decimals"]) * p2["price"]
        if usd:
            total += usd
        rows.append((r["symbol"], r["supply"] / 10**r["decimals"], p["price"] if p else None, usd, r["origin_token"]))
    rows.sort(key=lambda x: (x[3] or 0), reverse=True)
    for sym, amt, px, usd, orig in rows:
        if (usd or 0) > 100 or amt > 1000:
            print(f"  {sym:10} {amt:>20,.6f}  px={px}  usd={usd if usd is None else round(usd,2)}  origin={orig}")
    print(f"\nTOTAL Ethereum-origin TVS (priced subset) = ${total:,.2f}")
    print("(unpriced tokens need manual price check)")
