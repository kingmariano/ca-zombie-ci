import json, os, urllib.request, sys

R = "https://base.drpc.org"
KEY = os.environ["DRPC_API_KEY"]
def rpc(method, params):
    req = urllib.request.Request(R, data=json.dumps({"jsonrpc":"2.0","id":1,"method":method,"params":params}).encode(),
        headers={"Content-Type":"application/json","X-API-Key":KEY,"User-Agent":"Mozilla/5.0"})
    return json.load(urllib.request.urlopen(req, timeout=60))

addrs = {
 "vault":       "0xD1895f2019c2152FC2b9022D57f19198c4CFCABC",
 "vault_impl":  "0x209d85f0ed5393f8f772d46bf889c251132a68bb",
 "helper":      "0xcdFE91301356da873562EF513828a60dba1F569d",
 "helper_impl": "0x5d7a38144b4d17f47a22e3d0987523cd68b43310",
 "sibling":     "0x416Ec2cA21a38CbCFeAcD6a14532B3F348356d23",
 "sibling_impl":"0x67ed441b2444e055376F4acaBddA969F8926e4EA",
}
out = {}
for name, a in addrs.items():
    code = rpc("eth_getCode", [a, "latest"])["result"]
    out[name] = code
    open(f"code_{name}.hex","w").write(code)
    # print storage slots of proxy impl fields
    if name in ("vault","helper","sibling"):
        # EIP-1967 impl slot
        impl = rpc("eth_getStorageAt", [a, "0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc", "latest"])["result"]
        admin = rpc("eth_getStorageAt", [a, "0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103", "latest"])["result"]
        out[name+"_impl_slot"] = impl
        out[name+"_admin_slot"] = admin
    print(name, len(code)//2-1, "bytes")
print(json.dumps({k:v for k,v in out.items() if k.endswith("_slot")}, indent=1))
