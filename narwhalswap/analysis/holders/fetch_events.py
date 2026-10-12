#!/usr/bin/env python3
"""Fetch all events for a contract via GoldRush events/address (1M-block chunks), binary-search deployment."""
import json, os, sys, time, urllib.request, urllib.error

HERE = os.path.dirname(os.path.abspath(__file__))
RAW = os.path.join(HERE, "raw_goldrush")
os.makedirs(RAW, exist_ok=True)

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
    for attempt in range(5):
        try:
            with urllib.request.urlopen(req, timeout=60) as r:
                return json.loads(r.read().decode())
        except urllib.error.HTTPError as e:
            body = e.read().decode()[:200]
            if e.code in (429, 500, 502, 503):
                print('  retry', e.code, body[:80]); time.sleep(3 + attempt * 3); continue
            raise RuntimeError(f"HTTP {e.code}: {body}")
    raise RuntimeError("too many retries")

def count_range(addr, f, t):
    d = fetch_range(addr, f, t, 0)
    data = d.get('data') or {}
    items = data.get('items') or []
    pag = data.get('pagination') or {}
    return len(items), pag

def find_deploy(addr, hi):
    """binary search on 1M grid: first chunk with any event"""
    lo = 0
    # exponential probe
    probe = 1
    found = None
    while probe <= hi // CHUNK:
        n, pag = count_range(addr, (probe - 1) * CHUNK, probe * CHUNK if probe * CHUNK < hi else hi)
        print(f"  probe [{ (probe-1)*CHUNK }..{probe*CHUNK}): {n} events")
        if n > 0:
            found = probe
            break
        probe *= 2
        time.sleep(0.2)
    if found is None:
        return None
    lo_chunk = found - 1
    # linear refine backwards within the chunk window (max a few)
    return lo_chunk * CHUNK

def main():
    addr = sys.argv[1]
    lo = int(sys.argv[2])
    hi = int(sys.argv[3])
    outfile = sys.argv[4] if len(sys.argv) > 4 else os.path.join(RAW, f"events_{addr}.json")
    all_items = []
    f = lo
    while f < hi:
        t = min(f + CHUNK - 1, hi)
        page = 0
        while True:
            d = fetch_range(addr, f, t, page)
            data = d.get('data') or {}
            items = data.get('items') or []
            all_items.extend(items)
            pag = data.get('pagination') or {}
            has_more = pag.get('has_more')
            print(f"  [{f}..{t}] page {page}: {len(items)} items has_more={has_more} total={len(all_items)}")
            if not has_more or not items:
                break
            page += 1
            time.sleep(0.25)
        f = t + 1
        time.sleep(0.25)
    with open(outfile, 'w') as fh:
        json.dump(all_items, fh, indent=1)
    print("saved", len(all_items), "->", outfile)

if __name__ == '__main__':
    main()
