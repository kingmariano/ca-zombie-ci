#!/usr/bin/env python3
"""Final spot checks for H-22: Serum v3 vault reality + authorities + SOL price."""
import json, sys
sys.path.insert(0, "/home/heisenberg/CA/serum/analysis")
from rpc import rpc

out = {}
MB = ["https://api.mainnet-beta.solana.com"]
PN = ["https://solana-rpc.publicnode.com"]

# 1) Serum v3 fee_sweeper + disable authority accounts
for label, a in [("serum_fee_sweeper", "DeqYsmBd9BnrbgUwQjVH4sQWK71dEgE6eoZFw3Rp4ftE"),
                 ("serum_disable_authority", "5ZVJgwWxMsqXxRMYHXqMwH2hd4myX5Ef4Au2iUsuNQ7V")]:
    try:
        v = rpc("getAccountInfo", [a, {"encoding": "base64"}], endpoints=PN)
        v = v["value"]
        out[label] = {"exists": bool(v), "owner": (v or {}).get("owner"),
                      "lamports": (v or {}).get("lamports"), "data_len": (v or {}).get("space")}
    except Exception as e:
        out[label] = {"err": str(e)[:120]}

# 2) Serum v3 top vault actual balances vs market-state accounting
checks = [
    {"name": "SOL/USDC 9wFFyRf", "market": "9wFFyRfZBsuAha4YcuxcXLKwMxJR43S7fPfQLusDBzvT",
     "coin_vault": "36c6YqAwyGKQG66XEp2dJc5JqjaBNv7sVghEtJv4c7u6",
     "pc_vault": "8CFo8bL8mZQK8abbFyypFMwEDd8tVJjHTTojMLgQTUSZ",
     "coin_dep": 20290000000000, "pc_dep": 956741257330, "pc_fees": 1518550981004},
]
for c in checks:
    for side in ("coin", "pc"):
        try:
            b = rpc("getTokenAccountBalance", [c[f"{side}_vault"], {"commitment": "finalized"}], endpoints=PN)
            c[f"{side}_vault_actual"] = b["value"]["amount"]
            c[f"{side}_vault_decimals"] = b["value"]["decimals"]
        except Exception as e:
            c[f"{side}_vault_actual"] = "ERR " + str(e)[:80]
    out[c["name"]] = c

# 3) SOL price for rent conversion
import urllib.request
try:
    with urllib.request.urlopen("https://coins.llama.fi/prices/current/solana:So11111111111111111111111111111111111111112", timeout=30) as r:
        j = json.loads(r.read().decode())
    out["sol_price"] = j["coins"]["solana:So11111111111111111111111111111111111111112"]
except Exception as e:
    out["sol_price"] = {"err": str(e)[:100]}

# 4) current slot
try:
    out["slot"] = rpc("getSlot", [{"commitment": "finalized"}], endpoints=PN)
except Exception as e:
    out["slot"] = str(e)[:80]

json.dump(out, open("/home/heisenberg/CA/serum/analysis/final_spot_checks.json", "w"), indent=1)
print(json.dumps(out, indent=1)[:3000])
