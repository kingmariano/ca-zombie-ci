#!/usr/bin/env python3
"""Read-only PoC via starknet_simulateTransactions (NEVER sent, state discarded).

Simulates real INVOKE transactions against mainnet state at latest block:
  T1: attacker account calls pair.initialize(USDT, WBTC)  -> expect revert (caller != factory)
  T2: attacker account calls pair.initialize(orig tokens)-> expect revert (same gate)
  T3: attacker account calls pair.swap(out>0) without paying -> expect revert (10kSwap: K)
  T4: attacker account calls pair.skim(attacker) -> expect success, zero transfer
      (balances == reserves -> diff 0; proves no skimmable excess)

Uses SKIP_VALIDATE + SKIP_FEE_CHARGE simulation flags (no signature, no fees).
The sender address is any deployed account; nothing is signed or broadcast.
"""
import json, sys, os, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import sn

D = os.path.dirname(os.path.abspath(__file__))
PAIR = "0x23c72abdf49dffc85ae3ede714f2168ad384cc67d08524732acea90df325"  # ETH/USDC
USDT = 0x68f5c6a61780768455de69077e07e89787839bf8166decfbf92b645209c0fb8
WBTC = 0x3fe2b97c1fd336e750087d68b9b867997fd64a2661ff3ca5a7c771641e8e7ac
# sender: the 10KSwap router-using trader account observed on-chain (a deployed account)
SENDER = "0x1b45c8595a6a908e136763258a57517bc9c66c0d659c567ee055b5d9ab7ff6c"


def invoke_calldata(calls):
    """Cairo1 account __execute__ calldata: Array<Call>."""
    cd = [hex(len(calls))]
    for to, sel, data in calls:
        cd += [to, sel, hex(len(data))] + data
    return cd


def build_v3(calls, nonce=0):
    return {
        "type": "INVOKE",
        "version": "0x3",
        "sender_address": SENDER,
        "calldata": invoke_calldata(calls),
        "signature": [],
        "nonce": hex(nonce),
        "resource_bounds": {
            "l1_gas": {"max_amount": "0x1000000", "max_price_per_unit": "0x1000000000"},
            "l2_gas": {"max_amount": "0x1000000", "max_price_per_unit": "0x1000000000"},
            "l1_data_gas": {"max_amount": "0x1000000", "max_price_per_unit": "0x1000000000"},
        },
        "tip": "0x0",
        "paymaster_data": [],
        "account_deployment_data": [],
        "nonce_data_availability_mode": "L1",
        "fee_data_availability_mode": "L1",
    }


def simulate(tx, label):
    params = {
        "block_id": "latest",
        "transactions": [tx],
        "simulation_flags": ["SKIP_VALIDATE", "SKIP_FEE_CHARGE"],
    }
    last = None
    for attempt in range(4):
        try:
            r = sn.rpc("starknet_simulateTransactions", params, timeout=120)
            rec = {"label": label, "supported": True, "result": r}
            try:
                tr = r[0]["transaction_trace"]
                rec["execution_status"] = tr.get("execution_status")
                rec["revert_reason"] = tr.get("revert_reason")
                rec["events_count"] = len(tr.get("execute_invocation", {}).get("events", []) or [])
            except Exception:
                pass
            return rec
        except Exception as e:
            last = str(e)[:400]
            time.sleep(2.0 * (attempt + 1))
    return {"label": label, "supported": False, "error": last}


def main():
    blk = sn.rpc("starknet_blockNumber", [])
    nonce = sn.rpc("starknet_getNonce", ["latest", SENDER])
    nonce_int = int(nonce, 16)
    out = {"block": blk, "pair": PAIR, "sender": SENDER, "sender_nonce": nonce, "tests": []}
    sel_init = sn.selector("initialize")
    sel_swap = sn.selector("swap")
    sel_skim = sn.selector("skim")
    U = lambda v: [hex(v & ((1 << 128) - 1)), hex(v >> 128)]

    st = json.load(open(os.path.join(D, "recon1.json")))["pair_state"][PAIR]
    t0, t1 = st["token0"][0], st["token1"][0]

    tests = [
        ("T1_init_usdt_wbtc", [(PAIR, sel_init, [hex(USDT), hex(WBTC)])]),
        ("T2_init_orig", [(PAIR, sel_init, [t0, t1])]),
        ("T3_swap_unpaid", [(PAIR, sel_swap, U(0) + U(1000 * 10**6) + [hex(int(SENDER, 16))])]),
        ("T4_skim", [(PAIR, sel_skim, [hex(int(SENDER, 16))])]),
    ]
    for label, calls in tests:
        rec = simulate(build_v3(calls, nonce=nonce_int), label)
        out["tests"].append(rec)
        print(label, "->", json.dumps({k: v for k, v in rec.items() if k != "result"})[:400], flush=True)
    with open(os.path.join(D, "sim_tests.json"), "w") as f:
        json.dump(out, f, indent=1)
    print("wrote sim_tests.json")


if __name__ == "__main__":
    main()
