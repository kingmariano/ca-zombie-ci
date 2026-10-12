#!/usr/bin/env python3
"""
cog (Scroll) live-state scanner — read-only, keyless public RPC.
Reads every pair enumerated by the triage (l2-triage-b results.json) plus the
two core factories, and dumps full live state to ci-out/state_latest.json.

No secrets. Public RPC only.
"""
import json, os, sys, time, urllib.request, urllib.error
from concurrent.futures import ThreadPoolExecutor

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
OUT = os.path.join(ROOT, "ci-out")
os.makedirs(OUT, exist_ok=True)

RPC = os.environ.get("SCROLL_RPC", "https://rpc.scroll.io")
RPCS = [RPC, "https://scroll-rpc.publicnode.com", "https://scroll.drpc.org"]
_rr = [0]

def rpc(method, params, tries=3, timeout=25):
    body = json.dumps({"jsonrpc": "2.0", "id": 1, "method": method, "params": params}).encode()
    last = None
    for i in range(tries):
        u = RPCS[_rr[0] % len(RPCS)]
        _rr[0] += 1
        try:
            req = urllib.request.Request(u, data=body, headers={
                "Content-Type": "application/json", "User-Agent": "Mozilla/5.0 (research; read-only)"})
            with urllib.request.urlopen(req, timeout=timeout) as r:
                d = json.loads(r.read().decode())
            if "result" in d:
                return d["result"]
            last = str(d.get("error"))
        except Exception as e:
            last = str(e)
        time.sleep(0.2 + 0.3 * i)
    raise RuntimeError(f"rpc failed {method} {params[:1]}: {last}")

def words(hexstr):
    h = hexstr[2:] if hexstr.startswith("0x") else hexstr
    return [h[i:i+64] for i in range(0, len(h) - 63, 64)]

def dec_uint(w):
    return int(w, 16)

def dec_addr(w):
    return "0x" + w[-40:]

def call(to, sig, extra=""):
    # sig: 0x selector; extra: hex string appended after selector (already padded)
    data = sig + extra
    try:
        return rpc("eth_call", [{"to": to, "data": data}, "latest"])
    except Exception as e:
        return "ERR:" + str(e)[:80]

def selector(sig):
    from Crypto.Hash import keccak
    k = keccak.new(digest_bits=256)
    k.update(sig.encode())
    return "0x" + k.hexdigest()[:8]

SEL = {s: selector(s) for s in [
    "asset()", "collateral()", "oracle()", "paused()", "total_asset()", "total_borrow()",
    "exchange_rate()", "total_collateral_share()", "accrue_info()", "surge_info()",
    "owner()", "fee_to()", "pending_owner()", "blueprint()",
    "balanceOf(address)", "decimals()", "symbol()", "name()", "totalSupply()",
    "pool()", "token()", "multiply()", "divide()", "peek()", "peekSpot()", "get()",
    "get_exchange_rate()",
    "fuse_box(uint256)", "BORROW_OPENING_FEE()", "protocol_fee()", "DEFAULT_PROTOCOL_FEE()",
    "priv_users(address)", "paused(address)",
]}

def pad_addr(a):
    return a.lower().replace("0x", "").rjust(64, "0")

def dec_str(hexstr):
    try:
        if hexstr.startswith("ERR") or len(hexstr) < 130:
            return None
        w = words(hexstr)
        off = dec_uint(w[0]) // 32
        ln = dec_uint(w[off])
        raw = "".join(w[off+1:off+1+ln])
        return bytes.fromhex(raw[:ln*2]).decode("utf-8", "replace")
    except Exception:
        return None

def tuple2(hexstr):
    try:
        w = words(hexstr)
        return [dec_uint(w[0]), dec_uint(w[1])]
    except Exception:
        return None

def tuple3(hexstr):
    try:
        w = words(hexstr)
        return [dec_uint(w[0]), dec_uint(w[1]), dec_uint(w[2])]
    except Exception:
        return None

def read_addr_val(a, sig):
    r = call(a, SEL[sig])
    if isinstance(r, str) and not r.startswith("ERR") and len(r) >= 66:
        return dec_addr(words(r)[0])
    return None

def read_uint(a, sig, arg=None):
    r = call(a, SEL[sig], pad_addr(arg) if arg else "")
    if isinstance(r, str) and not r.startswith("ERR") and len(r) >= 66:
        return dec_uint(words(r)[0])
    return None

def token_meta(tok):
    return {
        "decimals": read_uint(tok, "decimals()"),
        "symbol": dec_str(call(tok, SEL["symbol()"])),
        "name": dec_str(call(tok, SEL["name()"])),
    }

def pair_state(p, asset, coll):
    row = {"pair": p, "asset": asset, "collateral": coll}
    row["asset_live"] = read_addr_val(p, "asset()")
    row["collateral_live"] = read_addr_val(p, "collateral()")
    row["oracle"] = read_addr_val(p, "oracle()")
    row["paused"] = call(p, SEL["paused()"])[:66]
    row["total_asset"] = tuple2(call(p, SEL["total_asset()"]))
    row["total_borrow"] = tuple2(call(p, SEL["total_borrow()"]))
    row["exchange_rate"] = read_uint(p, "exchange_rate()")
    row["total_collateral_share"] = read_uint(p, "total_collateral_share()")
    row["accrue_info"] = tuple3(call(p, SEL["accrue_info()"]))
    row["surge_info"] = tuple2(call(p, SEL["surge_info()"]))
    row["borrow_fee"] = read_uint(p, "BORROW_OPENING_FEE()")
    row["protocol_fee"] = read_uint(p, "protocol_fee()")
    row["asset_bal"] = read_uint(asset, "balanceOf(address)", p)
    row["coll_bal"] = read_uint(coll, "balanceOf(address)", p)
    row["asset_bal_raw"] = row["asset_bal"]
    row["coll_bal_raw"] = row["coll_bal"]
    # get_exchange_rate() simulation (updates stored rate if oracle reports change)
    ge = call(p, SEL["get_exchange_rate()"])
    if isinstance(ge, str) and not ge.startswith("ERR") and len(ge) >= 130:
        w = words(ge)
        row["get_exchange_rate_sim"] = {"updated": dec_uint(w[0]), "rate": dec_uint(w[1])}
    return row

def oracle_state(o):
    row = {"oracle": o}
    if o is None:
        return row
    try:
        row["code_len"] = len(rpc("eth_getCode", [o, "latest"]) or "")
    except Exception:
        row["code_len"] = None
    row["name"] = dec_str(call(o, SEL["name()"]))
    row["symbol"] = dec_str(call(o, SEL["symbol()"]))
    row["pool"] = read_addr_val(o, "pool()")
    row["token"] = read_addr_val(o, "token()")
    row["multiply"] = read_addr_val(o, "multiply()")
    row["divide"] = read_addr_val(o, "divide()")
    for k in ("peek()", "peekSpot()", "get()"):
        r = call(o, SEL[k])
        if isinstance(r, str) and not r.startswith("ERR") and len(r) >= 66:
            w = words(r)
            if k == "peekSpot()":
                row[k] = dec_uint(w[0])
            else:
                row[k] = {"updated": dec_uint(w[0]), "rate": dec_uint(w[1])}
    return row

def main():
    tri = json.load(open("/home/heisenberg/CA/l2-triage-b/ci-out/results.json"))
    cog = [p for p in tri["protocols"] if p.get("slug") == "cog"][0]
    pairs = []
    for t in cog["targets"]:
        for pr in t["pairs"]:
            if pr["pair"] not in [x[0] for x in pairs]:
                pairs.append((pr["pair"], pr["asset"], pr["collateral"]))

    block = int(rpc("eth_blockNumber", []), 16)
    print(f"latest scroll block: {block}, pairs: {len(pairs)}", flush=True)

    factories = ["0xbabd55549c266c6755b99173fe7604238d04117d", "0xcd44fecb08bb28405992358131fd5081a0f550d0"]
    fac_state = {}
    for f in factories:
        fac_state[f] = {
            "owner": read_addr_val(f, "owner()"),
            "pending_owner": read_addr_val(f, "pending_owner()"),
            "fee_to": read_addr_val(f, "fee_to()"),
            "blueprint": read_addr_val(f, "blueprint()"),
            "code_len": len(rpc("eth_getCode", [f, "latest"])),
        }

    # blueprints referenced by deployments file
    fac_state["blueprint_repo_0xaDEc"] = {
        "code_len": len(rpc("eth_getCode", ["0xaDEc0DF8F4a1152F6ae19e4BC5FAdF43Ab8DF59C", "latest"]))}

    states = []
    with ThreadPoolExecutor(max_workers=5) as ex:
        futs = {ex.submit(pair_state, p, a, c): p for p, a, c in pairs}
        for fu in futs:
            try:
                states.append(fu.result())
            except Exception as e:
                states.append({"pair": futs[fu], "err": str(e)[:120]})
            if len(states) % 20 == 0:
                print(f"  pairs done: {len(states)}", flush=True)

    with open(os.path.join(OUT, "state_pairs_partial.json"), "w") as f:
        json.dump({"block": block, "factories": fac_state, "pairs": states}, f, indent=1)

    # oracle info (unique)
    ors = sorted({s.get("oracle") for s in states if s.get("oracle")})
    oinfo = {}
    with ThreadPoolExecutor(max_workers=6) as ex:
        futs = {ex.submit(oracle_state, o): o for o in ors}
        for fu in futs:
            try:
                oinfo[futs[fu]] = fu.result()
            except Exception as e:
                oinfo[futs[fu]] = {"oracle": futs[fu], "err": str(e)[:120]}
    print(f"oracles: {len(ors)}", flush=True)

    # token meta (unique tokens)
    toks = sorted({s.get("asset") for s in states if s.get("asset")} | {s.get("collateral") for s in states if s.get("collateral")})
    tmeta = {}
    with ThreadPoolExecutor(max_workers=6) as ex:
        futs = {ex.submit(token_meta, t): t for t in toks}
        for fu in futs:
            try:
                tmeta[futs[fu]] = fu.result()
            except Exception as e:
                tmeta[futs[fu]] = {"err": str(e)[:80]}
    print(f"tokens: {len(toks)}", flush=True)

    out = {"scanned_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
           "block": block, "factories": fac_state, "pairs": states,
           "oracles": oinfo, "tokens": tmeta}
    with open(os.path.join(OUT, "state_latest.json"), "w") as f:
        json.dump(out, f, indent=1)
    print("wrote ci-out/state_latest.json")

if __name__ == "__main__":
    main()
