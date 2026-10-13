#!/usr/bin/env python3
"""Scan service storage slots to locate fields (find gauge/blackhole addresses)."""
import json, urllib.request

ENV = {}
for line in open("/home/heisenberg/CA/.env"):
    line = line.strip()
    if "=" in line and not line.startswith("#"):
        k, v = line.split("=", 1)
        ENV[k.strip()] = v.strip().strip('"').strip("'")
RPC = ENV.get("BLOCKPI_RPC_URL") or ENV.get("RPC_URL")

def rpc(method, params):
    req = urllib.request.Request(RPC, data=json.dumps({"jsonrpc": "2.0", "id": 1, "method": method, "params": params}).encode(),
                                 headers={"Content-Type": "application/json", "User-Agent": "qc"})
    with urllib.request.urlopen(req, timeout=90) as r:
        return json.load(r)["result"]

def scan(addr, label, slots=range(0, 200)):
    body = [{"jsonrpc": "2.0", "id": i, "method": "eth_getStorageAt", "params": [addr, hex(i), "latest"]} for i in slots]
    req = urllib.request.Request(RPC, data=json.dumps(body).encode(), headers={"Content-Type": "application/json", "User-Agent": "qc"})
    with urllib.request.urlopen(req, timeout=120) as r:
        res = json.load(r)
    out = {}
    for x in res:
        v = x["result"]
        if v != "0x" + "0" * 64:
            out[x["id"]] = v
    print(f"--- {label} {addr}: nonzero slots ---")
    for i, v in sorted(out.items()):
        print(f"slot {i}: {v}")

scan("0xF941BC649Ef0B20ABd7f6dC78CA8f8E225337933", "cvgSDT service")
scan("0x2FF160bcADb485b5F048b9880e6f471Af632060c", "sdCRV service")
