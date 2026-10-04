#!/usr/bin/env python3
"""Measure HYBR / gHYBR / rHYBR balances across Hybra core contracts + gauge/bribe enumeration (read-only)."""
import json, sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import hl_rpc as h

BLK = h.block_number()
print("block", BLK)
GM = "0x742caa5ba7c92ca6cfebfd0e73c21739b3b65d5e"
CLF = "0x32b9dA73215255d50D84FeB51540B75acC1324c2"
V = "0x5623f012d15eb828c12fe32e46d40adc2a9e4fa3"
M = "0xa8265e40e4cdf6db345861f4fcb75f9cc63e149b"
VE = "0xd7ed7792f71f3920dba01c544639fd546d87f4fd"
GH = "0x348b11cbb801fab12834e66691b7f25fe72b8aa5"
R = "0x6879db7e84c38e5f580b464d2f19e91e09f4bc98"
RD = "0x04fcae9af38e79b7bb96d4f2ef0f020e9c8739a9"
HYBR = "0x067b0c72aa4c6bd3bfefff443c536dcd6a25a9c8"
SAFE = "0xac6182ada71ee9ab2a194da8ae47f5f953e164ca"
PA = "0x85d0e935d65cf693c8abd51ce24ecb9aef6c1869"  # proxy admin

def bal(token, addr):
    try:
        return h.call_u256(token, "balanceOf(address)", (int(addr, 16),), hex(BLK))
    except Exception:
        return None

def total(token):
    try:
        return h.call_u256(token, "totalSupply()", (), hex(BLK))
    except Exception:
        return None

out = {"block": BLK, "hybr_balances": {}, "ghybr_balances": {}, "rhybr_balances": {}, "supply": {}}
core = {"GaugeManager": GM, "Voter": V, "Minter": M, "VotingEscrow": VE, "GrowthHYBR": GH,
        "RewardHYBR": R, "RewardsDistributor": RD, "CLFactory": CLF, "OwnerSafe": SAFE, "ProxyAdmin": PA}
for nm, a in core.items():
    out["hybr_balances"][nm] = bal(HYBR, a)
    out["ghybr_balances"][nm] = bal(GH, a)
    out["rhybr_balances"][nm] = bal(R, a)
for nm, a in [("HYBR", HYBR), ("gHYBR", GH), ("rHYBR", R)]:
    out["supply"][nm] = total(a)
print(json.dumps(out, indent=1))

# ve state
out["ve"] = {
    "supply": h.call_u256(VE, "supply()", (), hex(BLK)),
    "epoch": h.call_u256(VE, "epoch()", (), hex(BLK)),
    "gHYBR_veTokenId": h.call_u256(GH, "veTokenId()", (), hex(BLK)),
}
# locked amount of gHYBR veNFT: locked(uint256) returns (int128 amount, uint256 end, bool isPermanent)
try:
    raw = h.eth_call(VE, "0x4b9b3b41" + f"{36461:064x}", hex(BLK))
    out["ve"]["locked_36461_raw"] = raw
except Exception as e:
    out["ve"]["locked_36461_raw"] = str(e)
print(json.dumps(out["ve"], indent=1))

# enumerate gauges over all pools
pools = json.load(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "hybra_discovery.json")))["pools"]
gauges = []
seen = set()
for p in pools:
    try:
        g = h.call_addr(GM, "gauges(address)", (int(p, 16),), hex(BLK))
    except Exception:
        continue
    if g and g not in seen:
        seen.add(g)
        try:
            ib = h.call_addr(GM, "internal_bribes(address)", (int(g, 16),), hex(BLK))
            eb = h.call_addr(GM, "external_bribes(address)", (int(g, 16),), hex(BLK))
        except Exception:
            ib = eb = None
        gauges.append({"pool": p, "gauge": g, "ib": ib, "eb": eb})
out["n_gauges"] = len(gauges)
out["gauges"] = gauges

tot_h = 0; tot_gh = 0; tot_rh = 0
for gd in gauges:
    b = bal(HYBR, gd["gauge"]); b = b or 0
    gh = bal(GH, gd["gauge"]); gh = gh or 0
    rh = bal(R, gd["gauge"]); rh = rh or 0
    gd["hybr"] = b; gd["ghybr"] = gh; gd["rhybr"] = rh
    tot_h += b; tot_gh += gh; tot_rh += rh
    for k in ("ib", "eb"):
        if gd[k]:
            gd[k + "_hybr"] = bal(HYBR, gd[k]) or 0
            gd[k + "_ghybr"] = bal(GH, gd[k]) or 0
out["gauge_totals"] = {"hybr": tot_h, "ghybr": tot_gh, "rhybr": tot_rh}
print("gauge totals:", out["gauge_totals"])
print("n_gauges", len(gauges))
json.dump(out, open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "hybra_balances.json"), "w"), indent=1)
print("saved hybra_balances.json")
