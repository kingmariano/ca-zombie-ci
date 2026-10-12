#!/usr/bin/env python3
"""Read FlareBank live state (read-only, keyless public RPC)."""
import json, urllib.request, sys

RPC = "https://flare-api.flare.network/ext/C/rpc"

def batch(calls):
    req = urllib.request.Request(RPC, data=json.dumps(calls).encode(),
        headers={"Content-Type":"application/json","User-Agent":"Mozilla/5.0"})
    return json.load(urllib.request.urlopen(req, timeout=60))

def enc_addr(a): return a.lower().replace("0x","").rjust(64,"0")
def enc_uint(v): return hex(v)[2:].rjust(64,"0")

def main():
    bank   = "0x194726F6C2aE988f1Ab5e1C943c17e591a6f6059"
    other  = "0x90679234FE693B39BFdf5642060Cb10571Adc59b"
    wflr   = "0x1d80c49bbbcd1c0911346656b529df9e5c2f783d"
    calls = []
    def add(to, sel, args="", label=""):
        calls.append({"jsonrpc":"2.0","id":len(calls)+1,"method":"eth_call",
                      "params":[{"to":to,"data":"0x"+sel+args},"latest"]})
    # simple no-arg views on both contracts
    views = {
      "name":"06fdde03","symbol":"95d89b41","decimals":"313ce567","totalSupply":"18160ddd",
      "VERSION":"ffa1ad74","buyPrice":"e7572230","sellPrice":"9b6e3e1b","onlyAmbassadors":"0c73f6a9",
      "dividendGrowthX64":"11c0cd0c","dividends_of_zero":"f7b54b9b","unclaimedDividendTotal":"c88b2b1e",
      "unclaimedTeamFees":"6e2cf6cf","unclaimedFeeReceiverFees":"b24e55cc","teamAddress":"2c1a2f4a",
      "feeReceiverAddress":"d3f2c1a1","delegator":"976f7a2c","autoClaimTsoRewards":"72a3f6f1",
      "nextClaimEpoch":"a63e70ee","nextClaimMonth":"e2a3e02b",
    }
    for name,sel in views.items():
        add(bank, sel, "", f"bank.{name}")
        add(other, sel, "", f"other.{name}")
    add(bank, "70a08231", enc_addr(bank), "bank.wflr_balanceOf_self")
    add(bank, "70a08231", enc_addr(other), "bank.wflr_balanceOf_other")
    add(other, "70a08231", enc_addr(bank), "other.wflr_balanceOf_bank")
    add(other, "70a08231", enc_addr(other), "other.wflr_balanceOf_self")
    add(bank, "70a08231", enc_addr("0x0000000000000000000000000000000000000000"), "bank.balanceOf_zero")
    add(other, "70a08231", enc_addr("0x0000000000000000000000000000000000000000"), "other.balanceOf_zero")
    # roles: DEFAULT_ADMIN_ROLE = 0x00, BANK_ADMIN=keccak("BANK_ADMIN"), AMBASSADOR=keccak("AMBASSADOR")
    # role admin will be queried separately
    add(bank, "a217fddf", "", "bank.DEFAULT_ADMIN_ROLE")
    add(other, "a217fddf", "", "other.DEFAULT_ADMIN_ROLE")
    # proxy admin() for other (TransparentUpgradeableProxy)
    add(other, "f851a440", "", "other.admin()")
    rep = batch(calls)
    out = {}
    for c, r in zip(calls, rep):
        out[c["id"]] = r
    for c, r in zip(calls, rep):
        rid = c["id"]-1
        r0 = r.get("result")
        print(c["id"], views_label(calls, c), "->", r0)
    json.dump({"raw_results":[r.get("result") for r in rep]}, open("state_raw.json","w"), indent=1)

def views_label(calls, c):
    return f'{c["params"][0]["to"][:10]}:{c["params"][0]["data"][:10]}'

if __name__ == "__main__":
    main()
