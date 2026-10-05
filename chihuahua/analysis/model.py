#!/usr/bin/env python3
"""
C2-06 Chihuahua governance-capture model (read-only, public endpoints only).

Computes, from live chain state:
  1. gov params (via ABCI on the public RPC), staking pool, supply, community-pool
     accounting and the distribution module's actual balances;
  2. the CP spend cap per denom (SDK v0.54 DistributeFromFeePool caps at the
     fee-pool DecCoins accounting AND the module bank balance);
  3. HUAHUA market depth: every Osmosis pool (gamm + CL + other) containing HUAHUA,
     with counterpart USD value -> the max realizable value of a HUAHUA dump;
  4. Chihuahua native x/liquidity DEX reserves;
  5. cost/benefit of the two capture paths (solo-quorum vs deposit+validator-vote).

Outputs: model.json + model.md in --outdir (default: ./out).
No secrets, no transactions. Public LCD/RPC + price APIs only.
"""
import argparse, base64, hashlib, json, os, statistics, subprocess, sys, time
from datetime import datetime, timezone

UA = "Mozilla/5.0 (X11; Linux x86_64) research"

CHIH_LCD = "https://api.chihuahua.wtf"
CHIH_RPC = "https://rpc.chihuahua.wtf"
OSM_LCD = "https://lcd.osmosis.zone"
DL = "https://coins.llama.fi/prices/current/"
CG = "https://api.coingecko.com/api/v3"

HH_DENOM = "uhuahua"
HH_ON_OSMOSIS = "ibc/B9E0A1A524E98BB407D3CED8720EFEFD186002F90C1B1B7964811DD0CCC12228"
OSMOSIS_CHIH_CHANNEL = 113  # osmosis channel-113 <-> chihuahua channel-7
LIQUID_DENOMS = {
    "uosmo",
    "ibc/27394FB092D2ECCD56123C74F36E4C1F926001CEADA9CA97EA622B25F41E5EB2",  # uatom
    "ibc/498A0751C798A0D9A389AA3691123DADA57DAA4FE165D5C75894505B876BA6E4",  # uusdc
    "ibc/4ABBEF4C8926DDDB320AE5188CFD63267ABBCEFC0583E4AE05D6E5AA2401DDAB",  # usdt
    "factory/osmo147h5x9pcj7lm0cttlaefx6sqq5vdfnmwfcqxkmjd7exqm9gc7grqhr75m0/alloyed/allUSDC",
}

# Price map (USD per human unit). Sources recorded in model.json.
PRICES = {
    "uosmo": ("0.03600818367980535", "defillama coingecko:osmosis"),
    "ibc/27394FB092D2ECCD56123C74F36E4C1F926001CEADA9CA97EA622B25F41E5EB2": ("1.7945052125403327", "defillama coingecko:cosmos (uatom on osmosis)"),
    "ibc/498A0751C798A0D9A389AA3691123DADA57DAA4FE165D5C75894505B876BA6E4": ("1.0", "noble USDC (1:1)"),
    "ibc/4ABBEF4C8926DDDB320AE5188CFD63267ABBCEFC0583E4AE05D6E5AA2401DDAB": ("1.0", "USDT (1:1)"),
    "factory/osmo147h5x9pcj7lm0cttlaefx6sqq5vdfnmwfcqxkmjd7exqm9gc7grqhr75m0/alloyed/allUSDC": ("1.0", "alloyed allUSDC (1:1)"),
    "factory/osmo1z6r6qdknhgsc0zeracktgpcxf43j6sekq07nw8sxduc9lg0qjjlqfu25e3/alloyed/allBTC": ("85249.12", "defillama coingecko:bitcoin"),
    "factory/osmo1csp8fk353hnq2tmulklecxpex43qmjvrkxjcsh4c3eqcw2vjcslq5jls9v/alloyed/allLTC": ("70.13", "defillama coingecko:litecoin"),
    "ibc/23104D411A6EB6031FA92FB75F227422B84989969E91DCAD56A535DD7FF0A373": ("1.1468345162273383", "defillama coingecko:ondo-us-dollar-yield (ausdy)"),
    "ibc/BE1BB42D4BE3C30D50B68D7C41DB4DFCE9678E8EF8C539F6E6A9345048894FCC": ("0.005787279226646398", "defillama coingecko:terrausd (USTC)"),
    "ibc/0EF15DF2F02480ADE0BB6E85D9EBB5DAEA2836D3860E9F97F9AADE4F57A31AA0": ("0.00005260479605242329", "defillama coingecko:terra-luna (LUNC)"),
}
# Unpriced memecoins / dead tokens -> 0 (documented)
ZERO_PRICE_DENOMS = [
    "ibc/183C0BB962D2F57C957E0B134CFA0AC9D6F755C02DE9DC2A59089BA23009DEC3",  # ninja (injective)
    "ibc/794CF0A448ECA518B9FEAB3356BD283E8762460F8FE87A013E6F9DBA6C53601C",  # Chihuahua token
    "ibc/884EBC228DFCE8F1304D917A712AA9611427A6C1ECC3179B2E91D7468FB091A2",  # uhava
    "ibc/9B8EC667B6DF55387DC0F3ACC4F187DA6921B0806ED35DE6B04DE96F5AB81F53",  # uwoof
    "ibc/C12C353A83CD1005FC38943410B894DBEC5F2ABC97FC12908F0FB03B970E8E1B",  # udoki
    "factory/osmo1n6asrjy9754q8y9jsxqf557zmsv3s3xa5m9eg5/usherpa",
    "factory/osmo1n6asrjy9754q8y9jsxqf557zmsv3s3xa5m9eg5/uspice",
    "ibc/6F4EFBEAF2659742F33499C9B4D272CFD824DD785156DF4C5C453F95CEF27D98",  # ucrbrus (priced via pool 661)
    "ibc/41999DF04D9441DAC0DF5D8291DF4333FBCBA810FFD63FDCE34FDF41EF37B6F7",  # ucrbrus (priced via pool 661)
    "ibc/EB7FB9C8B425F289B63703413327C2051030E848CE4EAAEA2E51199D6D39D3EC",  # utori (priced via pool 816)
    "ibc/2FFE07C4B4EFC0DDA099A16C6AF3C9CCA653CC56077E87217A585D48794B0BC7",  # AWIF (priced via pool 1357)
]


def sh(p):
    return "ibc/" + hashlib.sha256(p.encode()).hexdigest().upper()


def curl(url, timeout=40):
    try:
        r = subprocess.run(["curl", "-s", "--max-time", str(timeout), "-A", UA, url],
                           capture_output=True, text=True)
        return r.stdout
    except Exception as e:
        return ""


def jget(url, timeout=40):
    out = curl(url, timeout)
    try:
        return json.loads(out)
    except Exception:
        return None


def abci(path, data_b64=""):
    payload = json.dumps({"jsonrpc": "2.0", "id": 1, "method": "abci_query",
                          "params": {"path": path, "data": data_b64, "prove": False}})
    r = subprocess.run(["curl", "-s", "--max-time", "30", "-X", "POST",
                        "-H", "Content-Type: application/json", "-d", payload, CHIH_RPC],
                       capture_output=True, text=True)
    try:
        d = json.loads(r.stdout)
        return d["result"]["response"]
    except Exception:
        return {}


def decode_varint(b, i):
    v = 0; s = 0
    while i < len(b):
        c = b[i]; v |= (c & 0x7F) << s; i += 1
        if not (c & 0x80):
            break
        s += 7
    return v, i


def pb_fields(b):
    """yield (field_no, wire_type, value_bytes_or_int)"""
    i = 0
    while i < len(b):
        try:
            tag, i = decode_varint(b, i)
        except Exception:
            return
        f, wt = tag >> 3, tag & 7
        if wt == 0:
            v, i = decode_varint(b, i)
            yield f, wt, v
        elif wt == 2:
            ln, i = decode_varint(b, i)
            yield f, wt, b[i:i + ln]
            i += ln
        elif wt == 1:
            i += 8
        elif wt == 5:
            i += 4
        else:
            return


def gov_params_abci():
    r = abci("/cosmos.gov.v1.Query/Params")
    val = r.get("value")
    if not val:
        return None, None
    raw = base64.b64decode(val)
    # QueryParamsResponse { Params params = 1; }
    out = {"raw": raw.hex(), "height": r.get("height")}
    for f, wt, v in pb_fields(raw):
        if wt == 2:
            # try to parse any embedded message as Params
            probe = list(pb_fields(v))
            if not any(pf == 1 and pwt == 2 for pf, pwt, _ in probe):
                continue
            p = v
            out["params_field"] = f
            coins = []

            def parse_coin(cb):
                den = amt = None
                for f3, wt3, v3 in pb_fields(cb):
                    if f3 == 1: den = v3.decode()
                    if f3 == 2: amt = v3.decode()
                return {"denom": den, "amount": amt}

            for f2, wt2, v2 in pb_fields(p):
                if f2 == 1 and wt2 == 2:
                    coins.append(parse_coin(v2))
                elif f2 in (2, 3, 10) and wt2 == 2:  # Duration{seconds}
                    secs = None
                    for f3, wt3, v3 in pb_fields(v2):
                        if f3 == 1 and wt3 == 0:
                            secs = v3
                    out[{2: "max_deposit_period", 3: "voting_period",
                         10: "expedited_voting_period"}[f2]] = secs
                elif f2 in (4, 5, 6, 7, 8, 11, 16) and wt2 == 2:
                    out[{4: "quorum", 5: "threshold", 6: "veto_threshold",
                         7: "min_initial_deposit_ratio", 8: "proposal_cancel_ratio",
                         11: "expedited_threshold", 16: "min_deposit_ratio"}[f2]] = v2.decode()
                elif f2 == 12 and wt2 == 2:
                    out["expedited_min_deposit"] = parse_coin(v2)
                elif f2 == 15 and wt2 == 0:
                    out["burn_vote_veto"] = bool(v2)
            out["min_deposit"] = coins
    return out, r.get("height")


def fetch_state():
    st = {}
    blocks = jget(f"{CHIH_LCD}/cosmos/base/tendermint/v1beta1/blocks/latest")
    if blocks:
        st["chihuahua_height"] = int(blocks["block"]["header"]["height"])
        st["chihuahua_time"] = blocks["block"]["header"]["time"]
    pool = jget(f"{CHIH_LCD}/cosmos/staking/v1beta1/pool")
    st["staking_pool"] = pool.get("pool") if pool else None
    sup = jget(f"{CHIH_LCD}/cosmos/bank/v1beta1/supply/by_denom?denom=uhuahua")
    st["supply_uhuahua"] = sup.get("amount", {}).get("amount") if sup else None
    cp = jget(f"{CHIH_LCD}/cosmos/distribution/v1beta1/community_pool")
    st["community_pool"] = cp.get("pool") if cp else None
    dist = jget(f"{CHIH_LCD}/cosmos/bank/v1beta1/balances/chihuahua1jv65s3grqf6v6jl3dp4t6c9t9rk99cd8y2fjga?pagination.limit=200")
    st["distribution_module_balances"] = dist.get("balances") if dist else None
    vals = jget(f"{CHIH_LCD}/cosmos/staking/v1beta1/validators?status=BOND_STATUS_BONDED&pagination.limit=200")
    st["validators"] = vals.get("validators") if vals else None
    st["gov_params"], st["gov_params_height"] = gov_params_abci()
    st["distribution_params"] = jget(f"{CHIH_LCD}/cosmos/distribution/v1beta1/params")
    # native DEX pools
    lp = jget(f"{CHIH_LCD}/cosmos/liquidity/v1beta1/pools")
    st["native_liquidity_pools"] = lp.get("pools") if lp else None
    return st


def fetch_native_reserves(st):
    out = []
    for p in (st.get("native_liquidity_pools") or []):
        b = jget(f"{CHIH_LCD}/cosmos/bank/v1beta1/balances/{p['reserve_account_address']}")
        out.append({"pool_id": p["id"], "denoms": p["reserve_coin_denoms"],
                    "balances": b.get("balances") if b else None})
    st["native_liquidity_reserves"] = out
    return out


def fetch_osmosis_pools():
    d = jget(f"{OSM_LCD}/osmosis/poolmanager/v1beta1/all-pools?pagination.limit=4000", timeout=120)
    if d and d.get("pools"):
        return d["pools"]
    return []


def huahua_pools(pools):
    return [p for p in pools if HH_ON_OSMOSIS in json.dumps(p)]


def pool_counterpart_value(p, price_map, spot_hh):
    """Return (counterpart_denom, human_amount, usd) for a HUAHUA pool."""
    t = p.get("@type", "")
    if "gamm" in t:
        cp = None; hh_amt = None
        for a in p["pool_assets"]:
            den = a["token"]["denom"]; amt = int(a["token"]["amount"])
            if den == HH_ON_OSMOSIS: hh_amt = amt / 1e6
            else: cp = (den, amt / 1e6)
        if not cp: return None
        den, amt = cp
        px = price_map.get(den)
        return {"denom": den, "human": amt, "usd": amt * px if px is not None else 0.0,
                "priced": px is not None, "kind": "gamm",
                "liquid": den in LIQUID_DENOMS}
    if "concentratedliquidity" in t:
        t0, t1 = p.get("token0"), p.get("token1")
        try:
            L = float(p.get("current_tick_liquidity", "0"))
            sq = float(p.get("current_sqrt_price", "0"))
        except Exception:
            return None
        if L <= 0 or sq <= 0: return None
        if t0 == HH_ON_OSMOSIS:
            cp_den, cp_raw = t1, L * sq
        elif t1 == HH_ON_OSMOSIS:
            cp_den, cp_raw = t0, L / sq
        else:
            return None
        # decimals: 6 for all normal tokens; 18 for ausdy
        dec = 18 if cp_den.endswith("A373") or "ausdy" in cp_den else 6
        amt = cp_raw / (10 ** dec)
        px = price_map.get(cp_den)
        return {"denom": cp_den, "human": amt, "usd": amt * px if px is not None else 0.0,
                "priced": px is not None, "kind": "cl", "liquidity": L, "sqrtP": sq,
                "liquid": cp_den in LIQUID_DENOMS}
    return None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--outdir", default="out")
    args = ap.parse_args()
    os.makedirs(args.outdir, exist_ok=True)

    model = {"generated_at": datetime.now(timezone.utc).isoformat(), "finding": "C2-06"}

    # --- prices ---
    dl = jget(DL + "coingecko:osmosis,coingecko:cosmos,coingecko:bitcoin,coingecko:litecoin,coingecko:terrausd,coingecko:terra-luna,coingecko:ondo-us-dollar-yield")
    cg = jget(f"{CG}/simple/price?ids=chihuahua-token&vs_currencies=usd&include_market_cap=true&include_24hr_vol=true&include_last_updated_at=true")
    model["prices"] = {"defillama": (dl or {}).get("coins", {}), "coingecko_huahua": cg}
    price_map = {k: float(v[0]) for k, v in PRICES.items()}

    # --- chihuahua state ---
    st = fetch_state()
    fetch_native_reserves(st)
    model["chihuahua_state"] = st

    gp = st.get("gov_params") or {}
    min_dep = None
    if gp.get("min_deposit"):
        min_dep = int(gp["min_deposit"][0]["amount"]) / 1e6  # HUAHUA
    exp_dep = None
    if gp.get("expedited_min_deposit"):
        exp_dep = int(gp["expedited_min_deposit"]["amount"]) / 1e6

    bonded = int(st["staking_pool"]["bonded_tokens"]) / 1e6 if st.get("staking_pool") else None
    supply = int(st["supply_uhuahua"]) / 1e6 if st.get("supply_uhuahua") else None
    q = float(gp.get("quorum", "0.334"))
    solo_quorum = bonded * q / (1 - q) if bonded else None

    cp_pool = {c["denom"]: float(c["amount"]) for c in (st.get("community_pool") or [])}
    cp_mod = {c["denom"]: int(c["amount"]) for c in (st.get("distribution_module_balances") or [])}

    # --- osmosis market ---
    pools = fetch_osmosis_pools()
    hp = huahua_pools(pools)
    model["osmosis"] = {"height_query": None, "n_pools_total": len(pools), "n_huahua_pools": len(hp)}

    # derive auxiliary prices from on-chain pools (CRBRUS via pool 661, TORI via 816, AWIF via 1357)
    def pool_by_id(pid):
        for p in pools:
            if p.get("id") == str(pid): return p
        return None
    def gamm_price(pid, base_denom, quote_denom, quote_px):
        p = pool_by_id(pid)
        if not p or "gamm" not in p.get("@type", ""): return None
        amts = {a["token"]["denom"]: int(a["token"]["amount"]) / 1e6 for a in p["pool_assets"]}
        if base_denom in amts and quote_denom in amts and amts[base_denom] > 0:
            return amts[quote_denom] / amts[base_denom] * quote_px
        return None
    crb = gamm_price(661, "ibc/41999DF04D9441DAC0DF5D8291DF4333FBCBA810FFD63FDCE34FDF41EF37B6F7", "uosmo", price_map["uosmo"])
    tori = gamm_price(816, "ibc/EB7FB9C8B425F289B63703413327C2051030E848CE4EAAEA2E51199D6D39D3EC", "uosmo", price_map["uosmo"])
    awif = gamm_price(1357, "ibc/2FFE07C4B4EFC0DDA099A16C6AF3C9CCA653CC56077E87217A585D48794B0BC7", "ibc/498A0751C798A0D9A389AA3691123DADA57DAA4FE165D5C75894505B876BA6E4", 1.0)
    if crb: price_map["ibc/41999DF04D9441DAC0DF5D8291DF4333FBCBA810FFD63FDCE34FDF41EF37B6F7"] = crb
    if crb: price_map["ibc/6F4EFBEAF2659742F33499C9B4D272CFD824DD785156DF4C5C453F95CEF27D98"] = crb
    if tori: price_map["ibc/EB7FB9C8B425F289B63703413327C2051030E848CE4EAAEA2E51199D6D39D3EC"] = tori
    if awif: price_map["ibc/2FFE07C4B4EFC0DDA099A16C6AF3C9CCA653CC56077E87217A585D48794B0BC7"] = awif
    for d in ZERO_PRICE_DENOMS:
        price_map.setdefault(d, 0.0)
    model["derived_prices"] = {"crbrus": crb, "tori": tori, "awif": awif}

    venue_rows = []
    dump_ceiling = 0.0
    dump_ceiling_liquid = 0.0
    hh_in_pools = 0.0
    for p in hp:
        cv = pool_counterpart_value(p, price_map, None)
        # HUAHUA amount in pool
        t = p.get("@type", "")
        hh_amt = 0.0
        if "gamm" in t:
            for a in p["pool_assets"]:
                if a["token"]["denom"] == HH_ON_OSMOSIS: hh_amt = int(a["token"]["amount"]) / 1e6
        elif "concentratedliquidity" in t:
            try:
                L = float(p.get("current_tick_liquidity", "0")); sq = float(p.get("current_sqrt_price", "0"))
                if p.get("token0") == HH_ON_OSMOSIS and sq > 0: hh_amt = L / sq / 1e6
                elif p.get("token1") == HH_ON_OSMOSIS and sq > 0: hh_amt = L * sq / 1e6
            except Exception:
                pass
        if cv and cv["priced"]:
            dump_ceiling += cv["usd"]
            if cv.get("liquid"):
                dump_ceiling_liquid += cv["usd"]
        hh_in_pools += hh_amt
        venue_rows.append({"pool_id": p.get("id"), "type": t.split(".")[-1], "huahua": hh_amt,
                           "counterpart": cv})
    model["osmosis"]["venues"] = sorted(venue_rows, key=lambda r: -(r["counterpart"]["usd"] if r["counterpart"] else 0))
    model["osmosis"]["huahua_in_pools"] = hh_in_pools
    model["osmosis"]["dump_ceiling_usd_priced_only"] = dump_ceiling
    model["osmosis"]["dump_ceiling_usd_liquid_only"] = dump_ceiling_liquid
    # Optimal split of the full CP uhuahua (X) across all liquid HUAHUA pools.
    # Maximize sum_i cp_i * x_i/(hh_i+x_i) s.t. sum x_i = X (constant-product approx;
    # CL pools approximated the same way at their active range).
    X = 7_400_000_000.0
    cand = []
    for r in venue_rows:
        cv = r["counterpart"]
        if not cv or not cv["priced"] or not cv.get("liquid"):
            continue
        if r["huahua"] > 0 and cv["usd"] > 0:
            cand.append((r["huahua"], cv["usd"]))
    # KKT: cp_i*hh_i/(hh_i+x_i)^2 = lam  ->  x_i = sqrt(cp_i*hh_i/lam) - hh_i
    def total_x(lam):
        s = 0.0
        for hh, cp in cand:
            x = (cp * hh / lam) ** 0.5 - hh
            if x > 0:
                s += x
        return s
    lo, hi = 1e-18, 1e6
    for _ in range(200):
        mid = (lo + hi) / 2
        if total_x(mid) > X:
            lo = mid
        else:
            hi = mid
    lam = (lo + hi) / 2
    opt = 0.0
    for hh, cp in cand:
        x = (cp * hh / lam) ** 0.5 - hh
        if x > 0:
            opt += cp * x / (hh + x)
    model["osmosis"]["dump_estimate_optimal_liquid_usd"] = opt
    # crude per-pool independent sum retained as an upper bound
    frac = 0.0
    for hh, cp in cand:
        frac += cp * X / (hh + X)
    model["osmosis"]["dump_estimate_fractional_liquid_usd"] = frac

    # native DEX
    native = []
    native_hh = 0.0
    native_cp_usd = 0.0
    for r in st.get("native_liquidity_reserves") or []:
        bal = {b["denom"]: int(b["amount"]) for b in (r.get("balances") or [])}
        hh = bal.get("uhuahua", 0) / 1e6
        native_hh += hh
        cpv = 0.0
        for den, amt in bal.items():
            if den == "uhuahua": continue
            cpv += (amt / 1e6) * price_map.get(den, 0.0)
        native_cp_usd += cpv
        native.append({"pool_id": r["pool_id"], "huahua": hh, "counterpart_usd": cpv, "balances": r.get("balances")})
    model["native_dex"] = {"pools": native, "huahua_total": native_hh, "counterpart_usd": native_cp_usd}

    # --- CP spend cap and values ---
    # decimals for CP denoms
    dec = {
        "uhuahua": 6,
        "factory/chihuahua1hplyuj2hzxd75q8686g9vm3uzrrny9ggvt8aza2csupgdp98vg2sp0e3h0/uhuahua.ash": 6,
        "factory/chihuahua1sj9verkuk8aa9jrngnpwup6zjht4vwngjlpemnt9w38ccp0qnlcswvsuzc/beer": 6,
        "factory/chihuahua1sj9verkuk8aa9jrngnpwup6zjht4vwngjlpemnt9w38ccp0qnlcswvsuzc/sbdc": 6,
        "factory/chihuahua1sj9verkuk8aa9jrngnpwup6zjht4vwngjlpemnt9w38ccp0qnlcswvsuzc/shib": 6,
        "factory/chihuahua1sj9verkuk8aa9jrngnpwup6zjht4vwngjlpemnt9w38ccp0qnlcswvsuzc/shiva": 6,
        "ibc/7D01429FF7542DBC41C261793B480B63FE7A83260C751989CC268BC7E852EB99": 6,  # ampGASH
        "ibc/B1C671DAA104B8D93C7E4F2C9E0BAD4FEEB7AD0FF39F0DE91B471CD92DB077B5": 6,  # uatom
        "ibc/C1F002C33A682AEEFDC87E1CEB655FBC05F9A58F31039ABF1DDF902DE25E5D8F": 18,  # adgm
    }
    hh_spot = float(cg["chihuahua-token"]["usd"]) if cg and cg.get("chihuahua-token") else 4.56e-6
    cp_assets = []
    cp_realizable = 0.0
    cp_realizable_marked = 0.0
    cp_nominal = 0.0
    for den, decv in dec.items():
        pool_base = cp_pool.get(den, 0.0)      # base units (may be fractional DecCoins)
        mod_base = float(cp_mod.get(den, 0))   # base units (integer)
        cap_base = min(int(pool_base), int(mod_base))  # max integer base units spendable
        human = cap_base / (10 ** decv)
        if den == "uhuahua":
            px = hh_spot
            # spot value is nominal; realizable = dump into every HUAHUA pool
            real = dump_ceiling_liquid + native_cp_usd
            real_marked = dump_ceiling + native_cp_usd
            note = ("spot value nominal; realizable = dump into all HUAHUA pools "
                    "(liquid counterpart only; marked includes illiquid memecoins)")
        elif den.startswith("ibc/B1C671"):  # uatom
            px = price_map["ibc/27394FB092D2ECCD56123C74F36E4C1F926001CEADA9CA97EA622B25F41E5EB2"]
            real = real_marked = human * px
            note = "IBC to Osmosis, liquid"
        elif den == "ibc/7D01429FF7542DBC41C261793B480B63FE7A83260C751989CC268BC7E852EB99":
            px = 0.0
            real = real_marked = 0.0
            note = "ampGASH: no Osmosis/native pool; Migaloo sunsetting -> no market"
        elif den.startswith("ibc/C1F002"):
            px = 0.0
            real = real_marked = 0.0
            note = "ADGM from dogmond rollapp; no market found"
        else:
            px = 0.0
            real = real_marked = 0.0
            note = "tokenfactory memecoin/receipt; no market"
        nominal = human * px
        cp_nominal += nominal
        cp_realizable += real
        cp_realizable_marked += real_marked
        cp_assets.append({"denom": den, "pool_accounting_base": pool_base, "module_balance_base": mod_base,
                          "spend_cap_base": cap_base, "spend_cap_human": human, "price_usd": px,
                          "nominal_usd": nominal, "realizable_usd": real,
                          "realizable_marked_usd": real_marked, "note": note})
    model["cp_assets"] = cp_assets
    model["cp_totals"] = {"nominal_usd": cp_nominal, "realizable_usd": cp_realizable,
                          "realizable_marked_usd": cp_realizable_marked}

    # --- attack model ---
    hh_spot_used = hh_spot
    dep_usd = (min_dep or 5_000_000) * hh_spot_used
    exp_usd = (exp_dep or 10_000_000) * hh_spot_used
    solo_usd_spot = (solo_quorum or 0) * hh_spot_used
    # cost to buy X HUAHUA from pool 606 (ATOM) — constant product estimate
    p606 = pool_by_id(606)
    buy_est = None
    if p606:
        amts = {a["token"]["denom"]: int(a["token"]["amount"]) for a in p606["pool_assets"]}
        x = amts.get(HH_ON_OSMOSIS, 0); y = amts.get("ibc/27394FB092D2ECCD56123C74F36E4C1F926001CEADA9CA97EA622B25F41E5EB2", 0)
        if x and y and min_dep:
            dx = min_dep * 1e6
            dy = y * dx / (x + dx)
            buy_est = dy / 1e6 * price_map["ibc/27394FB092D2ECCD56123C74F36E4C1F926001CEADA9CA97EA622B25F41E5EB2"]
    model["attack"] = {
        "gov_params": gp,
        "bonded_huahua": bonded, "supply_huahua": supply, "quorum": q,
        "solo_quorum_stake_huahua": solo_quorum,
        "solo_quorum_stake_usd_spot": solo_usd_spot,
        "min_deposit_huahua": min_dep, "min_deposit_usd": dep_usd,
        "expedited_min_deposit_usd": exp_usd,
        "voting_period_days": (gp.get("voting_period") or 432000) / 86400,
        "expedited_voting_period_days": (gp.get("expedited_voting_period") or 86400) / 86400,
        "huahua_in_osmosis_pools": hh_in_pools,
        "huahua_in_native_dex": native_hh,
        "buy_5m_deposit_cost_usd_via_pool606": buy_est,
        "pathA_piggyback": {
            "cost_usd_refundable": dep_usd, "cost_usd_if_vetoed": dep_usd,
            "proceeds_realizable_usd": cp_realizable, "proceeds_nominal_usd": cp_nominal,
            "gate": "20 bonded validators must vote yes; historically 95%+ yes, turnout 66-77% of bonded",
        },
        "pathB_solo_quorum": {
            "required_huahua": solo_quorum, "cost_usd_spot": solo_usd_spot,
            "available_huahua_onchain": hh_in_pools + native_hh,
            "feasible": bool(solo_quorum and (hh_in_pools + native_hh) > solo_quorum),
            "note": "cannot acquire required stake from on-chain liquidity; proceeds < spot cost",
        },
    }
    model["attack"]["net_pathA_realizable_usd"] = cp_realizable - dep_usd
    model["attack"]["net_pathA_nominal_usd"] = cp_nominal - dep_usd

    with open(os.path.join(args.outdir, "model.json"), "w") as f:
        json.dump(model, f, indent=1, default=str)

    # markdown summary
    L = []
    L.append(f"# C2-06 model output — {model['generated_at']}")
    L.append(f"\nChihuahua height: {st.get('chihuahua_height')}  gov params height: {st.get('gov_params_height')}")
    L.append(f"\nBonded: {bonded:,.2f} HUAHUA | supply: {supply:,.2f} | quorum {q}")
    L.append(f"\nSolo quorum stake: {solo_quorum:,.0f} HUAHUA = ${solo_usd_spot:,.2f} at spot ${hh_spot_used}")
    md_txt = f"{min_dep:,.0f}" if min_dep is not None else "n/a"
    ed_txt = f"{exp_dep:,.0f}" if exp_dep is not None else "n/a"
    L.append(f"Min deposit: {md_txt} HUAHUA = ${dep_usd:,.2f} | expedited: {ed_txt} = ${exp_usd:,.2f}")
    L.append(f"\nHUAHUA in Osmosis pools: {hh_in_pools:,.0f} | native DEX: {native_hh:,.0f}")
    L.append(f"Osmosis dump ceiling: liquid counterpart ${dump_ceiling_liquid:,.2f} | all marked ${dump_ceiling:,.2f} | native counterpart: ${native_cp_usd:,.2f}")
    L.append(f"\nCP nominal: ${cp_nominal:,.2f} | CP realizable: ${cp_realizable:,.2f} | marked ${cp_realizable_marked:,.2f}")
    L.append("\n## Top HUAHUA venues")
    for r in model["osmosis"]["venues"][:15]:
        cv = r["counterpart"]
        L.append(f"- pool {r['pool_id']} ({r['type']}): {r['huahua']:,.0f} HUAHUA | cp {cv['denom'][:28] if cv else '-'} {cv['human']:,.2f} = ${cv['usd']:,.2f}" if cv else f"- pool {r['pool_id']}: {r['huahua']:,.0f} HUAHUA")
    L.append("\n## CP assets (spend cap)")
    for a in cp_assets:
        L.append(f"- {a['denom'][:70]} cap {a['spend_cap_human']:,.6f} | nominal ${a['nominal_usd']:,.2f} | realizable ${a['realizable_usd']:,.2f} / marked ${a['realizable_marked_usd']:,.2f} ({a['note']})")
    with open(os.path.join(args.outdir, "model.md"), "w") as f:
        f.write("\n".join(L) + "\n")
    print("\n".join(L))


if __name__ == "__main__":
    main()
