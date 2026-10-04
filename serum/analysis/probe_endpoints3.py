#!/usr/bin/env python3
"""Retry gPA on rate-limited public endpoints + test a few extras. Read-only."""
import json, time, urllib.request, urllib.error
from probe_endpoints import SERUM, bytes_to_b58

FLT = [{"dataSize": 388}, {"memcmp": {"offset": 5, "bytes": bytes_to_b58((3).to_bytes(8, "little"))}}]

def call(url, method, params, timeout=60):
    body = json.dumps({"jsonrpc": "2.0", "id": 1, "method": method, "params": params}).encode()
    req = urllib.request.Request(url, data=body, headers={
        "Content-Type": "application/json",
        "User-Agent": "Mozilla/5.0 (X11; Linux x86_64) zombie-hunt/1.0"})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return json.loads(r.read().decode())

cands = [
    ("onfinality", "https://solana.api.onfinality.io/public"),
    ("solana-fm-v0", "https://api.solana.fm/v0/accounts"),
    ("solana-fm-v1", "https://api.solana.fm/v1/accounts"),
    ("blockdaemon", "https://svc.blockdaemon.com/solana/mainnet/native"),
    ("zyro", "https://rpc.zyro.capital"),
    ("gatewayfm", "https://solana-mainnet.gatewayfm.com"),
    ("mainnet1", "https://mainnet.helius-rpc.com"),
    ("public-getblock", "https://solana.getblock.io/mainnet-beta/"),
]
for name, url in cands:
    out = {"endpoint": name, "url": url.split("/")[2]}
    for attempt in range(3):
        try:
            j = call(url, "getVersion", [], timeout=30)
            out["version"] = str(j.get("result") or j.get("error"))[:100]
            break
        except urllib.error.HTTPError as e:
            out["version_err"] = f"HTTP {e.code}"
            time.sleep(3 * (attempt + 1))
        except Exception as e:
            out["version_err"] = f"{type(e).__name__}: {str(e)[:80]}"
            break
    if "version" in out:
        try:
            j = call(url, "getProgramAccounts", [SERUM, {"encoding": "base64", "filters": FLT}], timeout=120)
            if "error" in j:
                out["gpa"] = f"ERROR {json.dumps(j['error'])[:160]}"
            else:
                out["gpa"] = f"OK count={len(j['result'])}"
        except urllib.error.HTTPError as e:
            out["gpa"] = f"HTTP {e.code} {e.read().decode()[:120]}"
        except Exception as e:
            out["gpa"] = f"ERR {type(e).__name__}: {str(e)[:100]}"
    print(json.dumps(out), flush=True)
