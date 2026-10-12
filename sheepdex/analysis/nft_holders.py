#!/usr/bin/env python3
"""Reconstruct current holders of SheepDex position NFTs (ERC721 at the NFTPositionManager).
ERC721 Transfer has 4 topics (tokenId indexed); ERC20 Transfer has 3 -> filter on topic count.
Adaptive range splitting for RPC 10k result caps."""
import json, os, sys, urllib.request, time
from collections import Counter, defaultdict

RPC = os.environ["BSC_RPC"]
MGR = "0x754ca67efd5951960c43dd78063277ec50a86628"
XFER = "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef"

def rpc(method, params):
    req = urllib.request.Request(RPC, data=json.dumps(
        {"jsonrpc": "2.0", "id": 1, "method": method, "params": params}).encode(),
        headers={"Content-Type": "application/json"})
    for a in range(5):
        try:
            with urllib.request.urlopen(req, timeout=180) as r:
                resp = json.load(r)
            if "error" in resp:
                return {"error": resp["error"]}
            return {"result": resp["result"]}
        except Exception as e:
            time.sleep(2)
    return {"error": {"message": "req failed"}}

def get_logs(start, end, depth=0):
    res = rpc("eth_getLogs", [{"address": MGR, "topics": [XFER],
                               "fromBlock": hex(start), "toBlock": hex(end)}])
    if "error" in res:
        msg = str(res["error"].get("message", ""))
        if ("exceeds max results" in msg or "10000" in msg or "limit" in msg.lower() or "too large" in msg.lower()):
            if end - start < 2 or depth > 25:
                print("  giving up", start, end); return []
            mid = (start + end) // 2
            return get_logs(start, mid, depth+1) + get_logs(mid+1, end, depth+1)
        print("  err:", msg[:100], start, end)
        return []
    return res["result"]

latest = int(rpc("eth_blockNumber", [])["result"], 16)
logs = get_logs(11641289, latest)
print("total Transfer logs at manager:", len(logs))

own = {}
n721 = 0
for lg in logs:
    if len(lg["topics"]) != 4:
        continue  # ERC20 transfer (WBNB etc.)
    n721 += 1
    frm = "0x" + lg["topics"][1][-40:]
    to = "0x" + lg["topics"][2][-40:]
    tid = int(lg["topics"][3], 16)
    if frm == "0x0000000000000000000000000000000000000000":
        own[tid] = to
    elif to == "0x0000000000000000000000000000000000000000":
        own.pop(tid, None)
    else:
        own[tid] = to

print("ERC721 transfer events:", n721, "current NFTs:", len(own))
holders = Counter(own.values())
print("distinct holders:", len(holders))
print("top 40 holders:")
for h, n in holders.most_common(40):
    print(f"  {h} {n}")
json.dump({"latest_block": latest, "nfts": len(own), "holders": dict(holders)},
          open("nft-holders.json", "w"), indent=1)
