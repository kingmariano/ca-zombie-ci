#!/usr/bin/env python3
"""C2-26 unpatched-chain advisory class — independent live-state verification.

Read-only. Public endpoints only (no keys, no secrets). Runs on GitHub Actions.
Verifies, for PundiX / Nyx / Sommelier / Shido:
  - node binary + wasmvm + ibc-go versions across >=2 endpoints each
  - CosmWasm code_upload_access / instantiate permissions
  - codes / contracts census and their balances (wasm-capable chains)
  - gov / staking / supply / community-pool state
  - Shido DEX pool census (on-chain pair discovery + balances + USD pricing)
  - Osmosis visibility of the Shido + Nyx IBC vouchers
  - wasmvm module artifact verification (v2.1.4, v2.2.1 vulnerable; v2.2.9 fixed)
Outputs JSON + text into ci-out/.
"""
import base64
import hashlib
import json
import os
import sys
import time
import urllib.request
import urllib.error
from concurrent.futures import ThreadPoolExecutor

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "ci-out")
os.makedirs(OUT, exist_ok=True)
UA = {"User-Agent": "zombie-hunt-ci/1.0"}

RPC_SEL = {
    "reserves": "0x0902f1ac",       # getReserves()
    "token0": "0x0dfe1681",
    "token1": "0xd21220a7",
    "symbol": "0x95d89b41",
    "decimals": "0x313ce567",
    "liquidity": "0x1a686502",
    "fee": "0xddca3f43",
    "balanceOf": "0x70a08231",
    "totalSupply": "0x18160ddd",
}

CHAINS = {
    "pundix": {
        "rest": ["https://px-rest.pundix.com"],
        "rpc": ["https://px-json.pundix.com"],
        "expect_wasm": False,
    },
    "nyx": {
        "rest": ["https://api.nyx.nodes.guru", "https://api.nymtech.net"],
        "rpc": ["https://rpc.nymtech.net"],
        "expect_wasm": True,
    },
    "sommelier": {
        "rest": ["https://sommelier-api.polkachu.com"],
        "rpc": ["https://sommelier-rpc.polkachu.com"],
        "expect_wasm": False,
    },
    "shido": {
        "rest": ["https://api-shido.onenov.xyz", "https://rest.mavnode.io"],
        "rpc": ["https://rpc-shido.onenov.xyz"],
        "evm": "https://evm.shidoscan.net",
        "explorer": "https://shidoscan.com/api/v2",
        "expect_wasm": True,
    },
}

RESULTS = {}


def http(url, timeout=40, data=None, headers=None, retries=2):
    last = None
    for _ in range(retries + 1):
        try:
            req = urllib.request.Request(url, data=data, headers=headers or UA)
            with urllib.request.urlopen(req, timeout=timeout) as r:
                return r.read()
        except Exception as e:  # noqa
            last = e
            time.sleep(1.5)
    raise last


def jget(url, **kw):
    return json.loads(http(url, **kw))


def save(name, obj):
    with open(os.path.join(OUT, name), "w") as f:
        json.dump(obj, f, indent=1, default=str)
    print(f"[saved] {name}")


def save_text(name, text):
    with open(os.path.join(OUT, name), "w") as f:
        f.write(text)
    print(f"[saved] {name}")


# ---------------------------------------------------------------- cosmos REST
def node_info(chain, base):
    try:
        d = jget(f"{base}/cosmos/base/tendermint/v1beta1/node_info")
    except Exception as e:
        return {"endpoint": base, "error": str(e)}
    ai = d.get("application_version", {}) or {}
    deps = {b.get("path"): b.get("version") for b in ai.get("build_deps", []) or []}
    return {
        "endpoint": base,
        "app_name": ai.get("name"),
        "app_version": ai.get("version"),
        "git_commit": (ai.get("git_commit") or "")[:12],
        "cosmos_sdk": ai.get("cosmos_sdk_version"),
        "go_version": ai.get("go_version"),
        "build_tags": ai.get("build_tags"),
        "wasmvm": deps.get("github.com/CosmWasm/wasmvm/v2")
        or deps.get("github.com/CosmWasm/wasmvm"),
        "wasmd": deps.get("github.com/CosmWasm/wasmd"),
        "ibc_go": deps.get("github.com/cosmos/ibc-go/v3")
        or deps.get("github.com/cosmos/ibc-go/v4")
        or deps.get("github.com/cosmos/ibc-go/v5")
        or deps.get("github.com/cosmos/ibc-go/v6")
        or deps.get("github.com/cosmos/ibc-go/v7")
        or deps.get("github.com/cosmos/ibc-go/v8")
        or deps.get("github.com/cosmos/ibc-go/v10"),
        "cometbft": deps.get("github.com/cometbft/cometbft")
        or deps.get("github.com/tendermint/tendermint"),
        "dep_count": len(deps),
    }


def try_get_json(chain, path, sink, label=None):
    """Try the REST path on every endpoint; first 2xx wins. Sink is dict."""
    for base in CHAINS[chain]["rest"]:
        try:
            d = jget(base + path)
            if isinstance(d, dict) and (d.get("code") in (12, 3, 5) or "error" in d):
                continue
            sink[label or path] = {"endpoint": base, "data": d}
            return True
        except Exception:
            continue
    sink[label or path] = {"error": "all endpoints failed or not implemented"}
    return False


def latest_block(chain, base):
    try:
        d = jget(f"{base}/cosmos/base/tendermint/v1beta1/blocks/latest")
        h = (d.get("block") or {}).get("header", {})
        return {"height": h.get("height"), "time": h.get("time"), "chain_id": h.get("chain_id")}
    except Exception as e:
        return {"error": str(e)}


# ----------------------------------------------- generic protobuf (ABCI gov)
def _varint(b, i):
    r = 0; s = 0
    while True:
        x = b[i]; i += 1
        r |= (x & 0x7F) << s
        if not (x & 0x80):
            return r, i
        s += 7


def pb_fields(b):
    out = []
    i = 0
    while i < len(b):
        try:
            key, i = _varint(b, i)
        except Exception:
            break
        fn, wt = key >> 3, key & 7
        if wt == 0:
            v, i = _varint(b, i); out.append((fn, wt, v))
        elif wt == 1:
            out.append((fn, wt, b[i:i+8])); i += 8
        elif wt == 2:
            ln, i = _varint(b, i); out.append((fn, wt, b[i:i+ln])); i += ln
        elif wt == 5:
            out.append((fn, wt, b[i:i+4])); i += 4
        else:
            break
    return out


def abci_query(rpc, path, data_hex=None):
    q = f'{rpc}/abci_query?path=%22{path}%22&prove=false'
    if data_hex:
        q += f"&data=0x{data_hex}"
    d = jget(q)
    r = (d.get("result") or {}).get("response", {})
    val = r.get("value")
    raw = base64.b64decode(val) if val else b""
    return {"code": r.get("code"), "log": (r.get("log") or "")[:200], "raw": raw}


def decode_gov_params(raw):
    """gov v1/v1beta1 Params — locate the submessage that carries quorum strings."""
    fields = pb_fields(raw)
    params = None
    import re as _re
    for fn, wt, v in fields:
        if wt == 2 and fn in (4, 1):
            sub = pb_fields(v)
            for sfn, swt, sv in sub:
                if swt == 2:
                    try:
                        s = sv.decode("utf-8")
                        if _re.match(r"^0\.\d+$", s):
                            params = v
                            break
                    except Exception:
                        pass
            if params:
                break
    if params is None:
        for fn, wt, v in fields:
            if wt == 2:
                try:
                    s = pb_fields(v)
                    if any(swt == 2 and isinstance(sv, bytes) and b"." in sv for _, swt, sv in s):
                        params = v
                        break
                except Exception:
                    pass
    if params is None:
        params = raw
    pf = pb_fields(params)
    out = {}
    names = {1: "min_deposit", 2: "max_deposit_period", 3: "voting_period", 4: "quorum",
             5: "threshold", 6: "veto_threshold", 7: "min_initial_deposit_ratio",
             8: "expedited_min_deposit", 10: "expedited_voting_period",
             11: "expedited_threshold", 12: "expedited_min_deposit_denom",
             14: "expedited_min_initial_deposit_ratio_approx", 15: "?15", 16: "?16"}
    for fn, wt, v in pf:
        name = names.get(fn, f"field{fn}")
        if wt == 2:
            try:
                s = v.decode("utf-8")
                if all(32 <= ord(c) < 127 for c in s) and s:
                    out[name] = s
                    continue
            except Exception:
                pass
            sub = pb_fields(v)
            submap = {}
            for sfn, swt, sv in sub:
                if swt == 2:
                    try:
                        ss = sv.decode("utf-8")
                        if all(32 <= ord(c) < 127 for c in ss) and ss:
                            submap[sfn] = ss
                            continue
                    except Exception:
                        pass
                submap[sfn] = sv if isinstance(sv, int) else sv.hex()[:32]
            out[name] = submap
        else:
            out[name] = v
    return out


# ------------------------------------------------------------- EVM machinery
def evm(chain, calls, chunk=100):
    evm_url = CHAINS[chain]["evm"]
    out_all = []
    for start in range(0, len(calls), chunk):
        part = calls[start:start + chunk]
        payload = [{"jsonrpc": "2.0", "id": i, "method": m, "params": p} for i, (m, p) in enumerate(part)]
        out = json.loads(http(evm_url, data=json.dumps(payload).encode(),
                              headers={**UA, "Content-Type": "application/json"}, timeout=60))
        res = {}
        for r in out:
            res[r.get("id")] = r.get("result")
        out_all += [res.get(i) for i in range(len(part))]
    return out_all


def pad32(addr):
    return "0x" + addr[2:].rjust(64, "0")


def dec_str(h):
    try:
        b = bytes.fromhex(h[2:])
        if len(b) >= 64:
            ln = int.from_bytes(b[32:64], "big")
            return b[64:64+ln].decode("utf-8", "replace")
    except Exception:
        pass
    return "?"


def explorer_holders(chain, token, max_items=400):
    base = CHAINS[chain]["explorer"]
    items, nxt = [], None
    while len(items) < max_items:
        u = f"{base}/tokens/{token}/holders"
        if nxt:
            u += "?next_page_params=" + urllib.parse.quote(json.dumps(nxt))
        try:
            d = jget(u)
        except Exception:
            break
        items += d.get("items", [])
        nxt = d.get("next_page_params")
        if not nxt:
            break
    return items


# =========================================================== per-chain parts
def chain_cosmos_common(chain, sink):
    r = {}
    for base in CHAINS[chain]["rest"]:
        r[base] = node_info(chain, base)
    sink["node_info"] = r
    sink["latest_block"] = latest_block(chain, CHAINS[chain]["rest"][0])
    try_get_json(chain, "/cosmwasm/wasm/v1/codes/params", sink, "wasm_params")
    try_get_json(chain, "/cosmos/staking/v1beta1/pool", sink, "staking_pool")
    try_get_json(chain, "/cosmos/staking/v1beta1/params", sink, "staking_params")
    try_get_json(chain, "/cosmos/distribution/v1beta1/community_pool", sink, "community_pool")
    try_get_json(chain, "/cosmos/bank/v1beta1/supply?pagination.limit=30", sink, "supply")
    try_get_json(chain, "/cosmos/upgrade/v1beta1/current_plan", sink, "current_plan")
    try_get_json(chain, "/cosmos/gov/v1/proposals?pagination.limit=60&pagination.reverse=true",
                 sink, "proposals_v1")
    if sink.get("proposals_v1", {}).get("error"):
        try_get_json(chain, "/cosmos/gov/v1beta1/proposals?pagination.limit=60&pagination.reverse=true",
                     sink, "proposals_v1beta1")


def pundix_part():
    c = "pundix"; sink = {}
    chain_cosmos_common(c, sink)
    # gov params via ABCI (v1beta1) - try several request encodings
    rpc = CHAINS[c]["rpc"][0]
    attempts = {}
    for path in ["/cosmos.gov.v1beta1.Query/Params", "/cosmos.params.v1beta1.Query/Params"]:
        try:
            r = abci_query(rpc, path)
            attempts[path] = {"code": r["code"], "log": r["log"]}
            if r["code"] == 0 and r["raw"]:
                attempts[path]["decoded"] = decode_gov_params(r["raw"])
        except Exception as e:
            attempts[path] = {"error": str(e)}
    sink["gov_params_abci"] = attempts
    try_get_json(c, "/ibc/core/channel/v1/channels?pagination.limit=50", sink, "ibc_channels")
    try_get_json(c, "/ibc/core/connection/v1/connections?pagination.limit=50", sink, "ibc_connections")
    try_get_json(c, "/ibc/core/client/v1/client_states?pagination.limit=30", sink, "ibc_clients")
    try_get_json(c, "/cosmos/staking/v1beta1/validators?status=BOND_STATUS_BONDED&pagination.limit=60",
                 sink, "bonded_validators")
    RESULTS[c] = sink


def nyx_part():
    c = "nyx"; sink = {}
    chain_cosmos_common(c, sink)
    rpc = CHAINS[c]["rpc"][0]
    try:
        r = abci_query(rpc, "/cosmos.gov.v1.Query/Params")
        sink["gov_params_abci"] = {"code": r["code"], "log": r["log"], "decoded": decode_gov_params(r["raw"]) if r["code"] == 0 else None}
    except Exception as e:
        sink["gov_params_abci"] = {"error": str(e)}
    # codes census
    base = CHAINS[c]["rest"][0]
    codes, key, pages = [], None, 0
    while pages < 5:
        u = f"{base}/cosmwasm/wasm/v1/code?pagination.limit=100"
        if key:
            u += "&pagination.key=" + urllib.parse.quote(key, safe="")
        try:
            d = jget(u)
        except Exception as e:
            sink["codes_error"] = str(e); break
        codes += d.get("code_infos", [])
        key = (d.get("pagination") or {}).get("next_key")
        pages += 1
        if not key:
            break
    contracts = {}
    candidate_addrs = set()
    for x in codes:
        ci = x.get("code_info", x)
        cid = ci.get("code_id")
        try:
            d = jget(f"{base}/cosmwasm/wasm/v1/code/{cid}/contracts")
            cs = d.get("contracts", [])
            if cs:
                candidate_addrs.update(cs)
        except Exception:
            pass
    # verify each candidate via contract_info (the per-code endpoint can return spurious dupes)
    true_instances, spurious = {}, []
    for a in sorted(candidate_addrs):
        try:
            d = jget(f"{base}/cosmwasm/wasm/v1/contract/{a}")
            ci = d.get("contract_info", {})
            true_instances[a] = {"code_id": ci.get("code_id"), "creator": ci.get("creator"),
                                 "admin": ci.get("admin"), "label": ci.get("label"),
                                 "created": ci.get("created")}
        except Exception as e:
            spurious.append(a)
    balances = {}
    for a in true_instances:
        try:
            d = jget(f"{base}/cosmos/bank/v1beta1/balances/{a}")
            balances[a] = d.get("balances", [])
        except Exception:
            balances[a] = "err"
    whitelist = None
    wp = sink.get("wasm_params", {}).get("data", {}).get("params", {})
    if wp:
        whitelist = wp.get("code_upload_access", {}).get("addresses", [])
    wl_acct = {}
    for w in whitelist or []:
        try:
            wl_acct[w] = jget(f"{base}/cosmos/auth/v1beta1/accounts/{w}")
        except Exception as e:
            wl_acct[w] = {"error": str(e)}
    sink["codes"] = {
        "count": len(codes),
        "creators": {str(x.get("code_info", x).get("creator")): sum(1 for y in codes if y.get("code_info", y).get("creator") == x.get("code_info", x).get("creator")) for x in codes},
        "instances_verified": true_instances,
        "instance_balances": balances,
        "spurious_addresses": spurious,
        "whitelist_accounts": wl_acct,
    }
    try:
        sink["unyx_supply"] = jget(f"{base}/cosmos/bank/v1beta1/supply/by_denom?denom=unyx")
        sink["unym_supply"] = jget(f"{base}/cosmos/bank/v1beta1/supply/by_denom?denom=unym")
    except Exception as e:
        sink["supply_by_denom_error"] = str(e)
    mods = ["n1purnwdrhg477r0evks8t5ah7c8thvrsssq8hjx", "n139js96huvt800a0rprnsdqrj3ymjdlwa6p6up9",
            "n1m20fddqpmfuwcz2r9ckj6wd70p5e75t88yvu96", "n1mqcszwafr476x3rud8qyufdegn7gvxh9xd7cd7"]
    sink["module_balances"] = {}
    for m in mods:
        try:
            sink["module_balances"][m] = jget(f"{base}/cosmos/bank/v1beta1/balances/{m}")
        except Exception as e:
            sink["module_balances"][m] = {"error": str(e)}
    RESULTS[c] = sink


def sommelier_part():
    c = "sommelier"; sink = {}
    chain_cosmos_common(c, sink)
    rpc = CHAINS[c]["rpc"][0]
    try:
        r = abci_query(rpc, "/cosmos.gov.v1.Query/Params")
        sink["gov_params_abci"] = {"code": r["code"], "log": r["log"], "decoded": decode_gov_params(r["raw"]) if r["code"] == 0 else None}
    except Exception as e:
        sink["gov_params_abci"] = {"error": str(e)}
    RESULTS[c] = sink


def shido_part():
    c = "shido"; sink = {}
    chain_cosmos_common(c, sink)
    rpc = CHAINS[c]["rpc"][0]
    try:
        r = abci_query(rpc, "/cosmos.gov.v1.Query/Params")
        sink["gov_params_abci"] = {"code": r["code"], "log": r["log"], "decoded": decode_gov_params(r["raw"]) if r["code"] == 0 else None}
    except Exception as e:
        sink["gov_params_abci"] = {"error": str(e)}
    base = CHAINS[c]["rest"][0]
    codes, key, pages = [], None, 0
    while pages < 5:
        u = f"{base}/cosmwasm/wasm/v1/code?pagination.limit=100"
        if key:
            u += "&pagination.key=" + urllib.parse.quote(key, safe="")
        try:
            d = jget(u)
        except Exception as e:
            sink["codes_error"] = str(e); break
        codes += d.get("code_infos", [])
        key = (d.get("pagination") or {}).get("next_key")
        pages += 1
        if not key:
            break
    contracts = {}
    for x in codes:
        ci = x.get("code_info", x)
        cid = ci.get("code_id")
        try:
            d = jget(f"{base}/cosmwasm/wasm/v1/code/{cid}/contracts")
            contracts[str(cid)] = d.get("contracts", [])
        except Exception:
            pass
    sink["codes"] = {"count": len(codes), "contracts": contracts}

    # ---- DEX pool census (on-chain, via holder scan + pair probing)
    TOKENS = {
        "WSHIDO": "0x8cbafFD9b658997E7bf87E98FEbF6EA6917166F7",
        "SHDX": "0xe550Bde2F0898552B38a41635d7a8DDB1Fd81276",
        "USDC": "0xeE1Fc22381e6B6bb5ee3bf6B5ec58DF6F5480dF8",
    }
    holders = {}
    for name, addr in TOKENS.items():
        try:
            hs = explorer_holders(c, addr, 400)
            holders[name] = [{"addr": (h.get("address") or {}).get("hash"),
                              "bal": int(h.get("value") or 0),
                              "is_contract": (h.get("address") or {}).get("is_contract")}
                             for h in hs if (h.get("address") or {}).get("hash")]
        except Exception as e:
            holders[name] = {"error": str(e)}
    probe = sorted({h["addr"] for hs in holders.values() if isinstance(hs, list) for h in hs})
    t0 = evm(c, [("eth_call", [{"to": a, "data": RPC_SEL["token0"]}, "latest"]) for a in probe])
    cand = [a for a, r in zip(probe, t0) if r and len(r) >= 42]
    t0f = [r for r in t0 if r and len(r) >= 42]
    t1 = evm(c, [("eth_call", [{"to": a, "data": RPC_SEL["token1"]}, "latest"]) for a in cand])
    pairs = {}
    for a, r0, r1 in zip(cand, t0f, t1):
        if r0 and r1:
            a0 = "0x" + r0[-40:].lower(); a1 = "0x" + r1[-40:].lower()
            if a0 != a1:
                pairs[a] = [a0, a1]
    toks = sorted({t for v in pairs.values() for t in v})
    meta = {}
    sym = evm(c, [("eth_call", [{"to": t, "data": RPC_SEL["symbol"]}, "latest"]) for t in toks])
    dec = evm(c, [("eth_call", [{"to": t, "data": RPC_SEL["decimals"]}, "latest"]) for t in toks])
    for t, s, d in zip(toks, sym, dec):
        meta[t] = {"symbol": dec_str(s) if s else "?",
                   "decimals": int(d, 16) if d and d != "0x" else None}
    # retry failed metadata reads one-by-one
    for t in toks:
        if meta[t]["symbol"] == "?" or meta[t]["decimals"] is None:
            for _ in range(3):
                s = evm(c, [("eth_call", [{"to": t, "data": RPC_SEL["symbol"]}, "latest"])])[0]
                d = evm(c, [("eth_call", [{"to": t, "data": RPC_SEL["decimals"]}, "latest"])])[0]
                if s:
                    meta[t]["symbol"] = dec_str(s)
                if d and d != "0x":
                    meta[t]["decimals"] = int(d, 16)
                if meta[t]["symbol"] != "?" and meta[t]["decimals"] is not None:
                    break
                time.sleep(0.5)
    calls = []
    for a, (a0, a1) in pairs.items():
        calls.append(("eth_call", [{"to": a0, "data": RPC_SEL["balanceOf"] + pad32(a)[2:]}, "latest"]))
        calls.append(("eth_call", [{"to": a1, "data": RPC_SEL["balanceOf"] + pad32(a)[2:]}, "latest"]))
        calls.append(("eth_call", [{"to": a, "data": RPC_SEL["reserves"]}, "latest"]))
        calls.append(("eth_call", [{"to": a, "data": RPC_SEL["liquidity"]}, "latest"]))
        calls.append(("eth_call", [{"to": a, "data": RPC_SEL["fee"]}, "latest"]))
    bal = evm(c, calls)
    rows = []
    for i, (a, (a0, a1)) in enumerate(pairs.items()):
        b0 = bal[5*i]; b1 = bal[5*i+1]; res = bal[5*i+2]; liq = bal[5*i+3]; fee = bal[5*i+4]
        r0 = int(b0, 16) if b0 and b0 != "0x" else 0
        r1 = int(b1, 16) if b1 and b1 != "0x" else 0
        d0, d1 = meta[a0]["decimals"], meta[a1]["decimals"]
        rows.append({
            "pair": a, "token0": a0, "symbol0": meta[a0]["symbol"], "bal0": r0,
            "human0": r0 / 10**d0 if d0 else None,
            "token1": a1, "symbol1": meta[a1]["symbol"], "bal1": r1,
            "human1": r1 / 10**d1 if d1 else None,
            "v2_reserves": bool(res and res != "0x"),
            "v3_liquidity": int(liq, 16) if liq and liq != "0x" else None,
            "fee": int(fee, 16) if fee and fee != "0x" else None,
        })
    # USD pricing for pool tokens
    ids = ",".join(f"shido:{t}" for t in toks)
    try:
        pr = jget(f"https://coins.llama.fi/prices/current/{ids}")
        prices = {k.split(":")[1].lower(): v.get("price") for k, v in (pr.get("coins") or {}).items()}
    except Exception:
        prices = {}
    # implied prices from DefiLlama protocol token breakdown (for tokens without a coins price)
    implied = {}
    try:
        dl = jget("https://api.llama.fi/protocol/shido-dex-v3")
        tok = (dl.get("chainTvls", {}).get("Shido", {}) or {}).get("tokens", [])
        usd = (dl.get("chainTvls", {}).get("Shido", {}) or {}).get("tokensInUsd", [])
        if tok and usd:
            tlast = tok[-1].get("tokens", {})
            ulast = usd[-1].get("tokens", {})
            for k in tlast:
                if tlast[k]:
                    implied[k.upper()] = ulast.get(k, 0) / tlast[k]
    except Exception:
        pass
    total_nonshido, total_usd = 0.0, 0.0
    for r in rows:
        p0 = prices.get(r["token0"])
        if p0 is None and r["symbol0"].upper() in implied:
            p0 = implied[r["symbol0"].upper()]
        p1 = prices.get(r["token1"])
        if p1 is None and r["symbol1"].upper() in implied:
            p1 = implied[r["symbol1"].upper()]
        u0 = (r["human0"] or 0) * (p0 or 0)
        u1 = (r["human1"] or 0) * (p1 or 0)
        r["usd0"], r["usd1"] = u0, u1
        total_usd += u0 + u1
        WSHIDO = TOKENS["WSHIDO"].lower()
        if r["token0"] == WSHIDO:
            total_nonshido += u1
        elif r["token1"] == WSHIDO:
            total_nonshido += u0
    sink["dex_census"] = {
        "token_holders": {k: len(v) for k, v in holders.items() if isinstance(v, list)},
        "pair_count": len(rows), "rows": rows,
        "prices": prices, "implied_prices": implied,
        "total_pool_usd": total_usd,
        "non_wshido_side_usd": total_nonshido,
    }
    RESULTS[c] = sink


def osmosis_part():
    """Find SHIDO + unyx IBC vouchers in Osmosis pools."""
    targets = {
        "SHIDO": "62B50BB1DAEAD2A92D6C6ACAC118F4ED8CBE54265DCF5688E8D0A0A978AA46E7",
        "unyx": "43DC13F256D806DF763C36D922349DFE3CB0287B5DA064A64FA0E7B90971494F",
    }
    found = {k: [] for k in targets}
    key = None
    pages = 0
    while pages < 5:
        u = "https://lcd.osmosis.zone/osmosis/gamm/v1beta1/pools?pagination.limit=1000"
        if key:
            u += "&pagination.key=" + urllib.parse.quote(key, safe="")
        try:
            d = jget(u, timeout=90)
        except Exception as e:
            found["error"] = str(e)
            break
        pools = d.get("pools", [])
        for p in pools:
            s = json.dumps(p)
            for name, hash_ in targets.items():
                if hash_ in s:
                    found[name].append(p)
        key = (d.get("pagination") or {}).get("next_key")
        pages += 1
        if not key:
            break
    found["pages"] = pages
    save("osmosis_targets.json", found)
    return found


def wasmvm_artifacts():
    out = {"checked_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()), "versions": {}}
    lines = ["# wasmvm artifact verification (C2-26)", ""]
    for v in ["v2.1.4", "v2.2.1", "v2.2.9"]:
        entry = {"version": v}
        try:
            url = f"https://proxy.golang.org/github.com/!cosm!wasm/wasmvm/v2/@v/{v}.zip"
            data = http(url, timeout=120)
            entry["zip_sha256"] = hashlib.sha256(data).hexdigest()
            entry["zip_bytes"] = len(data)
            import zipfile, io
            z = zipfile.ZipFile(io.BytesIO(data))
            lock = [n for n in z.namelist() if n.endswith("Cargo.lock")]
            cargo = z.read(lock[0]).decode("utf-8", "replace") if lock else ""
            for pkg in ["wasmer", "wasmer-compiler-singlepass"]:
                idx = cargo.find(f'name = "{pkg}"')
                if idx >= 0:
                    seg = cargo[idx:idx+220].splitlines()
                    ver = None
                    for ln in seg:
                        if ln.strip().startswith("version"):
                            ver = ln.split('"')[1]
                            break
                    entry[pkg] = ver
            entry["cargo_lock"] = lock[0] if lock else None
        except Exception as e:
            entry["error"] = str(e)
        try:
            lookup = http(f"https://sum.golang.org/lookup/github.com/!cosm!wasm/wasmvm/v2@{v}", timeout=40).decode()
            entry["sum_golang"] = [l for l in lookup.splitlines() if l.startswith("github.com/CosmWasm/wasmvm")]
        except Exception as e:
            entry["sum_golang_error"] = str(e)
        out["versions"][v] = entry
        lines.append(f"{v}: sha256={entry.get('zip_sha256')} wasmer={entry.get('wasmer')} singlepass={entry.get('wasmer-compiler-singlepass')} bytes={entry.get('zip_bytes')}")
        for l in entry.get("sum_golang", []):
            lines.append("   sum.golang.org: " + l)
    save("wasmvm_artifact_check.json", out)
    save_text("wasmvm_artifact_check.txt", "\n".join(lines) + "\n")
    return out


def main():
    t0 = time.time()
    osmosis = None
    with ThreadPoolExecutor(max_workers=4) as ex:
        futs = {
            "pundix": ex.submit(pundix_part),
            "nyx": ex.submit(nyx_part),
            "sommelier": ex.submit(sommelier_part),
            "shido": ex.submit(shido_part),
            "osmosis": ex.submit(osmosis_part),
            "wasmvm": ex.submit(wasmvm_artifacts),
        }
        for k, f in futs.items():
            try:
                r = f.result()
                if k == "osmosis":
                    osmosis = r
            except Exception as e:
                RESULTS.setdefault("_errors", {})[k] = str(e)
                print(f"[ERR] {k}: {e}", file=sys.stderr)

    save("verification.json", RESULTS)
    summary = {
        "generated_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "runtime_s": round(time.time() - t0, 1),
        "chains": {
            c: {
                "versions": list({str(n.get("app_version")): n for n in (v.get("node_info") or {}).values()}.values()),
                "wasm_params": (v.get("wasm_params") or {}).get("data", {}).get("params"),
                "latest_block": v.get("latest_block"),
            }
            for c, v in RESULTS.items() if isinstance(v, dict) and "node_info" in v
        },
    }
    if isinstance(RESULTS.get("shido"), dict):
        dc = RESULTS["shido"].get("dex_census", {})
        summary["shido_dex"] = {
            "pair_count": dc.get("pair_count"),
            "total_pool_usd": dc.get("total_pool_usd"),
            "non_wshido_side_usd": dc.get("non_wshido_side_usd"),
        }
    save("summary_ci.json", summary)
    print(json.dumps(summary, indent=1)[:4000])


if __name__ == "__main__":
    import urllib.parse  # noqa
    main()
