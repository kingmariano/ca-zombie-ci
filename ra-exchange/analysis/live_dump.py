#!/usr/bin/env python3
"""
Live-state dump for Ra Exchange (Fraxtal) — read-only.
Reads all CL pools and crAMM pairs (addresses from triage row) at the latest block:
balances, slot0/liquidity/protocolFees (CL), reserves/feeSplit/hasActiveGauge (pairs).
Uses only the keyless public RPC. Writes analysis/live_state.json
"""
import json, urllib.request, sys, time

RPC = "https://rpc.frax.com"
OUT = "/home/heisenberg/CA/ra-exchange/analysis/live_state.json"
TRIAGE = "/home/heisenberg/CA/ra-exchange/analysis/triage-row.json"

SEL = {
    "token0": "0x0dfe1681", "token1": "0xd21220a7",
    "balanceOf": "0x70a08231", "slot0": "0x3850c7bd",
    "liquidity": "0x1a686502", "protocolFees": "0x1f18b6f6" , "fee": "0xddca3f43",
    "reserve0": "0x443cb4bc", "reserve1": "0xd669a4c9",
    "hasActiveGauge": "0x5bea5b40", "feeSplit": "0x1e83409a", "stable": "0x22be3de1",
    "getReserves": "0x0902f1ac", "totalSupply": "0x18160ddd",
    "factory": "0xc45a0155", "nfpManager": "0x10aa58ab", "owner": "0x8da5cb5b",
    "feeCollector": "0xfdcebea3", "poolFeeProtocol": "0x8da5cb5b",
}

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
        for attempt in range(4):
            try:
                with urllib.request.urlopen(req, timeout=60) as r:
                    resp = json.loads(r.read())
                byid = {x["id"]: x.get("result") for x in resp if isinstance(x, dict)}
                return [byid.get(i) for i in range(self.id-len(calls)+1, self.id+1)]
            except Exception as e:
                time.sleep(1.5)
        raise RuntimeError("rpc batch failed")

def enc_addr(a):
    return a.lower().replace("0x","").rjust(64,"0")

def dec_uint(hexstr):
    if hexstr is None: return None
    if hexstr == "0x": return 0
    return int(hexstr, 16)

def main():
    rpc = Rpc(RPC)
    # block number
    req = urllib.request.Request(RPC, data=json.dumps({"jsonrpc":"2.0","id":1,"method":"eth_blockNumber","params":[]}).encode(),
                                 headers={"Content-Type":"application/json","User-Agent":"research/1.0"})
    with urllib.request.urlopen(req, timeout=30) as r:
        block = int(json.loads(r.read())["result"], 16)
    print("latest block:", block)

    tri = json.load(open(TRIAGE))
    cl_pools = [p["pool"] for p in tri["targets"][0]["pools"]]
    pairs = [p["pair"] for p in tri["targets"][1]["pairs"]]
    print("cl pools:", len(cl_pools), "pairs:", len(pairs))

    out = {"block": block, "cl_pools": {}, "pairs": {}}

    def read_tokens(addrs, extra_slots=None):
        res = {}
        B = 10
        for i in range(0, len(addrs), B):
            chunk = addrs[i:i+B]
            calls = []
            for a in chunk:
                calls.append((a, SEL["token0"]))
                calls.append((a, SEL["token1"]))
                calls.append((a, SEL["balanceOf"] + enc_addr(a)))  # balance of self
                if extra_slots:
                    for s in extra_slots:
                        calls.append((a, s))
            rs = rpc.batch(calls)
            k = 0
            for a in chunk:
                rec = {"token0": "0x"+rs[k][-40:], "token1": "0x"+rs[k+1][-40:]}
                rec["bal_self"] = dec_uint(rs[k+2])
                k += 3
                if extra_slots:
                    for s in extra_slots:
                        rec.setdefault("extra", {})[s] = rs[k]; k += 1
                res[a.lower()] = rec
            print(f"  {i+len(chunk)}/{len(addrs)}", flush=True)
        return res

    print("== CL pools ==")
    cl = read_tokens(cl_pools, extra_slots=[SEL["slot0"], SEL["liquidity"], SEL["protocolFees"], SEL["fee"]])
    for a, rec in cl.items():
        e = rec.pop("extra")
        s0 = e[SEL["slot0"]]
        rec["sqrtPriceX96"] = dec_uint(s0[2:66]) if s0 and len(s0) >= 66 else None
        rec["tick"] = int(s0[66:130], 16) if s0 and len(s0) >= 130 else None
        rec["feeProtocol"] = int(s0[130:194], 16) if s0 and len(s0) >= 194 else None
        rec["unlocked"] = bool(int(s0[194:258], 16)) if s0 and len(s0) >= 258 else None
        rec["liquidity"] = dec_uint(e[SEL["liquidity"]])
        pf = e[SEL["protocolFees"]]
        rec["protocolFees0"] = dec_uint(pf[2:66]) if pf and len(pf) >= 66 else None
        rec["protocolFees1"] = dec_uint(pf[66:130]) if pf and len(pf) >= 130 else None
        rec["fee"] = dec_uint(e[SEL["fee"]])
    out["cl_pools"] = cl

    print("== pairs ==")
    pr = read_tokens(pairs, extra_slots=[SEL["getReserves"], SEL["hasActiveGauge"], SEL["feeSplit"], SEL["stable"]])
    for a, rec in pr.items():
        e = rec.pop("extra")
        r = e[SEL["getReserves"]]
        rec["reserve0"] = dec_uint(r[2:66]) if r and len(r) >= 66 else None
        rec["reserve1"] = dec_uint(r[66:130]) if r and len(r) >= 130 else None
        rec["hasActiveGauge"] = bool(dec_uint(e[SEL["hasActiveGauge"]]) or 0)
        rec["feeSplit"] = dec_uint(e[SEL["feeSplit"]])
        rec["stable"] = bool(dec_uint(e[SEL["stable"]]) or 0)
    out["pairs"] = pr

    json.dump(out, open(OUT, "w"), indent=1)
    print("wrote", OUT)

if __name__ == "__main__":
    main()
