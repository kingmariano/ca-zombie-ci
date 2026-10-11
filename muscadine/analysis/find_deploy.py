#!/usr/bin/env python3
"""Find contract deployment block via binary search (keyless RPC)."""
import json, urllib.request, sys, time

RPCS = ["https://mainnet.base.org", "https://base.publicnode.com", "https://base.drpc.org"]

def rpc(method, params, tries=4):
    for a in range(tries):
        rpc_url = RPCS[a % len(RPCS)]
        payload = {"jsonrpc":"2.0","id":1,"method":method,"params":params}
        req = urllib.request.Request(rpc_url, data=json.dumps(payload).encode(), headers={"Content-Type":"application/json","User-Agent":"Mozilla/5.0"})
        try:
            out = json.load(urllib.request.urlopen(req, timeout=40))
            if "result" in out: return out["result"]
            print("err:", out.get("error"), file=sys.stderr)
        except Exception as e:
            print(f"  fail {rpc_url}: {e}", file=sys.stderr); time.sleep(1.5)
    return None

def code_at(addr, block):
    return rpc("eth_getCode",[addr, hex(block)])

def find_deploy(addr, lo=1, hi=None):
    if hi is None: hi = int(rpc("eth_blockNumber",[]),16)
    if code_at(addr,hi) in (None,"0x"): return None
    while lo < hi:
        mid = (lo+hi)//2
        c = code_at(addr, mid)
        if c in (None,"0x"): lo = mid+1
        else: hi = mid
    return lo

if __name__ == "__main__":
    addrs = {
     "usdc_prime":"0x89712980cb434ef5ae4ab29349419eb976b0b496",
     "weth_prime":"0xd6dcad2f7da91fbb27bda471540d9770c97a5a43",
     "cbbtc_prime":"0x99dcd0d75822ba398f13b2a8852b07c7e137ec70",
     "usdc_frontier":"0x314fD07319ef645bA7D548915CCd91F4788A1839",
     "usdc_v1":"0xf7e26Fa48A568b8b0038e104DfD8ABdf0f99074F",
     "cbbtc_v1":"0xAeCc8113a7bD0CFAF7000EA7A31afFD4691ff3E9",
     "weth_v1":"0x21e0d366272798da3A977FEBA699FCB91959d120",
    }
    out = {}
    for n,a in addrs.items():
        b = find_deploy(a)
        out[n] = b
        print(n, a, "deployed at", b)
    json.dump(out, open("deploy-blocks.json","w"), indent=1)
