#!/usr/bin/env python3
"""Read-only: claimant balances for Splice Blast SYs + Wasabi vault holders."""
import json, time, urllib.request

RPCS = ["https://rpc.blast.io", "https://blast.drpc.org", "https://blast-rpc.publicnode.com"]

def rpc_call(rpc, method, params, retries=3, timeout=25):
    body = json.dumps({"jsonrpc": "2.0", "id": 1, "method": method, "params": params}).encode()
    for i in range(retries):
        try:
            req = urllib.request.Request(rpc, data=body, headers={"Content-Type": "application/json", "User-Agent": "Mozilla/5.0"})
            with urllib.request.urlopen(req, timeout=timeout) as r:
                j = json.loads(r.read())
            if "result" in j: return j["result"]
            if "revert" in str(j.get("error", "")).lower(): return "REVERT"
            time.sleep(0.4)
        except Exception:
            time.sleep(0.5)
    return None

def call(to, data):
    for rpc in RPCS:
        r = rpc_call(rpc, "eth_call", [{"to": to, "data": data}, "latest"])
        if r is not None: return r
    return None

def pad(a): return a.lower().replace("0x","").rjust(64,"0")
def bal(tok, who):
    r = call(tok, "0x70a08231" + pad(who))
    return int(r,16) if r and r != "REVERT" else None

SY = {
 "hUSDB": {"sy":"0x13293dacab830d8fa2e0e961fb997b3f37186f46",
           "markets":["0x6b61cfce05aaf44eba5da45def48c0fbd26390a1","0x258133c3ecd19591544c01884227e4ae03f0dbd0"],
           "yt":"0xc878aeb90e6c35d81a8ceaa8dbb89b35aee81c87",
           "vault":"0x390b781BAf1e6Db546cF4e3354b81446947838d2"},
 "hWETH": {"sy":"0xb80ad10dffdd415c2159962c1b35ef6edcf1b505",
           "markets":["0xb9612af20a0143661a695fcb0d176aa2bda2a332","0xaa09cff22452a6d59836b1e2b3820815f52498b8"],
           "yt":"0x22c1c2f9695d0cf8054472ef70510ec7c9640d04",
           "vault":"0x1856C7e0B559E9d7287473CB4b4786398Db4032A"},
 "wUSDB": {"sy":"0xf904fa59d1eacec21d758ccd2fe43261a1dd5470",
           "markets":["0x0f2a202c063bacb9d97bde7f1961c0d941d50351"],
           "yt":"0xaa1ed68628298ac4accf6edf49c501eaa218bbbc",
           "vault":"0x4BeD2A922654cAcC2Be974689619768FaBF24855"},
 "sWETH": {"sy":"0xc28fb4cc69081f9f72c643c47e8fef7b4ab2e7aa",
           "markets":["0xeff6adf7b87ea4c35a642a4b7527c9c44cf805f8"],
           "yt":"0x67f704a8891f46d31b2b7ba3ef767ae29a5b2265",
           "vault":"0x8A444bF22B490fCcee46959678F070256F06729A"},
 "sUSDB": {"sy":"0x0e999eb7f4e553348703d4ed804079c89e8c92f5",
           "markets":["0x9e8ade409ccd53d52325ac50972fcaf68d59409c"],
           "yt":"0x01b62ec2d43ee2865def480fb978ac4d41ca1274",
           "vault":"0x33413CA090fD09127e0c8cA86a1b68ae00209Ae9"},
}
TREASURY = "0x04d440ce29fec9a47ed471ff0dc7d002caadbc66"
HYPER_OWNER = "0x88653cb81db25da4136448bdf561b41b77b052c4"
out = {}
for k, v in SY.items():
    sy = v["sy"]
    rec = {"sy": sy, "vault": v["vault"]}
    rec["sy_totalSupply"] = bal(sy, sy)  # careful: totalSupply call below instead
    r = call(sy, "0x18160ddd"); rec["sy_totalSupply"] = int(r,16) if r and r!="REVERT" else None
    rec["sy_balances"] = {}
    for name, who in [("market1", v["markets"][0]), ("yt", v["yt"]), ("treasury", TREASURY), ("hyper_owner", HYPER_OWNER), ("zero", "0x0000000000000000000000000000000000000000")]:
        rec["sy_balances"][name] = bal(sy, who)
    if len(v["markets"]) > 1:
        rec["sy_balances"]["market2"] = bal(sy, v["markets"][1])
    # vault share balances of the same actors
    rec["vault_share_balances"] = {}
    for name, who in [("sy", sy), ("market1", v["markets"][0]), ("yt", v["yt"]), ("treasury", TREASURY)]:
        rec["vault_share_balances"][name] = bal(v["vault"], who)
    out[k] = rec
    print(k, json.dumps(rec, default=str), flush=True)
json.dump(out, open("/home/heisenberg/CA/splice-finance/analysis/claimants.json","w"), indent=1, default=str)
print("saved")
