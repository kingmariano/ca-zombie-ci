#!/usr/bin/env python3
"""Check live CLP balances for top pool depositors + cooldown; compute withdrawable amounts."""
import json, os, subprocess, urllib.request, time

RPC = os.environ.get("ARB_RPC", "https://arb1.arbitrum.io/rpc")
outdir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "state")

def sel(sig):
    return subprocess.check_output(["cast", "sig", sig]).decode().strip()

def call(to, sig, arg=None):
    data = sel(sig)
    if arg is not None:
        data += arg.rjust(64, "0")
    payload = [{"jsonrpc": "2.0", "id": 0, "method": "eth_call",
                "params": [{"to": to, "data": data}, "latest"]}]
    req = urllib.request.Request(RPC, data=json.dumps(payload).encode(),
                                 headers={"Content-Type": "application/json", "User-Agent": "Mozilla/5.0"})
    for _ in range(3):
        try:
            d = json.load(urllib.request.urlopen(req, timeout=30))
            return int(d[0]["result"], 16)
        except Exception:
            time.sleep(1)
    return None

SEL_BAL = "getBalance(address)"
SEL_LD = sel("lastDeposited(address)") if False else None  # lastDeposited is private; skip
SEL_SUP = sel("totalSupply()")
SEL_OI = sel("openInterest()")
SEL_UTIL = sel("getUtilization()")

for label, pool, fn in [("ethpool", "0xE0cCd451BB57851c1B2172c07d8b4A7c6952a54e", "logs-ethpool-0xE0cCd451.json"),
                        ("usdcpool", "0x958cc92297e6F087f41A86125BA8E121F0FbEcF2", "logs-usdcpool-0x958cc922.json")]:
    logs = json.load(open(os.path.join(outdir, fn)))
    dep, wd = {}, {}
    for l in logs:
        u = "0x" + l["topics"][1][-40:]
        clp = int(l["data"][66:130], 16)
        if l["_event"] == "Deposit":
            dep[u] = dep.get(u, 0) + clp
        else:
            wd[u] = wd.get(u, 0) + clp
    users = sorted(set(dep) | set(wd), key=lambda u: -(dep.get(u, 0) - wd.get(u, 0)))[:30]
    supply = call(pool, "totalSupply()")
    oi = call(pool, "openInterest()")
    util = call(pool, "getUtilization()")
    print(f"\n== {label} totalSupply={supply} openInterest={oi} util={util}")
    tot = 0
    for u in users:
        arg = u[2:].rjust(64,"0")
        b = call(pool, "getBalance(address)", arg)
        tot += b or 0
        print(f"   {u} getBalance={b} (netFromEvents={dep.get(u,0)-wd.get(u,0)})")
    print(f"   top30 sum={tot} / supply={supply}")
