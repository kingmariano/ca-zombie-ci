#!/usr/bin/env python3
"""Scan Approval events on all staking assets + cvgSDT for approvals granted BY
custody contracts (blackhole, services, distributor, cvgSdt service, buffers).
A leftover approval to an attacker-reachable spender = keyless drain path."""
import json, urllib.request, time

ENV = {}
for line in open("/home/heisenberg/CA/.env"):
    line = line.strip()
    if "=" in line and not line.startswith("#"):
        k, v = line.split("=", 1)
        ENV[k.strip()] = v.strip().strip('"').strip("'")
RPC = ENV.get("BLOCKPI_RPC_URL") or ENV.get("RPC_URL")
KEY = ENV.get("ETHERSCANV2_API_KEY")

def rpc(method, params):
    req = urllib.request.Request(RPC, data=json.dumps({"jsonrpc": "2.0", "id": 1, "method": method, "params": params}).encode(),
                                 headers={"Content-Type": "application/json", "User-Agent": "qc"})
    with urllib.request.urlopen(req, timeout=90) as r:
        return json.load(r)["result"]

def logs(topic0, address, topic1=None):
    url = f"https://api.etherscan.io/v2/api?chainid=1&module=logs&action=getLogs&fromBlock=0&toBlock=latest&address={address}&topic0={topic0}&apikey={KEY}"
    if topic1: url += f"&topic1={topic1}&topic0_1_opr=and"
    for attempt in range(4):
        req = urllib.request.Request(url, headers={"User-Agent": "qc"})
        with urllib.request.urlopen(req, timeout=90) as r:
            d = json.load(r)
        res = d.get("result")
        if isinstance(res, list): return res
        if d.get("message") == "No records found": return []
        _time.sleep(1.5)
    return []

APPROVAL = "0x8c5be1e5ebec7d5bd14f71427d1e84f3dd0314c0f7b2291e5b200ac8c7c3b925"
BLACKHOLE = "0x21777106355Ba506A31FF7984c0aE5C924deB77f"
DISTRIBUTOR = "0x6B65525a40704a4c48d07c25b8D05654854DFEcD"
CVGSDT_SVC = "0xF941BC649Ef0B20ABd7f6dC78CA8f8E225337933"
CVGSDT = "0x830614aE209FF9d8706d386fcdBc7a55206fcffC"

svcs = [l.strip() for l in open("/home/heisenberg/CA/convergence-fi-qc/analysis/services.txt") if l.strip()]
print("services from file:", len(svcs))

def allowance_scan(owner_label, owner, token, extra_spenders):
    out = []
    evs = logs(APPROVAL, token, topic1="0x" + owner[2:].rjust(64, "0"))
    for e in evs:
        spender = "0x" + e["topics"][2][-40:]
        value = int(e["data"], 16)
        out.append((e["blockNumber"], spender, value))
    return out

# collect tokens from assets.txt
assets = []
for s in svcs:
    assets.append((None, s))
import time as _time
tokens = [l.strip() for l in open("/home/heisenberg/CA/convergence-fi-qc/analysis/assets.txt") if l.strip()]
seen = {}
for tok in tokens:
    seen.setdefault(tok, []).append("svc")
seen.setdefault(CVGSDT, []).append(CVGSDT_SVC)
print("unique tokens:", len(seen))

targets = {"blackhole": BLACKHOLE, "distributor": DISTRIBUTOR, "cvgSdtSvc": CVGSDT_SVC}
for tok, svcs_for_tok in seen.items():
    for label, owner in targets.items():
        for e in logs(APPROVAL, tok, topic1="0x" + owner[2:].rjust(64, "0")):
            spender = "0x" + e["topics"][2][-40:]
            value = int(e["data"], 16)
            print(f"APPROVAL token={tok} owner={label}({owner}) spender={spender} value={value} block={e['blockNumber']}")
    # services themselves
    for svc in svcs_for_tok:
        for e in logs(APPROVAL, tok, topic1="0x" + svc[2:].rjust(64, "0")):
            spender = "0x" + e["topics"][2][-40:]
            value = int(e["data"], 16)
            print(f"APPROVAL token={tok} owner=svc({svc}) spender={spender} value={value} block={e['blockNumber']}")
print("scan complete")
