#!/usr/bin/env python3
"""FlareBank: quantify the unprivileged DEX-vs-curve arbitrage.

Path: mint BANK from the Bank contract (pay WFLR), sell BANK on the V2 pair(s)
for WFLR. Net = WFLR out - WFLR in, including the 10% mint fee, curve movement,
pair fee (0.3%) and price impact. Exact contract calls for quotes.
"""
import json, urllib.request

RPC = "https://flare-api.flare.network/ext/C/rpc"
BANK = "0x194726F6C2aE988f1Ab5e1C943c17e591a6f6059"
WFLR = "0x1d80c49bbbcd1c0911346656b529df9e5c2f783d"
PAIRS = {
    "pairC": ("0x5f29c8d049e47dd180c2b83e3560e8e271110335", 102880.852920, 2152068.159183),
    "pairB": ("0x0f574fc895c1abf82aeff334fa9d8ba43f866111", 4614.173145, 96773.461996),
    "pairA": ("0xd41787672e9c887ef66c42a4c60f00e6e71a762d", 32.356956, 674.353638),
}
E18 = 10**18

def call(to, data):
    req = urllib.request.Request(RPC, data=json.dumps({"jsonrpc": "2.0", "id": 1, "method": "eth_call",
        "params": [{"to": to, "data": data}, "latest"]}).encode(),
        headers={"Content-Type": "application/json", "User-Agent": "Mozilla/5.0"})
    r = json.load(urllib.request.urlopen(req, timeout=45))
    if "result" not in r: raise RuntimeError(r)
    return int(r["result"], 16) if r["result"] != "0x" else 0

def tokens_for_wflr(e_wei):   # calculateTokensReceived(uint256)
    return call(BANK, "0x10d0ffdd" + hex(e_wei)[2:].rjust(64, "0"))

def wflr_for_tokens(t_wei):   # calculateEthereumReceived(uint256)
    return call(BANK, "0x22609373" + hex(t_wei)[2:].rjust(64, "0"))

def pair_out(tokens_wei, x, y):
    """exact V2 out with 0.3% fee"""
    dx = tokens_wei * 997 // 1000
    return y - (x * y) // (x + dx)

def main():
    print("mint cost / redemption value (contract quotes):")
    for e in [1, 100, 1000, 10_000, 50_000]:
        t = tokens_for_wflr(e * E18)
        print(f"  pay {e:>6} WFLR -> {t/E18:,.4f} BANK  (cost/token {e*E18/t if t else 0:,.4f})")
    for t in [1, 10, 100, 1000]:
        v = wflr_for_tokens(t * E18)
        print(f"  sell {t:>4} BANK -> {v/E18:,.4f} WFLR (net of 10% fee)")

    print("\nDEX-vs-curve arb scan (mint from Bank -> sell into pairC/B/A):")
    best = None
    for e in [100, 500, 1000, 2000, 3000, 5000, 8000, 10000, 15000, 20000, 30000, 50000]:
        tokens = tokens_for_wflr(e * E18)
        if tokens == 0: continue
        rem = tokens
        out_total = 0
        for name, (addr, xf, yf) in PAIRS.items():
            x = int(xf * E18); y = int(yf * E18)
            take = min(rem, x * 5 // 100)  # don't drain >5% of a pair per sim step
            if take == 0: continue
            out_total += pair_out(take, x, y)
            rem -= take
        profit = (out_total - e * E18) / E18
        print(f"  spend {e:>6} WFLR -> mint {tokens/E18:>10,.4f} BANK -> DEX out {out_total/E18:>12,.4f} WFLR  profit {profit:>10,.4f}")
        if best is None or profit > best[1]:
            best = (e, profit)
    print(f"\nbest single-shot: spend {best[0]} WFLR, net profit {best[1]:,.4f} WFLR (~${best[1]*0.0069:,.2f})")
    # convergence estimate: sell until DEX price == mint cost
    x, y = PAIRS["pairC"][1] * E18, PAIRS["pairC"][2] * E18
    t = tokens_for_wflr(1000 * E18) / (1000 * E18)  # tokens per WFLR at small size
    price0 = y / x
    print(f"pairC marginal price {price0:,.4f} WFLR/BANK; small-size mint cost/token {1/t:,.4f}")
    print("=> gap ~%.4f WFLR/token; convergence volume ~%.0f BANK (~$%.2f)" %
          (price0 * 0.997 - 1/t, x * ((price0 - 1/t) / price0), x * ((price0 - 1/t) / price0) * (price0 - 1/t) / 2 * 0.0069))

if __name__ == "__main__":
    main()
