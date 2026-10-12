#!/usr/bin/env python3
"""childA: discover balance/allowance storage slots for the 4 pool coins via Tenderly overrides."""
import json, subprocess, sys, time

U = "https://gateway.tenderly.co/public/mainnet"
ATT = "0x1111111111111111111111111111111111111111"
POOL = "0x329239599afB305DA0A2eC69c58F8a6697F9F88d"
TOKENS = {
    "DAI":  "0x6B175474E89094C44Da98b954EedeAC495271d0F",
    "USDC": "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
    "USDT": "0xdAC17F958D2ee523a2206206994597C13D831ec7",
    "TUSD": "0x0000000000085d4780B73119b644AE5ecd22b376",
}
MARK = "0x0000000000000000000000000000000000000000000000000000000000012345"

def keccak_hex(data: bytes) -> str:
    from Crypto.Hash import keccak as ck
    h = ck.new(digest_bits=256); h.update(data); return "0x" + h.hexdigest()

def pad32(addr): return bytes.fromhex(addr[2:]).rjust(32, b"\x00")

def kaddr(addr, slot):  return keccak_hex(pad32(addr) + slot.to_bytes(32,"big"))
def knest(a1, a2, slot): return keccak_hex(pad32(a2) + bytes.fromhex(kaddr(a1, slot)[2:]))

def rpc(method, params, tries=5):
    p = json.dumps({"jsonrpc":"2.0","id":1,"method":method,"params":params})
    for a in range(tries):
        r = subprocess.run(["curl","-s","-X","POST",U,"-H","content-type: application/json","--data-binary",p],capture_output=True,text=True,timeout=120)
        try: d = json.loads(r.stdout)
        except Exception: d = {"raw": r.stdout[:200]}
        if isinstance(d, dict) and d.get("error",{}).get("code") == -32005:
            time.sleep(4*(a+1)); continue
        return d
    return d

def rpc_batch(reqs):
    p = json.dumps(reqs)
    r = subprocess.run(["curl","-s","-X","POST",U,"-H","content-type: application/json","--data-binary",p],capture_output=True,text=True,timeout=120)
    try: return json.loads(r.stdout)
    except Exception: return [{"raw": r.stdout[:200]}]

def call_data(sig4): return sig4
BAL = "0x70a08231"
ALLOW = "0xdd62ed3e"

def discover(token):
    out = {"bal":[], "alw":[]}
    for s in range(0, 16):
        key = kaddr(ATT, s)
        d = rpc("eth_call", [{"to":token,"data":BAL+"0"*24+ATT[2:]},"latest",{token:{"stateDiff":{key:MARK}}}])
        if isinstance(d.get("result"), str) and d["result"].lower().endswith("12345"):
            out["bal"].append(s)
        time.sleep(1.0)
    for s in range(0, 16):
        key = knest(ATT, POOL, s)
        d = rpc("eth_call", [{"to":token,"data":ALLOW+"0"*24+ATT[2:]+"0"*24+POOL[2:]},"latest",{token:{"stateDiff":{key:MARK}}}])
        if isinstance(d.get("result"), str) and d["result"].lower().endswith("12345"):
            out["alw"].append(s)
        time.sleep(1.0)
    return out

if __name__ == "__main__":
    table = {}
    for name, addr in TOKENS.items():
        d = discover(addr)
        table[name] = d
        print(name, addr, "balance_slots:", d["bal"], "allowance_slots:", d["alw"])
    json.dump(table, open("/tmp/opencode/childA_slots.json","w"))
