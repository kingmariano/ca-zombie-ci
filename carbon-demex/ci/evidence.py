#!/usr/bin/env python3
"""
C2-32 Carbon/Demex — CI evidence pull (read-only, public endpoints only).

Writes raw pulls to <outdir>/ and a merged inputs.json for analysis/model.py.
Every request is a plain public GET; no keys, no writes to any chain.
"""
import json, os, re, sys, time, urllib.request, datetime, html

OUT = sys.argv[1] if len(sys.argv) > 1 else "ci-out/raw"
os.makedirs(OUT, exist_ok=True)
UA = {"User-Agent": "Mozilla/5.0 (zombie-hunt-ci read-only)"}
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

def get(url, timeout=25, tries=4, backoff=2):
    last = None
    for _ in range(tries):
        try:
            req = urllib.request.Request(url, headers=UA)
            with urllib.request.urlopen(req, timeout=timeout) as r:
                return r.status, r.read()
        except Exception as e:
            last = e
            time.sleep(backoff)
    return None, str(last).encode()

PULLS = {}
def pull(name, url, timeout=25, tries=4):
    st, body = get(url, timeout, tries)
    PULLS[name] = {"url": url, "status": st, "bytes": len(body)}
    if st == 200:
        open(os.path.join(OUT, name), "wb").write(body)
    print(f"  [{'OK ' if st == 200 else 'ERR'}] {name} status={st} bytes={len(body)} {url}")
    return st, body

def strip_tags(s):
    s = re.sub(r"<script.*?</script>", " ", s, flags=re.S)
    s = re.sub(r"<style.*?</style>", " ", s, flags=re.S)
    s = re.sub(r"<[^>]+>", " ", s)
    s = html.unescape(re.sub(r"\s+", " ", s))
    return s

def num(s):
    return float(str(s).replace(",", ""))

def main():
    print(f"[evidence] start {datetime.datetime.utcnow().isoformat()}Z")
    base = json.load(open(os.path.join(ROOT, "analysis", "inputs_snapshot.json")))

    # 1) halt evidence — team node + cached LCD
    st, body = pull("tm_status.json", "https://tm-api.carbon.network/status")
    if st == 200:
        si = json.loads(body)["result"]["sync_info"]
        base["halt"]["last_block_height"] = int(si["latest_block_height"])
        base["halt"]["last_block_time"] = si["latest_block_time"]
        base["halt"]["catching_up"] = bool(si["catching_up"])
        print(f"[evidence] halt: height={si['latest_block_height']} time={si['latest_block_time']} catching_up={si['catching_up']}")

    pull("lcd_staking_pool.json", "https://api.carbon.network/cosmos/staking/v1beta1/pool")
    st, body = pull("lcd_staking_pool_cb.json", f"https://api.carbon.network/cosmos/staking/v1beta1/pool?cb={int(time.time())}")
    # cache-bust must fail (502) if the API backend is dead; that is the point
    pull("lcd_node_info.json", "https://api.carbon.network/cosmos/base/tendermint/v1beta1/node_info")
    pull("lcd_staking_params.json", "https://api.carbon.network/cosmos/staking/v1beta1/params")
    pull("lcd_distribution_params.json", "https://api.carbon.network/cosmos/distribution/v1beta1/params")
    pull("lcd_mint_inflation.json", "https://api.carbon.network/cosmos/mint/v1beta1/inflation")
    pull("lcd_blocks_latest.json", "https://api.carbon.network/cosmos/base/tendermint/v1beta1/blocks/latest")

    sp = os.path.join(OUT, "lcd_staking_pool.json")
    if os.path.exists(sp):
        d = json.load(open(sp))
        base["staking"]["bonded_raw"] = d["pool"]["bonded_tokens"]
        base["staking"]["not_bonded_raw"] = d["pool"]["not_bonded_tokens"]
        base["staking"]["bonded_swth"] = int(d["pool"]["bonded_tokens"]) / 1e8
        base["staking"]["not_bonded_swth"] = int(d["pool"]["not_bonded_tokens"]) / 1e8
        print(f"[evidence] bonded={base['staking']['bonded_swth']:.2f} SWTH not_bonded={base['staking']['not_bonded_swth']:.2f} SWTH")

    # 2) staking-explorer pages (params / validators / tokenomics)
    st, body = pull("se_parameters.html", "https://staking-explorer.com/parameters/carbon")
    if st == 200:
        t = strip_tags(body.decode("utf-8", "ignore"))
        m = re.search(r"Min deposit amount, SWTH ([\d,]+)", t)
        if m: base["gov"]["min_deposit_swth"] = num(m.group(1))
        for key, pat in (("voting_period_days", r"Voting period (\d+) days"),
                         ("max_deposit_period_days", r"Max deposit period (\d+) days")):
            m = re.search(pat, t)
            if m: base["gov"][key] = int(m.group(1))
        m = re.search(r"Quorum ([\d.]+)%", t)
        if m: base["gov"]["quorum"] = float(m.group(1)) / 100
        m = re.search(r"Threshold ([\d.]+)%", t)
        if m: base["gov"]["threshold"] = float(m.group(1)) / 100
        m = re.search(r"Veto threshold ([\d.]+)%", t)
        if m: base["gov"]["veto_threshold"] = float(m.group(1)) / 100
        m = re.search(r"Community pool tax ([\d.]+)%", t)
        if m: base["gov"]["community_pool_tax"] = float(m.group(1)) / 100
        print(f"[evidence] gov: {base['gov']}")

    st, body = pull("se_tokenomics.html", "https://staking-explorer.com/tokenomics/carbon")
    if st == 200:
        t = strip_tags(body.decode("utf-8", "ignore"))
        m = re.search(r"COMMUNITY POOL ([\d,]+) SWTH .*?Locked Community Tokens ([\d,]+) SWTH .*?Spent via Proposals ([\d,]+) SWTH", t)
        if m:
            base["community_pool"]["total_allocation_swth"] = num(m.group(1))
            base["community_pool"]["unspent_locked_swth"] = num(m.group(2))
            base["community_pool"]["spent_via_proposals_swth"] = num(m.group(3))
            print(f"[evidence] CP: total={m.group(1)} unspent={m.group(2)} spent={m.group(3)}")
        m = re.search(r"Carbon DISTRIBUTION POOL ([\d,]+) SWTH", t)
        if m:
            base["distribution_pool"]["total_swth"] = num(m.group(1))

    pull("se_staking.html", "https://staking-explorer.com/staking/carbon", timeout=40)
    p = os.path.join(OUT, "se_staking.html")
    if os.path.exists(p):
        t = strip_tags(open(p, encoding="utf-8", errors="ignore").read())
        m = re.search(r"(\d+)\s*Active nodes", t)
        if m: print(f"[evidence] staking-explorer active nodes: {m.group(1)}")
        m = re.search(r"(\d+)\s*Inactive nodes", t)
        if m: print(f"[evidence] staking-explorer inactive nodes: {m.group(1)}")

    # 3) prices (DefiLlama + CoinGecko)
    st, body = pull("llama_price_swth.json", "https://coins.llama.fi/prices/current/carbon:swth")
    if st == 200:
        base["prices"]["swth_usd_defillama"] = json.loads(body)["coins"]["carbon:swth"]["price"]
    st, body = pull("llama_price_osmo.json", "https://coins.llama.fi/prices/current/osmosis:uosmo")
    if st == 200:
        base["prices"]["osmo_usd_defillama"] = json.loads(body)["coins"]["osmosis:uosmo"]["price"]
    st, body = pull("cg_swth.json", "https://api.coingecko.com/api/v3/coins/switcheo?localization=false&tickers=true&market_data=true")
    if st == 200:
        d = json.loads(body)
        base["prices"]["swth_usd_coingecko"] = d["market_data"]["current_price"]["usd"]
        base["prices"]["swth_24h_volume_usd"] = d["market_data"]["total_volume"]["usd"]
        base["prices"]["swth_market_cap_usd"] = d["market_data"]["market_cap"]["usd"]
        base["_coingecko_ticker_count"] = len(d.get("tickers", []))
    print(f"[evidence] price SWTH=${base['prices']['swth_usd_defillama']:.8f} OSMO=${base['prices']['osmo_usd_defillama']:.5f}")

    # 4) DefiLlama TVL
    for name, key in (("llama_demex.json", "demex_usd"), ("llama_nitron.json", "nitron_usd")):
        st, body = pull(name, f"https://api.llama.fi/protocol/{name.split('_')[1].split('.')[0]}")
        if st == 200:
            d = json.loads(body)
            cur = list(d.get("currentChainTvls", {}).values())
            if cur:
                base["tvl"][key] = cur[0]
    st, body = pull("llama_chains.json", "https://api.llama.fi/v2/chains")
    if st == 200:
        for c in json.loads(body):
            if c.get("name") == "Carbon":
                base["tvl"]["defillama_chain_carbon_usd"] = c["tvl"]
    print(f"[evidence] TVL chain=${base['tvl']['defillama_chain_carbon_usd']:.2f} demex=${base['tvl']['demex_usd']:.2f} nitron=${base['tvl']['nitron_usd']:.2f}")

    # 5) Osmosis SWTH pool scan (full gamm pagination)
    DEN = "8FEFAE6AECF6E2A255585617F781F35A8D5709A545A804482A261C0C9548A9D3"
    pools, off, ok = [], 0, True
    while ok and off < 6000:
        st, body = get(f"https://lcd.osmosis.zone/osmosis/gamm/v1beta1/pools?pagination.limit=1000&pagination.offset={off}", timeout=45, tries=5, backoff=5)
        if st != 200:
            print(f"[evidence] osmosis scan: page offset={off} failed ({st}); using snapshot fallback for pools")
            ok = False
            break
        time.sleep(0.5)
        d = json.loads(body)
        page = d.get("pools", [])
        for p in page:
            if DEN in json.dumps(p):
                toks = p.get("poolAssets") or p.get("pool_assets") or []
                amounts = {t.get("token", {}).get("denom"): t.get("token", {}).get("amount") for t in toks}
                swth_key = "ibc/" + DEN
                swth_raw = amounts.get(swth_key)
                if not swth_raw:
                    continue
                counter = {k: v for k, v in amounts.items() if k != swth_key}
                cdenom, camt = next(iter(counter.items()))
                pools.append({"id": int(p.get("id")), "type": "gamm",
                              "swth": int(swth_raw) / 1e8, "counter_denom": cdenom,
                              "counter_amount": int(camt) / (1e6 if cdenom == "uosmo" else 1)})
        if len(page) < 1000:
            break
        off += 1000
    if pools:
        base["osmosis_swth_pools"]["pools"] = pools
        base["osmosis_swth_pools"]["total_swth_on_osmosis"] = sum(p["swth"] for p in pools)
        open(os.path.join(OUT, "osmosis_swth_pools.json"), "w").write(json.dumps(pools, indent=1))
    print(f"[evidence] osmosis SWTH pools: {len(pools)} total={base['osmosis_swth_pools']['total_swth_on_osmosis']:.2f} SWTH")

    # 6) endpoint census (decommissioned third parties)
    census = {}
    for host in ["https://carbon-api.polkachu.com", "https://carbon-mainnet-lcd.autostake.com",
                 "https://carbon-rest.publicnode.com", "https://rest.carbon.blockhunters.org",
                 "https://rest.lavenderfive.com/carbon"]:
        st, _ = get(host + "/cosmos/staking/v1beta1/pool", timeout=10, tries=2)
        census[host] = st
    base["_endpoint_census"] = census
    print(f"[evidence] endpoint census: {census}")

    base["_pull_status"] = PULLS
    base["_evidence_generated_at"] = datetime.datetime.utcnow().isoformat() + "Z"
    with open(os.path.join(OUT, "inputs.json"), "w") as f:
        json.dump(base, f, indent=1)
    print(f"[evidence] wrote {os.path.join(OUT, 'inputs.json')}")

if __name__ == "__main__":
    main()
