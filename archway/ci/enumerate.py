#!/usr/bin/env python3
"""
C2-09 Archway (archway-1) heavy enumeration + economics model.
Read-only. No transactions. Writes evidence JSON/CSV to ci-out/.

Pipeline:
  1. pin height, core chain state (wasm params, gov params via abci_query,
     staking pool, community pool, supply, module accounts + balances, proposals)
  2. enumerate all wasm codes -> contracts -> contract_info -> bank balances
  3. node version evidence (build_deps wasmvm) from several public endpoints
  4. Osmosis ARCH pools (IBC exit liquidity)
  5. cost-to-capture + extraction-bound model
"""
import json, os, sys, time, base64, hashlib, urllib.request, urllib.parse
import concurrent.futures as cf

LCD = "https://api.mainnet.archway.io"
RPC = "https://rpc.mainnet.archway.io"
OSMOSIS_LCD = "https://lcd.osmosis.zone"
OUT = os.path.join(os.path.dirname(__file__), "..", "ci-out")
os.makedirs(OUT, exist_ok=True)
UA = {"User-Agent": "Mozilla/5.0 (zombie-hunt-ci; read-only research)"}
LIMIT_CODES = int(os.environ.get("LIMIT_CODES", "0"))  # 0 = all
CONC = int(os.environ.get("CONC", "20"))

def get(url, tries=4, timeout=40):
    last = None
    for i in range(tries):
        try:
            req = urllib.request.Request(url, headers=UA)
            with urllib.request.urlopen(req, timeout=timeout) as r:
                return json.load(r)
        except Exception as e:
            last = e
            time.sleep(0.4 * (i + 1))
    return {"_error": str(last), "_url": url}

def save(name, obj):
    p = os.path.join(OUT, name)
    with open(p, "w") as f:
        json.dump(obj, f, indent=1)
    print("[saved]", name, flush=True)

def pin_height():
    d = get(f"{LCD}/cosmos/base/tendermint/v1beta1/blocks/latest")
    return int(d["block"]["header"]["height"])

# ---------------- protobuf mini-decoder (for gov params via abci_query) -----
def read_varint(b, i):
    v = 0; s = 0
    while True:
        x = b[i]; i += 1
        v |= (x & 0x7F) << s
        s += 7
        if not x & 0x80:
            return v, i

def decode_msg(b, depth=0):
    """Return list of (field, wiretype, value). Length-delimited values are
    decoded recursively when they look like a message, else kept as bytes/str."""
    i = 0; out = []
    while i < len(b):
        try:
            key, i = read_varint(b, i)
        except IndexError:
            break
        f, wt = key >> 3, key & 7
        if wt == 0:
            v, i = read_varint(b, i); out.append((f, wt, v))
        elif wt == 2:
            ln, i = read_varint(b, i)
            data = b[i:i + ln]; i += ln
            # printable ASCII => string (check before recursion; protobuf control
            # bytes make real nested messages non-printable)
            if data and all(32 <= x < 127 for x in data):
                out.append((f, wt, data.decode("utf8")))
                continue
            if depth < 4:
                sub = decode_msg(data, depth + 1)
                if sub and len(data) > 1 and all(1 <= sf <= 30 for sf, _, _ in sub):
                    out.append((f, wt, sub))
                    continue
            try:
                s = data.decode("utf8")
                out.append((f, wt, s if all(32 <= ord(c) < 127 for c in s) else data.hex()))
            except Exception:
                out.append((f, wt, data.hex()))
        else:
            out.append((f, wt, None)); break
    return out

def abci_gov_params(height):
    path = urllib.parse.quote('"/cosmos.gov.v1.Query/Params"')
    url = f"{RPC}/abci_query?path={path}&data=0x&height={height}"
    d = get(url)
    raw = d["result"]["response"]["value"]
    val = base64.b64decode(raw)
    fields = decode_msg(val)
    parsed = {"raw_b64": raw, "height": d["result"]["response"].get("height"), "fields": fields}
    # QueryParamsResponse: params is field 4 (fields 1-3 are deprecated voting/deposit/tally params)
    params = None
    for f, wt, v in fields:
        if f == 4 and isinstance(v, list):
            params = v
    if params is None:
        for f, wt, v in fields:
            if f == 1 and isinstance(v, list):
                params = v
    def strf(fields, n):
        for f, wt, v in fields or []:
            if f == n:
                return v
        return None
    def dur(fields, n):
        v = strf(fields, n)
        if isinstance(v, list):
            for f2, wt2, v2 in v:
                if f2 == 1:
                    return v2
        return None
    def coin(fields, n):
        v = strf(fields, n)
        if isinstance(v, list):
            den = amt = None
            for f2, wt2, v2 in v:
                if f2 == 1: den = v2
                if f2 == 2: amt = v2
            return {"denom": den, "amount": amt}
        return None
    if params:
        parsed["decoded"] = {
            "min_deposit": coin(params, 1),
            "max_deposit_period_s": dur(params, 2),
            "voting_period_s": dur(params, 3),
            "quorum": strf(params, 4),
            "threshold": strf(params, 5),
            "veto_threshold": strf(params, 6),
            "min_initial_deposit_ratio": strf(params, 7),
            "proposal_cancel_ratio": strf(params, 8),
            "proposal_cancel_dest": strf(params, 9),
            "expedited_voting_period_s": dur(params, 10),
            "expedited_threshold": strf(params, 11),
            "expedited_min_deposit": coin(params, 12),
            "burn_vote_quorum": strf(params, 13),
            "burn_proposal_deposit_prevote": strf(params, 14),
            "burn_vote_veto": strf(params, 15),
            "min_deposit_ratio": strf(params, 16),
        }
    return parsed

# ---------------- node version evidence -------------------------------------
def node_evidence():
    ev = []
    for base, kind in [
        ("https://api.mainnet.archway.io", "lcd"),
        ("https://archway-api.nodes.guru", "lcd"),
        ("https://rest.lavenderfive.com:443/archway", "lcd"),
        ("https://api-archway.mzonder.com", "lcd"),
    ]:
        d = get(f"{base}/cosmos/base/tendermint/v1beta1/node_info")
        if "_error" in d:
            ev.append({"endpoint": base, "error": d["_error"]})
            continue
        av = d.get("application_version", {})
        deps = {x.get("path"): x.get("version") for x in av.get("build_deps", [])}
        ev.append({
            "endpoint": base, "network": d["default_node_info"]["network"],
            "moniker": d["default_node_info"].get("moniker"),
            "app": av.get("app_name"), "app_version": av.get("version"),
            "git_commit": av.get("git_commit"), "cosmos_sdk": av.get("cosmos_sdk_version"),
            "wasmvm": deps.get("github.com/CosmWasm/wasmvm"),
            "wasmvm_v2": deps.get("github.com/CosmWasm/wasmvm/v2"),
            "wasmd": deps.get("github.com/CosmWasm/wasmd"),
            "ibc_go_v8": deps.get("github.com/cosmos/ibc-go/v8"),
            "cometbft": deps.get("github.com/cometbft/cometbft"),
            "wasmvm_sum": next((x.get("sum") for x in av.get("build_deps", []) if x.get("path") == "github.com/CosmWasm/wasmvm"), None),
        })
    return ev

# ---------------- wasm enumeration ------------------------------------------
def enum_codes(height):
    codes = []; key = None
    for _ in range(200):
        u = f"{LCD}/cosmwasm/wasm/v1/code?pagination.limit=100&height={height}"
        if key: u += "&pagination.key=" + urllib.parse.quote(key)
        d = get(u)
        if "code_infos" not in d:
            break
        codes += d["code_infos"]
        key = (d.get("pagination") or {}).get("next_key")
        if not key: break
    return codes

def enum_contracts(code_id, height):
    out = []; key = None
    for _ in range(500):
        u = f"{LCD}/cosmwasm/wasm/v1/code/{code_id}/contracts?pagination.limit=100&height={height}"
        if key: u += "&pagination.key=" + urllib.parse.quote(key)
        d = get(u)
        if "contracts" not in d:
            break
        out += d["contracts"]
        key = (d.get("pagination") or {}).get("next_key")
        if not key: break
    return code_id, out

def contract_info(addr, height):
    d = get(f"{LCD}/cosmwasm/wasm/v1/contract/{addr}?height={height}")
    ci = d.get("contract_info", {})
    return addr, {"code_id": ci.get("code_id"), "creator": ci.get("creator"),
                  "admin": ci.get("admin"), "label": ci.get("label"),
                  "ibc_port_id": ci.get("ibc_port_id")}

def balances(addr, height):
    out = []; key = None
    for _ in range(10):
        u = f"{LCD}/cosmos/bank/v1beta1/balances/{addr}?pagination.limit=1000&height={height}"
        if key: u += "&pagination.key=" + urllib.parse.quote(key)
        d = get(u)
        if "balances" not in d:
            return addr, []
        out += d["balances"]
        key = (d.get("pagination") or {}).get("next_key")
        if not key: break
    return addr, out

# ---------------- Osmosis ----------------------------------------------------
ARCH_ON_OSMOSIS = "ibc/" + hashlib.sha256(b"transfer/channel-1429/aarch").hexdigest().upper()

def osmosis_pools():
    res = {"arch_denom": ARCH_ON_OSMOSIS, "gamm": [], "cl": []}
    # GAMM scan
    key = None
    for _ in range(60):
        u = f"{OSMOSIS_LCD}/osmosis/gamm/v1beta1/pools?pagination.limit=100"
        if key: u += "&pagination.key=" + urllib.parse.quote(key)
        d = get(u)
        if "pools" not in d: break
        for p in d["pools"]:
            assets = [a["token"] for a in p.get("pool_assets", [])]
            if any(a["denom"] == ARCH_ON_OSMOSIS for a in assets):
                res["gamm"].append({"id": p["id"], "address": p["address"],
                                    "assets": assets, "swap_fee": p.get("pool_params", {}).get("swap_fee")})
        key = (d.get("pagination") or {}).get("next_key")
        if not key: break
    # CL scan
    key = None
    for _ in range(60):
        u = f"{OSMOSIS_LCD}/osmosis/concentratedliquidity/v1beta1/pools?pagination.limit=100"
        if key: u += "&pagination.key=" + urllib.parse.quote(key)
        d = get(u)
        if "pools" not in d: break
        for p in d["pools"]:
            if ARCH_ON_OSMOSIS in (p.get("token0"), p.get("token1")):
                res["cl"].append({"id": p["id"], "token0": p.get("token0"), "token1": p.get("token1"),
                                  "tick": p.get("current_tick"), "spacing": p.get("tick_spacing"),
                                  "current_tick_liquidity": p.get("current_tick_liquidity")})
        key = (d.get("pagination") or {}).get("next_key")
        if not key: break
    # denom traces for counterpart denoms of gamm pools
    traces = {}
    for p in res["gamm"]:
        for a in p["assets"]:
            if a["denom"].startswith("ibc/"):
                h = a["denom"][4:]
                d = get(f"{OSMOSIS_LCD}/ibc/apps/transfer/v1/denom_traces/{h}")
                traces[a["denom"]] = d.get("denom_trace", d)
    res["denom_traces"] = traces
    return res

def llama_prices():
    ids = ["coingecko:archway", "coingecko:osmosis", "coingecko:usd-coin", "coingecko:cosmos"]
    d = get("https://coins.llama.fi/prices/current/" + ",".join(ids))
    return d.get("coins", d)

# ---------------- main -------------------------------------------------------
def main():
    print("pinning height...", flush=True)
    height = pin_height()
    print("height:", height, flush=True)

    core = {"height": height}
    core["wasm_params"] = get(f"{LCD}/cosmwasm/wasm/v1/codes/params?height={height}")
    core["staking_pool"] = get(f"{LCD}/cosmos/staking/v1beta1/pool?height={height}")
    core["validators_bonded"] = get(f"{LCD}/cosmos/staking/v1beta1/validators?pagination.limit=200&status=BOND_STATUS_BONDED&height={height}")
    core["community_pool"] = get(f"{LCD}/cosmos/distribution/v1beta1/community_pool?height={height}")
    core["supply_aarch"] = get(f"{LCD}/cosmos/bank/v1beta1/supply/by_denom?denom=aarch&height={height}")
    core["supply_all"] = get(f"{LCD}/cosmos/bank/v1beta1/supply?pagination.limit=1000&height={height}")
    core["module_accounts"] = get(f"{LCD}/cosmos/auth/v1beta1/module_accounts?height={height}")
    core["consensus_params"] = get(f"{LCD}/cosmos/consensus/v1/params?height={height}")
    core["mint_inflation"] = get(f"{LCD}/cosmos/mint/v1beta1/inflation?height={height}")
    core["upgrade_plan"] = get(f"{LCD}/cosmos/upgrade/v1beta1/current_plan?height={height}")
    core["upgrade_module_versions"] = get(f"{LCD}/cosmos/upgrade/v1beta1/module_versions?height={height}")
    core["gov_params"] = abci_gov_params(height)
    # proposals (all)
    props = []; key = None
    for _ in range(20):
        u = f"{LCD}/cosmos/gov/v1/proposals?pagination.limit=200&pagination.reverse=false&height={height}"
        if key: u += "&pagination.key=" + urllib.parse.quote(key)
        d = get(u)
        if "proposals" not in d: break
        props += d["proposals"]
        key = (d.get("pagination") or {}).get("next_key")
        if not key: break
    core["proposals"] = props
    save("core_state.json", core)

    # module account balances
    mod_bals = {}
    mods = core["module_accounts"].get("accounts", [])
    def mod_bal(acct):
        addr = acct.get("base_account", {}).get("address") or acct.get("address")
        d = get(f"{LCD}/cosmos/bank/v1beta1/balances/{addr}?pagination.limit=1000&height={height}")
        return addr, {"name": acct.get("name"), "balances": d.get("balances", [])}
    if mods:
        with cf.ThreadPoolExecutor(CONC) as ex:
            for addr, b in ex.map(mod_bal, mods):
                mod_bals[addr] = b
    save("module_balances.json", mod_bals)

    # node evidence
    save("node_evidence.json", node_evidence())

    # wasm enumeration
    print("enumerating codes...", flush=True)
    codes = enum_codes(height)
    if LIMIT_CODES:
        codes = codes[:LIMIT_CODES]
    save("codes.json", codes)
    print("codes:", len(codes), flush=True)

    code_contracts = {}
    with cf.ThreadPoolExecutor(CONC) as ex:
        for cid, cl in ex.map(lambda c: enum_contracts(c["code_id"], height), codes):
            code_contracts[cid] = cl
    allc = [c for v in code_contracts.values() for c in v]
    save("code_contracts.json", code_contracts)
    print("contracts:", len(allc), flush=True)

    infos = {}
    with cf.ThreadPoolExecutor(CONC) as ex:
        for n, (addr, i) in enumerate(ex.map(lambda a: contract_info(a, height), allc)):
            infos[addr] = i
            if n and n % 2000 == 0:
                print("infos:", n, flush=True)
    save("contract_infos.json", infos)

    bals = {}
    with cf.ThreadPoolExecutor(CONC) as ex:
        for n, (addr, b) in enumerate(ex.map(lambda a: balances(a, height), allc)):
            bals[addr] = b
            if n and n % 2000 == 0:
                print("balances:", n, flush=True)
    save("contract_balances.json", bals)

    # osmosis + prices
    save("osmosis_pools.json", osmosis_pools())
    save("prices.json", llama_prices())

    print("DONE", flush=True)

if __name__ == "__main__":
    main()
