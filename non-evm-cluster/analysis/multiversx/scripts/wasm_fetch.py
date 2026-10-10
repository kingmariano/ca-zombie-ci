#!/usr/bin/env python3
"""Fetch account + parse wasm exports for arbitrary addresses (keyless). Usage: wasm_fetch.py addr [addr2...]"""
import json, sys, urllib.request
sys.path.insert(0, __import__("os").path.dirname(__import__("os").path.abspath(__file__)))
from wasm_exports import parse_exports

BASE = "https://api.multiversx.com"

def get(path):
    req = urllib.request.Request(BASE + path, headers={"Accept": "application/json", "User-Agent": "research-readonly/1.0"})
    with urllib.request.urlopen(req, timeout=60) as r:
        return json.loads(r.read().decode())

for addr in sys.argv[1:]:
    d = get(f"/accounts/{addr}")
    code = d.get("code") or ""
    funcs = []
    if code:
        f, err = parse_exports(code)
        funcs = f or []
    print(f"== {addr}")
    print("   balance:", int(d.get('balance',0))/1e18, "owner:", d.get("ownerAddress"), "upgradeable:", d.get("isUpgradeable"))
    print("   funcs:", ", ".join(funcs))
