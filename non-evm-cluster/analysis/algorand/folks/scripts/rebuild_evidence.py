"""Rebuild the evidence set after workspace loss (read-only, keyless)."""
import base64
import json
import os
import sys
import time
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))          # .../algorand/folks/scripts
FOLKS = os.path.dirname(HERE)                              # .../algorand/folks
ALG = os.path.dirname(FOLKS)                               # .../algorand
sys.path.insert(0, os.path.join(ALG, "scripts"))
import algo_lib as A  # noqa: E402

RAW = os.path.join(FOLKS, "raw")
os.makedirs(RAW, exist_ok=True)

V1 = {
    686498781: {"und": 0, "f": 686505742, "fr": 686505743, "lbl": "v1_pool_ALGO"},
    794055220: {"und": 793124631, "f": 794060802, "fr": 794060803, "lbl": "v1_pool_gALGO"},
    686500029: {"und": 31566704, "f": 686508050, "fr": 686508051, "lbl": "v1_pool_USDC"},
    686500844: {"und": 312769, "f": 686509463, "fr": 686509464, "lbl": "v1_pool_USDt"},
    686501760: {"und": 386192725, "f": 686510134, "fr": 686510135, "lbl": "v1_pool_goBTC"},
    694405065: {"und": 386195940, "f": 694408528, "fr": 694408529, "lbl": "v1_pool_goETH"},
    694464549: {"und": 694432641, "f": 694474015, "fr": 694474016, "lbl": "v1_pool_gALGO3"},
    805843312: {"und": 794948880, "f": 805848419, "fr": 805848420, "lbl": "v1_pool_TMP11_USDCgALGO"},
    805846536: {"und": 794882756, "f": 805848550, "fr": 805848551, "lbl": "v1_pool_PLP_ALGOgALGO"},
    743679535: {"und": 694683000, "f": 743689704, "fr": 743689705, "lbl": "v1_pool_TMP11_ALGOgALGO3"},
    743685742: {"und": 701364134, "f": 743689819, "fr": 743689820, "lbl": "v1_pool_PLP_ALGOgALGO3"},
    747237154: {"und": 552647097, "f": 747244426, "fr": 747244427, "lbl": "v1_pool_TMP11_ALGOUSDC"},
    747239433: {"und": 620996279, "f": 747244580, "fr": 747244581, "lbl": "v1_pool_PLP_ALGOUSDC"},
    776179559: {"und": 552888874, "f": 776184808, "fr": 776184809, "lbl": "v1_pool_TMP11_USDCUSDt"},
    776176449: {"und": 701273234, "f": 776185076, "fr": 776185077, "lbl": "v1_pool_PLP_USDCUSDt"},
    751285119: {"und": 27165954, "f": 751289888, "fr": 751289889, "lbl": "v1_pool_Planets"},
    818026112: {"und": 807805560, "f": 818036525, "fr": 818036526, "lbl": "v1_pool_PLP_goBTCgALGO"},
    818028354: {"und": 807804381, "f": 818036407, "fr": 818036408, "lbl": "v1_pool_PLP_goETHgALGO"},
}
SPECIALS = {
    956833333: "v1_oracle", 751277258: "v1_oracle_adapter", 793119270: "galgo_govdist4",
    887391617: "galgo_govdist5a", 902731930: "galgo_govdist5b", 991196662: "galgo_govdist6",
    1073098885: "galgo_govdist7", 1136393919: "galgo_govdist8", 1200551652: "galgo_govdist9",
    1282254855: "galgo_govdist10", 1702641473: "galgo_govdist11", 2057814942: "galgo_govdist12",
    2330032485: "galgo_govdist13", 2629511242: "galgo_govdist14", 793119194: "galgo_dispenser",
    1134695678: "xalgo_consensus", 2633147490: "xalgo_stake_deposit", 1093729103: "v2_deposit_staking",
    971350278: "v2_pool_manager", 971353536: "v2_deposits", 971368268: "v2_pool_ALGO",
    971372237: "v2_pool_USDC", 2611131944: "v2_pool_xALGO", 3184317016: "v2_pool_ECO_ALGO",
    1202382736: "v2_loan_ultraswap_up", 1202382829: "v2_loan_ultraswap_down", 3184333108: "v2_loan_eco",
    971388781: "v2_loan_general", 1040271396: "v2_oracle0", 971323141: "v2_oracle1", 971333964: "v2_oracle_adapter",
    3343137163: "v2_pool_ECO_FOLKS", 3514794123: "v2_pool_WBTC_NTT", 3514795114: "v2_pool_WETH_NTT",
    1067289273: "v2_pool_WBTC_old", 1067289481: "v2_pool_WETH_old",
}

round_now = A.algod_get("/status")["last-round"]
print("round:", round_now, flush=True)
summary = {"fetched_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()), "algod_round": round_now, "apps": []}

allapps = {**{k: v["lbl"] for k, v in V1.items()}, **SPECIALS}
for i, (aid, lbl) in enumerate(sorted(allapps.items())):
    rec = {"id": aid, "label": lbl}
    try:
        d = A.get_app(aid)
        p = d["params"]
        rec["creator"] = p.get("creator")
        rec["global_state"] = A.decode_global_state(p.get("global-state", []))
    except Exception as e:  # noqa: BLE001
        rec["app_error"] = str(e)[:200]
    try:
        rec["escrow_address"] = A.app_address(aid)
        acc = A.get_account(rec["escrow_address"])
        rec["escrow_microalgos"] = acc["amount"]
        rec["escrow_assets"] = [{"asset_id": x["asset-id"], "amount": x["amount"], "is_frozen": x.get("is-frozen", False)}
                                for x in acc.get("assets", [])]
    except Exception as e:  # noqa: BLE001
        rec["escrow_error"] = str(e)[:200]
    summary["apps"].append(rec)
    with open(os.path.join(RAW, f"app_{aid}.json"), "w") as f:
        json.dump(rec, f, indent=1)
    if i % 10 == 0:
        print(i, aid, lbl, flush=True)
json.dump(summary, open(os.path.join(RAW, "folks_escrow_summary.json"), "w"), indent=1)

# TEAL evidence
for aid, name in ((686498781, "folks_v1_algo_teal"), (956833333, "folks_v1_oracle_teal"), (2629511242, "folks_govdist14_teal")):
    try:
        teal = A.disassemble(A.get_app(aid)["params"]["approval-program"])
        open(os.path.join(RAW, f"{name}_{aid}.txt"), "w").write(teal)
        print("teal", aid, "saved", flush=True)
    except Exception as e:  # noqa: BLE001
        print("teal", aid, "ERR", str(e)[:100])

# asset info cache + prices
cache = {}
NEED = [0] + [m["und"] for m in V1.values()] + [m["f"] for m in V1.values()] + [m["fr"] for m in V1.values()] + \
       [971381860, 971384592, 971383839, 2611138444, 31566704, 312769, 386192725, 386195940, 793124631,
        1134696561, 2200000000, 1058926737, 887406851, 3495558025, 3495722210, 3203964481]
for aid in sorted(set(NEED)):
    if aid == 0:
        continue
    try:
        p = A.get_asset(aid)["asset"]["params"]
        cache[str(aid)] = {"decimals": p.get("decimals", 0), "total": p.get("total"),
                           "unit": p.get("unit-name"), "name": p.get("name")}
    except Exception as e:  # noqa: BLE001
        cache[str(aid)] = {"error": str(e)[:100]}
json.dump(cache, open(os.path.join(RAW, "asset_info_cache.json"), "w"), indent=1)

# prices
ids = ["coingecko:algorand"] + [f"algorand:{a}" for a in (31566704, 312769, 386192725, 386195940, 793124631,
       694432641, 27165954, 1134696561, 1058926737, 887406851, 3203964481)]
url = "https://coins.llama.fi/prices/current/" + ",".join(ids)
req = urllib.request.Request(url, headers={"User-Agent": "research/1.0"})
with urllib.request.urlopen(req, timeout=30) as r:
    prices = {k: v.get("price") for k, v in json.loads(r.read()).get("coins", {}).items()}
json.dump(prices, open(os.path.join(RAW, "prices_2026-10-10.json"), "w"), indent=1)
algo_px = prices.get("coingecko:algorand")

# v1 analysis
byid = {a["id"]: a for a in summary["apps"]}
rows = []
tot = {"escrow_usd": 0.0, "redeemable_usd": 0.0, "stuck_usd": 0.0}
for aid, m in V1.items():
    app = byid[aid]
    gs = app.get("global_state", {})
    dii = int(gs.get("deposit_interest_index", 10**14))
    td = int(gs.get("total_deposits", 0))
    tb = int(gs.get("total_borrows", 0))
    paused = int(gs.get("is_paused", 0))
    dec = 6 if m["und"] != 386192725 and m["und"] != 386195940 and m["und"] != 1058926737 and m["und"] != 887406851 else 8
    if m["und"] == 287867876:
        dec = 10
    finfo = cache.get(str(m["f"]), {})
    cap = finfo.get("total") or 0
    hold = next((x["amount"] for x in app.get("escrow_assets", []) if x["asset_id"] == m["f"]), 0)
    f_out = cap - hold
    esc = app.get("escrow_microalgos", 0) if m["und"] == 0 else \
        next((x["amount"] for x in app.get("escrow_assets", []) if x["asset_id"] == m["und"]), 0)
    esc_units = esc / (1e6 if m["und"] == 0 else 10 ** dec)
    td_units = td / 10 ** dec
    p = algo_px if m["und"] == 0 else prices.get(f"algorand:{m['und']}")
    row = {"app_id": aid, "label": m["lbl"], "underlying_asset": m["und"],
           "escrow_raw": esc, "escrow_units": esc_units, "escrow_usd": round(esc_units * p, 2) if p else None,
           "total_deposits_units": td_units, "total_borrows_units": tb / 10 ** dec,
           "f_out_units": f_out / 10 ** dec, "dii": dii,
           "redeemable_units": min(td_units, esc_units), "stuck_units": max(esc_units - td_units, 0),
           "redeemable_usd": round(min(td_units, esc_units) * p, 2) if p else None,
           "stuck_usd": round(max(esc_units - td_units, 0) * p, 2) if p else None,
           "is_paused": paused, "price_usd": p}
    rows.append(row)
    for k in ("escrow_usd", "redeemable_usd", "stuck_usd"):
        tot[k] += row[k] or 0
json.dump({"round": round_now, "algo_px": algo_px, "v1": rows, "totals": tot},
          open(os.path.join(RAW, "folks_v1_analysis.json"), "w"), indent=1)
print("TOTALS:", json.dumps(tot), flush=True)
for r in rows:
    print(f'{r["app_id"]} {r["label"]:26s} escrow={r["escrow_units"]:.6f} ${r["escrow_usd"]} td={r["total_deposits_units"]:.6f} redeem=${r["redeemable_usd"]} stuck=${r["stuck_usd"]} paused={r["is_paused"]}')
for a in summary["apps"]:
    if a["label"].startswith(("galgo", "xalgo", "v2_deposit")):
        print(a["label"], a["id"], "algo_raw", a["escrow_microalgos"], "assets", [(x["asset_id"], x["amount"]) for x in a.get("escrow_assets", [])][:2])
print("DONE")
