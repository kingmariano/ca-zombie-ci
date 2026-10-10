"""Analyze Folks live state: v1 pools solvency/redeem-cap, special contracts, v2 pools.

Inputs: folks/raw/app_*.json (fetched), plus asset infos + DefiLlama prices.
Output: folks/raw/folks_analysis.json + folks/raw/folks_v1_pools.csv
"""
import base64
import json
import os
import sys
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
FOLKS = os.path.dirname(HERE)
RAW = os.path.join(FOLKS, "raw")
sys.path.insert(0, os.path.join(FOLKS, "..", "scripts"))
import algo_lib as A  # noqa: E402

# ---- asset info cache ----
CACHE = os.path.join(RAW, "asset_info_cache.json")
cache = json.load(open(CACHE)) if os.path.exists(CACHE) else {}


def asset_info(aid):
    key = str(aid)
    if key not in cache:
        try:
            p = A.get_asset(int(aid))["asset"]["params"]
            cache[key] = {
                "decimals": p.get("decimals", 0),
                "total": p.get("total"),
                "unit": p.get("unit-name"),
                "name": p.get("name"),
                "creator": p.get("creator"),
            }
        except Exception as e:  # noqa: BLE001
            cache[key] = {"error": str(e)[:120]}
        json.dump(cache, open(CACHE, "w"), indent=1)
    return cache[key]


# ---- prices from DefiLlama (keyless) ----
def llama_prices(ids):
    out = {}
    for i in range(0, len(ids), 20):
        chunk = ids[i:i + 20]
        url = "https://coins.llama.fi/prices/current/" + ",".join(chunk)
        req = urllib.request.Request(url, headers={"User-Agent": "research/1.0"})
        with urllib.request.urlopen(req, timeout=30) as r:
            d = json.loads(r.read())
        out.update({k: v.get("price") for k, v in d.get("coins", {}).items()})
    return out


PRICE_IDS = [
    "coingecko:algorand", "algorand:31566704", "algorand:312769", "algorand:386192725",
    "algorand:386195940", "algorand:793124631", "algorand:694432641", "algorand:27165954",
    "algorand:1134696561", "algorand:1058926737", "algorand:887406851", "algorand:684649988",
    "algorand:227855942", "algorand:246516580", "algorand:246519683", "algorand:287867876",
    "algorand:1163259470", "algorand:893309613", "algorand:887648583", "algorand:1200094857",
    "algorand:2537013734", "algorand:3203964481", "algorand:2200000000", "algorand:849556893",
]
prices = llama_prices(PRICE_IDS)
ALGO_PX = prices.get("coingecko:algorand") or 0

summary = json.load(open(os.path.join(RAW, "folks_escrow_summary.json")))
byid = {a["id"]: a for a in summary["apps"]}
round_now = summary["algod_round"]

# fAsset mapping for v1 pools (from v1 SDK + observed pre-state)
V1 = {
    686498781: {"underlying": 0, "f": 686505742, "fr": 686505743, "dec": 6},
    794055220: {"underlying": 793124631, "f": 794060802, "fr": 794060803, "dec": 6},
    686500029: {"underlying": 31566704, "f": 686508050, "fr": 686508051, "dec": 6},
    686500844: {"underlying": 312769, "f": 686509463, "fr": 686509464, "dec": 6},
    686501760: {"underlying": 386192725, "f": 686510134, "fr": 686510135, "dec": 8},
    694405065: {"underlying": 386195940, "f": 694408528, "fr": 694408529, "dec": 8},
    694464549: {"underlying": 694432641, "f": 694474015, "fr": 694474016, "dec": 6},
    805843312: {"underlying": 794948880, "f": 805848419, "fr": 805848420, "dec": 6},
    805846536: {"underlying": 794882756, "f": 805848550, "fr": 805848551, "dec": 6},
    743679535: {"underlying": 694683000, "f": 743689704, "fr": 743689705, "dec": 6},
    743685742: {"underlying": 701364134, "f": 743689819, "fr": 743689820, "dec": 6},
    747237154: {"underlying": 552647097, "f": 747244426, "fr": 747244427, "dec": 6},
    747239433: {"underlying": 620996279, "f": 747244580, "fr": 747244581, "dec": 6},
    776179559: {"underlying": 552888874, "f": 776184808, "fr": 776184809, "dec": 6},
    776176449: {"underlying": 701273234, "f": 776185076, "fr": 776185077, "dec": 6},
    751285119: {"underlying": 27165954, "f": 751289888, "fr": 751289889, "dec": 6},
    818026112: {"underlying": 807805560, "f": 818036525, "fr": 818036526, "dec": 6},
    818028354: {"underlying": 807804381, "f": 818036407, "fr": 818036408, "dec": 6},
}

# v2 pools (underlying, fAsset, frAsset) from v2 constants + docs
V2 = {
    971368268: (0, 971381860, 971381861, 6),
    971370097: (793124631, 971383839, 971383840, 6),
    2611131944: (1134696561, 2611138444, 2611138445, 6),
    3073474613: (2537013734, 3073480070, 3073480071, 6),
    971372237: (31566704, 971384592, 971384593, 6),
    971372700: (312769, 971385312, 971385313, 6),
    1060585819: (684649988, 1060587336, 1060587337, 6),
    1247053569: (227855942, 1247054501, 1247054502, 6),
    971373361: (386192725, 971386173, 971386174, 8),
    971373611: (386195940, 971387073, 971387074, 8),
    1067289273: (1058926737, 1067295154, 1067295155, 8),
    1067289481: (887406851, 1067295558, 1067295559, 8),
    1166977433: (893309613, 1166979636, 1166979637, 8),
    1166980669: (887648583, 1166980820, 1166980821, 8),
    1216434571: (1200094857, 1216437148, 1216437149, 8),
    1258515734: (246516580, 1258524377, 1258524378, 6),
    1258524099: (246519683, 1258524381, 1258524382, 6),
    1044267181: (287867876, 1044269355, 1044269356, 10),
    1166982094: (1163259470, 1166982296, 1166982297, 8),
    3184317016: (0, 3184331013, 3184331014, 6),
    3184324594: (31566704, 3184331239, 3184331240, 6),
    3184325123: (2200000000, 3184331789, 3184331790, 6),
    3343137163: (3203964481, 3343139268, 3343139269, 6),
    3514794123: (3495558025, 3514808410, 3514808411, 8),
    3514795114: (3495722210, 3514808788, 3514808789, 8),
}

ASSET_PRICE = {}
for k, v in prices.items():
    ASSET_PRICE[k.split(":")[1] if ":" in k else "0"] = v
ASSET_PRICE["0"] = ALGO_PX


def px(aid):
    if aid == 0:
        return ALGO_PX
    return prices.get(f"algorand:{aid}")


def escrow_asset(app, aid):
    for x in app.get("escrow_assets", []) or []:
        if x["asset_id"] == aid:
            return int(x["amount"])
    return 0


def one_unit(aid, dec):
    return 1 / (10 ** dec)


rows = []
tot = {"redeemable_usd": 0.0, "stuck_usd": 0.0, "escrow_usd": 0.0, "unpriced": []}

for aid, m in V1.items():
    app = byid[aid]
    gs = app.get("global_state", {})
    dii = int(gs.get("deposit_interest_index", 10**14))
    td = int(gs.get("total_deposits", 0))
    tb = int(gs.get("total_borrows", 0))
    paused = int(gs.get("is_paused", 0))
    finfo = asset_info(m["f"])
    cap = finfo.get("total") or 0
    f_in_app = escrow_asset(app, m["f"])
    f_out = cap - f_in_app if f_in_app else None
    und = m["underlying"]
    esc = app.get("escrow_microalgos", 0) if und == 0 else escrow_asset(app, und)
    dec = m["dec"]
    if und == 0:
        esc_units = esc / 1e6
    else:
        esc_units = esc / (10 ** dec)
    # nominal claim value (underlying units)
    claim_units = None
    if f_out is not None:
        claim_units = f_out / (10 ** dec) * (dii / 1e14)
    rede_units = min(td / (10 ** dec), esc_units)
    stuck_units = max(esc_units - td / (10 ** dec), 0)
    p = px(und)
    row = {
        "app_id": aid,
        "label": app.get("label"),
        "underlying_asset": und,
        "underlying_unit": asset_info(und).get("unit") if und else "ALGO",
        "escrow_raw": esc,
        "escrow_units": esc_units,
        "escrow_usd": round(esc_units * p, 2) if p else None,
        "total_deposits_units": td / (10 ** dec),
        "total_borrows_units": tb / (10 ** dec),
        "f_out_units": f_out / (10 ** dec) if f_out is not None else None,
        "dii": dii,
        "nominal_claim_units": claim_units,
        "redeem_cap_units": td / (10 ** dec),
        "redeemable_units": rede_units,
        "redeemable_usd": round(rede_units * p, 2) if p else None,
        "stuck_units": stuck_units,
        "stuck_usd": round(stuck_units * p, 2) if p else None,
        "is_paused": paused,
        "price_usd": p,
    }
    rows.append(row)
    tot["escrow_usd"] += row["escrow_usd"] or 0
    tot["redeemable_usd"] += row["redeemable_usd"] or 0
    tot["stuck_usd"] += row["stuck_usd"] or 0
    if p is None:
        tot["unpriced"].append(aid)

# save
json.dump({"round": round_now, "algo_price": ALGO_PX, "v1": rows, "totals": tot,
           "asset_price_usd": {k: v for k, v in prices.items()}},
          open(os.path.join(RAW, "folks_v1_analysis.json"), "w"), indent=1)

with open(os.path.join(RAW, "folks_v1_pools.csv"), "w") as f:
    f.write("app_id,label,underlying,escrow_units,escrow_usd,total_deposits,redeemable_usd,stuck_units,stuck_usd,f_out,paused,price_usd\n")
    for r in rows:
        f.write(",".join(str(x) for x in [
            r["app_id"], r["label"], r["underlying_unit"], round(r["escrow_units"], 6),
            r["escrow_usd"], round(r["total_deposits_units"], 6), r["redeemable_usd"],
            round(r["stuck_units"], 6), r["stuck_usd"], round(r["f_out_units"], 6) if r["f_out_units"] else "",
            r["is_paused"], r["price_usd"]]) + "\n")

print(json.dumps(tot, indent=1))
for r in rows:
    print(f'{r["app_id"]} {r["label"]:32s} escrow={r["escrow_units"]:.4f} {r["underlying_unit"]} '
          f'(${r["escrow_usd"]}) td={r["total_deposits_units"]:.4f} f_out={r["f_out_units"]:.4f} '
          f'redeem=${r["redeemable_usd"]} stuck={r["stuck_units"]:.4f} (${r["stuck_usd"]}) paused={r["is_paused"]}')
