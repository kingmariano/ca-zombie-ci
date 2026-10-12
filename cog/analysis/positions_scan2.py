#!/usr/bin/env python3
"""
cog (Scroll) borrower-position scanner v2 — resumable, one getLogs call per pair.
Outputs ci-out/positions_partial.json (incremental) and ci-out/positions.json (final).
"""
import json, os, time, urllib.request
from Crypto.Hash import keccak

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
OUT = os.path.join(ROOT, "ci-out")
RPCS = ["https://rpc.scroll.io", "https://scroll-rpc.publicnode.com", "https://scroll.drpc.org"]
_rr = [0]

def rpc(method, params, tries=4, timeout=30):
    body = json.dumps({"jsonrpc": "2.0", "id": 1, "method": method, "params": params}).encode()
    last = None
    for i in range(tries):
        u = RPCS[_rr[0] % len(RPCS)]; _rr[0] += 1
        try:
            req = urllib.request.Request(u, data=body, headers={"Content-Type": "application/json",
                                                                "User-Agent": "Mozilla/5.0 (research; read-only)"})
            with urllib.request.urlopen(req, timeout=timeout) as r:
                d = json.loads(r.read().decode())
            if "result" in d: return d["result"]
            last = str(d.get("error"))
        except Exception as e:
            last = str(e)
        time.sleep(0.15 + 0.25 * i)
    raise RuntimeError(f"rpc failed {method}: {last}")

def words(h):
    h = h[2:] if h.startswith("0x") else h
    return [h[i:i+64] for i in range(0, len(h) - 63, 64)]

def uint(w): return int(w, 16)
def topic_addr(t): return "0x" + t[-40:]
def sel(sig):
    k = keccak.new(digest_bits=256); k.update(sig.encode()); return "0x" + k.hexdigest()[:8]
def evsig(sig):
    k = keccak.new(digest_bits=256); k.update(sig.encode()); return "0x" + k.hexdigest()

SIG = {
    "borrow": evsig("Borrow(uint256,address,address)"),
    "add": evsig("AddCollateral(address,uint256,uint256)"),
    "rem": evsig("RemoveCollateral(address,uint256,uint256)"),
}
SEL = {s: sel(s) for s in ["user_borrow_part(address)", "user_collateral_share(address)", "balanceOf(address)"]}

def call_data(to, data):
    return rpc("eth_call", [{"to": to, "data": data}, "latest"])

def read_uint(pair, selector, addr=None):
    data = selector + (addr[2:].rjust(64, "0") if addr else "")
    r = call_data(pair, data)
    return uint(words(r)[0])

def main():
    d = json.load(open(os.path.join(OUT, "state_latest.json")))
    pairs = [p["pair"] for p in d["pairs"] if "err" not in p]
    partial_path = os.path.join(OUT, "positions_partial.json")
    done = {}
    if os.path.exists(partial_path):
        try:
            done = json.load(open(partial_path))
        except Exception:
            done = {}
    t0 = time.time()
    for i, pair in enumerate(pairs):
        if pair in done:
            continue
        users = set()
        try:
            logs = rpc("eth_getLogs", [{"address": pair, "fromBlock": hex(85518), "toBlock": "latest",
                                        "topics": [[SIG["borrow"], SIG["add"], SIG["rem"]]]}])
        except Exception as e:
            done[pair] = {"err": str(e)[:100]}
            json.dump(done, open(partial_path, "w"))
            continue
        for lg in logs:
            tp = lg["topics"]
            t0_ = tp[0].lower()
            if t0_ == SIG["borrow"] and len(tp) >= 4:
                users.add(topic_addr(tp[2])); users.add(topic_addr(tp[3]))
            elif t0_ in (SIG["add"], SIG["rem"]) and len(tp) >= 2:
                users.add(topic_addr(tp[1]))
        row = {"users_n": len(users), "logs": len(logs), "positions": []}
        for u in sorted(users):
            try:
                bp = read_uint(pair, SEL["user_borrow_part(address)"], u)
                cs = read_uint(pair, SEL["user_collateral_share(address)"], u)
            except Exception:
                bp = cs = None
            if (bp or 0) > 0 or (cs or 0) > 0:
                row["positions"].append({"user": u, "borrow_part": bp, "collateral_share": cs})
        done[pair] = row
        json.dump(done, open(partial_path, "w"))
        print(f"[{i+1}/{len(pairs)}] {pair} logs={row['logs']} users={row['users_n']} live={len(row['positions'])} ({time.time()-t0:.0f}s)", flush=True)
    json.dump(done, open(os.path.join(OUT, "positions.json"), "w"), indent=1)
    print("done -> ci-out/positions.json")

if __name__ == "__main__":
    main()
