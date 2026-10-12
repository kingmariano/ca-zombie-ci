#!/usr/bin/env python3
"""
PinkSwap (BSC) L2 Phase-2 CI job — live-state + gate simulations (read-only).

Outputs ci-out/live_state.json and ci-out/SUMMARY.txt.
No secrets or RPC URLs are written. Uses BSC_RPC_URL from env (CI secret) with
public fallbacks; the URL itself is never printed or stored.
"""
import json, os, sys, time
import urllib.request, urllib.error
from concurrent.futures import ThreadPoolExecutor

BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(BASE, "ci-out")
UA = {"User-Agent": "Mozilla/5.0 (X11; Linux x86_64) zombie-ci"}

RPC_ENV = os.environ.get("BSC_RPC_URL")
RPCS = ([RPC_ENV] if RPC_ENV else []) + [
    "https://bsc-rpc.publicnode.com",
    "https://bsc.drpc.org",
    "https://1rpc.io/bnb",
]
FACTORY = "0x7d2ce25c28334e40f37b2a068ec8d5a59f11ea54"
MASTERCHEF = "0xe981676633dcf0256aa512f4923a7e8da180c595"
PINK = "0x702b3f41772e321aaccdea91e1fcef682d21125d"
FEE_TO = "0xcf6a864b0d705242bf1b916bf8c097ae503bc4d5"
PINKLOCK2 = "0x407993575c91ce7643a4d4ccacc9a98c36ee1bbe"   # PinkLock02 (non-upgradeable)
PINKLOCK1 = "0x7ee058420e5937496f5a2096f04caa7721cf70cc"   # PinkLock v1 (UUPS, owner renounced)
ATTACKER = "0x00000000000000000000000000000000deadbeef"

SEL = {
    "allPairsLength()": "0x574f2ba3",
    "allPairs(uint256)": "0x1e3dd18b",
    "token0()": "0x0dfe1681",
    "token1()": "0xd21220a7",
    "getReserves()": "0x0902f1ac",
    "totalSupply()": "0x18160ddd",
    "decimals()": "0x313ce567",
    "symbol()": "0x95d89b41",
    "balanceOf(address)": "0x70a08231",
    "feeTo()": "0x017e7e58",
    "feeToSetter()": "0x094b7415",
    "owner()": "0x8da5cb5b",
    "migrator()": "0x7cd07e47",
    "poolLength()": "0x081e3eda",
    "pinksPerBlock()": "0x4ea81f2b",
    "totalPinksReward()": "0xee6c2536",
    "totalAllocPoint()": "0x17caf6f1",
    "poolInfo(uint256)": "0x1526fe27",
    "mint(address,uint256)": "0x40c10f19",
    "deposit(uint256,uint256)": "0xe2bbb158",
    "updatePool(uint256)": "0x51eb05a6",
    "migrate(uint256)": "0x454b0608",
    "unlock(uint256)": "0x6198e339",
    "getTotalLockCount()": "0xfd981c66",
    "totalLockCountForToken(address)": "0xe3676f88",
    "getLocksForToken(address,uint256,uint256)": "0x332f26d7",
}

def _urls():
    return list(dict.fromkeys(RPCS))

def rpc_raw(method, params, timeout=30, tries=3):
    """Return the full JSON-RPC response (result or error) without raising on revert."""
    last = None
    for attempt in range(tries):
        for url in _urls():
            try:
                body = json.dumps({"jsonrpc": "2.0", "id": 1, "method": method, "params": params}).encode()
                req = urllib.request.Request(url, data=body, headers={**UA, "Content-Type": "application/json"})
                with urllib.request.urlopen(req, timeout=timeout) as r:
                    d = json.loads(r.read().decode())
                if isinstance(d, dict) and ("result" in d or "error" in d):
                    return d
                last = str(d)[:200]
            except Exception as e:
                last = type(e).__name__
        time.sleep(1.0 * (attempt + 1))
    return {"error": {"message": f"rpc-fail:{last}"}}

def rpc(method, params, timeout=30, tries=3):
    d = rpc_raw(method, params, timeout=timeout, tries=tries)
    if "result" in d:
        return d["result"]
    raise RuntimeError(f"rpc fail {method}: {str(d.get('error'))[:200]}")

def batch(calls, timeout=90, tries=3):
    payload = [{"jsonrpc": "2.0", "id": i, "method": m, "params": p} for i, (m, p) in enumerate(calls)]
    body = json.dumps(payload).encode()
    last = None
    for attempt in range(tries):
        for url in _urls():
            try:
                req = urllib.request.Request(url, data=body, headers={**UA, "Content-Type": "application/json"})
                with urllib.request.urlopen(req, timeout=timeout) as r:
                    d = json.loads(r.read().decode())
                if isinstance(d, list):
                    out = [None] * len(calls)
                    for item in d:
                        i = item.get("id")
                        if isinstance(i, int) and 0 <= i < len(calls):
                            out[i] = item.get("result", {"error": item.get("error")})
                    return out
                last = str(d)[:200]
            except Exception as e:
                last = type(e).__name__
        time.sleep(1.0 * (attempt + 1))
    raise RuntimeError(f"batch fail: {last}")

def hexint(h):
    try: return int(h, 16)
    except Exception: return None

def dec_addr(h):
    if not h or not isinstance(h, str) or len(h) < 42: return None
    a = "0x" + h[-40:]
    return a if a != "0x" + "0" * 40 else None

def dec_addr_any(h):
    if not h or not isinstance(h, str) or len(h) < 42: return None
    return "0x" + h[-40:]

def dec_str(h):
    try:
        b = bytes.fromhex(h[2:])
        if len(b) >= 64:
            ln = int.from_bytes(b[32:64], "big")
            return b[64:64+ln].decode("utf-8", "replace")
        return b.rstrip(b"\x00").decode("utf-8", "replace")
    except Exception:
        return None

def enc_uint(n): return hex(n)[2:].rjust(64, "0")
def enc_addr(a): return a.lower().replace("0x", "").rjust(64, "0")

def call(to, data, frm=None, tag="latest"):
    obj = {"to": to, "data": data}
    if frm: obj["from"] = frm
    return rpc("eth_call", [obj, tag])

def call_ok(to, data, frm=None):
    """returns (ok, result_or_error_reason)"""
    obj = {"to": to, "data": data}
    if frm: obj["from"] = frm
    d = rpc_raw("eth_call", [obj, "latest"])
    if "result" in d:
        return True, d["result"]
    err = d.get("error") or {}
    return False, str(err.get("message") or err)[:220]

def llama_prices(addrs):
    out = {}
    addrs = list(dict.fromkeys(a.lower() for a in addrs if a and a.startswith("0x")))
    for i in range(0, len(addrs), 80):
        chunk = addrs[i:i+80]
        try:
            url = "https://coins.llama.fi/prices/current/" + ",".join(f"bsc:{a}" for a in chunk)
            req = urllib.request.Request(url, headers=UA)
            with urllib.request.urlopen(req, timeout=30) as r:
                d = json.loads(r.read().decode())
            for k, v in (d.get("coins") or {}).items():
                a = k.split(":")[-1].lower()
                if v.get("price") is not None:
                    out[a] = {"price": float(v["price"]), "symbol": v.get("symbol")}
        except Exception:
            pass
    return out

def main():
    os.makedirs(OUT, exist_ok=True)
    blk = hexint(rpc("eth_blockNumber", []))
    print("block", blk, flush=True)
    res = {"block": blk, "chain": "bsc", "generated_utc": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())}

    # ---- factory ----
    fac = {"address": FACTORY}
    fac["code_len"] = len(rpc("eth_getCode", [FACTORY, "latest"])) // 2
    for name, sel in (("feeTo", SEL["feeTo()"]), ("feeToSetter", SEL["feeToSetter()"])):
        ok, r = call_ok(FACTORY, sel)
        fac[name] = dec_addr(r) if ok else f"revert"
    fac["feeTo_code_len"] = len(rpc("eth_getCode", [fac.get("feeTo") or FEE_TO, "latest"])) // 2
    n = hexint(call(FACTORY, SEL["allPairsLength()"]))
    fac["n_pairs"] = n
    res["factory"] = fac
    print("factory", fac, flush=True)

    # ---- pairs ----
    pairs = []
    for i in range(0, n, 100):
        chunk = list(range(i, min(i + 100, n)))
        rs = batch([("eth_call", [{"to": FACTORY, "data": SEL["allPairs(uint256)"] + enc_uint(x)}, "latest"]) for x in chunk])
        for r in rs:
            a = dec_addr(r)
            if a: pairs.append(a)
    pairs = list(dict.fromkeys(pairs))

    recs = []
    for i in range(0, len(pairs), 25):
        chunk = pairs[i:i+25]
        calls = []
        for p in chunk: calls.append(("eth_call", [{"to": p, "data": SEL["token0()"]}, "latest"]))
        for p in chunk: calls.append(("eth_call", [{"to": p, "data": SEL["token1()"]}, "latest"]))
        for p in chunk: calls.append(("eth_call", [{"to": p, "data": SEL["getReserves()"]}, "latest"]))
        for p in chunk: calls.append(("eth_call", [{"to": p, "data": SEL["totalSupply()"]}, "latest"]))
        rs = batch(calls)
        L = len(chunk)
        for j, p in enumerate(chunk):
            t0 = dec_addr(rs[j]); t1 = dec_addr(rs[L + j])
            rr = rs[2 * L + j] if isinstance(rs[2 * L + j], str) else None
            ts = hexint(rs[3 * L + j]) if isinstance(rs[3 * L + j], str) else None
            if not (t0 and t1 and rr and len(rr) >= 130):
                recs.append({"pair": p, "error": "read-failed"}); continue
            recs.append({"pair": p, "token0": t0, "token1": t1,
                         "r0": int(rr[2:66], 16), "r1": int(rr[66:130], 16), "lp_supply": ts})
    print("pairs read", len(recs), flush=True)

    toks = []
    for r in recs:
        if "token0" in r: toks += [r["token0"], r["token1"]]
    toks = list(dict.fromkeys(toks))
    meta = {}
    for i in range(0, len(toks), 50):
        chunk = toks[i:i+50]
        rs = batch([("eth_call", [{"to": t, "data": SEL["decimals()"]}, "latest"]) for t in chunk]
                   + [("eth_call", [{"to": t, "data": SEL["symbol()"]}, "latest"]) for t in chunk])
        for j, t in enumerate(chunk):
            d = hexint(rs[j]) if isinstance(rs[j], str) else None
            meta[t] = {"decimals": d if (d is not None and 0 <= d <= 36) else 18,
                       "symbol": (dec_str(rs[len(chunk) + j]) or "?")[:24] if isinstance(rs[len(chunk) + j], str) else "?"}

    # balances of pair for its own tokens + LP balances of infra addresses
    infra = {"feeTo": FEE_TO, "masterchef": MASTERCHEF, "pinklock2": PINKLOCK2, "pinklock1": PINKLOCK1,
             "zero": "0x0000000000000000000000000000000000000000",
             "dead": "0x000000000000000000000000000000000000dEaD"}
    live = [r for r in recs if "token0" in r]
    for i in range(0, len(live), 40):
        chunk = live[i:i+40]
        calls = []
        for r in chunk: calls.append(("eth_call", [{"to": r["token0"], "data": SEL["balanceOf(address)"] + enc_addr(r["pair"])}, "latest"]))
        for r in chunk: calls.append(("eth_call", [{"to": r["token1"], "data": SEL["balanceOf(address)"] + enc_addr(r["pair"])}, "latest"]))
        for r in chunk:
            for iname, iaddr in infra.items():
                calls.append(("eth_call", [{"to": r["pair"], "data": SEL["balanceOf(address)"] + enc_addr(iaddr)}, "latest"]))
        rs = batch(calls, timeout=120)
        L = len(chunk); N = len(infra)
        for j, r in enumerate(chunk):
            r["b0"] = hexint(rs[j]) if isinstance(rs[j], str) else None
            r["b1"] = hexint(rs[L + j]) if isinstance(rs[L + j], str) else None
            r["lp_infra"] = {}
            for k, iname in enumerate(infra):
                v = hexint(rs[2 * L + j * N + k]) if isinstance(rs[2 * L + j * N + k], str) else None
                if v: r["lp_infra"][iname] = v

    prices = llama_prices(toks)
    tot_reserve = tot_excess = tot_feeTo = 0.0
    excess_rows = []
    for r in live:
        t0, t1 = r["token0"], r["token1"]
        d0, d1 = meta[t0]["decimals"], meta[t1]["decimals"]
        p0 = prices.get(t0, {}).get("price", 0.0)
        p1 = prices.get(t1, {}).get("price", 0.0)
        r["sym0"], r["sym1"] = meta[t0]["symbol"], meta[t1]["symbol"]
        r["reserve_usd"] = round((r["r0"] / 10**d0) * p0 + (r["r1"] / 10**d1) * p1, 2)
        ex0 = max(0, (r.get("b0") or 0) - r["r0"]); ex1 = max(0, (r.get("b1") or 0) - r["r1"])
        r["excess0"], r["excess1"] = ex0, ex1
        r["excess_usd"] = round((ex0 / 10**d0) * p0 + (ex1 / 10**d1) * p1, 2)
        lp = r.get("lp_supply") or 0
        fe = r["lp_infra"].get("feeTo", 0)
        r["feeTo_share"] = round(fe / lp, 8) if lp else 0
        r["feeTo_value_usd"] = round(r["feeTo_share"] * r["reserve_usd"], 2)
        tot_reserve += r["reserve_usd"]; tot_excess += r["excess_usd"]; tot_feeTo += r["feeTo_value_usd"]
        if ex0 > 0 or ex1 > 0:
            excess_rows.append({"pair": r["pair"], "sym0": r["sym0"], "sym1": r["sym1"],
                                "excess0": ex0 / 10**d0, "excess1": ex1 / 10**d1, "excess_usd": r["excess_usd"]})
    excess_rows.sort(key=lambda x: -x["excess_usd"])
    res["pairs"] = [{"pair": r["pair"], "sym0": r.get("sym0"), "sym1": r.get("sym1"),
                     "reserve_usd": r.get("reserve_usd"), "excess_usd": r.get("excess_usd"),
                     "lp_supply": r.get("lp_supply"), "lp_infra": r.get("lp_infra"),
                     "feeTo_value_usd": r.get("feeTo_value_usd"), "error": r.get("error")} for r in recs]
    res["totals"] = {"n_pairs": len(recs), "reserves_usd": round(tot_reserve, 2),
                     "skim_excess_usd_at_llama_prices": round(tot_excess, 2),
                     "feeTo_lp_value_usd": round(tot_feeTo, 2)}
    res["excess_pairs"] = excess_rows
    print("totals", res["totals"], flush=True)

    # ---- masterchef ----
    mc = {"address": MASTERCHEF}
    for name, sel in (("owner", SEL["owner()"]), ("migrator", SEL["migrator()"])):
        ok, r = call_ok(MASTERCHEF, sel)
        mc[name] = dec_addr_any(r) if ok else None
    mc["owner_code_bytes"] = (len(rpc("eth_getCode", [mc["owner"] or "0x" + "0" * 40, "latest"])) - 2) // 2 if mc.get("owner") else None
    for name, sel in (("poolLength", SEL["poolLength()"]), ("pinksPerBlock", SEL["pinksPerBlock()"]),
                      ("totalPinksReward", SEL["totalPinksReward()"]), ("totalAllocPoint", SEL["totalAllocPoint()"])):
        ok, r = call_ok(MASTERCHEF, sel)
        mc[name] = str(hexint(r)) if ok and isinstance(r, str) else None
    pl = int(mc.get("poolLength") or 0)
    pools = []
    for i in range(pl):
        ok, r = call_ok(MASTERCHEF, SEL["poolInfo(uint256)"] + enc_uint(i))
        if not ok or not isinstance(r, str) or len(r) < 258:
            pools.append({"pid": i, "error": "read-failed"}); continue
        lp_token = dec_addr(r[2:66]); alloc = hexint(r[66:130]); last = hexint(r[130:194])
        bal = hexint(call(lp_token, SEL["balanceOf(address)"] + enc_addr(MASTERCHEF)))
        pools.append({"pid": i, "lp_token": lp_token, "allocPoint": alloc, "lastRewardBlock": last,
                      "lp_balance": bal})
    mc["pools"] = pools
    mc["pink_balance"] = hexint(call(PINK, SEL["balanceOf(address)"] + enc_addr(MASTERCHEF)))
    mc["pink_totalSupply"] = hexint(call(PINK, SEL["totalSupply()"]))
    mc["deposits_blocked"] = (mc["pink_totalSupply"] or 0) >= int(mc.get("totalPinksReward") or 0)
    res["masterchef"] = mc

    # ---- pink token ----
    pink = {"address": PINK}
    ok, r = call_ok(PINK, SEL["owner()"]); pink["owner"] = dec_addr(r) if ok else None
    pink["totalSupply"] = hexint(call(PINK, SEL["totalSupply()"]))
    res["pink"] = pink

    # ---- gate simulations (read-only eth_call with from=attacker) ----
    sims = {}
    # mint PINK from attacker
    data = SEL["mint(address,uint256)"] + enc_addr(ATTACKER) + enc_uint(10**18)
    ok, r = call_ok(PINK, data, frm=ATTACKER)
    sims["pink_mint_from_attacker"] = {"ok": ok, "err": None if ok else r}
    # masterchef deposit from attacker
    data = SEL["deposit(uint256,uint256)"] + enc_uint(0) + enc_uint(1)
    ok, r = call_ok(MASTERCHEF, data, frm=ATTACKER)
    sims["masterchef_deposit_from_attacker"] = {"ok": ok, "err": None if ok else r}
    # masterchef migrate
    data = SEL["migrate(uint256)"] + enc_uint(0)
    ok, r = call_ok(MASTERCHEF, data, frm=ATTACKER)
    sims["masterchef_migrate_from_attacker"] = {"ok": ok, "err": None if ok else r}
    # pinklock02 unlock of MEV/WBNB lock (id 1112062)
    data = SEL["unlock(uint256)"] + enc_uint(1112062)
    ok, r = call_ok(PINKLOCK2, data, frm=ATTACKER)
    sims["pinklock2_unlock_mev_lock_from_attacker"] = {"ok": ok, "err": None if ok else r}
    # skim top pair from attacker (should succeed - the mechanism)
    ok, r = call_ok("0xb9efbd2bb41f7a2136bf2b21e8b26641651adef9",
                    "0xbc25cf77" + enc_addr(ATTACKER), frm=ATTACKER)
    sims["skim_top_pair_from_attacker"] = {"ok": ok, "err": None if ok else r}
    res["gate_simulations"] = sims
    print("sims", json.dumps(sims)[:600], flush=True)

    # ---- lockers ----
    locks = {"pinklock2": {"address": PINKLOCK2}, "pinklock1": {"address": PINKLOCK1}}
    for lname, laddr in (("pinklock2", PINKLOCK2), ("pinklock1", PINKLOCK1)):
        ok, r = call_ok(laddr, SEL["owner()"])
        locks[lname]["owner"] = dec_addr_any(r) if ok else None
        ok, r = call_ok(laddr, SEL["getTotalLockCount()"])
        locks[lname]["total_locks"] = hexint(r) if ok and isinstance(r, str) else None
    import datetime
    # PinkLock02 (v2) returns Lock[] of *dynamic* structs (has description string -> per-element offsets).
    # PinkLock v1 returns Lock[] of *static* structs: length then inline {id, token, owner, amount, lockDate, unlockDate}.
    for lname, laddr in (("pinklock2", PINKLOCK2), ("pinklock1", PINKLOCK1)):
        static_layout = (lname == "pinklock1")
        for pair, label in (("0xf4e58b13f7e847111c120a7258e8e2164294c261", "MEV/WBNB"),
                            ("0x5cce01ada9aa19552571be68204126cc00576b3d", "ERODE/WBNB"),
                            ("0x1c02a798ea49d78eeb35840b481992a871608feb", "Infi/WBNB"),
                            ("0xf39fd80c0bf774beebc8803c2d9161a1678879e7", "McDOGE/WBNB")):
            data = SEL["getLocksForToken(address,uint256,uint256)"] + enc_addr(pair) + enc_uint(0) + enc_uint(0)
            ok, r = call_ok(laddr, data)
            if not ok or not isinstance(r, str) or len(r) < 3 * 64 + 2:
                continue
            b = r[2:]
            nw = len(b) // 64
            words = [b[i * 64:(i + 1) * 64] for i in range(nw)]
            try:
                ln = int(words[1], 16)
            except Exception:
                continue
            for e in range(min(ln, 5)):
                try:
                    if static_layout:
                        st = 2 + e * 6
                        if st + 5 >= len(words):
                            continue
                        entry = {"label": label, "lock_id": int(words[st], 16),
                                 "token": "0x" + words[st + 1][-40:], "owner": "0x" + words[st + 2][-40:],
                                 "amount": int(words[st + 3], 16), "lockDate": int(words[st + 4], 16),
                                 "tgeDate": int(words[st + 5], 16), "tgeBps": 0, "cycle": 0,
                                 "cycleBps": 0, "unlockedAmount": 0}
                    else:
                        off = int(words[2 + e], 16)
                        st = 2 + off // 32

                        def g(k, st=st):
                            idx = st + k
                            return int(words[idx], 16) if idx < len(words) else 0
                        entry = {"label": label, "lock_id": g(0), "token": "0x" + words[st + 1][-40:],
                                 "owner": "0x" + words[st + 2][-40:], "amount": g(3),
                                 "lockDate": g(4), "tgeDate": g(5), "tgeBps": g(6), "cycle": g(7),
                                 "cycleBps": g(8), "unlockedAmount": g(9)}
                    entry["unlock_date_iso"] = datetime.datetime.utcfromtimestamp(entry["tgeDate"]).strftime("%Y-%m-%d") if 0 < entry["tgeDate"] < 2**34 else None
                    locks[lname].setdefault("locks", []).append(entry)
                except Exception:
                    continue
    res["lockers"] = locks

    # ---- classification ----
    # E-U = skim excess at llama prices (all excess tokens are unpriced/junk; DexScreener check in analysis/)
    # P   = feeTo LP value (feeTo is an EOA)
    # S   = LP locked in a locker with a future unlock date or renounced owner
    # H-O = the rest of pair reserves (LP holders incl. MasterChef depositors and lock owners)
    now_ts = int(time.time())
    locked_future = {}
    for lname in ("pinklock2", "pinklock1"):
        for lk in locks.get(lname, {}).get("locks", []):
            tok = (lk.get("token") or "").lower()
            expired = (lk.get("tgeDate") or 0) <= now_ts and lk.get("unlockedAmount", 0) == 0
            renounced = (lk.get("owner") or "").lower() == "0x" + "0" * 40
            if tok and (not expired or renounced):
                locked_future[tok] = {"locker": lname, "lock_id": lk.get("lock_id"),
                                      "unlock_date_iso": lk.get("unlock_date_iso"), "renounced": renounced}
    s_usd = 0.0
    s_detail = []
    for r in live:
        info = locked_future.get(r["pair"].lower())
        if info:
            val = r["reserve_usd"] * (1 - (r.get("feeTo_share") or 0))
            s_usd += val
            s_detail.append({"pair": r["pair"], "sym0": r.get("sym0"), "sym1": r.get("sym1"),
                             "value_usd": round(val, 2), **info})
    eu = tot_excess
    p_ = tot_feeTo
    ho = tot_reserve - p_ - s_usd
    res["classification"] = {
        "E-U": round(eu, 2), "H-O": round(ho, 2), "P": round(p_, 2), "S": round(s_usd, 2),
        "S_detail": s_detail,
        "note": ("E-U = skim() excess only; all excess tokens are unpriced illiquid tokens "
                 "(PinkE/MEV/ARS/ERODE/COIN/COG/SFT/TRIII/WB3/SAFEMOON; DexScreener: no markets), "
                 "so market value ~0. P = feeTo EOA LP. S = LP locked in lockers with future unlock "
                 "dates / renounced owners (see S_detail). H-O = remaining pair reserves owned by LP "
                 "holders / MasterChef depositors / lock owners.")
    }
    json.dump(res, open(os.path.join(OUT, "live_state.json"), "w"), indent=1)

    lines = []
    lines.append(f"PinkSwap (BSC) live state @ block {blk}")
    lines.append(f"factory {FACTORY}: pairs={n} feeTo={fac.get('feeTo')} (EOA) feeToSetter={fac.get('feeToSetter')}")
    lines.append(f"total reserves (llama-priced tokens) = ${res['totals']['reserves_usd']:,.2f}")
    lines.append(f"skim() excess at llama prices          = ${res['totals']['skim_excess_usd_at_llama_prices']:,.2f}  ({len(excess_rows)} pairs, all unpriced junk tokens)")
    lines.append(f"feeTo LP value (P, feeTo is an EOA)    = ${res['totals']['feeTo_lp_value_usd']:,.2f}")
    lines.append(f"classification: E-U=${eu:.2f}  H-O=${ho:,.2f}  P=${p_:,.2f}  S=${s_usd:,.2f}")
    lines.append("")
    lines.append("gate simulations (eth_call from attacker, read-only):")
    for k, v in sims.items():
        lines.append(f"  {k}: ok={v['ok']} err={str(v['err'])[:110]}")
    lines.append("")
    lines.append("top excess pairs:")
    for r in excess_rows[:12]:
        lines.append(f"  {r['pair']} {r['sym0']}/{r['sym1']} ex0={r['excess0']:.6f} ex1={r['excess1']:.6f} usd={r['excess_usd']}")
    lines.append("")
    lines.append("locker locks on PinkSwap pairs:")
    for lname in ("pinklock2", "pinklock1"):
        for lk in locks.get(lname, {}).get("locks", []):
            lines.append(f"  {lname} {lk['label']} lock#{lk['lock_id']} owner={lk['owner']} amount={lk['amount']} "
                         f"lockDate={lk['lockDate']} unlock={lk.get('unlock_date_iso')} unlockedAmount={lk['unlockedAmount']}")
    lines.append("S detail: " + json.dumps(res["classification"].get("S_detail")))
    lines.append("")
    lines.append("masterchef: pools=%s migrator=%s owner=%s cap_reached=%s" % (pl, mc.get("migrator"), mc.get("owner"), mc.get("deposits_blocked")))
    lines.append("pink: owner=%s totalSupply=%s" % (pink.get("owner"), pink.get("totalSupply")))
    open(os.path.join(OUT, "SUMMARY.txt"), "w").write("\n".join(lines) + "\n")
    print("\n".join(lines), flush=True)
    print("DONE", flush=True)

if __name__ == "__main__":
    main()
