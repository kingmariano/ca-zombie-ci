"""Enrich census: contract names, proxies, USDC balance for every deployed contract."""
import json
import sys
from concurrent.futures import ThreadPoolExecutor

sys.path.insert(0, "/home/heisenberg/CA/cega-v1/analysis/evm")
import lib

raw = json.load(open("/home/heisenberg/CA/cega-v1/analysis/evm/census_raw.json"))

KNOWN_LABELS = {}
for cid, ch in raw["chains"].items():
    for a, info in ch["known"].items():
        KNOWN_LABELS[(int(cid), a.lower())] = info

out = {"generated_at": lib.time.strftime("%Y-%m-%dT%H:%M:%SZ", lib.time.gmtime()), "chains": {}}

for cid_s, ch in raw["chains"].items():
    cid = int(cid_s)
    addrs = set()
    for cr, info in ch["creators"].items():
        for c in info["contracts_created"]:
            addrs.add(c["address"].lower())
    for a in ch["known"].values():
        addrs.add(a.lower())
    addrs = sorted(addrs)

    def enrich_src(a):
        src = lib.es_getabi(cid, a)
        return a, src

    import os

    cache_path = f"/home/heisenberg/CA/cega-v1/analysis/evm/census_sources_{cid}.json"
    if os.path.exists(cache_path):
        srcs = json.load(open(cache_path))
        print(f"(using cached sources {cache_path})")
    else:
        with ThreadPoolExecutor(max_workers=1) as ex:
            srcs = dict(ex.map(enrich_src, addrs))
        lib.save_json(cache_path, srcs)
    codes = lib.rpc_batch(cid, [("eth_getCode", [a, "latest"]) for a in addrs], chunk=5)
    bals = lib.rpc_batch(
        cid,
        [
            (
                "eth_call",
                [{"to": lib.USDC[cid], "data": "0x70a08231" + "0" * 24 + a[2:]}, "latest"],
            )
            for a in addrs
        ],
        chunk=5,
    )
    rows = []
    for i, a in enumerate(addrs):
        src = srcs[a]
        code = codes[i] or "0x"
        code_size = len(code) // 2 - 1
        bal = None
        raw_bal = bals[i]
        if code_size > 0 and raw_bal and raw_bal != "0x":
            try:
                bal = int(raw_bal, 16)
            except Exception:
                bal = None
        rows.append(
            {
                "address": a,
                "name": src.get("ContractName", ""),
                "compiler": src.get("CompilerVersion", ""),
                "proxy": src.get("Proxy", ""),
                "implementation": src.get("Implementation", ""),
                "verified": bool(src.get("SourceCode")),
                "code_size": code_size,
                "usdc_balance_raw": bal,
                "usdc_balance": (bal / 1e6) if isinstance(bal, int) else None,
                "known_label": KNOWN_LABELS.get((cid, a), ""),
            }
        )
    out["chains"][cid_s] = rows
    print(f"=== chain {cid}: {len(rows)} addresses")
    for r in sorted(rows, key=lambda x: x["code_size"] == 0):
        if r["code_size"] == 0:
            continue
        print(
            f"  {r['address']} size={r['code_size']:>6} usdc={r['usdc_balance']} name={r['name']!r} "
            f"proxy={r['proxy']} impl={r['implementation']} label={r['known_label']}"
        )
    lib.save_json("/home/heisenberg/CA/cega-v1/analysis/evm/census_enriched.json", out)
