#!/usr/bin/env python3
"""C2-06 evidence pull: saves raw public-endpoint responses into ci-out/raw/.
Read-only. No secrets. Public LCD/RPC + price APIs only."""
import base64, json, os, subprocess, sys
from datetime import datetime, timezone

UA = "Mozilla/5.0 (X11; Linux x86_64) research"
CHIH_LCD = "https://api.chihuahua.wtf"
CHIH_RPC = "https://rpc.chihuahua.wtf"
OSM_LCD = "https://lcd.osmosis.zone"
OUT = sys.argv[1] if len(sys.argv) > 1 else "ci-out/raw"
os.makedirs(OUT, exist_ok=True)


def get(url, timeout=60):
    r = subprocess.run(["curl", "-s", "--max-time", str(timeout), "-A", UA, url],
                       capture_output=True, text=True)
    return r.stdout


def save(name, url, timeout=60):
    body = get(url, timeout)
    try:
        json.loads(body)
        ok = "json"
    except Exception:
        ok = f"non-json({len(body)}b)"
    with open(os.path.join(OUT, name), "w") as f:
        f.write(body)
    print(f"[evidence] {name}: {ok}")
    return body


def main():
    meta = {"pulled_at": datetime.now(timezone.utc).isoformat(), "endpoints": {}}

    blocks = save("chihuahua_latest_block.json",
                  f"{CHIH_LCD}/cosmos/base/tendermint/v1beta1/blocks/latest")
    try:
        h = json.loads(blocks)["block"]["header"]["height"]
        meta["endpoints"]["chihuahua_height"] = h
    except Exception:
        pass

    save("staking_pool.json", f"{CHIH_LCD}/cosmos/staking/v1beta1/pool")
    save("supply_uhuahua.json", f"{CHIH_LCD}/cosmos/bank/v1beta1/supply/by_denom?denom=uhuahua")
    save("community_pool.json", f"{CHIH_LCD}/cosmos/distribution/v1beta1/community_pool")
    save("distribution_balances.json",
         f"{CHIH_LCD}/cosmos/bank/v1beta1/balances/chihuahua1jv65s3grqf6v6jl3dp4t6c9t9rk99cd8y2fjga?pagination.limit=200")
    save("validators_bonded.json",
         f"{CHIH_LCD}/cosmos/staking/v1beta1/validators?status=BOND_STATUS_BONDED&pagination.limit=200")
    save("distribution_params.json", f"{CHIH_LCD}/cosmos/distribution/v1beta1/params")
    save("liquidity_pools.json", f"{CHIH_LCD}/cosmos/liquidity/v1beta1/pools")
    save("proposals_recent.json",
         f"{CHIH_LCD}/cosmos/gov/v1/proposals?pagination.limit=6&pagination.reverse=true")
    save("prop_103_votes.json", f"{CHIH_LCD}/cosmos/gov/v1/proposals/103/votes?pagination.limit=100")
    save("vote_txs.json",
         f"{CHIH_LCD}/cosmos/tx/v1beta1/txs?query=message.action%3D%27%2Fcosmos.gov.v1.MsgVote%27&pagination.limit=60&order_by=ORDER_BY_DESC")
    save("node_info.json", f"{CHIH_LCD}/cosmos/base/tendermint/v1beta1/node_info")

    # gov params via ABCI (the LCD does not implement /cosmos/gov/v1/params)
    payload = json.dumps({"jsonrpc": "2.0", "id": 1, "method": "abci_query",
                          "params": {"path": "/cosmos.gov.v1.Query/Params", "data": "", "prove": False}})
    r = subprocess.run(["curl", "-s", "--max-time", "30", "-X", "POST",
                        "-H", "Content-Type: application/json", "-d", payload, CHIH_RPC],
                       capture_output=True, text=True)
    with open(os.path.join(OUT, "gov_params_abci.json"), "w") as f:
        f.write(r.stdout)
    try:
        d = json.loads(r.stdout)
        val = d["result"]["response"]["value"]
        meta["endpoints"]["gov_params_height"] = d["result"]["response"]["height"]
        with open(os.path.join(OUT, "gov_params.pb"), "wb") as f:
            f.write(base64.b64decode(val))
        print("[evidence] gov_params_abci.json: ok height", meta["endpoints"]["gov_params_height"])
    except Exception as e:
        print("[evidence] gov_params_abci: FAILED", e)

    # osmosis: all pools (contains every HUAHUA venue) + HUAHUA denom trace
    save("osmosis_all_pools.json",
         f"{OSM_LCD}/osmosis/poolmanager/v1beta1/all-pools?pagination.limit=4000", timeout=180)
    save("osmosis_huahua_denom_trace.json",
         f"{OSM_LCD}/ibc/apps/transfer/v1/denom_traces/B9E0A1A524E98BB407D3CED8720EFEFD186002F90C1B1B7964811DD0CCC12228")
    save("osmosis_channel_113_client.json",
         f"{OSM_LCD}/ibc/core/channel/v1/channels/channel-113/ports/transfer/client_state")

    # native liquidity reserves
    try:
        lp = json.loads(open(os.path.join(OUT, "liquidity_pools.json")).read())
        reserves = {}
        for p in lp.get("pools", []):
            acc = p["reserve_account_address"]
            body = get(f"{CHIH_LCD}/cosmos/bank/v1beta1/balances/{acc}")
            try:
                reserves[acc] = json.loads(body)
            except Exception:
                reserves[acc] = body
        with open(os.path.join(OUT, "liquidity_reserves.json"), "w") as f:
            json.dump(reserves, f, indent=1)
        print("[evidence] liquidity_reserves.json: ok", len(reserves))
    except Exception as e:
        print("[evidence] liquidity reserves FAILED", e)

    # prices
    save("prices_defillama.json",
         "https://coins.llama.fi/prices/current/coingecko:osmosis,coingecko:cosmos,coingecko:bitcoin,coingecko:litecoin,coingecko:terrausd,coingecko:terra-luna,coingecko:ondo-us-dollar-yield")
    save("prices_coingecko_huahua.json",
         "https://api.coingecko.com/api/v3/simple/price?ids=chihuahua-token&vs_currencies=usd&include_market_cap=true&include_24hr_vol=true&include_last_updated_at=true")

    with open(os.path.join(OUT, "meta.json"), "w") as f:
        json.dump(meta, f, indent=1)
    print("[evidence] done ->", OUT)


if __name__ == "__main__":
    main()
