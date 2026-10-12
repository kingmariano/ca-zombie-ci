#!/usr/bin/env python3
"""Decode live Lenfi datums with a raw PlutusData decoder (cbor2), classify UTxOs by role and loan fields."""
import json, sys
from collections import defaultdict
import cbor2

import os as _os
D = _os.path.dirname(_os.path.abspath(__file__))
utxos = json.load(open(f"{D}/koios_address_utxos.json"))
datums = json.load(open(f"{D}/koios_datums.json"))
dec = json.load(open(f"{D}/addresses_decoded.json"))
addr2name = {}
for k, v in dec["base_script_addresses"].items():
    addr2name[v["bech32"]] = k
for k, v in dec["bare_script_hashes"].items():
    addr2name[v["enterprise_address"]] = k
for k, v in dec["other"].items():
    addr2name[v["bech32"]] = k


def dd(x):
    if isinstance(x, cbor2.CBORTag):
        t = x.tag
        if 121 <= t <= 127:
            return {"c": t - 121, "f": [dd(v) for v in x.value]}
        if 1280 <= t <= 1400:
            return {"c": t - 1280 + 7, "f": [dd(v) for v in x.value]}
        if t == 102:
            return {"big": [dd(v) for v in x.value]}
        if t == 2:
            return {"bignum": x.value.hex() if isinstance(x.value, bytes) else x.value}
        if t == 0:
            return {"t0": x.value.hex() if isinstance(x.value, bytes) else x.value}
        return {"tag": t, "value": repr(x.value)[:100]}
    if isinstance(x, (bytes, bytearray)):
        return {"bytes": bytes(x).hex()}
    if isinstance(x, bool):
        return {"bool": x}
    if isinstance(x, int):
        return {"int": x}
    if isinstance(x, list):
        return {"list": [dd(v) for v in x]}
    if isinstance(x, dict):
        return {"map": [[dd(k), dd(v)] for k, v in x.items()]}
    return {"?": repr(x)}


def assetclass(a):
    """AssetClass = Constr 0 [CurrencySymbol bytes, TokenName bytes]; ADA = empty both"""
    if isinstance(a, dict) and a.get("c") == 0 and len(a["f"]) == 2:
        cs = a["f"][0].get("bytes", "")
        tn = a["f"][1].get("bytes", "")
        return (cs, tn)
    return ("?", "?")


def addr_str(a):
    try:
        if isinstance(a, dict) and a.get("c") == 0:
            pay = a["f"][0]
            # Credential Constr 0 [bytes] pkh | Constr 1 [bytes] script
            cred = "pkh:" + pay["f"][0]["bytes"] if pay["c"] == 0 else "script:" + pay["f"][0]["bytes"]
            stake = a["f"][1]
            if isinstance(stake, dict) and stake.get("c") == 0:  # Just
                inner = stake["f"][0]  # StakingCredential Constr 0 [Credential]
                sc = inner["f"][0]
                sk = "pkh:" + sc["f"][0]["bytes"] if sc["c"] == 0 else "script:" + sc["f"][0]["bytes"]
                return f"{cred}+{sk}"
            return cred
    except Exception:
        pass
    return "?"


rows = []
for u in utxos:
    name = addr2name.get(u["address"], u["address"])
    d = None
    src = "none"
    if u.get("inline_datum"):
        hexd = u["inline_datum"]["bytes"] if isinstance(u["inline_datum"], dict) else u["inline_datum"]
        d = dd(cbor2.loads(bytes.fromhex(hexd)))
        src = "inline"
    elif u.get("datum_hash") and datums.get(u["datum_hash"]):
        d = dd(cbor2.loads(bytes.fromhex(datums[u["datum_hash"]])))
        src = "witness"
    r = {"addr": name, "tx": u["tx_hash"], "ix": u["tx_index"], "ada": int(u["value"]) / 1e6,
         "assets": {a["policy_id"] + "." + a["asset_name"]: int(a["quantity"]) for a in (u.get("asset_list") or [])},
         "datum_src": src, "datum": d, "block": u["block_height"], "time": u["block_time"]}
    # classify
    if name in ("request_v1", "request_v2", "collateral_v1", "collateral_v2", "debt_request_v1", "debt_request_v2"):
        if isinstance(d, dict) and d.get("c") == 0 and len(d["f"]) == 15:
            f = d["f"]
            r["loan"] = {
                "borrowersNftTn": f[0].get("bytes"),
                "borrowersAddress": addr_str(f[1]),
                "loan_asset": assetclass(f[2]), "loanAmnt": f[3].get("int"),
                "interest_asset": assetclass(f[4]), "interestAmnt": f[5].get("int"),
                "collateral_asset": assetclass(f[6]), "collateralAmnt": f[7].get("int"),
                "loanDuration_ms": f[8].get("int"),
                "liquidateNft_cs": f[9].get("bytes"),
                "collateralFactor": f[10].get("int"), "liquidationCommission": f[11].get("int"),
                "requestExpiration_ms": f[12].get("int"),
                "lenderNftTn": f[13].get("bytes"),
                "lendDate_ms": f[14].get("int"),
            }
    elif name in ("interest_v1", "liquidation_v1", "request_v2", "collateral_v2", "debt_request_v2"):
        if isinstance(d, dict) and "bytes" in d:
            r["nft_tn"] = d["bytes"]
    rows.append(r)

json.dump(rows, open(f"{D}/live_utxos_classified.json", "w"), indent=1)
print("classified", len(rows))

# aggregate base-address values
agg = defaultdict(lambda: {"n": 0, "ada": 0.0, "assets": defaultdict(int)})
for r in rows:
    a = agg[r["addr"]]
    a["n"] += 1
    a["ada"] += r["ada"]
    for k, v in r["assets"].items():
        a["assets"][k] += v
print("\n=== address totals ===")
for k, v in sorted(agg.items()):
    print(f"{k:20s} n={v['n']:4d} ada={v['ada']:12.2f} n_assets={len(v['assets'])}")

# examples
print("\n=== request_v1 sample loans ===")
for r in rows:
    if r["addr"] == "request_v1" and r.get("loan"):
        L = r["loan"]
        print(json.dumps({"tx": r["tx"][:12], "ada": r["ada"],
                          "loan": L["loan_asset"], "amnt": L["loanAmnt"],
                          "collateral": L["collateral_asset"], "coll": L["collateralAmnt"],
                          "liqNft": L["liquidateNft_cs"][:12] if L["liquidateNft_cs"] else None,
                          "borrowerNft": L["borrowersNftTn"][:12] if L["borrowersNftTn"] else None,
                          "lenderNft": L["lenderNftTn"][:12] if L["lenderNftTn"] else None,
                          "duration_ms": L["loanDuration_ms"], "exp_ms": L["requestExpiration_ms"],
                          "collFactor": L["collateralFactor"], "comm": L["liquidationCommission"]}))
print("\n=== interest_v1 datum samples (lender NFT token names) ===")
for r in rows[:200]:
    if r["addr"] == "interest_v1" and r.get("nft_tn"):
        print(r["tx"][:12], r["ix"], f'{r["ada"]:.2f} ADA', r["nft_tn"][:24])
        if r["ada"] > 1000:
            print("   ^ large")
