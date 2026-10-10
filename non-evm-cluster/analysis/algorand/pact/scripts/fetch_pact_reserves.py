"""Read-only Pact pool enumeration + on-chain reserve verification (keyless).

Sources:
  https://api.pact.fi/api/internal/pools_details/all          (pool list; same source as DefiLlama adapter)
  algod  /v2/accounts/{pool_address}                          (escrow balances = reserves)
Usage: python3 fetch_pact_reserves.py [tvl_threshold]
Writes pact/raw/pact_pools_api_<date>.json and pact/raw/pact_deprecated_ge{N}_reserves.json
"""
import json
import os
import sys
import time
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
RAW = os.path.join(os.path.dirname(HERE), "raw")
sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(HERE)), "scripts"))
import algo_lib as A  # noqa: E402

THRESH = float(sys.argv[1]) if len(sys.argv) > 1 else 1000.0

# pool list
req = urllib.request.Request("https://api.pact.fi/api/internal/pools_details/all",
                             headers={"User-Agent": "zombie-research/1.0"})
with urllib.request.urlopen(req, timeout=30) as r:
    pools = json.loads(r.read())
json.dump(pools, open(os.path.join(RAW, "pact_pools_api_2026-10-10.json"), "w"))

dep = [p for p in pools if p.get("is_deprecated") and float(p.get("tvl_usd") or 0) >= THRESH]
print("pools:", len(pools), "| deprecated >= $%.0f:" % THRESH, len(dep),
      "| API subtotal $", round(sum(float(p["tvl_usd"]) for p in dep), 2))

out = {"round": A.algod_get("/status")["last-round"], "threshold": THRESH, "pools": {}}
for i, p in enumerate(dep):
    try:
        acc = A.get_account(p["on_chain_address"])
        out["pools"][str(p["on_chain_id"])] = {
            "api_tvl": float(p["tvl_usd"]),
            "microalgos": acc["amount"],
            "assets": [(x["asset-id"], x["amount"]) for x in acc.get("assets", [])],
            "addr": p["on_chain_address"],
            "type": p.get("pool_type"),
        }
    except Exception as e:  # noqa: BLE001
        out["pools"][str(p["on_chain_id"])] = {"error": str(e)[:100]}
    if i % 20 == 0:
        print(i, "done", flush=True)
    time.sleep(0.1)
json.dump(out, open(os.path.join(RAW, f"pact_deprecated_ge{int(THRESH)}_reserves.json"), "w"), indent=1)
print("saved", len(out["pools"]), "pools at round", out["round"])
