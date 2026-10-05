import json, os, urllib.request, time, sys
DRPC="https://base.drpc.org"; DKEY=os.environ["DRPC_API_KEY"]
def rpc(method,params):
    for a in range(3):
        try:
            req=urllib.request.Request(DRPC, data=json.dumps({"jsonrpc":"2.0","id":1,"method":method,"params":params}).encode(),
                headers={"Content-Type":"application/json","X-API-Key":DKEY,"User-Agent":"Mozilla/5.0"})
            r=json.load(urllib.request.urlopen(req,timeout=90))
            if "result" in r or "error" in r: return r
        except Exception as e:
            time.sleep(1)
    raise RuntimeError(method)
IMPL_SLOT="0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc"
ADMIN_SLOT="0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103"
wls=["0xda9884fdd3f37691c9057571e50a5beaf7b92b2f","0xc23cffaaec0f1ceaee6323600e41106225b58c58",
"0x0d0e319054c5a87f4631dd488e37f44d696e4d9b","0xe83cd757f4db55b90321ece5eb64bcac3ea33d17",
"0x891694e3339a441b0985da795f30ed8372e4fcd5","0xdf8be1e693de1c140a59d938ea91d7217daa69e1",
"0x92aafa6be2b1aa1c6c8e98e37f65ceabd6349b8e","0x30b685d855820ff9c3a9da199291296094b67e06",
"0x3683a176b50574e89f1c2d25bd2d9af0ec4111d3","0x59193d6ba7543edb1b14fcdd7de2e9f6644eb022",
"0x97db22602733ebcac13697f73a647ed113a65705","0xcfa6b29ab2d7075cbcd9191351ea9a2df3a05a0f",
"0x31fdc04362cf14959d9296cc2f851d9dcd92a29f","0xb4ec1feab6dc53fb4ea2aad56882ffbcfed16c13"]
out={}
for a in wls:
    impl="0x"+rpc("eth_getStorageAt",[a,IMPL_SLOT,"latest"])["result"][-40:]
    admin="0x"+rpc("eth_getStorageAt",[a,ADMIN_SLOT,"latest"])["result"][-40:]
    c=rpc("eth_getCode",[a,"latest"])["result"]
    out[a]={"code_len":len(c)//2-1,"impl":impl,"admin":admin,
            "impl_code_len":len(rpc("eth_getCode",[impl,"latest"])["result"])//2-1}
    print(a,"code",out[a]["code_len"],"impl",impl,"impl_len",out[a]["impl_code_len"],"admin",admin)
json.dump(out, open("wl_contracts.json","w"), indent=1)
