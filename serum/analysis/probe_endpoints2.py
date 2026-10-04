#!/usr/bin/env python3
"""Second endpoint sweep for Solana gPA. Read-only, masks secrets."""
import json, os, re, urllib.request, urllib.error
from probe_endpoints import b58_to_bytes, bytes_to_b58, load_env, SERUM, mask

E = load_env()
FLT = {"dataSize": 388, "memcmp": {"offset": 5, "bytes": bytes_to_b58((3).to_bytes(8, "little"))}}

pub = [
    ("blastapi", "https://solana-mainnet.public.blastapi.io"),
    ("onfinality", "https://solana.api.onfinality.io/public"),
    ("coinsdo", "https://rpc.coinsdo.net/solana"),
    ("extrnode", "https://solana-mainnet.rpc.extrnode.com"),
    ("mathwallet", "https://solana.mathwallet.xyz"),
    ("blockpi", E.get("BLOCKPI_RPC_URL", "").rstrip("/") + "/solana" if E.get("BLOCKPI_RPC_URL") else ""),
    ("4everland", "https://solana-mainnet.4everland.org/v1/public"),
    ("nownodes", "https://sol.nownodes.io"),
    ("tatum", "https://solana-mainnet.gateway.tatum.io"),
    ("grove", "https://solana.rpc.grove.city/v1/01f2cf03"),
    ("alchemy2sol", f"https://solana-mainnet.g.alchemy.com/v2/{E.get('ALCHEMY_API_KEY_2','')}"),
    ("nodereal", f"https://solana-mainnet.nodereal.io/v1/{E.get('NODEREAL_API_KEY','')}"),
    ("ankr2", f"https://rpc.ankr.com/solana/{E.get('ANKR_API_KEY','')}"),
]
cands = [(n, u) for n, u in pub if u and u.startswith("http")]

def call(url, method, params, timeout=40):
    body = json.dumps({"jsonrpc": "2.0", "id": 1, "method": method, "params": params}).encode()
    req = urllib.request.Request(url, data=body, headers={
        "Content-Type": "application/json",
        "User-Agent": "Mozilla/5.0 (X11; Linux x86_64) zombie-hunt/1.0"})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return json.loads(r.read().decode())

for name, url in cands:
    out = {"endpoint": name, "host": urllib.request.urlparse(url).netloc}
    try:
        j = call(url, "getVersion", [])
        out["version"] = j.get("result", {}).get("solana-core") if isinstance(j.get("result"), dict) else str(j.get("error"))[:100]
    except Exception as e:
        out["version"] = f"ERR {type(e).__name__}: {str(e)[:90]}"
    if "version" in out and str(out["version"]).startswith("ERR"):
        print(json.dumps(out), flush=True); continue
    try:
        j = call(url, "getProgramAccounts", [SERUM, {"encoding": "base64", "filters": [FLT]}])
        if "error" in j:
            out["gpa"] = f"ERROR {json.dumps(j['error'])[:180]}"
        else:
            out["gpa"] = f"OK count={len(j['result'])}"
    except urllib.error.HTTPError as e:
        try: body = e.read().decode()[:140]
        except Exception: body = ""
        out["gpa"] = f"HTTP {e.code} {body}"
    except Exception as e:
        out["gpa"] = f"ERR {type(e).__name__}: {str(e)[:110]}"
    print(json.dumps(out), flush=True)
