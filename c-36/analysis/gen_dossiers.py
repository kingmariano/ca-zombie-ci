#!/usr/bin/env python3
"""Generate per-pot dossiers for the top-40 contracts by live value (ETH + tokens)."""
import json, os

BASE = "/home/heisenberg/CA/c-36/analysis"
os.makedirs(f"{BASE}/dossiers", exist_ok=True)
wl = json.load(open(f"{BASE}/worklist.json"))
cs = json.load(open(f"{BASE}/code_src_295.json"))["contracts"]
vm = json.load(open(f"{BASE}/value_map.json"))
tb = json.load(open(f"{BASE}/token_balances.json"))["balances"]

PRICES = vm["prices"]

rows = sorted(vm["listed_295"], key=lambda r: -r["total_usd"])[:40]
# add children
children = [
    {"address": "0xbf4ed7b27f1d666546e30d74d50d173d20bca754", "name": "The DAO WithdrawDAO (child)", "total_usd": 81399.81*PRICES["ETH"], "live_eth": 81399.81, "tokens": {}, "mapped": 81479.79},
    {"address": "0x23ea10cc1e6ebdb499d24e45369a35f43627062f", "name": "DigixDAO Acid (child)", "total_usd": 11681.83*PRICES["ETH"], "live_eth": 11681.83, "tokens": {}, "mapped": 10908.62},
    {"address": "0x4d9629e80118082b939e3d59e69c82a2ec08b4d5", "name": "TribeRedeemer (unindexed)", "total_usd": 1788335.56 + 3141.11*PRICES["stETH"], "live_eth": 0, "tokens": {"DAI": {"amount": 1788335.56, "usd": 1788335.56}, "stETH": {"amount": 3141.11, "usd": 3141.11*PRICES["stETH"]}}, "mapped": 0},
]
allrows = rows + children
allrows.sort(key=lambda r: -r["total_usd"])

for i, r in enumerate(allrows, 1):
    a = r["address"]
    w = wl.get(a, {})
    c = cs.get(a, {})
    lines = []
    lines.append(f"# Dossier {i}: {r.get('name')}")
    lines.append(f"- address: `{a}`")
    lines.append(f"- live ETH: {r.get('live_eth'):.6f} (block 26111001); value USD: ${r['total_usd']:,.0f}")
    if r.get("tokens"):
        for sym, v in r["tokens"].items():
            lines.append(f"  - {sym}: {v['amount']:.6f} (${v['usd']:,.0f})")
    lines.append(f"- index mapped (ETH-equiv): {w.get('mapped')}")
    lines.append(f"- category/source: {w.get('category')}/{w.get('source')} | index coverage%: {w.get('coverage_pct')}")
    lines.append(f"- Blockscout: verified={c.get('bs_verified')} name={c.get('bs_name')} code_size={c.get('code_size')}")
    lines.append(f"- selector count: {len(c.get('selectors') or [])}; owner_sel={w.get('owner_sel')} admin_sel={w.get('admin_sel')} paused_sel={w.get('sel_paused') if 'sel_paused' in w else ''}")
    lines.append(f"- index claim note: {w.get('desc') or '(none)'}")
    lines.append(f"- meta child addresses: {w.get('meta_addrs')}")
    lines.append(f"- selectors: {', '.join((c.get('selectors') or [])[:40])}")
    open(f"{BASE}/dossiers/{i:02d}_{a[:10]}.md", "w").write("\n".join(lines) + "\n")

print(f"wrote {len(allrows)} dossiers")
