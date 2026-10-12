#!/usr/bin/env python3
"""Enumerate ALL historical transfer participants per gauge (incremental, resumable)."""
import json, time, urllib.request, sys, os

# ordered by residual size (after holders attribution)
GAUGES = [
    "0xc96AeeaFF32129da934149F6134Aa7bf291a754E",
    "0x487c30CB18AA9Ced435911E2B414e0E85D7E52bB",
    "0x127b524c74C2162Ee4BB2e42d8d2eB9050C0293E",
    "0x27D9Bfa5F864862BeDC23cFab7e00b6b94488CC6",
    "0xdAA2ab880b7f3D5697e6F85e63c28b9120AA9E07",
    "0xE1f9D952EecC07cfEFa69df9fBB0cEF260957119",
    "0x0A125D473cd3b1968e728DDF7d424c928C09222A",
    "0xd1B3C05FE24bda6F52e704daf1ACBa8c440d8573",
    "0x107F94409746E8c8E6eFF139A100D17D9ca7FdfE",
    "0x52517feb1Fc6141d5CF6718111C7Cc0FD764fA5d",
]
OUT = "gauge_participants_tmp.json"


def fetch(url, tries=10):
    for i in range(tries):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0 (research)"})
            with urllib.request.urlopen(req, timeout=60) as r:
                return json.loads(r.read().decode())
        except Exception as e:
            print("  retry", i, e, file=sys.stderr, flush=True)
            time.sleep(1.5 + 2 * i)
    raise RuntimeError("fail " + url)


def participants(g, max_pages=600):
    addrs = set()
    url = f"https://celo.blockscout.com/api/v2/tokens/{g}/transfers"
    pages = 0
    while url and pages < max_pages:
        d = fetch(url)
        for it in d.get("items", []):
            frm = it.get("from", {}).get("hash")
            to = it.get("to", {}).get("hash")
            if frm: addrs.add(frm.lower())
            if to: addrs.add(to.lower())
        npp = d.get("next_page_params")
        pages += 1
        if not npp:
            break
        q = "&".join(f"{k}={v}" for k, v in npp.items())
        url = f"https://celo.blockscout.com/api/v2/tokens/{g}/transfers?{q}"
        time.sleep(0.25)
    return addrs, pages


out = {}
if os.path.exists(OUT):
    try:
        out = json.load(open(OUT))
    except Exception:
        out = {}
out = {k.lower(): v for k, v in out.items()}
for g in GAUGES:
    gl = g.lower()
    if out.get(gl):
        print(f"{g}: already done ({len(out[gl])})", flush=True)
        continue
    a, p = participants(g)
    out[gl] = sorted(a)
    json.dump(out, open(OUT, "w"), indent=1)
    print(f"{g}: participants={len(a)} pages={p}", flush=True)

print("DONE", OUT)
