#!/usr/bin/env python3
"""Enumerate tokens ever received by Hedgey ClaimCampaigns (Ethereum) from Etherscan tokentx
(all pages, desc) and read current balances on-chain. Read-only.
Usage: python3 hedgey_enum.py  -> writes hedgey_tokens.json
"""
import json, os, time, urllib.request, urllib.parse

ENV = {}
for line in open("/home/heisenberg/CA/.env"):
    line = line.strip()
    if line and not line.startswith("#") and "=" in line:
        k, v = line.split("=", 1)
        ENV[k] = v.strip().strip('"').strip("'")
KEY = ENV["ETHERSCANV2_API_KEY"]
RPC = "https://ethereum-rpc.publicnode.com"
ADDR = "0xBc452fdC8F851d7c5B72e1Fe74DFB63bb793D511"

def get(url):
    req = urllib.request.Request(url, headers={"User-Agent": "zombie-hunt/read-only"})
    for i in range(5):
        try:
            with urllib.request.urlopen(req, timeout=60) as r:
                return json.load(r)
        except Exception:
            time.sleep(1 + i)
    raise RuntimeError("fetch failed " + url)

def rpc_call(to, data):
    body = json.dumps({"jsonrpc": "2.0", "id": 1, "method": "eth_call",
                       "params": [{"to": to, "data": data}, "latest"]}).encode()
    req = urllib.request.Request(RPC, data=body, headers={"Content-Type": "application/json", "User-Agent": "zombie-hunt/read-only"})
    for i in range(5):
        try:
            with urllib.request.urlopen(req, timeout=60) as r:
                return json.load(r)["result"]
        except Exception:
            time.sleep(1 + i)
    raise RuntimeError("rpc failed")

def main():
    received = {}
    page = 1
    total = 0
    while page <= 80:
        url = ("https://api.etherscan.io/v2/api?chainid=1&module=account&action=tokentx"
               f"&address={ADDR}&startblock=0&endblock=99999999&sort=desc"
               f"&page={page}&offset=1000&apikey={KEY}")
        d = get(url)
        res = d.get("result")
        if not isinstance(res, list) or not res:
            break
        total += len(res)
        for t in res:
            ca = t["contractAddress"].lower()
            if t["to"].lower() == ADDR.lower():
                r = received.setdefault(ca, {"sym": t["tokenSymbol"], "dec": int(t["tokenDecimal"]),
                                             "in": 0, "first": 2**63, "last": 0})
                r["in"] += int(t["value"])
                r["first"] = min(r["first"], int(t["timeStamp"]))
                r["last"] = max(r["last"], int(t["timeStamp"]))
        if len(res) < 1000:
            break
        page += 1
    print("transfer rows scanned:", total, "distinct tokens received:", len(received))
    json.dump({"address": ADDR, "scanned": total,
               "tokens_received": received},
              open(os.path.join(os.path.dirname(__file__), "hedgey_tokens_received.json"), "w"), indent=1)

    # current balances
    out = []
    for ca, r in received.items():
        data = "0x70a08231" + "0" * 24 + ADDR[2:].lower()
        try:
            b = rpc_call(ca, data)
            bal = int(b, 16) if b and b != "0x" else 0
        except Exception as e:
            print("balance read failed for", ca, r["sym"], type(e).__name__)
            bal = -1
        out.append({"token": ca, "symbol": r["sym"], "decimals": r["dec"],
                    "received_raw": str(r["in"]), "received": r["in"] / 10 ** r["dec"],
                    "first_ts": r["first"], "last_ts": r["last"],
                    "balance_raw": str(bal), "balance": bal / 10 ** r["dec"]})
    out.sort(key=lambda x: -x["balance"])
    nonzero = [x for x in out if x["balance_raw"] != "0"]
    json.dump({"address": ADDR, "scanned": total, "tokens": out, "nonzero": nonzero},
              open(os.path.join(os.path.dirname(__file__), "hedgey_tokens.json"), "w"), indent=1)
    print("tokens with balance today:", len(nonzero))
    for x in nonzero:
        print(f"  {x['symbol']:>12} {x['token']} bal={x['balance']} (raw {x['balance_raw'][:20]})")

if __name__ == "__main__":
    main()
