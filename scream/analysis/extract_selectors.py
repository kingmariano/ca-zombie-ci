#!/usr/bin/env python3
"""Extract PUSH4 selectors from runtime bytecode and resolve via 4byte.directory."""
import json, sys, urllib.request, time

RPC = "https://rpcapi.fantom.network"

def rpc(method, params):
    req = urllib.request.Request(RPC, data=json.dumps({"jsonrpc": "2.0", "id": 1, "method": method, "params": params}).encode(),
                                 headers={"Content-Type": "application/json"})
    return json.loads(urllib.request.urlopen(req, timeout=60).read())["result"]

def selectors(code_hex):
    b = bytes.fromhex(code_hex[2:])
    sels = set()
    i = 0
    while i < len(b):
        op = b[i]
        if op == 0x63 and i + 4 < len(b):  # PUSH4
            sels.add(b[i+1:i+5].hex())
            i += 5
        else:
            i += 1
    return sels

def resolve(sel):
    url = f"https://www.4byte.directory/api/v1/signatures/?hex_signature=0x{sel}"
    try:
        d = json.loads(urllib.request.urlopen(url, timeout=20).read())
        rs = d.get("results", [])
        if rs:
            return rs[0]["text_signature"]
    except Exception:
        pass
    return None

def main():
    targets = {
        "oracle": "0x0b24e9420c125242a5ec438bc65e48af1e866ddd",
        "comptroller_impl": "0x37517c5d880c5c282437a3da4d627b4457c10beb",
        "ctoken_impl": "0xed4ab736d758ea2b8be84d610395e40972b51493",
        "sclink_delegator": "0x2359012ebe36cca231203d78b914284947b58aa3",
    }
    out = {}
    for name, addr in targets.items():
        code = rpc("eth_getCode", [addr, "latest"])
        sels = sorted(selectors(code))
        print(f"== {name} {addr}: {len(sels)} selectors", file=sys.stderr)
        res = {}
        for s in sels:
            t = resolve(s)
            res[s] = t
            time.sleep(0.05)
        out[name] = {"address": addr, "selectors": res}
        for s, t in sorted(res.items(), key=lambda kv: kv[1] or "zz"):
            print(f"  {s} {t}", file=sys.stderr)
    json.dump(out, open("/home/heisenberg/CA/scream/analysis/selectors.json", "w"), indent=2)

if __name__ == "__main__":
    main()
