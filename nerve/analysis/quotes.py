#!/usr/bin/env python3
"""Quote calculations for Nerve pools. Uses RPC from env (BSC_RPC) or a public fallback.
Never writes any keyed URL to disk."""
import json, urllib.request, os

RPC = os.environ.get("BSC_RPC") or "https://bsc-rpc.publicnode.com"

def rpc(m, p):
    req = urllib.request.Request(RPC, data=json.dumps({"jsonrpc":"2.0","id":1,"method":m,"params":p}).encode(),
                                 headers={"Content-Type":"application/json"})
    return json.load(urllib.request.urlopen(req, timeout=45))["result"]

def call(to, data):
    return int(rpc("eth_call", [{"to": to, "data": data}, "latest"]), 16)

def u256(x): return hex(int(x))[2:].rjust(64, "0")
def u8(x): return hex(x)[2:].rjust(64, "0")

def calc_swap(pool, frm, to, dx):
    return call(pool, "0xa95b089f" + u8(frm) + u8(to) + u256(dx))

ETH_POOL = "0x146CD24dCc9f4EB224DFd010c5Bf2b0D25aFA9C0"
BTC_POOL = "0x6C341938bB75dDe823FAAfe7f446925c66E6270c"
POOL3 = "0x1b3771a66ee31180906972580ade9b81afc5fcdc"
P_ETH, P_BTC = 2500.12, 82828.53

def main():
    print("== ETH pool: anyETH(idx1) -> ETH(idx0) [live swap]")
    for amt in [1e18, 5e18, 10e18, 27.91986e18, 36.086631e18, 160.3664976e18, 500e18]:
        out = calc_swap(ETH_POOL, 1, 0, int(amt))
        print(f"  dx={amt/1e18:.4f} anyETH -> {out/1e18:.6f} ETH (${out/1e18*P_ETH:.2f})")
    print("== ETH pool: ETH(idx0) -> anyETH(idx1)")
    out = calc_swap(ETH_POOL, 0, 1, 10**18)
    print(f"  1 ETH -> {out/1e18:.6f} anyETH")
    print("== BTC pool: anyBTC(idx1) -> BTCB(idx0) [live swap]")
    for amt in [0.1e8, 1e8, 1.599212e8, 8.82e8, 100e8]:
        out = calc_swap(BTC_POOL, 1, 0, int(amt))
        print(f"  dx={amt/1e8:.4f} anyBTC -> {out/1e18:.9f} BTCB (${out/1e18*P_BTC:.2f})")
    print("== 3pool round trip 100k USDT -> BUSD -> USDT")
    o1 = calc_swap(POOL3, 1, 0, 100000*10**18)
    o2 = calc_swap(POOL3, 0, 1, o1)
    print(f"  100k USDT -> {o1/1e18:.6f} BUSD -> {o2/1e18:.6f} USDT (loss {100000-o2/1e18:.6f})")
    print("== 3pool single-sided: 100k USDT -> USDC")
    o3 = calc_swap(POOL3, 1, 2, 100000*10**18)
    print(f"  {o3/1e18:.6f} USDC")

if __name__ == "__main__":
    main()
