#!/usr/bin/env python3
"""Enumerate tokens ever received by a Hedgey ClaimCampaigns instance on a given chain
(Etherscan V2 tokentx, all pages desc) and read current balances on-chain. Read-only.
Usage: python3 hedgey_enum_multi.py <chainid> <rpc> <address> <outfile>
"""
import json, os, sys, time, urllib.request

CHAINID, RPC, ADDR, OUTFILE = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
ENV = {}
for line in open("/home/heisenberg/CA/.env"):
    line = line.strip()
    if line and not line.startswith("#") and "=" in line:
        k, v = line.split("=", 1)
        ENV[k] = v.strip().strip('"').strip("'")
KEY = ENV["ETHERSCANV2_API_KEY"]
UA = {"User-Agent": "zombie-hunt/read-only"}

def get(url):
    req = urllib.request.Request(url, headers=UA)
    for i in range(6):
        try:
            with urllib.request.urlopen(req, timeout=60) as r:
                return json.load(r)
        except Exception:
            time.sleep(1.5 * (i + 1))
    raise RuntimeError("fetch failed " + url[:120])

def rpc_call(to, data):
    body = json.dumps({"jsonrpc": "2.0", "id": 1, "method": "eth_call",
                       "params": [{"to": to, "data": data}, "latest"]}).encode()
    req = urllib.request.Request(RPC, data=body, headers={**UA, "Content-Type": "application/json"})
    for i in range(5):
        try:
            with urllib.request.urlopen(req, timeout=60) as r:
                d = json.load(r)
            if "result" in d:
                return d["result"]
            time.sleep(1 + i)
        except Exception:
            time.sleep(1 + i)
    return None

def main():
    received = {}
    page, total = 1, 0
    while page <= 100:
        url = (f"https://api.etherscan.io/v2/api?chainid={CHAINID}&module=account&action=tokentx"
               f"&address={ADDR}&startblock=0&endblock=99999999&sort=desc"
               f"&page={page}&offset=1000&apikey={KEY}")
        d = get(url)
        res = d.get("result")
        if not isinstance(res, list) or not res:
            print("stop page", page, "status", d.get("status"), str(d.get("result"))[:80])
            break
        total += len(res)
        for t in res:
            if t["to"].lower() == ADDR.lower():
                ca = t["contractAddress"].lower()
                r = received.setdefault(ca, {"sym": t["tokenSymbol"], "dec": int(t["tokenDecimal"]),
                                             "in": 0, "first": 2**63, "last": 0})
                r["in"] += int(t["value"])
                r["first"] = min(r["first"], int(t["timeStamp"]))
                r["last"] = max(r["last"], int(t["timeStamp"]))
        if len(res) < 1000:
            break
        page += 1
    print("rows", total, "distinct received", len(received))
    json.dump({"address": ADDR, "chainid": CHAINID, "scanned": total, "tokens_received": received},
              open(OUTFILE + ".received.json", "w"), indent=1)
    out = []
    for ca, r in received.items():
        data = "0x70a08231" + "0" * 24 + ADDR[2:].lower()
        b = rpc_call(ca, data)
        bal = int(b, 16) if b and b != "0x" else 0
        out.append({"token": ca, "symbol": r["sym"], "decimals": r["dec"],
                    "received": r["in"] / 10 ** r["dec"], "first_ts": r["first"], "last_ts": r["last"],
                    "balance_raw": str(bal), "balance": bal / 10 ** r["dec"]})
    out.sort(key=lambda x: -x["balance"])
    json.dump({"address": ADDR, "chainid": CHAINID, "scanned": total, "tokens": out,
               "nonzero": [x for x in out if x["balance_raw"] != "0"]},
              open(OUTFILE, "w"), indent=1)
    nz = [x for x in out if x["balance_raw"] != "0"]
    print("nonzero:", len(nz))
    for x in nz:
        print(f"  {x['symbol']} {x['token']} bal={x['balance']}")

if __name__ == "__main__":
    main()
