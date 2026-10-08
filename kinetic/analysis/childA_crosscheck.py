#!/usr/bin/env python3
"""Cross-check key enumeration/flags on a second Flare RPC (independent provider)."""
import json, sys
sys.path.insert(0, "/home/heisenberg/CA/kinetic/analysis")
from childA_verify import RPCClient, C, sel, e_addr, d_addr, d_uint, d_bool, d_string, d_addr_array, ok

RPC2 = "https://flare.public-rpc.com"
cli = RPCClient(RPC2)
blk = int(cli.rpc("eth_blockNumber", []), 16)
blkh = hex(blk)
print("# second RPC", RPC2, "block", blk)

out = {"rpc": RPC2, "block": blk, "comptrollers": {}}
calls, keys = [], []
for k, a in C.items():
    calls.append((a, sel("getAllMarkets()"))); keys.append(("markets", k, None))
    calls.append((a, sel("oracle()"))); keys.append(("oracle", k, None))
    calls.append((a, sel("liquidatorsWhitelistVerifier()"))); keys.append(("lwv", k, None))
res = cli.batch(calls, blkh)
for (kind, k, m), r in zip(keys, res):
    d = out["comptrollers"].setdefault(k, {"address": C[k]})
    if kind == "markets":
        d["markets"] = d_addr_array(r)
    elif kind == "oracle":
        d["oracle"] = d_addr(r) if ok(r) else None
    elif kind == "lwv":
        d["lwv"] = d_addr(r) if ok(r) else None

calls, keys = [], []
for k in C:
    for m in out["comptrollers"][k]["markets"]:
        calls.append((m, sel("symbol()"))); keys.append((k, m, "symbol"))
        calls.append((m, sel("totalSupply()"))); keys.append((k, m, "totalSupply"))
        calls.append((m, sel("getCash()"))); keys.append((k, m, "getCash"))
        calls.append((C[k], sel("mintGuardianPaused(address)") + e_addr(m))); keys.append((k, m, "mintPaused"))
        calls.append((C[k], sel("borrowGuardianPaused(address)") + e_addr(m))); keys.append((k, m, "borrowPaused"))
        calls.append((C[k], sel("markets(address)") + e_addr(m))); keys.append((k, m, "markets"))
res = cli.batch(calls, blkh)
mk = {}
for (k, m, kind), r in zip(keys, res):
    d = mk.setdefault((k, m.lower()), {})
    if kind == "symbol":
        d["symbol"] = d_string(r)
    elif kind == "totalSupply":
        d["totalSupply"] = d_uint(r)
    elif kind == "getCash":
        d["getCash"] = d_uint(r)
    elif kind == "mintPaused":
        d["mintPaused"] = d_bool(r)
    elif kind == "borrowPaused":
        d["borrowPaused"] = d_bool(r)
    elif kind == "markets":
        d["isListed"] = d_bool(r, 0)
        d["cf"] = d_uint(r, 1)
out["markets"] = {f"{k}|{m}": v for (k, m), v in mk.items()}

# also spot-check the pinned block on this RPC (if archive window allows)
pin = 71639731
calls = [(C["C1"], sel("getAllMarkets()"))]
res2 = cli.batch(calls, hex(pin))
out["pinned_block_probe"] = {"block": pin, "getAllMarkets_C1_ok": ok(res2[0]),
                             "raw": res2[0]}

with open("/home/heisenberg/CA/kinetic/analysis/childA-crosscheck.json", "w") as f:
    json.dump(out, f, indent=1, sort_keys=True)

# print comparison summary
main = json.load(open("/home/heisenberg/CA/kinetic/analysis/childA-state.json"))
print("counts main:", {k: len(main["comptrollers"][k]["markets"]) for k in C},
      "| second:", {k: len(out["comptrollers"][k]["markets"]) for k in C})
for k in C:
    m1 = [x.lower() for x in main["comptrollers"][k]["markets"]]
    m2 = [x.lower() for x in out["comptrollers"][k]["markets"]]
    same_set = sorted(m1) == sorted(m2)
    same_order = m1 == m2
    print(f"{k}: same_set={same_set} same_order={same_order} oracle={out['comptrollers'][k]['oracle']} lwv={out['comptrollers'][k]['lwv']}")
    if not same_set:
        print("   main:", m1)
        print("   rpc2:", m2)
for key, v in out["markets"].items():
    m1 = main["markets"].get(key.split("|")[1])
    if m1:
        sym_ok = m1["symbol"] == v["symbol"]
        cf_ok = main["flags"][key]["collateralFactorMantissa"] == v["cf"]
        flag_ok = (main["flags"][key]["mintGuardianPaused"] == v["mintPaused"] and
                   main["flags"][key]["borrowGuardianPaused"] == v["borrowPaused"])
        if not (sym_ok and cf_ok and flag_ok):
            print("MISMATCH", key, m1["symbol"], v["symbol"], main["flags"][key]["collateralFactorMantissa"], v["cf"],
                  main["flags"][key]["mintGuardianPaused"], v["mintPaused"])
print("pinned block probe on rpc2:", out["pinned_block_probe"]["getAllMarkets_C1_ok"])
print("crosscheck written")
