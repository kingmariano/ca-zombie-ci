#!/usr/bin/env python3
"""C2-53 Ferra DLMM — CI verification (read-only; public endpoints only; no keys, no transactions).

Runs in GitHub Actions via ci/run.sh. Writes proofs to ci-out/.
Checks:
  1. devInspect replay of pre-built TransactionKind bytes (v1 origin vs v2 upgrade; gate 5004).
  2. Live state: GlobalConfig.package_version/pause; Pairs registry size; pair balances snapshot.
  3. Module-level diff v1 vs v2: sha256 of every module; function presence probes (GraphQL).
Exit code non-zero if a critical assertion fails.
"""
import base64, hashlib, json, os, sys, time, urllib.request
from concurrent.futures import ThreadPoolExecutor

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
OUT = os.path.join(ROOT, "ci-out")
os.makedirs(OUT, exist_ok=True)

RPC_ENDPOINTS = [
    "https://sui-rpc.publicnode.com",
    "https://sui-mainnet-endpoint.blockvision.org",
    "https://mainnet.suiet.app",
    "https://sui-mainnet.nodeinfra.com",
]
GQL_URL = "https://graphql.mainnet.sui.io/graphql"

V1 = "0x5a5c1d10e4782dbbdec3eb8327ede04bd078b294b97cfdba447b11b846b383ac"
V2 = "0x01aca2702b2402f13eacdf9f3e49f5d1bdd3ec5cc7d11847cf8acbaef1cb6d5c"
CONFIG = "0x5c9dacf5a678ea15b8569d65960330307e23d429289ca380e665b1aa175ebeca"
MODULES = ["lb_pair", "lb_position", "bin_manager", "config", "acl", "lb_factory", "fee_helper", "safe_math"]
FAILURES = []

def rpc(method, params=None, retries=4):
    body = json.dumps({"jsonrpc": "2.0", "id": 1, "method": method, "params": params or []}).encode()
    last = None
    for attempt in range(retries):
        for u in RPC_ENDPOINTS:
            try:
                req = urllib.request.Request(u, data=body, headers={"Content-Type": "application/json", "User-Agent": "ferra-ci/1.0"})
                with urllib.request.urlopen(req, timeout=45) as r:
                    j = json.loads(r.read().decode())
                if "result" in j:
                    return j["result"]
                last = j.get("error")
            except Exception as e:
                last = str(e)
        time.sleep(2 * (attempt + 1))
    raise RuntimeError(f"RPC {method} failed: {last}")

def gql(query, retries=3):
    body = json.dumps({"query": query}).encode()
    last = None
    for attempt in range(retries):
        try:
            req = urllib.request.Request(GQL_URL, data=body, headers={"Content-Type": "application/json", "User-Agent": "ferra-ci/1.0"})
            with urllib.request.urlopen(req, timeout=45) as r:
                j = json.loads(r.read().decode())
            if "errors" in j:
                raise RuntimeError(str(j["errors"])[:400])
            return j["data"]
        except Exception as e:
            last = str(e); time.sleep(2 * (attempt + 1))
    raise RuntimeError(f"GQL failed: {last}")

# ---------- 1. devInspect replay ----------
def check_devinspect():
    tb = json.load(open(os.path.join(HERE, "txbytes.json")))
    sender = tb["sender"]
    res = {}
    for label, b64 in tb["tests"].items():
        try:
            r = rpc("sui_devInspectTransactionBlock", [sender, b64, None, None])
            st = (r.get("effects") or {}).get("status") or {}
            res[label] = {"status": st.get("status"), "error": (st.get("error") or "")[:400]}
        except Exception as e:
            res[label] = {"status": "RPC_ERROR", "error": str(e)[:300]}
        print(f"[devinspect] {label}: {res[label]['status']} {res[label].get('error','')[:110]}")
    # assertions
    def assert_status(label, want):
        got = res.get(label, {}).get("status")
        if got != want:
            FAILURES.append(f"devinspect {label}: expected {want}, got {got}")
    assert_status("gate_origin_checked_package_version", "failure")   # v1 code aborts 5004
    assert_status("gate_v2_checked_package_version", "success")
    assert_status("origin_open_position", "failure")                  # v1 state-changing gated
    assert_status("v2_open_position", "success")
    assert_status("origin_get_price_from_id_u32", "success")          # v1 code executes
    assert_status("origin_get_swap_out_1SUI", "success")
    assert_status("v2_get_swap_out_1SUI", "success")
    if "5004" not in res.get("gate_origin_checked_package_version", {}).get("error", ""):
        FAILURES.append("gate_origin_checked_package_version did not abort 5004")
    json.dump(res, open(os.path.join(OUT, "devinspect_ci.json"), "w"), indent=1)

# ---------- 2. live state ----------
def check_state():
    cfg = rpc("sui_getObject", [CONFIG, {"showType": True, "showContent": True}])
    f = cfg["data"]["content"]["fields"]
    state = {"config_object": CONFIG, "package_version": f.get("package_version"),
             "pause": f.get("pause"), "flash_loan_enable": f.get("flash_loan_enable"),
             "allow_create_pair": f.get("allow_create_pair")}
    if str(f.get("package_version")) != "2":
        FAILURES.append(f"package_version expected 2, got {f.get('package_version')}")
    print("[state] GlobalConfig:", json.dumps(state))

    reg = rpc("sui_getObject", ["0x71ae968a99fd9a0b6a46519d7875fcc454c9811a3a6da8114382e6d926e78a04",
                                {"showType": True, "showContent": True}])
    rf = reg["data"]["content"]["fields"]
    size = int(rf.get("index"))
    state["registry_size"] = size
    print("[state] pairs registry size:", size)

    cached = json.load(open(os.path.join(HERE, "pair_ids.json")))
    ids = cached["pair_ids"]
    if size > len(ids):
        FAILURES.append(f"registry grew to {size} > cached {len(ids)}; re-cache needed")
    states = {}
    for i in range(0, len(ids), 50):
        r = rpc("sui_multiGetObjects", [ids[i:i+50], {"showType": True, "showContent": True}])
        for o in r:
            d = o.get("data") or {}
            states[d.get("objectId")] = d
    live = 0; empty = 0; paused = 0
    bal = {}; pf = {}
    for pid in ids:
        d = states.get(pid)
        if not d: continue
        fld = d.get("content", {}).get("fields", {})
        bx = int(fld.get("balance_x", 0)); by = int(fld.get("balance_y", 0))
        if fld.get("is_pause"): paused += 1
        if bx > 0 or by > 0: live += 1
        else: empty += 1
        t = d.get("type", "")
        # extract coin types from LBPair<A, B>
        try:
            inner = t[t.index("<")+1:t.rindex(">")]
            depth = 0; split = None
            for i, ch in enumerate(inner):
                if ch == "<": depth += 1
                elif ch == ">": depth -= 1
                elif ch == "," and depth == 0: split = i; break
            a, b = inner[:split].strip(), inner[split+1:].strip()
            bal[a] = bal.get(a, 0) + bx; bal[b] = bal.get(b, 0) + by
            pf[a] = pf.get(a, 0) + int(fld.get("protocol_fee_x", 0))
            pf[b] = pf.get(b, 0) + int(fld.get("protocol_fee_y", 0))
        except Exception:
            pass
    state.update({"pairs_live_nonzero": live, "pairs_empty": empty, "pairs_paused": paused,
                  "balances_raw_by_coin": bal, "protocol_fees_raw_by_coin": pf})
    print(f"[state] live={live} empty={empty} paused={paused}")
    json.dump(state, open(os.path.join(OUT, "state_snapshot.json"), "w"), indent=1)

# ---------- 3. module diff ----------
def check_modules():
    out = {"v1": V1, "v2": V2, "modules": {}}
    def fetch(addr):
        q = '{ object(address: "%s") { asMovePackage { modules { nodes { name bytes } } } } }' % addr
        d = gql(q)
        return {n["name"]: n["bytes"] for n in d["object"]["asMovePackage"]["modules"]["nodes"]}
    a = fetch(V1); b = fetch(V2)
    for m in MODULES:
        ha = hashlib.sha256(base64.b64decode(a[m])).hexdigest() if m in a else None
        hb = hashlib.sha256(base64.b64decode(b[m])).hexdigest() if m in b else None
        out["modules"][m] = {"v1_sha256": ha, "v2_sha256": hb, "identical": ha == hb}
        print(f"[modules] {m}: identical={ha==hb}")
    # function presence probes (paginate all functions)
    def funcs(addr, mod):
        names = []
        cursor = None
        while True:
            after = f', after: "{cursor}"' if cursor else ""
            q = '{ object(address: "%s") { asMovePackage { module(name: "%s") { functions(first: 50%s) { pageInfo { hasNextPage endCursor } nodes { name } } } } } }' % (addr, mod, after)
            d = gql(q)["object"]["asMovePackage"]["module"]["functions"]
            names += [n["name"] for n in d["nodes"]]
            if not d["pageInfo"]["hasNextPage"]: break
            cursor = d["pageInfo"]["endCursor"]
        return names
    f1 = funcs(V1, "lb_pair"); f2 = funcs(V2, "lb_pair")
    out["lb_pair_funcs_v1"] = len(f1); out["lb_pair_funcs_v2"] = len(f2)
    out["v2_only_fns"] = sorted(set(f2) - set(f1))
    out["v1_only_fns"] = sorted(set(f1) - set(f2))
    print(f"[modules] lb_pair fns v1={len(f1)} v2={len(f2)} v2-only={out['v2_only_fns']}")
    if "remove_liquidity_by_percent" not in f2:
        FAILURES.append("remove_liquidity_by_percent missing in v2")
    if "remove_liquidity_by_percent" in f1:
        FAILURES.append("remove_liquidity_by_percent unexpectedly present in v1")
    json.dump(out, open(os.path.join(OUT, "module_diff.json"), "w"), indent=1)

if __name__ == "__main__":
    check_devinspect()
    check_state()
    check_modules()
    summary = {"failures": FAILURES, "pass": len(FAILURES) == 0,
               "generated_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())}
    json.dump(summary, open(os.path.join(OUT, "ci_summary.json"), "w"), indent=1)
    print("\n=== CI SUMMARY ===", json.dumps(summary))
    sys.exit(0 if not FAILURES else 1)
