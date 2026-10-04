#!/usr/bin/env python3
"""Enumerate ALL initialized OpenBook v1 markets (mainnet, read-only).

Strategy:
  - nonces 0..3 (large): 256 chunks each on first byte of own_address (offset 13)
  - nonces >=4: single gPA per nonce, stop after 3 consecutive empty nonces
  - dataSlice offset 53 length 328 => one pass covering mints/vaults/deposits/
    fees/queues/lot sizes/fee_rate/referrer_rebates
  - resumable: each task writes <name>.jsonl + <name>.meta.json atomically
"""
import base64, json, os, sys, threading, time, urllib.request, urllib.error, queue

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from rpc import bytes_to_b58, u64le

PROGRAM = "srmqPvymJeFKQ4zGQed1GFppgkRHL9kaELCbyksJtPX"
ENDPOINTS = [
    "https://api.mainnet-beta.solana.com",
    "https://solana-rpc.publicnode.com",  # will 403 for gPA, kept last-resort only
]
CHUNK_DIR = os.environ.get("OB_CHUNK_DIR", os.path.join(HERE, "chunks"))
os.makedirs(CHUNK_DIR, exist_ok=True)
LOG_PATH = os.path.join(HERE, "enumerate.log")
WORKERS = int(os.environ.get("OB_WORKERS", "6"))
CHUNK_NONCES = [0, 1, 2, 3]
SINGLE_START = 4
MAX_NONCE = 512
STOP_STREAK = 3

log_lock = threading.Lock()

def log(msg):
    line = f"{time.strftime('%H:%M:%S')} {msg}"
    with log_lock:
        print(line, flush=True)
        with open(LOG_PATH, "a") as f:
            f.write(line + "\n")

def http_rpc(ep, method, params, timeout):
    body = json.dumps({"jsonrpc": "2.0", "id": 1, "method": method, "params": params}).encode()
    req = urllib.request.Request(ep, data=body, headers={
        "Content-Type": "application/json",
        "User-Agent": "Mozilla/5.0 (X11; Linux x86_64) zombie-hunt/1.0"})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return r.read()

def gpa_raw(ep, filters, slen=328, timeout=240):
    p = [PROGRAM, {"filters": filters, "encoding": "base64",
                   "dataSlice": {"offset": 53, "length": slen}, "commitment": "finalized"}]
    raw = http_rpc(ep, "getProgramAccounts", p, timeout)
    j = json.loads(raw)
    if "error" in j:
        raise RuntimeError(str(j["error"])[:200])
    return j["result"], len(raw)

def f_dataSize(n=388):
    return {"dataSize": n}

def f_flags(v=3):
    return {"memcmp": {"offset": 5, "bytes": bytes_to_b58(u64le(v))}}

def f_nonce(n):
    return {"memcmp": {"offset": 45, "bytes": bytes_to_b58(u64le(n))}}

def f_byte0(b):
    return {"memcmp": {"offset": 13, "bytes": bytes_to_b58(bytes([b]))}}

def decode_market(pubkey, lamports, nonce, d):
    def pk(o):
        return bytes_to_b58(d[o:o + 32])
    def u(o):
        return int.from_bytes(d[o:o + 8], "little")
    return {
        "pubkey": pubkey, "lamports": lamports, "nonce": nonce,
        "coin_mint": pk(0), "pc_mint": pk(32),
        "coin_vault": pk(64), "pc_vault": pk(112),
        "coin_dep": u(96), "coin_fees": u(104),
        "pc_dep": u(144), "pc_fees": u(152),
        "pc_dust": u(160),
        "req_q": pk(168), "event_q": pk(200),
        "bids": pk(232), "asks": pk(264),
        "coin_lot": u(296), "pc_lot": u(304),
        "fee_rate_bps": u(312), "referrer_rebates": u(320),
    }

def fetch_with_retry(filters, slen, timeout, attempts=7):
    last = None
    for a in range(attempts):
        ep = ENDPOINTS[0] if a < attempts - 1 else ENDPOINTS[0]
        try:
            return gpa_raw(ep, filters, slen=slen, timeout=timeout)
        except Exception as e:
            last = e
            s = str(e)
            sleep = min(60, 3 * (2 ** a))
            log(f"  retry {a+1}/{attempts} after {type(e).__name__}: {s[:100]} (sleep {sleep}s)")
            time.sleep(sleep)
    raise RuntimeError(f"gPA failed after {attempts} attempts: {last}")

def task_name(n, b):
    return f"n{n}_b{b}" if b is not None else f"n{n}_full"

def run_task(n, b):
    """Returns count; skips if already done."""
    name = task_name(n, b)
    meta_p = os.path.join(CHUNK_DIR, name + ".meta.json")
    if os.path.exists(meta_p):
        try:
            with open(meta_p) as f:
                m = json.load(f)
            return m["count"]
        except Exception:
            pass
    filt = [f_dataSize(), f_flags(3), f_nonce(n)]
    if b is not None:
        filt.append(f_byte0(b))
    slen = 328
    res, nraw = fetch_with_retry(filt, slen, timeout=240)
    tmp = os.path.join(CHUNK_DIR, name + ".jsonl.tmp")
    cnt = 0
    with open(tmp, "w") as f:
        for acc in res:
            d = base64.b64decode(acc["account"]["data"][0])
            if len(d) < 328:
                d = d + b"\x00" * (328 - len(d))
            rec = decode_market(acc["pubkey"], acc["account"]["lamports"], n, d)
            f.write(json.dumps(rec, separators=(",", ":")) + "\n")
            cnt += 1
    del res
    os.replace(tmp, os.path.join(CHUNK_DIR, name + ".jsonl"))
    with open(meta_p + ".tmp", "w") as f:
        json.dump({"count": cnt, "raw": nraw, "t": time.time()}, f)
    os.replace(meta_p + ".tmp", meta_p)
    log(f"{name}: {cnt} accounts ({nraw/1e6:.2f}MB)")
    return cnt

task_queue = queue.Queue()
results = {}
results_lock = threading.Lock()

def worker():
    while True:
        item = task_queue.get()
        if item is None:
            task_queue.task_done()
            return
        n, b = item
        try:
            cnt = run_task(n, b)
        except Exception as e:
            log(f"TASK FAILED {task_name(n,b)}: {str(e)[:200]}")
            with results_lock:
                results[(n, b)] = ("FAIL", 0)
            task_queue.task_done()
            continue
        with results_lock:
            results[(n, b)] = ("OK", cnt)
        task_queue.task_done()

def wait_for(pred):
    while True:
        with results_lock:
            if pred(results):
                return
        time.sleep(1)

def main():
    t_start = time.time()
    log(f"=== enumerate start workers={WORKERS} ===")
    threads = [threading.Thread(target=worker, daemon=True) for _ in range(WORKERS)]
    for t in threads:
        t.start()
    slot_raw = http_rpc(ENDPOINTS[0], "getSlot", [], 30)
    log("start slot: " + json.loads(slot_raw)["result"].__str__())

    # Phase 1: chunked nonces 0..3
    for n in CHUNK_NONCES:
        for b in range(256):
            task_queue.put((n, b))
    for n in CHUNK_NONCES:
        wait_for(lambda r, n=n: all((n, b) in r for b in range(256)))
        tot = sum(results[(n, b)][1] for b in range(256))
        fails = sum(1 for b in range(256) if results[(n, b)][0] == "FAIL")
        log(f"nonce {n}: chunks done sum={tot} fails={fails}")

    # Phase 2: single-query nonces >=4
    zero_streak = 0
    n = SINGLE_START
    while n < MAX_NONCE:
        task_queue.put((n, None))
        wait_for(lambda r, n=n: (n, None) in r)
        st, cnt = results[(n, None)]
        if st == "FAIL":
            log(f"nonce {n} single failed -> falling back to 256 byte chunks")
            for b in range(256):
                task_queue.put((n, b))
            wait_for(lambda r, n=n: all((n, b) in r for b in range(256)))
            cnt = sum(results[(n, b)][1] for b in range(256))
            log(f"nonce {n}: fallback chunk sum={cnt}")
        else:
            log(f"nonce {n}: single={cnt}")
        if cnt == 0:
            zero_streak += 1
            if zero_streak >= STOP_STREAK:
                log(f"stop: {STOP_STREAK} consecutive empty nonces at n={n}")
                break
        else:
            zero_streak = 0
        n += 1

    for _ in threads:
        task_queue.put(None)
    task_queue.join()
    end_slot = json.loads(http_rpc(ENDPOINTS[0], "getSlot", [], 30))["result"]
    log(f"end slot: {end_slot}")
    log(f"=== done in {time.time()-t_start:.0f}s ===")

if __name__ == "__main__":
    main()
