#!/usr/bin/env python3
import os as _os; _os.chdir(_os.path.dirname(_os.path.abspath(__file__)))
"""Consolidated live-state dump for C2-20 (Ethereum). Reads only; no transactions."""
import json, os, urllib.request

def env(name, fallback=None):
    v = os.environ.get(name)
    if v:
        v = v.strip().strip('"').strip("'")
        if v:
            return v
    try:
        for line in open("/home/heisenberg/CA/.env"):
            if line.startswith(name + "="):
                return line.strip().split("=", 1)[1].strip('"').strip("'")
    except FileNotFoundError:
        pass
    return fallback

RPC = env("NODEREAL_ETH_RPC_URL") or env("FORK_RPC_URL") or env("RPC_URL") or "https://ethereum-rpc.publicnode.com"

def rpc(method, params):
    body = json.dumps({"jsonrpc": "2.0", "id": 1, "method": method, "params": params}).encode()
    req = urllib.request.Request(RPC, data=body, headers={"Content-Type": "application/json", "User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(req, timeout=60) as r:
        return json.load(r)

def call(to, data, block="latest"):
    return rpc("eth_call", [{"to": to, "data": data}, block]).get("result")

def word(x):
    return int(x, 16) if x and x != "0x" else 0

ROUTER = "0x4f0055926c839D1d960a82CBF84E2eE933958ebC"
MODULE = "0xeA18B13d11f705a68F0954f637949e1eaA7AC4ca"
SAFE = "0x40E93a52F6Af9fCD3b476aeDADD7FeABD9f7AbA8"
EMPTY_SAFE = "0xbbd6b5b3565e151528c44200d4ee1a6895206962"
AETHRSETH = "0x2d62109243b87c4ba3ee7ba1d91b0dd0a074d7b1"
RSETH = "0xa1290d69c65a6fe4df752f95823fae25cb99e5a7"
AAVE_POOL = "0x87870bca3f3fd6335c3f4ce8392d69350b4fa4e2"
MODULES = {
    "ea18b13d": MODULE,
    "d479bcc8": "0xd479bcc84a6f972742ff19af23acf6b0c9253200",
    "f73a5695": "0xf73a5695bd538d09999f1987cfc43fd56eca59cc",
}

out = {"rpc": "redacted", "block": word(rpc("eth_blockNumber", [])["result"])}
out["router"] = {"address": ROUTER, "code": rpc("eth_getCode", [ROUTER, "latest"])["result"], "whitelist": {}}
for name, m in MODULES.items():
    out["router"]["whitelist"][name] = call(ROUTER, "0x919eb2f9" + m[2:].rjust(64, "0"))
for name, m in MODULES.items():
    out[f"module_{name}"] = {
        "address": m,
        "slot0": rpc("eth_getStorageAt", [m, "0x0", "latest"]).get("result"),
        "slot2": rpc("eth_getStorageAt", [m, "0x2", "latest"]).get("result"),
        "slot5": rpc("eth_getStorageAt", [m, "0x5", "latest"]).get("result"),
        "paused": call(m, "0x00000083"),
        "callers": call(m, "0x0000004f"),
    }
for label, s in (("funded_safe", SAFE), ("empty_safe", EMPTY_SAFE)):
    out[label] = {
        "address": s,
        "version": call(s, "0xffa4e618"),
        "threshold": word(call(s, "0xe75235b8")),
        "nonce": word(call(s, "0xaffed0e0")),
        "aEthrsETH": word(call(AETHRSETH, "0x70a08231" + s[2:].rjust(64, "0"))),
        "rsETH": word(call(RSETH, "0x70a08231" + s[2:].rjust(64, "0"))),
        "eth": word(rpc("eth_getBalance", [s, "latest"]).get("result")),
        "isModuleEnabled(module)": call(s, "0x2d9ad53d" + MODULE[2:].rjust(64, "0")),
        "getModulesPaginated_raw": call(s, "0xcc2f8452" + "0" * 63 + "1" + f"{30:064x}"),
    }
out["aave_account_whale"] = call(AAVE_POOL, "0xbf92857c" + SAFE[2:].rjust(64, "0"))
json.dump(out, open("state_latest.json", "w"), indent=1)
print(json.dumps({k: v for k, v in out.items() if k != "router"}, indent=1)[:3500])  # rpc field is redacted
