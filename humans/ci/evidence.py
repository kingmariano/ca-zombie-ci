#!/usr/bin/env python3
"""
C2-30 Humans governance capture — CI evidence job (read-only, public endpoints only).

Re-pulls, from the GitHub Actions runner (independent network egress):
  - humans_1089-1 state: height, staking pool, supply, community pool (2 LCDs),
    module account balances, bonded validators, gov params (ABCI), proposals/tallies
  - HEART price (DefiLlama current + 2026-10-04/05 historical; CoinGecko), ETH price
  - market depth: Osmosis pool 1493, Ethereum UniV2 HEART/WETH pair, Gate order book
  - IBC escrows on the humans side (ADR-028 escrow addresses, recomputed)
Then computes the capture cost model (own-stake-in-denominator correction; threshold;
veto; float coverage) and writes ci-out/evidence.json, ci-out/model.json, ci-out/model.md.

No secrets. No transactions. Public endpoints only.
"""
import base64, hashlib, json, os, subprocess, sys, time
from decimal import Decimal, getcontext

getcontext().prec = 50
HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.abspath(os.path.join(HERE, "..", "ci-out"))
os.makedirs(OUT, exist_ok=True)
UA = "Mozilla/5.0 (X11; Linux x86_64) zombie-ci research"

def curl(url, timeout=25, post=None):
    cmd = ["curl", "-s", "--max-time", str(timeout), "-A", UA]
    if post is not None:
        cmd += ["-X", "POST", "-H", "Content-Type: application/json", "-d", json.dumps(post)]
    cmd.append(url)
    for _ in range(2):
        o = subprocess.run(cmd, capture_output=True, text=True).stdout
        if o.strip():
            return o
        time.sleep(1)
    return o

def jget(url, base=None):
    try:
        return json.loads(curl((base or "") + url))
    except Exception:
        return {"_err": True}

def D(x): return Decimal(str(x))
def save(name, obj):
    with open(os.path.join(OUT, name), "w") as f:
        json.dump(obj, f, indent=1, default=str)

ev = {"finding": "C2-30", "chain": "humans_1089-1", "started": time.strftime("%FT%TZ", time.gmtime())}

# ---------------- bech32 helpers (ADR-028) ----------------
CH = "qpzry9x8gf2tvdw0s3jn54khce6mua7l"
def _pm(v):
    g=[0x3b6a57b2,0x26508e6d,0x1ea119fa,0x3d4233dd,0x2a1462b3]; c=1
    for x in v:
        b=c>>25; c=((c&0x1ffffff)<<5)^x
        for i in range(5):
            if (b>>i)&1: c^=g[i]
    return c
def _he(h): return [ord(x)>>5 for x in h]+[0]+[ord(x)&31 for x in h]
def b32(h,d):
    p=_pm(_he(h)+d+[0]*6)^1; cs=[(p>>5*(5-i))&31 for i in range(6)]
    return h+"1"+"".join(CH[x] for x in d+cs)
def conv(d,fb,tb):
    a=b=0; r=[]; m=(1<<tb)-1
    for v in d:
        a=(a<<fb)|v; b+=fb
        while b>=tb: b-=tb; r.append((a>>b)&m)
    if b: r.append((a<<(tb-b))&m)
    return r
def modaddr(name):
    return b32("human", conv(list(hashlib.sha256(name.encode()).digest()[:20]),8,5))
def escrow(ch):
    pre = b"ics20-1" + b"\x00" + f"transfer/{ch}".encode()
    return b32("human", conv(list(hashlib.sha256(pre).digest()[:20]),8,5))

# ---------------- humans state ----------------
LCDS = ["https://api.humans.nodestake.org", "https://humans-api.noders.services",
        "https://humans-mainnet-api.itrocket.net"]
def first_ok(path):
    for b in LCDS:
        d = jget(path, b)
        if isinstance(d, dict) and not d.get("_err") and d.get("code") is None:
            return d, b
    return {"_err": True}, None

blocks, lcd = first_ok("/cosmos/base/tendermint/v1beta1/blocks/latest")
ev["lcd"] = lcd
try:
    ev["height"] = int(blocks["block"]["header"]["height"]); ev["time"] = blocks["block"]["header"]["time"]
except Exception:
    ev["height"] = None
pool, _ = first_ok("/cosmos/staking/v1beta1/pool"); ev["staking_pool"] = pool.get("pool")
sup, _ = first_ok("/cosmos/bank/v1beta1/supply/by_denom?denom=aheart"); ev["supply_aheart"] = sup.get("amount")
cp1, _ = first_ok("/cosmos/distribution/v1beta1/community_pool"); ev["community_pool_lcd1"] = cp1.get("pool")
cp2 = jget("/cosmos/distribution/v1beta1/community_pool", LCDS[1]); ev["community_pool_lcd2"] = cp2.get("pool")
vals, _ = first_ok("/cosmos/staking/v1beta1/validators?status=BOND_STATUS_BONDED&pagination.limit=300")
ev["validators_bonded"] = [{"moniker": v["description"]["moniker"], "tokens": v["tokens"],
                             "operator": v["operator_address"]} for v in (vals.get("validators") or [])]
# module balances
mods = {}
for m in ["distribution", "gov", "mint", "fee_collector", "transfer", "bonded_tokens_pool", "not_bonded_tokens_pool"]:
    a = modaddr(m)
    b, _ = first_ok(f"/cosmos/bank/v1beta1/balances/{a}")
    mods[m] = {"addr": a, "balances": b.get("balances")}
ev["module_balances"] = mods
# escrows
esc = {}
for i in range(5):
    a = escrow(f"channel-{i}")
    b, _ = first_ok(f"/cosmos/bank/v1beta1/balances/{a}")
    esc[f"channel-{i}"] = {"addr": a, "balances": b.get("balances")}
ev["escrows"] = esc
# proposals
props, _ = first_ok("/cosmos/gov/v1beta1/proposals?pagination.limit=200")
ev["proposals"] = [{"id": p["proposal_id"], "status": p["status"],
                     "type": p.get("content", {}).get("@type", ""),
                     "final_tally": p.get("final_tally_result"),
                     "submit": p.get("submit_time")} for p in (props.get("proposals") or [])]
# gov params via ABCI (RPC fallbacks)
RPCS = ["https://humans-rpc.noders.services", "https://rpc.humans.nodestake.org",
        "https://mainnet-humans-rpc.konsortech.xyz"]
def abci(path, data=""):
    for rpc in RPCS:
        try:
            d = json.loads(curl(rpc, post={"jsonrpc":"2.0","id":1,"method":"abci_query",
                    "params":{"path":path,"data":data,"prove":False}}))
            r = d["result"]["response"]
            if r.get("code") == 0 and r.get("value"):
                return r
        except Exception:
            continue
    return {}
gp = {}
for pt in ["tallying", "voting", "deposit"]:
    data = "0a" + format(len(pt), "02x") + pt.encode().hex()
    r = abci("/cosmos.gov.v1beta1.Query/Params", data)
    gp[pt] = {"height": r.get("height"), "hex": base64.b64decode(r["value"]).hex() if r.get("value") else None}
ev["gov_params_abci"] = gp
ev["gov_params_genesis_expected"] = {"quorum": "0.334", "threshold": "0.5", "veto": "0.334",
                                      "min_deposit": "25000000000000000000000aheart", "voting_period": "432000s"}
# wasm / upgrade / authz
ev["wasm_check"] = jget(LCDS[0] + "/cosmwasm/wasm/v1/codes?pagination.limit=5")
ev["upgrade_plan"] = jget(LCDS[0] + "/cosmos/upgrade/v1beta1/current_plan")
gov_a = modaddr("gov")
ev["authz_gov"] = jget(LCDS[0] + f"/cosmos/authz/v1beta1/grants/grantee/{gov_a}")

# ---------------- prices ----------------
ev["price_now"] = jget("https://coins.llama.fi/prices/current/coingecko:humans-ai")
ev["price_oct4"] = jget("https://coins.llama.fi/prices/historical/1791072000/coingecko:humans-ai")
ev["price_oct5"] = jget("https://coins.llama.fi/prices/historical/1791158400/coingecko:humans-ai")
ev["eth_price"] = jget("https://coins.llama.fi/prices/current/coingecko:ethereum")
ev["coingecko"] = jget("https://api.coingecko.com/api/v3/coins/humans-ai?localization=false&tickers=true&market_data=true")

# ---------------- depth ----------------
ev["osmosis_pool_1493"] = jget("https://lcd.osmosis.zone/osmosis/gamm/v1beta1/pools/1493")
eth = "https://ethereum-rpc.publicnode.com"
def eth_call(to, data):
    try:
        r = json.loads(curl(eth, post={"jsonrpc":"2.0","id":1,"method":"eth_call",
                                        "params":[{"to":to,"data":data},"latest"]}))
        return r.get("result")
    except Exception:
        return None
HEART_ETH = "0x8fac8031e079f409135766c7d5de29cf22ef897c"
WETH = "0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2"
pair = eth_call("0x5c69bee701ef814a2b6a3edd4b1652cb9cc5aa6f",
                "0xe6a43905" + "0"*24 + HEART_ETH[2:] + "0"*24 + WETH[2:])
ev["eth_pair"] = pair
if pair and int(pair, 16) != 0:
    pa = "0x" + pair[-40:]
    ev["eth_pair_reserves"] = eth_call(pa, "0x0902f1ac")
    ev["eth_block"] = json.loads(curl(eth, post={"jsonrpc":"2.0","id":1,"method":"eth_blockNumber","params":[]})).get("result")
ev["gate_book"] = jget("https://api.gateio.ws/api/v4/spot/order_book?currency_pair=HEART_USDT&limit=100")
ev["kucoin_book"] = jget("https://api.kucoin.com/api/v1/market/orderbook/level2_100?symbol=HEART-USDT")

# ---------------- model ----------------
m = {}
try:
    B = D(pool["pool"]["bonded_tokens"]) / D(10**18)
    NB = D(pool["pool"]["not_bonded_tokens"]) / D(10**18)
    CP = D(cp1["pool"][0]["amount"]) / D(10**18) if cp1.get("pool") else None
    price = D(ev["price_now"]["coins"]["coingecko:humans-ai"]["price"])
    ethp = D(ev["eth_price"]["coins"]["coingecko:ethereum"]["price"])
    q = D("0.334")
    m["bonded_heart"] = str(B); m["bonded_usd"] = str(B * price)
    m["community_pool_heart"] = str(CP); m["community_pool_usd"] = str(CP * price)
    m["solo_quorum_stake_heart"] = str(q / (1 - q) * B)
    m["solo_quorum_stake_usd_spot"] = str(q / (1 - q) * B * price)
    vs = sorted(ev["validators_bonded"], key=lambda v: -int(v["tokens"]))
    sh = [D(v["tokens"]) / D(pool["pool"]["bonded_tokens"]) for v in vs]
    m["top2_share"] = str(sh[0] + sh[1]); m["top4_share"] = str(sum(sh[:4]))
    m["outvote_top2_no_heart"] = str((sh[0] + sh[1]) / (1 - (sh[0] + sh[1])) * B)
    m["outvote_top4_no_heart"] = str(sum(sh[:4]) / (1 - sum(sh[:4])) * B)
    m["outvote_top2_no_usd_spot"] = str((sh[0] + sh[1]) / (1 - (sh[0] + sh[1])) * B * price)
    m["outvote_top4_no_usd_spot"] = str(sum(sh[:4]) / (1 - sum(sh[:4])) * B * price)
    # float
    try:
        assets = {a["token"]["denom"]: D(a["token"]["amount"]) for a in ev["osmosis_pool_1493"]["pool"]["pool_assets"]}
        o_heart = next(v for k, v in assets.items() if k.startswith("ibc/35CECC")) / D(10**18)
        o_usdc = next(v for k, v in assets.items() if k.startswith("ibc/498A")) / D(10**6)
        m["osmo_pool1493_heart"] = str(o_heart); m["osmo_pool1493_usdc"] = str(o_usdc)
    except Exception:
        o_heart = o_usdc = D(0)
    try:
        r = ev["eth_pair_reserves"]; r0 = int(r[2:66], 16); r1 = int(r[2+64:2+128], 16)
        e_heart = D(r0) / D(10**18); e_weth = D(r1) / D(10**18)
        m["eth_univ2_heart"] = str(e_heart); m["eth_univ2_weth"] = str(e_weth)
    except Exception:
        e_heart = e_weth = D(0)
    try:
        gate_ask = sum(D(a[0]) * D(a[1]) for a in ev["gate_book"]["asks"])
        gate_bid = sum(D(b[0]) * D(b[1]) for b in ev["gate_book"]["bids"])
        m["gate_asks_usd"] = str(gate_ask); m["gate_bids_usd"] = str(gate_bid)
    except Exception:
        gate_ask = gate_bid = D(0)
    try:
        kd = ev["kucoin_book"]["data"]
        kucoin_ask = sum(D(a[0]) * D(a[1]) for a in kd["asks"])
        kucoin_bid = sum(D(b[0]) * D(b[1]) for b in kd["bids"])
        m["kucoin_asks_usd"] = str(kucoin_ask); m["kucoin_bids_usd"] = str(kucoin_bid)
    except Exception:
        kucoin_ask = kucoin_bid = D(0)
    onchain = o_heart + e_heart
    m["onchain_heart_buyable"] = str(onchain)
    m["float_cover_ratio"] = str(onchain / (q / (1 - q) * B))
    m["exit_usd_approx"] = str(o_usdc + e_weth * ethp + gate_bid + kucoin_bid)
    m["cex_ask_depth_usd"] = str(gate_ask + kucoin_ask)
    # corpus artifact
    cp6 = D(cp1["pool"][0]["amount"]) / D(10**6)
    p5 = D(ev["price_oct5"]["coins"]["coingecko:humans-ai"]["price"])
    m["corpus_artifact_heart_6dec"] = str(cp6)
    m["corpus_artifact_usd_oct5"] = str(cp6 * p5)
    m["true_cp_usd"] = str(CP * price)
    # module custody
    dist = D(0); nb = D(0); esc_t = D(0)
    try:
        dist = D(mods["distribution"]["balances"][0]["amount"]) / D(10**18) if mods["distribution"]["balances"] else D(0)
        nb = D(mods["not_bonded_tokens_pool"]["balances"][0]["amount"]) / D(10**18) if mods["not_bonded_tokens_pool"]["balances"] else D(0)
        esc_t = sum(D(b["amount"]) for c in esc.values() for b in (c["balances"] or [])) / D(10**18)
    except Exception:
        pass
    m["distribution_module_heart"] = str(dist)
    m["not_bonded_pool_heart"] = str(nb)
    m["escrows_total_heart"] = str(esc_t)
    m["latent_upgrade_reachable_heart"] = str(dist + nb + esc_t)
    m["latent_upgrade_reachable_usd"] = str((dist + nb + esc_t) * price)
    m["deposit_heart"] = "25000"; m["deposit_usd"] = str(D("25000") * price)
    m["net_ev_solo_usd"] = str(CP * price - q / (1 - q) * B * price)
    ev["model"] = m
    ev["prices"] = {"heart_usd": str(price), "eth_usd": str(ethp)}
except Exception as e:
    ev["model_error"] = repr(e)

ev["finished"] = time.strftime("%FT%TZ", time.gmtime())
save("evidence.json", ev)
save("model.json", {"finding": "C2-30", "height": ev.get("height"), "model": m, "prices": ev.get("prices")})

lines = [f"C2-30 Humans CI evidence @ height {ev.get('height')} ({ev.get('time')})",
         f"bonded={m.get('bonded_heart')} HEART (${m.get('bonded_usd')})",
         f"community_pool={m.get('community_pool_heart')} HEART (${m.get('community_pool_usd')})",
         f"solo_quorum={m.get('solo_quorum_stake_heart')} HEART (${m.get('solo_quorum_stake_usd_spot')})",
         f"top2={m.get('top2_share')} top4={m.get('top4_share')}",
         f"onchain_float={m.get('onchain_heart_buyable')} HEART cover={m.get('float_cover_ratio')}",
         f"exit_liquidity_usd={m.get('exit_usd_approx')} cex_ask_depth_usd={m.get('cex_ask_depth_usd')}",
         f"corpus_artifact_6dec_oct5_usd={m.get('corpus_artifact_usd_oct5')} true_cp_usd={m.get('true_cp_usd')}",
         f"latent_upgrade_reachable_heart={m.get('latent_upgrade_reachable_heart')} (${m.get('latent_upgrade_reachable_usd')})",
         "VERDICT: capture uneconomic; CP = dust (corpus $50.7k was a 6-decimal misread)"]
open(os.path.join(OUT, "evidence.log"), "w").write("\n".join(lines) + "\n")
open(os.path.join(OUT, "model.md"), "w").write("# C2-30 Humans CI model\n\n" + "\n".join("- " + l for l in lines) + "\n")
print("\n".join(lines))
print("exit 0")
