#!/usr/bin/env python3
"""Phase 3: admin-adjacent code checks, rHYBR, gauge factory, role candidates."""
import json, os, sys
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

def rb(calls, chunk=12):
    return rp.batch([("eth_call", [{"to": t, "data": dd}, hex(BLK)]) for t, dd in calls], chunk=chunk)

def codes(addrs, chunk=12):
    return rp.batch([("eth_getCode", [a, hex(BLK)]) for a in addrs], chunk=chunk)

def du(o):
    return int(o, 16) if o and o != "0x" else None

def da(o):
    return "0x" + o[-40:] if o and o != "0x" and len(o) >= 42 else None

def ds(o):
    if not o or o == "0x":
        return None
    b = bytes.fromhex(o[2:])
    off = int.from_bytes(b[0:32], "big")
    ln = int.from_bytes(b[off:off + 32], "big")
    return b[off + 32:off + 32 + ln].decode(errors="replace")

def main():
    gm = d["gaugeManager"]
    core = d["core"]
    GM = gm["address"]; ve = gm["_ve()"]; voter = gm["voter()"]; minter = gm["minter()"]; permreg = gm["permissionRegistry()"]
    rHYBR = None
    for g, info in d["gauges"].items():
        if info.get("rHYBR()"):
            rHYBR = info["rHYBR()"]; break
    addrs = {
        "swapFeeManager_0x8504": "0x85046ab2cb184decdfe2e7d7f1b32fc3a953cbe9",
        "gaugeOwner_0xeb60": "0xeb60888176d0c6af4c539d64b2e83e470a63e4f9",
        "proxyAdmin_0x85d0": "0x85d0e935d65cf693c8abd51ce24ecb9aef6c1869",
        "safeOwner1": "0x7acdfaac414a35b53105b49030c5736c37e20176",
        "safeOwner2": "0xd34c87fcd179763f38b5824b18d66c9c5dd0dc49",
        "safeOwner3": "0xae3ac83087e03e30804d0b462153ab92127b2c62",
        "gHYBR_operator": "0x8bfab3f44e0e4c98192f5c464e9a11ce3eac9c06",
        "rHYBR": rHYBR,
        "veArtProxy": core["votingEscrow"]["artProxy()"],
        "poolImpl": core["clFactory"]["poolImplementation()"],
        "gaugeManagerImpl": d["proxies"][GM]["impl"],
        "voterImpl": d["proxies"][voter]["impl"],
        "minterImpl": d["proxies"][minter]["impl"],
        "bribeFactoryImpl": d["proxies"][d["gaugeManager"]["bribefactory()"]]["impl"],
    }
    cs = codes([a for a in addrs.values() if a])
    out = {}
    for (name, a), c in zip([(k, v) for k, v in addrs.items() if v], cs):
        out[name] = {"address": a, "code_size": (len(c) // 2 - 1) if c and c != "0x" else 0}
    # getters
    getter_map = {
        "swapFeeManager_0x8504": ["owner()"],
        "gaugeOwner_0xeb60": ["owner()", "permissionsRegistry()", "length()"],
        "proxyAdmin_0x85d0": ["owner()"],
        "rHYBR": ["name()", "symbol()", "totalSupply()", "HYBR()", "owner()", "paused()", "gHYBR()", "fixedConversionRate()"],
    }
    calls, meta = [], []
    for name, sigs in getter_map.items():
        a = addrs.get(name)
        if not a:
            continue
        for s in sigs:
            calls.append((a, enc(s))); meta.append((name, s))
    raw = rb(calls)
    for (name, s), r in zip(meta, raw):
        if s in ("name()", "symbol()"):
            out[name][s] = ds(r)
        elif s == "owner()":
            out[name][s] = da(r)
        else:
            out[name][s] = du(r)
    # rHYBR balances: HYBR backing + totalSupply + where held
    rb_addr = addrs["rHYBR"]
    if rb_addr:
        bals = {}
        holders = {"rHYBR_self": rb_addr, "GM": GM, "minter": minter, "rewardsDistributor": core["minter"]["_rewards_distributor()"],
                   "ve": ve, "gHYBR": "0x348b11cbb801fab12834e66691b7f25fe72b8aa5"}
        raw = rb([(addr, enc("HYBR()")) for addr in holders.values()] + [(rb_addr, enc("balanceOf(address)", [("a", h)])) for h in holders.values()])
        # recover held amounts
        for (k, h), r in zip(holders.items(), raw[len(holders):]):
            bals[k] = du(r) or 0
        out["rHYBR"]["balances"] = bals
        # gauge rHYBR sum
        tot = 0
        for g, info in d["gauges"].items():
            tot += (info.get("balances", {}).get("rHYBR", {}) or {}).get("amount", 0)
        out["rHYBR"]["gauge_rHYBR_sum"] = tot
    d["phase3"] = out
    json.dump(d, open(OUT, "w"), indent=1)
    print(json.dumps(out, indent=1), flush=True)

    # role checks incl. new candidates
    role_names = ["GOVERNANCE", "GAUGE_ADMIN", "VOTER_ADMIN", "GENESIS_MANAGER", "BRIBE_ADMIN",
                  "CL_POOL_ADMIN", "EPOCH_MANAGER", "FEE_MANAGER"]
    cands = set(d.get("role_candidates") or [])
    for a in addrs.values():
        if a:
            cands.add(a)
    cands = sorted(cands)
    calls, meta = [], []
    for rn in role_names:
        for a in cands:
            calls.append((permreg, enc_str_addr("hasRole(bytes,address)", rn, a))); meta.append((rn, a))
    raw = rb(calls)
    roles = {}
    for (rn, a), r in zip(meta, raw):
        if du(r):
            roles.setdefault(rn, []).append(a)
    d["roles_extended"] = roles
    # PermissionRegistry roleToAddresses for each role name
    raw = rb([(permreg, enc_str_addr("hasRole(bytes,address)", "x", permreg)) for _ in [0]])  # noop
    calls = []
    for rn in role_names:
        sb = rn.encode()
        tail = f"{len(sb):064x}" + sb.hex().ljust(((len(sb) + 31) // 32) * 64, "0")
        calls.append((permreg, SIG["roleToAddresses(string)"] + f"{0x20:064x}" + tail))
    raw = rb(calls)
    rta = {}
    for rn, r in zip(role_names, raw):
        if not r or r == "0x":
            continue
        b = bytes.fromhex(r[2:])
        try:
            off = int.from_bytes(b[0:32], "big")
            ln = int.from_bytes(b[off:off + 32], "big")
            lst = []
            for i in range(ln):
                lst.append("0x" + b[off + 32 + i * 32 + 12:off + 32 + (i + 1) * 32].hex())
            rta[rn] = lst
        except Exception as e:
            rta[rn] = "decode-error"
    d["roleToAddresses"] = rta
    json.dump(d, open(OUT, "w"), indent=1)
    print("roleToAddresses:", json.dumps(rta, indent=1), flush=True)
    print("roles_extended:", json.dumps(roles, indent=1), flush=True)

    # Voter.length retry + numPools of CLFactory via allPools? and GM pools length check
    extra = rb([(voter, enc("length()")), (voter, enc("totalWeight()")),
                (GM, enc("index()")), (permreg, enc("rolesLength()"))])
    print("voter.length:", du(extra[0]), "totalWeight:", du(extra[1]), "GM index:", du(extra[2]), "rolesLength:", du(extra[3]), flush=True)

if __name__ == "__main__":
    main()
