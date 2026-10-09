#!/usr/bin/env python3
"""
C2-31 Nolus (pirin-1) governance-capture model.

Reads raw on-chain reads (JSON) from a raw/ directory and computes:
  1. gov params / staking / CP facts
  2. capture-cost scenarios with the standard corrections
     (own stake in quorum denominator; validator blocs / veto; float depth)
  3. gov-movable asset inventory (CP, treasury, LPP vaults, module accounts)
  4. net cost vs proceeds scenarios

Usage: python3 model.py <raw_dir> <out_dir> [price_nls_usd]
Default price is taken from <raw_dir>/coingecko_nolus.json if present.

Read-only; no secrets. All inputs are public chain reads / public APIs.
"""
import json, sys, os
from decimal import Decimal

RAW = sys.argv[1] if len(sys.argv) > 1 else "raw"
OUT = sys.argv[2] if len(sys.argv) > 2 else "."

def load(name, default=None):
    p = os.path.join(RAW, name)
    try:
        with open(p) as f:
            return json.load(f)
    except Exception:
        return default

# ---------------------------------------------------------------- facts
node = load("node_info.json") or {}
app_ver = (node.get("application_version") or {}).get("version", "0.8.6")
sdk_ver = (node.get("application_version") or {}).get("cosmos_sdk_version", "v0.53.3-nolus-4")

pool = load("staking_pool.json") or {}
BONDED = int(pool.get("pool", {}).get("bonded_tokens", 212518285802600))
NOT_BONDED = int(pool.get("pool", {}).get("not_bonded_tokens", 57403690086521))

cp = load("community_pool.json") or {}
CP = {c["denom"]: float(c["amount"]) for c in cp.get("pool", [])}

supply = load("supply.json") or {}
SUPPLY = {c["denom"]: float(c["amount"]) for c in supply.get("supply", [])}

vals = load("validators.json") or {}
VLIST = vals.get("validators", [])
VTOT = sum(int(v["tokens"]) for v in VLIST)
V_TOP1 = max((int(v["tokens"]) for v in VLIST), default=0)
V_TOP3 = sum(sorted((int(v["tokens"]) for v in VLIST), reverse=True)[:3])
V_TOP5 = sum(sorted((int(v["tokens"]) for v in VLIST), reverse=True)[:5])
N_VALS = len(VLIST)

props = load("gov_props_all.json") or {}
# CI variant: list form + single prop file
if not props:
    lst = (load("gov_props.json") or {}).get("proposals", [])
    props = {str(p.get("id")): {"proposal": p} for p in lst}
if not props.get("295"):
    p295 = load("prop_295.json") or {}
    if p295.get("proposal"):
        props["295"] = p295
# empirical opposition: hostile scam proposal 295 (rejected, 162.3M NLS NoWithVeto)
PROP295 = (props.get("295") or {}).get("proposal", {})
T295 = PROP295.get("final_tally_result", {})
EMP_NWV = int(T295.get("no_with_veto_count", 162331398467336))
# turnout stats over all proposals
turnouts = []
for pid, dd in props.items():
    ft = (dd.get("proposal") or {}).get("final_tally_result") or {}
    tot = sum(int(ft.get(k, 0) or 0) for k in ("yes_count", "no_count", "abstain_count", "no_with_veto_count"))
    if tot > 0:
        turnouts.append(tot)
turnouts.sort()
MED_TURNOUT = turnouts[len(turnouts) // 2] if turnouts else 150082950000000

# ---------------------------------------------------------------- price
cg = load("coingecko_nolus.json") or {}
PRICE = float(sys.argv[3]) if len(sys.argv) > 3 else float(
    ((cg.get("market_data") or {}).get("current_price") or {}).get("usd", 0.00364916) or 0.00364916)
VOL24 = float(((cg.get("market_data") or {}).get("total_volume") or {}).get("usd", 62403) or 62403)

# carried-token USD prices (public references; conservative round numbers)
P_SOL = 150.0
P_BTC = 60000.0
P_WETH = 2500.0

def usd(denom, amount_raw):
    """USD value of a raw bank balance for known denoms (decimals applied)."""
    P = {
        "unls": (6, PRICE),
        "ibc/18161D8EFBD00FF5B7683EF8E923B8913453567FBE3FB6672D75712B0DEB6682": (6, 0.99964),   # USDC noble
        "ibc/F5FABF52B54E65064B57BF6DBD8E5FAD22CEE9F4B8A57ADBB20CCD0173AA72A4": (6, 0.99964),   # USDC (osmosis->noble)
        "ibc/7FBDBEEEBA9C50C4BCDF7BF438EAB99E64360833D240B32655C96E319559E911": (6, 0.99964),   # axlUSDC
        "ibc/6CDD4663F2F09CD62285E2D45891FC149A3568E316CE3EBBE201A71A78A69388": (6, 1.88),      # ATOM
        "ibc/ED07A3391A112B175915CD8FAF43A2DA8E4790EDE12566649D0C2F97716B8518": (6, 0.0341138), # OSMO
        "ibc/3D6BC6E049CAEB905AC97031A42800588C58FB471EBDC7A3530FFCD0C3DC9E09": (6, 0.00056446),# NTRN
        "ibc/32B15E261477BD3A14EE91726C48E49FDF8DDF54970E3652A1C48CD42FE3E084": (9, P_SOL),     # SOL (solray carrier)
        "ibc/3E507F7BA8D40C5CDFFB74234444ECEB6889562B82DE70E70F9EA8DE16B3D452": (6, 0.99964),   # USDC (solray carrier)
        "ibc/3503E534494C431F5CD534800B5A78D49C5BF87549AF565DC50CBA37307880F4": (8, P_BTC),     # cbBTC (solray)
        "ibc/1F7E4E6396A1BE5B47F2BA3C20B8C6C95538EF0142F4A795C12876E26C5FB1A3": (8, P_WETH),    # WETH (solray)
    }
    if denom not in P:
        return None
    dec, p = P[denom]
    return amount_raw / (10 ** dec) * p

# ---------------------------------------------------------------- contracts
contracts = load("contracts_all.json") or {}
inv = []
tot_contract_usd = 0.0
for addr, v in contracts.items():
    ci = (v.get("info") or {}).get("contract_info", {})
    label = ci.get("label", "?")
    bals = (v.get("balances") or {}).get("balances", [])
    rows = []
    cusd = 0.0
    for b in bals:
        amt = float(b["amount"])
        if amt <= 0:
            continue
        u = usd(b["denom"], amt)
        rows.append({"denom": b["denom"], "amount": amt, "usd": u})
        if u:
            cusd += u
    if rows:
        inv.append({"address": addr, "label": label, "code_id": ci.get("code_id"), "usd": round(cusd, 2), "balances": rows})
        tot_contract_usd += cusd
inv.sort(key=lambda x: -x["usd"])

# known big pots
treasury = next((x for x in inv if x["label"] == "treasury"), None)
lpps = [x for x in inv if x["label"].endswith("lpp") or x["label"] == "lpp"]
reserves = [x for x in inv if "reserve" in x["label"].lower()]

# ---------------------------------------------------------------- market depth
mexc = load("mexc_depth.json") or {}
asks = sorted((float(p), float(q)) for p, q in mexc.get("asks", []))
bids = sorted(((float(p), float(q)) for p, q in mexc.get("bids", [])), reverse=True)

def walk(levels, target):
    qty = cost = 0.0
    for p, q in levels:
        take = min(q, target - qty)
        qty += take; cost += take * p
        if qty >= target:
            break
    return qty, cost

MID = 0.003684
def depth_within(mult):
    return sum(q for p, q in asks if p <= MID * mult)

depth = {
    "mexc_bid_usd_total": sum(p * q for p, q in bids),
    "mexc_ask_nls_total": sum(q for p, q in asks),
    "mexc_ask_usd_top30": sum(p * q for p, q in asks[:30]),
    "mexc_ask_nls_within_2x": depth_within(2.0),
    "mexc_ask_nls_within_10x": depth_within(10.0),
    "nls_24h_volume_usd": VOL24,
}

# ---------------------------------------------------------------- capture models
Q = 0.334; TH = 0.5; V = 0.334
B0 = BONDED / 1e6  # whole NLS

scen = {}
scen["naive_claim_quorum_x_bonded"] = {
    "nls": Q * B0, "usd_spot": Q * B0 * PRICE,
    "note": "campaign-claim basis (33.4% of bonded, spot) - ignores own-stake denominator"
}
A_floor = B0 * Q / (1 - Q)
scen["quorum_floor_own_stake_corrected"] = {
    "nls": A_floor, "usd_spot": A_floor * PRICE,
    "bonded_after": B0 + A_floor,
    "note": "attacker votes alone; own stake raises the quorum denominator"
}
A_thr = 0.8 * B0
scen["opposition_threshold_80pct_turnout"] = {
    "nls": A_thr, "usd_spot": A_thr * PRICE,
    "note": "needs Yes>50% vs non-attacker votes cast at 80% of current bonded"
}
A_veto = 2.0 * EMP_NWV / 1e6
scen["empirical_nwv_veto_survival"] = {
    "nls": A_veto, "usd_spot": A_veto * PRICE,
    "nwv_observed": EMP_NWV / 1e6,
    "note": "survive NoWithVeto=162.33M (prop 295 scam; 76% of bonded): A >= 2x NWV"
}
A_veto_all = 2.0 * (0.8 * B0)
scen["all_validators_nwv_80pct_turnout"] = {
    "nls": A_veto_all, "usd_spot": A_veto_all * PRICE,
    "note": "worst realistic case: entire non-attacker bonded votes NWV at 80% turnout"
}
# depth-adjusted acquisition estimates
for name, a in (("floor", A_floor), ("empirical_veto", A_veto)):
    scen[f"acquisition_{name}_depth_note"] = {
        "nls": a,
        "days_at_20pct_of_daily_volume": (a * PRICE) / (0.2 * VOL24) if VOL24 else None,
        "days_at_100pct_of_daily_volume": (a * PRICE) / VOL24 if VOL24 else None,
        "mexc_visible_ask_multiple": a / depth["mexc_ask_nls_total"] if depth["mexc_ask_nls_total"] else None,
        "usd_spot": a * PRICE,
        "usd_stress_3x_slippage": a * PRICE * 3,
        "usd_stress_10x_slippage": a * PRICE * 10,
    }

# ---------------------------------------------------------------- proceeds
cp_other = {d: a for d, a in CP.items() if d != "unls"}
# NOTE: community_pool amounts are base units (DecCoins). For IBC denoms these are
# micro-units: the CP's non-NLS balances are dust (~$0.03). Cross-checked against the
# distribution module account bank balance (CP + fee pool).
cp_other_usd = sum(usd(d, a) or 0 for d, a in cp_other.items())
cp_nls = CP.get("unls", 0) / 1e6
treasury_nls = 0.0
treasury_other_usd = 0.0
if treasury:
    for b in treasury["balances"]:
        if b["denom"] == "unls":
            treasury_nls = b["amount"] / 1e6
        elif b["usd"]:
            treasury_other_usd += b["usd"]

lpp_usd = 0.0
lpp_nls = 0.0
lpp_rows = []
for x in lpps:
    for b in x["balances"]:
        if b["usd"]:
            lpp_usd += b["usd"]
            lpp_rows.append({"contract": x["label"], "denom": b["denom"][:24], "amount": b["amount"], "usd": round(b["usd"], 2)})

reserve_usd = sum((b["usd"] or 0) for x in reserves for b in x["balances"])

gov_movable_nominal = cp_nls * PRICE + cp_other_usd + treasury_nls * PRICE + treasury_other_usd + lpp_usd + reserve_usd
gov_movable_liquid = cp_other_usd + treasury_other_usd + lpp_usd + reserve_usd
nls_tokens_in_pots = cp_nls + treasury_nls

# NLS liquidation scenarios (slow sale into a $62k/day market)
nls_sale = {}
for avg_p in (0.0015, 0.001, 0.0005):
    nls_sale[f"avg_{avg_p}"] = {"usd": nls_tokens_in_pots * avg_p, "avg_price": avg_p,
                                "discount_vs_spot": 1 - avg_p / PRICE}
nls_sale["note"] = ("392.0M NLS = 42% of total supply; MEXC bid depth is ~$1.9k and all-venue 24h volume "
                    "$62.4k; immediate market sale recovers ~$2k. Slow-sale scenarios assume the price does not "
                    "collapse further while 42% of supply is distributed.")

# ---------------------------------------------------------------- net
net = {
    "capital_path_floor_spot": {"cost": scen["quorum_floor_own_stake_corrected"]["usd_spot"],
                                "liquid_proceeds": round(gov_movable_liquid, 2),
                                "net_vs_liquid_only": round(gov_movable_liquid - scen["quorum_floor_own_stake_corrected"]["usd_spot"], 2),
                                "note": "proceeds in NLS are not liquidatable at spot"},
    "capital_path_empirical_veto_spot": {"cost": scen["empirical_nwv_veto_survival"]["usd_spot"],
                                         "liquid_proceeds": round(gov_movable_liquid, 2),
                                         "net_vs_liquid_only": round(gov_movable_liquid - scen["empirical_nwv_veto_survival"]["usd_spot"], 2)},
    "capital_path_floor_stress3x": {"cost": scen["acquisition_floor_depth_note"]["usd_stress_3x_slippage"],
                                    "net_vs_liquid_only": round(gov_movable_liquid - scen["acquisition_floor_depth_note"]["usd_stress_3x_slippage"], 2)},
    "deception_path": {
        "capital_required_usd": 200 * PRICE * 2,
        "note": ("two disguised proposals (1: wasm MsgUpdateParams -> open code upload; attacker stores malicious code; "
                 "2: MsgPinCodes + MsgSudoContract(Admin, migrate_contracts with explicit code_id) -> migrate treasury/LPP "
                 "to malicious code). Versioning checks are self-attested by the target code, so a malicious contract can "
                 "satisfy them. Requires validators to vote Yes on proposals they historically approve 100% Yes "
                 "(99/100 passed; all migrations 100% Yes). Mechanics proven on-chain; success depends on validator diligence."),
        "liquid_proceeds_usd": round(gov_movable_liquid, 2),
        "nls_nominal_usd": round(nls_tokens_in_pots * PRICE, 2),
    },
}

# ---------------------------------------------------------------- output
out = {
    "finding": "C2-31",
    "chain": "pirin-1 (Nolus)",
    "app_version": app_ver,
    "sdk": sdk_ver,
    "price_nls_usd": PRICE,
    "facts": {
        "bonded_nls": B0, "not_bonded_nls": NOT_BONDED / 1e6,
        "total_supply_nls": SUPPLY.get("unls", 0) / 1e6,
        "validators": N_VALS, "top1_nls": V_TOP1 / 1e6, "top3_nls": V_TOP3 / 1e6, "top5_nls": V_TOP5 / 1e6,
        "median_turnout_nls": MED_TURNOUT / 1e6,
        "empirical_nwv_nls": EMP_NWV / 1e6,
        "gov": {"quorum": Q, "threshold": TH, "veto": V, "voting_days": 3, "min_deposit_nls": 200},
    },
    "market_depth": depth,
    "capture_scenarios": scen,
    "gov_movable": {
        "cp_nls": cp_nls, "cp_other_usd": round(cp_other_usd, 2),
        "treasury_nls": treasury_nls, "treasury_other_usd": round(treasury_other_usd, 2),
        "lpp_carried_usd": round(lpp_usd, 2), "lpp_rows": lpp_rows,
        "reserves_usd": round(reserve_usd, 2),
        "nominal_total_usd": round(gov_movable_nominal, 2),
        "liquid_total_usd": round(gov_movable_liquid, 2),
        "nls_tokens_in_pots": nls_tokens_in_pots,
    },
    "nls_liquidation": nls_sale,
    "net": net,
    "contract_inventory_top": inv[:15],
    "contract_inventory_total_usd": round(tot_contract_usd, 2),
}
os.makedirs(OUT, exist_ok=True)
with open(os.path.join(OUT, "capture_model.json"), "w") as f:
    json.dump(out, f, indent=1)
with open(os.path.join(OUT, "asset_inventory.json"), "w") as f:
    json.dump(inv, f, indent=1)

# console summary
print(f"NLS spot ${PRICE:.6f} | bonded {B0/1e6:.2f}M NLS | 24h vol ${VOL24:,.0f}")
print(f"CP: {cp_nls:,.0f} NLS + ${cp_other_usd:.4f} dust | treasury {treasury_nls:,.0f} NLS | LPP carried ${lpp_usd:,.0f}")
print(f"gov-movable nominal ${gov_movable_nominal:,.0f} | liquid ${gov_movable_liquid:,.0f}")
print("capture costs (spot):")
for k, v in scen.items():
    if "usd_spot" in v:
        print(f"  {k:42s} {v['nls']/1e6:9.2f}M NLS  ${v['usd_spot']:,.0f}")
print(f"depth: mexc ask total {depth['mexc_ask_nls_total']/1e6:.3f}M NLS | within 2x {depth['mexc_ask_nls_within_2x']/1e6:.3f}M | bids ${depth['mexc_bid_usd_total']:,.0f}")
