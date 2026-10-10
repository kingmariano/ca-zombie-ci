#!/usr/bin/env python3
"""Decode Djed addresses -> payment/stake script hashes; fetch script_info from Koios; save raw."""
import json, hashlib, urllib.request, time, sys
from pycardano import Address

def koios(endpoint, body, retries=6):
    url = f"https://api.koios.rest/api/v1/{endpoint}"
    data = json.dumps(body).encode()
    for i in range(retries):
        try:
            req = urllib.request.Request(url, data=data, method="POST", headers={"Content-Type": "application/json"})
            with urllib.request.urlopen(req, timeout=90) as r:
                return json.loads(r.read().decode())
        except Exception as e:
            print("retry", i, e, file=sys.stderr); time.sleep(2 * (i + 1))
    raise SystemExit("fail")

addrs = {
 "orderAddress": "addr1wypp5vhw2csaf62d78vmaa4652z20nr4hfgmkhacqnrvgug2vdyq4",
 "poolAddress": "addr1z8mcpc26j64fmhhd6sv5qj5mk9xqnfxgm6k8zmk7h2rlu4qm5kjdmrpmng059yellupyvwgay2v0lz6663swmds7hp0qhxg9gt",
 "oracleAddress": "addr1wxyc99q448xlkv4q2y3truxq7j2msr6hkqqg0wmzz9n9r6q8j7kpa",
 "treasuryAddress": "addr1w9ut73sw2k94pla354k97zjjxygcxx795hgkdv3hwyp4h8q694wcj",
 "refScriptAddress": "addr1w83l0f59hjy5wxwk83kdmk7u80rtm2ptgqlndm9ym67jg8q63k62g",
 "minswapPool": "addr1z84q0denmyep98ph3tmzwsmw0j7zau9ljmsqx6a4rvaau66j2c79gy9l76sdg0xwhd7r0c0kna0tycz4y5s6mlenh8pq777e2a",
 "wingridersPool": "addr1zxhew7fmsup08qvhdnkg8ccra88pw7q5trrncja3dlszhq6d77rk0jjxny493quf2pv32xup2ucx6hp6enfjg8gnjq0qqzlqam",
 "legacyBankForum": "addr1z8ru2k4eqtwrf95fvmgxu04pugezz7xg8l3jrrq9mhgh5agm5kjdmrpmng059yellupyvwgay2v0lz6663swmds7hp0q4jak04",
}
out = {}
hashes = set()
for k, a in addrs.items():
    ad = Address.from_primitive(a)
    pay = ad.payment_part.payload.hex() if getattr(ad, "payment_part", None) else None
    st = ad.staking_part.payload.hex() if getattr(ad, "staking_part", None) else None
    out[k] = {"addr": a, "type": str(ad.address_type), "payment_hash": pay, "stake_hash": st}
    for h in (pay, st):
        if h: hashes.add(h)

# reward address of pool (stake1uyd6...) decode
ra = Address.from_primitive("stake1uyd6tfxa3sae586zjvll7qjx8ywj9x8l3dddgc8dkc0tshssd5g6e")
sh = ra.staking_part.payload.hex() if getattr(ra, "staking_part", None) else None
out["poolRewardAddress"] = {"addr": "stake1uyd6...", "stake_hash": sh, "type": str(ra.address_type)}
if sh: hashes.add(sh)

# candidate known hashes
known = {
 "djedShenMintPolicy": "8db269c3ec630e06ae29f74bc39edd1f87c819f1056206e879a1cd61",
 "orderAssetPolicy": "04ea363a127872366ef2d3186325a25a5cee8826ff8a79dc7c8fa671",
 "oracleAssetPolicy": "815aca02042ba9188a2ca4f8ce7b276046e2376b4bce56391342299e",
}
for k, h in known.items():
    out[k] = {"policy": h}
    hashes.add(h)

# on-chain ref script hashes seen
onchain = ["021a32ee5621d4e94df1d9bef6baa284a7cc75ba51bb5fb804c6c471",
 "04ea363a127872366ef2d3186325a25a5cee8826ff8a79dc7c8fa671",
 "78bf460e558b50ffb1a56c5f0a523111831bc5a5d166b23771035b9c",
 "d0f7ccfe58aecdc393218b786b8c8b793dfccd8a8d73ab0c2b7f11f8",
 "f780e15a96aa9ddeedd419404a9bb14c09a4c8deac716edeba87fe54"]
hashes.update(onchain)

print(json.dumps(out, indent=1))
json.dump(out, open("address_decode.json", "w"), indent=1)

hs = sorted(hashes)
res = koios("script_info", {"_script_hashes": hs})
json.dump({"queried": hs, "response": res}, open("koios_script_info.json", "w"), indent=1)
for r in res:
    size = len(r["bytes"]) // 2
    calc = hashlib.blake2b(b"\x02" + bytes.fromhex(r["bytes"]), digest_size=28).hexdigest()
    print(r["script_hash"], r["type"], size, "blake2b(02||bytes)=", calc, "match" if calc == r["script_hash"] else "NO-MATCH")
