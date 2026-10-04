#!/usr/bin/env python3
"""Hybra core: gauge impl discovery + system balance measurement (read-only)."""
import sys, json
sys.path.insert(0, "/home/heisenberg/CA/hyperevm-residuals/analysis")
from hl_rpc import *

GM = "0x742caa5ba7c92ca6cfebfd0e73c21739b3b65d5e"
VE = "0xd7ed7792f71f3920dba01c544639fd546d87f4fd"
MINTER = "0xa8265e40e4cdf6db345861f4fcb75f9cc63e149b"
VOTER = "0x5623f012d15eb828c12fe32e46d40adc2a9e4fa3"
HYBR = "0x067b0c72aa4c6bd3bfefff443c536dcd6a25a9c8"
GHYBR = "0x348b11cbb801fab12834e66691b7f25fe72b8aa5"
EIP1967_IMPL = "0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc"

def main():
    bn = block_number()
    print("block", bn)
    out = {"block": bn}
    # gauge manager getters
    for sig in ["gaugeFactoryCL()", "gaugeImplementation()", "gaugeFactory()", "implementation()", "voter()", "minter()", "_ve()", "bribefactory()"]:
        try:
            r = eth_call(GM, enc_sel(sig), hex(bn))
            if r and r != "0x":
                v = int(r, 16)
                print(sig, ("0x%040x" % v) if len(r) <= 66 and v > 2**40 else v)
                out[sig] = ("0x%040x" % v) if len(r) <= 66 and v > 2**40 else v
        except Exception as e:
            print(sig, "ERR", str(e)[:60])
    # EIP1967 impl of gaugeManager itself
    slot = storage(GM, EIP1967_IMPL, hex(bn))
    print("gaugeManager EIP1967 impl:", slot)
    out["gaugeManager_impl"] = slot
    # balances
    def bal(token, who):
        r = eth_call(token, enc_sel("balanceOf(address)") + who[2:].rjust(64, "0"), hex(bn))
        return int(r, 16) if r and r != "0x" else 0
    out["balances"] = {
        "HYBR_in_VE": bal(HYBR, VE),
        "HYBR_in_Minter": bal(HYBR, MINTER),
        "HYBR_in_Voter": bal(HYBR, VOTER),
        "HYBR_in_gHYBR": bal(HYBR, GHYBR),
        "HYBR_in_GM": bal(HYBR, GM),
        "gHYBR_totalSupply": call_u256(GHYBR, "totalSupply()", (), hex(bn)),
    }
    # gHYBR.totalAssets + veTokenId + locked
    for sig in ["totalAssets()", "veTokenId()", "withdrawFee()", "rHYBR()", "votingEscrow()"]:
        try:
            r = eth_call(GHYBR, enc_sel(sig), hex(bn))
            if r and r != "0x":
                v = int(r, 16)
                out["ghybr_" + sig] = ("0x%040x" % v) if len(r) <= 66 and v > 2**40 else v
                print("gHYBR." + sig, out["ghybr_" + sig])
        except Exception as e:
            print("gHYBR." + sig, "ERR", str(e)[:60])
    # VE totalSupply
    try:
        out["VE_totalSupply"] = call_u256(VE, "totalSupply()", (), hex(bn))
        print("VE.totalSupply", out["VE_totalSupply"])
    except Exception as e:
        print("VE.totalSupply ERR", str(e)[:60])
    # gauges from discovery
    disc = json.load(open("/home/heisenberg/CA/hyperevm-residuals/analysis/hybra_discovery.json"))
    gauges = disc.get("gauges", [])
    g_out = []
    for g in gauges:
        entry = {"pool": g["pool"], "gauge": g["gauge"]}
        try:
            entry["gauge_code"] = len(get_code(g["gauge"]))
            entry["staked_totalSupply"] = call_u256(g["gauge"], "totalSupply()", (), hex(bn))
            slot = storage(g["gauge"], EIP1967_IMPL, hex(bn))
            entry["impl_slot"] = slot
            entry["HYBR_bal"] = bal(HYBR, g["gauge"])
            entry["ibribe"] = g.get("internal_bribe")
            entry["ebribe"] = g.get("external_bribe")
            if g.get("internal_bribe"):
                entry["ibribe_HYBR"] = bal(HYBR, g["internal_bribe"])
                entry["ibribe_WHYPE"] = bal("0x5555555555555555555555555555555555555555", g["internal_bribe"])
            if g.get("external_bribe"):
                entry["ebribe_HYBR"] = bal(HYBR, g["external_bribe"])
                entry["ebribe_WHYPE"] = bal("0x5555555555555555555555555555555555555555", g["external_bribe"])
        except Exception as e:
            entry["err"] = str(e)[:80]
        g_out.append(entry)
    out["gauges"] = g_out
    json.dump(out, open("/home/heisenberg/CA/hyperevm-residuals/analysis/hybra_core_state.json", "w"), indent=1)
    for e in g_out:
        print(json.dumps(e)[:260])

if __name__ == "__main__":
    main()
