#!/usr/bin/env python3
"""QC-2 CI evidence dump: Convergence Fi fresh live state at the CI fork block.
Read-only; prints chain data only. No RPC URLs / secrets in output."""
import json, os, urllib.request

def pick_rpc():
    for k in ("FORK_RPC_URL", "BLOCKPI_RPC_URL", "NODEREAL_ETH_RPC_URL", "RPC_URL"):
        u = os.environ.get(k)
        if u:
            return u
    return "https://ethereum-rpc.publicnode.com"

RPC = pick_rpc()
TOWER = "0xB0Afc8363b8F36E0ccE5D54251e20720FfaeaeE7"
BLACKHOLE = "0x21777106355Ba506A31FF7984c0aE5C924deB77f"
MANAGER = "0x7319662aD7D7ce2d1595073EA042B723F6d0dc48"
FACTORY = "0x15A2d42421b62E92fe0ABD22E2aa6caC8Ffa6ec5"
DIST = "0x6B65525a40704a4c48d07c25b8D05654854DFEcD"
CVGSDT_SVC = "0xF941BC649Ef0B20ABd7f6dC78CA8f8E225337933"
CVGSDT = "0x830614aE209FF9d8706d386fcdBc7a55206fcffC"
CLAIMER = "0x539e65190a371cE73244A98DEc42BA635cCa512c"
UTILITIES = "0xD861Ff854206d0Db64f1C0f3108f59576A5CCc04"
CVG_REWARDS = "0xa044fd2E8254eC5DE93B15b8B27d005899579109"
SDCRV_SVC = "0x2FF160bcADb485b5F048b9880e6f471Af632060c"
SDCRV_GAUGE = "0x7f50786A0b15723D741727882ee99a0BF34e3466"

# verified selectors (cast sig, 2026-10-13)
SEL = {
    "getSdtStakings": "0x315c6359",
    "isSdtStaking": "0xd7cb3458",
    "isStakingContract": "0x06df2719",
    "vault": "0xfbfa77cf",
    "buffer": "0xedaafe20",
    "stakingCycle": "0x9d143362",
    "stakingAsset": "0x7776768f",
    "cycleInfo": "0x44f79609",
    "lastUpdatedTimestamp": "0xfbaf894c",
    "governance": "0x5aa6e675",
    "balanceOf": "0x70a08231",
    "allowance": "0xdd62ed3e",
}

def rpc(method, params):
    req = urllib.request.Request(RPC, data=json.dumps({"jsonrpc": "2.0", "id": 1, "method": method, "params": params}).encode(),
                                 headers={"Content-Type": "application/json", "User-Agent": "qc-ci"})
    with urllib.request.urlopen(req, timeout=90) as r:
        return json.load(r)["result"]

def batch(calls):
    out = []
    for i in range(0, len(calls), 10):
        chunk = calls[i:i + 10]
        body = [{"jsonrpc": "2.0", "id": i + j, "method": m, "params": p} for j, (m, p) in enumerate(chunk)]
        req = urllib.request.Request(RPC, data=json.dumps(body).encode(),
                                     headers={"Content-Type": "application/json", "User-Agent": "qc-ci"})
        with urllib.request.urlopen(req, timeout=120) as r:
            res = json.load(r)
        if isinstance(res, dict):
            res = [res]
        m = {x["id"]: x.get("result") for x in res}
        out += [m.get(i + j) for j in range(len(chunk))]
    return out

def u(w): return int(w, 16) if w and w != "0x" else 0
def ad(w): return "0x" + w[-40:] if w and len(w) >= 40 else None
def pad_a(a): return a.lower().replace("0x", "").rjust(64, "0")

IMPL_SLOT = "0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc"

out = {}
blk = u(rpc("eth_blockNumber", []))
out["block"] = blk
out["timestamp"] = u(rpc("eth_getBlockByNumber", [hex(blk), False])["timestamp"])

# 1) proxy impl drift
impls = {}
for name, addr in [("tower", TOWER), ("blackhole", BLACKHOLE), ("manager", MANAGER),
                   ("distributor", DIST), ("factory", FACTORY), ("cvgSdtService", CVGSDT_SVC),
                   ("claimer", CLAIMER)]:
    impls[name] = {"addr": addr, "impl": ad(rpc("eth_getStorageAt", [addr, IMPL_SLOT, "latest"]))}
out["proxy_impls"] = impls

# 2) enumerate services (ABI: (address,string)[])
res = rpc("eth_call", [{"to": TOWER, "data": SEL["getSdtStakings"] + "0" * 64 + hex(1000)[2:].rjust(64, "0")}, "latest"])
data = res[2:]
O = int(data[0:64], 16) * 2  # hex-string index of array data
n = int(data[O:O + 64], 16)
services = []
for i in range(n):
    eo = O + 64 + int(data[O + 64 + i * 64: O + 128 + i * 64], 16) * 2  # tuple hex index
    a = ad(data[eo + 24: eo + 64])
    so = int(data[eo + 64: eo + 128], 16) * 2  # string offset relative to tuple
    spos = eo + so
    slen = int(data[spos: spos + 64], 16)
    name = bytes.fromhex(data[spos + 64: spos + 64 + slen * 2]).decode("utf-8", "replace")
    services.append((a, name))
out["services_count"] = len(services)

svc_rows = []
for a, name in services:
    r = batch([
        ("eth_call", [{"to": a, "data": SEL["stakingAsset"]}, "latest"]),
        ("eth_call", [{"to": a, "data": SEL["stakingCycle"]}, "latest"]),
        ("eth_call", [{"to": a, "data": SEL["buffer"]}, "latest"]),
        ("eth_call", [{"to": a, "data": SEL["vault"]}, "latest"]),
        ("eth_getStorageAt", [a, hex(160), "latest"]),
        ("eth_getStorageAt", [a, hex(161), "latest"]),
    ])
    asset = ad(r[0])
    cycle = u(r[1])
    buffer_ = ad(r[2])
    vault = ad(r[3])
    ci = batch([("eth_call", [{"to": a, "data": SEL["cycleInfo"] + hex(cycle)[2:].rjust(64, "0")}, "latest"]),
                ("eth_call", [{"to": asset, "data": SEL["balanceOf"] + pad_a(BLACKHOLE)}, "latest"])]) if asset else [None, None]
    total = u(ci[0][66:130]) if ci[0] else 0
    bhbal = u(ci[1]) if ci[1] else 0
    svc_rows.append({
        "service": a, "name": name, "asset": asset, "vault": vault, "buffer": buffer_,
        "cycle": cycle, "totalStaked": str(total), "blackholeBalance": str(bhbal),
        "backed": bhbal >= total, "callinfo_addr": ad(r[4]), "callinfo_sig": "0x" + (r[5] or "0x")[2:10],
    })
out["services"] = svc_rows
out["all_backed"] = all(s["backed"] for s in svc_rows)
out["all_callinfo_blackhole_withdraw"] = all(s["callinfo_sig"] == "0xf3fef3a3" for s in svc_rows)

# 3) cvgSDT service callinfo
r = batch([("eth_getStorageAt", [CVGSDT_SVC, hex(160), "latest"]),
           ("eth_getStorageAt", [CVGSDT_SVC, hex(161), "latest"])])
out["cvgSdtSvc_callinfo"] = {"addr": ad(r[0]), "sig": "0x" + (r[1] or "0x")[2:10]}

# 4) registrations
regs = {}
for label, a in [("cvgSdtSvc", CVGSDT_SVC), ("distributor", DIST), ("utilities", UTILITIES),
                 ("claimer", CLAIMER), ("service1", services[0][0] if services else SDCRV_SVC)]:
    r = batch([("eth_call", [{"to": TOWER, "data": SEL["isSdtStaking"] + pad_a(a)}, "latest"]),
               ("eth_call", [{"to": TOWER, "data": SEL["isStakingContract"] + pad_a(a)}, "latest"])])
    regs[label] = {"isSdtStaking": u(r[0]) != 0, "isStakingContract": u(r[1]) != 0}
out["registrations"] = regs

# 5) weekly heartbeat window
last = u(rpc("eth_call", [{"to": CVG_REWARDS, "data": SEL["lastUpdatedTimestamp"]}, "latest"]))
out["heartbeat_lastUpdatedTimestamp"] = last
out["heartbeat_next_window_ts"] = last + 604800 + 28800
out["heartbeat_window_open"] = out["timestamp"] >= out["heartbeat_next_window_ts"]

# 6) claimer governance (UUPS init consumed if non-zero)
out["claimer_governance"] = ad(rpc("eth_call", [{"to": CLAIMER, "data": SEL["governance"]}, "latest"]))

# 7) spot custody allowances (must be 0)
r = batch([
    ("eth_call", [{"to": SDCRV_GAUGE, "data": SEL["allowance"] + pad_a(BLACKHOLE) + pad_a(SDCRV_SVC)}, "latest"]),
    ("eth_call", [{"to": CVGSDT, "data": SEL["allowance"] + pad_a(CVGSDT_SVC) + pad_a(DIST)}, "latest"]),
])
out["spot_allowances_zero"] = {"blackhole_svc1_gauge": u(r[0]) == 0, "cvgSdtSvc_dist_cvgSDT": u(r[1]) == 0}

# 8) distributor holdings snapshot (headline reward pots)
DIST_HOLD = {
    "sdCRV-gauge": "0x7f50786A0b15723D741727882ee99a0BF34e3466",
    "crvUSD": "0xf939E0A03FB07F59A73314E73794Be0E57ac1b4E",
    "CRV": "0xD533a949740bb3306d119CC777fa900bA034cd52",
    "USDT": "0xdAC17F958D2ee523a2206206994597C13D831ec7",
    "cvgSDT": CVGSDT,
    "SDT": "0x73968b9a57c6E53d41345FD57a6E6ae27d6CDB2F",
}
hold = {}
for sym, tok in DIST_HOLD.items():
    hold[sym] = str(u(rpc("eth_call", [{"to": tok, "data": SEL["balanceOf"] + pad_a(DIST)}, "latest"])))
out["distributor_holdings"] = hold

# 9) blackhole headline asset balances
bh = {}
for sym, tok in [("sdCRV-gauge", SDCRV_GAUGE), ("cvgSDT", CVGSDT)]:
    bh[sym] = str(u(rpc("eth_call", [{"to": tok, "data": SEL["balanceOf"] + pad_a(BLACKHOLE)}, "latest"])))
out["blackhole_holdings"] = bh

print(json.dumps(out, indent=1))
os.makedirs("ci-out", exist_ok=True)
json.dump(out, open("ci-out/live-state.json", "w"), indent=1)
