#!/usr/bin/env python3
"""C2-10 child-verifier: read-only evidence pull for market-depth verification.

All access is unauthenticated public HTTP GET (curl -4). Nothing is signed or sent.
Raw responses land in analysis/verify_market_raw/.
"""
import json, os, subprocess, sys, hashlib, urllib.parse, time

RAW = os.path.join(os.path.dirname(os.path.abspath(__file__)), "verify_market_raw")
os.makedirs(RAW, exist_ok=True)
UA = "verify-market/1.0"
LOG = []

def log(msg):
    line = f"[{time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime())}] {msg}"
    print(line, flush=True)
    LOG.append(line)

def get(url, name, tries=3, timeout=30):
    """curl -4 GET -> RAW/name, returns parsed json or None."""
    path = os.path.join(RAW, name)
    for i in range(tries):
        r = subprocess.run(
            ["curl", "-4", "-s", "-m", str(timeout), "-H", f"User-Agent: {UA}",
             "-w", "%{http_code}", "-o", path, url],
            capture_output=True, text=True)
        code = r.stdout.strip()
        if code == "200" and os.path.exists(path):
            try:
                with open(path) as f:
                    d = json.load(f)
                return d
            except Exception as e:
                log(f"JSON parse fail {name}: {e}")
        time.sleep(1.5)
    log(f"FAIL {name}: {url} (HTTP {code if 'code' in dir() else '?'})")
    return None

def to_int(x, d=0):
    try:
        return int(x)
    except Exception:
        return d

def bech32_polymod(values):
    GEN = [0x3b6a57b2, 0x26508e6d, 0x1ea119fa, 0x3d4233dd, 0x2a1462b3]
    chk = 1
    for v in values:
        b = chk >> 25
        chk = (chk & 0x1ffffff) << 5 ^ v
        for i in range(5):
            chk ^= GEN[i] if ((b >> i) & 1) else 0
    return chk

def bech32_hrp_expand(hrp):
    return [ord(x) >> 5 for x in hrp] + [0] + [ord(x) & 31 for x in hrp]

def bech32_create_checksum(hrp, data):
    values = bech32_hrp_expand(hrp) + data
    polymod = bech32_polymod(values + [0, 0, 0, 0, 0, 0]) ^ 1
    return [(polymod >> 5 * (5 - i)) & 31 for i in range(6)]

def bech32_encode(hrp, data):
    CHARSET = "qpzry9x8gf2tvdw0s3jn54khce6mua7l"
    combined = data + bech32_create_checksum(hrp, data)
    return hrp + "1" + "".join([CHARSET[d] for d in combined])

def convertbits(data, frombits, tobits, pad=True):
    acc = 0; bits = 0; ret = []
    maxv = (1 << tobits) - 1
    for value in data:
        acc = (acc << frombits) | value
        bits += frombits
        while bits >= tobits:
            bits -= tobits
            ret.append((acc >> bits) & maxv)
    if pad and bits:
        ret.append((acc << (tobits - bits)) & maxv)
    return ret

def escrow_addr(hrp, port, channel):
    # ibc-go transfer GetEscrowAddress: version "ics20-1", 0 byte, "port/channel"
    pre = b"ics20-1\x00" + f"{port}/{channel}".encode()
    h = hashlib.sha256(pre).digest()[:20]
    return bech32_encode(hrp, convertbits(list(h), 8, 5))

DESMOS = ["https://api.mainnet.desmos.network", "https://desmos-rest.staketab.org"]
OSMO = "https://lcd.osmosis.zone"
DSM_HASH = hashlib.sha256(b"transfer/channel-135/udsm").hexdigest().upper()
log(f"DSM ibc hash computed = ibc/{DSM_HASH}")

# ---------------- 0. independent escrow derivation ----------------
DERIV = {}
for name, ep in [("api.mainnet.desmos.network", DESMOS[0]), ("desmos-rest.staketab.org", DESMOS[1])]:
    DERIV[name] = escrow_addr("desmos", "transfer", "channel-2")
DERIV["given"] = "desmos12k2pyuylm9t7ugdvz67h9pg4gmmvhn5vt7gzxv"
with open(os.path.join(RAW, "escrow-derivation.json"), "w") as f:
    json.dump(DERIV, f, indent=2)
log(f"escrow derived transfer/channel-2 = {DERIV['api.mainnet.desmos.network']} given={DERIV['given']}")

# ---------------- 1. Osmosis raw data ----------------
# latest height (two reads around the pulls)
b = get(f"{OSMO}/cosmos/base/tendermint/v1beta1/blocks/latest", "osmo-block-start.json")
osmo_h_start = to_int(((b or {}).get("block") or {}).get("header", {}).get("height"))
log(f"osmosis height at start: {osmo_h_start}")

# denom trace
get(f"{OSMO}/ibc/apps/transfer/v1/denom_traces/{DSM_HASH}", "osmo-denom-trace.json")
# channel-135
get(f"{OSMO}/ibc/core/channel/v1/channels/channel-135/ports/transfer", "osmo-channel-135.json")
# supply by denom
q = urllib.parse.quote(f"ibc/{DSM_HASH}", safe="")
get(f"{OSMO}/cosmos/bank/v1beta1/supply/by_denom?denom={q}", "osmo-dsm-supply.json")

# gamm pools, all pages
def paginate(base, name, key_param="pagination.key", max_pages=15):
    items = []; key = None; pages = []
    for i in range(max_pages):
        url = f"{base}?pagination.limit=1000"
        if key:
            url += f"&{key_param}={urllib.parse.quote(key)}"
        d = get(url, f"{name}-p{i}.json")
        if not d:
            break
        items.extend(d.get("pools") or d.get("pool") or [])
        key = ((d.get("pagination") or {}).get("next_key") or None)
        pages.append({"page": i, "n": len(d.get("pools") or [])})
        log(f"{name} page {i}: {len(d.get('pools') or [])} pools, next_key={'yes' if key else 'no'}")
        if not key:
            break
        time.sleep(0.3)
    return items, pages

gamm, gamm_pages = paginate(f"{OSMO}/osmosis/gamm/v1beta1/pools", "osmo-gamm")
cl, cl_pages = paginate(f"{OSMO}/osmosis/concentratedliquidity/v1beta1/pools", "osmo-cl")
log(f"gamm total {len(gamm)}, cl total {len(cl)}")

with open(os.path.join(RAW, "osmo-gamm-all.json"), "w") as f:
    json.dump({"pools": gamm, "pages": gamm_pages}, f)
with open(os.path.join(RAW, "osmo-cl-all.json"), "w") as f:
    json.dump({"pools": cl, "pages": cl_pages}, f)

# ---------------- 2. Desmos chain state, two endpoints, pinned heights ----------------
def desmos_height(ep):
    b = get(f"{ep}/cosmos/base/tendermint/v1beta1/blocks/latest", f"desmos-block-{ep.split('//')[1].split('/')[0]}.json")
    h = (b or {}).get("block", {}).get("header", {})
    return {"height": to_int(h.get("height")), "time": h.get("time")}

heights = {}
for ep in DESMOS:
    heights[ep] = desmos_height(ep)
    log(f"desmos {ep} latest height {heights[ep]['height']} @ {heights[ep]['time']}")

H = heights[DESMOS[0]]["height"]

def get_h(ep, path, name, height=H):
    """Try height-pinned; fall back to unpinned. Returns (json, pin_used, height_echo)."""
    d = get(f"{ep}{path}{'&' if '?' in path else '?'}height={height}", name + "-h.json", tries=2)
    if d is not None and not (isinstance(d, dict) and "code" in d and d.get("code")):
        return d, True
    d = get(f"{ep}{path}", name + "-latest.json", tries=3)
    return d, False

chain = {}
for ep in DESMOS:
    tag = "api" if "api.mainnet" in ep else "staketab"
    rec = {"endpoint": ep, "height_at_start": heights[ep]["height"], "time": heights[ep]["time"], "calls": {}}
    for name, path in [
        ("community-pool", "/cosmos/distribution/v1beta1/community_pool"),
        ("staking-pool", "/cosmos/staking/v1beta1/pool"),
        ("supply", "/cosmos/bank/v1beta1/supply"),
        ("escrow-balances", "/cosmos/bank/v1beta1/balances/desmos12k2pyuylm9t7ugdvz67h9pg4gmmvhn5vt7gzxv"),
        ("channel-2", "/ibc/core/channel/v1/channels/channel-2/ports/transfer"),
        ("validators-bonded", "/cosmos/staking/v1beta1/validators?status=BOND_STATUS_BONDED&pagination.limit=200"),
        ("gov-params-quorum", "/cosmos/params/v1beta1/params?subspace=gov&key=tallyparams"),
        ("node-info", "/cosmos/base/tendermint/v1beta1/node_info"),
        ("balances-supply-pool-addr", "/cosmos/bank/v1beta1/balances/desmos1jv65s3grqf6v6jl3dp4t6c9t9rk99cd8a7vdmv"),
    ]:
        d, pinned = get_h(ep, path, f"desmos-{tag}-{name}")
        rec["calls"][name] = {"pinned_height": pinned, "ok": d is not None,
                              "json_file": f"desmos-{tag}-{name}-h.json" if pinned else f"desmos-{tag}-{name}-latest.json"}
    h2 = desmos_height(ep)
    rec["height_at_end"] = h2["height"]
    chain[tag] = rec
    log(f"desmos {tag}: calls done, height {rec['height_at_start']} -> {rec['height_at_end']}")

with open(os.path.join(RAW, "desmos-chain-calls.json"), "w") as f:
    json.dump(chain, f, indent=2)

# second Osmosis height after balances read
b2 = get(f"{OSMO}/cosmos/base/tendermint/v1beta1/blocks/latest", "osmo-block-end.json")
osmo_h_end = to_int(((b2 or {}).get("block") or {}).get("header", {}).get("height"))
log(f"osmosis height at end: {osmo_h_end}")

# ---------------- 3. prices (multiple sources) ----------------
get("https://api.coingecko.com/api/v3/simple/price?ids=desmos,cosmos,osmosis&vs_currencies=usd&include_market_cap=true&include_24hr_vol=true&include_last_updated_at=true", "prices-coingecko.json")
get("https://coins.llama.fi/prices/current/coingecko:desmos,coingecko:cosmos,coingecko:osmosis", "prices-llama.json")
get("https://api.coingecko.com/api/v3/coins/desmos/tickers?include_exchange_logo=false&page=1&order=volume_desc", "cg-dsm-tickers.json")

# ---------------- 4. manifest ----------------
with open(os.path.join(RAW, "manifest.log"), "w") as f:
    f.write("\n".join(LOG) + "\n")
log("fetch complete")
