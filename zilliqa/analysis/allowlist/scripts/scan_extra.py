#!/usr/bin/env python3
"""Fetch code for arbitrary addresses, scan PUSH4 selectors, resolve new ones, write report.

Read-only. Output: raw/code_extra_<addr>.hex, raw/extra_scan.json, raw/extra_scan.md
"""
import json
import subprocess
import time
import urllib.request
from pathlib import Path

HERE = Path(__file__).resolve().parent.parent
RAW = HERE / "raw"
RPC = "https://api.zilliqa.com"
UA = {"Content-Type": "application/json", "User-Agent": "Mozilla/5.0 (read-only research)"}

ADDRS = [
    "0xc1656b63d9eeba6d114f6be19565177893e5bcbf",  # beacon impl for 806B proxies
    "0x7af37182219324ea89ba8bf0c6b7f9e557a67201",  # beacon impl for 759B proxy
    "0xb675161b8350be0689b180fc257d085e0dc09d22",  # impl of 130B minimal proxy
    "0x8484fefc929076c1c0429c9d330779d1a3d1f51d",  # impl of EIP1967 proxy 0xE9df5b
    "0xd953ab2caf7cebaf14a14493bdb4eae8973fc264",  # impl of cToken delegator 0xB861959B
    "0x2485cd5f29e4082bd38e7a65654383dafca64a2d",  # hardcoded target of 44B proxy group 1
    "0xf685ab231f1581a89f9266070d3997753e69e097",  # hardcoded target of 44B proxy group 2
    "0x8244d6ffe0695b30b2bad424683ee3bc534ea464",  # beacon 1
    "0x623346f63fdb90a06009be8c7795b26553757ba1",  # beacon 2
]


def rpc(method, params):
    body = json.dumps({"jsonrpc": "2.0", "method": method, "params": params, "id": 1}).encode()
    req = urllib.request.Request(RPC, data=body, headers=UA)
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.loads(r.read().decode())


def pushes(code: bytes):
    i = 0
    while i < len(code):
        op = code[i]
        if 0x60 <= op <= 0x7F:
            ln = op - 0x5F
            yield i, op, code[i + 1:i + 1 + ln]
            i += 1 + ln
        else:
            yield i, op, b""
            i += 1


def scan(code: bytes):
    push4 = []
    dispatch = []
    for off, op, imm in pushes(code):
        if op == 0x63 and len(imm) == 4:
            sel = "0x" + imm.hex()
            push4.append({"offset": off, "sel": sel})
            if code[off + 5:off + 6] == b"\x14":
                dispatch.append(sel)
    return push4, sorted(set(dispatch))


def resolve_new(sels):
    cache_path = RAW / "selector_signatures.json"
    cache = json.loads(cache_path.read_text())
    for s in sels:
        if cache.get(s):
            continue
        got = []
        try:
            req = urllib.request.Request(
                f"https://api.openchain.xyz/signature-database/v1/lookup?function={s}&filter=false",
                headers={"User-Agent": UA["User-Agent"]})
            with urllib.request.urlopen(req, timeout=20) as r:
                d = json.loads(r.read().decode())
            f = (d.get("result") or {}).get("function") or {}
            if f.get(s):
                got = sorted({x["name"] for x in f[s]})
        except Exception as e:
            print("oc err", s, str(e)[:80])
        cache[s] = got
        time.sleep(0.4)
    cache_path.write_text(json.dumps(cache, indent=1, sort_keys=True))
    return cache


def main():
    bn = int(rpc("eth_blockNumber", [])["result"], 16)
    cache = json.loads((RAW / "selector_signatures.json").read_text())
    results = []
    all_new = []
    for a in ADDRS:
        code_hex = rpc("eth_getCode", [a, "latest"])["result"]
        (RAW / f"code_extra_{a}.hex").write_text(code_hex)
        code = bytes.fromhex(code_hex[2:]) if code_hex.startswith("0x") else b""
        push4, dispatch = scan(code)
        all_new += [s for s in dispatch if not cache.get(s)]
        kh = subprocess.run(["cast", "keccak", code_hex], capture_output=True, text=True).stdout.strip()
        results.append({"address": a, "size": len(code), "code_hash": kh,
                        "has_5a494c53": "5a494c53" in code_hex,
                        "dispatch": dispatch, "push4": push4})
        print(a, "size", len(code), "hash", kh[:12], "precompile:", "5a494c53" in code_hex)
    resolve_new(sorted(set(all_new)))

    lines = [f"# Extra contract scan (block {bn})", ""]
    for r in results:
        lines.append(f"## {r['address']} size={r['size']} hash={r['code_hash'][:12]} precompile_const={'Y' if r['has_5a494c53'] else 'n'}")
        for s in r["dispatch"]:
            v = cache.get(s) or ["<unresolved>"]
            lines.append(f"    {s}  {' | '.join(v)}")
        disp = set(r["dispatch"])
        others = sorted({p["sel"] for p in r["push4"]} - disp)
        lines.append(f"- other PUSH4 ({len(others)}): " + " ".join(others[:40]))
        lines.append("")
    (RAW / "extra_scan.json").write_text(json.dumps(results, indent=1))
    (RAW / "extra_scan.md").write_text("\n".join(lines))
    print("wrote raw/extra_scan.{json,md}")


if __name__ == "__main__":
    main()
