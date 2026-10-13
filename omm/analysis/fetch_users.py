#!/usr/bin/env python3
"""Enumerate Omm depositors/borrowers and compute account data (read-only)."""
import json, subprocess, sys

RPC = "https://ctz.solidwallet.io/api/v3"
LP = "cxcb455f26a2c01c686fa7f30e1e3661642dd53c0d"
DP = "cx5f9a6ca11b2b761a469965cedab40ada9e503cb5"

def call(to, method, params=None, timeout=40):
    body = {"jsonrpc":"2.0","id":1,"method":"icx_call","params":{"to":to,"dataType":"call","data":{"method":method,"params":params or {}}}}
    r = subprocess.run(["curl","-s","-m",str(timeout),"-X","POST",RPC,"-H","Content-Type: application/json","-d",json.dumps(body)],capture_output=True,text=True)
    try:
        j = json.loads(r.stdout)
        if "result" in j: return j["result"]
        return {"__error__": j.get("error")}
    except Exception as e:
        return {"__error__": str(e)}

def paged(method):
    out, idx = [], 0
    while True:
        r = call(LP, method, {"_index": hex(idx)})
        if not isinstance(r, list) or not r:
            break
        out.extend(r)
        if len(r) < 50:
            break
        idx += 1
        if idx > 40:  # runaway guard
            out.append("__PAGE_LIMIT_HIT__")
            break
    return out

def main():
    deposits = paged("getDepositWallets")
    borrows = paged("getBorrowWallets")
    print(f"depositors={len(deposits)} borrowers={len(borrows)}")
    json.dump({"depositors":deposits,"borrowers":borrows}, open("users.json","w"), indent=1)

    rows = []
    for u in borrows:
        if u.startswith("__"): continue
        ad = call(DP, "getUserAccountData", {"_user": u})
        rows.append({"user": u, "account": ad})
    json.dump(rows, open("borrowers_account.json","w"), indent=1)

    # also deposits-only users
    dset = set(deposits); bset = set(borrows)
    only_dep = [u for u in deposits if u not in bset]
    rows2 = []
    for u in only_dep:
        ad = call(DP, "getUserAccountData", {"_user": u})
        rows2.append({"user": u, "account": ad})
    json.dump(rows2, open("depositors_account.json","w"), indent=1)
    print(f"depositors-only={len(only_dep)}")

if __name__ == "__main__":
    main()
