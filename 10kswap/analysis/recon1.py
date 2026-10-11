#!/usr/bin/env python3
"""Recon 1: factory state, pair enumeration, per-pair class hashes + reserves.
Read-only. Writes analysis/recon1.json. Public keyless RPC only."""
import json, sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import sn

FACTORY = "0x1c0a36e26a8f822e0d81f20a5a562b16a8f8a3dfd99801367dd2aea8f1a87a2"
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "recon1.json")

def main():
    out = {"block": None, "factory": FACTORY}
    blk = sn.rpc("starknet_blockNumber", [])
    out["block"] = blk
    print("block:", blk)

    # factory class hash + class
    fch = sn.get_class_hash_at(FACTORY)
    out["factory_class_hash"] = fch
    print("factory class hash:", fch)
    try:
        fcc = sn.get_class(fch)
        out["factory_class_keys"] = list(fcc.keys())
        out["factory_entrypoints"] = sn.entrypoints(fcc)
        print("factory class keys:", list(fcc.keys()))
        for typ, sels in out["factory_entrypoints"].items():
            print(f"  {typ}: {len(sels)} eps")
        abi = fcc.get("abi")
        if abi:
            out["factory_abi"] = abi
            print("factory ABI entries:", len(abi))
        prog = sn.decode_program(fcc)
        if prog:
            out["factory_program_meta"] = {k: (len(v) if isinstance(v, list) else v) for k, v in prog.items()}
    except Exception as e:
        out["factory_class_error"] = str(e)
        print("factory class error:", e)

    # pairs
    ret = sn.call(FACTORY, "allPairsLength")
    n = sn.felt(ret[0]) + (sn.felt(ret[1]) << 128 if len(ret) > 1 else 0)
    out["allPairsLength"] = n
    print("allPairsLength:", n)

    pairs = []
    pcalls = [(FACTORY, sn.selector("allPairs"), [i]) for i in range(n)]
    pret = sn.batch_calls(pcalls)
    for i, r in enumerate(pret):
        if r and not isinstance(r, dict):
            pairs.append(sn.hexaddr(r[0]))
        else:
            print("allPairs", i, "error:", r)
    out["pairs"] = pairs
    print("pairs:", pairs)

    # per pair: class hash + tokens + reserves + supply
    out["pair_state"] = {}
    calls = []
    order = []
    for p in pairs:
        calls.append((p, sn.selector("token0"), [])); order.append((p, "token0"))
        calls.append((p, sn.selector("token1"), [])); order.append((p, "token1"))
        calls.append((p, sn.selector("getReserves"), [])); order.append((p, "getReserves"))
        calls.append((p, sn.selector("totalSupply"), [])); order.append((p, "totalSupply"))
        calls.append((p, sn.selector("kLast"), [])); order.append((p, "kLast"))
    rets = sn.batch_calls(calls)
    st = {}
    for (p, name), r in zip(order, rets):
        st.setdefault(p, {})[name] = r
    out["pair_state"] = st
    for p in pairs:
        s = st.get(p, {})
        print(p)
        for k in ("token0", "token1", "getReserves", "totalSupply", "kLast"):
            print("   ", k, s.get(k))

    # per pair class hash
    for p in pairs:
        try:
            ch = sn.get_class_hash_at(p)
            st[p]["class_hash"] = ch
            print(p, "class_hash:", ch)
        except Exception as e:
            st[p]["class_hash_error"] = str(e)
            print(p, "class_hash error:", e)

    with open(OUT, "w") as f:
        json.dump(out, f, indent=1)
    print("wrote", OUT)

if __name__ == "__main__":
    main()
