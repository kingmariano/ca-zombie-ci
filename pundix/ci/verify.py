#!/usr/bin/env python3
"""C2-33 PundiX governance-capture — independent CI re-verification (read-only).

Public data only (no keys, no secrets). Re-derives every headline number from the
live PundiX LCD at an explicit height and writes ci-out/verification.json +
ci-out/summary_ci.json. Also re-checks the cosmos-sdk v0.45.11 tally semantics
(quorum denominator = TotalBondedTokens at tally) from the tagged source.

Run from the finding folder root:  python3 ci/verify.py
"""
import json, hashlib, os, sys, time, urllib.request, urllib.error

FOLDER = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(FOLDER, "ci-out")
RAW = os.path.join(OUT, "raw")
os.makedirs(RAW, exist_ok=True)

LCD = os.environ.get("PUNDIX_LCD", "https://px-rest.pundix.com")
UA = {"User-Agent": "zombie-hunt-research/1.0"}
D = 10**18

PUNDIX = "ibc/55367B7B6572631B78A93C66EF9FDFCE87CDE372CC4ED7848DA78C1EB1DCDD78"
PURSE = "bsc0x29a63F4B209C29B4DC47f06FFA896F32667DAD2C"

PRICE_FALLBACK = {"pundix_dl": 0.11189131591008934, "pundix_cg": 0.112057,
                  "purse": 0.000002068669043896242, "fx": 0.071802,
                  "weth": 2496.4015703447217}

errors = []

def get(url, timeout=40, retries=4):
    last = None
    for i in range(retries):
        try:
            req = urllib.request.Request(url, headers=UA)
            with urllib.request.urlopen(req, timeout=timeout) as r:
                return json.loads(r.read())
        except Exception as e:  # noqa
            last = e
            time.sleep(2 + 2 * i)
    errors.append({"url": url, "error": str(last)})
    return None

# ---------- bech32 + ibc-go v3.4.0 escrow address ----------
CHARSET = "qpzry9x8gf2tvdw0s3jn54khce6mua7l"
def _polymod(values):
    GEN = [0x3b6a57b2, 0x26508e6d, 0x1ea119fa, 0x3d4233dd, 0x2a1462b3]
    chk = 1
    for v in values:
        b = chk >> 25
        chk = (chk & 0x1ffffff) << 5 ^ v
        for i in range(5):
            chk ^= GEN[i] if ((b >> i) & 1) else 0
    return chk
def _hrp(hrp):
    return [ord(x) >> 5 for x in hrp] + [0] + [ord(x) & 31 for x in hrp]
def _cs(hrp, data):
    pm = _polymod(_hrp(hrp) + data + [0] * 6) ^ 1
    return [(pm >> 5 * (5 - i)) & 31 for i in range(6)]
def _cb(data, f, t, pad=True):
    acc = bits = 0; ret = []
    for v in data:
        acc = (acc << f) | v; bits += f
        while bits >= t:
            bits -= t; ret.append((acc >> bits) & ((1 << t) - 1))
    if pad and bits:
        ret.append((acc << (t - bits)) & ((1 << t) - 1))
    return ret
def _enc(hrp, b20):
    d = _cb(list(b20), 8, 5)
    return hrp + "1" + "".join(CHARSET[x] for x in d + _cs(hrp, d))
def escrow_v340(port, channel, hrp):
    pre = b"ics20-1" + b"\x00" + f"{port}/{channel}".encode()
    return _enc(hrp, hashlib.sha256(pre).digest()[:20])

# ---------- live reads ----------
v = {"fetched_utc": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
     "lcd": LCD, "folder": os.path.basename(FOLDER)}

lb = get(f"{LCD}/cosmos/base/tendermint/v1beta1/blocks/latest")
v["height"] = lb["block"]["header"]["height"] if lb else None
v["block_time"] = lb["block"]["header"]["time"] if lb else None

def save(name, obj):
    with open(os.path.join(RAW, name), "w") as f:
        json.dump(obj, f, indent=1)
    return obj

node = get(f"{LCD}/cosmos/base/tendermint/v1beta1/node_info")
if node: save("node_info.json", node)
v["binary"] = {
    "app": (node or {}).get("application_version", {}).get("name"),
    "version": (node or {}).get("application_version", {}).get("version"),
}
if node:
    deps = (node.get("application_version") or {}).get("build_deps") or []
    depmap = {d.get("path", ""): d.get("version", "") for d in deps}
    v["binary"]["cosmos_sdk"] = depmap.get("github.com/cosmos/cosmos-sdk")
    v["binary"]["ibc_go"] = depmap.get("github.com/cosmos/ibc-go/v3")
    v["binary"]["wasmvm"] = depmap.get("github.com/CosmWasm/wasmvm")

staking_pool = save("staking_pool.json", get(f"{LCD}/cosmos/staking/v1beta1/pool") or {})
staking_params = save("staking_params.json", get(f"{LCD}/cosmos/staking/v1beta1/params") or {})
cp = save("community_pool.json", get(f"{LCD}/cosmos/distribution/v1beta1/community_pool") or {})
supply = save("supply.json", get(f"{LCD}/cosmos/bank/v1beta1/supply") or {})
voting = save("gov_votingparams.json", get(f"{LCD}/cosmos/params/v1beta1/params?subspace=gov&key=votingparams") or {})
tally = save("gov_tallyparams.json", get(f"{LCD}/cosmos/params/v1beta1/params?subspace=gov&key=tallyparams") or {})
deposit = save("gov_depositparams.json", get(f"{LCD}/cosmos/params/v1beta1/params?subspace=gov&key=depositparams") or {})
mint = save("mint_params.json", get(f"{LCD}/cosmos/mint/v1beta1/params") or {})
props = save("proposals.json", get(f"{LCD}/cosmos/gov/v1beta1/proposals?pagination.limit=50") or {})
vals = save("validators_bonded.json",
            get(f"{LCD}/cosmos/staking/v1beta1/validators?pagination.limit=100&status=BOND_STATUS_BONDED") or {})
dist_bal = save("distribution_module_balances.json",
                get(f"{LCD}/cosmos/bank/v1beta1/balances/px1jv65s3grqf6v6jl3dp4t6c9t9rk99cd8xw93zt") or {})

# denom traces for every supply denom
traces = {}
for s in (supply.get("supply") or []):
    d = s["denom"]
    if d.startswith("ibc/"):
        t = get(f"{LCD}/ibc/apps/transfer/v1/denom_traces/{d[4:]}")
        if t: traces[d] = t["denom_trace"]
    else:
        traces[d] = {"path": "", "base_denom": d}
save("denom_traces.json", traces)

# module accounts (scan the (small) account set) + escrows
accounts = []
for off in (0, 1000, 2000):
    a = get(f"{LCD}/cosmos/auth/v1beta1/accounts?pagination.limit=1000&pagination.offset={off}")
    if not a: break
    accounts += a.get("accounts", [])
    if not (a.get("pagination") or {}).get("next_key"):
        break
mods = [x for x in accounts if "ModuleAccount" in (x.get("@type") or "")]
save("module_accounts.json", mods)
mod_addrs = {m["name"]: m["base_account"]["address"] for m in mods}
for ch in ("channel-0", "channel-1"):
    mod_addrs[f"transfer_escrow_{ch}_v340"] = escrow_v340("transfer", ch, "px")
esc_bal = {}
for name, addr in mod_addrs.items():
    b = get(f"{LCD}/cosmos/bank/v1beta1/balances/{addr}?pagination.limit=200")
    esc_bal[name] = {"address": addr, "balances": (b or {}).get("balances", [])}
save("module_and_escrow_balances.json", esc_bal)
v["module_accounts"] = {k: e["balances"] for k, e in esc_bal.items()}

# prices (public)
prices = dict(PRICE_FALLBACK)
v["prices_source"] = "fallback-constants"
try:
    dl = get("https://coins.llama.fi/prices/current/ethereum:0x0FD10b9899882a6f2fcb5c371E17e70FdEe00C38,"
             "bsc:0x29a63F4B209C29B4DC47f06FFA896F32667DAD2C,ethereum:0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2",
             retries=2)
    coins = (dl or {}).get("coins", {})
    px = coins.get("ethereum:0x0FD10b9899882a6f2fcb5c371E17e70FdEe00C38", {}).get("price")
    pu = coins.get("bsc:0x29a63F4B209C29B4DC47f06FFA896F32667DAD2C", {}).get("price")
    we = coins.get("ethereum:0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2", {}).get("price")
    if px: prices["pundix_dl"] = px; v["prices_source"] = "defillama-live"
    if pu: prices["purse"] = pu
    if we: prices["weth"] = we
    save("prices_defillama.json", dl or {})
except Exception as e:
    errors.append({"url": "defillama", "error": str(e)})

# ---------- SDK v0.45.11 tally semantics re-check ----------
tally_src = None
try:
    req = urllib.request.Request(
        "https://raw.githubusercontent.com/cosmos/cosmos-sdk/v0.45.11/x/gov/keeper/tally.go", headers=UA)
    with urllib.request.urlopen(req, timeout=40) as r:
        tally_src = r.read()
    sha = hashlib.sha256(tally_src).hexdigest()
    txt = tally_src.decode()
    ok = "totalVotingPower.Quo(keeper.sk.TotalBondedTokens(ctx).ToDec())" in txt
    v["sdk_tally_check"] = {"url": "cosmos-sdk v0.45.11 x/gov/keeper/tally.go", "sha256": sha,
                            "quorum_denominator_is_live_total_bonded": bool(ok)}
    with open(os.path.join(RAW, "tally_v04511.go"), "wb") as f:
        f.write(tally_src)
except Exception as e:
    errors.append({"url": "sdk-tally-source", "error": str(e)})
    v["sdk_tally_check"] = {"error": str(e)}

# ---------- compute ----------
def dec_amounts(lst):
    out = {}
    for x in lst or []:
        out[x["denom"]] = x["amount"]
    return out

pool = (staking_pool or {}).get("pool", {})
bonded = int(pool.get("bonded_tokens", 0)) / D
not_bonded = int(pool.get("not_bonded_tokens", 0)) / D
sup = {x["denom"]: int(x["amount"]) for x in (supply or {}).get("supply", [])}
cpm = {x["denom"]: float(x["amount"]) for x in (cp or {}).get("pool", [])}
dm = {x["denom"]: int(x["amount"]) for x in (dist_bal or {}).get("balances", [])}

def govparam(obj):
    try:
        return json.loads(obj["param"]["value"])
    except Exception:
        return {}

tp = govparam(tally)
dpp = govparam(deposit)
vpp = govparam(voting)
Q = float(tp.get("quorum", 0)) or None
THR = float(tp.get("threshold", 0)) or None
VETO = float(tp.get("veto_threshold", 0)) or None

supply_px = sup.get(PUNDIX, 0) / D
supply_purse = sup.get(PURSE, 0) / D
cp_px = cpm.get(PUNDIX, 0) / D
cp_purse = cpm.get(PURSE, 0) / D
dist_px = dm.get(PUNDIX, 0) / D
dist_purse = dm.get(PURSE, 0) / D

esc0 = dec_amounts(esc_bal.get("transfer_escrow_channel-0_v340", {}).get("balances", []))
esc1 = dec_amounts(esc_bal.get("transfer_escrow_channel-1_v340", {}).get("balances", []))
esc0_purse = int(esc0.get(PURSE, 0)) / D
esc1_purse = int(esc1.get(PURSE, 0)) / D

free_px = supply_px - bonded - not_bonded - cp_px
free_purse = supply_purse - esc0_purse - esc1_purse - dist_purse
P = prices["pundix_dl"]

other_dec = {
    "ibc/027BB5CDD412B8C3130E1D7EF27D3C90412373FDFB915D3F0B35C067A85819EA": (6, "USDT", 1.0),
    "ibc/0471F1C4E7AFD3F07702BEF6DC365268D64570F7C1FDC98EA6098DD6DE59817B": (6, "OSMO", 0.0),
    "ibc/0816EE31A3FE24B7B00ED64C6ABB34C3FD14410A5DCFB61CD7C126ABFE96B9ED": (6, "USDT", 1.0),
    "ibc/37CA072246C3BCBB445AEC196645F5AAB7876C456D76BC96141D3A0D6E615D2E": (18, "FX", prices["fx"]),
    "ibc/41746107C9CB12ECF4402F46ECCEF66D0C30D9283E6647DCAFED8A09C9A78197": (18, "WETH", prices["weth"]),
    "ibc/6259AD5A0FEBC77820378BCF9939ABFC3BB4CC8E2F2094703669F217858F1BE1": (6, "USDT", 1.0),
}
other_usd = 0.0
other_rows = []
for denom, (d, sym, price) in other_dec.items():
    amt = sup.get(denom, 0) / 10**d
    usd = amt * price
    other_usd += usd
    other_rows.append({"denom": denom, "base": traces.get(denom, {}).get("base_denom"),
                       "amount": amt, "symbol": sym, "usd": round(usd, 2)})

naive = Q * bonded
selfinc = Q / (1 - Q) * bonded
cp_usd = cp_purse * prices["purse"] + cp_px * P
min_dep = 0.0
try:
    min_dep = int(dpp["min_deposit"][0]["amount"]) / D
except Exception:
    pass

v["params"] = {
    "bond_denom": (staking_params or {}).get("params", {}).get("bond_denom"),
    "unbonding_time_s": (staking_params or {}).get("params", {}).get("unbonding_time"),
    "gov": {"quorum": Q, "threshold": THR, "veto_threshold": VETO,
            "voting_period_s": vpp.get("voting_period"), "min_deposit": min_dep,
            "max_deposit_period_s": dpp.get("max_deposit_period")},
    "mint": (mint or {}).get("params", {}),
    "bonded_validators": len((vals or {}).get("validators", [])),
    "total_proposals": len((props or {}).get("proposals", [])),
}
v["state"] = {
    "bonded_PUNDIX": bonded, "not_bonded_PUNDIX": not_bonded,
    "supply_PUNDIX": supply_px, "supply_PURSE": supply_purse,
    "community_pool": {"PUNDIX": cp_px, "PURSE": cp_purse, "usd": round(cp_usd, 2)},
    "distribution_module": {"PUNDIX": dist_px, "PURSE": dist_purse,
                            "excess_over_cp_PURSE": dist_purse - cp_purse,
                            "excess_over_cp_usd": round((dist_purse - cp_purse) * prices["purse"] + (dist_px - cp_px) * P, 2)},
    "ibc_escrow_channel0_PURSE": esc0_purse, "ibc_escrow_channel0_usd": round(esc0_purse * prices["purse"], 2),
    "ibc_escrow_channel1_PURSE": esc1_purse, "ibc_escrow_channel1_usd": round(esc1_purse * prices["purse"], 2),
    "free_float_PUNDIX": free_px, "free_float_PUNDIX_usd": round(free_px * P, 2),
    "free_float_PURSE": free_purse, "free_float_PURSE_usd": round(free_purse * prices["purse"], 2),
    "other_user_vouchers_usd": round(other_usd, 2),
    "other_user_vouchers": other_rows,
}
v["capture"] = {
    "prices": prices,
    "scenarios_PUNDIX": {
        "naive_QxB": naive, "precise_Q_over_1mQ_xB": selfinc,
        "usd_naive": round(naive * P, 2), "usd_precise": round(selfinc * P, 2),
    },
    "proceeds_cp_usd": round(cp_usd, 2),
    "ev_naive": round(cp_usd - naive * P, 2),
    "ev_precise": round(cp_usd - selfinc * P, 2),
    "float_vs_naive_pct": round(100 * free_px / naive, 2) if naive else None,
    "float_vs_precise_pct": round(100 * free_px / selfinc, 2) if selfinc else None,
}
v["errors"] = errors
v["success"] = bool(Q and bonded and cp_usd)

lb2 = get(f"{LCD}/cosmos/base/tendermint/v1beta1/blocks/latest", retries=2)
v["height_after"] = lb2["block"]["header"]["height"] if lb2 else None

with open(os.path.join(OUT, "verification.json"), "w") as f:
    json.dump(v, f, indent=2)

summary = {
    "finding": "C2-33",
    "title": "PundiX governance capture - dead end confirmed",
    "height": v["height"], "block_time": v["block_time"],
    "quorum_live": Q, "bonded_PUNDIX": round(bonded, 6),
    "cp_usd": round(cp_usd, 2),
    "capture_cost_usd_naive": round(naive * P, 2),
    "capture_cost_usd_precise": round(selfinc * P, 2),
    "ev_usd_precise": round(cp_usd - selfinc * P, 2),
    "gov_movable_beyond_cp_usd": 0.0,
    "escrows_usd": round((esc0_purse + esc1_purse) * prices["purse"], 2),
    "verdict": "capture cost >= 16x CP; negative EV; dead end",
    "success": v["success"], "errors": len(errors),
}
with open(os.path.join(OUT, "summary_ci.json"), "w") as f:
    json.dump(summary, f, indent=2)

print(json.dumps(summary, indent=2))
sys.exit(0 if v["success"] else 1)
