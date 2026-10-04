#!/usr/bin/env python3
"""Walk the live Hybra contract graph on HyperEVM (read-only)."""
import json, sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import hl_rpc as h

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "hybra_discovery.json")

def c(to, sig, args=(), block="latest"):
    return h.call_addr(to, sig, args, block)

def u(to, sig, args=(), block="latest"):
    return h.call_u256(to, sig, args, block)

def s(to, sig, block="latest"):
    return h.call_str(to, sig, block)

def code_size(a):
    try:
        return len(h.get_code(a)) // 2 - 1
    except Exception:
        return -1

BLK = h.block_number()
print("block", BLK)

GM = "0x742caa5ba7c92ca6cfebfd0e73c21739b3b65d5e"
CLF = "0x32b9dA73215255d50D84FeB51540B75acC1324c2"
OWNER = "0xac6182ada71ee9ab2a194da8ae47f5f953e164ca"

out = {"block": BLK, "addresses": {}}

def rec(name, addr, **kw):
    d = {"address": addr, "code_size": code_size(addr)}
    d.update(kw)
    out["addresses"][name] = d
    return d

# --- GaugeManager ---
gm = {
    "voter": c(GM, "voter()"),
    "minter": c(GM, "minter()"),
    "_ve": c(GM, "_ve()"),
    "bribefactory": c(GM, "bribefactory()"),
    "tokenHandler": c(GM, "tokenHandler()"),
    "permissionRegistry": c(GM, "permissionRegistry()"),
    "nfpm": c(GM, "nfpm()"),
    "getHybraGovernor": c(GM, "getHybraGovernor()"),
    "poolsLength": u(GM, "poolsLength()"),
}
# implementation slot
gm["impl_eip1967"] = h.storage(GM, "0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc")
gm["admin_eip1967"] = h.storage(GM, "0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103")
gm["owner"] = c(GM, "owner()")
rec("GaugeManager", GM, **gm)
print("GM", json.dumps(gm, indent=1))

# --- Voter ---
V = gm["voter"]
voter = {
    "permissionRegistry": c(V, "permissionRegistry()"),
    "tokenHandler": c(V, "tokenHandler()"),
    "gaugeManager": c(V, "gaugeManager()"),
    "maxVotingNum": u(V, "maxVotingNum()"),
    "EPOCH_DURATION": u(V, "EPOCH_DURATION()"),
    "totalWeight": u(V, "totalWeight()"),
    "length": u(V, "length()"),
    "owner": c(V, "owner()"),
}
try:
    voter["votingEscrow"] = c(V, "votingEscrow()")
except Exception:
    voter["votingEscrow"] = None
voter["minter"] = c(V, "minter()") if True else None
voter["impl_eip1967"] = h.storage(V, "0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc")
voter["admin_eip1967"] = h.storage(V, "0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103")
rec("VoterV3", V, **voter)
print("Voter", json.dumps(voter, indent=1))

# --- VotingEscrow ---
VE = gm["_ve"]
ve = {
    "token": c(VE, "token()"),
    "voter": c(VE, "voter()"),
    "team": c(VE, "team()"),
    "artProxy": c(VE, "artProxy()"),
    "epoch": u(VE, "epoch()"),
    "supply": u(VE, "supply()"),
    "totalSupply": u(VE, "totalSupply()"),
    "permanentLockBalance": u(VE, "permanentLockBalance()"),
    "name": s(VE, "name()"),
    "symbol": s(VE, "symbol()"),
    "owner": c(VE, "owner()"),
}
ve["impl_eip1967"] = h.storage(VE, "0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc")
ve["admin_eip1967"] = h.storage(VE, "0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103")
rec("VotingEscrow", VE, **ve)
print("VE", json.dumps(ve, indent=1))

# --- Minter ---
M = gm["minter"]
mn = {
    "gaugeManager": c(M, "gaugeManager()"),
    "votingEscrow": c(M, "votingEscrow()") if False else None,
    "team": c(M, "team()"),
    "pendingTeam": c(M, "pendingTeam()"),
    "weekly": u(M, "weekly()"),
    "active_period": u(M, "active_period()"),
    "epochCount": u(M, "epochCount()"),
    "EMISSION": u(M, "EMISSION()"),
    "TAIL_EMISSION": u(M, "TAIL_EMISSION()"),
    "REBASEMAX": u(M, "REBASEMAX()"),
    "teamRate": u(M, "teamRate()"),
    "WEEK": u(M, "WEEK()"),
    "isFirstMint": u(M, "isFirstMint()"),
    "owner": c(M, "owner()"),
}
for k in ("rewardsDistributor", "rewardDistro"):
    try:
        mn[k] = c(M, k + "()")
    except Exception:
        pass
mn["impl_eip1967"] = h.storage(M, "0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc")
rec("MinterUpgradeable", M, **mn)
print("Minter", json.dumps(mn, indent=1))

# --- HYBR / gHYBR ---
HYBR = "0x067b0c72aa4c6bd3bfefff443c536dcd6a25a9c8"
GH = "0x348b11cbb801fab12834e66691b7f25fe72b8aa5"
for nm, a in [("HYBR", HYBR), ("GrowthHYBR", GH)]:
    d = {
        "name": s(a, "name()"),
        "symbol": s(a, "symbol()"),
        "decimals": u(a, "decimals()"),
        "totalSupply": u(a, "totalSupply()"),
        "owner": c(a, "owner()"),
    }
    if nm == "GrowthHYBR":
        for sig in ("asset()", "underlying()", "token()", "want()", "stakingToken()", "ve()", "votingEscrow()"):
            try:
                v = c(a, sig)
                if v:
                    d[sig] = v
            except Exception:
                pass
    rec(nm, a, **d)
    print(nm, json.dumps(d, indent=1))

# --- permissions registry / token handler ---
for nm, a in [("PermissionsRegistry", gm["permissionRegistry"]), ("TokenHandler", gm["tokenHandler"]), ("NFPM", gm["nfpm"]), ("HybraGovernor", gm["getHybraGovernor"]), ("BribeFactory", gm["bribefactory"])]:
    if a:
        rec(nm, a)
        print(nm, a, "codesize", code_size(a))

# --- pools + gauges (first 5 + aggregate) ---
n = min(gm["poolsLength"] or 0, 194)
pools = []
for i in range(n):
    p = c(GM, "pools(uint256)", (i,))
    pools.append(p)
out["pools"] = pools
print("pools read:", len(pools))

# gauge for pool 0..2
gm_info = []
for p in pools[:3]:
    g = c(GM, "gauges(address)", (int(p, 16),))
    if g:
        gm_info.append({
            "pool": p, "gauge": g,
            "internal_bribe": c(GM, "internal_bribes(address)", (int(g, 16),)),
            "external_bribe": c(GM, "external_bribes(address)", (int(g, 16),)),
            "isCLGauge": u(GM, "isCLGauge(address)", (int(g, 16),)),
            "isGauge": u(GM, "isGauge(address)", (int(g, 16),)),
            "isAlive": u(GM, "isAlive(address)", (int(g, 16),)),
        })
out["gauge_samples"] = gm_info
print(json.dumps(gm_info, indent=1))

json.dump(out, open(OUT, "w"), indent=1)
print("saved", OUT)
