#!/usr/bin/env python3
"""H-33 child A: live-value map of Hybra ve33 core, gauges, bribes + admin map.
Read-only JSON-RPC at one pinned block. Output: ve33_probe.json
Safe to re-run; uses unique filenames (not shared with sibling child)."""
import json, os, sys, time, urllib.request
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ve33_rpc as rp

D = os.path.dirname(os.path.abspath(__file__))
SIG = json.load(open(os.path.join(D, "sigs.json")))
OUT = os.path.join(D, "ve33_probe.json")

def enc(sig, args=()):
    data = SIG[sig]
    for t, v in args:
        if t == "a":
            data += v.lower().replace("0x", "").rjust(64, "0")
        elif t == "u":
            data += f"{v:064x}"
    return data

def enc_str(sig, s):
    sb = s.encode()
    tail = f"{len(sb):064x}" + (sb.hex().ljust(((len(sb) + 31) // 32) * 64, "0") if sb else "")
    return SIG[sig] + f"{0x20:064x}" + tail

def enc_str_addr(sig, s, addr):
    sb = s.encode()
    tail = f"{len(sb):064x}" + (sb.hex().ljust(((len(sb) + 31) // 32) * 64, "0") if sb else "")
    return SIG[sig] + f"{0x40:064x}" + addr.lower().replace("0x", "").rjust(64, "0") + tail

BLK = None

def rb(calls, chunk=20):
    """calls: list of (to, data). Returns raw results."""
    params = [("eth_call", [{"to": t, "data": d}, hex(BLK)]) for t, d in calls]
    return rp.batch(params, chunk=chunk)

def get_codes(addrs, chunk=15):
    return rp.batch([("eth_getCode", [a, hex(BLK)]) for a in addrs], chunk=chunk)

def storage(addr, slot):
    return rp.rpc("eth_getStorageAt", [addr, slot, hex(BLK)])

def dec_u(out):
    if not out or out == "0x":
        return None
    return int(out, 16)

def dec_a(out):
    if not out or out == "0x" or len(out) < 42:
        return None
    return "0x" + out[-40:]

def dec_s(out):
    if not out or out == "0x":
        return None
    b = bytes.fromhex(out[2:])
    if len(b) < 64:
        return None
    try:
        off = int.from_bytes(b[0:32], "big")
        ln = int.from_bytes(b[off:off + 32], "big")
        return b[off + 32:off + 32 + ln].decode(errors="replace")
    except Exception:
        return None

def dec_words(out, n):
    if not out or out == "0x":
        return [None] * n
    b = bytes.fromhex(out[2:])
    return [b[i * 32:(i + 1) * 32] for i in range(min(n, len(b) // 32))]

def batch_getter(addrs, sig, args=lambda a: ()):
    """one getter across many addresses"""
    calls = [(a, enc(sig, args(a))) for a in addrs]
    return rb(calls)

def batch_u(addrs, sig, args=lambda a: ()):
    return [dec_u(r) for r in batch_getter(addrs, sig, args)]

def batch_a(addrs, sig, args=lambda a: ()):
    return [dec_a(r) for r in batch_getter(addrs, sig, args)]

def tess(x):
    """token enum-safe"""
    return x

def main():
    global BLK
    BLK = int(rp.rpc("eth_blockNumber", []), 16)
    print("pinned block", BLK)
    res = {"block": BLK, "method": "read-only eth_call/eth_getCode at pinned block; addresses lowercased"}

    # ---------- Phase 1: GaugeManager core ----------
    GM = "0x742caa5ba7c92ca6cfebfd0e73c21739b3b65d5e"
    CLF = "0x32b9da73215255d50d84feb51540b75acc1324c2"
    gmsigs = ["owner()", "minter()", "bribefactory()", "_ve()", "voter()", "tokenHandler()",
              "HybraGovernor()", "nfpm()", "permissionRegistry()", "index()"]
    raw = rb([(GM, enc(s)) for s in gmsigs])
    gm = {s: (dec_a(r) if ")" in s and s != "index()" else dec_u(r)) for s, r in zip(gmsigs, raw)}
    # fix: all are addresses except index()
    gm = {}
    for s, r in zip(gmsigs, raw):
        gm[s] = dec_u(r) if s == "index()" else dec_a(r)
    res["gaugeManager"] = {"address": GM, **gm}
    print("GM:", json.dumps(gm, indent=1))
    json.dump(res, open(OUT, "w"), indent=1)

    ve = gm["_ve()"]; voter = gm["voter()"]; minter = gm["minter()"]; permreg = gm["permissionRegistry()"]
    tokenHandler = gm["tokenHandler()"]; nfpm = gm["nfpm()"]; bribefactory = gm["bribefactory()"]

    # ---------- Phase 2: enumerate GM pools ----------
    pools_gm = []
    i = 0
    misses = 0
    while i < 130:
        part = rb([(GM, enc("pools(uint256)", [("u", j)])) for j in range(i, i + 10)], chunk=10)
        for j, r in zip(range(i, i + 10), part):
            a = dec_a(r)
            if a and int(a, 16) != 0:
                if len(pools_gm) != j:
                    print("NOTE: pools array gap at index", j, "got", a, "have", len(pools_gm))
                pools_gm.append(a)
                misses = 0
            else:
                misses += 1
        i += 10
        if misses >= 20:
            break
    print("raw pools slots probed:", i, "decoded:", len(pools_gm))
    pools_gm = list(dict.fromkeys(pools_gm))
    res["gaugeManager"]["pools_length"] = len(pools_gm)
    print("GM pools:", len(pools_gm))
    json.dump(res, open(OUT, "w"), indent=1)

    # ---------- Phase 3: core system getters ----------
    core = {}

    UINT_S = {"totalSupply()", "supply()", "epoch()", "permanentLockBalance()", "length()", "totalWeight()",
              "maxVotingNum()", "active_period()", "weekly()", "weekly_emission()", "circulating_emission()",
              "calculate_emission()", "EMISSION()", "teamRate()", "REBASEMAX()", "TAIL_EMISSION()", "WEEK()",
              "LOCK()", "rolesLength()", "veTokenId()", "withdrawFee()", "rebase()", "penalty()", "votingYield()",
              "transferLockPeriod()", "lastVoteEpoch()", "index()", "claimable(uint256)", "rewardRate()",
              "DURATION()", "rewardsListLength()", "nonce()", "getThreshold()", "numPools()", "allPoolsLength()",
              "whiteListedTokensLength()", "connectorTokensLength()", "decimals()", "EPOCH_DURATION()"}
    STR_S = {"name()", "symbol()", "VERSION()"}

    def add(name, addr, sigs):
        raw = rb([(addr, enc(s)) for s in sigs]) if addr else [None] * len(sigs)
        no = {}
        for s, r in zip(sigs, raw):
            if s in UINT_S:
                no[s] = dec_u(r)
            elif s in STR_S:
                no[s] = dec_s(r)
            else:
                no[s] = dec_a(r)
        core[name] = {"address": addr, **no}

    add("votingEscrow", ve, ["token()", "voter()", "team()", "artProxy()", "totalSupply()", "supply()",
                             "epoch()", "permanentLockBalance()", "owner()", "name()", "symbol()", "decimals()"])
    add("voter", voter, ["_ve()", "gaugeManager()", "permissionRegistry()", "tokenHandler()", "totalWeight()",
                         "length()", "maxVotingNum()", "EPOCH_DURATION()", "owner()"])
    add("minter", minter, ["_gaugeManager()", "_ve()", "_rewards_distributor()", "team()", "pendingTeam()",
                           "active_period()", "weekly()", "weekly_emission()", "circulating_emission()",
                           "calculate_emission()", "EMISSION()", "teamRate()", "REBASEMAX()", "TAIL_EMISSION()",
                           "WEEK()", "LOCK()", "owner()"])
    add("permissionRegistry", permreg, ["hybraMultisig()", "hybraTeamMultisig()", "emergencyCouncil()",
                                        "rolesLength()"])
    add("tokenHandler", tokenHandler, ["permissionRegistry()", "whiteListedTokensLength()", "connectorTokensLength()"])
    add("clFactory", CLF, ["owner()", "gaugeManager()", "poolImplementation()", "protocolFeeManager()",
                           "swapFeeManager()", "unstakedFeeManager()", "numPools()", "allPoolsLength()"])
    add("nfpm", nfpm, ["owner()", "factory()"])
    add("bribeFactory", bribefactory, ["owner()"])
    add("gaugeManager_owner", GM, ["owner()"])
    print(json.dumps(core, indent=1)[:4000])
    res["core"] = core
    json.dump(res, open(OUT, "w"), indent=1)

    # rewards distributor derived from minter
    rew_dist = core["minter"].get("_rewards_distributor()")
    add("rewardsDistributor", rew_dist, ["owner()", "voting_escrow()", "token()", "depositor()"])
    res["core"] = core

    # ---------- Phase 4: HYBR token + ve locked totals ----------
    HYBR = "0x067b0c72aa4c6bd3bfefff443c536dcd6a25a9c8"
    hybr = {}
    for s, r in zip(["name()", "symbol()", "decimals()", "totalSupply()", "owner()", "minter()"],
                    rb([(HYBR, enc(s)) for s in ["name()", "symbol()", "decimals()", "totalSupply()", "owner()", "minter()"]])):
        if s in ("name()", "symbol()"):
            hybr[s] = dec_s(r)
        elif s == "decimals()":
            hybr[s] = dec_u(r)
        elif s == "totalSupply()":
            hybr[s] = dec_u(r)
        else:
            hybr[s] = dec_a(r) or dec_u(r)
    res["hybr"] = {"address": HYBR, **hybr}
    json.dump(res, open(OUT, "w"), indent=1)

    # ---------- Phase 5: gauges ----------
    hb_pools = json.load(open(os.path.join(D, "hybra_pools.json")))
    gauge_set = set()
    for p in hb_pools:
        g = p.get("gauge()")
        if g and int(g, 16) != 0:
            gauge_set.add(g.lower())
    # from GM pools mapping
    gmap = {}
    raw = rb([(GM, enc("gauges(address)", [("a", p)])) for p in pools_gm])
    for p, r in zip(pools_gm, raw):
        g = dec_a(r)
        if g and int(g, 16) != 0:
            gmap[p] = g
            gauge_set.add(g)
    gauges = sorted(gauge_set)
    res["gauge_count"] = len(gauges)
    print("gauges:", len(gauges))
    json.dump(res, open(OUT, "w"), indent=1)

    ginfo = {}
    codes = get_codes(gauges)
    for g, c in zip(gauges, codes):
        ginfo[g] = {"code_size": (len(c) // 2 - 1) if c and c != "0x" else 0}

    gsigs = ["rewardToken()", "rHYBR()", "VE()", "DISTRIBUTION()", "internal_bribe()", "external_bribe()",
             "clPool()", "poolAddress()", "isForPair()", "emergency()", "rewardRate()", "DURATION()",
             "owner()", "nonfungiblePositionManager()"]
    raw = rb([(g, enc(s)) for g in gauges for s in gsigs])
    k = 0
    for g in gauges:
        for s in gsigs:
            r = raw[k]; k += 1
            if s in ("rewardRate()", "rewardRate()", "DURATION()"):
                ginfo[g][s] = dec_u(r)
            elif s in ("isForPair()", "emergency()"):
                ginfo[g][s] = dec_u(r)
            else:
                ginfo[g][s] = dec_a(r)
    res["gauges"] = ginfo
    json.dump(res, open(OUT, "w"), indent=1)
    print("gauge getters done")

    # gauge token balances: rewardToken (HYBR), rHYBR, token0, token1
    bal_calls = []
    bal_meta = []
    for g in gauges:
        rt = ginfo[g].get("rewardToken()")
        rh = ginfo[g].get("rHYBR()")
        cp = ginfo[g].get("clPool()")
        for tok, tag in ((rt, "rewardToken"), (rh, "rHYBR")):
            if tok:
                bal_calls.append((tok, enc("balanceOf(address)", [("a", g)])))
                bal_meta.append((g, tag, tok))
    # token0/token1 per pool for gauge fee balances
    pools_all = sorted(set([p.lower() for p in pools_gm] + [p["pool"] for p in hb_pools]))
    t01 = {}
    raw = rb([(p, enc("token0()")) for p in pools_all] + [(p, enc("token1()")) for p in pools_all])
    for p, r in zip(pools_all, raw[:len(pools_all)]):
        t01.setdefault(p, {})["token0"] = dec_a(r)
    for p, r in zip(pools_all, raw[len(pools_all):]):
        t01.setdefault(p, {})["token1"] = dec_a(r)
    for g in gauges:
        cp = ginfo[g].get("clPool()")
        if not cp:
            continue
        for tk in ("token0", "token1"):
            tok = t01.get(cp.lower(), {}).get(tk) if cp else None
            if tok:
                bal_calls.append((tok, enc("balanceOf(address)", [("a", g)])))
                bal_meta.append((g, tk, tok))
    raw = rb(bal_calls)
    for (g, tag, tok), r in zip(bal_meta, raw):
        ginfo[g].setdefault("balances", {})[tag] = {"token": tok, "amount": dec_u(r) or 0}
    # gaugeBalances() fees accrued in pool for gauge (token0,token1)
    raw = rb([(g, enc("gaugeBalances()")) for g in gauges])
    for g, r in zip(gauges, raw):
        w = dec_words(r, 2)
        ginfo[g]["gaugeFees"] = [int.from_bytes(x, "big") if x else 0 for x in w]
    # NFPM staked position count + tokenIds
    np_calls = [(nfpm, enc("balanceOf(address)", [("a", g)])) for g in gauges]
    raw = rb(np_calls)
    probs = {}
    for g, r in zip(gauges, raw):
        n = dec_u(r) or 0
        ginfo[g]["nfpm_position_count"] = n
        probs[g] = n
    print("staked positions per gauge sum:", sum(probs.values()))
    res["gauges"] = ginfo
    res["pools"] = {p: t01.get(p) for p in pools_all}
    json.dump(res, open(OUT, "w"), indent=1)

    # ---------- Phase 6: bribes ----------
    bribe_set = set()
    for g in gauges:
        for s in ("internal_bribe()", "external_bribe()"):
            b = ginfo[g].get(s)
            if b and int(b, 16) != 0:
                bribe_set.add(b.lower())
    bribes = sorted(bribe_set)
    print("bribes:", len(bribes))
    binfo = {}
    bcs = get_codes(bribes)
    for b, c in zip(bribes, bcs):
        binfo[b] = {"code_size": (len(c) // 2 - 1) if c and c != "0x" else 0}
    bsigs = ["owner()", "gaugeManager()", "voter()", "minter()", "ve()", "rewardsListLength()", "totalSupply()", "TYPE()"]
    raw = rb([(b, enc(s)) for b in bribes for s in bsigs])
    k = 0
    for b in bribes:
        for s in bsigs:
            r = raw[k]; k += 1
            if s in ("rewardsListLength()", "totalSupply()"):
                binfo[b][s] = dec_u(r)
            elif s == "TYPE()":
                binfo[b][s] = dec_s(r)
            else:
                binfo[b][s] = dec_a(r)
    res["bribes"] = binfo
    json.dump(res, open(OUT, "w"), indent=1)

    # bribe tokens & balances
    bt_calls = []
    bt_meta = []
    for b in bribes:
        n = binfo[b].get("rewardsListLength()") or 0
        for i in range(min(n, 6)):
            bt_calls.append((b, enc("bribeTokens(uint256)", [("u", i)])))
            bt_meta.append((b, i))
    raw = rb(bt_calls)
    for (b, i), r in zip(bt_meta, raw):
        tok = dec_a(r)
        if tok:
            binfo[b].setdefault("tokens", []).append(tok.lower())
    # only unique-preserve
    for b in bribes:
        if "tokens" in binfo[b]:
            binfo[b]["tokens"] = list(dict.fromkeys(binfo[b]["tokens"]))
    bal_calls, bal_meta = [], []
    for b in bribes:
        for tok in binfo[b].get("tokens", []):
            bal_calls.append((tok, enc("balanceOf(address)", [("a", b)])))
            bal_meta.append((b, tok))
    raw = rb(bal_calls)
    for (b, tok), r in zip(bal_meta, raw):
        binfo[b].setdefault("balances", {})[tok] = dec_u(r) or 0
    res["bribes"] = binfo
    json.dump(res, open(OUT, "w"), indent=1)
    print("bribe balances done")

    # ---------- Phase 7: system addresses & major token balances ----------
    majors = {
        "HYBR": HYBR,
        "WHYPE": "0x5555555555555555555555555555555555555555",
        "USDC": "0xb88339cb7199b77e23db6e890353e22632ba630f",
        "USDT0": "0xb8ce59fc3717ada4c02eadf9682a9e934f625ebb",
        "kHYPE": "0xfd739d4e423301ce9385c1fb8850539d657c296d",
        "UBTC": "0x9fdbda0a5e284c32744d2f17ee5c74b284993463",
        "UETH": "0xbe6727b535545c67d5caa73dea54865b92cf7907",
    }
    sys_addrs = {
        "gaugeManager": GM, "votingEscrow": ve, "voter": voter, "minter": minter,
        "permissionRegistry": permreg, "tokenHandler": tokenHandler, "rewardsDistributor": rew_dist,
        "gHYBR": "0x348b11cbb801fab12834e66691b7f25fe72b8aa5",
        "bribeFactory": bribefactory, "nfpm": nfpm, "clFactory": CLF,
        "clPoolImplementation": core["clFactory"].get("poolImplementation()"),
        "veArtProxy": core["votingEscrow"].get("artProxy()"),
        "minterTeam": core["minter"].get("team()"),
    }
    bals = {}
    calls, meta = [], []
    for name, a in sys_addrs.items():
        if not a:
            continue
        for sym, tok in majors.items():
            calls.append((tok, enc("balanceOf(address)", [("a", a)])))
            meta.append((name, sym, tok))
    # gauges and bribes aggregate
    for g in gauges:
        for sym, tok in majors.items():
            calls.append((tok, enc("balanceOf(address)", [("a", g)])))
            meta.append(("gauge:" + g, sym, tok))
    for b in bribes:
        for sym, tok in majors.items():
            calls.append((tok, enc("balanceOf(address)", [("a", b)])))
            meta.append(("bribe:" + b, sym, tok))
    raw = rb(calls, chunk=25)
    for (name, sym, tok), r in zip(meta, raw):
        bals.setdefault(name, {})[sym] = {"token": tok, "amount": dec_u(r) or 0}
    res["systemBalances"] = bals
    json.dump(res, open(OUT, "w"), indent=1)
    print("system balances done")

    # ---------- Phase 8: gHYBR detail ----------
    GH = "0x348b11cbb801fab12834e66691b7f25fe72b8aa5"
    ghsigs = ["HYBR()", "votingEscrow()", "voter()", "rewardsDistributor()", "gaugeManager()", "veTokenId()",
              "operator()", "Team()", "withdrawFee()", "rebase()", "penalty()", "votingYield()",
              "transferLockPeriod()", "lastVoteEpoch()", "totalSupply()", "owner()"]
    raw = rb([(GH, enc(s)) for s in ghsigs])
    gh = {}
    for s, r in zip(ghsigs, raw):
        if s in ("veTokenId()", "withdrawFee()", "rebase()", "penalty()", "votingYield()", "transferLockPeriod()",
                 "lastVoteEpoch()", "totalSupply()"):
            gh[s] = dec_u(r)
        else:
            gh[s] = dec_a(r)
    vid = gh.get("veTokenId()")
    if vid is not None:
        o = dec_a(rb([(ve, enc("ownerOf(uint256)", [("u", vid)]))])[0])
        lw = dec_words(rb([(ve, enc("locked(uint256)", [("u", vid)]))])[0], 2)
        bn = dec_u(rb([(ve, enc("balanceOfNFT(uint256)", [("u", vid)]))])[0])
        gh["veNFT"] = {"tokenId": vid, "ownerOf": o,
                       "locked_amount": int.from_bytes(lw[0], "big", signed=True) if lw[0] else 0,
                       "locked_end": int.from_bytes(lw[1], "big") if len(lw) > 1 and lw[1] else 0,
                       "balanceOfNFT": bn}
    res["gHYBR"] = {"address": GH, **gh}
    json.dump(res, open(OUT, "w"), indent=1)
    print("gHYBR done")

    # ---------- Phase 9: admin map ----------
    admin = {}
    admin_addrs = {
        "gaugeManager": GM, "clFactory": CLF, "votingEscrow": ve, "voter": voter, "minter": minter,
        "tokenHandler": tokenHandler, "bribeFactory": bribefactory, "nfpm": nfpm, "gHYBR": GH,
        "rewardsDistributor": rew_dist, "hybr": HYBR,
    }
    osigs = ["owner()", "pendingOwner()", "admin()", "governance()"]
    raw = rb([(a, enc(s)) for a in admin_addrs.values() for s in osigs])
    k = 0
    for name, a in admin_addrs.items():
        d = {"address": a}
        for s in osigs:
            d[s] = dec_a(raw[k]); k += 1
        admin[name] = d
    # gauge owners and bribe owners already captured.
    # EIP-1967 impl+admin slots for all core + gauges + bribes
    SLOT_IMPL = "0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc"
    SLOT_ADMIN = "0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103"
    proxies = {}
    probe = list(admin_addrs.values()) + gauges[:0] + [bribefactory, tokenHandler]
    for a in dict.fromkeys(probe):
        imp = storage(a, SLOT_IMPL)
        adm = storage(a, SLOT_ADMIN)
        impa = "0x" + imp[-40:] if imp and int(imp, 16) != 0 else None
        adma = "0x" + adm[-40:] if adm and int(adm, 16) != 0 else None
        if impa or adma:
            proxies[a] = {"impl": impa, "proxyAdmin": adma}
    res["proxies"] = proxies
    # code of owner addresses
    owners = set()
    for name, d in admin.items():
        for s in osigs:
            if d.get(s):
                owners.add(d[s])
    for name, d in gm.items():
        pass
    owners.add(core["gaugeManager_owner"].get("owner()") or "")
    owners.add(core["clFactory"]["owner()"] if "owner()" in core["clFactory"] else "")
    owners.add(core["permissionRegistry"]["hybraMultisig()"] or "")
    owners.add(core["permissionRegistry"]["hybraTeamMultisig()"] or "")
    owners.add(core["permissionRegistry"]["emergencyCouncil()"] or "")
    owners.discard("")
    owners.discard(None)
    codes = dict(zip(owners, get_codes(owners)))
    admin_codes = {o: (len(c) // 2 - 1) if c and c != "0x" else 0 for o, c in codes.items()}
    res["admin"] = admin
    res["admin_codes"] = admin_codes
    json.dump(res, open(OUT, "w"), indent=1)
    print("admin map done; owners:", json.dumps(admin_codes, indent=1))

    # Safe details for each contract owner with code
    safes = {}
    for o, cs in admin_codes.items():
        if cs > 0:
            slot0 = storage(o, 0)
            single = dec_a(slot0)
            getters = rb([(o, enc("getOwners()")), (o, enc("getThreshold()")), (o, enc("VERSION()")), (o, enc("nonce()"))])
            owners_list = []
            go = getters[0]
            if go and go != "0x":
                b = bytes.fromhex(go[2:])
                try:
                    off = int.from_bytes(b[0:32], "big")
                    ln = int.from_bytes(b[off:off + 32], "big")
                    for i in range(ln):
                        owners_list.append("0x" + b[off + 32 + i * 32 + 12:off + 32 + (i + 1) * 32].hex())
                except Exception:
                    pass
            safes[o] = {"singleton_slot0": single, "getOwners": owners_list,
                        "getThreshold": dec_u(getters[1]), "VERSION": dec_s(getters[2]),
                        "nonce": dec_u(getters[3]),
                        "code_size": cs}
    res["safes"] = safes
    json.dump(res, open(OUT, "w"), indent=1)
    print("safes:", json.dumps(safes, indent=1))

    # PermissionRegistry roles for key addresses
    role_names = ["GOVERNANCE", "GAUGE_ADMIN", "VOTER_ADMIN", "GENESIS_MANAGER", "BRIBE_ADMIN",
                  "CL_POOL_ADMIN", "EPOCH_MANAGER", "FEE_MANAGER"]
    cands = set(owners)
    for x in ["0xac6182ada71ee9ab2a194da8ae47f5f953e164ca", "0x85046ab2cb184decdfe2e7d7f1b32fc3a953cbe9",
              GM, ve, voter, minter, "0x348b11cbb801fab12834e66691b7f25fe72b8aa5"]:
        cands.add(x)
    cands.discard(None)
    cands.discard("")
    cands = sorted(cands)
    calls, meta = [], []
    for rn in role_names:
        for a in cands:
            calls.append((permreg, enc_str_addr("hasRole(bytes,address)", rn, a)))
            meta.append((rn, a))
    raw = rb(calls, chunk=25)
    roles = {}
    for (rn, a), r in zip(meta, raw):
        v = dec_u(r)
        if v:
            roles.setdefault(rn, []).append(a)
    res["roles"] = roles
    res["role_candidates"] = cands
    json.dump(res, open(OUT, "w"), indent=1)
    print("roles:", json.dumps(roles, indent=1))
    print("saved", OUT)

if __name__ == "__main__":
    main()
