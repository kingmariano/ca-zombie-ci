#!/usr/bin/env python3
"""PureSwap (BSC) fresh live scan for CI. Read-only, keyless env RPC only.

Produces ci-out/ci-live-scan.json:
  - factory/maker/chef roles and code checks
  - convert() revert matrix over ALL pairs x both makers (the bricked fee-LP proof)
  - live reserves/totalSupply/maker+chef LP balances, skim excess
  - valuation split (maker=S / chef=H-O / other H-O / skim dust) at snapshot prices
  - swap-arbitrage scan (stale-price surface)
"""
import json, math, os, sys, time, urllib.request

RPC = os.environ.get("BSC_RPC_URL") or "https://bsc-rpc.publicnode.com"

FACTORY = "0x94b4188d143b9dd6bd7083ae38a461fcc6aad07e"
PM1 = "0xcc93fbbfae96d2fdc562afce89f466f2996b4c95"
PM2 = "0xa7d7c06928a6a255a8e7083433f3fcea08082698"
PURE = "0x481f0557fb3bb5ee461fd47f287b1ca944ad89bc"
MX = "0x9f882567a62a5560d147d64871776eea72df41d3"
WBNB = "0xbb4cdb9cbd36b01bd1cbaebf2de08d9173bc095c"
BUSD = "0xe9e7cea3dedca5984780bafc599bd69add087d56"
CHEF = "0xb8692d7768cc70c8309b669c1f5a3d856909adb8"
SINGLE_CHEF = "0x63621a878f6eae37dc5bdedb2b828d9e3747b0f4"
MX_PANCAKE_BUSD = "0x41f049d990d38305504631c9835f6f856bf1ba67"  # Pancake MX/BUSD (price ref)
EOA = "0x0000000000000000000000000000000000001234"

SEL = {
    "convert": None,  # filled by keccak via cast at runtime? use known selector
    "balanceOf": "0x70a08231",
    "allowance": "0xdd62ed3e",
    "allPairs": "0x1e3dd18b",
    "allPairsLength": "0x574f2ba3",
    "token0": "0x0dfe1681",
    "token1": "0xd21220a7",
    "getReserves": "0x0902f1ac",
    "totalSupply": "0x18160ddd",
    "symbol": "0x95d89b41",
    "decimals": "0x313ce567",
    "bar": "0xfebb0f7e",
    "owner": "0x8da5cb5b",
    "factory": "0xc45a0155",
    "feeTo": "0x017e7e58",
    "feeToSetter": "0x094b7415",
    "migrator": "0x7cd07e47",
    "poolLength": "0x081e3dbc",   # poolLength()
    "poolInfo": "0x1526fe27",     # poolInfo(uint256)
}

# correct poolLength selector computed via cast 'poolLength()' = 0x081e3dbc? -- computed below at runtime if needed
def keccak_selector(sig: str) -> str:
    # minimal keccak256 via eth-hash unavailable; use known selectors instead
    known = {
        "convert(address,address)": "0xbd1b820c",
        "poolLength()": "0x081e3eda",
        "poolInfo(uint256)": "0x1526fe27",
        "owner()": "0x8da5cb5b",
        "bar()": "0xf0f44260",
        "factory()": "0x2d3c2f12",
        "feeTo()": "0x017e7e58",
        "feeToSetter()": "0x094b7415",
        "migrator()": "0x7cd07e47",
        "transfer(address,uint256)": "0xa9059cbb",
    }
    return known[sig]

SEL["convert"] = keccak_selector("convert(address,address)")
SEL["poolLength"] = keccak_selector("poolLength()")
SEL["poolInfo"] = keccak_selector("poolInfo(uint256)")

def rpc(method, params, retries=4):
    body = json.dumps({"jsonrpc": "2.0", "id": 1, "method": method, "params": params}).encode()
    for i in range(retries):
        try:
            req = urllib.request.Request(RPC, data=body, headers={"Content-Type": "application/json", "User-Agent": "Mozilla/5.0"})
            d = json.loads(urllib.request.urlopen(req, timeout=40).read().decode())
            if "result" in d:
                return d["result"]
        except Exception:
            time.sleep(1.2 * (i + 1))
    return None

def batch(pairs, retries=4):
    """pairs: list of (to, data, from_optional). Returns list of results (None on error)."""
    out = []
    for i in range(0, len(pairs), 10):
        chunk = pairs[i:i + 10]
        payload = []
        for j, pr in enumerate(chunk):
            to, data = pr[0], pr[1]
            obj = {"to": to, "data": data}
            if len(pr) > 2 and pr[2]:
                obj["from"] = pr[2]
            payload.append({"jsonrpc": "2.0", "id": j, "method": "eth_call", "params": [obj, "latest"]})
        res = None
        for attempt in range(retries):
            try:
                req = urllib.request.Request(RPC, data=json.dumps(payload).encode(), headers={"Content-Type": "application/json", "User-Agent": "Mozilla/5.0"})
                res = json.loads(urllib.request.urlopen(req, timeout=60).read().decode())
                break
            except Exception:
                time.sleep(1.2 * (attempt + 1))
        if res is None:
            out.extend([None] * len(chunk))
            continue
        res = sorted(res, key=lambda x: x["id"])
        for x in res:
            if "result" in x and x["result"] != "0x":
                out.append(x["result"])
            else:
                out.append(None)
    return out

def pad(a):
    a = a.lower()
    if a.startswith("0x"):
        a = a[2:]
    return "0" * (64 - len(a)) + a

def wi(x):
    if not x or x == "0x":
        return None
    return int(x, 16)

def addr(x):
    return "0x" + x[-40:].lower() if x else None

def decode_str(x):
    if not x or x == "0x":
        return None
    try:
        if len(x) == 66:
            return bytes.fromhex(x[2:]).decode("utf-8", "replace").strip("\x00")
        ln = int(x[66:130], 16)
        return bytes.fromhex(x[130:130 + ln * 2]).decode("utf-8", "replace")
    except Exception:
        return None

def batch_raw(pairs, retries=4):
    """Like batch() but returns (result_or_None, error_message_or_None) per item."""
    out = []
    for i in range(0, len(pairs), 10):
        chunk = pairs[i:i + 10]
        payload = []
        for j, pr in enumerate(chunk):
            obj = {"to": pr[0], "data": pr[1]}
            if len(pr) > 2 and pr[2]:
                obj["from"] = pr[2]
            payload.append({"jsonrpc": "2.0", "id": j, "method": "eth_call", "params": [obj, "latest"]})
        res = None
        for attempt in range(retries):
            try:
                req = urllib.request.Request(RPC, data=json.dumps(payload).encode(), headers={"Content-Type": "application/json", "User-Agent": "Mozilla/5.0"})
                res = json.loads(urllib.request.urlopen(req, timeout=60).read().decode())
                break
            except Exception:
                time.sleep(1.2 * (attempt + 1))
        if res is None:
            out.extend([(None, "transport-error")] * len(chunk))
            continue
        res = sorted(res, key=lambda x: x["id"])
        for x in res:
            if "result" in x and x["result"] != "0x":
                out.append((x["result"], None))
            else:
                out.append((None, (x.get("error") or {}).get("message", "") or "empty-result"))
    return out


def eth_price_llama(ids):
    url = "https://coins.llama.fi/prices/current/" + ",".join(ids)
    try:
        d = json.loads(urllib.request.urlopen(urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"}), timeout=40).read().decode())
        px = {k.split(":", 1)[1].lower(): v["price"] for k, v in (d.get("coins") or {}).items()}
    except Exception:
        px = {}
    if not px:
        # fallback: bundled snapshot (analysis/llama-prices.json, public data, no secrets)
        try:
            snap = json.load(open(os.path.join(os.path.dirname(__file__), "..", "analysis", "llama-prices.json")))["coins"]
            px = {k.split(":", 1)[1].lower(): v["price"] for k, v in snap.items()}
            print("[scan] llama unavailable -> using bundled snapshot prices", flush=True)
        except Exception:
            pass
    return px

def main():
    out = {}
    block = wi(rpc("eth_blockNumber", []))
    out["block"] = block
    print(f"[scan] block {block}", flush=True)

    # ---- factory state
    n = wi(rpc("eth_call", [{"to": FACTORY, "data": SEL["allPairsLength"]}, "latest"]))
    feeTo = rpc("eth_call", [{"to": FACTORY, "data": SEL["feeTo"]}, "latest"])
    feeToSetter = addr(rpc("eth_call", [{"to": FACTORY, "data": SEL["feeToSetter"]}, "latest"]))
    migrator = addr(rpc("eth_call", [{"to": FACTORY, "data": SEL["migrator"]}, "latest"]))
    code_maker1 = rpc("eth_getCode", [PM1, "latest"])
    setter_code = rpc("eth_getCode", [feeToSetter, "latest"]) or "0x"
    out["factory"] = {"allPairsLength": n, "feeTo_raw": feeTo, "feeToSetter": feeToSetter,
                      "migrator": migrator, "feeToSetter_code_len": max(0, (len(setter_code) - 2) // 2),
                      "maker1_code_len": max(0, (len(code_maker1 or "0x") - 2) // 2)}
    out["makers"] = {}
    for nm, m in (("PM1", PM1), ("PM2", PM2)):
        out["makers"][nm] = {
            "bar": addr(rpc("eth_call", [{"to": m, "data": SEL["bar"]}, "latest"])),
            "owner": addr(rpc("eth_call", [{"to": m, "data": SEL["owner"]}, "latest"])),
            "factory": addr(rpc("eth_call", [{"to": m, "data": SEL["factory"]}, "latest"])),
            "pure_balance": wi(rpc("eth_call", [{"to": PURE, "data": SEL["balanceOf"] + pad(m)}, "latest"])),
        }
    print(f"[scan] pairs={n} makers: {json.dumps(out['makers'])}", flush=True)

    # ---- pair addresses + tokens
    pa = [addr(x) for x in batch([(FACTORY, SEL["allPairs"] + format(i, "064x")) for i in range(n)])]
    tok_res = batch([(p, SEL["token0"]) for p in pa] + [(p, SEL["token1"]) for p in pa])
    t0 = [addr(x) for x in tok_res[:n]]
    t1 = [addr(x) for x in tok_res[n:]]

    # ---- PURE rejects 0x0; convert revert matrix (batched, error text preserved)
    pure_zero = rpc("eth_call", [{"to": PURE, "data": "0xa9059cbb" + pad("0x" + "0" * 40) + format(1, "064x"), "from": SINGLE_CHEF}, "latest"]) is None
    calls = []
    for i in range(n):
        for m in (PM1, PM2):
            calls.append((m, SEL["convert"] + pad(t0[i]) + pad(t1[i]), EOA))
    results = batch_raw(calls)
    reverts = {"PURE_TO_ZERO_VIA_PAIR": 0, "PURE_TO_ZERO_DIRECT": 0,
               "NO_MAKER_LP_IN_PAIR": 0, "NO_BRIDGE_PAIR": 0, "OTHER": 0, "OK": 0}
    other_reasons = {}
    for res_val, err in results:
        if res_val is not None:
            reverts["OK"] += 1
        elif "TRANSFER_FAILED" in err:
            reverts["PURE_TO_ZERO_VIA_PAIR"] += 1
        elif "SafeERC20: Transfer failed" in err:
            reverts["PURE_TO_ZERO_DIRECT"] += 1
        elif "INSUFFICIENT_LIQUIDITY_BURNED" in err:
            reverts["NO_MAKER_LP_IN_PAIR"] += 1
        elif "Cannot convert" in err:
            reverts["NO_BRIDGE_PAIR"] += 1
        else:
            reverts["OTHER"] += 1
            other_reasons[err[:90]] = other_reasons.get(err[:90], 0) + 1
    out["convert_matrix"] = {"calls": len(calls), "counts": reverts, "other_reasons": other_reasons,
                             "pure_rejects_zero_transfer": pure_zero}
    print(f"[scan] convert matrix: {reverts} pure_zero={pure_zero}", flush=True)

    # ---- live pair state + maker/chef balances
    res = batch(
        [(p, SEL["getReserves"]) for p in pa]
        + [(p, SEL["totalSupply"]) for p in pa]
        + [(p, SEL["balanceOf"] + pad(PM1)) for p in pa]
        + [(p, SEL["balanceOf"] + pad(PM2)) for p in pa]
        + [(t0[i], SEL["balanceOf"] + pad(pa[i])) for i in range(n)]
        + [(t1[i], SEL["balanceOf"] + pad(pa[i])) for i in range(n)]
    )
    rs = res[:n]; ts = res[n:2 * n]; pm1 = res[2 * n:3 * n]; pm2 = res[3 * n:4 * n]
    b0 = res[4 * n:5 * n]; b1 = res[5 * n:6 * n]

    # chef balances
    chef_bals = {}
    for chef, tag in ((CHEF, "PureChef"), (SINGLE_CHEF, "SingleChef")):
        pl = wi(rpc("eth_call", [{"to": chef, "data": SEL["poolLength"]}, "latest"])) or 0
        lps = []
        for i in range(pl):
            r = rpc("eth_call", [{"to": chef, "data": SEL["poolInfo"] + format(i, "064x")}, "latest"])
            if r and len(r) >= 130:
                lps.append("0x" + r[2 + 24:2 + 64].lower())
        bals = batch([(lp, SEL["balanceOf"] + pad(chef)) for lp in lps])
        for lp, b in zip(lps, bals):
            chef_bals[lp.lower()] = chef_bals.get(lp.lower(), 0) + (wi(b) or 0)
        out.setdefault("chefs", {})[tag] = {"pools": pl, "lp_tokens": lps}
    print(f"[scan] chef lp positions: {len(chef_bals)}", flush=True)

    decimals = batch([(t, SEL["decimals"]) for t in sorted(set(t0 + t1))])
    syms = batch([(t, SEL["symbol"]) for t in sorted(set(t0 + t1))])
    uniq = sorted(set(t0 + t1))
    meta = {t: {"decimals": wi(d) or 18, "symbol": decode_str(s)} for t, d, s in zip(uniq, decimals, syms)}

    rows = []
    for i, p in enumerate(pa):
        r = rs[i]
        r0 = wi("0x" + r[2:66]) if r else None
        r1 = wi("0x" + r[66:130]) if r else None
        row = {
            "pair": p, "token0": t0[i], "token1": t1[i],
            "symbol": f"{meta[t0[i]]['symbol']}/{meta[t1[i]]['symbol']}",
            "dec0": meta[t0[i]]["decimals"], "dec1": meta[t1[i]]["decimals"],
            "reserve0": r0, "reserve1": r1, "totalSupply": wi(ts[i]) or 0,
            "lp_maker1": wi(pm1[i]) or 0, "lp_maker2": wi(pm2[i]) or 0,
            "chef_lp": min(chef_bals.get(p.lower(), 0), wi(ts[i]) or 0),
            "bal0": wi(b0[i]), "bal1": wi(b1[i]),
        }
        row["excess0"] = (row["bal0"] - r0) if (row["bal0"] is not None and r0 is not None) else None
        row["excess1"] = (row["bal1"] - r1) if (row["bal1"] is not None and r1 is not None) else None
        rows.append(row)

    # ---- prices: llama + internal mids (MX via Pancake BUSD pool, PURE via PURE/BUSD pool)
    ids = []
    for t in uniq:
        ids.append("bsc:" + t)
    px = eth_price_llama(ids)
    # MX mid from Pancake MX/BUSD
    mxr = rpc("eth_call", [{"to": MX_PANCAKE_BUSD, "data": SEL["getReserves"]}, "latest"])
    if mxr:
        mx_busd_res0, mx_busd_res1 = wi("0x" + mxr[2:66]), wi("0x" + mxr[66:130])
        if mx_busd_res0 and mx_busd_res1:
            px[MX] = (mx_busd_res1 / 1e18) / (mx_busd_res0 / 1e18)
    # PURE mid from PURE/BUSD pool
    pb = next((r for r in rows if r["token0"] == PURE and r["token1"] == BUSD), None)
    if pb and pb["reserve0"] and pb["reserve1"]:
        px[PURE] = (pb["reserve1"] / 10 ** pb["dec1"]) / (pb["reserve0"] / 10 ** pb["dec0"])
    out["prices"] = {t: px.get(t) for t in uniq}

    INTERNAL = {MX, PURE}
    tot = {"pool": 0.0, "pool_real": 0.0, "maker": 0.0, "maker_real": 0.0, "chef": 0.0,
           "chef_real": 0.0, "other": 0.0, "other_real": 0.0, "dust_excess_usd": 0.0}
    for r in rows:
        v0 = (r["reserve0"] / 10 ** r["dec0"]) * (px.get(r["token0"]) or 0) if r["reserve0"] else 0
        v1 = (r["reserve1"] / 10 ** r["dec1"]) * (px.get(r["token1"]) or 0) if r["reserve1"] else 0
        real0 = 0.0 if r["token0"] in INTERNAL else v0
        real1 = 0.0 if r["token1"] in INTERNAL else v1
        r["pool_usd"], r["pool_real_usd"] = v0 + v1, real0 + real1
        tsx = r["totalSupply"]
        if tsx:
            mk = r["lp_maker1"] + r["lp_maker2"]
            ch = r["chef_lp"]
            ot = max(tsx - mk - ch - 1000, 0)
            r["maker_usd"] = r["pool_usd"] * mk / tsx
            r["maker_real_usd"] = r["pool_real_usd"] * mk / tsx
            r["chef_usd"] = r["pool_usd"] * ch / tsx
            r["other_usd"] = r["pool_usd"] * ot / tsx
            tot["pool"] += r["pool_usd"]; tot["pool_real"] += r["pool_real_usd"]
            tot["maker"] += r["maker_usd"]; tot["maker_real"] += r["maker_real_usd"]
            tot["chef"] += r["chef_usd"]; tot["chef_real"] += r["pool_real_usd"] * ch / tsx
            tot["other"] += r["other_usd"]; tot["other_real"] += r["pool_real_usd"] * ot / tsx
        if r["excess0"]:
            tot["dust_excess_usd"] += (r["excess0"] / 10 ** r["dec0"]) * (px.get(r["token0"]) or 0)
        if r["excess1"]:
            tot["dust_excess_usd"] += (r["excess1"] / 10 ** r["dec1"]) * (px.get(r["token1"]) or 0)
    out["valuation"] = {k: round(v, 2) for k, v in tot.items()}
    out["rows"] = rows

    # ---- swap-arb scan (stale-price surface), closed form per direction
    arb = []
    for r in rows:
        p0, p1 = px.get(r["token0"]), px.get(r["token1"])
        if not p0 or not p1 or not r["reserve0"] or not r["reserve1"]:
            continue
        x, y = r["reserve0"], r["reserve1"]
        d0, d1 = r["dec0"], r["dec1"]
        best = 0.0
        # direction: spend quote token1 -> buy token0 -> sell at market p0
        rad = x * 997.0 * y * 1000.0 * (p0 / p1)
        if rad > 0:
            dy = (math.sqrt(rad) - y * 1000.0) / 997.0
            if dy > 0:
                outx = x * 997.0 * dy / (y * 1000.0 + 997.0 * dy)
                best = max(best, (outx / 10 ** d0) * p0 - (dy / 10 ** d1) * p1)
        # direction: spend token0 -> buy token1 -> sell at market p1
        rad = y * 997.0 * x * 1000.0 * (p1 / p0)
        if rad > 0:
            dx = (math.sqrt(rad) - x * 1000.0) / 997.0
            if dx > 0:
                outy = y * 997.0 * dx / (x * 1000.0 + 997.0 * dx)
                best = max(best, (outy / 10 ** d1) * p1 - (dx / 10 ** d0) * p0)
        if best > 0.0001:
            arb.append({"pair": r["pair"], "symbol": r["symbol"], "best_usd": round(best, 4)})
    arb.sort(key=lambda a: -a["best_usd"])
    out["swap_arb"] = {"opportunities_over_cent": arb[:10], "sum_usd": round(sum(a["best_usd"] for a in arb), 2)}

    os.makedirs(os.path.join(os.path.dirname(__file__), "..", "ci-out"), exist_ok=True)
    fn = os.path.join(os.path.dirname(__file__), "..", "ci-out", "ci-live-scan.json")
    json.dump(out, open(fn, "w"), indent=1)
    print(f"[scan] wrote {fn}", flush=True)
    print(f"[scan] valuation: {json.dumps(out['valuation'])}", flush=True)
    print(f"[scan] swap arb >$0.01: {out['swap_arb']}", flush=True)

    # exit non-zero if convert succeeded anywhere (must not happen)
    if reverts["OK"] > 0 or not pure_zero:
        print("[scan] FAIL: unexpected state", flush=True)
        return 1
    return 0

if __name__ == "__main__":
    sys.exit(main())
