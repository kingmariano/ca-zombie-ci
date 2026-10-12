#!/usr/bin/env python3
"""Local light recon for Dfyn Network factories (read-only). Public keyless RPCs only.
Never prints secrets."""
import json, urllib.request, sys

UA = {"User-Agent": "Mozilla/5.0 (X11; Linux x86_64) dfyn-research", "Content-Type": "application/json"}

RPCS = {
    "polygon": ["https://polygon-bor-rpc.publicnode.com", "https://polygon.llamarpc.com"],
    "fantom":  ["https://fantom-rpc.publicnode.com", "https://rpcapi.fantom.network"],
    "okc":     ["https://exchainrpc.okex.org"],
}

FACTORIES = {
    "polygon": "0xe7fb3e833efe5f9c441105eb65ef8b261266423b",
    "fantom":  "0xd9820a17053d6314b20642e465a84bf01a3d64f5",
    "okc":     "0xe7fb3e833efe5f9c441105eb65ef8b261266423b",
}

def rpc(chain, method, params):
    last = None
    for url in RPCS[chain]:
        try:
            body = json.dumps({"jsonrpc": "2.0", "id": 1, "method": method, "params": params}).encode()
            req = urllib.request.Request(url, data=body, headers=UA)
            with urllib.request.urlopen(req, timeout=20) as r:
                d = json.loads(r.read().decode())
            if "result" in d:
                return d["result"]
            last = d.get("error")
        except Exception as e:
            last = str(e)[:120]
    raise RuntimeError(f"{chain} {method}: {last}")

def call(chain, to, data):
    return rpc(chain, "eth_call", [{"to": to, "data": data}, "latest"])

def block(chain):
    return int(rpc(chain, "eth_blockNumber", []), 16)

SEL = {"allPairsLength": "0x574f2ba3", "feeTo": "0x017e7e58", "owner": "0x8da5cb5b",
       "feeToSetter": "0x094b7415", "getCode": None}

out = {}
for chain, fac in FACTORIES.items():
    o = {"factory": fac}
    try:
        o["block"] = block(chain)
    except Exception as e:
        o["block_error"] = str(e)[:100]
    for name, sel in [("allPairsLength", SEL["allPairsLength"]), ("feeTo", SEL["feeTo"]),
                      ("feeToSetter", SEL["feeToSetter"]), ("owner", SEL["owner"])]:
        try:
            r = call(chain, fac, sel)
            o[name] = r if name == "allPairsLength" else ("0x" + r[-40:] if r and len(r) >= 42 else r)
            if name == "allPairsLength":
                o[name] = int(r, 16)
        except Exception as e:
            o[name + "_err"] = str(e)[:100]
    # code presence
    try:
        code = rpc(chain, "eth_getCode", [fac, "latest"])
        o["code_len"] = len(code) // 2
    except Exception as e:
        o["code_err"] = str(e)[:100]
    out[chain] = o
    print(json.dumps(o))

json.dump(out, open("/home/heisenberg/CA/dfyn-network/analysis/factory-recon.json", "w"), indent=2)
