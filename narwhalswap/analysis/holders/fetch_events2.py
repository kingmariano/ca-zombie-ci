#!/usr/bin/env python3
"""Fetch all events for a contract via GoldRush events/address (1M-block chunks), incremental, resumable.

Usage: fetch_events2.py <address> <lo> <hi> <outfile>
Saves JSONL (one event per line) + checkpoint file <outfile>.ckpt
"""
import json, os, sys, time, urllib.request, urllib.error

HERE = os.path.dirname(os.path.abspath(__file__))
KEY = None
for line in open('/home/heisenberg/CA/.env'):
    if line.startswith('GOLD_RUSH_API_KEY='):
        KEY = line.split('=', 1)[1].strip()
UA = {'User-Agent': 'Mozilla/5.0 (X11; Linux x86_64) holder-scan'}
CHUNK = 1_000_000

def fetch_range(addr, f, t, page):
    url = (f"https://api.covalenthq.com/v1/56/events/address/{addr}/"
           f"?key={KEY}&starting-block={f}&ending-block={t}&page-number={page}&page-size=1000")
    req = urllib.request.Request(url, headers=UA)
    last = None
    for attempt in range(6):
        try:
            with urllib.request.urlopen(req, timeout=60) as r:
                return json.loads(r.read().decode())
        except urllib.error.HTTPError as e:
            body = e.read().decode()[:200]
            last = f"HTTP {e.code}: {body}"
            if e.code in (429, 500, 502, 503, 504):
                time.sleep(2 + attempt * 3)
                continue
            raise RuntimeError(last)
        except Exception as e:
            last = str(e)
            time.sleep(2 + attempt * 3)
    raise RuntimeError("too many retries: " + str(last))

def rpc_block():
    body = json.dumps({"jsonrpc": "2.0", "id": 1, "method": "eth_blockNumber", "params": []}).encode()
    req = urllib.request.Request("https://bsc-rpc.publicnode.com", data=body,
                                 headers={'User-Agent': 'Mozilla/5.0', 'Content-Type': 'application/json'})
    with urllib.request.urlopen(req, timeout=30) as r:
        return int(json.loads(r.read().decode())['result'], 16)

def main():
    addr = sys.argv[1]
    lo = int(sys.argv[2])
    hi = int(sys.argv[3])
    outfile = sys.argv[4]
    hi = min(hi, rpc_block())
    ckpt = outfile + ".ckpt"
    logf = open(outfile, "a")
    start_chunk = lo
    if os.path.exists(ckpt):
        try:
            start_chunk = json.load(open(ckpt))["next"]
            print(f"resume from {start_chunk}", flush=True)
        except Exception:
            pass
    f = start_chunk
    skipped = []
    while f < hi:
        t = min(f + CHUNK - 1, hi)
        page = 0
        try:
            while True:
                d = fetch_range(addr, f, t, page)
                data = d.get('data') or {}
                items = data.get('items') or []
                for it in items:
                    logf.write(json.dumps(it) + "\n")
                logf.flush()
                pag = data.get('pagination') or {}
                has_more = pag.get('has_more')
                if items:
                    print(f"  [{f}..{t}] p{page}: {len(items)} (has_more={has_more})", flush=True)
                if not has_more or not items:
                    break
                page += 1
                time.sleep(0.2)
        except RuntimeError as e:
            print(f"  [{f}..{t}] FAILED: {e}", flush=True)
            skipped.append((f, t))
        f = t + 1
        json.dump({"next": f}, open(ckpt, "w"))
    # retry skipped ranges once
    for f, t in skipped:
        if t >= hi:  # beyond chain - drop
            continue
        page = 0
        try:
            while True:
                d = fetch_range(addr, f, t, page)
                data = d.get('data') or {}
                items = data.get('items') or []
                for it in items:
                    logf.write(json.dumps(it) + "\n")
                logf.flush()
                pag = data.get('pagination') or {}
                if not pag.get('has_more') or not items:
                    break
                page += 1
        except RuntimeError as e:
            print(f"  retry [{f}..{t}] still failed: {e}", flush=True)
    logf.close()
    print("done", addr, flush=True)

if __name__ == '__main__':
    main()
