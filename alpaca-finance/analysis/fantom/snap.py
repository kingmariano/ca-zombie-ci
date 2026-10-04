#!/usr/bin/env python3
"""Read-only batched JSON-RPC snapshot helper for the Alpaca Fantom audit.

Only eth_call / eth_getLogs / eth_getStorageAt are used. No signing, no tx.
"""
import json, sys, urllib.request, time, os

RPCS = {
    "ftm": os.environ.get("FTM_RPC", "https://rpcapi.fantom.network"),
    "bsc": os.environ.get("BSC_RPC", "https://bsc-rpc.publicnode.com"),
}

def selector(sig):
    sel = {}
    here = os.path.dirname(os.path.abspath(__file__))
    with open(os.path.join(here, "sigs.txt")) as f:
        for line in f:
            parts = line.split()
            if len(parts) >= 2:
                sel[" ".join(parts[1:])] = parts[0]
    return sel[sig]

def enc_arg(a):
    if isinstance(a, str) and a.startswith("0x"):
        raw = a[2:]
    elif isinstance(a, bool):
        raw = "01" if a else "00"
    else:
        raw = format(int(a), "x")
    return raw.rjust(64, "0")

def enc_call(to, sig, args=()):
    data = selector(sig)
    if not data.startswith("0x"):
        data = "0x" + data
    for a in args:
        data += enc_arg(a)
    return {"to": to, "data": data}

def rpc_batch(chain, calls):
    """calls: list of dicts (to,data[,from]). Returns list of {result|error}."""
    url = RPCS[chain]
    out = []
    CH = 32
    for i in range(0, len(calls), CH):
        chunk = calls[i:i+CH]
        payload = [
            {"jsonrpc": "2.0", "id": j, "method": "eth_call",
             "params": [{"to": c["to"], "data": c["data"], **({"from": c["from"]} if "from" in c else {})}, "latest"]}
            for j, c in enumerate(chunk)
        ]
        body = json.dumps(payload).encode()
        for attempt in range(4):
            try:
                req = urllib.request.Request(url, data=body, headers={"Content-Type": "application/json"})
                with urllib.request.urlopen(req, timeout=90) as r:
                    res = json.loads(r.read().decode())
                res = sorted(res, key=lambda x: x.get("id", 0))
                out.extend(res)
                break
            except Exception as e:
                if attempt == 3:
                    out.extend([{"error": str(e)}] * len(chunk))
                else:
                    time.sleep(1.5 * (attempt + 1))
        time.sleep(0.05)
    return out

def dec_addr(hexstr):
    h = hexstr[2:].rjust(64, "0")
    return "0x" + h[-40:]

def dec_uint(hexstr):
    return int(hexstr, 16) if hexstr and hexstr != "0x" else 0

def dec_int(hexstr):
    v = dec_uint(hexstr)
    return v - 2**256 if v >= 2**255 else v

def dec_bool(hexstr):
    return dec_uint(hexstr) != 0

def dec_str(hexstr):
    if not hexstr or hexstr == "0x":
        return ""
    b = bytes.fromhex(hexstr[2:])
    # first word offset, second word len
    off = int.from_bytes(b[0:32], "big")
    ln = int.from_bytes(b[off:off+32], "big")
    return b[off+32:off+32+ln].decode("utf8", "replace")

def words(hexstr):
    b = hexstr[2:] if hexstr.startswith("0x") else hexstr
    return [b[i:i+64] for i in range(0, len(b), 64)]

def show(label, res):
    if "result" in res:
        print(f"{label}: {res['result']}")
    else:
        print(f"{label}: ERR {res.get('error')}")
