#!/usr/bin/env python3
"""Scan full Transfer history of Muscadine vault share tokens (read-only).
RPC key comes from ANKR_API_KEY env var; never written to output files."""
import json, os, sys, time, urllib.request

KEY = os.environ.get("ANKR_API_KEY")
if not KEY:
    print("ANKR_API_KEY not set", file=sys.stderr); sys.exit(1)
RPC = f"https://rpc.ankr.com/base/{KEY}"   # keyed: never persist this string
PUBLIC = "https://base.drpc.org"
TRANSFER = "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef"

def rpc_call(method, params, tries=5, rpc=None):
    url = rpc or RPC
    payload = {"jsonrpc":"2.0","id":1,"method":method,"params":params}
    for a in range(tries):
        req = urllib.request.Request(url, data=json.dumps(payload).encode(), headers={"Content-Type":"application/json","User-Agent":"Mozilla/5.0"})
        try:
            out = json.load(urllib.request.urlopen(req, timeout=60))
            if "result" in out: return out["result"]
            print("  err:", str(out.get("error"))[:120], file=sys.stderr)
        except Exception as e:
            print(f"  fail: {str(e)[:120]}", file=sys.stderr)
        time.sleep(2*(a+1))
    return None

VAULTS = {
 "usdc_prime":   ("0x89712980cb434ef5ae4ab29349419eb976b0b496", 38047058),
 "weth_prime":   ("0xd6dcad2f7da91fbb27bda471540d9770c97a5a43", 38047308),
 "cbbtc_prime":  ("0x99dcd0d75822ba398f13b2a8852b07c7e137ec70", 38048705),
 "usdc_frontier":("0x314fD07319ef645bA7d548915CCd91F4788A1839", 47630549),
 "usdc_v1":      ("0xf7e26Fa48A568b8b0038e104DfD8ABdf0f99074F", 31145260),
 "cbbtc_v1":     ("0xAeCc8113a7bD0CFAF7000EA7A31afFD4691ff3E9", 31221017),
 "weth_v1":      ("0x21e0d366272798da3A977FEBA699FCB91959d120", 31221149),
}
CHUNK = 4_000_000

latest = int(rpc_call("eth_blockNumber", []), 16)
print("latest block:", latest)

out = {"latest_block": latest, "vaults": {}}
for name,(addr, deploy) in VAULTS.items():
    print("="*20, name, addr, "deploy", deploy)
    logs = []
    lo = deploy
    while lo <= latest:
        hi = min(lo + CHUNK - 1, latest)
        res = rpc_call("eth_getLogs", [{"address": addr, "fromBlock": hex(lo), "toBlock": hex(hi), "topics": [TRANSFER]}])
        if res is None:
            print("  !! failed chunk", lo, hi, file=sys.stderr); sys.exit(2)
        logs.extend(res)
        print(f"  chunk {lo}-{hi}: {len(res)} logs (total {len(logs)})")
        lo = hi + 1
        time.sleep(0.4)
    # aggregate
    bal = {}
    transfers = []
    for lg in logs:
        f = "0x"+lg["topics"][1][-40:]
        t = "0x"+lg["topics"][2][-40:]
        v = int(lg["data"], 16)
        bal[f] = bal.get(f,0) - v
        bal[t] = bal.get(t,0) + v
        transfers.append({"b": int(lg["blockNumber"],16), "tx": lg["transactionHash"], "f": f, "t": t, "v": str(v)})
    holders = {k:v for k,v in bal.items() if v > 0}
    out["vaults"][name] = {"address": addr, "deploy": deploy, "n_transfers": len(logs), "holders": holders, "transfers": transfers}
    json.dump(out, open("transfers-raw.json","w"), indent=1)
    top = sorted(holders.items(), key=lambda kv:-kv[1])[:15]
    print("  current holders (from full history):")
    for a,v in top: print("   ", a, v)
    # verify total
    ts = rpc_call("eth_call", [{"to": addr, "data": "0x18160ddd"}, "latest"], rpc=PUBLIC)
    print("  totalSupply on-chain:", int(ts,16) if ts else None)
    # verify top holder balances on-chain
    for a,v in top[:5]:
        data = "0x70a08231" + a.lower().replace("0x","").rjust(64,"0")
        b = rpc_call("eth_call", [{"to": addr, "data": data}, "latest"], rpc=PUBLIC)
        onchain = int(b,16) if b else None
        match = "OK" if onchain == v else "MISMATCH"
        print(f"    verify {a}: computed {v} onchain {onchain} {match}")
    time.sleep(0.5)

json.dump(out, open("transfers-raw.json","w"), indent=1)
print("saved transfers-raw.json")
