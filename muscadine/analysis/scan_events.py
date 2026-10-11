#!/usr/bin/env python3
"""Scan governance/approval events on Muscadine VaultV2 vaults + adapters (read-only).
ANKR_API_KEY from env; no key persisted."""
import json, os, sys, time, urllib.request

KEY = os.environ.get("ANKR_API_KEY")
if not KEY: sys.exit("ANKR_API_KEY not set")
RPC = f"https://rpc.ankr.com/base/{KEY}"

def rpc(method, params, tries=5):
    payload = {"jsonrpc":"2.0","id":1,"method":method,"params":params}
    for a in range(tries):
        req = urllib.request.Request(RPC, data=json.dumps(payload).encode(), headers={"Content-Type":"application/json","User-Agent":"Mozilla/5.0"})
        try:
            out = json.load(urllib.request.urlopen(req, timeout=60))
            if "result" in out: return out["result"]
            print("  err:", str(out.get("error"))[:100], file=sys.stderr)
        except Exception as e: print("  fail:", str(e)[:100], file=sys.stderr)
        time.sleep(1.5*(a+1))
    return None

TOPICS = {
 "Approval":"0x8c5be1e5ebec7d5bd14f71427d1e84f3dd0314c0f7b2291e5b200ac8c7c3b925",
 "Submit":"0x8b18afeb361b83b025999ed5b42f1d90c68aaa5a0fd49c015f04c3b8b81e80eb",
 "SetLiquidityAdapterAndData":"0x9deb43d71422af41853c3921fb364b7647f9a9b136e46d66d45c1bf707af706c",
 "SetIsAllocator":"0x74dc60cbc81a9472d04ad1d20e151d369c41104d655ed3f2f3091166a502cd8d",
 "ForceDeallocate":"0x2737eb76574207b36781c9206b573af038d8cd46a4995aa716143770f337b24b",
 "Accept":"0x29aa42fc192ff77ef42105abba283197ac841341e196e417a7fc2784cdc4e5fb",
 "Revoke":"0x70521cf6a7c2458c5ad406081ad7b3bc4afd31b01b586a157a9780fcee6a77cb",
 "BurnShares":"0x82234a83a62d451b7758221f55cd21fe22d35d7798bdfea8a44168fd355880cb",
 "Skim":"0x5e99aaf6d3588fb2497fde044168e8c046704a3223559cfe107f8f94b42cefdd",
}
CONTRACTS = {
 "usdc_prime":   ("0x89712980cb434ef5ae4ab29349419eb976b0b496", 38047058),
 "weth_prime":   ("0xd6dcad2f7da91fbb27bda471540d9770c97a5a43", 38047308),
 "cbbtc_prime":  ("0x99dcd0d75822ba398f13b2a8852b07c7e137ec70", 38048705),
 "usdc_frontier":("0x314fD07319ef645bA7d548915CCd91F4788A1839", 47630549),
 "adapter_usdc_prime":   ("0xC2ec18c8049ab354756304Fb8F9e45e084097972", 38047058),
 "adapter_weth_prime":   ("0xa54d822CD2a3E95A847AcFce2400D0b38205ffD8", 38047308),
 "adapter_cbbtc_prime":  ("0x2eeb629c6F2998842617cb6d1E8167Cc86F44e13", 38048705),
 "adapter_usdc_frontier":("0xD0500CD83eCA6085dcFbE0A052B335F26da71BFd", 47630549),
}
CHUNK = 4_000_000
latest = int(rpc("eth_blockNumber", []), 16)
out = {"latest": latest, "events": {}}
for cname,(addr,deploy) in CONTRACTS.items():
    ev = {}
    for ename, topic in TOPICS.items():
        logs = []
        lo = deploy
        while lo <= latest:
            hi = min(lo+CHUNK-1, latest)
            res = rpc("eth_getLogs", [{"address": addr, "fromBlock": hex(lo), "toBlock": hex(hi), "topics": [topic]}])
            if res is None: sys.exit(f"failed {cname} {ename}")
            logs.extend(res); lo = hi+1; time.sleep(0.25)
        if logs: ev[ename] = logs
    if ev:
        out["events"][cname] = ev
        print(cname)
        for ename, logs in ev.items():
            print(f"  {ename}: {len(logs)} events")
            for lg in logs[-6:]:
                print("    blk", int(lg["blockNumber"],16), "topics", [t[:26] for t in lg["topics"]], "data", lg["data"][:130])
    else:
        print(cname, "-> no events")
json.dump(out, open("events-scan.json","w"), indent=1)
print("saved events-scan.json")
