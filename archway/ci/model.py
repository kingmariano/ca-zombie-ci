#!/usr/bin/env python3
"""C2-09 Archway cost-to-capture + extraction-bound model from ci-out evidence."""
import json, os, re, urllib.request, urllib.parse, csv
from collections import defaultdict

D = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "ci-out")
LCD = "https://api.mainnet.archway.io"
UA = {"User-Agent": "Mozilla/5.0 (zombie-hunt-ci; read-only research)"}

def load(n):
    p = os.path.join(D, n)
    if not os.path.exists(p):
        return None
    with open(p) as f:
        return json.load(f)

def get(url):
    try:
        req = urllib.request.Request(url, headers=UA)
        with urllib.request.urlopen(req, timeout=40) as r:
            return json.load(r)
    except Exception as e:
        return {"_error": str(e)}

core = load("core_state.json")
infos = load("contract_infos.json") or {}
bals = load("contract_balances.json") or {}
# merge the dedicated code-31 sweep (EvolvNFT instances; unstable pagination in the main pass)
c31bals = load("code31_balances.json") or {}
for _a, _b in c31bals.items():
    if _a not in bals:
        bals[_a] = _b
    infos.setdefault(_a, {"code_id": "31", "label": "EvolvNFT Collection (sweep)", "admin": None})
modb = load("module_balances.json") or {}
osmo = load("osmosis_pools.json") or {}
prices = load("prices.json") or {}
nodes = load("node_evidence.json") or []

P = prices.get("coins", prices)
def price(cid, default=None):
    v = P.get(cid, {})
    return v.get("price", default)
ARCH = price("coingecko:archway")
OSMO = price("coingecko:osmosis")
USDC = price("coingecko:usd-coin", 1.0)
ATOM = price("coingecko:cosmos")
# extra majors via DefiLlama
EXTRA = {
    "coingecko:injective-protocol": "inj",
    "coingecko:akash-network": "uakt",
    "coingecko:celestia": "utia",
    "coingecko:ethereum": "weth-wei",
    "coingecko:wrapped-bitcoin": "wbtc",
}
extra_prices = {}
try:
    ids = ",".join(EXTRA)
    d = get("https://coins.llama.fi/prices/current/" + ids)
    for cid, meta in (d.get("coins") or {}).items():
        extra_prices[EXTRA.get(cid, cid)] = meta.get("price")
except Exception:
    pass

def aarch(x): return float(x) / 1e18

# ---- core numbers ----
def safe(d, *keys, default=None):
    for k in keys:
        if not isinstance(d, dict):
            return default
        d = d.get(k, default)
        if d is None:
            return default
    return d

bonded = int(safe(core, "staking_pool", "pool", "bonded_tokens", default="0") or 0)
not_bonded = int(safe(core, "staking_pool", "pool", "not_bonded_tokens", default="0") or 0)
supply = int(safe(core, "supply_aarch", "amount", "amount", default="0") or 0)
cp_raw = 0.0
for c in safe(core, "community_pool", "pool", default=[]) or []:
    if isinstance(c, dict) and c.get("denom") == "aarch":
        cp_raw += float(c["amount"])
cp = aarch(cp_raw)
gp = (core.get("gov_params") or {}).get("decoded", {}) if core else {}
quorum = float(gp.get("quorum") or 0.334)
threshold = float(gp.get("threshold") or 0.5)
veto = float(gp.get("veto_threshold") or 0.334)
min_dep = gp.get("min_deposit") or {}
voting_s = gp.get("voting_period_s")

gov_addr = None
for acct in safe(core, "module_accounts", "accounts", default=[]) or []:
    if acct.get("name") == "gov":
        gov_addr = safe(acct, "base_account", "address")

# ---- denom trace map for IBC denoms held by contracts ----
tot_by_denom = defaultdict(float)
for addr, bl in bals.items():
    for b in bl or []:
        tot_by_denom[b["denom"]] += float(b["amount"])
top_ibc = sorted([d for d in tot_by_denom if d.startswith("ibc/")],
                 key=lambda d: -tot_by_denom[d])[:120]
trace_map = {}
for d in top_ibc:
    t = get(f"{LCD}/ibc/apps/transfer/v1/denom_traces/{d[4:]}")
    trace_map[d] = t.get("denom_trace", t)
# Osmosis-side traces (for pricing the counterpart assets of ARCH pools)
for d, t in (osmo.get("denom_traces") or {}).items():
    if d not in trace_map:
        trace_map[d] = t

HARD_USD_BASES = {"uusdc": 1.0, "uusdt": 1.0, "usdc": 1.0, "usdt": 1.0, "udai": 1.0}
MAJOR = {"uatom": ATOM, "uosmo": OSMO, "inj": extra_prices.get("inj"),
         "uakt": extra_prices.get("uakt"), "utia": extra_prices.get("utia"),
         "weth-wei": extra_prices.get("weth-wei"), "wbtc-osmo": extra_prices.get("wbtc"),
         "ueth": extra_prices.get("weth-wei"), "wbtc": extra_prices.get("wbtc")}

def base_of(denom):
    if denom == "aarch": return "aarch"
    if denom in ("uosmo", "uatom"): return denom
    t = trace_map.get(denom)
    return (t or {}).get("base_denom", "")

def usd_of(denom, amount):
    if denom == "aarch":
        return aarch(amount) * (ARCH or 0), "arch"
    b = base_of(denom)
    if not b:
        return None, "unknown"
    if b in HARD_USD_BASES:
        return (amount / 1e6) * (HARD_USD_BASES[b] or 1.0), "hard-usd"
    if b in MAJOR and MAJOR[b]:
        dec = 18 if b in ("inj", "weth-wei", "ueth") else (8 if "wbtc" in b else 6)
        return (amount / 10 ** dec) * MAJOR[b], "major"
    return None, "longtail:" + b

# ---- contract values ----
contract_rows = []
denom_agg = defaultdict(lambda: {"amount": 0.0, "usd": 0.0, "cls": ""})
for addr, bl in bals.items():
    tot = 0.0; cls = set(); tops = []
    for b in bl or []:
        v, c = usd_of(b["denom"], float(b["amount"]))
        denom_agg[b["denom"]]["amount"] += float(b["amount"])
        denom_agg[b["denom"]]["cls"] = c
        if v:
            denom_agg[b["denom"]]["usd"] += v
            tot += v
            cls.add(c)
            tops.append((v, b["denom"]))
    if tot > 0:
        contract_rows.append({"addr": addr, "label": infos.get(addr, {}).get("label"),
                              "admin": infos.get(addr, {}).get("admin"), "usd": round(tot, 2),
                              "class": ",".join(sorted(cls)),
                              "top": ";".join(f"{d}:{v:.0f}" for v, d in sorted(tops, reverse=True)[:4])})
contract_rows.sort(key=lambda r: -r["usd"])
known_usd = sum(r["usd"] for r in contract_rows)
hard_usd = sum(r["usd"] for r in contract_rows if "hard-usd" in r["class"])
major_usd = sum(r["usd"] for r in contract_rows if "major" in r["class"])
arch_usd = sum(r["usd"] for r in contract_rows if r["class"] == "arch")

with open(os.path.join(D, "top_contracts.csv"), "w", newline="") as f:
    w = csv.DictWriter(f, fieldnames=["addr", "label", "admin", "usd", "class", "top"])
    w.writeheader()
    for r in contract_rows[:400]:
        w.writerow(r)

# ---- groups by label ----
def group(pred):
    out = []
    for a, i in infos.items():
        if pred(i):
            u = next((r["usd"] for r in contract_rows if r["addr"] == a), 0.0)
            out.append({"addr": a, "label": i.get("label"), "admin": i.get("admin"), "usd": u})
    return out

astro = group(lambda i: "astrovault" in (i.get("label") or "").lower())
gov_contracts = group(lambda i: gov_addr and i.get("admin") == gov_addr)
gov_contracts_usd = sum(x["usd"] for x in gov_contracts)

# ---- module balances ----
mod_usd = {}
for addr, m in modb.items():
    v = 0.0
    for b in m.get("balances", []) or []:
        u, _ = usd_of(b["denom"], float(b["amount"]))
        if u:
            v += u
    mod_usd[m.get("name") or addr] = {"addr": addr, "usd_known": round(v, 2)}

# ---- osmosis exit liquidity ----
osmo_rows = []
for p in osmo.get("gamm", []) or []:
    v = 0.0; desc = []
    for a in p.get("assets", []):
        if a["denom"] == osmo.get("arch_denom"):
            continue
        u, _ = usd_of(a["denom"], float(a["amount"]))
        desc.append({"denom": a["denom"], "amount": a["amount"], "usd": u})
        v += u or 0
    osmo_rows.append({"id": p["id"], "other_side_usd": round(v, 2), "assets": desc})
osmo_gamm_usd = sum(r["other_side_usd"] for r in osmo_rows)

# ---- capture model ----
quorum_arch = aarch(bonded) * quorum
cap = {
    "bonded_arch": aarch(bonded), "not_bonded_arch": aarch(not_bonded),
    "supply_arch": aarch(supply), "arch_price_usd": ARCH,
    "bonded_usd": round(aarch(bonded) * (ARCH or 0), 2),
    "community_pool_arch": cp, "community_pool_usd": round(cp * (ARCH or 0), 2),
    "quorum": quorum, "threshold": threshold, "veto_threshold": veto,
    "voting_period_s": voting_s, "min_deposit": min_dep,
    "quorum_arch": round(quorum_arch, 3), "quorum_usd": round(quorum_arch * (ARCH or 0), 2),
    "majority_arch": round(aarch(bonded) * 0.5, 3), "majority_usd": round(aarch(bonded) * 0.5 * (ARCH or 0), 2),
    "veto_proof_arch": round(aarch(bonded) * (1 - veto), 3), "veto_proof_usd": round(aarch(bonded) * (1 - veto) * (ARCH or 0), 2),
    "gov_module_address": gov_addr,
    "gov_administered_contracts": len(gov_contracts),
    "gov_administered_contracts_usd": round(gov_contracts_usd, 2),
}
cap["treasury_module_usd"] = mod_usd.get("treasury", {}).get("usd_known", 0)
model = {
    "height": core.get("height"),
    "prices": {"ARCH": ARCH, "OSMO": OSMO, "USDC": USDC, "ATOM": ATOM, "extra": extra_prices},
    "capture": cap,
    "code31": (load("code31_summary.json") or {}),
    "contracts": {
        "n_codes": len(load("codes.json") or []),
        "n_contracts": len(infos),
        "n_with_value": len(contract_rows),
        "known_value_usd": round(known_usd, 2),
        "hard_usd_assets_usd": round(hard_usd, 2),
        "major_assets_usd": round(major_usd, 2),
        "arch_in_contracts_usd": round(arch_usd, 2),
        "top_denoms": sorted(({"denom": d, **v} for d, v in denom_agg.items()), key=lambda x: -x["usd"])[:30],
        "gov_administered": gov_contracts[:20],
        "astrovault_contracts": len(astro), "astrovault_usd": round(sum(x["usd"] for x in astro), 2),
    },
    "module_balances_usd": mod_usd,
    "osmosis": {"arch_denom": osmo.get("arch_denom"), "gamm_pools": osmo_rows,
                "gamm_other_side_usd": round(osmo_gamm_usd, 2),
                "cl_pool_ids": [p["id"] for p in osmo.get("cl", []) or []]},
    "node_evidence": nodes,
}
model["bounds"] = {
    "E_U_mint_and_dump_hard_assets_usd": round(hard_usd + major_usd, 2),
    "E_U_mint_and_dump_osmosis_usd": round(osmo_gamm_usd, 2),
    "E_U_mint_and_dump_total_measured_usd": round(hard_usd + major_usd + osmo_gamm_usd, 2),
    "gov_capture_immediate_usd": round(cap["community_pool_usd"] + gov_contracts_usd, 2),
    "total_wasm_contract_known_usd": round(known_usd, 2),
}
with open(os.path.join(D, "model.json"), "w") as f:
    json.dump(model, f, indent=1)
print(json.dumps(model["bounds"], indent=1))
print("capture:", json.dumps(cap, indent=1)[:1200])
print("contracts:", json.dumps(model["contracts"], indent=1)[:1200])
print("module:", json.dumps(mod_usd, indent=1)[:800])
print("osmosis gamm:", json.dumps(osmo_rows, indent=1)[:800])
