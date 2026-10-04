#!/usr/bin/env python3
"""Walk the live Hybra contract graph v2 (read-only), resilient to reverts."""
import json, sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import hl_rpc as h

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "hybra_discovery.json")

def safe(fn, *a, **kw):
    try:
        v = fn(*a, **kw)
        return v
    except Exception as e:
        return f"REVERT"

def c(to, sig, args=(), block="latest"):
    if not to: return None
    return safe(h.call_addr, to, sig, args, block)
def u(to, sig, args=(), block="latest"):
    if not to: return None
    return safe(h.call_u256, to, sig, args, block)
def s(to, sig, block="latest"):
    if not to: return None
    return safe(h.call_str, to, sig, block)

def code_size(a):
    try:
        return len(h.get_code(a)) // 2 - 1
    except Exception:
        return -1

def impl(proxy):
    v = h.storage(proxy, "0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc")
    if v and int(v, 16) != 0:
        return "0x" + v[-40:]
    return None

BLK = h.block_number()
print("block", BLK)
out = {"block": BLK, "addresses": {}, "pools": [], "gauges": []}

def rec(name, addr, **kw):
    d = {"address": addr, "code_size": code_size(addr)}
    d.update(kw)
    out["addresses"][name] = d
    return d

GM = "0x742caa5ba7c92ca6cfebfd0e73c21739b3b65d5e"
CLF = "0x32b9dA73215255d50D84FeB51540B75acC1324c2"
OWNER = "0xac6182ada71ee9ab2a194da8ae47f5f953e164ca"

gm = {
    "voter": c(GM, "voter()"),
    "minter": c(GM, "minter()"),
    "_ve": c(GM, "_ve()"),
    "bribefactory": c(GM, "bribefactory()"),
    "tokenHandler": c(GM, "tokenHandler()"),
    "permissionRegistry": c(GM, "permissionRegistry()"),
    "nfpm": c(GM, "nfpm()"),
    "getHybraGovernor": c(GM, "getHybraGovernor()"),
    "owner": c(GM, "owner()"),
    "impl_eip1967": impl(GM),
}
rec("GaugeManager", GM, **gm)
print("GM:", json.dumps(gm, indent=1))

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
    "impl_eip1967": impl(V),
}
voter["minter"] = c(V, "minter()")
voter["votingEscrow"] = c(V, "votingEscrow()")
rec("VoterV3", V, **voter)
print("Voter:", json.dumps(voter, indent=1))

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
    "impl_eip1967": impl(VE),
}
ve["tokenName"] = ve.pop("name")
rec("VotingEscrow", VE, **ve)
print("VE:", json.dumps(ve, indent=1))

M = gm["minter"]
mn = {
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
    "impl_eip1967": impl(M),
    "gaugeManager": c(M, "gaugeManager()"),
    "votingEscrow": c(M, "votingEscrow()"),
}
for k in ("rewardsDistributor", "rewardDistro", "rewardDistributor"):
    v = c(M, k + "()")
    if v and not str(v).startswith("REVERT"):
        mn[k] = v
rec("MinterUpgradeable", M, **mn)
print("Minter:", json.dumps(mn, indent=1))

HYBR = "0x067b0c72aa4c6bd3bfefff443c536dcd6a25a9c8"
GH = "0x348b11cbb801fab12834e66691b7f25fe72b8aa5"
for nm, a in [("HYBR", HYBR), ("GrowthHYBR", GH)]:
    d = {"tokenName": s(a, "name()"), "symbol": s(a, "symbol()"), "decimals": u(a, "decimals()"),
         "totalSupply": u(a, "totalSupply()"), "owner": c(a, "owner()")}
    if nm == "GrowthHYBR":
        for sig in ("asset()", "underlying()", "token()", "want()", "stakingToken()",
                    "ve()", "votingEscrow()", "rewardToken()", "rewardsToken()", "minter()"):
            v = c(a, sig)
            if v and not str(v).startswith("REVERT"):
                d[sig] = v
    rec(nm, a, **d)
    print(nm, json.dumps(d, indent=1))

for nm, a in [("PermissionsRegistry", gm["permissionRegistry"]), ("TokenHandler", gm["tokenHandler"]),
              ("NFPM", gm["nfpm"]), ("HybraGovernor", gm["getHybraGovernor"]),
              ("BribeFactory", gm["bribefactory"]), ("CLFactory", CLF), ("OwnerSafe", OWNER)]:
    if a:
        rec(nm, a)
        print(nm, a, "codesize", code_size(a))

# --- pools: enumerate from CLFactory allPoolsLength (194) ---
pools = []
n = u(CLF, "allPoolsLength()")
n = n if isinstance(n, int) else 0
for i in range(n):
    p = c(CLF, "allPools(uint256)", (i,))
    if p and not str(p).startswith("REVERT"):
        pools.append(p)
out["pools"] = pools
print("pools:", len(pools), "of", n)

# --- gauges for first 8 pools ---
for p in pools[:8]:
    g = c(GM, "gauges(address)", (int(p, 16),))
    if not g or str(g).startswith("REVERT"):
        continue
    gd = {
        "pool": p, "gauge": g,
        "internal_bribe": c(GM, "internal_bribes(address)", (int(g, 16),)),
        "external_bribe": c(GM, "external_bribes(address)", (int(g, 16),)),
        "isCLGauge": u(GM, "isCLGauge(address)", (int(g, 16),)),
        "isGauge": u(GM, "isGauge(address)", (int(g, 16),)),
        "isAlive": u(GM, "isAlive(address)", (int(g, 16),)),
        "lastDist": u(GM, "gaugesDistributionTimestmap(address)", (int(g, 16),)),
    }
    out["gauges"].append(gd)
print(json.dumps(out["gauges"], indent=1))

json.dump(out, open(OUT, "w"), indent=1)
print("saved", OUT)
