#!/usr/bin/env python3
"""Test Solana gPA on endpoints with keys from .env (masked output)."""
import json, os, sys, time, urllib.request, urllib.error

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from rpc import bytes_to_b58, u64le

PROGRAM = "srmqPvymJeFKQ4zGQed1GFppgkRHL9kaELCbyksJtPX"

def load_env(path="/home/heisenberg/CA/.env"):
    env = {}
    for line in open(path):
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        k, v = line.split("=", 1)
        env[k.strip()] = v.strip().strip('"').strip("'")
    return env

E = load_env()

def raw_rpc(ep, method, params, timeout=90):
    body = json.dumps({"jsonrpc": "2.0", "id": 1, "method": method, "params": params}).encode()
    req = urllib.request.Request(ep, data=body, headers={
        "Content-Type": "application/json",
        "User-Agent": "Mozilla/5.0 (X11; Linux x86_64) zombie-hunt/1.0"})
    t0 = time.time()
    with urllib.request.urlopen(req, timeout=timeout) as r:
        raw = r.read()
    return raw, time.time() - t0

def endpoint_list():
    eps = []
    if E.get("NODEREAL_API_KEY"):
        eps.append(("nodereal", f"https://solana-mainnet.nodereal.io/v1/{E['NODEREAL_API_KEY']}"))
    if E.get("ALCHEMY_API_KEY_2"):
        eps.append(("alchemy2", f"https://solana-mainnet.g.alchemy.com/v2/{E['ALCHEMY_API_KEY_2']}"))
    if E.get("ALCHEMY_API_KEY"):
        eps.append(("alchemy1", f"https://solana-mainnet.g.alchemy.com/v2/{E['ALCHEMY_API_KEY']}"))
    blk = E.get("BLOCKPI_RPC_URL", "")
    key = blk.rstrip("/").split("/")[-1] if blk else ""
    if key and key not in ("rpc", "public"):
        eps.append(("blockpi-sol", f"https://solana.blockpi.network/v1/rpc/{key}"))
    eps.append(("blast", "https://solana-mainnet.public.blastapi.io"))
    eps.append(("onfinality", "https://solana.api.onfinality.io/public"))
    return eps

def trial(name, ep, use_filters=True):
    params_ver = []
    try:
        raw, dt = raw_rpc(ep, "getVersion", params_ver, timeout=30)
        j = json.loads(raw)
        ok = "result" in j
        print(f"[{name}] getVersion ok={ok} {dt:.1f}s {str(j.get('error'))[:100] if not ok else ''}")
        if not ok:
            return
    except Exception as e:
        print(f"[{name}] getVersion EXC {str(e)[:120]}")
        return
    filt = [
        {"dataSize": 388},
        {"memcmp": {"offset": 5, "bytes": bytes_to_b58(u64le(3))}},
        {"memcmp": {"offset": 45, "bytes": bytes_to_b58(u64le(0))}},
        {"memcmp": {"offset": 13, "bytes": bytes_to_b58(b"\x00")}},
    ]
    p = [PROGRAM, {"filters": filt, "encoding": "base64",
                   "dataSlice": {"offset": 53, "length": 0}, "commitment": "finalized"}]
    try:
        raw, dt = raw_rpc(ep, "getProgramAccounts", p, timeout=120)
        j = json.loads(raw)
        if "error" in j:
            print(f"[{name}] gPA ERROR {str(j['error'])[:200]} ({dt:.1f}s)")
            return
        res = j.get("result")
        n = len(res) if isinstance(res, list) else "?"
        print(f"[{name}] gPA OK count={n} raw={len(raw)/1e6:.3f}MB {dt:.1f}s")
    except Exception as e:
        print(f"[{name}] gPA EXC {str(e)[:160]}")

if __name__ == "__main__":
    for name, ep in endpoint_list():
        trial(name, ep)
        time.sleep(0.5)
