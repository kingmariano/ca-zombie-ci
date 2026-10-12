#!/usr/bin/env python3
"""Robust decompile + constant extraction for all live Lenfi scripts."""
import re, json, sys, os
sys.setrecursionlimit(300000)
import uplc
import uplc.ast as A

import os as _os
D = _os.path.dirname(_os.path.abspath(__file__))
SCRS = {
    "liquidation_v1": "b1259b98f6e4776985fc5a9333717d8c9f1e62744fed8240640461d7",
    "collateral_v1": "2d75e5cf11622d5f68e2b2ef5be50f0027bb7d485e98c881e665676c",
    "request_v2": "d721808a6ca9cb6af91d6d0fac862293f112d659addb8bfdbecb3761",
    "collateral_v2": "31e7527a2972e83de4e4a77750a8acf8225b8247e86d4c400d4a2651",
    "pool_v1": "32e8c0ae314ef4be452c16a999867f66d1a1791fc972cb2f7c74e38d",
    "debt_request_v1": "16ecc417c3ec9a58e4ef07a7e277c1a48289896cd2b0bc69e2b0208d",
    "interest_v1": "92862d28096bed36fb01d36dc4c77214f64630d60bc990db9876f250",
    "leftovers_v1": "8021830afedd85fda1253da2be75b66c0e65c482148eb8ca690903cb",
    "collateral_pool_v1": "9b99fef5ee9a6b170a418999e89edad93bbf55bf1feef57b6053d634",
    "request_v1": "0a5abd03628e0308b63abe546c0d3bd8969faaf46b98d082808b8059",
    "lenfi_stake_holder": "1999507bc0ee90e1c376e608496e624e8645b3d558e244c2cd825a38",
    "debt_request_v2": "34c3e3c66dd2bfcfc2b538c596fa976d3e9be6d5c549d9da8ec28777",
    "lender_nft_policy": "42f0e3706d2e0a0761db8da21387aadabe609a7cf328d249ebc2eeff",
    "borrower_nft_policy": "21ca2902ad0406bc2ce361ad91157b3542544d86d4e3d3e3c43f1763",
}


def walk(term, out):
    if isinstance(term, A.Constant):
        out.append(term)
        return
    if isinstance(term, A.Apply):
        walk(term.f, out); walk(term.x, out)
    elif isinstance(term, A.Lambda):
        walk(term.term, out)
    elif isinstance(term, (A.Force, A.Delay)):
        walk(term.term, out)
    elif isinstance(term, A.Case):
        walk(term.term, out)
        for b in term.branches:
            walk(b, out)
    elif isinstance(term, A.Constr):
        for f in term.fields:
            walk(f, out)


def crepr(v):
    if isinstance(v, A.PlutusData):
        try:
            return "data:" + bytes(v.to_cbor().hex(), "utf-8")
        except Exception:
            import cbor2
            return "data:" + cbor2.dumps(v.to_cbor()).hex()
    if isinstance(v, A.PlutusByteString):
        return "pbytes:" + v.value.hex()
    if isinstance(v, A.PlutusInteger):
        return "pint:" + str(v.value)
    if isinstance(v, A.BuiltinByteString):
        return "bytes:" + bytes(v.value).hex()
    if isinstance(v, A.BuiltinInteger):
        return "int:" + str(int(v.value))
    if isinstance(v, A.BuiltinString):
        return "str:" + str(v.value)
    if isinstance(v, A.BuiltinList):
        return "list:" + repr([crepr(x) for x in v.values])[:200]
    if isinstance(v, A.BuiltinUnit):
        return "unit"
    return type(v).__name__ + ":" + repr(v)[:100]


summary = {}
for n, h in SCRS.items():
    p = f"{D}/script_{n}.hex"
    if not os.path.exists(p):
        continue
    hx = open(p).read().strip()
    try:
        prog = uplc.unflatten(bytes.fromhex(hx))
        txt = uplc.dumps(prog)
        open(f"{D}/uplc_{n}.uplc", "w").write(txt)
        consts = []
        walk(prog.term, consts)
        reps = sorted({crepr(c) for c in consts})
        summary[n] = {"size": len(bytes.fromhex(hx)), "uplc_text_len": len(txt), "consts": reps}
        print(f"===== {n} ({len(bytes.fromhex(hx))}B, uplc {len(txt)} chars) =====")
        for r in reps:
            if r.startswith("int:") or r.startswith("list:"):
                continue
            print("   ", r[:200])
    except Exception as e:
        summary[n] = {"error": f"{type(e).__name__}: {str(e)[:300]}"}
        print(f"===== {n}: DECODE FAILED: {type(e).__name__}: {str(e)[:200]}")
json.dump(summary, open(f"{D}/uplc_constants_full.json", "w"), indent=1)
print("saved uplc_constants_full.json")
