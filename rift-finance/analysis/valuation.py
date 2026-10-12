#!/usr/bin/env python3
"""Valuation of Rift vault holdings (read-only, keyless).
Reads token metadata + balances + LP composition, prices via DefiLlama."""
import json, sys, urllib.request

RPCS = {"ethereum": "https://ethereum-rpc.publicnode.com",
        "aurora": "https://mainnet.aurora.dev"}
LLAMA = "https://coins.llama.fi/prices/current/"

def rpc_batch(url, calls, chunk=25):
    out = []
    for i in range(0, len(calls), chunk):
        part = calls[i:i+chunk]
        payload = [{"jsonrpc":"2.0","id":j,"method":"eth_call","params":[{"to":t,"data":d},"latest"]}
                   for j,(t,d) in enumerate(part)]
        req = urllib.request.Request(url, json.dumps(payload).encode(),
                                     headers={"Content-Type":"application/json","User-Agent":"rift-research"})
        with urllib.request.urlopen(req, timeout=180) as r:
            res = json.loads(r.read())
        m = {x["id"]: x for x in res}
        for j in range(len(part)):
            x = m.get(j, {})
            out.append(x.get("result") if "result" in x else None)
    return out

def rpc(url, method, params):
    req = urllib.request.Request(url, json.dumps({"jsonrpc":"2.0","id":1,"method":method,"params":params}).encode(),
                                 headers={"Content-Type":"application/json","User-Agent":"rift-research"})
    with urllib.request.urlopen(req, timeout=120) as r:
        return json.loads(r.read())["result"]

def num(h, dec=0):
    if not h or not h.startswith("0x"): return None
    return int(h,16)/10**dec if dec else int(h,16)

def addr(h):
    return "0x"+h[-40:] if h and h.startswith("0x") else None

def str_dec(h):
    try:
        b = bytes.fromhex(h[2:])
        ln = int.from_bytes(b[32:64],'big')
        return b[64:64+ln].decode()
    except Exception: return None

SEL = {"symbol":"0x95d89b41","decimals":"0x313ce567","token0":"0x0dfe1681","token1":"0xd21220a7",
       "getReserves":"0x0902f1ac","totalSupply":"0x18160ddd","balanceOf":"0x70a08231"}

def bal_of(token, holder):
    return SEL["balanceOf"] + "0"*24 + holder[2:]

def main():
    tasks = json.load(open(sys.argv[1]))  # {"chain": {"vaults": {addr: {tokens...}}}}
    out = {}
    for chain, data in tasks.items():
        url = RPCS[chain]
        block = int(rpc(url, "eth_blockNumber", []),16)
        vaults = data["vaults"]
        # collect unique tokens and pairs
        toks = set(); pairs = set()
        for v,s in vaults.items():
            for k in ("token0","token1"):
                if s.get(k): toks.add(s[k].lower())
            if s.get("pair"): pairs.add(s["pair"].lower())
        meta_calls = []
        meta_keys = []
        for t in sorted(toks):
            meta_calls += [(t, SEL["symbol"]), (t, SEL["decimals"])]; meta_keys += [("sym",t),("dec",t)]
        for p in sorted(pairs):
            meta_calls += [(p, SEL["token0"]), (p, SEL["token1"]), (p, SEL["getReserves"]), (p, SEL["totalSupply"])]
            meta_keys += [("p0",p),("p1",p),("res",p),("ts",p)]
        res = rpc_batch(url, meta_calls)
        M = {}
        for (k,t), r in zip(meta_keys, res):
            M.setdefault(t, {})[k] = r
        tinfo = {}
        for t in sorted(toks):
            sym = str_dec(M[t].get("sym") or "0x"); dec = num(M[t].get("dec") or "0x0") or 18
            tinfo[t] = {"symbol": sym, "decimals": int(dec)}
        pinfo = {}
        for p in sorted(pairs):
            r = M[p].get("res")
            if r and r.startswith("0x") and len(r) >= 130:
                r0 = int(r[2:66],16); r1 = int(r[66:130],16)
            else:
                r0 = r1 = None
            pinfo[p] = {"token0": addr(M[p].get("p0") or ""), "token1": addr(M[p].get("p1") or ""),
                        "reserve0": r0, "reserve1": r1, "totalSupply": num(M[p].get("ts"))}
        # balances for vaults
        calls = []; keys = []
        for v,s in vaults.items():
            for k in ("token0","token1"):
                if s.get(k): calls.append((s[k].lower(), bal_of(s[k].lower(), v.lower()))); keys.append((v,"bal0" if k=="token0" else "bal1"))
            if s.get("pair"): calls.append((s["pair"].lower(), bal_of(s["pair"].lower(), v.lower()))); keys.append((v,"balLP"))
        bres = rpc_batch(url, calls)
        B = {}
        for (v,k), r in zip(keys, bres):
            B.setdefault(v,{})[k] = num(r)
        # prices
        price_ids = [f"{chain}:{t}" for t in sorted(toks)]
        pr = json.loads(urllib.request.urlopen(urllib.request.Request(
            LLAMA + ",".join(price_ids), headers={"User-Agent":"rift-research"}), timeout=60).read())
        prices = {k: v["price"] for k,v in pr.get("coins",{}).items()}
        out[chain] = {"block": block, "tokens": tinfo, "pairs": pinfo, "vaults": {}}
        for v,s in vaults.items():
            b = B.get(v,{})
            t0 = s.get("token0","").lower(); t1 = s.get("token1","").lower(); p = (s.get("pair") or "").lower()
            entry = {"token0": t0, "token1": t1, "pair": p, "bal0": b.get("bal0"), "bal1": b.get("bal1"),
                     "balLP": b.get("balLP"),
                     "dec0": tinfo.get(t0,{}).get("decimals"), "dec1": tinfo.get(t1,{}).get("decimals"),
                     "sym0": tinfo.get(t0,{}).get("symbol"), "sym1": tinfo.get(t1,{}).get("symbol"),
                     "price0": prices.get(f"{chain}:{t0}"), "price1": prices.get(f"{chain}:{t1}")}
            if p in pinfo and pinfo[p]["totalSupply"] and b.get("balLP") is not None:
                share = b["balLP"]/pinfo[p]["totalSupply"]
                pr0 = pinfo[p]["reserve0"]; pr1 = pinfo[p]["reserve1"]
                entry["lp_share"] = share
                # map pair reserves to vault token0/token1 by address
                if pinfo[p]["token0"] == t0:
                    entry["lp_t0"] = pr0*share if pr0 is not None else None
                    entry["lp_t1"] = pr1*share if pr1 is not None else None
                else:
                    entry["lp_t0"] = pr1*share if pr1 is not None else None
                    entry["lp_t1"] = pr0*share if pr0 is not None else None
            # usd
            try:
                usd = 0
                if entry["bal0"] is not None and entry["price0"] is not None:
                    usd += entry["bal0"]/10**entry["dec0"]*entry["price0"]
                if entry["bal1"] is not None and entry["price1"] is not None:
                    usd += entry["bal1"]/10**entry["dec1"]*entry["price1"]
                if entry.get("lp_t0") is not None:
                    usd += entry["lp_t0"]/10**entry["dec0"]*entry["price0"]
                    usd += entry["lp_t1"]/10**entry["dec1"]*entry["price1"]
                entry["usd_total"] = round(usd,2)
            except Exception as e:
                entry["usd_total"] = None
            out[chain]["vaults"][v] = entry
    print(json.dumps(out, indent=1))

if __name__ == "__main__":
    main()
