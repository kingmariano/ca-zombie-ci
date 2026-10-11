#!/usr/bin/env python3
"""
Correct live-state dump for Ra Exchange: reads actual ERC20 balances held by each
pool/pair (token0.balanceOf(pool), token1.balanceOf(pool)), plus reserves, gauges, etc.
"""
import json, urllib.request, time

RPC = "https://rpc.frax.com"
OUT = "/home/heisenberg/CA/ra-exchange/analysis/live_state2.json"
TRIAGE = "/home/heisenberg/CA/ra-exchange/analysis/triage-row.json"
CLF = "0xAAA32926fcE6bE95ea2c51cB4Fcb60836D320C42"
STF = "0xaaa16c016bf556fcd620328f0759252e29b1ab57"
VOTER = "0xAAAf3D9CDD3602d117c67D80eEC37a160C8d9869"

class Rpc:
    def __init__(self, url):
        self.url = url; self.id = 0
    def batch(self, calls):
        payload = []
        for (to, data) in calls:
            self.id += 1
            payload.append({"jsonrpc":"2.0","id":self.id,"method":"eth_call",
                            "params":[{"to":to,"data":data},"latest"]})
        req = urllib.request.Request(self.url, data=json.dumps(payload).encode(),
                                     headers={"Content-Type":"application/json","User-Agent":"research/1.0"})
        for _ in range(4):
            try:
                with urllib.request.urlopen(req, timeout=60) as r:
                    resp = json.loads(r.read())
                byid = {x["id"]: x.get("result") for x in resp if isinstance(x, dict)}
                return [byid.get(i) for i in range(self.id-len(calls)+1, self.id+1)]
            except Exception:
                time.sleep(1.5)
        raise RuntimeError("rpc batch failed")

def enc_addr(a): return a.lower().replace("0x","").rjust(64,"0")
def du(h): return None if h is None else (0 if h=="0x" else int(h,16))

def main():
    rpc = Rpc(RPC)
    with urllib.request.urlopen(urllib.request.Request(RPC, data=json.dumps({"jsonrpc":"2.0","id":1,"method":"eth_blockNumber","params":[]}).encode(), headers={"Content-Type":"application/json","User-Agent":"research/1.0"}), timeout=30) as r:
        block = int(json.loads(r.read())["result"], 16)
    tri = json.load(open(TRIAGE))
    cl_pools = [p["pool"] for p in tri["targets"][0]["pools"]]
    pairs = [p["pair"] for p in tri["targets"][1]["pairs"]]

    out = {"block": block, "cl_pools": {}, "pairs": {}}

    # Step 1: read token0/token1 for all
    def get_tokens(addrs):
        res = {}
        for i in range(0, len(addrs), 20):
            chunk = addrs[i:i+20]
            calls = []
            for a in chunk:
                calls.append((a, "0x0dfe1681"))  # token0
                calls.append((a, "0xd21220a7"))  # token1
            rs = rpc.batch(calls)
            for j, a in enumerate(chunk):
                t0 = "0x"+rs[2*j][-40:]
                t1 = "0x"+rs[2*j+1][-40:]
                res[a.lower()] = (t0, t1)
        return res

    cl_toks = get_tokens(cl_pools)
    pr_toks = get_tokens(pairs)

    # Step 2: balances + extra state
    def read_state(addrs, toks, extras):
        res = {}
        for i in range(0, len(addrs), 12):
            chunk = addrs[i:i+12]
            calls = []
            for a in chunk:
                t0, t1 = toks[a.lower()]
                calls.append((t0, "0x70a08231" + enc_addr(a)))  # token0 balanceOf(pool)
                calls.append((t1, "0x70a08231" + enc_addr(a)))  # token1 balanceOf(pool)
                for e in extras:
                    calls.append((a, e))
            rs = rpc.batch(calls)
            k = 0
            for a in chunk:
                t0, t1 = toks[a.lower()]
                rec = {"token0": t0, "token1": t1, "bal0": du(rs[k]), "bal1": du(rs[k+1])}
                k += 2
                for e in extras:
                    rec.setdefault("x", {})[e] = rs[k]; k += 1
                res[a.lower()] = rec
            print(f"  {i+len(chunk)}/{len(addrs)}", flush=True)
        return res

    print("== CL pools ==")
    cl = read_state(cl_pools, cl_toks, ["0x3850c7bd", "0x1a686502", "0x1ad8b03b", "0xddca3f43"])
    for a, rec in cl.items():
        x = rec.pop("x")
        s0 = x["0x3850c7bd"]
        rec["sqrtPriceX96"] = du(s0[2:66]) if s0 and len(s0) >= 66 else None
        rec["tick"] = int(s0[66:130],16) if s0 and len(s0) >= 130 else None
        rec["feeProtocol"] = int(s0[130:194],16) if s0 and len(s0) >= 194 else None
        rec["unlocked"] = bool(int(s0[194:258],16)) if s0 and len(s0) >= 258 else None
        rec["liquidity"] = du(x["0x1a686502"])
        pf = x["0x1ad8b03b"]
        rec["protocolFees0"] = du(pf[2:66]) if pf and len(pf) >= 66 else None
        rec["protocolFees1"] = du(pf[66:130]) if pf and len(pf) >= 130 else None
        rec["fee"] = du(x["0xddca3f43"])
    out["cl_pools"] = cl

    print("== pairs ==")
    pr = read_state(pairs, pr_toks, ["0x0902f1ac", "0xdf089369", "0x6373ea69", "0x22be3de1"])
    for a, rec in pr.items():
        x = rec.pop("x")
        r = x["0x0902f1ac"]
        rec["reserve0"] = du(r[2:66]) if r and len(r) >= 66 else None
        rec["reserve1"] = du(r[66:130]) if r and len(r) >= 130 else None
        rec["hasActiveGauge"] = bool(du(x["0xdf089369"]) or 0)
        rec["feeSplit"] = du(x["0x6373ea69"])
        rec["stable"] = bool(du(x["0x22be3de1"]) or 0)
    out["pairs"] = pr

    # Step 3: voter gauges for big pools + gauge state
    print("== gauges ==")
    gauge_calls = []
    for a in cl_pools + pairs:
        gauge_calls.append((VOTER, "0xb9a09fd5" + enc_addr(a)))
    gauge_res = []
    for i in range(0, len(gauge_calls), 40):
        gauge_res += rpc.batch(gauge_calls[i:i+40])
    gauges = {}
    for a, g in zip(cl_pools + pairs, gauge_res):
        gauges[a.lower()] = "0x"+g[-40:] if g and len(g) >= 42 else None
    out["gauges"] = gauges

    json.dump(out, open(OUT, "w"), indent=1)
    print("wrote", OUT, "block", block)

if __name__ == "__main__":
    main()
