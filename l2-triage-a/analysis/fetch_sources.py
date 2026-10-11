#!/usr/bin/env python3
"""Fetch DefiLlama protocol details + adapter sources for L2-SPLIT-A protocols.
Light network I/O only. Saves JSON to analysis/. No secrets."""
import json, os, re, sys, time
import urllib.request
from concurrent.futures import ThreadPoolExecutor

BASE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(BASE)
CA = os.path.dirname(ROOT)
UA = {"User-Agent": "Mozilla/5.0 (X11; Linux x86_64) research"}

def get(url, timeout=40):
    req = urllib.request.Request(url, headers=UA)
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return r.read().decode("utf-8", "replace")

def main():
    mine = json.load(open(os.path.join(CA, "ci/L2-SPLIT-A.json")))
    protos = json.load(open(os.path.join(BASE, "llama-protocols.json")))
    byname = {p["slug"]: p for p in protos if p.get("slug")}

    det_dir = os.path.join(BASE, "llama-detail"); os.makedirs(det_dir, exist_ok=True)
    ad_dir = os.path.join(BASE, "adapters"); os.makedirs(ad_dir, exist_ok=True)

    def fetch_detail(r):
        s = r["slug"].strip("`")
        fp = os.path.join(det_dir, s + ".json")
        if os.path.exists(fp):
            return (s, "cached")
        try:
            d = get("https://api.llama.fi/protocol/" + s)
            open(fp, "w").write(d)
            return (s, "ok")
        except Exception as e:
            return (s, "ERR " + str(e)[:80])

    def fetch_adapter(r):
        s = r["slug"].strip("`")
        p = byname.get(s) or {}
        mod = p.get("module") or ""
        if not mod:
            return (s, "no-module")
        fp = os.path.join(ad_dir, s + ".js")
        if os.path.exists(fp):
            return (s, "cached")
        url = "https://raw.githubusercontent.com/DefiLlama/DefiLlama-Adapters/main/projects/" + mod
        try:
            d = get(url)
            open(fp, "w").write(d)
            return (s, "ok")
        except Exception as e:
            return (s, "ERR " + str(e)[:80])

    with ThreadPoolExecutor(max_workers=6) as ex:
        for s, st in ex.map(fetch_detail, mine):
            if "ERR" in st: print("detail", s, st)
    with ThreadPoolExecutor(max_workers=6) as ex:
        for s, st in ex.map(fetch_adapter, mine):
            if "ERR" in st or st == "no-module": print("adapter", s, st)
    print("done")

if __name__ == "__main__":
    main()
