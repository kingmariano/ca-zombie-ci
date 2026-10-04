#!/usr/bin/env python3
"""Characterize mainnet-beta gPA limits + retry Alchemy/Nodereal variants."""
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

def raw_rpc(ep, method, params, timeout=120, tries=1, backoff=5, tag=""):
    body = json.dumps({"jsonrpc": "2.0", "id": 1, "method": method, "params": params}).encode()
    last = None
    for a in range(tries):
        try:
            req = urllib.request.Request(ep, data=body, headers={
                "Content-Type": "application/json",
                "User-Agent": "Mozilla/5.0 (X11; Linux x86_64) zombie-hunt/1.0"})
            t0 = time.time()
            with urllib.request.urlopen(req, timeout=timeout) as r:
                raw = r.read()
            return raw, time.time() - t0
        except Exception as e:
            last = e
            time.sleep(backoff * (a + 1))
    raise last

def mkfilters(nonce=None, byte0=None, byte1=None, flags=3):
    f = [{"dataSize": 388}, {"memcmp": {"offset": 5, "bytes": bytes_to_b58(u64le(flags))}}]
    if nonce is not None:
        f.append({"memcmp": {"offset": 45, "bytes": bytes_to_b58(u64le(nonce))}})
    if byte0 is not None:
        f.append({"memcmp": {"offset": 13, "bytes": bytes_to_b58(bytes([byte0]))}})
    if byte1 is not None:
        f.append({"memcmp": {"offset": 14, "bytes": bytes_to_b58(bytes([byte1]))}})
    return f

def gpa(ep, filters, slen=0, timeout=120, tag=""):
    p = [PROGRAM, {"filters": filters, "encoding": "base64",
                   "dataSlice": {"offset": 53, "length": slen}, "commitment": "finalized"}]
    raw, dt = raw_rpc(ep, "getProgramAccounts", p, timeout=timeout, tag=tag)
    j = json.loads(raw)
    if "error" in j:
        raise RuntimeError(str(j["error"])[:200])
    return j["result"], len(raw), dt

MB = "https://api.mainnet-beta.solana.com"

def test_mb():
    print("== mainnet-beta ==")
    # 1. two-byte filter tiny
    try:
        res, nraw, dt = gpa(MB, mkfilters(0, 0, 0), 0, timeout=60)
        print(f"tiny(2B) count={len(res)} raw={nraw/1e3:.1f}KB {dt:.1f}s")
    except Exception as e:
        print("tiny(2B) EXC", str(e)[:160])
    time.sleep(3)
    # 2. one-byte filter small nonce + 328 slice (nonce8 ~1449 total)
    try:
        res, nraw, dt = gpa(MB, mkfilters(8, 0), 328, timeout=120)
        print(f"nonce8 byte0 slice328 count={len(res)} raw={nraw/1e6:.3f}MB {dt:.1f}s")
    except Exception as e:
        print("nonce8 byte0 slice328 EXC", str(e)[:160])
    time.sleep(3)
    # 3. one-byte filter nonce0 slice0 (big)
    try:
        res, nraw, dt = gpa(MB, mkfilters(0, 0), 0, timeout=120)
        print(f"nonce0 byte0 slice0 count={len(res)} raw={nraw/1e6:.3f}MB {dt:.1f}s")
    except Exception as e:
        print("nonce0 byte0 slice0 EXC", str(e)[:160])

def test_alchemy():
    for label, key in (("alchemy1", E.get("ALCHEMY_API_KEY")), ("alchemy2", E.get("ALCHEMY_API_KEY_2"))):
        if not key:
            continue
        ep = f"https://solana-mainnet.g.alchemy.com/v2/{key}"
        try:
            raw, dt = raw_rpc(ep, "getSlot", [], timeout=30, tries=3, backoff=20)
            print(f"== {label} getSlot OK {dt:.1f}s")
        except Exception as e:
            print(f"== {label} getSlot EXC {str(e)[:120]}")
            continue
        try:
            res, nraw, dt = gpa(ep, mkfilters(8, 0), 328, timeout=120)
            print(f"{label} nonce8 gPA count={len(res)} raw={nraw/1e3:.1f}KB {dt:.1f}s")
        except Exception as e:
            print(f"{label} gPA EXC {str(e)[:200]}")

def test_nodereal():
    key = E.get("NODEREAL_API_KEY")
    if not key:
        return
    for host in ("https://solana.nodereal.io/v1/", "https://solana-mainnet.nodereal.io/v1/", "https://solana-api.nodereal.io/v1/"):
        ep = host + key
        try:
            raw, dt = raw_rpc(ep, "getVersion", [], timeout=20)
            print(f"== {host.split('//')[1].split('/')[0]} OK {raw[:80]}")
            try:
                res, nraw, dt = gpa(ep, mkfilters(8, 0), 328, timeout=120)
                print(f"  gPA count={len(res)} raw={nraw/1e3:.1f}KB {dt:.1f}s")
            except Exception as e:
                print("  gPA EXC", str(e)[:160])
        except Exception as e:
            print(f"== {host.split('//')[1].split('/')[0]} EXC {str(e)[:100]}")

if __name__ == "__main__":
    test_mb()
    test_alchemy()
    test_nodereal()
