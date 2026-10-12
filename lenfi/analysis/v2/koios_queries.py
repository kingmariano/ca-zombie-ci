#!/usr/bin/env python3
"""Keyless Koios queries for Lenfi V2 zombie investigation (evidence saved under v2/)."""
import json, time, urllib.request, urllib.error, sys

BASE = "https://api.koios.rest/api/v1"
V2 = "/home/heisenberg/CA/lenfi/analysis/v2"
REPO = "/tmp/opencode/lenfi-v2-repo"

def post(path, payload, retries=6):
    data = json.dumps(payload).encode()
    for i in range(retries):
        try:
            req = urllib.request.Request(BASE + path, data=data,
                headers={"Content-Type": "application/json", "Accept": "application/json"})
            with urllib.request.urlopen(req, timeout=90) as r:
                return json.loads(r.read())
        except urllib.error.HTTPError as e:
            code = e.code
            print(f"  HTTP {code} on {path}, retry {i+1}", file=sys.stderr)
            if code in (413, 429, 500, 502, 503):
                time.sleep(5 * (i + 1))
                continue
            raise
        except Exception as e:
            print(f"  ERR {e} on {path}, retry {i+1}", file=sys.stderr)
            time.sleep(5 * (i + 1))
    raise RuntimeError("failed " + path)

# ---- 1. deployedValidators.json txs ----
deps = json.load(open(f"{REPO}/src/deployedValidators.json"))
txs = sorted(set(d["txHash"] for d in deps))
print("querying", len(txs), "deployment txs")
tinfo = post("/tx_info", {"_tx_hashes": txs})
json.dump(tinfo, open(f"{V2}/koios_deployed_validators_tx_info.json", "w"), indent=1)
found = {t["tx_hash"] for t in tinfo}
print("found on mainnet:", len(found), "/", len(txs))
for d in deps:
    print("  ", "FOUND " if d["txHash"] in found else "MISSING", d["validatorName"], d["txHash"][:16], "ix", d["outputIndex"])

# map validatorName -> output ref script hash + address
name_map = {}
for t in tinfo:
    for d in deps:
        if d["txHash"] == t["tx_hash"]:
            outs = t.get("outputs") or []
            ix = d["outputIndex"]
            if ix < len(outs):
                o = outs[ix]
                name_map[d["validatorName"]] = {
                    "tx": t["tx_hash"], "ix": ix, "address": o.get("payment_addr", {}).get("bech32"),
                    "value": o.get("value"), "ref_script": o.get("reference_script"),
                    "block_time": t.get("block_time"), "block_height": t.get("block_height"),
                }
json.dump(name_map, open(f"{V2}/koios_deployed_validators_name_map.json", "w"), indent=1)
for k, v in name_map.items():
    rs = v.get("ref_script") or {}
    print(f"  {k:25s} addr={v['address']} ref={rs.get('hash')} sz={rs.get('size')} blk={v['block_time']}")

# ---- 2. script_info for the 3 live scripts + related ----
hashes = [
    "32e8c0ae314ef4be452c16a999867f66d1a1791fc972cb2f7c74e38d",
    "9b99fef5ee9a6b170a418999e89edad93bbf55bf1feef57b6053d634",
    "8021830afedd85fda1253da2be75b66c0e65c482148eb8ca690903cb",
    "4f0ea56aa63c5b67ace582d2284a665d246c9b40f222c0929b3b4864",
    "c7e01eda20dc413d27739c164b38474189b192e92c024d35fdf60219",
    "4bb070564113d5dfffd0d7336d1a6efd1fd154e6d8a75467213deed8",
    "fa0a035e313e3a5861dad43f58b25d7675e1443966fa0a46d01ac9e1",
    "936a724f84a77f4bbbe167d8779ea1a3af9124e0b9d4712fedfa4d4d",
    "b6e02be7d97343048c53a06786bfd6185f5fdef306a870cfc8edf033",
    "ecf0762dfc1c15f918937b151197b3f955e390cff20f6e78ef0be6c9",
    "c04e78ea267631f27975446a15d96ef1f3bbcdbf99577d3e552c663b",
    "f8dddd3eab826faf5926132244abf477190bf8db6efcb12398343561",
    "4c29cb6c48ff822900a5233db40526b97a191e8c5fa00a4b3f896b2e",
]
print("querying", len(hashes), "script_info")
sinfo = post("/script_info", {"_script_hashes": hashes})
json.dump(sinfo, open(f"{V2}/koios_script_info_v2.json", "w"), indent=1)
for s in sinfo:
    print(" ", s.get("script_hash"), "type", s.get("type"), "size", s.get("size"),
          "creation_tx", s.get("creation_tx_hash"), "blk", s.get("creation_tx_hash") and s.get("block_height"), s.get("block_time"))

# ---- 3. tx_info for creation txs ----
ct = sorted(set(s["creation_tx_hash"] for s in sinfo if s.get("creation_tx_hash")))
if ct:
    print("querying", len(ct), "creation txs")
    cinfo = post("/tx_info", {"_tx_hashes": ct})
    json.dump(cinfo, open(f"{V2}/koios_creation_tx_info.json", "w"), indent=1)
    for t in cinfo:
        print("  ", t["tx_hash"], "block", t.get("block_height"), "time", t.get("block_time"))
print("DONE")
