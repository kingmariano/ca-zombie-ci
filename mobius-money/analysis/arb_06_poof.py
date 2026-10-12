#!/usr/bin/env python3
"""Arb step 6: Poof token + bridge token deep-dive on-chain (Blockscout).
- creation tx details
- verified source function scan (mint/burn/redeem/bridge)
- top holders / recent mint-burn activity
Outputs: analysis/_poof_bridge.json
"""
import json, urllib.request, os, time

HERE = os.path.dirname(os.path.abspath(__file__))
BS = "https://celo.blockscout.com/api/v2"

POOF = {
    "pUSD_b4aa": "0xb4aa2986622249b1f45eb93f28cfca2b2606d809",
    "pUSD_eadf": "0xeadf4a7168a82d30ba0619e64d5bcf5b30b45226",
    "pEUR_5607": "0x56072d4832642db29225da12d6fd1290e4744682",
    "pEUR_d876": "0xd8761dd6c7cb54febd33add699f5e4440b62e01b",
    "pCELO_e74a": "0xe74abf23e1fdf7acbec2f3a30a772ef77f1601e1",
    "pCELO_301a": "0x301a61d01a63c8d670c2b8a43f37d12ef181f997",
    "POOF": "0x00400fcbf0816bebb94654259de7273f4a05c762",
    "MOBI": "0x73a210637f6f6b7005512677ba6b3c96bb4aa44b",
}
BRIDGY = {
    "atUST": "0xed193c4e69f591e42398ef54dea65aa1bb02835c",
    "aaUSDC": "0xb70e0a782b058bfdb0d109a3599bec1f19328e36",
    "USDCet": "0x2a3684e9dc20b857375ea04235f2f7edbe818fa7",
    "USDCold": "0x1bfc26ce035c368503fae319cc2596716428ca44",
    "BTC_d629": "0xd629eb00deced2a080b7ec630ef6ac117e614f1b",
    "WBTC_baab": "0xbaab46e28388d2779e6e31fd00cf0e5ad95e327b",
    "WBTC_be50": "0xbe50a3013a1c94768a1abb78c3cb79ab28fc1ace",
}


def get_json(url, tries=3):
    for t in range(tries):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0 (research; read-only)"})
            with urllib.request.urlopen(req, timeout=45) as r:
                return json.loads(r.read().decode())
        except Exception as e:
            if t == tries - 1:
                return {"error": str(e)}
            time.sleep(1 + t)


def scan_src(src):
    import re
    hits = {}
    for pat in ["mint", "burn", "redeem", "swap", "bridge", "Blacklist", "restriction",
                "role", "admin", "owner", "pause"]:
        n = len(re.findall(pat, src, re.I))
        if n:
            hits[pat] = n
    fns = re.findall(r"function\s+(\w+)\s*\(", src)
    return hits, sorted(set(fns))


def main():
    out = {"poof": {}, "bridges": {}}
    ext = json.load(open(os.path.join(HERE, "_externals.json")))
    for name, addr in {**POOF, **BRIDGY}.items():
        rec = {"address": addr}
        bs = ext["blockscout"].get(addr) or {}
        rec["creator"] = bs.get("creator")
        rec["creation_tx"] = bs.get("creation_tx")
        if bs.get("creation_tx"):
            tx = get_json(f"{BS}/transactions/{bs['creation_tx']}")
            rec["creation"] = {
                "timestamp": tx.get("timestamp"),
                "from": (tx.get("from") or {}).get("hash"),
                "block": tx.get("block_number"),
                "to": (tx.get("to") or {}).get("hash"),
                "decoded_method": ((tx.get("decoded_input") or {}).get("method_call") or "")[:200],
            }
            time.sleep(0.2)
        # source
        sc = get_json(f"{BS}/smart-contracts/{addr}")
        if isinstance(sc, dict) and sc.get("source_code"):
            hits, fns = scan_src(sc["source_code"])
            rec["impl_name"] = sc.get("name")
            rec["source_hits"] = hits
            rec["functions"] = fns[:40]
            rec["source_len"] = len(sc["source_code"])
        # holders top5
        h = get_json(f"{BS}/tokens/{addr}/holders")
        hs = []
        for it in (h.get("items") or [])[:6]:
            a = (it.get("address") or {})
            hs.append({"addr": a.get("hash"), "name": a.get("name"), "contract": a.get("is_contract"),
                       "tags": [t.get("name") for t in ((a.get("metadata") or {}).get("tags") or [])][:3],
                       "value": it.get("value")})
        rec["top_holders"] = hs
        # recent transfers (look for mints/burns from/to 0x0 and latest activity)
        tr = get_json(f"{BS}/tokens/{addr}/transfers")
        recent = []
        for it in (tr.get("items") or [])[:8]:
            recent.append({"ts": (it.get("timestamp") or "")[:10], "blk": it.get("block_number"),
                           "from": ((it.get('from') or {}).get('hash') or '')[:14],
                           "to": ((it.get('to') or {}).get('hash') or '')[:14],
                           "value": it.get("total", {}).get("value"), "type": it.get("type")})
        rec["recent_transfers"] = recent
        key = "poof" if name in POOF else "bridges"
        out[key][name] = rec
        print(name, addr, "| creator", rec.get("creator"), "| impl", rec.get("impl_name"),
              "| fns", (rec.get("functions") or [])[:10])
        time.sleep(0.3)

    with open(os.path.join(HERE, "_poof_bridge.json"), "w") as f:
        json.dump(out, f, indent=1)
    print("wrote _poof_bridge.json")


if __name__ == "__main__":
    main()
