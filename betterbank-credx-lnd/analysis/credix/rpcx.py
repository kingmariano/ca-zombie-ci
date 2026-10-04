#!/usr/bin/env python3
"""Read-only JSON-RPC helper for Sonic (chain 146). No signing, no sending."""
import json
import urllib.request

SONIC = "https://sonic-rpc.publicnode.com"
FALLBACKS = ["https://sonic.drpc.org", "https://sonic.api.onfinality.io/public",
             "https://rpc.soniclabs.com"]


def rpc(method, params, url=SONIC, _id=1, timeout=60):
    req = urllib.request.Request(url, data=json.dumps({
        "jsonrpc": "2.0", "id": _id, "method": method, "params": params
    }).encode(), headers={"Content-Type": "application/json", "User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        out = json.load(r)
    if "error" in out:
        return {"error": out["error"]}
    return out.get("result")


def batch(calls, url=SONIC, timeout=120):
    """calls: list of (method, params). Returns list of results (or {'error':..})."""
    payload = [{"jsonrpc": "2.0", "id": i, "method": m, "params": p}
               for i, (m, p) in enumerate(calls)]
    req = urllib.request.Request(url, data=json.dumps(payload).encode(),
                                 headers={"Content-Type": "application/json",
                                          "User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        out = json.load(r)
    res = [None] * len(calls)
    for item in out:
        i = item.get("id")
        res[i] = item.get("result") if "error" not in item else {"error": item["error"]}
    return res


def eth_call(to, data, block="latest", url=SONIC):
    return rpc("eth_call", [{"to": to, "data": data}, block], url=url)


def call_many(to, datas, block="latest", url=SONIC):
    calls = [("eth_call", [{"to": to, "data": d}, block]) for d in datas]
    return batch(calls, url=url)


def dec_u(hexstr):
    if not hexstr or hexstr in ("0x", "0x0"):
        return 0
    return int(hexstr, 16)


def addr_from_word(hexstr):
    return "0x" + hexstr[-40:]


# --- minimal ABI encoding helpers (static types + dynamic address) ---
def pad32(h):
    h = h.lower().replace("0x", "")
    return h.rjust(64, "0")


def enc_addr(a):
    return pad32(a)


def enc_uint(v):
    return pad32(hex(v)[2:])


def enc_selector(sig):
    import subprocess
    return subprocess.run(["cast", "sig", sig], capture_output=True, text=True,
                          check=True).stdout.strip()


def enc_bytes32(b):
    return pad32(b)


if __name__ == "__main__":
    print("block", int(rpc("eth_blockNumber", []), 16))
