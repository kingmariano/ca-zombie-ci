#!/usr/bin/env python3
"""Build master worklist (295 + children) with all metadata, then split into 5 segments."""
import json, os

BASE = "/home/heisenberg/CA/c-36/analysis"
rows = json.load(open(f"{BASE}/index_full_live.json"))
live = json.load(open(f"{BASE}/live_295.json"))
cs = json.load(open(f"{BASE}/code_src_295.json"))
meta_addrs = json.load(open(f"{BASE}/meta_addrs.json"))
children = json.load(open(f"{BASE}/children_from_descriptions.json"))
tok = json.load(open(f"{BASE}/token_balances.json"))

data = {}
for r in rows:
    a = r["contract"]
    c = cs["contracts"].get(a, {})
    rec = {
        "address": a,
        "name": r.get("name"),
        "key": r.get("key"),
        "category": r.get("category"),
        "source": r.get("source"),
        "live_eth": r.get("live_eth"),
        "mapped": r.get("total_eth_in_balances") if isinstance(r.get("total_eth_in_balances"), (int, float)) else None,
        "idx_contract_eth": r.get("contract_eth_balance") if isinstance(r.get("contract_eth_balance"), (int, float)) else None,
        "coverage_pct": r.get("coverage_pct") if isinstance(r.get("coverage_pct"), (int, float)) else None,
        "desc": (r.get("description") or "")[:600],
        "holders": r.get("addresses_with_balance"),
        "multi_step": r.get("multi_step"),
        "verified": c.get("bs_verified"),
        "bs_name": c.get("bs_name"),
        "code_size": c.get("code_size"),
        "selectors": c.get("selectors"),
        "owner_sel": r.get("sel_owner"),
        "admin_sel": r.get("sel_admin"),
        "meta_addrs": meta_addrs.get(a.lower(), {}).get("meta_addrs", []),
        "live_tokens": {k: v for k, v in (tok["balances"].get(a) or {}).items() if isinstance(v, str) and v not in ("0x",) and int(v, 16) > 0},
    }
    data[a] = rec

json.dump(data, open(f"{BASE}/worklist.json", "w"), indent=1)
print("worklist entries:", len(data))

# ---- segment definitions ----
def has_live(rec, thresh=0.5):
    return (rec.get("live_eth") or 0) > thresh

def mapped(rec):
    return rec.get("mapped") or 0

# child/backing extra contracts to review (with known live value)
CHILD_EXTRA = [
    {"address": "0xbf4ed7b27f1d666546e30d74d50d173d20bca754", "name": "The DAO WithdrawDAO", "live_eth": 81399.81, "note": "child of The DAO entry; verified source: withdraw() self-only; trusteeWithdraw() underflow no-op"},
    {"address": "0x23ea10cc1e6ebdb499d24e45369a35f43627062f", "name": "DigixDAO Acid", "live_eth": 11681.83, "note": "child of DigixDAO; Acid.burn() holder-only"},
    {"address": "0x707f9118e33a9b8998bea41dd0d46f38bb963fc8", "name": "Lido bETH", "live_eth": 0, "note": "AnchorVault share token; bETH supply 1013.43 vs vault 745.47 stETH"},
    {"address": "0xa2f987a546d4cd1c607ee8141276876c26b72bdf", "name": "Lido AnchorVault", "live_eth": 0, "note": "holds 745.47 stETH"},
    {"address": "0x3dfd23a6c5e8bbcfc9581d2e864a68feb6a076d3", "name": "Aave v1 LendingPoolCore", "live_eth": 926.00, "note": "child of Aave v1; prior deep-dive: holder-only"},
    {"address": "0x1e0447b19bb6ecfdae1e4ae1694b0c3659614e4e", "name": "dYdX Solo Margin", "live_eth": 0, "note": "prior deep-dive: <= $16-18 liquidation spread"},
    {"address": "0x0a14b696350546110a0d8acdb86226983af9d2a0", "name": "zkSync Lite L1 exit", "live_eth": 10926.66, "note": "prior deep-dive: $0 (root immutable, claims self-only)"},
]

segs = {"A": [], "B": [], "C": [], "D": [], "E": []}
for a, rec in data.items():
    cat = rec.get("category")
    L = has_live(rec); M = mapped(rec)
    if cat == "ico":
        if L or M > 20: segs["A"].append(a)
    elif cat in ("gambling", "powh"):
        if L or M > 20: segs["B"].append(a)
    elif cat in ("dex", "nft", "other", "prediction"):
        if L or M > 20: segs["C"].append(a)
    elif cat in ("defi", "token", "options", "lending", "yield", "payment_channel", "hack_recovery", "dao"):
        if L or M > 20: segs["D"].append(a)
    else:  # masterchef, owner-action-required, None
        segs["E"].append(a)

# E also gets insolvent smalls and unverified leftovers
for a, rec in data.items():
    if a in segs["E"] or any(a in v for v in segs.values()): continue
    if (rec.get("coverage_pct") or 0) > 100 or rec.get("verified") is False:
        segs["E"].append(a)

# owner-action-required always in A (special class)
for a, rec in data.items():
    if rec.get("category") == "owner-action-required":
        if a not in segs["A"]: segs["A"].append(a)
        if a in segs["E"]: segs["E"].remove(a)

for k, v in segs.items():
    tot = sum((data[a].get("live_eth") or 0) for a in v)
    totm = sum(mapped(data[a]) for a in v)
    print(f"seg {k}: {len(v)} contracts, live {tot:.1f} ETH, mapped {totm:.1f}")
    json.dump(v, open(f"{BASE}/seg_{k}_addrs.json", "w"), indent=1)

json.dump(CHILD_EXTRA, open(f"{BASE}/child_extra.json", "w"), indent=1)
