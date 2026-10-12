#!/usr/bin/env python3
"""Determine NFT custody for every live Lenfi V1 UTxO: which claim-gating NFTs still exist, where."""
import json, time, sys, urllib.request

KOIOS = "https://api.koios.rest/api/v1"
import os as _os
D = _os.path.dirname(_os.path.abspath(__file__))
LENDER_CS = "42f0e3706d2e0a0761db8da21387aadabe609a7cf328d249ebc2eeff"
BORROWER_CS = "21ca2902ad0406bc2ce361ad91157b3542544d86d4e3d3e3c43f1763"


def post(path, body, retries=4):
    for i in range(retries):
        try:
            req = urllib.request.Request(f"{KOIOS}{path}", data=json.dumps(body).encode(),
                                         headers={"Content-Type": "application/json", "User-Agent": "readonly/1.0"}, method="POST")
            return json.loads(urllib.request.urlopen(req, timeout=120).read())
        except Exception as e:
            print("retry", path, e, file=sys.stderr)
            time.sleep(3 * (i + 1))
    raise RuntimeError(path)


rows = json.load(open(f"{D}/live_utxos_classified.json"))

# collect NFT queries: (class, key, policy, name)
queries = []
for r in rows:
    if r["addr"] == "interest_v1" and r.get("nft_tn"):
        queries.append(("interest_v1", f'{r["tx"]}#{r["ix"]}', LENDER_CS, r["nft_tn"]))
    elif r["addr"] == "liquidation_v1" and r.get("nft_tn"):
        queries.append(("liquidation_v1", f'{r["tx"]}#{r["ix"]}', BORROWER_CS, r["nft_tn"]))
    elif r.get("loan"):
        L = r["loan"]
        if L.get("lenderNftTn") and L["lenderNftTn"] != "ff":
            queries.append((r["addr"], f'{r["tx"]}#{r["ix"]}', LENDER_CS, L["lenderNftTn"]))
        if L.get("borrowersNftTn") and L["borrowersNftTn"] != "ff":
            queries.append((r["addr"], f'{r["tx"]}#{r["ix"]}', BORROWER_CS, L["borrowersNftTn"]))

print("total NFT queries:", len(queries))
results = {}
B = 25
for i in range(0, len(queries), B):
    batch = queries[i:i + B]
    pairs = [["42f0e3706d2e0a0761db8da21387aadabe609a7cf328d249ebc2eeff" if p == LENDER_CS else "21ca2902ad0406bc2ce361ad91157b3542544d86d4e3d3e3c43f1763", n] for (_, _, p, n) in batch]
    au = post("/asset_utxos", {"_asset_list": pairs, "_extended": True})
    # build map name->(has_unspent, count) -- note: _extended False still returns asset_list? use per-pair queries if needed
    holders = {}
    for u in au:
        al = u.get("asset_list")
        if al is None:
            continue
        for a in al:
            key = (a["policy_id"], a["asset_name"])
            holders.setdefault(key, []).append(u["address"])
    for (cls, key, pol, name) in batch:
        h = holders.get((pol, name), [])
        results[f"{cls}|{key}|{pol[:8]}|{name}"] = {"n_utxos": len(h), "addresses": h[:3]}
    print(f"  batch {i//B}: ok ({len(batch)} queries)")
    time.sleep(1)

json.dump(results, open(f"{D}/nft_custody.json", "w"), indent=1)

# Summarize: for each class, how many gating NFTs exist unspent at key vs script addresses
from collections import Counter
summary = Counter()
details = {}
for k, v in results.items():
    cls, key, pol, name = k.split("|")
    # classify holder address type quickly: script-ish if starts with addr1z/addr1x/addr1w/script
    holders = v["addresses"]
    if v["n_utxos"] == 0:
        kind = "BURNED_OR_LOST"
    else:
        kind = "KEY_HELD"  # refine later
    summary[(cls, pol, kind)] += 1
    details.setdefault(cls, []).append((key, pol, v["n_utxos"], holders))

print("\n=== NFT custody summary (CLAIM GATE TOKENS) ===")
for k, v in sorted(summary.items()):
    print(f"  {k[0]:18s} policy={k[1]:8s} {k[2]:16s} x{v}")
print("\n=== per-class: missing (burned/lost) gate tokens ===")
for cls, lst in details.items():
    missing = [x for x in lst if x[2] == 0]
    print(f"  {cls}: {len(missing)}/{len(lst)} gates missing")
    for m in missing[:5]:
        print("      ", m[0], m[1], m[3])
