#!/usr/bin/env python3
"""Probe all shell contracts at one pinned block via JSON-RPC.

Stage 1: totalSupply() for every shell.
Stage 2: ownerOf(baseType | i) i=1..min(N,25) for NFT shells with N>0.
Stage 3: name() for shells with N>0 (best effort).

Reads BLOCKPI_RPC_URL (fallback RPC_URL) from env. Batches of <=10 calls.
Writes analysis/census/probe_totalSupply.json and probe_owners.jsonl (resumable).
"""
import json, os, sys, time, urllib.request, urllib.error

CENSUS = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
SHELLS = os.path.join(CENSUS, "shells_parsed.json")
OUT_SUPPLY = os.path.join(CENSUS, "probe_totalSupply.json")
OUT_OWNERS = os.path.join(CENSUS, "probe_owners.jsonl")
BURN = "0x0000deaddeaddeaddeaddeaddeaddeaddead0000"

RPCS = [u for u in [os.environ.get("BLOCKPI_RPC_URL"), os.environ.get("NODEREAL_ETH_RPC_URL"), os.environ.get("RPC_URL")] if u]
BATCH = 10

def rpc_batch(calls, tries=6):
    """calls: list of (method, params). Returns list of results (or {'__error__': ...})."""
    payload = [{"jsonrpc": "2.0", "id": i, "method": m, "params": p} for i, (m, p) in enumerate(calls)]
    data = json.dumps(payload).encode()
    last_err = None
    for url in RPCS:
        for t in range(tries):
            try:
                req = urllib.request.Request(url, data=data, headers={"content-type": "application/json", "User-Agent": "Mozilla/5.0 (X11; Linux x86_64) census-probe/1.0"})
                with urllib.request.urlopen(req, timeout=60) as r:
                    body = json.load(r)
                byid = {b["id"]: b for b in body}
                out = []
                for i in range(len(calls)):
                    b = byid.get(i)
                    if b is None:
                        out.append({"__error__": "missing"})
                    elif "error" in b:
                        out.append({"__error__": b["error"].get("message", "rpc error")})
                    else:
                        out.append(b.get("result"))
                return out
            except Exception as e:
                last_err = e
                time.sleep(0.4 + t * 0.5)
    raise RuntimeError(f"RPC batch failed: {last_err}")

def to_addr(word_hex):
    if not word_hex or len(word_hex) < 42:
        return None
    return "0x" + word_hex[-40:]

def main():
    with open(SHELLS) as f:
        shells = json.load(f)["shells"]

    # pinned block
    [blk_hex] = rpc_batch([("eth_blockNumber", [])])
    pinned = int(blk_hex, 16)
    print(f"pinned block: {pinned}", flush=True)

    # stage 1: totalSupply
    results = {}
    if os.path.exists(OUT_SUPPLY):
        with open(OUT_SUPPLY) as f:
            results = json.load(f).get("results", {})
    todo = [s for s in shells if s["shell"] not in results]
    print(f"stage1: {len(todo)} shells to probe", flush=True)
    for i in range(0, len(todo), BATCH):
        chunk = todo[i:i + BATCH]
        calls = [("eth_call", [{"to": s["shell"], "data": "0x18160ddd"}, hex(pinned)]) for s in chunk]
        res = rpc_batch(calls)
        for s, r in zip(chunk, res):
            if isinstance(r, dict):
                results[s["shell"]] = {"totalSupply": None, "error": r.get("__error__")}
            else:
                results[s["shell"]] = {"totalSupply": int(r, 16) if r and r != "0x" else 0}
        if (i // BATCH) % 10 == 0:
            with open(OUT_SUPPLY, "w") as f:
                json.dump({"block": pinned, "results": results}, f)
            print(f"  {i + len(chunk)}/{len(todo)}", flush=True)
        time.sleep(0.05)
    with open(OUT_SUPPLY, "w") as f:
        json.dump({"block": pinned, "results": results}, f)
    ok = sum(1 for v in results.values() if isinstance(v.get("totalSupply"), int))
    nz = sum(1 for v in results.values() if isinstance(v.get("totalSupply"), int) and v["totalSupply"] > 0)
    print(f"stage1 done: {ok} answered, {nz} with totalSupply>0", flush=True)

    # stage 2: owners for NFT shells with supply>0
    done = set()
    if os.path.exists(OUT_OWNERS):
        with open(OUT_OWNERS) as f:
            for line in f:
                if line.strip():
                    done.add(json.loads(line)["shell"])
    nft_todo = []
    for s in shells:
        if s["kind"] != "NFT" or s["shell"] in done:
            continue
        v = results.get(s["shell"], {})
        n = v.get("totalSupply")
        if isinstance(n, int) and n > 0:
            nft_todo.append((s, n))
    print(f"stage2: {len(nft_todo)} NFT shells with supply>0", flush=True)
    fout = open(OUT_OWNERS, "a")
    for s, n in nft_todo:
        base = int(s["baseType"])
        cap = min(n, 25)
        calls = []
        ids = []
        for i in range(1, cap + 1):
            iid = base | i
            ids.append(iid)
            calls.append(("eth_call", [{"to": s["shell"], "data": "0x6352211e" + format(iid, "064x")}, hex(pinned)]))
        res = rpc_batch(calls)
        owners = []
        for iid, r in zip(ids, res):
            if isinstance(r, dict):
                owners.append({"id": str(iid), "owner": None, "error": r.get("__error__")})
            else:
                owners.append({"id": str(iid), "owner": to_addr(r)})
        # name (best effort)
        [nres] = rpc_batch([("eth_call", [{"to": s["shell"], "data": "0x06fdde03"}, hex(pinned)])])
        name = None
        if isinstance(nres, str) and len(nres) > 130:
            try:
                h = nres[2:]
                off = int(h[0:64], 16) * 2
                ln = int(h[off:off + 64], 16) * 2
                name = bytes.fromhex(h[off + 64:off + 64 + ln]).decode("utf8", "replace")
            except Exception:
                name = None
        rec = {"shell": s["shell"], "baseType": s["baseType"], "kind": "NFT",
               "totalSupply": n, "scanned": cap, "block": pinned, "name": name, "owners": owners}
        fout.write(json.dumps(rec) + "\n")
        fout.flush()
    fout.close()
    print("stage2 done", flush=True)

if __name__ == "__main__":
    main()
