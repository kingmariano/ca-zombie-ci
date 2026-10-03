#!/usr/bin/env python3
"""Enumerate partyA users + lifetime deposit/withdraw totals from the diamond's
own Deposit(sender,user,amount) / Withdraw(sender,user,amount) events.

Base: Ankr chunked eth_getLogs. Others: Etherscan V2 decimal chunks + page escalation.
Writes raw/diamond_users_<chain>.json
"""
import json
import os
import sys
import time
import requests

RAW = os.path.join(os.path.dirname(os.path.abspath(__file__)), "raw")
TOPIC_DEP = "0x5548c837ab068cf56a2c2479df0882a4922fd203edb7517321831d95078c5f62"
TOPIC_WD = "0x9b1bfa7fa9ee420a16e124f794c35ac9f90472acc99140eb2f6447c714cad8eb"

CHAINS = {
    "base": dict(kind="ankr", diamond="0x91Cf2D8Ed503EC52768999aA6D8DBeA6e52dbe43", dec=6),
    "arb": dict(kind="etherscan", id=42161, diamond="0x8F06459f184553e5d04F07F868720BDaCAB39395", dec=6),
    "mantle": dict(kind="etherscan", id=5000, diamond="0x2Ecc7da3Cc98d341F987C85c3D9FC198570838B5", dec=18),
    "blast": dict(kind="etherscan", id=81457, diamond="0x3d17f073cCb9c3764F105550B0BCF9550477D266", dec=18),
}


def parse_user_logs(logs, dec):
    users = {}
    total = 0
    for lg in logs:
        data = lg["data"][2:] if lg["data"].startswith("0x") else lg["data"]
        if len(data) < 192:
            continue
        user = "0x" + data[64 + 24:128]
        amount = int(data[128:192], 16)
        users[user] = users.get(user, 0) + amount
        total += amount
    return users, total


def run_ankr(chain, cfg, topics):
    rpc = "https://rpc.ankr.com/base/" + os.environ.get("ANKR_API_KEY", "")
    latest = int(requests.post(rpc, json={"jsonrpc": "2.0", "id": 1, "method": "eth_blockNumber", "params": []},
                               timeout=60).json()["result"], 16)
    out = {"chain": chain, "latest": latest}
    for tname, topic in topics.items():
        users = {}
        total = 0
        n = 0
        CH = 5_000_000
        for lo in range(0, latest + 1, CH):
            hi = min(lo + CH - 1, latest)
            for attempt in range(5):
                d = requests.post(rpc, json={"jsonrpc": "2.0", "id": 1, "method": "eth_getLogs",
                                             "params": [{"address": cfg["diamond"], "topics": [topic],
                                                         "fromBlock": hex(lo), "toBlock": hex(hi)}]},
                                  timeout=180).json()
                if "error" not in d:
                    break
                time.sleep(3 * (attempt + 1))
            if "error" in d:
                raise RuntimeError(f"{chain}/{tname} {lo}-{hi}: {d['error']}")
            logs = d["result"]
            u, t = parse_user_logs(logs, cfg["dec"])
            for k, v in u.items():
                users[k] = users.get(k, 0) + v
            total += t
            n += len(logs)
            print(f"  [{chain}/{tname}] {lo}-{hi}: {len(logs)} logs, users={len(users)}", flush=True)
            time.sleep(0.3)
        out[tname.lower()] = {"count": n, "total_token": total / 10 ** cfg["dec"],
                              "users": users, "user_count": len(users)}
    return out


def run_es(chain, cfg, topics):
    key = os.environ["ETHERSCANV2_API_KEY"]
    u = f"https://api.etherscan.io/v2/api?chainid={cfg['id']}&module=proxy&action=eth_blockNumber&apikey={key}"
    latest = int(requests.get(u, timeout=60).json()["result"], 16)
    out = {"chain": chain, "latest": latest}
    for tname, topic in topics.items():
        users = {}
        total = 0
        n = 0
        CH = 5_000_000
        lo = 0
        while lo <= latest:
            hi = min(lo + CH - 1, latest)
            page = 1
            while True:
                u = (f"https://api.etherscan.io/v2/api?chainid={cfg['id']}&module=logs&action=getLogs"
                     f"&address={cfg['diamond']}&topic0={topic}&fromBlock={lo}&toBlock={hi}"
                     f"&offset=1000&page={page}&apikey={key}")
                r = requests.get(u, timeout=90).json()
                if r.get("status") != "1":
                    msg = str(r.get("message")) + str(r.get("result"))
                    if "No logs" in msg or "No records" in msg:
                        break
                    raise RuntimeError(f"{chain}/{tname} {lo}-{hi} p{page}: {msg[:150]}")
                logs = r["result"]
                uu, t = parse_user_logs(logs, cfg["dec"])
                for k, v in uu.items():
                    users[k] = users.get(k, 0) + v
                total += t
                n += len(logs)
                if len(logs) < 1000:
                    break
                page += 1
                if page > 10:
                    break
                time.sleep(0.25)
            print(f"  [{chain}/{tname}] {lo}-{hi}: total logs={n}, users={len(users)}", flush=True)
            lo = hi + 1
            time.sleep(0.3)
        out[tname.lower()] = {"count": n, "total_token": total / 10 ** cfg["dec"],
                              "users": users, "user_count": len(users)}
    return out


if __name__ == "__main__":
    topics = {"Deposit": TOPIC_DEP, "Withdraw": TOPIC_WD}
    for c in sys.argv[1:]:
        cfg = CHAINS[c]
        if cfg["kind"] == "ankr":
            out = run_ankr(c, cfg, topics)
        else:
            out = run_es(c, cfg, topics)
        with open(os.path.join(RAW, f"diamond_users_{c}.json"), "w") as f:
            json.dump(out, f, indent=1)
        print(f"[{c}] deposit count={out['deposit']['count']} total={out['deposit']['total_token']:,.2f}; "
              f"withdraw count={out['withdraw']['count']} total={out['withdraw']['total_token']:,.2f}; "
              f"universe={len(set(out['deposit']['users'])|set(out['withdraw']['users']))}")
