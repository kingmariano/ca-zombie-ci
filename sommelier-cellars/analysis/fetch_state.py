#!/usr/bin/env python3
"""C2-28 Sommelier cellars / gravity module dust — read-only evidence fetch.

Public endpoints only (no API keys). Queries:
  * sommelier-3 LCD: module balances, cellarfees v2, cork/axelarcork cellar IDs,
    community pool, staking pool, supply, gravity params + raw KV subspaces.
  * Ethereum public RPC: SOMM ERC-20 totalSupply/decimals/symbol (the bridge counter-asset).
  * DefiLlama: SOMM price + Sommelier protocol TVL.

Usage: python3 fetch_state.py <outdir>
Writes <outdir>/raw/*.json and <outdir>/state.json (consolidated).
"""
import json
import sys
import urllib.request
import urllib.error
import base64
import os
import struct

LCD = "https://sommelier-api.polkachu.com"
RPC = "https://sommelier-rpc.polkachu.com"
ETH_RPC = "https://ethereum-rpc.publicnode.com"
UA = {"User-Agent": "zombie-hunt-ci/1.0 (read-only research)"}

OUT = sys.argv[1] if len(sys.argv) > 1 else "ci-out"
RAW = os.path.join(OUT, "raw")
os.makedirs(RAW, exist_ok=True)


def http_json(url, data=None, headers=None):
    req = urllib.request.Request(url, data=json.dumps(data).encode() if data is not None else None,
                                 headers={**UA, **(headers or {})})
    with urllib.request.urlopen(req, timeout=45) as r:
        return json.loads(r.read().decode())


def get(path, height=None, name=None):
    h = {"x-cosmos-block-height": str(height)} if height else {}
    try:
        d = http_json(LCD + path, headers=h)
    except Exception as e:
        d = {"error": str(e)}
    if name:
        with open(os.path.join(RAW, name + ".json"), "w") as f:
            json.dump(d, f, indent=1)
    return d


def abci(path, data_hex, name=None):
    payload = {"jsonrpc": "2.0", "id": 1, "method": "abci_query",
               "params": {"path": path, "data": data_hex, "height": "0", "prove": False}}
    try:
        d = http_json(RPC, data=payload)
    except Exception as e:
        d = {"error": str(e)}
    if name:
        with open(os.path.join(RAW, name + ".json"), "w") as f:
            json.dump(d, f, indent=1)
    return d


def abci_val(resp):
    try:
        v = resp["result"]["response"].get("value")
        return base64.b64decode(v) if v else b""
    except Exception:
        return b""


def read_varint(b, i):
    r = 0
    s = 0
    while True:
        x = b[i]
        i += 1
        r |= (x & 0x7F) << s
        if not x & 0x80:
            break
        s += 7
    return r, i


def parse_kv_pairs(b):
    """Decode cosmos kv.Pairs protobuf: repeated Pair pairs=1 { bytes key=1; bytes value=2; }"""
    pairs = []
    i = 0
    while i < len(b):
        tag, i = read_varint(b, i)
        fn, wt = tag >> 3, tag & 7
        if wt == 2:
            ln, i = read_varint(b, i)
            chunk = b[i:i + ln]
            i += ln
            if fn == 1:
                pairs.append(chunk)
        elif wt == 0:
            _, i = read_varint(b, i)
        else:
            raise ValueError("wiretype")
    out = []
    for p in pairs:
        j, key, val = 0, None, None
        while j < len(p):
            tag, j = read_varint(p, j)
            fn, wt = tag >> 3, tag & 7
            if wt == 2:
                ln, j = read_varint(p, j)
                chunk = p[j:j + ln]
                j += ln
                if fn == 1:
                    key = chunk
                elif fn == 2:
                    val = chunk
            elif wt == 0:
                _, j = read_varint(p, j)
        out.append((key, val))
    return out


def eth_call(to, data):
    payload = {"jsonrpc": "2.0", "id": 1, "method": "eth_call",
               "params": [{"to": to, "data": data}, "latest"]}
    try:
        d = http_json(ETH_RPC, data=payload)
        return d.get("result")
    except Exception as e:
        return "err:" + str(e)


def main():
    state = {}
    # --- height anchor ---
    latest = get("/cosmos/base/tendermint/v1beta1/blocks/latest", name="latest_block")
    try:
        hdr = latest["block"]["header"]
        H = hdr["height"]
        state["sommelier"] = {"chain_id": hdr["chain_id"], "height": int(H), "time": hdr["time"]}
    except Exception:
        H = None
        state["sommelier"] = {"error": "latest block failed", "raw": latest}
    print("[fetch] sommelier-3 height:", H)

    # --- bank balances of all module accounts of interest ---
    addrs = {
        "gravity": "somm16n3lc7cywa68mg50qhp847034w88pntq22vzye",
        "cellarfees": "somm1hqf42j6zxfnth4xpdse05wpnjjrgc864vwujxx",
        "auction": "somm1j4yzhgjm00ch3h0p9kel7g8sp6g045qfhle2uq",
        "axelarcork": "somm1lrneqhq4rq8nz2nk6vn3sanrxva7zuns8aa45g",
        "pubsub": "somm1jttycysjw62kuy5a2zdvdxgcp7xr93hqsw05qu",
        "distribution": "somm1jv65s3grqf6v6jl3dp4t6c9t9rk99cd8trtsc4",
        "fee_collector": "somm17xpfvakm2amg962yls6f84z3kell8c5lu9vv6h",
        "gov": "somm10d07y265gmmuvt4z0w9aw880jnsr700jk7uf8e",
        "cellarfees_proceeds_msig": "somm1rvu9w27sstm2z7jgyq7kll0hfj4fdhsgnw0tat",
    }
    state["module_balances"] = {}
    for name, addr in addrs.items():
        d = get(f"/cosmos/bank/v1beta1/balances/{addr}?pagination.limit=200",
                height=H, name=f"bal_{name}")
        state["module_balances"][name] = {"address": addr, "balances": d.get("balances", d)}

    # --- community pool / supply / staking ---
    cp = get("/cosmos/distribution/v1beta1/community_pool", height=H, name="community_pool")
    state["community_pool"] = cp.get("pool", cp)
    sup = get("/cosmos/bank/v1beta1/supply/by_denom?denom=usomm", height=H, name="supply_usomm")
    state["supply_usomm"] = sup.get("amount", sup)
    sp = get("/cosmos/staking/v1beta1/pool", height=H, name="staking_pool")
    state["staking_pool"] = sp.get("pool", sp)

    # --- gravity module state (v1 routes + raw KV) ---
    gp = get("/gravity/v1/params", height=H, name="gravity_params")
    state["gravity_params"] = gp.get("params", gp)
    state["gravity_kv"] = {}
    for pref, nm in [("07", "unbatched_sends"), ("06", "outgoing_txs"),
                     ("10", "denom_to_erc20"), ("11", "erc20_to_denom"),
                     ("15", "completed_outgoing")]:
        r = abci("/store/gravity/subspace", pref, name=f"gravity_subspace_{nm}")
        v = abci_val(r)
        try:
            pairs = parse_kv_pairs(v)
        except Exception:
            pairs = []
        state["gravity_kv"][nm] = {
            "count": len(pairs),
            "keys": [k.hex() if k else None for k, _ in pairs[:60]],
        }
        if nm == "denom_to_erc20":
            state["gravity_kv"][nm]["pairs_hex"] = [[k.hex(), (val.hex() if val else None)] for k, val in pairs]
    for key, nm in [("0E", "last_send_to_ethereum_id"), ("0D", "last_outgoing_batch_nonce"),
                    ("09", "last_observed_event_nonce")]:
        r = abci("/store/gravity/key", key, name=f"gravity_key_{nm}")
        v = abci_val(r)
        state["gravity_kv"][nm] = struct.unpack(">Q", v)[0] if len(v) == 8 else None

    # --- cellarfees v2 ---
    state["cellarfees"] = {
        "params": get("/sommelier/cellarfees/v2/params", height=H, name="cellarfees_params"),
        "module_accounts": get("/sommelier/cellarfees/v2/module_accounts", height=H, name="cellarfees_accounts"),
        "fee_token_balances": get("/sommelier/cellarfees/v2/fee_token_balances", height=H, name="cellarfees_fee_balances"),
        "last_reward_supply_peak": get("/sommelier/cellarfees/v2/last_reward_supply_peak", height=H, name="cellarfees_reward_peak"),
    }

    # --- cork managed cellar IDs (the strategy contracts) ---
    state["cork_v2_cellar_ids"] = get("/sommelier/cork/v2/cellar_ids", height=H, name="cork_v2_cellar_ids")
    state["cork_v2_params"] = get("/sommelier/cork/v2/params", height=H, name="cork_v2_params")
    state["axelarcork_cellar_ids"] = get("/sommelier/axelarcork/v1/cellar_ids", height=H, name="axelarcork_cellar_ids")

    # --- Ethereum counter-asset: SOMM ERC-20 ---
    SOMM_ERC20 = "0xa670d7237398238de01267472c6f13e5b8010fd1"
    eth = {
        "address": SOMM_ERC20,
        "totalSupply_raw": eth_call(SOMM_ERC20, "0x18160ddd"),
        "decimals_raw": eth_call(SOMM_ERC20, "0x313ce567"),
        "name_raw": eth_call(SOMM_ERC20, "0x06fdde03"),
        "symbol_raw": eth_call(SOMM_ERC20, "0x95d89b41"),
    }
    state["somm_erc20"] = eth
    with open(os.path.join(RAW, "somm_erc20.json"), "w") as f:
        json.dump(eth, f, indent=1)

    # --- prices / TVL (DefiLlama, keyless) ---
    try:
        state["price_somm"] = http_json(
            "https://coins.llama.fi/prices/current/coingecko:sommelier")
    except Exception as e:
        state["price_somm"] = {"error": str(e)}
    try:
        state["sommelier_tvl"] = http_json("https://api.llama.fi/tvl/sommelier")
    except Exception as e:
        state["sommelier_tvl"] = {"error": str(e)}
    try:
        state["sommelier_protocol"] = http_json("https://api.llama.fi/protocol/sommelier")
    except Exception as e:
        state["sommelier_protocol"] = {"error": str(e)}

    # --- derived headline arithmetic ---
    try:
        price = state["price_somm"]["coins"]["coingecko:sommelier"]["price"]
    except Exception:
        price = None

    def bal(name, denom):
        for b in state["module_balances"][name]["balances"]:
            if b.get("denom") == denom:
                return int(b["amount"])
        return 0

    usd = {}
    if price:
        usd["gravity_module_usomm"] = bal("gravity", "usomm") / 1e6 * price
        usd["community_pool_usomm"] = int(state["community_pool"][1]["amount"].split(".")[0]) / 1e6 * price \
            if len(state["community_pool"]) > 1 else None
        usd["cellarfees_usd_module_valuation"] = sum(
            b.get("usd_value", 0) for b in state["cellarfees"]["fee_token_balances"].get("balances", []))
    state["derived_usd"] = usd
    state["somm_price_usd"] = price

    with open(os.path.join(OUT, "state.json"), "w") as f:
        json.dump(state, f, indent=1)
    print("[fetch] wrote", os.path.join(OUT, "state.json"))
    return 0


if __name__ == "__main__":
    sys.exit(main())
