#!/usr/bin/env python3
"""Parse the CI forge-test log for Captured events and price the captured tokens.
Usage: python3 parse_captures.py <logfile> [--json out.json]"""
import json, re, sys, urllib.request, time

log = sys.argv[1] if len(sys.argv) > 1 else "/home/heisenberg/CA/c-23/ci-log.txt"
text = open(log, encoding="utf-8", errors="ignore").read()

# lines look like:  "  captured token: 0x....", "    amount: 123", "    from victim: 0x...."
tok_re = re.compile(r"captured token:\s*(0x[0-9a-fA-F]{40})")
amt_re = re.compile(r"amount:\s*(\d+)")
vic_re = re.compile(r"from victim:\s*(0x[0-9a-fA-F]{40})")
lines = text.splitlines()
rows = []
for i, ln in enumerate(lines):
    m = tok_re.search(ln)
    if not m:
        continue
    token = m.group(1).lower()
    amount = None
    victim = None
    for j in range(i + 1, min(i + 4, len(lines))):
        a = amt_re.search(lines[j])
        if a and amount is None:
            amount = int(a.group(1))
        v = vic_re.search(lines[j])
        if v and victim is None:
            victim = v.group(1).lower()
    if amount is not None:
        rows.append({"token": token, "amount": amount, "victim": victim})

print("captured positions parsed:", len(rows))
uniq = {}
for r in rows:
    uniq.setdefault(r["token"], 0)
    uniq[r["token"]] += r["amount"]

# price via DefiLlama
prices = {}
toks = sorted(uniq)
for i in range(0, len(toks), 40):
    url = "https://coins.llama.fi/prices/current/" + ",".join(f"ethereum:{t}" for t in toks[i:i + 40])
    try:
        d = json.load(urllib.request.urlopen(url, timeout=60))
        for k, v in d.get("coins", {}).items():
            prices[k.split(":")[1]] = v.get("price")
    except Exception as e:
        print("llama err", str(e)[:60])
    time.sleep(0.3)

total = 0.0
priced = []
# decimals from the valuation snapshot (all contract targets are in there)
dec_map = {}
try:
    snap = json.load(open("/home/heisenberg/CA/c-23/analysis/confirmed_valuation.json"))
    for v, items in snap.get("balances", {}).items():
        for i in items:
            dec_map[i["tok"].lower()] = int(i["dec"])
except Exception as e:
    print("dec map err", str(e)[:60])
for t, amt in uniq.items():
    p = prices.get(t)
    if p is None:
        continue
    dec = dec_map.get(t, 18)
    usd = p * amt / 10 ** dec
    if usd > 0.005:
        priced.append((usd, t, amt, p))
        total += usd
priced.sort(reverse=True)
print(f"captured tokens priced: {len(priced)}  TOTAL USD = {total:.2f}")
for usd, t, amt, p in priced[:20]:
    print(f"  ${usd:>8.2f}  {t}  raw={amt}  price={p}")
out = {"positions": len(rows), "unique_tokens": len(uniq), "priced_tokens": len(priced),
       "total_usd": round(total, 2), "rows": rows,
       "priced": [{"token": t, "raw": a, "price": p, "usd": round(u, 2)} for u, t, a, p in priced]}
json.dump(out, open("/home/heisenberg/CA/c-23/analysis/production_capture_valuation.json", "w"), indent=1)
print("saved analysis/production_capture_valuation.json")
