#!/usr/bin/env python3
"""Robust balanceOf+getCode verification of a candidate address set for a token."""
import json, os, sys, time
sys.path.insert(0, '/home/heisenberg/CA/narwhalswap/analysis')
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bsc

HERE = os.path.dirname(os.path.abspath(__file__))

def call_one(method, params, tries=8):
    for att in range(tries):
        try:
            return bsc.rpc(method, params)
        except Exception:
            time.sleep(0.7 * (att + 1))
    return None

def call_one_safe(method, params):
    r = call_one(method, params)
    return r

def verify_token(token, addrs, label, blk, outfile=None):
    addrs = sorted(set(a.lower() for a in addrs))
    bal, code = {}, {}
    # batched first pass
    CH = 20
    for i in range(0, len(addrs), CH):
        part = addrs[i:i+CH]
        calls = [("eth_call", [{"to": token, "data": bsc.SEL['balanceOf'] + bsc.word(a)}, hex(blk)]) for a in part]
        calls += [("eth_getCode", [a, hex(blk)]) for a in part]
        got = None
        for att in range(4):
            try:
                got = bsc.rpc_batch(calls)
                break
            except Exception:
                time.sleep(1.0 + att)
        if got is None:
            got = [None] * len(calls)
        n = len(part)
        for a, r in zip(part, got[:n]):
            bal[a] = int(r, 16) if r and r != '0x' else None
        for a, r in zip(part, got[n:]):
            code[a] = (len(r) - 2) // 2 if r else None
        time.sleep(0.15)
    # fallback for missing/None values individually
    for a in addrs:
        if bal.get(a) is None:
            r = call_one("eth_call", [{"to": token, "data": bsc.SEL['balanceOf'] + bsc.word(a)}, hex(blk)])
            bal[a] = int(r, 16) if r and r != '0x' else 0
        if code.get(a) is None:
            r = call_one("eth_getCode", [a, hex(blk)])
            code[a] = (len(r) - 2) // 2 if r else 0
    nz = {a: v for a, v in bal.items() if v > 0}
    print(f"== {label}: candidates={len(addrs)} nonzero={len(nz)} sum={sum(nz.values())/1e18:,.9f}")
    if outfile:
        json.dump({'block': blk, 'token': token, 'balances': bal, 'code_len': code},
                  open(os.path.join(HERE, outfile), 'w'), indent=1)
    return bal, code

if __name__ == '__main__':
    pass
