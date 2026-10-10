#!/usr/bin/env python3
"""Resolve unique selectors via openchain.xyz (batch) then 4byte.directory (fallback).
Writes raw/selector_signatures.json. Public APIs, no keys."""
import json
import time
import urllib.request
import urllib.error
from pathlib import Path

HERE = Path(__file__).resolve().parent.parent
RAW = HERE / "raw"
UA = {"User-Agent": "Mozilla/5.0 (read-only security research)"}


def get_json(url, timeout=30):
    req = urllib.request.Request(url, headers=UA)
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return json.loads(r.read().decode())


def openchain_lookup(sels):
    out = {}
    for i in range(0, len(sels), 40):
        chunk = sels[i:i + 40]
        qs = "&".join(f"function={s}" for s in chunk)
        url = f"https://api.openchain.xyz/signature-database/v1/lookup?{qs}&filter=true"
        try:
            d = get_json(url)
            res = (d.get("result") or {}).get("function") or {}
            for sel in chunk:
                v = res.get(sel)
                if v:
                    out[sel] = sorted({x["name"] for x in v})
        except Exception as e:
            print("openchain chunk failed:", str(e)[:100])
        time.sleep(0.4)
    return out


def fbd_lookup(sel, attempts=3):
    url = f"https://www.4byte.directory/api/v1/signatures/?hex_signature={sel}&ordering=created_at"
    for a in range(attempts):
        try:
            d = get_json(url)
            return sorted({x["text_signature"] for x in d["results"]})
        except urllib.error.HTTPError as e:
            if e.code in (429, 503):
                time.sleep(5 * (a + 1))
            else:
                return []
        except Exception:
            time.sleep(2)
    return []


def main():
    raw = json.loads((RAW / "selectors_raw.json").read_text())
    all_sels = sorted({s for r in raw for s in r["dispatcher_selectors"]})
    # also include extras
    cache_path = RAW / "selector_signatures.json"
    cache = json.loads(cache_path.read_text()) if cache_path.exists() else {}
    todo = [s for s in all_sels if s not in cache]
    print(f"{len(all_sels)} unique dispatcher selectors, {len(todo)} to resolve")
    oc = openchain_lookup(todo)
    for sel in todo:
        sigs = oc.get(sel)
        if not sigs:
            sigs = fbd_lookup(sel)
            time.sleep(0.6)
        cache[sel] = sigs or []
    cache_path.write_text(json.dumps(cache, indent=1, sort_keys=True))
    miss = [s for s in all_sels if not cache.get(s)]
    print(f"resolved {len(all_sels) - len(miss)}/{len(all_sels)}; unresolved: {miss}")


if __name__ == "__main__":
    main()
