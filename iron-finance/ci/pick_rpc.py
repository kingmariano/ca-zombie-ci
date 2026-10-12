#!/usr/bin/env python3
"""Probe RPC candidates for *fork viability* (not just reads).
Tests: blockNumber, block-by-number(hash), block-by-hash (the failure mode
seen in CI), and state reads at that block. Writes a public-safe choice:
  ENV  -> test should use its env var (never write the keyed URL anywhere)
  <url> -> a keyless public URL to use directly
Usage: python3 ci/pick_rpc.py <envvar> <outfile> <public1> <public2> ...
"""
import json, os, sys, urllib.request

def rpc(url, method, params):
    req = urllib.request.Request(url, data=json.dumps({
        "jsonrpc": "2.0", "id": 1, "method": method, "params": params}).encode(),
        headers={"Content-Type": "application/json", "User-Agent": "Mozilla/5.0 (research; read-only)"})
    r = json.load(urllib.request.urlopen(req, timeout=25))
    if "error" in r:
        raise RuntimeError(str(r["error"])[:120])
    return r["result"]

def viable(url, probe_addr):
    try:
        bn = rpc(url, "eth_blockNumber", [])
        blk = rpc(url, "eth_getBlockByNumber", [bn, False])
        h = blk["hash"]
        # the CI failure mode: header-by-hash lookup error
        bh = rpc(url, "eth_getBlockByHash", [h, False])
        assert bh and bh.get("number") == bn
        # state availability at that block
        rpc(url, "eth_getCode", [probe_addr, bn])
        rpc(url, "eth_getStorageAt", [probe_addr, "0x0", bn])
        rpc(url, "eth_getBalance", [probe_addr, bn])
        return True
    except Exception:
        return False

def main():
    env_name, outfile = sys.argv[1], sys.argv[2]
    publics = sys.argv[3:]
    candidates = []
    env_url = os.environ.get(env_name)
    if env_url:
        candidates.append(("ENV", env_url))
    for p in publics:
        candidates.append((p, p))
    probe = "0x837503e8A8753ae17fB8C8151B8e6f586defCb57"  # IS3USD pool
    for label, url in candidates:
        ok = viable(url, probe)
        print(f"{label}: {'OK' if ok else 'not viable'}")
        if ok:
            with open(outfile, "w") as f:
                f.write(label)
            print(f"-> wrote {outfile}: {label}")
            return
    # nothing viably forks; still write ENV and let the test try (with fallback)
    with open(outfile, "w") as f:
        f.write("ENV")
    print(f"-> no candidate passed probe; wrote ENV to {outfile}")

if __name__ == "__main__":
    main()
