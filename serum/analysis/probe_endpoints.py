#!/usr/bin/env python3
"""Probe Solana RPC endpoints for getProgramAccounts support on Serum v3.
Read-only. Never prints secrets (URLs are masked)."""
import json, os, re, sys, urllib.request, urllib.error

SERUM = "9xQeWvG816bUx9EPjHmaT23yvVM2ZWbrrpZb9PusVFin"
ALPHA = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"

def b58_to_bytes(s):
    n = 0
    for ch in s:
        n = n * 58 + ALPHA.index(ch)
    b = n.to_bytes((n.bit_length() + 7) // 8, "big") if n else b""
    return b"\x00" * (len(s) - len(s.lstrip("1"))) + b

def bytes_to_b58(b):
    n = int.from_bytes(b, "big")
    out = ""
    while n:
        n, r = divmod(n, 58)
        out = ALPHA[r] + out
    return "1" * (len(b) - len(b.lstrip(b"\x00"))) + out

def load_env(path="/home/heisenberg/CA/.env"):
    env = {}
    try:
        with open(path) as f:
            for line in f:
                line = line.strip()
                if not line or line.startswith("#") or "=" not in line:
                    continue
                k, v = line.split("=", 1)
                env[k.strip()] = v.strip().strip('"').strip("'")
    except Exception as e:
        print("env load error:", e)
    return env

E = load_env()

def mask(u):
    return re.sub(r"(/(?:v2|ogrpc|)[^/ ]*?(?:key|token|dkey)=)[^& ]+", r"\1<redacted>", u) \
        if "?" in u else re.sub(r"/(v2|)[A-Za-z0-9_\-]{20,}$", "/<redacted>", u)

def candidates():
    c = [
        ("mainnet-beta", "https://api.mainnet-beta.solana.com", None),
        ("publicnode", "https://solana-rpc.publicnode.com", None),
        ("free.rpcpool", "https://free.rpcpool.com", None),
        ("metaplex", "https://api.metaplex.solana.com", None),
        ("public-rpc", "https://solana.public-rpc.com", None),
        ("hellomoon", "https://rpc.hellomoon.io", None),
        ("genesysgo", "https://ssc-dao.genesysgo.net", None),
        ("rpcpool-mainnet", "https://solana-mainnet.rpcpool.com", None),
        ("1rpc", "https://1rpc.io/solana", None),
        ("drpc-public", "https://solana.drpc.org", None),
        ("ankr-public", "https://rpc.ankr.com/solana", None),
    ]
    if E.get("ALCHEMY_API_KEY"):
        c.append(("alchemy", f"https://solana-mainnet.g.alchemy.com/v2/{E['ALCHEMY_API_KEY']}", "header"))
    if E.get("ALCHEMY_API_KEY_2"):
        c.append(("alchemy2", f"https://solana-mainnet.g.alchemy.com/v2/{E['ALCHEMY_API_KEY_2']}", "header"))
    if E.get("ANKR_API_KEY"):
        c.append(("ankr-key", f"https://rpc.ankr.com/solana/{E['ANKR_API_KEY']}", "header"))
    if E.get("DRPC_API_KEY"):
        c.append(("drpc-key", f"https://lb.drpc.org/ogrpc?network=solana&dkey={E['DRPC_API_KEY']}", "header"))
    if E.get("QUICKNODE_API_KEY"):
        c.append(("quicknode", f"https://solana-mainnet.quiknode.pro/{E['QUICKNODE_API_KEY']}", "header"))
    return c

def call(url, method, params, timeout=45):
    body = json.dumps({"jsonrpc": "2.0", "id": 1, "method": method, "params": params}).encode()
    req = urllib.request.Request(url, data=body, headers={
        "Content-Type": "application/json",
        "User-Agent": "Mozilla/5.0 (X11; Linux x86_64) zombie-hunt/1.0"})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return json.loads(r.read().decode())

def summarize(method, params):
    if method == "getProgramAccounts":
        return [{"dataSize": 388, "memcmp": {"offset": 5, "bytes": bytes_to_b58((3).to_bytes(8, "little"))}}]
    return params

for name, url, kind in candidates():
    out = {"endpoint": mask(url)}
    try:
        j = call(url, "getVersion", [])
        out["version"] = j.get("result", {}).get("solana-core") if isinstance(j.get("result"), dict) else j.get("error")
    except Exception as e:
        out["version"] = f"ERR {type(e).__name__}: {str(e)[:120]}"
    # small gPA test
    try:
        flt = summarize("getProgramAccounts", None)
        j = call(url, "getProgramAccounts", [SERUM, {"encoding": "base64", "filters": flt}])
        if "error" in j:
            out["gpa"] = f"ERROR {json.dumps(j['error'])[:200]}"
        elif isinstance(j.get("result"), list):
            out["gpa"] = f"OK count={len(j['result'])}"
        else:
            out["gpa"] = f"UNEXPECTED {str(j)[:150]}"
    except urllib.error.HTTPError as e:
        body = ""
        try:
            body = e.read().decode()[:150]
        except Exception:
            pass
        out["gpa"] = f"HTTP {e.code} {body}"
    except Exception as e:
        out["gpa"] = f"ERR {type(e).__name__}: {str(e)[:120]}"
    print(json.dumps(out, default=str), flush=True)
