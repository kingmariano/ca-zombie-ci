#!/usr/bin/env python3
"""Binary-search V1 stakedUserAddresses length + scan a range of users for
lastEpochClaimed==1 and owed dividends. Keyless public RPC."""
import json, urllib.request, time, sys

RPC = "https://polygon-bor-rpc.publicnode.com"
UA = {"Content-Type": "application/json", "User-Agent": "Mozilla/5.0"}
V1 = "0xd5d5eDdC6D634a729EcEf53f710B4a3Cd61bc2B2"

def batch(calls):
    out = []
    for i in range(0, len(calls), 10):
        chunk = calls[i:i+10]
        payload = [{"jsonrpc": "2.0", "id": j, "method": m, "params": p} for j, (m, p) in enumerate(chunk)]
        req = urllib.request.Request(RPC, data=json.dumps(payload).encode(), headers=UA)
        for attempt in range(5):
            try:
                resp = json.loads(urllib.request.urlopen(req, timeout=40).read()); break
            except Exception:
                if attempt == 4: raise
                time.sleep(1.5 * (attempt + 1))
        by_id = {r["id"]: r for r in resp}
        for j in range(len(chunk)):
            r = by_id.get(j, {})
            out.append(r.get("result", {"error": r.get("error")}))
    return out

def call(to, data, block="latest"):
    return ("eth_call", [{"to": to, "data": data}, block])

def pad32(x): return hex(x)[2:].rjust(64, "0")
def pad_addr(a): return a.lower().replace("0x", "").rjust(64, "0")

def get_addr(i):
    r = batch([call(V1, "0x" + "f7f9f3d1" if False else "0x" + sig("stakedUserAddresses(uint256)") + pad32(i))])
    # use ABI selector manually below; placeholder
    return r

# selectors
SEL = {
  "stakedUserAddresses(uint256)": "0x66e53cb7",
  "userInfos(address)": "0x2fa3ae23",
  "calculateOwedDividendsFromNow_d6(address)": "0xbdab2a01",
}
for k, v in list(SEL.items()):
    pass

def sel_check():
    # verify selectors with cast offline? just use cast for the first call; here use known selectors via keccak on-chain not possible.
    pass

if __name__ == "__main__":
    # binary search for length
    lo, hi = 6000, 7000
    # first check hi is out of range
    def ok(i):
        r = batch([call(V1, SEL["stakedUserAddresses(uint256)"] + pad32(i))])[0]
        return not isinstance(r, dict)
    while lo + 1 < hi:
        mid = (lo + hi) // 2
        if ok(mid): lo = mid
        else: hi = mid
    print("array length =", hi, "(last index", lo, ")")
    n = hi
    json.dump({"stakedUserAddresses_len": hi}, open("v1_array_len.json", "w"), indent=1)
