#!/usr/bin/env python3
"""Sample tail indices (>25) of NFT shells where N>25 to look for survivors missed by the
first-25 scan. Writes probe_tails.jsonl. Resumable per shell."""
import json, os, sys, time

CENSUS = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
OUT = os.path.join(CENSUS, "probe_tails.jsonl")
BURN = "0x0000deaddeaddeaddeaddeaddeaddeaddead0000"
ZERO = "0x0000000000000000000000000000000000000000"
DEAD = "0x000000000000000000000000000000000000dead"

exec(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "probe_shells.py")).read().split("def main")[0])

def main():
    shells = json.load(open(os.path.join(CENSUS, "shells_parsed.json")))["shells"]
    sup = json.load(open(os.path.join(CENSUS, "probe_totalSupply.json")))["results"]
    ENVOY = "0x0f1f62c38fa21da98bdcfb2f06e8a20dba979791"  # already fully scanned
    mine = {json.loads(l)["shell"] for l in open(OUT)} if os.path.exists(OUT) else set()
    todo = []
    for s in shells:
        if s["kind"] != "NFT" or s["shell"] in mine or s["shell"] == ENVOY:
            continue
        N = sup[s["shell"]].get("totalSupply")
        if isinstance(N, int) and N > 25:
            todo.append((s, N))
    print(f"tail-sampling {len(todo)} shells", flush=True)
    [pinned] = [int(rpc_batch([("eth_blockNumber", [])])[0], 16)]
    fout = open(OUT, "a")
    for s, N in todo:
        base = int(s["baseType"])
        k = 10
        idxs = sorted({26, min(N, 27), min(N, 30), N // 8, N // 4, N // 2, (3 * N) // 4, max(26, N - 8), max(26, N - 3), N})
        idxs = [i for i in idxs if 26 <= i <= N and i >= 1]
        calls = [("eth_call", [{"to": s["shell"], "data": "0x6352211e" + format(base | i, "064x")}, hex(pinned)]) for i in idxs]
        res = []
        for i in range(0, len(calls), 10):
            res.extend(rpc_batch(calls[i:i + 10]))
        owners = []
        for i, v in zip(idxs, res):
            owners.append({"id": str(base | i), "idx": i, "owner": None if isinstance(v, dict) else "0x" + v[-40:],
                           **({"error": v.get("__error__")} if isinstance(v, dict) else {})})
        rec = {"shell": s["shell"], "baseType": s["baseType"], "totalSupply": N, "block": pinned,
               "sampled": idxs, "owners": owners}
        fout.write(json.dumps(rec) + "\n")
        fout.flush()
    fout.close()
    print("done", flush=True)

if __name__ == "__main__":
    main()
