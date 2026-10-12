import json, urllib.request, sys
BASE="https://flare-explorer.flare.network/api?module=contract&action=getsourcecode&address="
addrs={
 "proxy_1947":"0x194726F6C2aE988f1Ab5e1C943c17e591a6f6059",
 "impl_a76578":"0xa76578a68a05cede65e6587d60efd2ea4555c6d6",
 "proxy_9067":"0x90679234FE693B39BFdf5642060Cb10571Adc59b",
 "impl_564953":"0x564953d87668514415fb2339ef0834313713e332",
}
for k,a in addrs.items():
    try:
        req=urllib.request.Request(BASE+a, headers={"User-Agent":"Mozilla/5.0"})
        d=json.load(urllib.request.urlopen(req, timeout=30))
        r=d["result"][0]
        out={"name":r.get("ContractName"),"compiler":r.get("CompilerVersion"),"verified":bool(r.get("SourceCode")),"proxy":r.get("Proxy"),"impl":r.get("Implementation"),"abi":json.loads(r["ABI"]) if r.get("ABI") else None}
        json.dump(out, open(f"src_{k}.json","w"), indent=1)
        open(f"src_{k}.sol","w").write(r.get("SourceCode") or "")
        print(k, out["name"], "proxy=",out["proxy"], "impl=",out["impl"], "abi_n=", len(out["abi"]) if out["abi"] else 0)
    except Exception as e:
        print(k,"ERR",e)
