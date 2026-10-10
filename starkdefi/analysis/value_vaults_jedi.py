#!/usr/bin/env python3
"""Value vaults + JEDI-P token1s; correlate creation order with class."""
import json, urllib.request, os, time
from concurrent.futures import ThreadPoolExecutor, as_completed

ENDPOINTS = ["https://starknet-rpc.publicnode.com","https://api.cartridge.gg/x/starknet/mainnet","https://starknet.api.onfinality.io/public"]
HERE = os.path.dirname(os.path.abspath(__file__)); OUT = os.path.join(HERE, "..", "analysis")

def rpc(method, params, timeout=45, retries=4):
    last=None
    for i in range(retries):
        url=ENDPOINTS[i%len(ENDPOINTS)]
        try:
            req=urllib.request.Request(url,data=json.dumps({"jsonrpc":"2.0","id":1,"method":method,"params":params}).encode(),headers={"Content-Type":"application/json","User-Agent":"Mozilla/5.0"})
            with urllib.request.urlopen(req,timeout=timeout) as r: out=json.loads(r.read().decode())
            if "result" in out: return out["result"]
            last=out
        except Exception as e: last=repr(e)
        time.sleep(0.4)
    raise RuntimeError(str(last)[:120])

def call(addr, sel, cd, block):
    return rpc("starknet_call", [{"contract_address":addr,"entry_point_selector":sel,"calldata":cd}, {"block_number":block}])

def sel(f):
    import subprocess
    h=subprocess.run(["cast","keccak",f],capture_output=True,text=True).stdout.strip()
    return hex(int(h,16)&((1<<250)-1))

S_BAL = sel("balanceOf"); S_TS = sel("total_supply"); S_T0 = sel("token0"); S_T1 = sel("token1"); S_RES = sel("get_reserves")

def u256(res, i=0):
    return int(res[i],16) + (int(res[i+1],16) << 128)

def main():
    block = rpc("starknet_blockNumber", [])
    print("block", block, flush=True)
    pairs = [json.loads(l) for l in open(os.path.join(OUT,"pairs_raw.jsonl"))]
    meta = json.load(open(os.path.join(OUT,"factory_state.json")))
    chs = meta["pair_class_hashes"]; vaults = meta["vaults"]
    prices = json.load(open(os.path.join(OUT,"token_prices.json")))
    def price(t): return prices.get(f"starknet:{t}",{}).get("price")

    # 1) creation order vs class
    from collections import Counter
    order = Counter()
    for i,p in enumerate(pairs):
        ch = chs[p["pair"]]
        key = ch[:12]
        order[key] = order.get(key,0)+1
    print("creation-order class sequence (first index of each class):")
    seen={}
    for i,p in enumerate(pairs):
        ch=chs[p["pair"]][:12]
        if ch not in seen: seen[ch]=i
    for ch,i in seen.items(): print(f"  {ch} first at index {i}")

    # 2) vault balances
    def fetch_vault(p):
        v = vaults.get(p["pair"])
        if isinstance(v, list): v = v[0]
        if not v or not isinstance(v,str): return None
        b0 = u256(call(p["token0"], S_BAL, [v], {"block_number":block}))
        b1 = u256(call(p["token1"], S_BAL, [v], {"block_number":block}))
        return {"pair":p["pair"],"vault":v,"vt0":p["token0"],"vt1":p["token1"],"vb0":b0,"vb1":b1}
    vrecs=[]
    with ThreadPoolExecutor(max_workers=6) as ex:
        futs=[ex.submit(fetch_vault,p) for p in pairs]
        for i,f in enumerate(as_completed(futs)):
            try: vrecs.append(f.result())
            except Exception as e: vrecs.append({"error":repr(e)[:100]})
    json.dump(vrecs, open(os.path.join(OUT,"vault_balances.json"),"w"), indent=1)
    tot=0; nz=0
    for r in vrecs:
        if not r or "vb0" not in r: continue
        p0,p1=price(r["vt0"]),price(r["vt1"])
        d0={p["pair"]:int(p["decimal0"]) for p in pairs}[r["pair"]]
        d1={p["pair"]:int(p["decimal1"]) for p in pairs}[r["pair"]]
        v=(r["vb0"]/d0*p0 if p0 else 0)+(r["vb1"]/d1*p1 if p1 else 0)
        if r["vb0"] or r["vb1"]: nz+=1
        tot+=v
    print(f"vaults with nonzero balance: {nz}/312, priced fee value: ${tot:.2f}")

    # 3) value JEDI-P token1s held by buggy drainable pairs
    drain = json.load(open(os.path.join(OUT,"drainable_buggy_class.json")))
    jedis = {}
    for r in drain:
        if int(r["drainable_raw"])==0: continue
        t1=r["token1"]
        if t1 in jedis: continue
        sym = call(t1, sel("symbol"), [], {"block_number":block})
        name = call(t1, sel("name"), [], {"block_number":block})
        def f2s(h):
            try:
                b=bytes.fromhex(h[2:].rjust(64,"0")); return b.rstrip(b"\x00").decode("utf-8","replace")
            except: return "?"
        jedis[t1]={"symbol":f2s(sym[0]) if sym else "?", "name":f2s(name[0]) if name else "?"}
        if jedis[t1]["symbol"].strip() in ("JEDI-P",""):
            # try to fetch underlying via JediSwap pair ABI
            try:
                t0=call(t1,S_T0,[],{"block_number":block})[0]; tt1=call(t1,S_T1,[],{"block_number":block})[0]
                res=call(t1,S_RES,[],{"block_number":block}); ts=u256(call(t1,S_TS,[],{"block_number":block}))
                jedis[t1].update({"jt0":t0,"jt1":tt1,"jr0":str(u256(res,0)),"jr1":str(u256(res,2)),"jts":str(ts)})
            except Exception as e:
                jedis[t1]["err"]=repr(e)[:80]
    json.dump(jedis, open(os.path.join(OUT,"jedi_lp_info.json"),"w"), indent=1)
    print(json.dumps(jedis, indent=1)[:2500])

if __name__=="__main__":
    main()
