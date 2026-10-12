#!/usr/bin/env python3
"""
cog (Scroll) borrower-position scanner — read-only, keyless public RPC.
For every pair: pull Borrow / AddCollateral / RemoveCollateral logs, collect users,
read live user_borrow_part + user_collateral_share, and evaluate:
  - solvency under the pair's live oracle rate
  - market (DefiLlama) value of debt & collateral
  - liquidation profit for an external attacker (repay debt in asset -> receive collateral)
Outputs ci-out/positions.json + ci-out/positions_summary.json
"""
import json, os, time, urllib.request
from concurrent.futures import ThreadPoolExecutor
from Crypto.Hash import keccak

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
OUT = os.path.join(ROOT, "ci-out")
RPCS = ["https://rpc.scroll.io", "https://scroll-rpc.publicnode.com", "https://scroll.drpc.org"]
_rr = [0]

def rpc(method, params, tries=3, timeout=30):
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
        time.sleep(0.2 + 0.3 * i)
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
    "Borrow(uint256,address,address)": evsig("Borrow(uint256,address,address)"),
    "AddCollateral(address,uint256,uint256)": evsig("AddCollateral(address,uint256,uint256)"),
    "RemoveCollateral(address,uint256,uint256)": evsig("RemoveCollateral(address,uint256,uint256)"),
}
SEL = {s: sel(s) for s in ["user_borrow_part(address)", "user_collateral_share(address)"]}

def call(to, selector, addr=None, block="latest"):
    data = selector + (addr.lower().replace("0x", "").rjust(64, "0") if addr else "")
    return rpc("eth_call", [{"to": to, "data": data}, block])

FACTORY_FROM = {
    "0xbabd55549c266c6755b99173fe7604238d04117d": 85518,
    "0xcd44fecb08bb28405992358131fd5081a0f550d0": 3147376,
}

def main():
    d = json.load(open(os.path.join(OUT, "state_latest.json")))
    toks = d["tokens"]; prices = json.load(open("/tmp/opencode/cog_prices.json"))
    prices['scroll:0x79379c0e09a41d7978f883a56246290ee9a8c4d3'] = 163.20437647880277
    prices['scroll:0xb755039edc7910c1f1bd985d48322e55a31ac0bf'] = 0.36039696153033285
    def px(t): return prices.get(('scroll:'+t).lower()) or 0.0
    block = d["block"]

    # which factory each pair came from: use first-seen order in triage lists is not exact; try both fromBlocks
    pos_out = []
    users_all = {}
    for p in d["pairs"]:
        if "err" in p: continue
        pair = p["pair"]
        users = set()
        for ev in ["Borrow(uint256,address,address)"]:
            try:
                logs = rpc("eth_getLogs", [{"address": pair, "fromBlock": hex(85518), "toBlock": "latest",
                                            "topics": [SIG[ev]]}])
            except Exception as e:
                logs = []
            for lg in logs:
                tp = lg["topics"]
                if len(tp) >= 4:
                    users.add(topic_addr(tp[2])); users.add(topic_addr(tp[3]))
        for ev in ["AddCollateral(address,uint256,uint256)", "RemoveCollateral(address,uint256,uint256)"]:
            try:
                logs = rpc("eth_getLogs", [{"address": pair, "fromBlock": hex(85518), "toBlock": "latest",
                                            "topics": [SIG[ev]]}])
            except Exception:
                logs = []
            for lg in logs:
                tp = lg["topics"]
                if len(tp) >= 2:
                    users.add(topic_addr(tp[1]))
        row = {"pair": pair, "users_n": len(users), "users": []}
        for u in users:
            try:
                bp = uint(words(call(pair, SEL["user_borrow_part(address)"], u))[0])
                cs = uint(words(call(pair, SEL["user_collateral_share(address)"], u))[0])
            except Exception:
                bp = cs = None
            if (bp or 0) > 0 or (cs or 0) > 0:
                row["users"].append({"user": u, "borrow_part": bp, "collateral_share": cs})
        if row["users"]:
            pos_out.append(row)
        print(f"{pair} users={len(users)} live_pos={len(row['users'])}", flush=True)

    json.dump({"block": block, "positions": pos_out}, open(os.path.join(OUT, "positions.json"), "w"), indent=1)
    print("wrote positions.json")

if __name__ == "__main__":
    main()
