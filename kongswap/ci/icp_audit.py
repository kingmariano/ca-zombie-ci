#!/usr/bin/env python3
"""
KongSwap (ICP) live-state audit - READ-ONLY.
Only anonymous IC query calls + public HTTP GETs. No update calls, no transactions.

Outputs:
  ci-out/live_state.json   machine-readable state
  ci-out/SUMMARY.txt       human-readable summary
"""
import json, os, sys, time, threading, traceback
from concurrent.futures import ThreadPoolExecutor

import urllib.request

from ic.client import Client
from ic.identity import Identity
from ic.agent import Agent
from ic.candid import encode, decode, Types
from ic.principal import Principal
from ic.agent import sign_request
import cbor2

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "ci-out")
os.makedirs(OUT, exist_ok=True)

DEX = "2ipq2-uqaaa-aaaar-qailq-cai"
ROOT = "ormnc-tiaaa-aaaaq-aadyq-cai"
GOV = "oypg6-faaaa-aaaaq-aadza-cai"
KONG = "o7oak-iyaaa-aaaaq-aadzq-cai"
IDX = "onixt-eiaaa-aaaaq-aad2q-cai"
SWAP = "okjrh-jqaaa-aaaaq-aad2a-cai"
ICP_LEDGER = "ryjl3-tyaaa-aaaaa-aaaba-cai"
TREASURY_ICP_ACCOUNT = "f39d9b22c382c25f832fd1d3e6ad5216249623b204a7fc5498f991f4cf2df1e1"
# SNS treasury KONG subaccount (API prints 63 hex chars; pad leading zero to 32 bytes)
TREASURY_KONG_SUB = bytes.fromhex("0ecfd73b8ea0a1d24c36a1affe890b81bf2506e4a4f183591c9600872a5edc72")

client = Client(url=os.environ.get("IC_GATEWAY", "https://ic0.app"))
agent = Agent(identity=Identity(), client=client)
_lock = threading.Lock()
_calls = {"ok": 0, "err": 0}

BAL_T = Types.Record({"owner": Types.Principal, "subaccount": Types.Opt(Types.Vec(Types.Nat8))})
ACC_T = Types.Record({"account": Types.Vec(Types.Nat8)})
OPT_TEXT = Types.Opt(Types.Text)

def call_query(canister, method, params, retries=3):
    last = None
    for i in range(retries):
        try:
            data = encode(params)
            req = {
                "request_type": "query",
                "sender": agent.identity.sender().bytes,
                "canister_id": Principal.from_str(canister).bytes,
                "method_name": method,
                "arg": data,
                "ingress_expiry": agent.get_expiry_date(),
            }
            _, payload = sign_request(req, agent.identity)
            ret = agent.query_endpoint(canister, payload)
            d = ret if not isinstance(ret, bytes) else cbor2.loads(ret)
            if d.get("status") != "replied":
                raise RuntimeError(str(d.get("reject_message", d))[:200])
            arg = d["reply"].get("arg")
            with _lock:
                _calls["ok"] += 1
            return decode(arg) if arg else None
        except Exception as e:
            last = e
            time.sleep(0.6 + i)
    with _lock:
        _calls["err"] += 1
    raise RuntimeError(str(last)[:200])

def http_json(url, retries=4):
    last = None
    for i in range(retries):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0 kongswap-audit"})
            with urllib.request.urlopen(req, timeout=30) as r:
                return json.load(r)
        except Exception as e:
            last = e
            time.sleep(1.5 + 2 * i)
    raise RuntimeError(str(last)[:200])

def val(rec):
    """unwrap ic-py decoded value"""
    if isinstance(rec, list) and rec and isinstance(rec[0], dict) and "value" in rec[0]:
        return rec[0]["value"]
    return rec

state = {"ts_utc": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()), "gateway": client.url}

# ---------------------------------------------------------------- 1. canister set
print("[1] canister info (ic-api)")
canisters = [ROOT, GOV, KONG, IDX, SWAP, DEX]
state["canisters"] = {}
for c in canisters:
    try:
        d = http_json(f"https://ic-api.internetcomputer.org/api/v3/canisters/{c}")
        state["canisters"][c] = {k: d.get(k) for k in ("name", "canister_type", "controllers", "module_hash", "subnet_id")}
        print("   ", c, state["canisters"][c].get("name"), state["canisters"][c].get("controllers"))
    except Exception as e:
        state["canisters"][c] = {"error": str(e)[:120]}
        print("   ", c, "ERR", str(e)[:80])

# SNS-level canister status incl. cycles
try:
    sns = http_json(f"https://sns-api.internetcomputer.org/api/v1/snses/{ROOT}")
    state["sns"] = {
        "name": sns.get("name"),
        "lifecycle": (sns.get("swap_lifecycle") or {}).get("lifecycle"),
        "icp_treasury_account": sns.get("icp_treasury_account"),
        "icp_treasury_balance_e8s": sns.get("icp_treasury_balance_e8s"),
        "ledger_price_usd": sns.get("ledger_price_usd"),
        "ledger_fdv_usd": sns.get("ledger_fdv_usd"),
        "total_proposals_count": sns.get("total_proposals_count"),
        "total_proposals_count_30d": sns.get("total_proposals_count_30d"),
        "ledger_volume_24h_usd": sns.get("ledger_volume_24h_usd"),
        "canisters": [
            {k: c.get(k) for k in ("canister_id", "canister_type", "status", "cycles", "memory_size", "controllers")}
            for c in sns.get("canisters", [])
        ],
    }
    print("   SNS:", state["sns"]["name"], state["sns"]["lifecycle"], "cycles DEX:",
          next((c["cycles"] for c in state["sns"]["canisters"] if c["canister_id"] == DEX), "?"))
except Exception as e:
    state["sns"] = {"error": str(e)[:200]}
    print("   SNS ERR", str(e)[:120])

# ---------------------------------------------------------------- 2. DEX method surface
print("[2] DEX live queries")
dex = {}
try:
    dex["icrc1_name"] = val(call_query(DEX, "icrc1_name", []))
except Exception as e:
    dex["icrc1_name_error"] = str(e)[:120]
try:
    pools = val(call_query(DEX, "pools", [{"type": OPT_TEXT, "value": []}]))
    # unwrap variant Ok
    if isinstance(pools, dict):
        pools = next(iter(pools.values()))
    dex["pools_all_count"] = len(pools) if isinstance(pools, list) else pools
except Exception as e:
    dex["pools_error"] = str(e)[:120]
# specific historical pools: name -> expected canister
for pname in ["KONG_ICP", "ICP_ckUSDT", "ckBTC_ICP", "ICP_ckETH", "ICP_ckUSDC"]:
    try:
        r = val(call_query(DEX, "pools", [{"type": OPT_TEXT, "value": [pname]}]))
        if isinstance(r, dict):
            r = next(iter(r.values()))
        dex[f"pool_{pname}"] = r[0] if isinstance(r, list) and r else None
    except Exception as e:
        dex[f"pool_{pname}_error"] = str(e)[:120]
state["dex"] = dex
print("   icrc1_name:", dex.get("icrc1_name"), "| pools_all_count:", dex.get("pools_all_count"))

# tokens list -> save full list
try:
    toks = val(call_query(DEX, "tokens", [{"type": OPT_TEXT, "value": []}]))
    if isinstance(toks, dict):
        toks = next(iter(toks.values()))
    token_list = []
    for item in toks or []:
        v = item.get("value", item) if isinstance(item, dict) else None
        if isinstance(v, dict) and "_16346" in v:
            t = v["_16346"]
            token_list.append({
                "symbol": t.get("_4007505752"),
                "canister_id": t.get("_1313628723"),
                "decimals": t.get("_308955842"),
                "fee": t.get("_5094982"),
                "icrc1": t.get("_3067731910"),
                "is_removed": t.get("_3451244299"),
            })
    state["tokens_count"] = len(token_list)
    state["tokens"] = token_list
    print("   tokens:", len(token_list))
except Exception as e:
    state["tokens_error"] = str(e)[:150]
    token_list = []
    print("   tokens ERR", str(e)[:100])

# ---------------------------------------------------------------- 3. DEX balances
print("[3] DEX ledger balances (all listed tokens + majors)")
majors = {
    "ICP": ICP_LEDGER, "ckBTC": "mxzaz-hqaaa-aaaar-qaada-cai", "ckETH": "ss2fx-dyaaa-aaaar-qacoq-cai",
    "ckUSDC": "xevnm-gaaaa-aaaar-qafnq-cai", "ckUSDT": "cngnf-vqaaa-aaaar-qag4q-cai", "KONG": KONG,
    "CHAT": "2ouva-viaaa-aaaaq-aaamq-cai", "BOB": "7pail-xaaaa-aaaas-aabmq-cai",
}
scan = {s: c for s, c in majors.items()}
for t in token_list:
    if t.get("canister_id") and t["canister_id"] not in scan.values():
        scan[t.get("symbol") or t["canister_id"]] = t["canister_id"]

def bal(item):
    sym, cid = item
    try:
        r = val(call_query(cid, "icrc1_balance_of",
                           [{"type": BAL_T, "value": {"owner": DEX, "subaccount": []}}]))
        return sym, cid, str(r), None
    except Exception as e:
        return sym, cid, None, str(e)[:110]

balances = {}
with ThreadPoolExecutor(max_workers=8) as ex:
    for sym, cid, b, err in ex.map(bal, list(scan.items())):
        balances[sym] = {"canister_id": cid, "balance_raw": b, "error": err}
state["dex_balances"] = balances
nonzero = {k: v for k, v in balances.items() if v.get("balance_raw") not in (None, "0")}
state["dex_nonzero_balances"] = nonzero
print("   ledgers scanned:", len(balances), "| nonzero:", len(nonzero), "| errors:", sum(1 for v in balances.values() if v.get("error")))
for k, v in nonzero.items():
    print("   NONZERO", k, v["balance_raw"], v["canister_id"])

# ---------------------------------------------------------------- 4. treasury
print("[4] SNS treasury balances")
treasury = {}
try:
    r = val(call_query(ICP_LEDGER, "account_balance",
                       [{"type": ACC_T, "value": {"account": bytes.fromhex(TREASURY_ICP_ACCOUNT)}}]))
    if isinstance(r, dict):
        r = next(iter(r.values()))
    treasury["icp_e8s"] = str(r)
    treasury["icp"] = int(r) / 1e8
except Exception as e:
    treasury["icp_error"] = str(e)[:150]
try:
    r = val(call_query(KONG, "icrc1_balance_of",
                       [{"type": BAL_T, "value": {"owner": GOV, "subaccount": [list(TREASURY_KONG_SUB)]}}]))
    treasury["kong_e8s"] = str(r)
    treasury["kong"] = int(r) / 1e8
except Exception as e:
    treasury["kong_error"] = str(e)[:150]
state["treasury"] = treasury
print("   ICP:", treasury.get("icp"), "| KONG:", treasury.get("kong"))

# ---------------------------------------------------------------- 5. governance
print("[5] SNS governance (top neurons + last proposals)")
gov = {}
try:
    n = http_json(f"https://sns-api.internetcomputer.org/api/v2/snses/{ROOT}/neurons?limit=100&sort_by=-voting_power")
    nd = n.get("data", [])
    gov["top100_voting_power"] = sum(x["voting_power"] for x in nd)
    gov["top100_stake_e8s"] = sum(x["stake_e8s"] for x in nd)
    clusters = {}
    for x in nd:
        for c in (x.get("claimers") or ["?"]):
            clusters[c] = clusters.get(c, 0) + x["voting_power"]
    gov["top_claimers_by_vp"] = sorted(clusters.items(), key=lambda kv: -kv[1])[:8]
    gov["top_neuron"] = {
        "vp": nd[0]["voting_power"], "stake_e8s": nd[0]["stake_e8s"],
        "dissolve_state": nd[0]["dissolve_state"], "claimers": nd[0].get("claimers"),
        "followees": nd[0].get("followees"),
    }
except Exception as e:
    gov["neurons_error"] = str(e)[:150]
try:
    cnt = http_json(f"https://sns-api.internetcomputer.org/api/v2/snses/{ROOT}/neurons/count")
    gov["neurons_total"] = cnt.get("total")
    for st in ("NotDissolving", "Dissolving", "Dissolved"):
        c = http_json(f"https://sns-api.internetcomputer.org/api/v2/snses/{ROOT}/neurons/count?include_state={st}")
        gov[f"neurons_{st}"] = c.get("total")
except Exception as e:
    gov["count_error"] = str(e)[:150]
try:
    props = http_json(f"https://sns-api.internetcomputer.org/api/v1/snses/{ROOT}/proposals?limit=10")
    gov["recent_proposals"] = [
        {"id": p["id"], "action": p["action"], "status": p["status"],
         "decided": p["decided_timestamp_seconds"], "tally": p.get("latest_tally"),
         "min_yes_exercised_bp": (p.get("minimum_yes_proportion_of_exercised") or {}).get("basis_points"),
         "min_yes_total_bp": (p.get("minimum_yes_proportion_of_total") or {}).get("basis_points")}
        for p in props.get("data", [])
    ]
except Exception as e:
    gov["proposals_error"] = str(e)[:150]
state["governance"] = gov
print("   top100 VP:", gov.get("top100_voting_power"), "| neurons:", gov.get("neurons_total"))

# ---------------------------------------------------------------- write outputs
state["query_calls"] = _calls
with open(os.path.join(OUT, "live_state.json"), "w") as f:
    json.dump(state, f, indent=1, default=str)

lines = []
lines.append("KongSwap (ICP) live-state audit - READ-ONLY - " + state["ts_utc"])
lines.append("=" * 70)
lines.append("DEX canister: %s  (%s)" % (DEX, state["canisters"].get(DEX, {}).get("name")))
lines.append("  pools (all, non-removed): %s" % dex.get("pools_all_count"))
for p in ["KONG_ICP", "ICP_ckUSDT", "ckBTC_ICP"]:
    pr = dex.get("pool_" + p)
    if pr:
        # fields: balance_0/1 are hashed keys _1283592060/_1283592061 (ints)
        lines.append("  pool %-10s balances: %s / %s (pool_id %s)" % (
            p, pr.get("_1283592060"), pr.get("_1283592061"), pr.get("_3290882718")))
lines.append("  listed tokens: %s" % state.get("tokens_count"))
lines.append("  DEX balances: %d ledgers scanned, %d nonzero, %d errors" % (
    len(balances), len(nonzero), sum(1 for v in balances.values() if v.get("error"))))
for k, v in nonzero.items():
    lines.append("    NONZERO %-10s %s  (%s)" % (k, v.get("balance_raw"), v.get("canister_id")))
lines.append("SNS treasury: %.2f ICP  +  %.2f KONG" % (treasury.get("icp", 0), treasury.get("kong", 0)))
lines.append("SNS governance: neurons=%s (NotDissolving=%s, Dissolving=%s, Dissolved=%s)" % (
    gov.get("neurons_total"), gov.get("neurons_NotDissolving"), gov.get("neurons_Dissolving"), gov.get("neurons_Dissolved")))
lines.append("  top-100 voting power: %s" % gov.get("top100_voting_power"))
for c, vp in (gov.get("top_claimers_by_vp") or [])[:5]:
    lines.append("    claimer %s  VP=%.4fe15" % (c, vp / 1e15))
for p in (gov.get("recent_proposals") or [])[:5]:
    t = p.get("tally") or {}
    lines.append("  proposal %s action=%s %s yes=%s no=%s" % (
        p["id"], p["action"], p["status"], t.get("yes"), t.get("no")))
lines.append("SNS canister cycles (DEX): %s" % next(
    (c.get("cycles") for c in state["sns"].get("canisters", []) if c.get("canister_id") == DEX), "?"))
lines.append("query calls: ok=%d err=%d" % (_calls["ok"], _calls["err"]))
open(os.path.join(OUT, "SUMMARY.txt"), "w").write("\n".join(lines) + "\n")
print("\n".join(lines))

# success if we got the core facts
core_ok = (dex.get("pools_all_count") == 0 and "icp" in treasury and state.get("tokens_count", 0) > 0)
print("\nCORE_OK:", bool(core_ok))
sys.exit(0 if core_ok else 1)
