#!/usr/bin/env python3
"""Supplementary: internal-vs-external bribe splits, gauge factory proxy, misc checks."""
import json, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ve33_rpc as rp

D = os.path.dirname(os.path.abspath(__file__))
d = json.load(open(os.path.join(D, "ve33_probe.json")))
SIG = json.load(open(os.path.join(D, "sigs.json")))
BLK = d["block"]

def du(o):
    return int(o, 16) if o and o != "0x" else None

def da(o):
    return "0x" + o[-40:] if o and o != "0x" and len(o) >= 42 else None

def main():
    out = {"block": BLK}
    # gauge code sizes
    gs = d["gauges"]
    out["gauge_code_nonzero"] = sum(1 for g in gs.values() if (g.get("code_size") or 0) > 0)
    out["gauge_count"] = len(gs)
    # internal vs external bribe sets
    int_set, ext_set = set(), set()
    for g, info in gs.items():
        i = info.get("internal_bribe()"); e = info.get("external_bribe()")
        if i: int_set.add(i.lower())
        if e: ext_set.add(e.lower())
    out["internal_bribes"] = sorted(int_set)
    out["external_bribes"] = sorted(ext_set)
    out["internal_bribe_count"] = len(int_set)
    out["external_bribe_count"] = len(ext_set)
    bt = {b: d["bribes"].get(b, {}) for b in list(int_set | ext_set)}
    for tag, s in (("internal", int_set), ("external", ext_set)):
        tot = {}
        for b in s:
            for t, amt in (bt[b].get("balances") or {}).items():
                tot[t] = tot.get(t, 0) + amt
        out[tag + "_totals_raw"] = tot
    # gauge factory proxy admin
    gf = "0xeb60888176d0c6af4c539d64b2e83e470a63e4f9"
    SLOT_IMPL = "0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc"
    SLOT_ADMIN = "0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103"
    imp = rp.rpc("eth_getStorageAt", [gf, SLOT_IMPL, hex(BLK)])
    adm = rp.rpc("eth_getStorageAt", [gf, SLOT_ADMIN, hex(BLK)])
    out["gaugeFactoryCL"] = {"address": gf,
                             "impl": "0x" + imp[-40:] if imp and int(imp, 16) else None,
                             "proxyAdmin": "0x" + adm[-40:] if adm and int(adm, 16) else None}
    # rHYBR getter decode as address
    rob = d.get("phase3", {}).get("rHYBR", {})
    out["rHYBR"] = {
        "address": rob.get("address"),
        "name": rob.get("name()"),
        "symbol": rob.get("symbol()"),
        "totalSupply": du(hex(int(rob.get("totalSupply()") or 0))) if rob.get("totalSupply()") is not None else None,
        "HYBR_addr": "0x" + hex(int(rob.get("HYBR()")))[2:].zfill(40) if rob.get("HYBR()") else None,
        "gHYBR_addr": "0x" + hex(int(rob.get("gHYBR()")))[2:].zfill(40) if rob.get("gHYBR()") else None,
        "paused": rob.get("paused()"),
        "fixedConversionRate": rob.get("fixedConversionRate()"),
    }
    # 0x8504 token balances (majors) + selectors guess: check some known getters
    x = "0x85046ab2cb184decdfe2e7d7f1b32fc3a953cbe9"
    majors = {"HYBR": "0x067b0c72aa4c6bd3bfefff443c536dcd6a25a9c8",
              "WHYPE": "0x5555555555555555555555555555555555555555"}
    raw = rp.batch([("eth_call", [{"to": t, "data": SIG["balanceOf(address)"] + x[2:].rjust(64, "0")}, hex(BLK)]) for t in majors.values()])
    out["swapFeeManagerBalances"] = {k: du(v) or 0 for k, v in zip(majors, raw)}
    # Safe nonce again + owners code (EOA check done). GENESIS_MANAGER EOA
    out["genesisManager"] = {"address": "0x752cb4c9189e8beb10fcab5059c31781816530e8",
                             "code_size": 0, "role": "GENESIS_MANAGER"}
    # HYBR allowance from system contracts to GM? (not needed) skip
    # ve epoch timestamp sanity
    out["ve_epoch_raw"] = d["core"]["votingEscrow"]["epoch()"]
    json.dump(out, open(os.path.join(D, "ve33_supp.json"), "w"), indent=1)
    # print compact
    print("gauges", out["gauge_count"], "with code", out["gauge_code_nonzero"])
    print("internal bribes", len(int_set), "external bribes", len(ext_set))
    print("internal totals:", json.dumps(out["internal_totals_raw"], indent=1)[:1200])
    print("external totals:", json.dumps(out["external_totals_raw"], indent=1)[:2500])
    print("gaugeFactoryCL:", json.dumps(out["gaugeFactoryCL"], indent=1))
    print("rHYBR:", json.dumps(out["rHYBR"], indent=1))
    print("swapFeeManager balances:", out["swapFeeManagerBalances"])

if __name__ == "__main__":
    main()
