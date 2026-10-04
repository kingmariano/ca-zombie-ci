#!/usr/bin/env python3
"""Read-only state checks: EthVault, CommonMinter, ORC flows (Ethereum)."""
import json, urllib.request

ETH="https://ethereum-rpc.publicnode.com"
_id=[0]
def rpc(method, params, url=ETH):
    _id[0]+=1
    req=urllib.request.Request(url, data=json.dumps({"jsonrpc":"2.0","id":_id[0],"method":method,"params":params}).encode(),
        headers={"Content-Type":"application/json","User-Agent":"Mozilla/5.0 (X11; Linux x86_64) research/1.0"})
    with urllib.request.urlopen(req, timeout=30) as r:
        d=json.load(r)
    if "error" in d: raise RuntimeError(d["error"])
    return d["result"]

def call(to,data,block="latest"):
    return rpc("eth_call",[{"to":to,"data":data},block])
def u(h): return None if not h or h=="0x" else int(h,16)
def a(h): return None if not h or h=="0x" else "0x"+h[-40:]

VAULT="0x1Bf68A9d1EaEe7826b3593C20a0Ca93293cb489a"
MINTER="0x6BD8E3beEC87176BA9c705c9507Aa5e6F0E6706f"
ORC="0x662b67d00a13faf93254714dd601f5ed49ef2f51"
IMPL_SLOT="0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc"
ADMIN_SLOT="0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103"
EIP1822="0xc5f16f0fcc639fa48a6947836d9850f504798523bf8c9a3a87d5876cf622bcf7"  # implementation slot (mapping)

if __name__=="__main__":
    bn=int(rpc("eth_blockNumber",[]),16)
    print(f"# block {bn}")
    print("== EthVault (proxy) x MultiSigWallet ==")
    for name,sel,dec in [("chain","0x05f5d2f5","s"),("isActivated","0xd0ac6af3","u"),("implementation","0x5c60da1b","a"),
                          ("required","0xdc8452cd","u"),("transactionCount","0x6f2fd1f4","u"),
                          ("depositCount","0x2dfdf0b5","u"),("tetherAddress","0x5c1e9bf5","a"),
                          ("MAX_OWNER_COUNT","0x9b2ea4bd","u")]:
        try:
            r=call(VAULT,sel)
            print(f"  {name:20}", a(r) if dec=="a" else (r if dec=="s" else u(r)))
        except Exception as e:
            print(f"  {name:20} ERR {str(e)[:60]}")
    for name,sel,dec in [("policyAdmin","0x39a66e6b","a"),("feeGovernance","0x1e3117a3","a"),("taxRate","0xcc872e6b","u")]:
        try:
            r=call(VAULT,sel)
            print(f"  impl.{name:16}", a(r) if dec=="a" else u(r))
        except Exception as e:
            print(f"  impl.{name:16} ERR {str(e)[:60]}")
    print("  owners:")
    for i in range(6):
        r=call(VAULT,"0x025e7c27"+hex(i)[2:].rjust(64,"0"))
        o=a(r)
        print(f"    [{i}] {o}")
        if not o: break
    print("== CommonMinter 0x6BD8E3 ==")
    for name,sel,dec in [("implementation","0x5c60da1b","a"),("IMPL_SLOT","0x"+IMPL_SLOT[2:],"slot"),
                          ("isActivated","0xd0ac6af3","u"),("getVersion","0x3c530b3d","s"),
                          ("chain","0x05f5d2f5","s"),("hubContract","0x5c79a76b","a"),
                          ("policyAdmin","0x39a66e6b","a"),("owner","0x8da5cb5b","a"),("required","0xdc8452cd","u")]:
        try:
            if sel=="0x"+IMPL_SLOT[2:]:
                r=rpc("eth_getStorageAt",[MINTER,IMPL_SLOT,"latest"]); print(f"  {name:16} {a(r)}")
            else:
                r=call(MINTER,sel)
                print(f"  {name:16}", a(r) if dec=="a" else (r if dec=="s" else u(r)))
        except Exception as e:
            print(f"  {name:16} ERR {str(e)[:60]}")
    print("== balances of CommonMinter ==")
    for tn,ta,dec in [("ORC",ORC,18),("USDC","0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",6),
                      ("USDT","0xdAC17F958D2ee523a2206206994597C13D831ec7",6),
                      ("WBTC","0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599",8),
                      ("WETH","0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2",18),
                      ("DAI","0x6B175474E89094C44Da98b954EedeAC495271d0F",18)]:
        r=call(ta,"0x70a08231"+MINTER[2:].lower().rjust(64,"0"))
        b=u(r)
        print(f"  {tn:5} {b/10**dec:,.4f}")
    print(f"  ETH   {int(rpc('eth_getBalance',[MINTER,'latest']),16)/1e18:.6f}")
