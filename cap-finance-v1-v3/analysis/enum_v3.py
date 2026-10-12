#!/usr/bin/env python3
"""Enumerate Cap v3 (0x9BC357bc) stakes 1..nextStakeId-1 and positions 1..nextPositionId-1.
Read-only via public RPC (batched eth_call). Output: analysis/state/v3-stakes.json, v3-positions.json"""
import json, os, urllib.request, time

RPC = os.environ.get("ARB_RPC", "https://arb1.arbitrum.io/rpc")
TRADE = "0x9BC357bc5b312AaCD41a84F3C687F031B8786853"
outdir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "state")
os.makedirs(outdir, exist_ok=True)

def rpc_batch(calls):
    payload = [{"jsonrpc": "2.0", "id": i, "method": "eth_call",
                "params": [{"to": c[0], "data": c[1]}, "latest"]} for i, c in enumerate(calls)]
    req = urllib.request.Request(RPC, data=json.dumps(payload).encode(),
                                 headers={"Content-Type": "application/json", "User-Agent": "Mozilla/5.0"})
    for attempt in range(4):
        try:
            d = json.load(urllib.request.urlopen(req, timeout=60))
            out = [None] * len(calls)
            for item in d:
                out[item["id"]] = item.get("result")
            return out
        except Exception as e:
            last = e
            time.sleep(2)
    raise last

# selectors (computed with cast sig):
# getStakes(uint256[]) -> 0x...
# getPositions(uint256[]) -> 0x...
import subprocess
def sel(sig):
    return subprocess.check_output(["cast", "sig", sig]).decode().strip()

SEL_STAKES = sel("getStakes(uint256[])")
SEL_POS = sel("getPositions(uint256[])")
print("selectors", SEL_STAKES, SEL_POS)

# encode uint256[] arg (with offset word for a single dynamic arg)
def enc_array(vals):
    n = len(vals)
    offset = hex(0x20)[2:].rjust(64, "0")
    return offset + hex(n)[2:].rjust(64, "0") + "".join(hex(v)[2:].rjust(64, "0") for v in vals)

# stakes 1..51
stake_ids = list(range(1, 52))
data = SEL_STAKES + enc_array(stake_ids)
res = rpc_batch([(TRADE, data)])[0]
open("state-raw-stakes.json", "w").write(json.dumps(res))
print("stakes raw len", len(res) if res else None)

# decode: (address,uint64,uint32)[]  -> head offset, then array
def dec_tuple_array(hexstr, types):
    b = bytes.fromhex(hexstr[2:])
    off = int.from_bytes(b[0:32], "big")
    n = int.from_bytes(b[off:off+32], "big")
    out = []
    base = off + 32
    for i in range(n):
        item = {}
        vals = []
        for j, t in enumerate(types):
            v = int.from_bytes(b[base + i*32*len(types) + j*32: base + i*32*len(types) + (j+1)*32], "big")
            vals.append(v)
        out.append(vals)
    return out

stakes = dec_tuple_array(res, ["address", "uint64", "uint32"])
live = []
for i, s in enumerate(stakes):
    owner = "0x" + hex(s[0])[2:].rjust(40, "0")
    amt = s[1]
    ts = s[2]
    if amt > 0:
        live.append({"stakeId": i+1, "owner": owner, "amount": amt, "timestamp": ts})
print("live stakes:", len(live), "total amount:", sum(x["amount"] for x in live)/1e8)
for x in live:
    print("  ", x)
json.dump(live, open(os.path.join(outdir, "v3-stakes.json"), "w"), indent=1)

# positions 1..3918 in chunks of 400
POS_TYPES = ["uint64", "uint64", "uint64", "uint64", "address", "uint80", "bool", "bool"]
allpos = []
chunk = 400
for start in range(1, 3919, chunk):
    ids = list(range(start, min(start+chunk, 3919)))
    data = SEL_POS + enc_array(ids)
    r = rpc_batch([(TRADE, data)])[0]
    arr = dec_tuple_array(r, POS_TYPES)
    for i, p in enumerate(arr):
        allpos.append({
            "positionId": ids[i], "productId": p[0], "leverage": p[1], "price": p[2],
            "margin": p[3], "owner": "0x" + hex(p[4])[2:].rjust(40, "0"),
            "timestamp": p[5], "isLong": bool(p[6]), "isSettling": bool(p[7]),
        })
    print(f"chunk {start}: decoded {len(arr)}")
    time.sleep(0.3)

open_pos = [p for p in allpos if p["margin"] > 0]
print("positions with margin>0:", len(open_pos), "total margin:", sum(p["margin"] for p in open_pos)/1e8)
json.dump(allpos, open(os.path.join(outdir, "v3-positions.json"), "w"), indent=1)
json.dump(open_pos, open(os.path.join(outdir, "v3-open-positions.json"), "w"), indent=1)
print("saved")
