#!/usr/bin/env python3
"""Recon 2: per-pair actual token balances vs reserves (skim excess), LP supply details,
pair class ABI/entry points, factory admin surfaces. Read-only, public RPC only."""
import json, sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import sn

D = os.path.dirname(os.path.abspath(__file__))
FACTORY = "0x1c0a36e26a8f822e0d81f20a5a562b16a8f8a3dfd99801367dd2aea8f1a87a2"

def main():
    r1 = json.load(open(os.path.join(D, "recon1.json")))
    pairs = r1["pairs"]
    st = r1["pair_state"]
    block = r1["block"]
    out = {"block": block, "factory": FACTORY, "pairs": {}}

    # current block timestamp
    bh = sn.rpc("starknet_getBlockWithTxHashes", ["latest"])
    out["block_timestamp"] = int(bh.get("timestamp", 0))
    print("block ts:", out["block_timestamp"], "block:", block)

    sel_balanceOf = sn.selector("balanceOf")
    sel_totalSupply = sn.selector("totalSupply")

    # per pair: token balances of pair, and LP balance of pair itself (MINIMUM_LIQUIDITY),
    # plus allowances-style probes are not needed. Also fee_to on factory.
    calls = []
    order = []
    for p in pairs:
        t0 = sn.hexaddr(st[p]["token0"][0])
        t1 = sn.hexaddr(st[p]["token1"][0])
        calls.append((t0, sel_balanceOf, [p])); order.append((p, "bal_t0"))
        calls.append((t1, sel_balanceOf, [p])); order.append((p, "bal_t1"))
        calls.append((p, sel_balanceOf, [p])); order.append((p, "lp_of_pair"))
        # LP balance of the zero address / factory (in case of locked supply)
        calls.append((p, sel_balanceOf, [FACTORY])); order.append((p, "lp_of_factory"))
    rets = sn.batch_calls(calls)
    for (p, name), r in zip(order, rets):
        out["pairs"].setdefault(p, {})[name] = r

    # factory admin surfaces: try common entry points
    fprobes = {
        "fee_to": [], "feeTo": [], "get_fee_to": [],
        "fee_to_setter": [], "feeToSetter": [], "get_fee_to_setter": [],
        "owner": [], "get_owner": [], "admin": [], "get_admin": [],
        "implementation": [], "get_implementation": [],
        "paused": [], "is_paused": [],
    }
    for fn, cd in fprobes.items():
        try:
            r = sn.call(FACTORY, fn, cd)
            out.setdefault("factory_probes", {})[fn] = r
            print(f"factory.{fn}() ->", r)
        except Exception as e:
            out.setdefault("factory_probes", {})[fn] = f"ERR: {str(e)[:120]}"

    # pair class: ABI + entry points
    pair_class_hash = st[pairs[0]].get("class_hash")
    out["pair_class_hash"] = pair_class_hash
    cc = sn.get_class(pair_class_hash)
    out["pair_class_keys"] = list(cc.keys())
    out["pair_entrypoints"] = sn.entrypoints(cc)
    abi = cc.get("abi")
    out["pair_abi"] = abi
    if abi:
        print("pair ABI:", json.dumps(abi)[:4000])
    else:
        print("pair class has no abi field; keys:", list(cc.keys()))

    # factory class ABI
    fch = r1["factory_class_hash"]
    fcc = sn.get_class(fch)
    fabi = fcc.get("abi")
    out["factory_abi"] = fabi
    out["factory_entrypoints"] = sn.entrypoints(fcc)
    if fabi:
        print("factory ABI:", json.dumps(fabi)[:3000])

    with open(os.path.join(D, "recon2.json"), "w") as f:
        json.dump(out, f, indent=1)
    print("wrote recon2.json")

if __name__ == "__main__":
    main()
