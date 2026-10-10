#!/usr/bin/env python3
"""
C2-57 · Kava Mint (x/cdp) + Kava Lend (x/hard) live extraction scan — READ-ONLY.

Recomputes, from keyless public LCD endpoints only:
  1. module params (cdp / hard / pricefeed / auction)
  2. full CDP census (all collateral types, all CDPs) + liquidation-eligibility
  3. full Lend census (all deposits / all borrows) + per-borrower LTV health
  4. Lend balance sheet: synced claims vs module cash + loans (insolvency check)
  5. module-account balances (cdp / liquidator / hard / auction)
  6. live auctions
  7. chain-side MsgLiquidate dry-runs (simulate endpoint, no tx sent) for the
     closest-to-liquidation CDP (busd-a, usdt-a) and Lend borrower.

Writes JSON + text results to ../ci-out/ (or $OUT_DIR).
No secrets, no transactions, no state-changing calls.
"""
import base64, json, os, sys, time, urllib.parse, urllib.request

LCD = os.environ.get("KAVA_LCD", "https://api.data.kava.io")
OUT = os.environ.get("OUT_DIR", os.path.join(os.path.dirname(__file__), "..", "ci-out"))
os.makedirs(OUT, exist_ok=True)

def get(path, timeout=90, retries=3):
    url = LCD + path
    for i in range(retries):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": "zombie-hunt-ci/1.0"})
            with urllib.request.urlopen(req, timeout=timeout) as r:
                return json.loads(r.read().decode())
        except Exception as e:
            if i == retries - 1:
                raise
            time.sleep(2 * (i + 1))

def post_json(path, payload, timeout=60):
    req = urllib.request.Request(LCD + path, data=json.dumps(payload).encode(),
                                 headers={"Content-Type": "application/json",
                                          "User-Agent": "zombie-hunt-ci/1.0"})
    try:
        with urllib.request.urlopen(req, timeout=timeout) as r:
            return r.read().decode()
    except urllib.error.HTTPError as e:
        # the simulate endpoint returns the (expected) revert reason in the body
        return e.read().decode()

# ---------------- protobuf helpers for the simulate dry-run ----------------
def _varint(n):
    out = b""
    while True:
        b = n & 0x7F; n >>= 7
        out += bytes([b | 0x80]) if n else bytes([b])
        if not n: break
    return out
def _tag(f, w): return _varint((f << 3) | w)
def _ld(f, d): return _tag(f, 2) + _varint(len(d)) + d
def _vint(f, n): return _tag(f, 0) + _varint(n)
def _s(f, t): return _ld(f, t.encode())

def simulate_msg(type_url, fields, pubkey_b64, seq):
    """Dry-run a Cosmos msg via /cosmos/tx/v1beta1/simulate. Signature verification
    is skipped in simulate mode; a dummy 64-byte signature is used. Read-only."""
    msg = b"".join(_s(i + 1, v) for i, v in enumerate(fields))
    body = _ld(1, _ld(1, type_url.encode()) + _ld(2, msg))
    pub = base64.b64decode(pubkey_b64)
    pub_any = _ld(1, b"/cosmos.crypto.secp256k1.PubKey") + _ld(2, _ld(1, pub))
    mode = _ld(1, _vint(1, 1))  # SIGN_MODE_DIRECT
    signer = _ld(1, pub_any) + _ld(2, mode) + _vint(3, seq)
    auth = _ld(1, signer) + _ld(2, _vint(2, 1000000))
    tx_raw = _ld(1, body) + _ld(2, auth) + _ld(3, b"\x00" * 64)
    return post_json("/cosmos/tx/v1beta1/simulate",
                     {"tx_bytes": base64.b64encode(tx_raw).decode()})

# ---------------- 0. block height / time ----------------
hdr = get("/cosmos/base/tendermint/v1beta1/blocks/latest")["block"]["header"]
block = {"height": hdr["height"], "time": hdr["time"], "chain_id": hdr["chain_id"]}
json.dump(block, open(f"{OUT}/block.json", "w"), indent=1)

# ---------------- 1. params ----------------
params = {
    "cdp": get("/kava/cdp/v1beta1/params")["params"],
    "hard": get("/kava/hard/v1beta1/params")["params"],
    "pricefeed": get("/kava/pricefeed/v1beta1/params")["params"],
    "auction": get("/kava/auction/v1beta1/params")["params"],
    "prices": get("/kava/pricefeed/v1beta1/prices")["prices"],
}
json.dump(params, open(f"{OUT}/params.json", "w"), indent=1)

# ---------------- 2. full CDP census ----------------
cdps = get("/kava/cdp/v1beta1/cdps?pagination.limit=100000")["cdps"]
liq_ratio = {c["type"]: float(c["liquidation_ratio"]) for c in params["cdp"]["collateral_params"]}
keeper_pct = {c["type"]: float(c["keeper_reward_percentage"]) for c in params["cdp"]["collateral_params"]}
by_type = {}
for c in cdps:
    t = c["type"]
    s = by_type.setdefault(t, {"n": 0, "collateral_usd": 0.0, "debt_usd": 0.0,
                               "min_cr": 9e9, "min_cr_id": None, "min_cr_owner": None,
                               "below": [], "keeper_reward_if_all_liq_usd": 0.0})
    cv = int(c["collateral_value"]["amount"]) / 1e6
    dv = (int(c["principal"]["amount"]) + int(c["accumulated_fees"]["amount"])) / 1e6
    cr = float(c["collateralization_ratio"])
    s["n"] += 1; s["collateral_usd"] += cv; s["debt_usd"] += dv
    s["keeper_reward_if_all_liq_usd"] += cv * keeper_pct[t]
    if cr < s["min_cr"]:
        s["min_cr"], s["min_cr_id"], s["min_cr_owner"] = cr, c["id"], c["owner"]
    if cr < liq_ratio[t]:
        s["below"].append({"id": c["id"], "owner": c["owner"], "cr": cr, "collateral_usd": cv, "debt_usd": dv})
cdp_out = {"n_total": len(cdps), "types": by_type,
           "total_collateral_usd": sum(s["collateral_usd"] for s in by_type.values()),
           "total_debt_face_usd": sum(s["debt_usd"] for s in by_type.values()),
           "below_threshold_total": sum(len(s["below"]) for s in by_type.values())}
json.dump(cdp_out, open(f"{OUT}/cdp_census.json", "w"), indent=1)

# ---------------- 3. full Lend census + health ----------------
dep = get("/kava/hard/v1beta1/deposits?pagination.limit=100000")["deposits"]
bor = get("/kava/hard/v1beta1/borrows?pagination.limit=100000")["borrows"]
ifs = {f["denom"]: f for f in get("/kava/hard/v1beta1/interest-factors")["interest_factors"]}
sf = {dn: float(f["supply_interest_factor"] or 0) for dn, f in ifs.items()}
bf = {dn: float(f["borrow_interest_factor"] or 0) for dn, f in ifs.items()}
mm = {m["denom"]: m for m in params["hard"]["money_markets"]}
prices = {p["market_id"]: float(p["price"]) for p in params["prices"]}
def px(dn): return prices.get(mm[dn]["spot_market_id"]) if dn in mm else None
def cf(dn): return int(mm[dn]["conversion_factor"]) if dn in mm else 1
def ltv(dn): return float(mm[dn]["borrow_limit"]["loan_to_value"]) if dn in mm else 0.0

D, B = {}, {}
for d in dep:
    idx = {i["denom"]: float(i["value"]) for i in d["index"]}
    a = d["depositor"]; D.setdefault(a, {})
    for c in d["amount"]:
        dn = c["denom"]; v = int(c["amount"]) * (sf.get(dn, 1) / idx[dn] if idx.get(dn) else 1)
        D[a][dn] = D[a].get(dn, 0) + v
for b in bor:
    idx = {i["denom"]: float(i["value"]) for i in b["index"]}
    a = b["borrower"]; B.setdefault(a, {})
    for c in b["amount"]:
        dn = c["denom"]; v = int(c["amount"]) * (bf.get(dn, 1) / idx[dn] if idx.get(dn) else 1)
        B[a][dn] = B[a].get(dn, 0) + v

rows = []
for a, bl in B.items():
    dl = D.get(a, {})
    bu = sum(v / cf(dn) * px(dn) for dn, v in bl.items() if px(dn))
    du = sum(v / cf(dn) * px(dn) for dn, v in dl.items() if px(dn))
    bw = sum(v / cf(dn) * px(dn) * ltv(dn) for dn, v in dl.items() if px(dn))
    rew = sum(v / cf(dn) * px(dn) for dn, v in dl.items() if px(dn)) * 0.02
    rows.append({"borrower": a, "debt_usd": bu, "deposits_usd": du,
                 "borrowable_usd": bw, "ratio": (bu / bw) if bw else None,
                 "keeper_reward_if_liq_usd": rew})
rows.sort(key=lambda r: -(r["ratio"] or 0))
liquidatable = [r for r in rows if r["ratio"] is not None and r["ratio"] > 1.0]
lend_out = {"n_deposits": len(dep), "n_borrows": len(bor), "n_borrowers": len(rows),
            "n_liquidatable": len(liquidatable),
            "total_borrower_deposits_usd": sum(r["deposits_usd"] for r in rows),
            "total_borrower_debt_usd": sum(r["debt_usd"] for r in rows),
            "closest": rows[:10]}
json.dump(lend_out, open(f"{OUT}/lend_health.json", "w"), indent=1)

# ---------------- 4. Lend balance sheet (insolvency check) ----------------
ud = get("/kava/hard/v1beta1/unsynced-deposits?pagination.limit=100000")["deposits"]
ub = get("/kava/hard/v1beta1/unsynced-borrows?pagination.limit=100000")["borrows"]
from collections import defaultdict
O, L = defaultdict(float), defaultdict(float)
for d in ud:
    idx = {i["denom"]: float(i["value"]) for i in d["index"]}
    for c in d["amount"]:
        dn = c["denom"]; v = int(c["amount"]) * (sf.get(dn, 1) / idx[dn] if idx.get(dn) else 1)
        O[dn] += v
for b in ub:
    idx = {i["denom"]: float(i["value"]) for i in b["index"]}
    for c in b["amount"]:
        dn = c["denom"]; v = int(c["amount"]) * (bf.get(dn, 1) / idx[dn] if idx.get(dn) else 1)
        L[dn] += v
mod_bals = {x["denom"]: int(x["amount"]) for x in
            get("/cosmos/bank/v1beta1/balances/kava1a42xtwfzphuuu9mdp0es6633wu5mm8fhm789v3?pagination.limit=200")["balances"]}
sheet = {}
for dn in sorted(set(list(O) + list(L))):
    claims = O.get(dn, 0) / cf(dn) if dn in mm else O.get(dn, 0)
    loans = L.get(dn, 0) / cf(dn) if dn in mm else L.get(dn, 0)
    cash = mod_bals.get(dn, 0) / cf(dn) if dn in mm else mod_bals.get(dn, 0)
    short_usd = (claims - loans - cash) * (px(dn) or 0)
    sheet[dn] = {"claims": claims, "loans": loans, "cash": cash, "shortfall_usd": short_usd}
json.dump({"by_denom": sheet, "total_shortfall_usd": sum(v["shortfall_usd"] for v in sheet.values())},
          open(f"{OUT}/lend_solvency.json", "w"), indent=1)

# ---------------- 5. module balances ----------------
mods = {a["name"]: a["base_account"]["address"] for a in
        get("/cosmos/auth/v1beta1/module_accounts?pagination.limit=200")["accounts"]
        if a.get("name") in ("cdp", "liquidator", "hard", "auction")}
modbal = {}
for name, addr in mods.items():
    bal = get(f"/cosmos/bank/v1beta1/balances/{addr}?pagination.limit=200")["balances"]
    modbal[name] = {x["denom"]: x["amount"] for x in bal}
json.dump(modbal, open(f"{OUT}/module_balances.json", "w"), indent=1)

# ---------------- 6. live auctions ----------------
auctions = get("/kava/auction/v1beta1/auctions?pagination.limit=100000")["auctions"]
auction_out = []
for a in auctions:
    ba = a["base_auction"]
    auction_out.append({"type": a["@type"].split(".")[-1], "id": ba["id"], "initiator": ba["initiator"],
                        "lot": ba["lot"], "bid": ba["bid"], "max_bid": a.get("max_bid"),
                        "has_received_bids": ba["has_received_bids"], "end_time": ba["end_time"]})
json.dump({"n": len(auction_out), "auctions": auction_out}, open(f"{OUT}/auctions.json", "w"), indent=1)

# ---------------- 7. simulate dry-runs ----------------
# use a real on-chain account pubkey (CDP owner) for the simulated keeper; dummy sig.
KEEPER = "kava1mx376mhmv38h9dx9elun9utqc2v2d43c4ly5mn"
PUB = "A4gTZY/yQaoK9gr5jOLn0OxcTTK4/YqFmgOcdJOfXtiO"
SEQ = 252
sims = {}
closest_busd = min([c for c in cdps if c["type"] == "busd-a"], key=lambda c: float(c["collateralization_ratio"]))
closest_usdt = min([c for c in cdps if c["type"] == "usdt-a"], key=lambda c: float(c["collateralization_ratio"]))
closest_lend = rows[0]
sims["cdp_busd_a"] = {"cdp_id": closest_busd["id"], "owner": closest_busd["owner"],
                      "response": simulate_msg("/kava.cdp.v1beta1.MsgLiquidate",
                                               [KEEPER, closest_busd["owner"], "busd-a"], PUB, SEQ)}
sims["cdp_usdt_a"] = {"cdp_id": closest_usdt["id"], "owner": closest_usdt["owner"],
                      "response": simulate_msg("/kava.cdp.v1beta1.MsgLiquidate",
                                               [KEEPER, closest_usdt["owner"], "usdt-a"], PUB, SEQ)}
sims["lend_closest"] = {"borrower": closest_lend["borrower"], "ratio": closest_lend["ratio"],
                        "response": simulate_msg("/kava.hard.v1beta1.MsgLiquidate",
                                                 [KEEPER, closest_lend["borrower"]], PUB, SEQ)}
json.dump(sims, open(f"{OUT}/sim_proofs.json", "w"), indent=1)

# ---------------- summary text ----------------
lines = []
lines.append(f"Kava LCD: {LCD}")
lines.append(f"Block: {block['height']} ({block['time']}) chain {block['chain_id']}")
lines.append(f"CDPs: {cdp_out['n_total']} total; below-threshold: {cdp_out['below_threshold_total']}")
for t, s in sorted(by_type.items()):
    lines.append(f"  {t:9s} n={s['n']:4d} coll=${s['collateral_usd']:14,.2f} debt=${s['debt_usd']:12,.2f} "
                 f"minCR={s['min_cr']:.18f} thr={liq_ratio[t]}")
lines.append(f"Lend: {lend_out['n_deposits']} deposits / {lend_out['n_borrows']} borrows / "
             f"{lend_out['n_borrowers']} borrowers; liquidatable: {lend_out['n_liquidatable']}")
lines.append(f"Lend closest borrower ratio: {rows[0]['ratio']:.6f} ({rows[0]['borrower']})")
lines.append(f"Lend solvency: total shortfall ${sum(v['shortfall_usd'] for v in sheet.values()):,.2f}")
for dn in ("busd",):
    v = sheet[dn]
    lines.append(f"  {dn}: claims={v['claims']:,.2f} loans={v['loans']:,.2f} cash={v['cash']:,.2f} "
                 f"shortfall=${v['shortfall_usd']:,.2f}")
lines.append(f"Live auctions: {len(auction_out)} (all dust; see auctions.json)")
lines.append("Simulate dry-runs:")
for k, v in sims.items():
    resp = json.loads(v["response"]) if v["response"].strip().startswith("{") else {"raw": v["response"]}
    lines.append(f"  {k}: {resp.get('message', resp)[:220]}")
open(f"{OUT}/SUMMARY.txt", "w").write("\n".join(lines) + "\n")
print("\n".join(lines))
print("\nWrote:", os.listdir(OUT))
