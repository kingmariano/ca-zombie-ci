#!/usr/bin/env python3
"""Resume of probe_ve33.py: phases 7-9 (balances, gHYBR, admin map, roles) at the SAME pinned block.
Loads ve33_probe.json and merges results back into it."""
import json, os, sys, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ve33_rpc as rp

D = os.path.dirname(os.path.abspath(__file__))
SIG = json.load(open(os.path.join(D, "sigs.json")))
OUT = os.path.join(D, "ve33_probe.json")
d = json.load(open(OUT))
BLK = d["block"]

def enc(sig, args=()):
    data = SIG[sig]
    for t, v in args:
        if t == "a":
            data += v.lower().replace("0x", "").rjust(64, "0")
        elif t == "u":
            data += f"{v:064x}"
    return data

def enc_str_addr(sig, s, addr):
    sb = s.encode()
    tail = f"{len(sb):064x}" + (sb.hex().ljust(((len(sb) + 31) // 32) * 64, "0") if sb else "")
    return SIG[sig] + f"{0x40:064x}" + addr.lower().replace("0x", "").rjust(64, "0") + tail

def rb(calls, chunk=15):
    params = [("eth_call", [{"to": t, "data": dd}, hex(BLK)]) for t, dd in calls]
    return rp.batch(params, chunk=chunk)

def get_codes(addrs, chunk=12):
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
    off = int.from_bytes(b[0:32], "big")
    ln = int.from_bytes(b[off:off + 32], "big")
    return b[off + 32:off + 32 + ln].decode(errors="replace")

def dec_words(out, n):
    if not out or out == "0x":
        return [None] * n
    b = bytes.fromhex(out[2:])
    return [b[i * 32:(i + 1) * 32] for i in range(min(n, len(b) // 32))]

def main():
    print("resume at block", BLK, flush=True)
    gm = d["gaugeManager"]
    core = d["core"]
    GM = gm["address"]
    ve = gm["_ve()"]; voter = gm["voter()"]; minter = gm["minter()"]; permreg = gm["permissionRegistry()"]
    tokenHandler = gm["tokenHandler()"]; nfpm = gm["nfpm()"]; bribefactory = gm["bribefactory()"]
    rew_dist = core["minter"].get("_rewards_distributor()")
    CLF = core["clFactory"]["address"]
    gauges = sorted(d["gauges"].keys())
    bribes = sorted(d["bribes"].keys())
    GH = "0x348b11cbb801fab12834e66691b7f25fe72b8aa5"
    HYBR = "0x067b0c72aa4c6bd3bfefff443c536dcd6a25a9c8"
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
        "gHYBR": GH, "bribeFactory": bribefactory, "nfpm": nfpm, "clFactory": CLF,
        "clPoolImplementation": core["clFactory"].get("poolImplementation()"),
        "veArtProxy": core["votingEscrow"].get("artProxy()"),
        "minterTeam": core["minter"].get("team()"),
    }

    # ---------- Phase 7: balances ----------
    if "systemBalances" not in d:
        bals = {}
        calls, meta = [], []
        for name, a in sys_addrs.items():
            if not a:
                continue
            for sym, tok in majors.items():
                calls.append((tok, enc("balanceOf(address)", [("a", a)])))
                meta.append((name, sym, tok))
        for g in gauges:
            for sym, tok in majors.items():
                calls.append((tok, enc("balanceOf(address)", [("a", g)])))
                meta.append(("gauge:" + g, sym, tok))
        for b in bribes:
            for sym, tok in majors.items():
                calls.append((tok, enc("balanceOf(address)", [("a", b)])))
                meta.append(("bribe:" + b, sym, tok))
        print("balance calls:", len(calls), flush=True)
        raw = rb(calls, chunk=15)
        for (name, sym, tok), r in zip(meta, raw):
            bals.setdefault(name, {})[sym] = {"token": tok, "amount": dec_u(r) or 0}
        d["systemBalances"] = bals
        json.dump(d, open(OUT, "w"), indent=1)
        print("system balances done", flush=True)

    # ---------- Phase 8: gHYBR ----------
    if "gHYBR" not in d:
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
        d["gHYBR"] = {"address": GH, **gh}
        json.dump(d, open(OUT, "w"), indent=1)
        print("gHYBR done:", json.dumps(gh, default=str), flush=True)

    # ---------- Phase 9: admin map ----------
    if "admin" not in d:
        admin_addrs = {
            "gaugeManager": GM, "clFactory": CLF, "votingEscrow": ve, "voter": voter, "minter": minter,
            "tokenHandler": tokenHandler, "bribeFactory": bribefactory, "nfpm": nfpm, "gHYBR": GH,
            "rewardsDistributor": rew_dist, "hybr": HYBR,
        }
        osigs = ["owner()", "pendingOwner()", "admin()", "governance()"]
        raw = rb([(a, enc(s)) for a in admin_addrs.values() for s in osigs])
        k = 0
        admin = {}
        for name, a in admin_addrs.items():
            dd = {"address": a}
            for s in osigs:
                dd[s] = dec_a(raw[k]); k += 1
            admin[name] = dd
        d["admin"] = admin

        SLOT_IMPL = "0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc"
        SLOT_ADMIN = "0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103"
        proxies = {}
        for a in dict.fromkeys(list(admin_addrs.values()) + [GM, voter, minter, ve, GH]):
            imp = storage(a, SLOT_IMPL)
            adm = storage(a, SLOT_ADMIN)
            impa = "0x" + imp[-40:] if imp and int(imp, 16) != 0 else None
            adma = "0x" + adm[-40:] if adm and int(adm, 16) != 0 else None
            if impa or adma:
                proxies[a] = {"impl": impa, "proxyAdmin": adma}
        d["proxies"] = proxies

        owners = set()
        for name, dd in admin.items():
            for s in osigs:
                if dd.get(s):
                    owners.add(dd[s])
        for key in ("hybraMultisig()", "hybraTeamMultisig()", "emergencyCouncil()"):
            v = core["permissionRegistry"].get(key)
            if v:
                owners.add(v)
        for name in ("gaugeManager_owner",):
            v = core[name].get("owner()")
            if v:
                owners.add(v)
        v = core["clFactory"].get("owner()")
        if v:
            owners.add(v)
        owners.discard("")
        owners = sorted(owners)
        codes = dict(zip(owners, get_codes(owners)))
        admin_codes = {o: (len(c) // 2 - 1) if c and c != "0x" else 0 for o, c in codes.items()}
        d["admin_codes"] = admin_codes

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
                            "nonce": dec_u(getters[3]), "code_size": cs}
        d["safes"] = safes
        json.dump(d, open(OUT, "w"), indent=1)
        print("safes:", json.dumps(safes, indent=1), flush=True)

        role_names = ["GOVERNANCE", "GAUGE_ADMIN", "VOTER_ADMIN", "GENESIS_MANAGER", "BRIBE_ADMIN",
                      "CL_POOL_ADMIN", "EPOCH_MANAGER", "FEE_MANAGER"]
        cands = set(owners)
        for x in ["0xac6182ada71ee9ab2a194da8ae47f5f953e164ca", "0x85046ab2cb184decdfe2e7d7f1b32fc3a953cbe9",
                  GM, ve, voter, minter, GH]:
            cands.add(x)
        cands.discard("")
        cands = sorted(cands)
        calls, meta = [], []
        for rn in role_names:
            for a in cands:
                calls.append((permreg, enc_str_addr("hasRole(bytes,address)", rn, a)))
                meta.append((rn, a))
        raw = rb(calls, chunk=15)
        roles = {}
        for (rn, a), r in zip(meta, raw):
            if dec_u(r):
                roles.setdefault(rn, []).append(a)
        d["roles"] = roles
        d["role_candidates"] = cands
        json.dump(d, open(OUT, "w"), indent=1)
        print("roles:", json.dumps(roles, indent=1), flush=True)

    print("DONE", flush=True)
    print("system balance addresses:", len(d.get("systemBalances", {})), flush=True)

if __name__ == "__main__":
    main()
