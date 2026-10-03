#!/usr/bin/env python3
"""C-26 CI heavy job: enumerate every Safe with the SquidRouterModule enabled today,
verify permissions on-chain, measure balances, and price them.

Outputs (to $OUT, default ../ci-out):
  - modules_events.json     raw enable/disable logs
  - enumeration.json        per-Safe verified state + balances (raw)
  - safes.csv               compact table
  - summary.json            aggregate USD + block numbers
Read-only. Needs env: RPC/FORK_RPC_URL, ETHERSCANV2_API_KEY. GoldRush optional.
"""
import csv, json, os, sys, time, urllib.request, urllib.parse

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.environ.get("OUT", os.path.join(HERE, "..", "ci-out"))
os.makedirs(OUT, exist_ok=True)
RPC = os.environ.get("FORK_RPC_URL") or os.environ.get("BLOCKPI_RPC_URL") or os.environ.get("RPC_URL")
ESKEY = os.environ.get("ETHERSCANV2_API_KEY", "")
MODULE = "0x1f1d37a3bf840e35c6a860c7c2da71fe555123ca"
PM = "0x03B8B1bA6B02b8A566cB757DFa627f7198c44cB7"
T_ENABLED = "0xecdf3a3effea5783a3c4c2140e677577666428d44ed9d474a0b3a4c9943f8440"
T_DISABLED = "0xaab4fa2b463f581b2b32cb3b7e3b704b9ce37cc209b5fb4d77e593ace4054276"
T_MODULE = "0x000000000000000000000000" + MODULE[2:]

CURATED = {
    "USDC": "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
    "USDT": "0xdAC17F958D2ee523a2206206994597C13D831ec7",
    "DAI": "0x6B175474E89094C44Da98b954EedeAC495271d0F",
    "WETH": "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2",
    "WBTC": "0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599",
    "stETH": "0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84",
    "wstETH": "0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0",
    "LINK": "0x514910771AF9Ca656af840dff83E8264EcF986CA",
    "UNI": "0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984",
    "AAVE": "0x7Fc66500c84A76Ad7e9c93437bFc5Ac33E2DDaE9",
    "MKR": "0x9f8F72aA9304c8B593d555F12eF6589cC3A579A2",
    "CRV": "0xD533a949740bb3306d119CC777fa900bA034cd52",
    "LDO": "0x5A98FcBEA516Cf06857215779Fd812CA3beF1B32",
    "PEPE": "0x6982508145454Ce325dDbE47a25d4ec3d2311933",
    "SHIB": "0x95aD61b0a150d79219dCF64E1E6Cc01f0B64C4cE",
    "ENS": "0xC18360217D8F7Ab5e7c516566761Ea12Ce7F9D72",
    "COMP": "0xc00e94Cb662C3520282E6f5717214004A7f26888",
    "SNX": "0xC011a73ee8576Fb46F5E1c5751cA3B9Fe0af2a6F",
    "GRT": "0xc944E90C64B2c07662A292be6244BDf05Cda44a7",
    "1INCH": "0x111111111117dC0aa78b770fA6A738034120C302",
    "SUSHI": "0x6B3595068778DD592e39A122f4f5a5cF09C90fE2",
    "YFI": "0x0bc529c00C6401aEF6D220BE8C6Ea1667F6Ad93e",
    "BAL": "0xba100000625a3754423978a60c9317c58a424e3D",
    "RPL": "0xD33526068D116cE69F19A9ee46F0bd304F21A51f",
    "ARB": "0xB50721BCf8d664c30412Cfbc6cf7a15145234ad1",
    "PYUSD": "0x6c3ea9036406852006290770BEdFcAbA0e23A0e8",
    "FRAX": "0x853d955aCEf822Db058eb8505911ED77F175b99e",
    "USDe": "0x4c9EDD5852cd905f086C759E8383e09bff1E68B3",
    "sUSDe": "0x9D39A5DE30e57443BfF2A8307A4256c8797A3497",
    "GHO": "0x40D16FC0246aD3160Ccc09B8D0D3A2cD28aE6C2f",
    "cbETH": "0xBe9895146f7AF43049ca1c1AE358B0541Ea49704",
    "rETH": "0xae78736Cd615f374D3085123A210448E74Fc6393",
    "ENA": "0x57e114B691Db790C35207b2e685D4A43181e6061",
    "ONDO": "0xfAbA6f8e4a5E8Ab82F62fe7C39859FA577269BE3",
    "MORPHO": "0x58D97B57BB95320F9a05dC918Aef65434969c2B2",
}
BALOF = "0x70a08231"


def http_json(url, tries=4):
    for a in range(tries):
        try:
            with urllib.request.urlopen(url, timeout=45) as r:
                return json.loads(r.read().decode())
        except Exception as e:
            print("http retry", e, flush=True)
            time.sleep(2 + a)
    return {}


def rpc(method, params, tries=4):
    body = json.dumps({"jsonrpc": "2.0", "id": 1, "method": method, "params": params}).encode()
    for a in range(tries):
        try:
            req = urllib.request.Request(RPC, data=body, headers={"Content-Type": "application/json",
                                                                  "User-Agent": "Mozilla/5.0"})
            with urllib.request.urlopen(req, timeout=45) as r:
                return json.loads(r.read().decode()).get("result")
        except Exception as e:
            print("rpc retry", method, e, flush=True)
            time.sleep(2 + a)
    return None


def rpc_batch(calls):
    reqs = [{"jsonrpc": "2.0", "id": i, "method": "eth_call",
             "params": [{"to": t, "data": d}, "latest"]} for i, (t, d) in enumerate(calls)]
    body = json.dumps(reqs).encode()
    for a in range(4):
        try:
            req = urllib.request.Request(RPC, data=body, headers={"Content-Type": "application/json",
                                                                  "User-Agent": "Mozilla/5.0"})
            with urllib.request.urlopen(req, timeout=60) as r:
                resp = json.loads(r.read().decode())
            break
        except Exception as e:
            print("batch retry", e, flush=True)
            time.sleep(2 + a)
    else:
        return [None] * len(calls)
    out = [None] * len(calls)
    for item in resp:
        if "result" in item:
            out[item["id"]] = item["result"]
    return out


def fetch_logs(topic0, name):
    rows, page = [], 1
    while True:
        q = {"chainid": "1", "module": "logs", "action": "getLogs", "fromBlock": "0", "toBlock": "latest",
             "topic0": topic0, "topic1": T_MODULE, "page": str(page), "offset": "1000", "apikey": ESKEY}
        d = http_json("https://api.etherscan.io/v2/api?" + urllib.parse.urlencode(q))
        rs = d.get("result") if isinstance(d.get("result"), list) else []
        if not rs:
            if d.get("message") and d.get("message") != "No records found":
                print("etherscan", name, ":", d.get("status"), d.get("message"), str(d.get("result"))[:200], flush=True)
            break
        rows += rs
        if len(rs) < 1000:
            break
        page += 1
    # fallback to locally fetched evidence if the shared Etherscan key is rate-limited
    if not rows:
        fname = {"enabled_logs.json": "enabled_module.json",
                 "disabled_logs.json": "disabled_module.json"}.get(name)
        cand = os.path.join(HERE, "..", "analysis", "logs", fname) if fname else None
        if cand and os.path.exists(cand):
            rows = json.load(open(cand))
            print("using fallback", cand, len(rows), flush=True)
    json.dump(rows, open(os.path.join(OUT, name), "w"), indent=1)
    return rows


def num(v):
    return int(v, 16) if isinstance(v, str) and v.startswith("0x") else int(v)


def topic_addr(t):
    return "0x" + t[-40:]


def parse_delegators(raw):
    """Parse cast-like output is not available in CI; we decode raw eth_call return data here."""
    return raw  # placeholder (filled by _decode_delegators below)


# ---- minimal ABI decoder for getAccountDelegatorsInfo(address) ----
def _w(data, byteoff):
    return int(data[byteoff * 2: byteoff * 2 + 64], 16)


def _addr(data, byteoff):
    return "0x" + data[byteoff * 2 + 24: byteoff * 2 + 64]


def decode_delegators(hexdata):
    """decode DelegateInfo[]: (address,(address,string[])[])[]  (byte-offset ABI)"""
    if not hexdata or hexdata == "0x":
        return []
    data = hexdata[2:]
    out = []
    arr = _w(data, 0)                       # byte offset to array data
    n = _w(data, arr)                       # number of delegates
    for i in range(n):
        t = arr + 32 + _w(data, arr + 32 + 32 * i)      # tuple start byte
        delegate = _addr(data, t)
        m = t + _w(data, t + 32)                        # modules array start byte
        mcount = _w(data, m)
        mods = []
        for j in range(mcount):
            u = m + 32 + _w(data, m + 32 + 32 * j)      # module tuple start
            module = _addr(data, u)
            q = u + _w(data, u + 32)                    # permissions array start
            pcount = _w(data, q)
            perms = []
            for k in range(pcount):
                s = q + 32 + _w(data, q + 32 + 32 * k)  # string start
                ln = _w(data, s)
                raw = data[(s + 32) * 2: (s + 32 + ln) * 2]
                perms.append(bytes.fromhex(raw).decode("utf-8", "replace"))
            mods.append({"module": module, "permissions": perms})
        out.append({"delegate": delegate, "modulesInfo": mods})
    return out


def main():
    # 1) event-derived currently-enabled set
    en = fetch_logs(T_ENABLED, "enabled_logs.json")
    dis = fetch_logs(T_DISABLED, "disabled_logs.json")
    events = []
    for x in en:
        events.append((num(x["blockNumber"]), num(x["logIndex"]), "enable", x["address"].lower()))
    for x in dis:
        events.append((num(x["blockNumber"]), num(x["logIndex"]), "disable", x["address"].lower()))
    events.sort()
    state = {}
    for _, _, kind, safe in events:
        state[safe] = kind
    current = sorted(s for s, k in state.items() if k == "enable")
    print(f"ever_enabled={len(state)} currently_enabled={len(current)}", flush=True)

    # token universe from curated + transfer discovery
    tokens = {a.lower() for a in CURATED.values()}
    if ESKEY:
        for s in current:
            q = {"chainid": "1", "module": "account", "action": "tokentx", "address": s,
                 "page": "1", "offset": "200", "sort": "desc", "apikey": ESKEY}
            d = http_json("https://api.etherscan.io/v2/api?" + urllib.parse.urlencode(q))
            rs = d.get("result") if isinstance(d.get("result"), list) else []
            for r in rs:
                if r.get("contractAddress"):
                    tokens.add(r["contractAddress"].lower())
            time.sleep(0.25)
    token_list = sorted(tokens)
    print("token universe:", len(token_list), flush=True)

    results = []
    for i, s in enumerate(current):
        rec = {"safe": s}
        # isModuleEnabled(module) selector 0x2d9ad53d
        mod_raw = rpc("eth_call", [{"to": s, "data": "0x2d9ad53d" + MODULE[2:].rjust(64, "0")}, "latest"])
        rec["module_enabled_now"] = (mod_raw == "0x" + "0" * 63 + "1")
        deleg_raw = rpc("eth_call", [{"to": PM, "data": "0x934cf4d1" + s[2:].rjust(64, "0")}, "latest"])
        rec["delegators"] = decode_delegators(deleg_raw)
        rec["module_grants"] = [
            {"delegate": d["delegate"], "permissions": m["permissions"]}
            for d in rec["delegators"] for m in d["modulesInfo"] if m["module"].lower() == MODULE
        ]
        res = rpc_batch([(t, BALOF + s[2:].rjust(64, "0")) for t in token_list])
        bals = {}
        for t, r in zip(token_list, res):
            if r and r != "0x":
                try:
                    v = int(r, 16)
                except Exception:
                    continue
                if v > 0:
                    bals[t] = v
        rec["token_balances_raw"] = bals
        native = rpc("eth_getBalance", [s, "latest"])
        rec["native_wei"] = int(native, 16) if native else None
        results.append(rec)
        print(f"[{i+1}/{len(current)}] {s} enabled={rec['module_enabled_now']} "
              f"grants={len(rec['module_grants'])} tokens={len(bals)}", flush=True)

    # module own balance
    module_native = rpc("eth_getBalance", [MODULE, "latest"])
    module_tokens = {}
    mres = rpc_batch([(t, BALOF + MODULE[2:].rjust(64, "0")) for t in token_list])
    for t, r in zip(token_list, mres):
        if r and r != "0x":
            v = int(r, 16)
            if v > 0:
                module_tokens[t] = v

    # 6) prices via DefiLlama (tokens + native ETH)
    price_ids = {t: f"ethereum:{t}" for t in token_list if t != "0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee"}
    prices = {}
    ids = list(price_ids.values())
    for i in range(0, len(ids), 100):
        chunk = ids[i:i + 100]
        d = http_json("https://coins.llama.fi/prices/current/" + ",".join(chunk))
        prices.update(d.get("coins", {}))
        time.sleep(0.3)
    eth_price = None
    d = http_json("https://coins.llama.fi/prices/current/ethereum:0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2")
    try:
        eth_price = d["coins"]["ethereum:0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2"]["price"]
    except Exception:
        pass

    def usd_for(token, raw):
        p = prices.get(f"ethereum:{token}")
        if not p:
            return None
        return raw / (10 ** p["decimals"]) * p["price"]

    total_usd = 0.0
    for rec in results:
        usd = 0.0
        unknown = []
        for t, raw in rec["token_balances_raw"].items():
            u = usd_for(t, raw)
            if u is None:
                unknown.append({"token": t, "raw": str(raw)})
            else:
                usd += u
        native_usd = (rec["native_wei"] or 0) / 1e18 * eth_price if eth_price else 0.0
        rec["token_usd"] = round(usd, 2)
        rec["native_usd"] = round(native_usd, 2)
        rec["unknown_tokens"] = unknown
        if rec["module_enabled_now"] and rec["module_grants"]:
            total_usd += usd + native_usd

    block = rpc("eth_blockNumber", [])
    summary = {
        "module": MODULE,
        "block": int(block, 16) if block else None,
        "eth_price_usd": eth_price,
        "ever_enabled": len(state),
        "currently_enabled": len(current),
        "enabled_and_permissioned": sum(
            1 for r in results if r["module_enabled_now"] and r["module_grants"]),
        "total_extractable_usd_estimate": round(total_usd, 2),
        "module_own_native_wei": int(module_native, 16) if module_native else None,
        "module_own_tokens": module_tokens,
    }
    json.dump(results, open(os.path.join(OUT, "enumeration.json"), "w"), indent=1)
    json.dump(summary, open(os.path.join(OUT, "summary.json"), "w"), indent=1)
    with open(os.path.join(OUT, "safes.csv"), "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["safe", "module_enabled", "delegates_with_module_permission",
                    "permissions", "native_wei", "tokens_usd_estimate"])
        for r in results:
            perms = sorted({p for g in r["module_grants"] for p in g["permissions"]})
            w.writerow([r["safe"], r["module_enabled_now"], len(r["module_grants"]), "|".join(perms),
                        r["native_wei"], r["token_usd"]])
    print(json.dumps(summary, indent=1), flush=True)


if __name__ == "__main__":
    main()
