#!/usr/bin/env python3
"""
cog (Scroll) positions scanner v3 — Multicall3-batched, resumable.
Reuses ci-out/positions_partial.json user lists where present; collects logs for the rest.
Outputs ci-out/positions.json.
"""
import json, os, sys, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from multicall import rpc, aggregate3, sel

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
OUT = os.path.join(ROOT, "ci-out")

from Crypto.Hash import keccak
def evsig(s):
    k = keccak.new(digest_bits=256); k.update(s.encode()); return "0x" + k.hexdigest()

SIGB = evsig("Borrow(uint256,address,address)")
SIGA = evsig("AddCollateral(address,uint256,uint256)")
SIGR = evsig("RemoveCollateral(address,uint256,uint256)")
SEL_BP = sel("user_borrow_part(address)")
SEL_CS = sel("user_collateral_share(address)")

def topic_addr(t): return "0x" + t[-40:]

def get_users(pair):
    users = set()
    logs = rpc("eth_getLogs", [{"address": pair, "fromBlock": hex(85518), "toBlock": "latest",
                                "topics": [[SIGB, SIGA, SIGR]]}], timeout=45)
    for lg in logs:
        tp = lg["topics"]; t0 = tp[0].lower()
        if t0 == SIGB and len(tp) >= 4:
            users.add(topic_addr(tp[2])); users.add(topic_addr(tp[3]))
        elif t0 in (SIGA, SIGR) and len(tp) >= 2:
            users.add(topic_addr(tp[1]))
    return sorted(users), len(logs)

def main():
    d = json.load(open(os.path.join(OUT, "state_latest.json")))
    pairs = [p["pair"] for p in d["pairs"] if "err" not in p]
    partial = {}
    pp = os.path.join(OUT, "positions_partial.json")
    if os.path.exists(pp):
        try: partial = json.load(open(pp))
        except Exception: partial = {}
    users_map = {}
    for pair in pairs:
        if pair in partial and isinstance(partial[pair], dict) and "users" not in partial[pair]:
            # old format stores positions only; extract user addresses
            users = [p["user"] for p in partial[pair].get("positions", [])]
            # old scan only stored nonzero users; we also want all users for negative evidence
            if users:
                users_map[pair] = sorted(set(users))
    # collect users for pairs not covered
    for i, pair in enumerate(pairs):
        if pair in users_map:
            continue
        try:
            users, nlogs = get_users(pair)
            users_map[pair] = users
            print(f"[users {i+1}/{len(pairs)}] {pair} logs={nlogs} users={len(users)}", flush=True)
        except Exception as e:
            users_map[pair] = []
            print(f"[users {i+1}/{len(pairs)}] {pair} ERR {str(e)[:80]}", flush=True)
    json.dump(users_map, open(os.path.join(OUT, "users_map.json"), "w"), indent=1)

    # batched reads
    out = {}
    for i, pair in enumerate(pairs):
        users = users_map.get(pair, [])
        pos = []
        CH = 90  # users per multicall batch (180 calls)
        for j in range(0, len(users), CH):
            chunk = users[j:j+CH]
            calls = []
            for u in chunk:
                calls.append((pair, SEL_BP + u[2:].rjust(64, "0")))
                calls.append((pair, SEL_CS + u[2:].rjust(64, "0")))
            try:
                res = aggregate3(calls)
            except Exception as e:
                pos.append({"err": str(e)[:80], "chunk_start": j})
                continue
            for k, u in enumerate(chunk):
                bp = res[2*k] if 2*k < len(res) else (False, "0x")
                cs = res[2*k+1] if 2*k+1 < len(res) else (False, "0x")
                bv = int(bp[1], 16) if bp[0] and bp[1] != "0x" else None
                cv = int(cs[1], 16) if cs[0] and cs[1] != "0x" else None
                if (bv or 0) > 0 or (cv or 0) > 0:
                    pos.append({"user": u, "borrow_part": bv, "collateral_share": cv})
        out[pair] = {"users_n": len(users), "positions": pos}
        print(f"[pos {i+1}/{len(pairs)}] {pair} users={len(users)} live={len(pos)}", flush=True)
        json.dump(out, open(os.path.join(OUT, "positions.json"), "w"), indent=1)
    print("done")

if __name__ == "__main__":
    main()
