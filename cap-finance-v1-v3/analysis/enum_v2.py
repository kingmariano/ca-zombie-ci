#!/usr/bin/env python3
"""Fetch v2 Trading (0xCAEc6505, 0xbEd32937) order/position events and enumerate current positions."""
import json, os, subprocess, urllib.request, time, sys

key = os.environ["ETHERSCANV2_API_KEY"]
RPC = os.environ.get("ARB_RPC", "https://arb1.arbitrum.io/rpc")
outdir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "state")

TOPICS = {
    "NewOrderV2": "0xe6f0e81a24c1b1c11cfcbbce67e7c5ef361e984c1e4f3528125c93f6f906680d",
    "PositionUpdatedV2": "0x722a60bf2980ad6565c04c8210c55454af895983660b33099a60a0af5e05037b",
    "ClosePositionV2": "0x1eba783f67334e9b95080299c6a95635568b5bf34dbe80586bc9f938307d7b9c",
}

def get_logs(addr, topic0, from_block=0):
    out, page = [], 1
    while True:
        url = (f"https://api.etherscan.io/v2/api?chainid=42161&module=logs&action=getLogs"
               f"&fromBlock={from_block}&toBlock=latest&address={addr}&topic0={topic0}"
               f"&apikey={key}&offset=1000&page={page}")
        req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
        d = json.load(urllib.request.urlopen(req, timeout=60))
        res = d.get("result", [])
        if not isinstance(res, list):
            print("ERR", addr, topic0, d.get("message"), str(res)[:150]); break
        out.extend(res)
        if len(res) < 1000:
            break
        page += 1
        time.sleep(0.2)
    return out

def sel(sig):
    return subprocess.check_output(["cast", "sig", sig]).decode().strip()

def call(to, sig, args_hex=""):
    data = sel(sig) + args_hex
    payload = [{"jsonrpc": "2.0", "id": 0, "method": "eth_call",
                "params": [{"to": to, "data": data}, "latest"]}]
    req = urllib.request.Request(RPC, data=json.dumps(payload).encode(),
                                 headers={"Content-Type": "application/json", "User-Agent": "Mozilla/5.0"})
    for _ in range(3):
        try:
            d = json.load(urllib.request.urlopen(req, timeout=30))
            return d[0].get("result")
        except Exception:
            time.sleep(1)
    return None

def w(x): return x.rjust(64, "0")

for label, addr in [("tradev2a", "0xCAEc650502F15c1a6bFf1C2288fC8F819776B2eC"),
                    ("tradev2b", "0xbEd32937D8A5D1421241F52809908f1a17D75bDb")]:
    fn = os.path.join(outdir, f"v2keys-{label}.json")
    if os.path.exists(fn):
        keys = json.load(open(fn))
        print(f"{label}: cached {len(keys)} keys")
    else:
        keys = set()
        for name, t0 in TOPICS.items():
            logs = get_logs(addr, t0)
            print(f"  {label} {name}: {len(logs)}")
            for l in logs:
                user = "0x" + l["topics"][2][-40:]
                prod = l["topics"][3]
                data = l["data"][2:]
                currency = "0x" + data[24:64]
                isLong = int(data[64:128], 16) == 1
                keys.add((user, prod, currency, isLong))
        keys = sorted(keys)
        json.dump(keys, open(fn, "w"), indent=1)
        print(f"{label}: {len(keys)} unique position keys")
    # query positions
    open_pos, total_margin, settling = [], 0, []
    for (user, prod, cur, isLong) in keys:
        args = w(user[2:]) + prod + w(cur[2:]) + w(1 if isLong else 0)
        r = call(addr, "getPosition(address,address,bytes32,bool)", args)
        if not r or len(r) < 2+64*4:
            continue
        margin = int(r[2+64*1:2+64*2], 16)  # struct: size,margin,timestamp,price
        size = int(r[2:2+64], 16)
        price = int(r[2+64*3:2+64*4], 16)
        if margin > 0:
            open_pos.append({"user": user, "productId": prod, "currency": cur, "isLong": isLong,
                             "size": size, "margin": margin, "price": price})
            total_margin += margin
    print(f"{label}: open positions={len(open_pos)} total margin(8dec)={total_margin}")
    for p in sorted(open_pos, key=lambda x: -x["margin"])[:12]:
        print("   ", p)
    # pending fees
    for cur, name in [("0x"+"0"*40, "ETH"), ("0xff970a61a04b1ca14834a43f5de4533ebddb5cc8", "USDC")]:
        r = call(addr, "getPendingFee(address)", w(cur[2:]))
        print(f"   pendingFee[{name}] = {int(r,16) if r else None}")
    json.dump(open_pos, open(os.path.join(outdir, f"v2open-{label}.json"), "w"), indent=1)
