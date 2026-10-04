#!/usr/bin/env python3
"""Approvals census: latest Approval events per (owner,spender), verify live allowance
via RPC, flag contract spenders, fetch their sources. Read-only."""
import json, os, time, urllib.request, sys

HERE = os.path.dirname(os.path.abspath(__file__))
CENSUS = os.path.dirname(HERE)
RAW = os.path.join(CENSUS, "raw")
SRC = os.path.join(CENSUS, "contract_sources")
os.makedirs(SRC, exist_ok=True)
RPC = "https://rpc.hyperliquid.xyz/evm"
KEY = os.environ["ETHERSCANV2_API_KEY"]

TARGETS = {
    "fwWHYPE": "0x9e1148bC3665a9f7C35F313d89c0432c34928AEf",
    "fwUETH":  "0x0C47cbbEDE5d8c6f9614cF770C26c3315205C397",
    "fwUSDC":  "0xd2646b9B02859416D8cBc759F85f0676f6E19974",
    "fwUSDT0": "0x7576dd9a2775bFd789616d9eA7A2af21d06782D0",
    "fwUSDH":  "0x09D21E89EF332347eb3E1E496f1265a600e364C1",
    "pair1_LP_fwUETH_fwWHYPE":  "0x0185E8e8B7FDf22638ecB2D781b3EA7E8AA2452a",
    "pair2_LP_fwUSDH_fwUSDC":   "0xabEd9A9aDe03a80ED98f903Eb9db62DE55C9DDF3",
    "pair3_LP_fwUSDH_fwUSDT0":  "0xf37f1e83BEb55F1b88AF9A8Df1a746e79C222150",
    "pair4_LP_fwUSDT0_fwUSDC":  "0x8868a630dD13A954D3f8B186508EF6c733BE959F",
    "pair5_LP_fwUSDT0_fwWHYPE": "0xf3760B19f1Baa2bFcf6Bd6e5d174e129c80aeD17",
}
SEL_ALLOWANCE = "0xdd62ed3e"  # allowance(address,address)

def rpc_batch(payload, retries=6):
    for i in range(retries):
        try:
            req = urllib.request.Request(RPC, data=json.dumps(payload).encode(),
                                         headers={"Content-Type": "application/json", "User-Agent": "research/1.0"})
            with urllib.request.urlopen(req, timeout=60) as r:
                return json.loads(r.read())
        except Exception:
            if i == retries - 1: raise
            time.sleep(2 * (i + 1))

def pad(a): return "0" * 24 + a[2:].lower()

def calls(call_list):
    out = []
    for i in range(0, len(call_list), 20):
        chunk = call_list[i:i + 20]
        payload = [{"jsonrpc": "2.0", "id": j, "method": "eth_call", "params": [{"to": to, "data": d}, "latest"]}
                   for j, (to, d) in enumerate(chunk)]
        res = rpc_batch(payload)
        by = {r.get("id"): r for r in res}
        for j in range(len(chunk)):
            r = by.get(j, {})
            out.append(r.get("result") if "error" not in r else {"error": r.get("error")})
        time.sleep(0.2)
    return out

def codes(addrs):
    out = []
    for i in range(0, len(addrs), 20):
        chunk = addrs[i:i + 20]
        payload = [{"jsonrpc": "2.0", "id": j, "method": "eth_getCode", "params": [a, "latest"]}
                   for j, a in enumerate(chunk)]
        res = rpc_batch(payload)
        by = {r.get("id"): r for r in res}
        for j in range(len(chunk)):
            out.append(by.get(j, {}).get("result", "0x"))
        time.sleep(0.2)
    return out

def es_source(addr):
    url = (f"https://api.etherscan.io/v2/api?chainid=999&module=contract&action=getsourcecode"
           f"&address={addr}&apikey={KEY}")
    for i in range(4):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": "research/1.0"})
            with urllib.request.urlopen(req, timeout=60) as r:
                d = json.loads(r.read())
            if d.get("status") == "1":
                res = d["result"][0]
                return {"ContractName": res.get("ContractName"), "SourceCode": res.get("SourceCode"),
                        "ABI": res.get("ABI"), "CompilerVersion": res.get("CompilerVersion"),
                        "Verified": bool(res.get("SourceCode"))}
        except Exception as e:
            time.sleep(2 * (i + 1))
    return None

def main():
    res = rpc_batch([{"jsonrpc": "2.0", "id": 0, "method": "eth_blockNumber", "params": []}])
    block = int(res[0]["result"], 16)
    out = {"block": block, "tokens": {}}
    for name, addr in TARGETS.items():
        f = os.path.join(RAW, f"logs_approval_{name}.json")
        if not os.path.exists(f):
            print("MISSING", f); continue
        logs = json.load(open(f))
        latest = {}
        for e in logs:
            try:
                owner = "0x" + e["topics"][1][-40:].lower()
                spender = "0x" + e["topics"][2][-40:].lower()
                v = int(e["data"], 16) if e["data"] not in ("0x", "") else 0
                bn = int(e["blockNumber"], 16)
                li = int(e.get("logIndex", "0x0") or "0x0", 16)
            except Exception:
                continue
            k = (owner, spender)
            if k not in latest or (bn, li) > (latest[k]["block"], latest[k]["logIndex"]):
                latest[k] = {"owner": owner, "spender": spender, "value": v, "block": bn, "logIndex": li}
        items = list(latest.values())
        # live allowance
        cl = [(addr, SEL_ALLOWANCE + pad(x["owner"]) + pad(x["spender"])) for x in items]
        rs = calls(cl) if cl else []
        spenders = sorted(set(x["spender"] for x in items))
        cs = codes(spenders) if spenders else []
        codemap = dict(zip(spenders, cs))
        rows = []
        for x, r in zip(items, rs):
            live = int(r, 16) if isinstance(r, str) else None
            c = codemap.get(x["spender"], "0x")
            rows.append({**{k: (str(v) if isinstance(v, int) else v) for k, v in x.items()},
                         "allowance_live": str(live) if live is not None else None,
                         "spender_code_size": (len(c) - 2) // 2, "spender_is_contract": len(c) > 2})
        # contract spenders with live allowance
        watch = [r for r in rows if r["spender_is_contract"] and r["allowance_live"] not in (None, "0")]
        out["tokens"][name] = {"address": addr, "approval_events": len(logs), "unique_pairs": len(items),
                               "rows": rows, "contract_spenders_live": watch}
        print(f"[{name}] approvals={len(logs)} unique={len(items)} live-contract-spenders={len(watch)}")
        for w in watch:
            print("   spender", w["spender"], "owner", w["owner"], "allowance", w["allowance_live"], "codesize", w["spender_code_size"])
        time.sleep(0.4)
    json.dump(out, open(os.path.join(CENSUS, "approvals_census.json"), "w"), indent=1)
    # sources for contract spenders that appear in watch
    seen = set()
    for t in out["tokens"].values():
        for w in t["contract_spenders_live"]:
            if w["spender"] in seen: continue
            seen.add(w["spender"])
            src = es_source(w["spender"])
            if src:
                json.dump(src, open(os.path.join(SRC, f"{w['spender']}.json"), "w"))
                print("source saved:", w["spender"], src.get("ContractName"), "verified:", src.get("Verified"))
    print("WROTE approvals_census.json")

if __name__ == "__main__":
    main()
