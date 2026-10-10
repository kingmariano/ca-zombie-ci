#!/usr/bin/env python3
"""
swap_sim.py — local analysis helper (READ-ONLY, eth_call only) for fstswap-top-pairs.

Simulates an unprivileged sell of a counterparty token T into a FstSwap pair using
eth_call state overrides (no real tx, no keys):
  1. discover T's balances/allowances storage slots by probing storage overrides
     (slot s, key = keccak256(abi.encode(addr, s)) / nested for allowance)
  2. override balances[attacker]=BIG and allowances[attacker][router]=MAX
  3. eth_call router.swapExactTokensForTokens(amountIn, 0, [T, blue], attacker, deadline)
  4. compare actual out vs router.getAmountsOut(amountIn) quote
     -> if actual < quote: fee-on-transfer / transfer tax
     -> if revert: honeypot / blocked transfer
Also reports pair getReserves and token balanceOf(pair) so the caller can sanity-check.

Usage: python3 swap_sim.py JOBS.json OUT.json
JOBS.json: [{"label":..., "token":..., "pair":..., "blue":..., "decimals":n, "amount_in_human":...}, ...]
"""
import json, os, sys, time, urllib.request
from eth_hash.auto import keccak  # optional; fallback below

RPC = os.environ.get("BSC_RPC", "https://bsc.publicnode.com")
ROUTER = "0x1b6c9c20693afde803b27f8782156c0f892abc2d"
ATTACKER = "0x00000000000000000000000000000000FeedFace"
RPCS = [RPC, "https://bsc.publicnode.com", "https://bsc-dataseed.binance.org"]
RPCS = [u for u in RPCS if u and u.startswith("http")]
_good = [None]

def post(url, payload, timeout=60):
    req = urllib.request.Request(url, data=json.dumps(payload).encode(),
                                 headers={"Content-Type": "application/json", "User-Agent": "h2-09-recon/1.0"})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return json.loads(r.read())

def rpc(method, params):
    order = ([_good[0]] if _good[0] else []) + [u for u in RPCS if u != _good[0]]
    last = None
    for url in order:
        try:
            d = post(url, {"jsonrpc": "2.0", "id": 1, "method": method, "params": params})
            if "error" in d: raise RuntimeError(d["error"])
            _good[0] = url
            return d.get("result")
        except Exception as e:
            last = e
            time.sleep(0.6)
    raise RuntimeError(f"rpc failed: {last}")

def rpc_paced(method, params):
    time.sleep(0.3)
    return rpc(method, params)

def pad(v): return f"{v:064x}"
def dec_u(res):
    if not isinstance(res, str) or res in ("0x", ""): return None
    h = res[2:] if res.startswith("0x") else res
    return int(h, 16) if 0 < len(h) <= 66 else None
def dec_addr(res):
    if not isinstance(res, str): return None
    h = res[2:] if res.startswith("0x") else res
    return "0x" + h[-40:] if len(h) == 64 else None

def keccak256(b: bytes) -> bytes:
    try:
        return keccak(b)
    except Exception:
        import sha3  # pysha3 fallback
        k = sha3.keccak_256(); k.update(b); return k.digest()

def slot_key(addr, slot):
    return "0x" + keccak256(bytes.fromhex(addr.lower().replace("0x", "").rjust(64, "0")) + bytes.fromhex(pad(slot))).hex()

def slot_key_nested(owner, spender, slot):
    inner = keccak256(bytes.fromhex(owner.lower().replace("0x", "").rjust(64, "0")) + bytes.fromhex(pad(slot)))
    return "0x" + keccak256(bytes.fromhex(spender.lower().replace("0x", "").rjust(64, "0")) + inner).hex()

BIG = 10**30
SLOT_CACHE = {}  # (token, addr) -> (slot, key); (token, owner, spender) -> (slot, key)

def call(to, data, frm=None, block="latest", override=None):
    o = {"to": to, "data": data}
    if frm: o["from"] = frm
    params = [o, block]
    if override: params.append(override)
    return rpc_paced("eth_call", params)

def discover_balance_slot(token, addr, block):
    key = (token, addr)
    if key in SLOT_CACHE: return SLOT_CACHE[key]
    for s in range(0, 8):
        sk = slot_key(addr, s)
        ov = {token: {"stateDiff": {sk: "0x" + pad(BIG)}}}
        try:
            r = dec_u(call(token, "0x70a08231" + pad(int(addr, 16)), block=block, override=ov))
            if r == BIG:
                SLOT_CACHE[key] = (s, sk); return s, sk
        except Exception:
            pass
    SLOT_CACHE[key] = (None, None)
    return None, None

def discover_allowance_slot(token, owner, spender, block):
    key = (token, owner, spender)
    if key in SLOT_CACHE: return SLOT_CACHE[key]
    for s in range(0, 8):
        sk = slot_key_nested(owner, spender, s)
        ov = {token: {"stateDiff": {sk: "0x" + pad(BIG)}}}
        try:
            data = "0xdd62ed3e" + pad(int(owner, 16)) + pad(int(spender, 16))
            r = dec_u(call(token, data, block=block, override=ov))
            if r == BIG:
                SLOT_CACHE[key] = (s, sk); return s, sk
        except Exception:
            pass
    SLOT_CACHE[key] = (None, None)
    return None, None

def main():
    jobs = json.load(open(sys.argv[1]))
    out_path = sys.argv[2]
    out = {"router": ROUTER, "attacker": ATTACKER, "results": []}
    for j in jobs:
        blk = int(rpc("eth_blockNumber", []), 16)
        block = hex(blk)
        r = dict(j); r["block"] = blk
        T = j["token"].lower(); P = j["pair"].lower(); B = j["blue"].lower()
        dec = j.get("decimals", 18)
        amount_in = int(j["amount_in_human"] * 10 ** dec)
        r["amount_in_raw"] = str(amount_in)
        # pair state
        try:
            rr = call(P, "0x0902f1ac", block=block)
            h = rr[2:]
            r["reserves"] = {"r0": str(int(h[0:64], 16)), "r1": str(int(h[64:128], 16))}
            t0 = dec_addr(call(P, "0x0dfe1681", block=block))
            r["token0"] = t0
            r["pair_token_is_token0"] = (t0 == T)
        except Exception as e:
            r["pair_err"] = str(e)[:200]
        r["quote_out_raw"] = None
        try:
            path = [T, B]
            data = "0xd06ca61f" + pad(amount_in) + pad(0x40) + pad(2) + pad(int(path[0], 16)) + pad(int(path[1], 16))
            q = call(ROUTER, data, block=block)
            if q and len(q) >= 2 + 64 * 4:
                h = q[2:]
                n = int(h[64:128], 16)
                r["quote_out_raw"] = str(int(h[192:256], 16))  # amounts[1] (amounts[0]=amountIn)
                r["quote_in_echo_raw"] = str(int(h[128:192], 16))
                r["quote_path_len"] = n
        except Exception as e:
            r["quote_err"] = str(e)[:200]
        # discover slots
        bs, bkey = discover_balance_slot(T, ATTACKER, block)
        as_, akey = discover_allowance_slot(T, ATTACKER, ROUTER, block)
        r["balance_slot"] = bs; r["allowance_slot"] = as_
        if bs is None or as_ is None:
            r["sim"] = {"result": "cannot_setup_overrides", "balance_slot": bs, "allowance_slot": as_}
            out["results"].append(r); print(f"[{j.get('label')}] setup failed bs={bs} as={as_}", flush=True)
            continue
        ov = {T: {"stateDiff": {bkey: "0x" + pad(BIG), akey: "0x" + pad(BIG)}}}
        deadline = 0xffffffff
        route = j.get("route", "exact")
        sel = "0x5c11d795" if route == "supporting" else "0x38ed1739"  # swapExactTokensForTokens[SupportingFeeOnTransferTokens]
        data = (sel + pad(amount_in) + pad(0) + pad(0xa0) + pad(int(ATTACKER, 16)) + pad(deadline)
                + pad(2) + pad(int(T, 16)) + pad(int(B, 16)))
        try:
            res = call(ROUTER, data, frm=ATTACKER, block=block, override=ov)
            amounts = []
            if res and res != "0x":
                h = res[2:]; n = int(h[64:128], 16)
                amounts = [str(int(h[128 + i * 64:192 + i * 64], 16)) for i in range(n)]
            r["sim"] = {"result": "SUCCESS", "amounts_raw": amounts}
            if r["quote_out_raw"] and len(amounts) >= 2:
                actual = int(amounts[-1]); quoted = int(r["quote_out_raw"])
                r["sim"]["actual_out_raw"] = str(actual)
                r["sim"]["quote_out_raw"] = str(quoted)
                r["sim"]["ratio_actual_over_quote"] = round(actual / quoted, 6) if quoted else None
                r["sim"]["fee_on_transfer"] = bool(quoted and actual < quoted * 0.999)
        except Exception as e:
            r["sim"] = {"result": "REVERT", "err": str(e)[:300]}
        out["results"].append(r)
        print(f"[{j.get('label')}] {T[:10]}.. quote={r.get('quote_out_raw')} sim={r['sim'].get('result')} "
              f"ratio={r['sim'].get('ratio_actual_over_quote')} fee={r['sim'].get('fee_on_transfer')}", flush=True)
        time.sleep(0.2)
    json.dump(out, open(out_path, "w"), indent=1)
    print("wrote", out_path, flush=True)

if __name__ == "__main__":
    main()
