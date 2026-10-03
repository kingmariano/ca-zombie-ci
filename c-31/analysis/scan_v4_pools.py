#!/usr/bin/env python3
"""Scan Uniswap v4 PoolManager Initialize logs for pools containing a target currency.
Read-only. Usage: scan_v4_pools.py <rpc> <fromBlock> <toBlock> <tokenAddress> <out.json>
Chunks eth_getLogs into 5000-block ranges (BlockPI limit), batches requests."""
import json, sys, urllib.request, concurrent.futures

RPC = sys.argv[1]; FROM = int(sys.argv[2]); TO = int(sys.argv[3]); TOKEN = sys.argv[4].lower(); OUT = sys.argv[5]
MGR = "0x000000000004444c5dc75cB358380D2e3dE08A90"
TOPIC0 = "0xdd466e674ea557f56295e2d0218a125ea4b4f0f6f3307b95f85e6110838d6438"
TOK = "0x" + TOKEN[2:].rjust(64, "0")
CHUNK = 5000

def get_logs(args):
    frm, to = args
    payload = [{"jsonrpc":"2.0","id":0,"method":"eth_getLogs","params":[{
        "address": MGR, "fromBlock": hex(frm), "toBlock": hex(to),
        "topics": [TOPIC0, TOK]}]},
        {"jsonrpc":"2.0","id":1,"method":"eth_getLogs","params":[{
        "address": MGR, "fromBlock": hex(frm), "toBlock": hex(to),
        "topics": [TOPIC0, None, TOK]}]}]
    req = urllib.request.Request(RPC, data=json.dumps(payload).encode(),
                                 headers={"Content-Type":"application/json","User-Agent":"research"})
    for _ in range(3):
        try:
            r = json.load(urllib.request.urlopen(req, timeout=120))
            out = []
            for x in r:
                if "result" in x and x["result"]:
                    out.extend(x["result"])
            return out
        except Exception as e:
            err = e
    print("chunk failed", frm, to, err, file=sys.stderr)
    return []

ranges = [(b, min(b+CHUNK-1, TO)) for b in range(FROM, TO+1, CHUNK)]
logs = []
with concurrent.futures.ThreadPoolExecutor(max_workers=8) as ex:
    for res in ex.map(get_logs, ranges):
        logs.extend(res)

pools = []
for l in logs:
    # topics: [sig, id, c0, c1]
    c0 = "0x"+l["topics"][2][-40:]
    c1 = "0x"+l["topics"][3][-40:]
    pools.append({"poolId": l["topics"][1], "currency0": c0, "currency1": c1,
                  "block": int(l["blockNumber"],16), "tx": l["transactionHash"]})
# dedupe by poolId
seen={}
for p in pools: seen[p["poolId"]]=p
out = {"token": TOKEN, "from": FROM, "to": TO, "chunks": len(ranges), "pools": list(seen.values())}
json.dump(out, open(OUT,"w"), indent=1)
print(json.dumps(out, indent=1)[:2000])
print("total pools:", len(seen))
