#!/usr/bin/env python3
"""Read-only gate proofs for SithSwap via starknet_simulateTransactions (SKIP_VALIDATE).

Uses a real deployed account as an unprivileged sender. No transactions are sent.
Writes results to ci-out/sim_results.json (when run with --out).
"""
import json, os, sys, time, urllib.request, urllib.error
from sn import rpc, selector

SENDER = "0x5bcbbaa25518ac4e0ccff36b2b64779f6424eb9f63354aadec18c6a17ff4611"  # recent account, not owner
PAIR = 0x32ebb8e68553620b97b308684babf606d9556d5c0a652450c32e85f40d000d  # DAI/ETH pool pid 1
PAIR2 = 0x30615bec9c1506bfac97d9dbd3c546307987d467a7f95d5533c2e861eb81f3f  # pid 2

SIM_URL = "https://api.cartridge.gg/x/starknet/mainnet"

def build_invoke(sender, calls, nonce="0x0", max_fee="0x0", cairo1=True):
    if cairo1:
        # Cairo 1 accounts: calldata = serialized Array<Call>
        cd = [hex(len(calls))]
        for addr, fn, args in calls:
            cd += [hex(addr), hex(int(selector(fn), 16)), hex(len(args))] + [hex(x) for x in args]
    else:
        call_array = []
        flat = []
        for addr, fn, args in calls:
            call_array += [hex(addr), hex(int(selector(fn), 16)), hex(len(args))]
            flat += [hex(x) for x in args]
        cd = [hex(len(calls))] + call_array + [hex(len(flat))] + flat
    return {
        "type": "INVOKE",
        "version": "0x1",
        "sender_address": sender,
        "calldata": cd,
        "signature": [],
        "nonce": nonce,
        "max_fee": max_fee,
    }

_SIM_LAST = [0.0]
def simulate_raw(txs, block="latest", tries=5):
    import time as _t
    dt = _t.time() - _SIM_LAST[0]
    if dt < 0.5:
        _t.sleep(0.5 - dt)
    _SIM_LAST[0] = _t.time()
    body = json.dumps({"jsonrpc": "2.0", "method": "starknet_simulateTransactions",
                       "params": {"block_id": block, "transactions": txs,
                                  "simulation_flags": ["SKIP_VALIDATE", "SKIP_FEE_CHARGE"]}, "id": 1}).encode()
    last = None
    for i in range(tries):
        try:
            req = urllib.request.Request(SIM_URL, data=body,
                                         headers={"Content-Type": "application/json", "User-Agent": "Mozilla/5.0"})
            with urllib.request.urlopen(req, timeout=60) as r:
                return json.loads(r.read())
        except urllib.error.HTTPError as e:
            last = f"HTTP {e.code} {e.read().decode()[:200]}"
        except Exception as e:
            last = str(e)
        time.sleep(1.0 + i)
    return {"error": {"message": last}}

def summarize(resp):
    if "error" in resp:
        e = resp["error"]
        msg = e.get("message", "")
        data = e.get("data", {})
        reason = data.get("execution_error") or data.get("revert_error") or msg
        return {"status": "REVERT" if data else "RPC_ERROR", "reason": str(reason)[:1500]}
    try:
        tt = resp["result"][0].get("transaction_trace", {})
        er = tt.get("execute_invocation", {})
        if isinstance(er, dict) and "revert_reason" in er:
            return {"status": "REVERT", "reason": er["revert_reason"][:1500]}
        # successful: try to extract nested call result
        res = None
        try:
            res = er["result"]
        except Exception:
            pass
        return {"status": "OK", "result": str(res)[:300] if res is not None else None,
                "trace_keys": list(tt.keys())[:6]}
    except Exception as e:
        return {"status": "UNKNOWN", "raw": str(resp)[:300]}

def run_case(name, calls, nonce, cairo1=True, block="latest"):
    tx = build_invoke(SENDER, calls, nonce=nonce, cairo1=cairo1)
    resp = simulate_raw([tx], block=block)
    r = summarize(resp)
    print(f"[{name}] {json.dumps(r)[:350]}", flush=True)
    return {"name": name, "result": r}

def main():
    nonce = rpc("starknet_getNonce", ["latest", SENDER])
    cls = rpc("starknet_getClass", ["latest", "0x036078334509b514626504edc9fb252328d1a240e4e948bef8d0c08dff45927f"])
    cairo1 = "sierra_program" in cls
    blk = rpc("starknet_blockNumber", [])
    out = []
    print(f"sender={SENDER} nonce={nonce} block={blk}", flush=True)
    cases = [
        ("set_trade_fee(1,0) non-owner", [(PAIR, "setTradeFee", [1, 0])]),
        ("transfer_ownership(sender,1) non-owner", [(PAIR, "transferOwnership", [int(SENDER, 16), 1])]),
        ("clawback_ownership non-factory-owner", [(PAIR, "clawbackOwnership", [])]),
        ("initialize live pair", [(PAIR, "initialize", [1, 0xda114221cb83fa859dbdb4c44beeaa0bb37c7537ad5ae66fe5e0efd20e6eb3, 0x49d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7, 0, 1500, int(SENDER, 16)])]),
        ("claim_fees non-LP", [(PAIR, "claimFees", [])]),
        ("swap(0,0,to,0) insufficient output", [(PAIR, "swap", [0, 0, 0, 0, int(SENDER, 16), 0])]),
        ("swap(reserve0-1,0,to,0) insufficient input", [(PAIR, "swap", [0x16ad47bccc1b4f6fce0 - 1, 0, 0, 0, int(SENDER, 16), 0])]),
        ("burn no LP", [(PAIR, "burn", [int(SENDER, 16)])]),
        ("sync permissionless", [(PAIR, "sync", [])]),
        ("skim no excess", [(PAIR, "skim", [int(SENDER, 16)])]),
        ("renounce_ownership non-owner", [(PAIR, "renounceOwnership", [])]),
        ("claim_ownership non-pending", [(PAIR, "claimOwnership", [])]),
        ("set_trade_fee(1,0) pid2 non-owner", [(PAIR2, "setTradeFee", [1, 0])]),
    ]
    for name, calls in cases:
        out.append(run_case(name, calls, nonce, cairo1=cairo1))
    # positive swap + K-guard proofs (sender = funded account; swap is permissionless so privilege is irrelevant)
    try:
        out += swap_guard_proofs()
    except Exception as e:
        print("swap_guard_proofs failed:", str(e)[:300], flush=True)
    if "--out" in sys.argv:
        outp = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "ci-out")
        os.makedirs(outp, exist_ok=True)
        json.dump({"sender": SENDER, "block": blk, "cases": out}, open(os.path.join(outp, "sim_results.json"), "w"), indent=1)
    print("done", flush=True)


# ---- positive swap proofs ----
FUNDED_CANDIDATES = [
    "0x17dd33c2dcbdac44429ded27be81638e77fe729e243630106790c516020cc07",  # active account, ~0.57 ETH
    "0x5ae9c593b2bef20a8d69ae7abf1e6da551481f9efd83d03a9f05b6d7c9a78ec",
]
ETH = 0x49d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7
PAIR1 = PAIR  # DAI/ETH, token0=DAI, token1=ETH

def get_amount_out(pair, amount_in, token_in, block="latest"):
    res = rpc("starknet_call", {
        "request": {"contract_address": hex(pair), "entry_point_selector": selector("getAmountOut"),
                    "calldata": [hex(amount_in & ((1 << 128) - 1)), hex(amount_in >> 128), hex(token_in)]},
        "block_id": block,
    })
    return int(res[0], 16) + (int(res[1], 16) << 128)

def swap_guard_proofs():
    cases = []
    X = 10 ** 14  # 0.0001 ETH
    out_amt = get_amount_out(PAIR1, X, ETH)
    print(f"[swap] X={X} ETH -> quoted out={out_amt} DAI", flush=True)
    sender = None
    for cand in FUNDED_CANDIDATES:
        try:
            cls = rpc("starknet_getClassAt", ["latest", cand])
            cairo1 = "sierra_program" in cls if isinstance(cls, dict) else True
            nonce = rpc("starknet_getNonce", ["latest", cand])
            probe = summarize(simulate_raw([build_invoke(cand, [(ETH, "transfer", [int(cand, 16), 0, 0])], nonce=nonce, cairo1=cairo1)]))
            if probe["status"] == "OK":
                sender = cand
                break
        except Exception:
            continue
    if sender is None:
        print("[swap] no working funded sender found", flush=True)
        return cases
    cls = rpc("starknet_getClassAt", ["latest", sender])
    cairo1 = "sierra_program" in cls if isinstance(cls, dict) else True
    nonce = rpc("starknet_getNonce", ["latest", sender])

    def build(out_amount):
        calls = [(ETH, "transfer", [PAIR1, X & ((1 << 128) - 1), X >> 128]),
                 (PAIR1, "swap", [out_amount & ((1 << 128) - 1), out_amount >> 128, 0, 0, int(sender, 16), 0])]
        return build_invoke(sender, calls, nonce=nonce, cairo1=cairo1)
    # fair amount -> expect OK
    r = summarize(simulate_raw([build(out_amt)]))
    print(f"[swap fair out={out_amt}] {json.dumps(r)[:300]}", flush=True)
    cases.append({"name": "swap fair amount passes", "sender": sender, "result": r, "amount_in": X, "amount_out": out_amt})
    # out + 1 -> expect K revert
    resp = simulate_raw([build(out_amt + 1)])
    r = summarize(resp)
    if r["status"] == "REVERT":
        # capture full inner reason
        try:
            r["reason"] = resp["result"][0]["transaction_trace"]["execute_invocation"]["revert_reason"]
        except Exception:
            pass
    print(f"[swap out+1={out_amt+1}] {json.dumps(r)[:500]}", flush=True)
    cases.append({"name": "swap out+1 reverts K", "sender": sender, "result": r, "amount_in": X, "amount_out": out_amt + 1})
    return cases

if __name__ == "__main__":
    main()
