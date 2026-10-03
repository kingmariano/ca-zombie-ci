#!/usr/bin/env python3
"""Aggregate live value map (ETH + major tokens) for the 295 index contracts and known children."""
import json

BASE = "/home/heisenberg/CA/c-36/analysis"
PRICES = {"ETH": 2681.598367983263, "WETH": 2681.775337627309, "USDC": 0.9999935048989171,
          "USDT": 0.9999149247148644, "DAI": 1.0000341903531882, "WBTC": 84534.84977500243,
          "stETH": 2679.0247374345136, "wstETH": 2679.0247374345136, "SAI": 1.0}
DEC = {"ETH":18,"WETH":18,"USDC":6,"USDT":6,"DAI":18,"WBTC":8,"stETH":18,"wstETH":18,"SAI":18}

wl = json.load(open(f"{BASE}/worklist.json"))
tb = json.load(open(f"{BASE}/token_balances.json"))["balances"]
extra = json.load(open(f"{BASE}/child_extra.json"))
extra2 = [
    {"address": "0xbf4ed7b27f1d666546e30d74d50d173d20bca754", "name": "The DAO WithdrawDAO", "role": "backing of The DAO entry"},
    {"address": "0x23ea10cc1e6ebdb499d24e45369a35f43627062f", "name": "DigixDAO Acid", "role": "backing of DigixDAO entry"},
    {"address": "0xa2f987a546d4cd1c607ee8141276876c26b72bdf", "name": "Lido AnchorVault", "role": "backing of AnchorVault entry (stETH)"},
    {"address": "0x93314ee69bf8f943504654f9a8eced0071526439", "name": "AimBot dividends child", "role": "unindexed child pool (seg-E); self-only claim"},
]

def token_usd(vals):
    usd = 0.0; out = {}
    for sym, raw in (vals or {}).items():
        if sym == "ETH":
            continue
        if not isinstance(raw, str) or raw in ("0x",):
            continue
        try:
            amt = int(raw, 16) / 10**DEC[sym]
        except Exception:
            continue
        if amt <= 0: continue
        u = amt * PRICES.get(sym, 0)
        usd += u
        out[sym] = {"amount": amt, "usd": u}
    return usd, out

# aggregate over 295
tot_eth = 0.0; tot_tok = 0.0; rows_out = []
for a, r in wl.items():
    eth = r.get("live_eth") or 0
    usd_t, tok = token_usd(tb.get(a))
    tot_eth += eth; tot_tok += usd_t
    rows_out.append({"address": a, "name": r.get("name"), "category": r.get("category"),
                     "source": r.get("source"), "live_eth": eth, "usd_eth": eth*PRICES["ETH"],
                     "tokens": tok, "usd_tokens": usd_t, "mapped": r.get("mapped"),
                     "total_usd": eth*PRICES["ETH"] + usd_t})

# children (not in 295)
child_rows = []
HARDCODE = {"0x93314ee69bf8f943504654f9a8eced0071526439": 67.458694474256203200,
            "0x23ea10cc1e6ebdb499d24e45369a35f43627062f": 11681.827613866489998200}
TB_LOWER = {k.lower(): v for k, v in tb.items()}
for c in extra2:
    a = c["address"]
    vals = tb.get(a) or TB_LOWER.get(a.lower()) or {}
    if a in HARDCODE:
        eth = HARDCODE[a]
    else:
        eth = int(vals.get("ETH","0x0"),16)/1e18 if isinstance(vals.get("ETH"),str) else 0
    usd_t, tok = token_usd(vals)
    child_rows.append({"address": a, "name": c["name"], "role": c.get("role",""),
                       "live_eth": eth, "usd_eth": eth*PRICES["ETH"], "tokens": tok,
                       "usd_tokens": usd_t, "total_usd": eth*PRICES["ETH"]+usd_t})

out = {"block_eth": 26111001, "block_tokens": 26111067,
       "prices": PRICES, "listed_295": rows_out, "children": child_rows,
       "totals": {
           "listed_live_eth": tot_eth, "listed_live_eth_usd": tot_eth*PRICES["ETH"],
           "listed_tokens_usd": tot_tok, "listed_total_usd": tot_eth*PRICES["ETH"]+tot_tok,
           "children_live_eth": sum(c["live_eth"] for c in child_rows),
           "children_eth_usd": sum(c["usd_eth"] for c in child_rows),
           "children_tokens_usd": sum(c["usd_tokens"] for c in child_rows),
       }}
json.dump(out, open(f"{BASE}/value_map.json","w"), indent=1)
t = out["totals"]
print("LISTED 295:  ETH %.2f ($%.0f) + tokens $%.0f = $%.0f" % (t['listed_live_eth'], t['listed_live_eth_usd'], t['listed_tokens_usd'], t['listed_total_usd']))
print("CHILDREN:    ETH %.2f ($%.0f) + tokens $%.0f" % (t['children_live_eth'], t['children_eth_usd'], t['children_tokens_usd']))
print("GRAND TOTAL live index value: $%.0f" % (t['listed_total_usd'] + t['children_eth_usd'] + t['children_tokens_usd']))
print()
print("Top 15 listed by total USD:")
for r in sorted(rows_out, key=lambda x:-x["total_usd"])[:15]:
    print(f"  ${r['total_usd']/1e6:8.2f}M  eth={r['live_eth']:10.2f} tok=${r['usd_tokens']/1e6:6.2f}M  {str(r['name'])[:36]:38s} {r['address']}")
print("Children:")
for r in child_rows:
    print(f"  ${r['total_usd']/1e6:8.2f}M  eth={r['live_eth']:10.2f} tok=${r['usd_tokens']/1e6:6.2f}M  {r['name']}")
