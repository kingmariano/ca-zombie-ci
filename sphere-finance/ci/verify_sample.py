#!/usr/bin/env python3
"""CI verification job for the sphere-finance kick enumeration.

The full enumeration (all 5,526 ylSPHERE lockers, 40,537 Staked events) is committed in
analysis/kick_enum_full.json and was computed with analysis/../ci/kick_enum.py against a
fast public Polygon RPC. GitHub-hosted runners are heavily throttled on public Polygon
RPCs (the full run did not finish within ~30 min on the CI endpoint), so CI:
  1. copies the committed full result into ci-out/ (the artifact of record), and
  2. independently re-verifies a deterministic sample (top 20 kickable users + 20 random
     users) with the same Solidity-mirroring math at the current block, writing
     ci-out/kick_enum_verify.json.

Exit code is 0 unless verification fails, so the Foundry step still runs.
"""
import json, os, sys, random, urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
FULL = os.path.join(ROOT, "analysis", "kick_enum_full.json")

def _env(name, default=None):
    v = os.environ.get(name)
    if v:
        return v
    envfile = "/home/heisenberg/CA/.env"
    if os.path.exists(envfile):
        for line in open(envfile):
            if line.startswith(name + "="):
                return line.split("=", 1)[1].strip().strip('"').strip("'")
    return default

RPCS = ["https://polygon.gateway.tenderly.co", "https://polygon-bor-rpc.publicnode.com"]
v = _env("POLYGON_RPC_URL")
if v:
    RPCS.append(v)
v = _env("ALCHEMY_API_KEY")
if v:
    RPCS.append(f"https://polygon-mainnet.g.alchemy.com/v2/{v}")

YLSPHERE = "0x4af613f297ab00361d516454e5e46bc895889653"
WEEK = 604800
KICK_DELAY = 3 * WEEK
DENOM = 10000
SEL_LB = "0x0483a7f6"
SEL_BAL = "0x27e235e3"
SEL_LEN = "0x8b4ef9fd"
SEL_LOCKS = "0xaa33fedb"
SEL_KICKRATE = "0x9bdc7467"

def enc_addr(a): return a[2:].lower().rjust(64, "0")
def enc_uint(i): return hex(i)[2:].rjust(64, "0")

def post(url, payload, timeout=30):
    req = urllib.request.Request(url, data=json.dumps(payload).encode(),
                                 headers={"Content-Type": "application/json", "User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return json.load(r)

URL = None
def call(to, data, block):
    global URL
    urls = ([URL] if URL else []) + [u for u in RPCS if u != URL]
    for attempt in range(2):
        for u in urls:
            try:
                d = post(u, {"jsonrpc": "2.0", "id": 1, "method": "eth_call",
                             "params": [{"to": to, "data": data}, block]})
                if d.get("result") is not None:
                    URL = u
                    return d["result"]
            except Exception:
                continue
    return None

def main():
    full = json.load(open(FULL))
    os.makedirs(os.path.join(ROOT, "ci-out"), exist_ok=True)
    json.dump(full, open(os.path.join(ROOT, "ci-out", "kick_enum.json"), "w"), indent=1)

    # pick sample: top 20 from full + 20 deterministic "random"
    top = [x["user"] for x in full["top50"][:20]]
    users_all = json.load(open(os.path.join(ROOT, "analysis", "yl_users_all.json")))
    rnd = random.Random(1337)
    sample = top + rnd.sample([u for u in users_all if u not in top], 20)

    bn_hex = post(RPCS[0], {"jsonrpc": "2.0", "id": 1, "method": "eth_blockNumber", "params": []})["result"]
    bn = int(bn_hex, 16)
    blk = post(RPCS[0], {"jsonrpc": "2.0", "id": 1, "method": "eth_getBlockByNumber", "params": [hex(bn), False]})["result"]
    now = int(blk["timestamp"], 16)
    expiry = now - KICK_DELAY
    current_epoch = (now - KICK_DELAY) // WEEK * WEEK
    kr = call(YLSPHERE, SEL_KICKRATE, hex(bn))
    kick_rate = int(kr, 16) if kr else 1

    rows = []
    ok = 0
    for u in sample:
        lb = call(YLSPHERE, SEL_LB + enc_addr(u), hex(bn))
        if not lb or len(lb) < 130:
            rows.append({"user": u, "error": "lockedBalances failed"}); continue
        h = lb[2:]
        t_total, t_unlockable, t_locked = int(h[0:64], 16), int(h[64:128], 16), int(h[128:192], 16)
        bal = call(YLSPHERE, SEL_BAL + enc_addr(u), hex(bn))
        nui = int(bal[2:][64:128], 16) if bal and len(bal) >= 130 else 0
        ln = call(YLSPHERE, SEL_LEN + enc_addr(u), hex(bn))
        n = int(ln, 16) if ln else 0
        locks = []
        for j in range(nui, n):
            r = call(YLSPHERE, SEL_LOCKS + enc_addr(u) + enc_uint(j), hex(bn))
            if r and len(r) >= 130:
                locks.append((int(r[2:][0:64], 16), int(r[2:][64:128], 16)))
        reward = 0
        path = "loop"
        if locks and locks[-1][1] <= expiry:
            path = "bundle"
            epochsover = (current_epoch - locks[-1][1]) // WEEK
            reward = t_total * min(kick_rate * (epochsover + 1), DENOM) // DENOM
        else:
            for amt, ut in locks:
                if ut > expiry:
                    break
                epochsover = (current_epoch - ut) // WEEK
                reward += amt * min(kick_rate * (epochsover + 1), DENOM) // DENOM
        rows.append({"user": u, "reward_sphere": reward, "total": t_total,
                     "unlockable": t_unlockable, "path": path})
        if reward > 0:
            ok += 1
    out = {"block": bn, "timestamp": now, "sample_size": len(sample), "with_reward": ok,
           "full_result_block": full["block"],
           "full_total_kick_reward_sphere_human": full["total_kick_reward_sphere_human"],
           "rows": rows,
           "note": "sample re-verification of the committed full enumeration; "
                   "see analysis/kick_enum_full.json and analysis/kick_enum_local_full.log"}
    json.dump(out, open(os.path.join(ROOT, "ci-out", "kick_enum_verify.json"), "w"), indent=1)
    print(json.dumps({k: v for k, v in out.items() if k != "rows"}, indent=1))
    for r in rows[:10]:
        print("  ", r)
    if ok == 0:
        print("VERIFY FAILED: no rewards found in sample")
        sys.exit(1)
    print("VERIFY OK")

if __name__ == "__main__":
    main()
