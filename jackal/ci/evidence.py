#!/usr/bin/env python3
"""
C2-35 Jackal (jackal-1) — read-only live-state collection + governance-capture / liquidity model.

Public endpoints only. No keys, no transactions. Safe to run locally and in CI.

Outputs:
  <out>/raw/*.json     raw state (heights recorded)
  <out>/model.json     machine-readable model
  <out>/model.md       human-readable model

Usage:
  python3 evidence.py [--out DIR] [--gauge-cap N] [--workers N]
"""
import argparse, base64, concurrent.futures as cf, datetime, hashlib, json, os, sys, time
import urllib.parse, urllib.request

JKL_DENOM_OSMOSIS = "ibc/8E697BDABE97ACE8773C6DF7402B2D1D5104DD1EEABE12608E3469B7F64C15BA"

JACKAL_ENDPOINTS = [
    "https://api.jackalprotocol.com",
    "https://api-jackal.polkachu.com",
    "https://jackal-api.polkachu.com",
    "https://api.jackal.nodestake.org",
    "https://jackal-api.kleomedes.network",
    "https://jackal.api.pocket.network",
    "https://rest.cosmos.directory/jackal",
]
OSMOSIS_ENDPOINTS = [
    "https://lcd.osmosis.zone",
    "https://osmosis-api.polkachu.com",
    "https://osmosis-rest.publicnode.com",
    "https://rest.cosmos.directory/osmosis",
    "https://osmosis.api.pocket.network",
]

# ---------------------------------------------------------------- http helpers
class Http:
    def __init__(self, bases, timeout=45, retries=4):
        self.bases = bases
        self.timeout = timeout
        self.retries = retries
        self.i = 0

    def get(self, path, timeout=None, retries=None):
        last = None
        retries = retries or self.retries
        retries = max(retries, len(self.bases))
        for attempt in range(retries):
            base = self.bases[(self.i + attempt) % len(self.bases)]
            try:
                req = urllib.request.Request(base + path, headers={"User-Agent": "zombie-research/1.0"})
                with urllib.request.urlopen(req, timeout=timeout or self.timeout) as r:
                    self.i = (self.i + attempt) % len(self.bases)
                    return json.load(r)
            except Exception as e:  # noqa
                last = e
                time.sleep(0.8 + 0.4 * attempt)
        raise last


# ---------------------------------------------------------------- bech32
CHARSET = "qpzry9x8gf2tvdw0s3jn54khce6mua7l"


def _polymod(values):
    gen = [0x3B6A57B2, 0x26508E6D, 0x1EA119FA, 0x3D4233DD, 0x2A1462B3]
    chk = 1
    for v in values:
        b = chk >> 25
        chk = (chk & 0x1FFFFFF) << 5 ^ v
        for i in range(5):
            chk ^= gen[i] if (b >> i) & 1 else 0
    return chk


def _hrp_expand(h):
    return [ord(x) >> 5 for x in h] + [0] + [ord(x) & 31 for x in h]


def _convert(data, f, t, pad=True):
    acc = bits = 0
    ret = []
    maxv = (1 << t) - 1
    for value in data:
        acc = (acc << f) | value
        bits += f
        while bits >= t:
            bits -= t
            ret.append((acc >> bits) & maxv)
    if pad and bits:
        ret.append((acc << (t - bits)) & maxv)
    return ret


def bech32(prefix, data):
    d5 = _convert(data, 8, 5)
    pm = _polymod(_hrp_expand(prefix) + d5 + [0] * 6) ^ 1
    chk = [(pm >> 5 * (5 - i)) & 31 for i in range(6)]
    return prefix + "1" + "".join(CHARSET[x] for x in d5 + chk)


def mod_addr(name, full32=False):
    h = hashlib.sha256(name.encode()).digest()
    return bech32("jkl", h if full32 else h[:20])


def gauge_addr(gauge_id_b64):
    raw = base64.b64decode(gauge_id_b64)
    name = "gauge:" + raw.hex()
    return bech32("jkl", hashlib.sha256(name.encode()).digest())


# ---------------------------------------------------------------- collection
MODULES = ["fee_collector", "distribution", "gov", "mint", "staking", "bonded_tokens_pool",
           "not_bonded_tokens_pool", "ibc", "transfer", "interchainaccounts", "storage",
           "filetree", "notifications", "rns", "jklmint", "oracle", "wasm", "upgrade",
           "params", "auth", "bank", "capability", "crisis", "evidence", "feegrant",
           "slashing", "authz", "storage_collateral_name"]
# POL is a regular account derived via canine types.GetAccount (full sha256, 32-byte address)
FULL32_ACCOUNTS = ["protocol_owned_liq"]


def paginate(http, path, key, limit=1000, max_pages=120, timeout=None):
    out, next_key, pages = [], None, 0
    while pages < max_pages:
        u = f"{path}?pagination.limit={limit}"
        if next_key:
            u += "&pagination.key=" + urllib.parse.quote(next_key)
        try:
            d = http.get(u, timeout=timeout)
        except Exception:
            break
        out += d.get(key, [])
        next_key = d.get("pagination", {}).get("next_key")
        pages += 1
        if not next_key:
            break
    return out, next_key


def collect(out, gauge_cap=30000, workers=20):
    os.makedirs(out, exist_ok=True)
    raw = os.path.join(out, "raw")
    os.makedirs(raw, exist_ok=True)
    jk = Http(JACKAL_ENDPOINTS)
    osm = Http(OSMOSIS_ENDPOINTS)

    def save(name, obj):
        with open(os.path.join(raw, name), "w") as f:
            json.dump(obj, f, indent=1)

    state = {}

    blk = jk.get("/cosmos/base/tendermint/v1beta1/blocks/latest")
    state["height"] = int(blk["block"]["header"]["height"])
    state["block_time"] = blk["block"]["header"]["time"]
    state["chain_id"] = blk["block"]["header"]["chain_id"]
    save("latest_block.json", state)

    ni = jk.get("/cosmos/base/tendermint/v1beta1/node_info")
    state["app"] = ni["application_version"]["name"] + " " + ni["application_version"]["version"]
    deps = {d["path"]: d["version"] for d in ni["application_version"]["build_deps"]}
    state["deps"] = {k: deps[k] for k in deps if any(
        s in k for s in ["wasmd", "wasmvm", "cosmos-sdk", "ibc-go", "tendermint/tendermint"])}
    save("node_info.json", ni)

    pool = jk.get("/cosmos/staking/v1beta1/pool")["pool"]
    state["bonded_ujkl"] = int(pool["bonded_tokens"])
    state["not_bonded_ujkl"] = int(pool["not_bonded_tokens"])
    save("staking_pool.json", pool)

    state["supply_ujkl"] = int(jk.get("/cosmos/bank/v1beta1/supply/ujkl")["amount"]["amount"])
    save("supply_ujkl.json", {"amount": {"denom": "ujkl", "amount": str(state["supply_ujkl"])}})
    cp = jk.get("/cosmos/distribution/v1beta1/community_pool")["pool"]
    state["community_pool"] = cp
    save("community_pool.json", cp)

    for key in ["depositparams", "votingparams", "tallyparams"]:
        save(f"gov_{key}.json", jk.get(f"/cosmos/params/v1beta1/params?subspace=gov&key={key}"))

    allvals, more = paginate(jk, "/cosmos/staking/v1beta1/validators", "validators", 500, max_pages=10)
    vals = [v for v in allvals if v.get("status") == "BOND_STATUS_BONDED"]
    state["bonded_validators"] = len(vals)
    save("validators_bonded.json", {"validators": vals})

    props, more = paginate(jk, "/cosmos/gov/v1beta1/proposals?pagination.reverse=true", "proposals", 50, max_pages=5)
    save("proposals.json", {"proposals": props})

    # module balances
    def bal(addr):
        try:
            return jk.get(f"/cosmos/bank/v1beta1/balances/{addr}", timeout=25)["balances"]
        except Exception:
            return []

    balances = {}
    with cf.ThreadPoolExecutor(max_workers=workers) as ex:
        futs = {m: ex.submit(bal, mod_addr(m)) for m in MODULES}
        futs.update({m: ex.submit(bal, mod_addr(m, full32=True)) for m in FULL32_ACCOUNTS})
        for m, f in futs.items():
            balances[m] = {"address": (mod_addr(m) if m not in FULL32_ACCOUNTS else mod_addr(m, True)),
                           "balances": f.result()}
    save("module_balances.json", balances)

    # wasm
    codes = []
    for i in range(1, 500):
        try:
            codes.append(jk.get(f"/cosmwasm/wasm/v1/code/{i}", timeout=20)["code_info"])
        except Exception:
            break
    save("wasm_codes.json", {"codes": codes})
    contracts = []
    for c in codes:
        cid = c.get("code_id")
        try:
            cl = jk.get(f"/cosmwasm/wasm/v1/code/{cid}/contracts?pagination.limit=500")["contracts"]
        except Exception:
            continue
        for addr in cl:
            row = {"code_id": cid, "address": addr}
            try:
                row["contract_info"] = jk.get(f"/cosmwasm/wasm/v1/contract/{addr}", timeout=20).get("contract_info", {})
            except Exception:
                pass
            row["balances"] = bal(addr)
            contracts.append(row)
    save("wasm_contracts.json", {"contracts": contracts})

    # storage module
    for name, path in [
        ("storage_providers.json", "/jackal/canine-chain/storage/providers?pagination.limit=500"),
        ("storage_stats.json", "/jackal/canine-chain/storage/storage_stats"),
        ("storage_network_size.json", "/jackal/canine-chain/storage/network_size"),
        ("storage_available_space.json", "/jackal/canine-chain/storage/available_space"),
        ("storage_payment_info.json", "/jackal/canine-chain/storage/payment_info?pagination.limit=500"),
    ]:
        try:
            save(name, jk.get(path))
        except Exception as e:
            save(name, {"error": str(e)})

    # gauges
    gauges, more = paginate(jk, "/jackal/canine-chain/storage/gauges", "gauges", 1000, max_pages=120)
    save("gauges.json", {"gauges": gauges, "truncated": bool(more)})
    state["gauges"] = len(gauges)

    # gauge balances (parallel, capped; light retries to bound runtime)
    jk_light = Http(JACKAL_ENDPOINTS, timeout=15, retries=3)

    def bal_light(addr):
        try:
            return jk_light.get(f"/cosmos/bank/v1beta1/balances/{addr}", timeout=15)["balances"]
        except Exception:
            return []

    gbal = {}
    with cf.ThreadPoolExecutor(max_workers=workers) as ex:
        futs = {}
        for g in gauges[:gauge_cap]:
            futs[g["id"]] = ex.submit(bal_light, gauge_addr(g["id"]))
        for gid, f in futs.items():
            gbal[gid] = f.result()
    save("gauge_balances.json", gbal)
    state["gauge_balances_checked"] = len(gbal)

    # IBC channels
    try:
        save("ibc_channels.json", jk.get("/ibc/core/channel/v1/channels?pagination.limit=300"))
    except Exception as e:
        save("ibc_channels.json", {"error": str(e)})

    # ---------------- osmosis: all pools, find JKL, balances
    osm_state = {}
    try:
        d = osm.get("/osmosis/gamm/v1beta1/pools?pagination.limit=1&pagination.count_total=true")
        osm_state["gamm_total"] = d.get("pagination", {}).get("total")
    except Exception as e:
        osm_state["gamm_total_error"] = str(e)
    gamm, more = paginate(osm, "/osmosis/gamm/v1beta1/pools", "pools", 1000, max_pages=40)
    osm_state["gamm_scanned"] = len(gamm)
    try:
        d = osm.get("/osmosis/concentratedliquidity/v1beta1/pools?pagination.limit=1&pagination.count_total=true")
        osm_state["cl_total"] = d.get("pagination", {}).get("total")
    except Exception as e:
        osm_state["cl_total_error"] = str(e)
    cl, more = paginate(osm, "/osmosis/concentratedliquidity/v1beta1/pools", "pools", 1000, max_pages=40)
    osm_state["cl_scanned"] = len(cl)

    pools = []
    for p in gamm:
        assets = p.get("pool_assets", [])
        if any(a["token"]["denom"] == JKL_DENOM_OSMOSIS for a in assets):
            pools.append({"type": "gamm", "id": p.get("id"), "address": p.get("address"),
                          "swap_fee": p.get("pool_params", {}).get("swap_fee"),
                          "assets": [{"denom": a["token"]["denom"], "amount": a["token"]["amount"],
                                      "weight": a.get("weight")} for a in assets]})
    for p in cl:
        if JKL_DENOM_OSMOSIS in (p.get("token0", ""), p.get("token1", "")):
            pools.append({"type": "cl", "id": p.get("id"), "address": p.get("address"),
                          "token0": p.get("token0"), "token1": p.get("token1"),
                          "spread_factor": p.get("spread_factor"),
                          "current_sqrt_price": p.get("current_sqrt_price"),
                          "current_tick_liquidity": p.get("current_tick_liquidity")})
    # pool balances (Osmosis endpoints!)
    def obal(addr):
        try:
            return osm.get(f"/cosmos/bank/v1beta1/balances/{addr}", timeout=25)["balances"]
        except Exception:
            return []
    with cf.ThreadPoolExecutor(max_workers=workers) as ex:
        futs = {p["id"]: ex.submit(obal, p["address"]) for p in pools}
        for p in pools:
            p["balances"] = futs[p["id"]].result()
    save("osmosis_jkl_pools.json", {"pools": pools, "scan": osm_state})
    try:
        d = osm.get("/cosmos/bank/v1beta1/supply/by_denom?denom=" + urllib.parse.quote(JKL_DENOM_OSMOSIS, safe=""))
        osm_state["jkl_supply_on_osmosis"] = d.get("amount", {}).get("amount")
    except Exception as e:
        osm_state["jkl_supply_error"] = str(e)

    # ---------------- prices
    prices = {}
    try:
        ids = ("jackal-protocol,osmosis,neta,fetch-ai,bitcanna,dogecoin,bitcoin,usd-coin,tether,"
               "sentinel,decentr,odin-protocol,rebus,ki,assetmantle")
        d = Http(["https://api.coingecko.com/api/v3"], timeout=30).get(
            f"/simple/price?ids={ids}&vs_currencies=usd&include_24hr_vol=true&include_market_cap=true")
        prices["coingecko"] = d
    except Exception as e:
        prices["coingecko_error"] = str(e)
    try:
        d = Http(["https://coins.llama.fi"], timeout=30).get(
            "/prices/current/coingecko:jackal-protocol,coingecko:osmosis")
        prices["defillama"] = d
    except Exception as e:
        prices["defillama_error"] = str(e)
    save("prices.json", prices)

    save("collect_meta.json", {"osm_scan": osm_state})
    return state, prices, pools, balances, contracts, gauges, gbal


# ---------------------------------------------------------------- model
def usd_price(prices):
    p = None
    try:
        p = prices["coingecko"]["jackal-protocol"]["usd"]
    except Exception:
        pass
    if p is None:
        try:
            p = prices["defillama"]["coins"]["coingecko:jackal-protocol"]["price"]
        except Exception:
            pass
    return p


def counter_price(prices, denom):
    cg = prices.get("coingecko", {})
    table = {
        "uosmo": cg.get("osmosis", {}).get("usd"),
        "ibc/498A0751C798A0D9A389AA3691123DADA57DAA4FE165D5C75894505B876BA6E4": cg.get("usd-coin", {}).get("usd", 1.0),
        "ibc/4ABBEF4C8926DDDB320AE5188CFD63267ABBCEFC0583E4AE05D6E5AA2401DDAB": cg.get("tether", {}).get("usd", 1.0),
        "ibc/297C64CC42B5A8D8F82FE2EBE208A6FE8F94B86037FA28C4529A23701C228F7A": cg.get("neta", {}).get("usd"),
        "ibc/5D1F516200EE8C6B2354102143B78A2DEDA25EDE771AC0F8DC3C1837C8FD4447": cg.get("fetch-ai", {}).get("usd"),
        "ibc/D805F1DA50D31B96E4282C1D4181EDDFB1A44A598BFF5666F4B43E4B8BEA95A5": cg.get("bitcanna", {}).get("usd"),
        "ibc/9712DBB13B9631EDFA9BF61B55F1B2D290B2ADB67E3A4EB3A875F3B6081B3B84": cg.get("sentinel", {}).get("usd"),
        "ibc/9BCB27203424535B6230D594553F1659C77EC173E36D9CF4759E7186EE747E84": cg.get("decentr", {}).get("usd"),
        "ibc/C360EF34A86D334F625E4CBB7DA3223AEA97174B61F35BB3758081A8160F7D9B": cg.get("odin-protocol", {}).get("usd"),
        "ibc/A1AC7F9EE2F643A68E3A35BCEB22040120BEA4059773BB56985C76BDFEBC71D9": cg.get("rebus", {}).get("usd"),
        "ibc/B547DC9B897E7C3AA5B824696110B8E3D2C31E3ED3F02FF363DCBAD82457E07E": cg.get("ki", {}).get("usd"),
        "ibc/CBA34207E969623D95D057D9B11B0C8B32B89A71F170577D982FDDE623813FFC": cg.get("assetmantle", {}).get("usd"),
    }
    if denom.endswith("/alloyed/allUSDC"):
        return cg.get("usd-coin", {}).get("usd", 1.0)
    if denom.endswith("/alloyed/allDOGE"):
        return cg.get("dogecoin", {}).get("usd")
    if denom.endswith("/alloyed/allBTC"):
        return cg.get("bitcoin", {}).get("usd")
    return table.get(denom)


def dump_gamm(x, y, dx, fee):
    """JKL (x) sold into pool with counterpart y; returns counterpart out after fee."""
    if x <= 0 or y <= 0 or dx <= 0:
        return 0.0
    out = y * dx / (x + dx)
    return out * (1.0 - fee)


def model(state, prices, pools, balances, contracts, gauges, gbal, rawdir):
    jkl = usd_price(prices)
    m = {"finding": "C2-35", "chain": "jackal-1", "height": state["height"],
         "block_time": state["block_time"], "app": state["app"], "deps": state["deps"],
         "jkl_price_usd": jkl, "prices": prices}
    cg = prices.get("coingecko", {})
    m["jkl_market"] = {
        "coingecko_usd": cg.get("jackal-protocol", {}).get("usd"),
        "coingecko_mcap": cg.get("jackal-protocol", {}).get("usd_market_cap"),
        "coingecko_24h_vol": cg.get("jackal-protocol", {}).get("usd_24h_vol"),
    }

    # gov params
    gp = {}
    for k in ["depositparams", "votingparams", "tallyparams"]:
        try:
            gp[k] = json.loads(json.load(open(os.path.join(rawdir, f"gov_{k}.json")))["param"]["value"])
        except Exception as e:
            gp[k] = {"error": str(e)}
    m["gov_params"] = gp

    B = state["bonded_ujkl"] / 1e6
    m["bonded_jkl"] = B
    m["not_bonded_jkl"] = state["not_bonded_ujkl"] / 1e6
    m["supply_jkl"] = state["supply_ujkl"] / 1e6
    cp_amt = 0
    for c in state["community_pool"]:
        if c["denom"] == "ujkl":
            cp_amt = float(c["amount"]) / 1e6
    m["community_pool_jkl"] = cp_amt
    m["community_pool_usd_nominal"] = cp_amt * jkl if jkl else None

    q = float(gp["tallyparams"].get("quorum", 0.334))
    veto = float(gp["tallyparams"].get("veto_threshold", 0.334))
    threshold = float(gp["tallyparams"].get("threshold", 0.5))
    min_dep = float(gp["depositparams"]["min_deposit"][0]["amount"]) / 1e6
    m["capture"] = {
        "min_deposit_jkl": min_dep,
        "min_deposit_usd": min_dep * jkl if jkl else None,
        "solo_quorum_stake_jkl": q / (1 - q) * B,
        "solo_quorum_stake_usd": q / (1 - q) * B * jkl if jkl else None,
        "beat_74pct_turnout_stake_jkl": 0.7436 * B,
        "beat_74pct_turnout_usd": 0.7436 * B * jkl if jkl else None,
        "beat_full_turnout_stake_jkl": B,
        "beat_full_turnout_usd": B * jkl if jkl else None,
        "veto_proof_74pct_stake_jkl": 0.7436 * B * (1 - veto) / veto,
        "prize_cp_usd_nominal": cp_amt * jkl if jkl else None,
        "sdk_line": "v0.45.17 (tally: quorum failure burns deposits; veto >33.4% burns; normal reject refunds)",
    }

    # pool inventory
    pool_rows = []
    total_counter_usd = 0.0
    for p in pools:
        row = {"type": p["type"], "id": p["id"], "address": p["address"]}
        jkl_amt = 0.0
        counters = []
        for b in (p.get("balances") or []):
            if not isinstance(b, dict):
                continue
            amt = float(b["amount"])
            if b["denom"] == JKL_DENOM_OSMOSIS:
                jkl_amt = amt / 1e6
            else:
                price = counter_price(prices, b["denom"])
                # decimals map (verified against the chain-registry osmosis asset list)
                dec = 6
                if b["denom"].endswith("/alloyed/allBTC") or b["denom"].endswith("/alloyed/allDOGE"):
                    dec = 8
                if "5D1F5162" in b["denom"]:  # FET
                    dec = 18
                if "A1AC7F9E" in b["denom"]:  # REBUS
                    dec = 18
                if b["denom"].endswith("/ba-ba"):
                    dec = 6  # unpriced anyway
                human = amt / (10 ** dec)
                usd = human * price if price else None
                counters.append({"denom": b["denom"], "amount": human, "price_usd": price, "usd": usd})
                if usd and price is not None:
                    # exclude illiquid NETA from the liquid bound but keep in row
                    total_counter_usd += usd
        row["jkl"] = jkl_amt
        row["counters"] = counters
        pool_rows.append(row)

    # liquid bound (exclude NETA — 24h vol <$2 — and unknown-price assets)
    liquid_bound = 0.0
    for r in pool_rows:
        for c in r["counters"]:
            if c["usd"] is None:
                continue
            if "297C64CC" in c["denom"]:  # NETA illiquid
                continue
            liquid_bound += c["usd"]
    m["pool_inventory"] = pool_rows
    m["pool_counter_usd_all_priced"] = total_counter_usd
    m["pool_counter_usd_liquid"] = liquid_bound
    m["osmosis_jkl_in_pools"] = sum(r["jkl"] for r in pool_rows)

    # realizable CP dump
    # (a) main gamm pool 832 exact
    dump_res = {}
    g832 = next((r for r in pool_rows if r["type"] == "gamm" and str(r["id"]) == "832"), None)
    if g832 and jkl:
        x = g832["jkl"]
        for c in g832["counters"]:
            if c["price_usd"]:
                out = dump_gamm(x, c["amount"], cp_amt, 0.003)
                dump_res["pool832_" + c["denom"][:12]] = {"out": out, "usd": out * c["price_usd"]}
                dump_res["pool832_usd"] = out * c["price_usd"]
                dump_res["pool832_out"] = out
                dump_res["pool832_denom"] = c["denom"]
    # (b) all gamm pools, proportional split by counterpart usd (rough)
    total_usd = 0.0
    for r in pool_rows:
        if r["type"] != "gamm":
            continue
        x = r["jkl"]
        for c in r["counters"]:
            if c["price_usd"] is None or x <= 0:
                continue
            share = 0.0
            # allocate CP proportionally to pool counterpart liquidity share
            denom_usd = sum((cc["usd"] or 0) for rr in pool_rows if rr["type"] == "gamm" for cc in rr["counters"])
            if denom_usd > 0:
                share = cp_amt * (c["usd"] or 0) / denom_usd
            fee = float(r.get("swap_fee") or 0.003)
            out = dump_gamm(x, c["amount"], share, fee)
            total_usd += out * c["price_usd"]
    dump_res["all_gamm_proportional_usd"] = total_usd
    m["cp_dump"] = dump_res

    # module balances
    mod_rows = []
    for name, info in balances.items():
        amt = 0.0
        bs = info.get("balances")
        if not isinstance(bs, list):
            bs = []
        for b in bs:
            if isinstance(b, dict) and b.get("denom") == "ujkl":
                amt = float(b["amount"]) / 1e6
        mod_rows.append({"module": name, "address": info["address"], "jkl": amt,
                         "usd": amt * jkl if jkl else None})
    m["module_balances"] = mod_rows

    # wasm
    wasm_total = 0.0
    for c in contracts:
        bs = c.get("balances")
        if not isinstance(bs, list):
            continue
        for b in bs:
            if isinstance(b, dict) and b.get("denom") == "ujkl":
                wasm_total += float(b["amount"]) / 1e6
    m["wasm"] = {"codes": len({c["code_id"] for c in contracts}) if contracts else 0,
                 "contracts": len(contracts), "held_jkl": wasm_total,
                 "held_usd": wasm_total * jkl if jkl else None,
                 "upload": "Everybody", "instantiate": "Everybody"}

    # gauges
    now = datetime.datetime.now(datetime.timezone.utc)
    planned = 0
    expired = 0
    bal_sum = 0.0
    for g in gauges:
        planned += sum(int(c["amount"]) for c in g.get("coins", []))
        try:
            if datetime.datetime.fromisoformat(g["end"].replace("Z", "+00:00")) < now:
                expired += 1
        except Exception:
            pass
    for gid, b in gbal.items():
        for c in (b if isinstance(b, list) else b.get("balances", [])):
            if isinstance(c, dict) and c.get("denom") == "ujkl":
                bal_sum += float(c["amount"]) / 1e6
    m["gauges"] = {"count": len(gauges), "planned_jkl": planned / 1e6,
                   "checked": len(gbal), "balance_jkl": bal_sum,
                   "balance_usd": bal_sum * jkl if jkl else None, "expired": expired}

    # classification
    m["classification"] = {
        "E-U_cwa_bound_usd": liquid_bound,
        "capture_cp_realizable_usd": dump_res.get("pool832_usd"),
        "capture_cp_nominal_usd": cp_amt * jkl if jkl else None,
        "P_distribution_module_jkl": next((r["jkl"] for r in mod_rows if r["module"] == "distribution"), None),
        "P_pol_jkl": next((r["jkl"] for r in mod_rows if r["module"] == "protocol_owned_liq"), None),
        "H-O_collateral_jkl": next((r["jkl"] for r in mod_rows if r["module"] == "storage_collateral_name"), None),
        "S_gauges_balance_usd": bal_sum * jkl if jkl else None,
    }
    return m


def load_raw(rawdir):
    """Reconstruct model inputs from raw JSON dumps (for --model-only runs)."""
    def rd(name):
        with open(os.path.join(rawdir, name)) as f:
            return json.load(f)

    lb = rd("latest_block.json")
    ni = rd("node_info.json")
    deps = {d["path"]: d["version"] for d in ni["application_version"]["build_deps"]}
    state = {
        "height": lb["height"], "block_time": lb["block_time"], "chain_id": lb["chain_id"],
        "app": ni["application_version"]["name"] + " " + ni["application_version"]["version"],
        "deps": {k: deps[k] for k in deps if any(s in k for s in ["wasmd", "wasmvm", "cosmos-sdk", "ibc-go", "tendermint/tendermint"])},
        "bonded_ujkl": int(rd("staking_pool.json")["bonded_tokens"]),
        "not_bonded_ujkl": int(rd("staking_pool.json")["not_bonded_tokens"]),
        "community_pool": rd("community_pool.json"),
        "gauges": len(rd("gauges.json")["gauges"]),
        "gauge_balances_checked": len(rd("gauge_balances.json")),
    }
    try:
        state["supply_ujkl"] = int(rd("supply_ujkl.json")["amount"]["amount"])
    except Exception:
        state["supply_ujkl"] = 0
    prices = rd("prices.json")
    pools = rd("osmosis_jkl_pools.json")["pools"]
    balances = rd("module_balances.json")
    contracts = rd("wasm_contracts.json")["contracts"]
    gauges = rd("gauges.json")["gauges"]
    gbal = rd("gauge_balances.json")
    return state, prices, pools, balances, contracts, gauges, gbal


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default="ci-out")
    ap.add_argument("--gauge-cap", type=int, default=30000)
    ap.add_argument("--workers", type=int, default=20)
    ap.add_argument("--model-only", action="store_true")
    args = ap.parse_args()
    out = args.out
    rawdir = os.path.join(out, "raw")
    if args.model_only:
        state, prices, pools, balances, contracts, gauges, gbal = load_raw(rawdir)
    else:
        state, prices, pools, balances, contracts, gauges, gbal = collect(out, args.gauge_cap, args.workers)
    m = model(state, prices, pools, balances, contracts, gauges, gbal, rawdir)
    with open(os.path.join(out, "model.json"), "w") as f:
        json.dump(m, f, indent=1)
    # markdown summary
    lines = []
    A = lines.append
    A(f"# Jackal C2-35 model — h {m['height']} ({m['block_time']})")
    A("")
    A(f"- JKL price: ${m['jkl_price_usd']} (CG mcap ${m['jkl_market'].get('coingecko_mcap')}, 24h vol ${m['jkl_market'].get('coingecko_24h_vol')})")
    A(f"- Bonded: {m['bonded_jkl']:,.2f} JKL | not-bonded {m['not_bonded_jkl']:,.2f} | supply {m['supply_jkl']:,.2f}")
    A(f"- Community pool: {m['community_pool_jkl']:,.2f} JKL = ${m['community_pool_usd_nominal']:,.2f} nominal")
    c = m["capture"]
    A(f"- Capture solo-quorum stake: {c['solo_quorum_stake_jkl']:,.0f} JKL = ${c['solo_quorum_stake_usd']:,.0f}; full turnout {c['beat_full_turnout_stake_jkl']:,.0f} JKL = ${c['beat_full_turnout_usd']:,.0f}; min deposit {c['min_deposit_jkl']:,.0f} JKL = ${c['min_deposit_usd']:.2f}")
    A(f"- CP realizable (dump into pool 832): ${(m['cp_dump'].get('pool832_usd') or 0):,.2f}; all-gamm proportional ${m['cp_dump'].get('all_gamm_proportional_usd', 0):,.2f}")
    A(f"- JKL pool counterpart: liquid ${m['pool_counter_usd_liquid']:,.2f}; all priced ${m['pool_counter_usd_all_priced']:,.2f} (NETA illiquid)")
    A(f"- Wasm: {m['wasm']['codes']} codes / {m['wasm']['contracts']} contracts holding {m['wasm']['held_jkl']:.2f} JKL (${m['wasm']['held_usd']:.2f})")
    A(f"- Gauges: {m['gauges']['count']} (planned {m['gauges']['planned_jkl']:.2f} JKL); checked {m['gauges']['checked']} balances = {m['gauges']['balance_jkl']:.2f} JKL (${m['gauges']['balance_usd']:.2f})")
    A(f"- Classification: E-U(CWA bound) ${m['classification']['E-U_cwa_bound_usd']:,.2f}; capture ${m['classification']['capture_cp_realizable_usd']:,.2f}; P distribution {m['classification']['P_distribution_module_jkl']:,.2f} JKL; POL {m['classification']['P_pol_jkl']:,.2f} JKL; H-O collateral {m['classification']['H-O_collateral_jkl']:,.2f} JKL")
    with open(os.path.join(out, "model.md"), "w") as f:
        f.write("\n".join(lines) + "\n")
    print("\n".join(lines))


if __name__ == "__main__":
    main()
