#!/usr/bin/env python3
"""C2-08 Sommelier live-state collector (read-only, public endpoints only).

Writes ci-out/live_state.json. No secrets, no transactions.
"""
import json, os, sys, urllib.request, urllib.parse, base64, hashlib, datetime, re

OUT = os.path.join(os.path.dirname(__file__), "..", "ci-out")
os.makedirs(OUT, exist_ok=True)


def scrub(x):
    """Never persist RPC URLs (they may embed API keys in CI)."""
    return re.sub(r"https?://\S+", "[rpc]", str(x))

UA = {"User-Agent": "Mozilla/5.0 (zombie-hunt-ci)"}

LCDS = [
    "https://sommelier-api.polkachu.com",
    "https://rest.cosmos.directory/sommelier",
]
RPCS = [
    "https://sommelier-rpc.polkachu.com",
    "https://rpc.cosmos.directory/sommelier",
]
ETH_RPC = os.environ.get("FORK_RPC_URL") or "https://ethereum-rpc.publicnode.com"
ARB_RPC = os.environ.get("ARB_RPC_URL") or "https://arb1.arbitrum.io/rpc"
OP_RPC = os.environ.get("OP_RPC_URL") or "https://mainnet.optimism.io"
SCROLL_RPC = "https://rpc.scroll.io"

SOMM_IBC = "ibc/9BBA9A1C257E971E38C1422780CE6F0B0686F0A3085E2D61118D904BFE0F5F5E"
USOMM = "usomm"


def get(url, timeout=30):
    req = urllib.request.Request(url, headers=UA)
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return json.load(r)


def get_first(bases, path):
    return get_first_with_base(bases, path)[0]


def get_first_with_base(bases, path):
    err = None
    for b in bases:
        try:
            return get(b + path), b
        except Exception as e:  # noqa
            err = e
    raise RuntimeError(f"all bases failed for {path}: {err}")


def rpc_call(urls, method, params):
    err = None
    for u in urls:
        try:
            req = urllib.request.Request(
                u,
                data=json.dumps({"jsonrpc": "2.0", "id": 1, "method": method, "params": params}).encode(),
                headers={**UA, "Content-Type": "application/json"},
            )
            with urllib.request.urlopen(req, timeout=30) as r:
                d = json.load(r)
            if "result" in d:
                return d["result"]
            err = d.get("error")
        except Exception as e:  # noqa
            err = e
    raise RuntimeError(f"rpc {method} failed: {err}")


def eth_call(url, to, data):
    req = urllib.request.Request(
        url,
        data=json.dumps({"jsonrpc": "2.0", "id": 1, "method": "eth_call",
                         "params": [{"to": to, "data": data}, "latest"]}).encode(),
        headers={**UA, "Content-Type": "application/json"},
    )
    with urllib.request.urlopen(req, timeout=30) as r:
        d = json.load(r)
    return d.get("result")


def eth_block(url):
    return int(rpc_call([url], "eth_blockNumber", []), 16)


def decode_gov_params(b: bytes):
    """Minimal gov v1 Params decoder for the fields we care about (SDK 0.47)."""
    out, i = {}, 0

    def _dur(v: bytes) -> int:
        """Duration { seconds=1 varint, nanos=2 varint } -> seconds."""
        j, secs = 0, 0
        while j < len(v):
            t = v[j]; j += 1
            f, w = t >> 3, t & 7
            if w == 0:
                shift = 0
                val = 0
                while True:
                    c = v[j]; j += 1
                    val |= (c & 0x7F) << shift
                    if not c & 0x80:
                        break
                    shift += 7
                if f == 1:
                    secs = val
            elif w == 2:
                n = v[j]; j += 1
                j += n
        return secs

    def varint():
        nonlocal i
        shift = 0
        v = 0
        while True:
            c = b[i]; i += 1
            v |= (c & 0x7F) << shift
            if not c & 0x80:
                return v
            shift += 7

    def ld():
        nonlocal i
        n = varint()
        v = b[i:i + n]; i += n
        return v

    while i < len(b):
        tag = varint()
        f, wt = tag >> 3, tag & 7
        if wt == 2:
            v = ld()
            if f == 1:  # min_deposit Coin { denom=1 string, amount=2 string }
                j, amt, denom = 0, None, None
                while j < len(v):
                    t2 = v[j]; j += 1
                    f2, w2 = t2 >> 3, t2 & 7
                    if w2 == 2:
                        n2 = v[j]; j += 1
                        val = v[j:j + n2]; j += n2
                        if f2 == 1:
                            denom = val.decode()
                        elif f2 == 2:
                            amt = val.decode()
                out["min_deposit"] = {"denom": denom, "amount": amt}
            elif f == 2:
                out["max_deposit_period_s"] = _dur(v)
            elif f == 3:
                out["voting_period_s"] = _dur(v)
            elif f in (4, 5, 6, 7):
                key = {4: "quorum", 5: "threshold", 6: "veto_threshold", 7: "min_initial_deposit_ratio"}[f]
                out[key] = v.decode()
        else:
            varint()
    return out


def main():
    res = {"collected_at_utc": datetime.datetime.utcnow().isoformat() + "Z", "chain": "sommelier-3"}

    # --- Sommelier LCD core state ---
    latest, lcd_used = get_first_with_base(LCDS, "/cosmos/base/tendermint/v1beta1/blocks/latest")
    hdr = latest["block"]["header"]
    res["sommelier"] = {
        "lcd_used": lcd_used,
        "height": int(hdr["height"]),
        "time": hdr["time"],
        "chain_id": hdr.get("chain_id"),
    }
    s = res["sommelier"]
    s["staking_pool"] = get_first(LCDS, "/cosmos/staking/v1beta1/pool")["pool"]
    s["supply_usomm"] = get_first(LCDS, "/cosmos/bank/v1beta1/supply/by_denom?denom=usomm")["amount"]
    s["community_pool"] = get_first(LCDS, "/cosmos/distribution/v1beta1/community_pool")["pool"]
    s["staking_params"] = get_first(LCDS, "/cosmos/staking/v1beta1/params")["params"]
    s["validators_all"] = get_first(
        LCDS, "/cosmos/staking/v1beta1/validators?pagination.limit=200")["validators"]
    s["poa_safe_mode"] = get_first(LCDS, "/sommelier/poa/v1/safe_mode")
    s["poa_params"] = get_first(LCDS, "/sommelier/poa/v1/params")["params"]
    s["poa_authority_set"] = get_first(LCDS, "/sommelier/poa/v1/authority_set")["validators"]
    s["cork_params"] = get_first(LCDS, "/sommelier/cork/v2/params")["params"]
    s["axelarcork_cellar_ids"] = get_first(LCDS, "/sommelier/axelarcork/v1/cellar_ids")["cellar_ids"]
    s["axelarcork_chain_configs"] = get_first(
        LCDS, "/sommelier/axelarcork/v1/chain_configurations")["configurations"]
    s["gravity_params"] = get_first(LCDS, "/gravity/v1/params")["params"]
    s["module_accounts"] = get_first(
        LCDS, "/cosmos/auth/v1beta1/module_accounts?pagination.limit=100")["accounts"]

    # balances of key module accounts
    mods = {a["name"]: a["base_account"]["address"] for a in s["module_accounts"]}
    s["module_balances"] = {}
    for name in ("distribution", "cellarfees", "gravity", "auction", "gov", "incentives",
                 "fee_collector", "pubsub", "interchainaccounts"):
        if name in mods:
            s["module_balances"][name] = get_first(
                LCDS, f"/cosmos/bank/v1beta1/balances/{mods[name]}?pagination.limit=200").get("balances", [])

    # cork authority account
    ca = s["cork_params"].get("cork_authority")
    if ca:
        s["cork_authority_account"] = get_first(LCDS, f"/cosmos/auth/v1beta1/accounts/{ca}").get("account")
        s["cork_authority_balances"] = get_first(
            LCDS, f"/cosmos/bank/v1beta1/balances/{ca}").get("balances", [])

    # effective power for authority validators
    s["effective_power"] = {}
    for op in s["poa_authority_set"]:
        try:
            s["effective_power"][op] = get_first(LCDS, f"/sommelier/poa/v1/effective_power/{op}")
        except Exception as e:  # noqa
            s["effective_power"][op] = {"error": scrub(e)}

    # recent proposals + prop 173
    try:
        props = get_first(LCDS, "/cosmos/gov/v1/proposals?pagination.limit=20&pagination.reverse=true")["proposals"]
        s["recent_proposals"] = [{
            "id": p["id"], "status": p.get("status"), "title": p.get("title"),
            "submit_time": p.get("submit_time"), "voting_end_time": p.get("voting_end_time"),
            "msgs": [m.get("@type") for m in p.get("messages", [])],
            "tally": p.get("final_tally_result"),
            "deposit": p.get("total_deposit"),
        } for p in props]
    except Exception as e:  # noqa
        s["recent_proposals_error"] = scrub(e)

    # gov params via ABCI (LCD params route is unimplemented on this chain)
    try:
        raw = rpc_call(RPCS, "abci_query",
                       {"path": "/store/gov/key", "data": "30", "height": "0"})
        val = raw["response"]["value"]
        s["gov_params"] = decode_gov_params(base64.b64decode(val))
        s["gov_params_height"] = raw["response"].get("height")
    except Exception as e:  # noqa
        s["gov_params_error"] = scrub(e)

    # --- prices ---
    try:
        res["prices"] = get(
            "https://coins.llama.fi/prices/current/coingecko:sommelier,coingecko:osmosis,coingecko:ethereum")
    except Exception as e:  # noqa
        res["prices_error"] = scrub(e)

    # --- Osmosis SOMM pools (scan up to 6 pages x 1000) ---
    pools, key, pages = [], None, 0
    try:
        while pages < 6:
            url = "https://lcd.osmosis.zone/osmosis/gamm/v1beta1/pools?pagination.limit=1000"
            if key:
                url += "&pagination.key=" + urllib.parse.quote(key)
            d = get(url, timeout=45)
            for p in d.get("pools", []):
                if SOMM_IBC in json.dumps(p):
                    pools.append(p)
            key = d.get("pagination", {}).get("next_key")
            pages += 1
            if not key:
                break
        res["osmosis_somm_pools"] = pools
        res["osmosis_pages_scanned"] = pages
    except Exception as e:  # noqa
        res["osmosis_error"] = scrub(e)

    # denom traces for the counter-denoms of the main pools (for valuation)
    traces = {}
    try:
        for p in pools:
            for tok in p.get("pool_assets", []) + p.get("pool_liquidity", []):
                den = tok.get("denom", "")
                if den.startswith("ibc/"):
                    try:
                        t = get(f"https://lcd.osmosis.zone/ibc/apps/transfer/v1/denom_traces/{den[4:]}", timeout=20)
                        traces[den] = t.get("denom_trace")
                    except Exception:  # noqa
                        pass
        res["osmosis_denom_traces"] = traces
    except Exception:  # noqa
        pass

    # --- Ethereum facts ---
    eth = {"block": eth_block(ETH_RPC)}
    SOMM = "0xa670d7237398238DE01267472C6f13e5B8010FD1"
    WETH = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2"
    PAIR = "0x8bbe2a88603e63ba5f2fac8ee4f54171d9bfaa96"
    GRAVITY = "0x69592e6f9d21989a043646fe8225da2600e5a0f7"
    eth["uniswap_v2_pair"] = PAIR
    try:
        r = eth_call(ETH_RPC, PAIR, "0x0902f1ac")
        eth["pair_reserves"] = {
            "reserve0": int(r[2:66], 16), "reserve1": int(r[66:130], 16),
            "blockTimestampLast": int(r[130:194], 16),
        }
    except Exception as e:  # noqa
        eth["pair_reserves_error"] = scrub(e)
    try:
        eth["somm_erc20_total_supply"] = int(eth_call(ETH_RPC, SOMM, "0x18160ddd"), 16)
    except Exception as e:  # noqa
        eth["somm_erc20_error"] = scrub(e)
    eth["gravity_holdings"] = {}
    for name, tok, dec in [("WETH", WETH, 18), ("USDC", "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48", 6),
                           ("stETH", "0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84", 18),
                           ("FRAX", "0x853d955aCEf822Db058eb8505911ED77F175b99e", 18),
                           ("SOMM", SOMM, 6)]:
        try:
            v = int(eth_call(ETH_RPC, tok, "0x70a08231" + "0" * 24 + GRAVITY[2:].lower()), 16)
            eth["gravity_holdings"][name] = {"raw": str(v), "tokens": v / (10 ** dec)}
        except Exception as e:  # noqa
            eth["gravity_holdings"][name] = {"error": scrub(e)}
    res["ethereum"] = eth

    # --- EVM cellars (cork-managed) ---
    cellars = {
        "arbitrum": {"rpc": ARB_RPC, "addrs": [
            "0x438087f7c226A89762a791F187d7c3D4a0e95ae6",
            "0x392B1E6905bb8449d26af701Cdea6Ff47bF6e5A8",
            "0x01a4A3E1E730D245F210EebC6aEE54F2381CAC63",
            "0xC47bB288178Ea40bF520a91826a3DEE9e0DbFA4C"]},
        "optimism": {"rpc": OP_RPC, "addrs": ["0xC47bB288178Ea40bF520a91826a3DEE9e0DbFA4C"]},
        "scroll": {"rpc": SCROLL_RPC, "addrs": ["0xd3BB04423b0c98aBc9d62f201212f44dC2611200"]},
    }
    res["cellars"] = {}
    for chain, cfg in cellars.items():
        res["cellars"][chain] = {"block": None, "items": []}
        try:
            res["cellars"][chain]["block"] = eth_block(cfg["rpc"])
        except Exception:  # noqa
            pass
        for a in cfg["addrs"]:
            item = {"address": a}
            for sig, name in [("0x8da5cb5b", "owner"), ("0x01e1d114", "totalAssets"), ("0x38d52e0f", "asset")]:
                try:
                    item[name] = eth_call(cfg["rpc"], a, sig)
                except Exception as e:  # noqa
                    item[name] = "error: " + scrub(e)
            res["cellars"][chain]["items"].append(item)

    with open(os.path.join(OUT, "live_state.json"), "w") as f:
        json.dump(res, f, indent=1)
    print(json.dumps({
        "height": res["sommelier"]["height"],
        "bonded": res["sommelier"]["staking_pool"]["bonded_tokens"],
        "cp_usomm": [x for x in res["sommelier"]["community_pool"] if x["denom"] == "usomm"],
        "safe_mode": res["sommelier"]["poa_safe_mode"],
        "gov_params": res["sommelier"].get("gov_params"),
        "osmosis_pools_found": len(res.get("osmosis_somm_pools", [])),
        "eth_block": res["ethereum"]["block"],
    }, indent=1))


if __name__ == "__main__":
    main()
