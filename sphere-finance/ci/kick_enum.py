#!/usr/bin/env python3
"""Enumerate ALL ylSPHERE lockers and compute the exact permissionless kickExpiredLocks
reward available to any external attacker, replicating the deployed Solidity math.

v3: single eth_calls via a thread pool (no JSON-RPC batching), working-endpoint probe,
per-call fallback. Read-only. Outputs ci-out/kick_enum.json.
"""
import json, os, sys, time, urllib.request
from concurrent.futures import ThreadPoolExecutor

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)

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

RPCS = []
# fast public endpoints first; the CI-provided endpoint last (observed very slow on 2026-10-03)
RPCS += ["https://polygon.gateway.tenderly.co", "https://polygon-bor-rpc.publicnode.com"]
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

SEL_LB = "0x0483a7f6"       # lockedBalances(address)
SEL_BAL = "0x27e235e3"      # balances(address)
SEL_LEN = "0x8b4ef9fd"      # userLocksLen(address)
SEL_LOCKS = "0xaa33fedb"    # userLocks(address,uint256)
SEL_KICKRATE = "0x9bdc7467"  # kickRewardPerEpoch()

def enc_addr(a):
    return a[2:].lower().rjust(64, "0")

def enc_uint(i):
    return hex(i)[2:].rjust(64, "0")

def _post(url, payload, timeout=45):
    req = urllib.request.Request(url, data=json.dumps(payload).encode(),
                                 headers={"Content-Type": "application/json", "User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return json.load(r)

class Rpc:
    def __init__(self):
        self.url = None
        self.lock = __import__("threading").Lock()
    def probe(self):
        best = None
        best_t = None
        # time a real eth_call on each candidate; pick the fastest that answers
        for u in RPCS:
            t0 = time.time()
            try:
                d = _post(u, {"jsonrpc": "2.0", "id": 1, "method": "eth_call",
                              "params": [{"to": YLSPHERE, "data": SEL_LB + enc_addr(
                                  "0x42dcc796fF5B5d8D11928448a3eb62127b52BF5D")}, "latest"]})
                if d.get("result"):
                    dt = time.time() - t0
                    print(f"  probe {u.split('/')[2][:40]}: {dt:.2f}s", flush=True)
                    if best_t is None or dt < best_t:
                        best, best_t = u, dt
            except Exception as e:
                print(f"  probe {u.split('/')[2][:40]}: FAIL {str(e)[:60]}", flush=True)
        self.url = best
        if best:
            print(f"using RPC: {best.split('/')[2]}", flush=True)
            return True
        return False
    def call(self, to, data, block):
        payload = {"jsonrpc": "2.0", "id": 1, "method": "eth_call", "params": [{"to": to, "data": data}, block]}
        urls = [self.url] + [u for u in RPCS if u != self.url]
        last = None
        for attempt in range(3):
            for u in urls:
                try:
                    d = _post(u, payload)
                    if d.get("result") is not None:
                        return d["result"]
                    last = d.get("error")
                except Exception as e:
                    last = e
            time.sleep(0.3 * (attempt + 1))
        return None

RPC = Rpc()

def pmap(fn, items, workers=8):
    out = [None] * len(items)
    with ThreadPoolExecutor(max_workers=workers) as ex:
        futs = {ex.submit(fn, it): i for i, it in enumerate(items)}
        for f, i in futs.items():
            out[i] = f.result()
    return out

def main():
    users = json.load(open(os.path.join(ROOT, "analysis", "yl_users_all.json")))
    limit = int(os.environ.get("KICK_ENUM_LIMIT", "0"))
    if limit > 0:
        users = users[:limit]
    print(f"users: {len(users)}", flush=True)
    if not RPC.probe():
        raise RuntimeError("no working RPC")
    bn = int(_post(RPC.url, {"jsonrpc": "2.0", "id": 1, "method": "eth_blockNumber", "params": []})["result"], 16)
    blk = _post(RPC.url, {"jsonrpc": "2.0", "id": 1, "method": "eth_getBlockByNumber", "params": [hex(bn), False]})["result"]
    now = int(blk["timestamp"], 16)
    expiry = now - KICK_DELAY
    current_epoch = (now - KICK_DELAY) // WEEK * WEEK
    kick_hex = RPC.call(YLSPHERE, SEL_KICKRATE, hex(bn))
    kick_rate = int(kick_hex, 16) if kick_hex else 1
    print(f"block={bn} now={now} expiry={expiry} kickRewardPerEpoch={kick_rate}", flush=True)

    # step 1: lockedBalances for all users
    def lb(u):
        r = RPC.call(YLSPHERE, SEL_LB + enc_addr(u), hex(bn))
        if not r or len(r) < 130:
            return None
        h = r[2:]
        return (int(h[0:64], 16), int(h[64:128], 16), int(h[128:192], 16))
    print("step1: lockedBalances", flush=True)
    totals = pmap(lb, users)
    totals = {u: t for u, t in zip(users, totals)}
    active = [u for u in users if totals[u] and totals[u][0] > 0]
    none_count = sum(1 for t in totals.values() if t is None)
    print(f"  active users: {len(active)} (failed calls: {none_count})", flush=True)
    if none_count > len(users) * 0.2:
        raise RuntimeError(f"too many failed lockedBalances calls: {none_count}/{len(users)}")

    # step 2: nextUnlockIndex + lock count
    def meta1(u):
        r = RPC.call(YLSPHERE, SEL_BAL + enc_addr(u), hex(bn))
        nui = 0
        if r and len(r) >= 130:
            nui = int(r[2:][64:128], 16)
        return nui
    def meta2(u):
        r = RPC.call(YLSPHERE, SEL_LEN + enc_addr(u), hex(bn))
        return int(r, 16) if r else 0
    print("step2: balances/userLocksLen", flush=True)
    nuis = pmap(meta1, active)
    lens = pmap(meta2, active)
    meta = {u: (n, l) for u, n, l in zip(active, nuis, lens)}
    bad = sum(1 for u in active if meta[u][1] == 0)
    print(f"  zero-length users: {bad}/{len(active)}; sample nui/n: "
          f"{[(u[:10], meta[u]) for u in active[:3]]}", flush=True)
    if len(active) > 100 and bad == len(active):
        raise RuntimeError("all userLocksLen calls failed/zero; refusing false 0")

    # step 3: fetch locks from nextUnlockIndex..len-1
    lock_calls = []
    for u in active:
        nui, n = meta[u]
        for j in range(nui, n):
            lock_calls.append((u, j))
    print(f"step3: lock records: {len(lock_calls)}", flush=True)
    def lockcall(pair):
        u, j = pair
        r = RPC.call(YLSPHERE, SEL_LOCKS + enc_addr(u) + enc_uint(j), hex(bn))
        if not r or len(r) < 130:
            return None
        h = r[2:]
        return (int(h[0:64], 16), int(h[64:128], 16))
    locks_res = pmap(lockcall, lock_calls)
    locks = {u: [] for u in active}
    for (u, j), r in zip(lock_calls, locks_res):
        if r:
            locks[u].append(r)
    # locks are already ordered per user by j
    fail_locks = sum(1 for r in locks_res if r is None)
    print(f"  lock fetch failures: {fail_locks}/{len(lock_calls)}", flush=True)
    if len(lock_calls) > 100 and fail_locks > len(lock_calls) * 0.2:
        raise RuntimeError("too many lock fetch failures")

    # step 4: exact kick reward
    total_reward = 0
    total_expired = 0
    per_user = []
    bundle_users = 0
    for u in active:
        t_total, t_unlockable, t_locked = totals[u]
        ls = locks[u]
        if not ls:
            continue
        total_expired += t_unlockable
        last_ut = ls[-1][1]
        reward = 0
        path = "loop"
        if last_ut <= expiry:
            path = "bundle"
            bundle_users += 1
            epochsover = (current_epoch - last_ut) // WEEK
            rrate = min(kick_rate * (epochsover + 1), DENOM)
            reward = t_total * rrate // DENOM
        else:
            for amt, ut in ls:
                if ut > expiry:
                    break
                epochsover = (current_epoch - ut) // WEEK
                rrate = min(kick_rate * (epochsover + 1), DENOM)
                reward += amt * rrate // DENOM
        if reward > 0:
            total_reward += reward
            per_user.append({"user": u, "reward_sphere": reward, "total": t_total,
                             "unlockable": t_unlockable, "path": path, "last_unlock": last_ut})
    per_user.sort(key=lambda x: -x["reward_sphere"])
    out = {
        "block": bn, "timestamp": now, "users": len(users), "active_users": len(active),
        "bundle_path_users": bundle_users,
        "total_expired_unprocessed_sphere": str(total_expired),
        "total_kick_reward_sphere": str(total_reward),
        "total_kick_reward_sphere_human": total_reward / 1e18,
        "top50": per_user[:50],
        "note": "reward computed with live kickRewardPerEpoch=1 (0.01%/epoch overdue), cap 100%; "
                "kicker receives reward in SPHERE, victim is force-withdrawn",
    }
    os.makedirs(os.path.join(ROOT, "ci-out"), exist_ok=True)
    json.dump(out, open(os.path.join(ROOT, "ci-out", "kick_enum.json"), "w"), indent=1)
    print(json.dumps({k: v for k, v in out.items() if k != "top50"}, indent=1))
    print("TOP 10:")
    for x in per_user[:10]:
        print(f"  {x['user']} reward={x['reward_sphere']/1e18:.2f} SPHERE total={x['total']/1e18:.0f} path={x['path']}")

if __name__ == "__main__":
    main()
