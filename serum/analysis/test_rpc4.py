#!/usr/bin/env python3
"""Verify market layout + measure mainnet-beta gPA throughput/size limits."""
import json, os, sys, time, urllib.request, urllib.error, base64, threading

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from rpc import bytes_to_b58, b58_to_bytes, u64le

PROGRAM = "srmqPvymJeFKQ4zGQed1GFppgkRHL9kaELCbyksJtPX"
MB = "https://api.mainnet-beta.solana.com"

def raw_rpc(ep, method, params, timeout=120):
    body = json.dumps({"jsonrpc": "2.0", "id": 1, "method": method, "params": params}).encode()
    req = urllib.request.Request(ep, data=body, headers={
        "Content-Type": "application/json",
        "User-Agent": "Mozilla/5.0 (X11; Linux x86_64) zombie-hunt/1.0"})
    t0 = time.time()
    with urllib.request.urlopen(req, timeout=timeout) as r:
        raw = r.read()
    return raw, time.time() - t0

def mkfilters(nonce=None, byte0=None, byte1=None, flags=3):
    f = [{"dataSize": 388}, {"memcmp": {"offset": 5, "bytes": bytes_to_b58(u64le(flags))}}]
    if nonce is not None:
        f.append({"memcmp": {"offset": 45, "bytes": bytes_to_b58(u64le(nonce))}})
    if byte0 is not None:
        f.append({"memcmp": {"offset": 13, "bytes": bytes_to_b58(bytes([byte0]))}})
    if byte1 is not None:
        f.append({"memcmp": {"offset": 14, "bytes": bytes_to_b58(bytes([byte1]))}})
    return f

def gpa(filters, slen=328, timeout=180):
    p = [PROGRAM, {"filters": filters, "encoding": "base64",
                   "dataSlice": {"offset": 53, "length": slen}, "commitment": "finalized"}]
    raw, dt = raw_rpc(MB, "getProgramAccounts", p, timeout=timeout)
    j = json.loads(raw)
    if "error" in j:
        raise RuntimeError(str(j["error"])[:200])
    return j["result"], len(raw), dt

def verify_layout():
    for mkt in ("8BnEgHoWFysVcuFFX7QztDmzuH8r5ZFvyP3sYwn1XTh6",
                "9wFFyRfZBsuAha4YcuxcXLKwMxJR43S7fPfQLusDBzvT"):
        p = [mkt, {"encoding": "base64", "commitment": "finalized"}]
        raw, dt = raw_rpc(MB, "getAccountInfo", p)
        j = json.loads(raw)
        res = j.get("result", {}).get("value")
        if not res:
            print(f"layout {mkt[:8]}: NOT FOUND"); continue
        data = base64.b64decode(res["data"][0])
        head = data[0:5]
        flags = int.from_bytes(data[5:13], "little")
        nonce = int.from_bytes(data[45:53], "little")
        cm = bytes_to_b58(data[53:85]); pm = bytes_to_b58(data[85:117])
        cv = bytes_to_b58(data[117:149]); pv = bytes_to_b58(data[165:197])
        cd = int.from_bytes(data[149:157], "little"); pd = int.from_bytes(data[197:205], "little")
        print(f"layout {mkt[:8]}: size={len(data)} head={head} flags={flags} nonce={nonce}")
        print(f"  coin_mint={cm} pc_mint={pm}")
        print(f"  coin_vault={cv} pc_vault={pv} coin_dep={cd} pc_dep={pd}")

def main():
    verify_layout()
    print("--- throughput: 6 sequential byte chunks nonce0 ---")
    t0 = time.time()
    tot = 0
    for b in range(6):
        try:
            res, nraw, dt = gpa(mkfilters(0, b))
            tot += len(res)
            print(f"  b={b} n={len(res)} {nraw/1e6:.2f}MB {dt:.1f}s")
        except Exception as e:
            print(f"  b={b} EXC {str(e)[:120]}")
            break
    print(f"  total {tot} in {time.time()-t0:.1f}s")
    print("--- 4 parallel byte chunks ---")
    t0 = time.time()
    out = {}
    def job(b):
        try:
            res, nraw, dt = gpa(mkfilters(0, b))
            out[b] = (len(res), nraw, dt)
        except Exception as e:
            out[b] = ("EXC", str(e)[:80], 0)
    th = [threading.Thread(target=job, args=(b,)) for b in range(10, 14)]
    for t in th: t.start()
    for t in th: t.join()
    for b in sorted(out): print(f"  b={b} {out[b]}")
    print(f"  parallel total {time.time()-t0:.1f}s")
    print("--- byte1-only filter test (nonce0, byte1=0) ---")
    try:
        res, nraw, dt = gpa(mkfilters(0, None, 0))
        print(f"  byte1=0 n={len(res)} {nraw/1e6:.2f}MB {dt:.1f}s")
    except Exception as e:
        print(f"  byte1 EXC {str(e)[:150]}")
    print("--- single-nonce full queries ---")
    for n in (8, 6, 5):
        try:
            res, nraw, dt = gpa(mkfilters(n, None, None))
            print(f"  nonce{n} n={len(res)} {nraw/1e6:.2f}MB {dt:.1f}s")
        except Exception as e:
            print(f"  nonce{n} EXC {str(e)[:150]}")
        time.sleep(1)

if __name__ == "__main__":
    main()
