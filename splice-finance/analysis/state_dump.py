#!/usr/bin/env python3
"""Read-only live-state dump for Splice Finance (Blast + Mode). Public keyless RPCs. No transactions."""
import json, sys, time, urllib.request, urllib.error, os

RPCS = {
    "blast": [os.environ.get("BLAST_RPC_URL") or "https://rpc.blast.io", "https://blast.drpc.org", "https://blast-rpc.publicnode.com"],
    "mode":  [os.environ.get("MODE_RPC_URL") or "https://mainnet.mode.network", "https://1rpc.io/mode", "https://mode.drpc.org"],
}
FACTORIES = {
    "blast": [
        ("blast-factory-1", "0x96A6C433078059577F0CEB707d596A5F81d64375", 1850297),
        ("blast-factory-2", "0xf87E18913f7143E7C7eFee714813ABbC8e0E34bf", 1850297),
    ],
    "mode": [
        ("mode-factory", "0x9e6d12097339ddd5402FDD39fc0Ef86Eec54AB39", 7764229),
    ],
}
# Market (market, PT) pairs recovered via Etherscan V2 getLogs (topic0 CreateNewMarket) when the
# public RPC refuses the 40M-block range. Read-only; recorded in analysis/etherscan_logs/.
BLAST_MARKETS = {
    "0x96A6C433078059577F0CEB707d596A5F81d64375": [
        ("0xb9612af20a0143661a695fcb0d176aa2bda2a332","0xd4154f0175f5423de93dd1e1499f3a6801465375",1850300),
        ("0x6b61cfce05aaf44eba5da45def48c0fbd26390a1","0x1cde6a099a1cb14f3093d2b7cb5b7cbb2145cb64",1850303),
        ("0xaa09cff22452a6d59836b1e2b3820815f52498b8","0xd4154f0175f5423de93dd1e1499f3a6801465375",1969108),
        ("0x258133c3ecd19591544c01884227e4ae03f0dbd0","0x1cde6a099a1cb14f3093d2b7cb5b7cbb2145cb64",1969111),
        ("0x89bb9e39e497a9f42e67f9c9f32fcc1183d0c5d8","0x9eb1009bd8bc4cc6c8037acc032a0cdf2b1a3048",2309714),
        ("0x92523143fc87ef79fd8a4461574fb0c07611d1fc","0x93040d9775770a478370aea9f6048fe350e65544",2323062),
    ],
    "0xf87E18913f7143E7C7eFee714813ABbC8e0E34bf": [
        ("0x0f2a202c063bacb9d97bde7f1961c0d941d50351","0xad7e37c1820f314374c6bf5f81e6bcf1e29ae4ba",4988726),
        ("0xeff6adf7b87ea4c35a642a4b7527c9c44cf805f8","0x57a367871f7b331f4868c584181d42152d86d9b2",5509976),
        ("0x9e8ade409ccd53d52325ac50972fcaf68d59409c","0x0fdf90a6ded0611b39e1b0ffd691005077f58fe8",5510045),
    ],
}
TOPIC = "0xae811fae25e2770b6bd1dcb1475657e8c3a976f91d1ebf081271db08eef920af"
SEL = {
 "totalSupply":"0x18160ddd","balanceOf":"0x70a08231","decimals":"0x313ce567","symbol":"0x95d89b41","name":"0x06fdde03",
 "assetInfo":"0xa40bee50","exchangeRate":"0x3ba0b9a9","yieldToken":"0x76d5de85","owner":"0x8da5cb5b","paused":"0x5c975abb",
 "expiry":"0xe184c9be","SY":"0xafd27bf5","YT":"0x781c18db","PT":"0xd94073d4","readTokens":"0x2c8ce6bc",
 "getMarketConfig":"0x5c098c11","treasury":"0x61d027b3","pyIndexStored":"0xd2a3584e","syReserve":"0x4ba6dcd7",
 "getPostExpiryData":"0x0b49fcef","isExpired":"0x2f13b60c","totalAssets":"0x01e1d114","convertToAssets":"0x07a2d13a",
 "asset":"0x38d52e0f","previewRedeem":"0x4cdad506","factory":"0xc45a0155",
}
def rpc_call(rpc, method, params, retries=4, timeout=45):
    body=json.dumps({"jsonrpc":"2.0","id":1,"method":method,"params":params}).encode()
    last=None
    for i in range(retries):
        try:
            req=urllib.request.Request(rpc,data=body,headers={"Content-Type":"application/json","User-Agent":"Mozilla/5.0"})
            with urllib.request.urlopen(req,timeout=timeout) as r: j=json.loads(r.read())
            if "result" in j: return j["result"]
            last=str(j.get("error"))[:150]
            if "revert" in last.lower(): return "REVERT"
            time.sleep(0.6)
        except Exception as e:
            last=str(e)[:120]; time.sleep(0.8)
    return None
def call(rpc,to,data):
    return rpc_call(rpc,"eth_call",[{"to":to,"data":data},"latest"])
def words(hexs):
    h=hexs[2:] if hexs.startswith("0x") else hexs
    return [h[i:i+64] for i in range(0,len(h),64)] if h else []
def addr(w): return "0x"+w[-40:].lower()
def uint(w): return int(w,16)
def pad(a): return a.lower().replace("0x","").rjust(64,"0")
def dec_str(hexs):
    w=words(hexs)
    if not w: return ""
    if len(w)>=3:
        try:
            off=uint(w[0])//32; ln=uint(w[off]) if off<len(w) else 0
            data="".join(w[off+1:off+1+(ln+31)//32])[:ln*2]
            return bytes.fromhex(data).decode("utf-8","replace").strip("\x00")
        except Exception: return ""
    return ""
def u(rpc,to,sel):
    r=call(rpc,to,sel)
    return uint(r[2:]) if r and r!="REVERT" and r is not None else None
def a(rpc,to,sel):
    r=call(rpc,to,sel)
    return addr(r) if r and r!="REVERT" and r is not None else None

def main():
    out={"generated_at":time.strftime("%Y-%m-%dT%H:%M:%SZ",time.gmtime()),"chains":{}}
    for chain,rpcs in RPCS.items():
        rpc=None
        for u_ in rpcs:
            try:
                b=int(rpc_call(u_,"eth_blockNumber",[]),16); rpc=u_; break
            except Exception: continue
        if not rpc: out["chains"][chain]={"error":"no rpc"}; continue
        cheight=int(rpc_call(rpc,"eth_blockNumber",[]),16)
        print(f"[{chain}] block={cheight}",flush=True)
        c={"block":cheight,"factories":[]}
        sy_cache={}
        for label,fac,fb in FACTORIES[chain]:
            pairs=[]
            if fac in BLAST_MARKETS:
                pairs=[(m,p,b) for (m,p,b) in BLAST_MARKETS[fac]]
            else:
                logs=None
                for u_ in [rpc]+[x for x in rpcs if x!=rpc]:
                    try:
                        logs=rpc_call(u_,"eth_getLogs",[{"fromBlock":hex(fb),"toBlock":hex(cheight),"address":fac,"topics":[TOPIC]}])
                        if isinstance(logs,list): break
                        logs=None
                    except Exception:
                        logs=None
                if logs is None:
                    c["factories"].append({"label":label,"factory":fac,"error":"getLogs failed on all RPCs"}); continue
                for lg in logs:
                    t=lg.get("topics") or []
                    if len(t)<3: continue
                    pairs.append((addr(t[1]),addr(t[2]),int(lg["blockNumber"],16)))
            markets=[]; seen=set()
            for (mkt,pt,blk) in pairs:
                if mkt in seen: continue
                seen.add(mkt)
                row={"market":mkt,"pt":pt,"deploy_block":blk}
                row["lp_supply"]=u(rpc,mkt,SEL["totalSupply"])
                row["expiry"]=u(rpc,mkt,SEL["expiry"])
                sy=a(rpc,pt,SEL["SY"]); yt=a(rpc,pt,SEL["YT"])
                row["sy"]=sy; row["yt"]=yt
                row["pt_supply"]=u(rpc,pt,SEL["totalSupply"])
                row["pt_name"]=dec_str(call(rpc,pt,SEL["name"]))
                row["market_pt_balance"]=u(rpc,pt,SEL["balanceOf"]+pad(mkt))
                if sy:
                    row["market_sy_balance"]=u(rpc,sy,SEL["balanceOf"]+pad(mkt))
                if yt:
                    row["yt_supply"]=u(rpc,yt,SEL["totalSupply"])
                    row["yt_sy_balance"]=u(rpc,sy,SEL["balanceOf"]+pad(yt)) if sy else None
                    row["yt_pt_balance"]=u(rpc,pt,SEL["balanceOf"]+pad(yt))
                    row["yt_syReserve"]=u(rpc,yt,SEL["syReserve"])
                    row["yt_pyIndexStored"]=u(rpc,yt,SEL["pyIndexStored"])
                    pe=call(rpc,yt,SEL["getPostExpiryData"])
                    if pe and pe!="REVERT":
                        w=words(pe); row["yt_postExpiry_firstPYIndex"]=uint(w[0]); row["yt_postExpiry_treasurySy"]=uint(w[1])
                # market config
                mc=call(rpc,fac,SEL["getMarketConfig"]+pad(mkt)+pad("0x0"))
                if mc and mc!="REVERT":
                    w=words(mc); row["treasury"]=addr(w[0]); row["overriddenFee"]=uint(w[1]); row["reserveFeePercent"]=uint(w[2])
                markets.append(row)
            c["factories"].append({"label":label,"factory":fac,"from_block":fb,"market_count":len(markets),"markets":markets})
        # factory-level
        for f in c["factories"]:
            if "error" in f: continue
            f["owner"]=a(rpc,f["factory"],SEL["owner"]); f["treasury"]=a(rpc,f["factory"],SEL["treasury"])
        # SY + vault detail for every unique SY
        sys_={}
        for f in c["factories"]:
            for m in f.get("markets",[]):
                if m.get("sy") and m["sy"] not in sys_: sys_[m["sy"]]=True
        syrows={}
        for sy in sys_:
            row={"sy":sy}
            ai=call(rpc,sy,SEL["assetInfo"])
            if ai and ai!="REVERT":
                w=words(ai); row["assetType"]=uint(w[0]); row["uAsset"]=addr(w[1]); row["assetDecimals"]=uint(w[2])
            row["name"]=dec_str(call(rpc,sy,SEL["name"])); row["symbol"]=dec_str(call(rpc,sy,SEL["symbol"]))
            row["decimals"]=u(rpc,sy,SEL["decimals"])
            row["sy_supply"]=u(rpc,sy,SEL["totalSupply"])
            row["exchangeRate"]=u(rpc,sy,SEL["exchangeRate"])
            row["yieldToken"]=a(rpc,sy,SEL["yieldToken"])
            row["owner"]=a(rpc,sy,SEL["owner"])
            r=call(rpc,sy,SEL["paused"]); row["paused"]= (uint(r[2:]) if r and r!="REVERT" else None)
            if row.get("yieldToken"):
                yt_=row["yieldToken"]
                row["sy_yieldToken_balance"]=u(rpc,yt_,SEL["balanceOf"]+pad(sy))
                row["vault_asset"]=a(rpc,yt_,SEL["asset"])
                row["vault_totalAssets"]=u(rpc,yt_,SEL["totalAssets"])
                row["vault_totalSupply"]=u(rpc,yt_,SEL["totalSupply"])
                row["vault_convertToAssets_1e18"]=u(rpc,yt_,SEL["convertToAssets"]+pad(hex(10**18)))
                row["vault_previewRedeem_1e18"]=u(rpc,yt_,SEL["previewRedeem"]+pad(hex(10**18)))
                row["vault_owner"]=a(rpc,yt_,SEL["owner"])
                r=call(rpc,yt_,SEL["paused"]); row["vault_paused"]=(uint(r[2:]) if r and r!="REVERT" else None)
            syrows[sy]=row
        c["sys"]=syrows
        out["chains"][chain]=c
    json.dump(out,open(sys.argv[1] if len(sys.argv)>1 else "state_dump.json","w"),indent=1)
    print("done")
if __name__=="__main__": main()
