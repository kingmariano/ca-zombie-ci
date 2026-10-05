#!/usr/bin/env python3
"""C2-10 child verifier: check CEX listings and DSM presence on other IBC chains.

Read-only public API GETs (curl -4). Raw results saved under verify_market_raw/venues/.
"""
import json, os, subprocess, hashlib, urllib.parse, time

BASE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(BASE, "verify_market_raw", "venues")
os.makedirs(OUT, exist_ok=True)
UA = "verify-market/1.0"

def log(m):
    print(f"[{time.strftime('%H:%M:%S')}] {m}", flush=True)

def get(url, name, timeout=25):
    path = os.path.join(OUT, name)
    r = subprocess.run(["curl", "-4", "-sL", "-m", str(timeout), "-H", f"User-Agent: {UA}",
                        "-w", "%{http_code}", "-o", path, url], capture_output=True, text=True)
    code = r.stdout.strip()
    if code.startswith("2"):
        try:
            with open(path) as f:
                return json.load(f)
        except Exception:
            return None
    return None

results = {"exchanges": {}, "chains": {}, "holders": {}}

# ---------------- CEX spot market checks ----------------
CEX = [
    ("binance", "https://www.binance.com/bapi/asset/v2/public/asset-service/product/get-products?includeEtf=true", "DSM"),
    ("mexc", "https://api.mexc.com/api/v3/exchangeInfo", "DSM"),
    ("gateio", "https://api.gateio.ws/api/v4/spot/currency_pairs", "DSM"),
    ("kucoin", "https://api.kucoin.com/api/v2/symbols", "DSM"),
    ("bitget", "https://api.bitget.com/api/v2/spot/public/symbols", "DSM"),
    ("coinbase", "https://api.exchange.coinbase.com/products", "DSM"),
]
def scan_cex_payload(name, d):
    hits = []
    if d is None:
        return hits
    try:
        if name == "binance":
            for it in (d.get("data") or []):
                if it.get("b") == "DSM" or it.get("q") == "DSM":
                    hits.append({"symbol": it.get("s"), "status": it.get("st")})
        elif name == "mexc":
            for s in d.get("symbols", []):
                if s.get("baseAsset") == "DSM" or s.get("quoteAsset") == "DSM":
                    hits.append({"symbol": s.get("symbol"), "status": s.get("status")})
        elif name == "gateio":
            for s in (d if isinstance(d, list) else []):
                if s.get("base") == "DSM" or s.get("quote") == "DSM":
                    hits.append({"symbol": s.get("id"), "trade_status": s.get("trade_status")})
        elif name == "kucoin":
            for s in (d.get("data") or []):
                if s.get("baseCurrency") == "DSM" or s.get("quoteCurrency") == "DSM":
                    hits.append({"symbol": s.get("symbol"), "enableTrading": s.get("enableTrading")})
        elif name == "bitget":
            for s in (d.get("data") or []):
                if s.get("baseCoin") == "DSM" or s.get("quoteCoin") == "DSM":
                    hits.append({"symbol": s.get("symbol"), "status": s.get("status")})
        elif name == "coinbase":
            for p in (d if isinstance(d, list) else []):
                if p.get("base_currency") == "DSM" or p.get("quote_currency") == "DSM":
                    hits.append({"id": p.get("id"), "status": p.get("status"), "trading_disabled": p.get("trading_disabled")})
    except Exception as e:
        return [{"parse_error": str(e)[:120]}]
    return hits

for name, url, sym in CEX:
    d = get(url, f"cex-{name}.json")
    hits = scan_cex_payload(name, d)
    results["exchanges"][name] = {"fetched": d is not None, "hits": hits}
    log(f"CEX {name}: fetched={d is not None} hits={hits}")

# ---------------- other-chain DSM IBC check ----------------
CHAINS = {
    "juno": ["https://rest.cosmos.directory/juno", "https://juno-api.polkachu.com"],
    "crescent": ["https://rest.cosmos.directory/crescent", "https://lcd.crescent.network"],
    "kujira": ["https://rest.cosmos.directory/kujira", "https://lcd.kaiyo.kujira.setten.io"],
    "secret": ["https://rest.cosmos.directory/secret", "https://lcd.secret.chainapsis.com"],
}

def first_ok(eps, path, name):
    for i, ep in enumerate(eps):
        d = get(ep + path, f"{name}-{i}.json")
        if d is not None:
            return ep, d
    return None, None

for chain, eps in CHAINS.items():
    rec = {"endpoints": eps}
    ep, cs = first_ok(eps, "/ibc/core/client/v1/client_states?pagination.limit=1000", f"{chain}-clients")
    if cs is None:
        # try paginated page size 200
        ep, cs = first_ok(eps, "/ibc/core/client/v1/client_states?pagination.limit=200", f"{chain}-clients200")
    if cs is None:
        results["chains"][chain] = {"error": "no client_states"}
        log(f"chain {chain}: no client_states")
        continue
    rec["lcd"] = ep
    target_client = None
    for c in cs.get("client_states", []):
        ch = (c.get("client_state") or {}).get("chain_id")
        if ch == "desmos-mainnet":
            target_client = c.get("client_id")
    rec["desmos_client"] = target_client
    if not target_client:
        # some chains return chain_id inside different key
        for c in cs.get("client_states", []):
            blob = json.dumps(c)
            if "desmos-mainnet" in blob:
                target_client = c.get("client_id")
        rec["desmos_client_blob"] = target_client
    if not target_client:
        results["chains"][chain] = rec
        log(f"chain {chain}: no desmos client found (n={len(cs.get('client_states',[]))})")
        continue
    _, conns = first_ok(eps, "/ibc/core/connection/v1/connections?pagination.limit=1000", f"{chain}-conns")
    conn_id = None
    for cn in (conns or {}).get("connections", []):
        if cn.get("client_id") == target_client:
            conn_id = cn.get("id")
    rec["connection"] = conn_id
    _, chans = first_ok(eps, "/ibc/core/channel/v1/channels?pagination.limit=1000", f"{chain}-chans")
    chan = None
    for ch in (chans or {}).get("channels", []):
        if ch.get("port_id") == "transfer" and conn_id in (ch.get("connection_hops") or []):
            chan = ch.get("channel_id")
    rec["transfer_channel"] = chan
    if chan:
        h = hashlib.sha256(f"transfer/{chan}/udsm".encode()).hexdigest().upper()
        rec["dsm_ibc_denom"] = "ibc/" + h
        q = urllib.parse.quote("ibc/" + h, safe="")
        _, sup = first_ok(eps, f"/cosmos/bank/v1beta1/supply/by_denom?denom={q}", f"{chain}-dsm-supply")
        if sup is None:
            _, sup = first_ok(eps, f"/cosmos/bank/v1beta1/supply/by_denom?denom=ibc%2F{h}", f"{chain}-dsm-supply2")
        rec["dsm_supply"] = (sup or {}).get("amount")
        # also full supply (to catch other channels carrying udsm if any)
        _, supall = first_ok(eps, "/cosmos/bank/v1beta1/supply?pagination.limit=1000", f"{chain}-supply-all")
        dsm_like = []
        for b in (supall or {}).get("supply", []):
            if b.get("denom", "").startswith("ibc/"):
                dsm_like.append(b.get("denom"))
        rec["n_ibc_denoms"] = len(dsm_like)
        rec["dsm_supply_denoms_seen"] = [x for x in dsm_like if x == rec.get("dsm_ibc_denom")]
    results["chains"][chain] = rec
    log(f"chain {chain}: client={target_client} conn={conn_id} chan={chan} supply={rec.get('dsm_supply')}")

# ---------------- holder indexers ----------------
HOLDER_URLS = [
    ("bigdipper-desmos-accounts", "https://api.desmos.bigdipper.live/v1/accounts?pagination.limit=10"),
    ("bigdipper-desmos-validators", "https://api.desmos.bigdipper.live/v1/staking/validators"),
    ("mintscan-desmos", "https://api.mintscan.io/v1/desmos/accounts?pagination.limit=10"),
    ("bigdipper-osmosis", "https://api.osmosis.bigdipper.live/v1/accounts?pagination.limit=10"),
]
for name, url in HOLDER_URLS:
    d = get(url, name + ".json", timeout=20)
    results["holders"][name] = {"fetched": d is not None, "preview": json.dumps(d)[:300] if d is not None else None}
    log(f"holders {name}: fetched={d is not None}")

with open(os.path.join(BASE, "verify_market_raw", "venues.json"), "w") as f:
    json.dump(results, f, indent=2)
log("venues check complete")
