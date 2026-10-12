#!/usr/bin/env python3
"""Empirically verify NFT naming rule and locate NFTs behind live interest/liquidation UTxOs (Koios)."""
import json, time, hashlib, sys, urllib.request

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
            return json.loads(urllib.request.urlopen(req, timeout=90).read())
        except Exception as e:
            print("retry", path, e, file=sys.stderr)
            time.sleep(3 * (i + 1))
    raise RuntimeError(path)


def name_from_ref(txid_hex, idx):
    return hashlib.sha256(bytes([idx]) + bytes.fromhex(txid_hex)).hexdigest()


rows = json.load(open(f"{D}/live_utxos_classified.json"))

# --- 1) empirical NFT-name rule from funding txs of live collateral UTxOs
samples = [r for r in rows if r["addr"] in ("collateral_v1", "collateral_v2")][:8]
byhash = {t["tx_hash"]: t for t in post("/tx_info", {"_tx_hashes": [r["tx"] for r in samples]})}
print("=== funding txs: minted lender NFTs and name rule ===")
out = []
for r in samples:
    t = byhash.get(r["tx"])
    if not t:
        continue
    mints = [m for m in (t.get("assets_minted") or []) if m["policy_id"] == LENDER_CS]
    burns = [m for m in (t.get("assets_minted") or []) if m["policy_id"] == BORROWER_CS and int(m["quantity"]) < 0]
    rec = {"utxo": r["tx"][:16] + "#" + str(r["ix"]), "class": r["addr"], "ada": r["ada"],
           "minted_lender_nft": [(m["asset_name"][:16], m["quantity"]) for m in mints],
           "burned_borrower": [(m["asset_name"][:16], m["quantity"]) for m in burns],
           "inputs": [[i["tx_hash"][:12], i["tx_index"]] for i in t.get("inputs", [])][:6]}
    rule = []
    for m in mints:
        match = any(name_from_ref(i["tx_hash"], i["tx_index"]) == m["asset_name"] for i in t.get("inputs", []))
        rule.append({"tm": m["asset_name"][:20], "sha256_rule": match})
    rec["rule_check"] = rule
    out.append(rec)
    print(json.dumps(rec))
json.dump(out, open(f"{D}/nft_rule_check.json", "w"), indent=1)

# --- 2) holders of lender NFTs behind top interest UTxOs (Koios /asset_utxos)
top = sorted([r for r in rows if r["addr"] == "interest_v1" and r.get("nft_tn")], key=lambda r: -r["ada"])[:12]
pairs = [["42f0e3706d2e0a0761db8da21387aadabe609a7cf328d249ebc2eeff", r["nft_tn"]] for r in top]
au = post("/asset_utxos", {"_asset_list": pairs, "_extended": False})
print("\n=== lender NFTs behind top interest UTxOs (current unspent instances) ===")
json.dump(au, open(f"{D}/lender_nft_utxos_top.json", "w"), indent=1)
by_asset = {}
for u in au:
    for a in u["asset_list"]:
        by_asset.setdefault(a["policy_id"] + a["asset_name"], []).append(u["address"])
for r in top:
    key = "42f0e3706d2e0a0761db8da21387aadabe609a7cf328d249ebc2eeff" + r["nft_tn"]
    holders = by_asset.get(key, [])
    print(f'{r["ada"]:10.2f} ADA  nft={r["nft_tn"][:20]}  holders={len(holders)} {holders[:2]}')

# --- 3) borrower NFTs behind top liquidation UTxOs
top2 = sorted([r for r in rows if r["addr"] == "liquidation_v1" and r.get("nft_tn")], key=lambda r: -r["ada"])[:6]
pairs2 = [["21ca2902ad0406bc2ce361ad91157b3542544d86d4e3d3e3c43f1763", r["nft_tn"]] for r in top2]
au2 = post("/asset_utxos", {"_asset_list": pairs2})
json.dump(au2, open(f"{D}/borrower_nft_utxos_top.json", "w"), indent=1)
by_asset2 = {}
for u in au2:
    for a in u["asset_list"]:
        by_asset2.setdefault(a["policy_id"] + a["asset_name"], []).append(u["address"])
print("\n=== borrower NFTs behind top liquidation UTxOs ===")
for r in top2:
    key = "21ca2902ad0406bc2ce361ad91157b3542544d86d4e3d3e3c43f1763" + r["nft_tn"]
    holders = by_asset2.get(key, [])
    print(f'{r["ada"]:10.2f} ADA  nft={r["nft_tn"][:20]}  holders={len(holders)} {holders[:2]}')
