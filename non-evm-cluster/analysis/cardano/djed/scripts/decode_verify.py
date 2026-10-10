#!/usr/bin/env python3
"""Decode Djed addresses + verify registry script hashes against on-chain reference script hashes.
Reads registry raw TS from scripts/ dir. Uses pycardano.
"""
import re, json, hashlib
from pycardano import Address, Network, PlutusV2Script, plutus_script_hash

RAW = open("scripts/open-djed-registry-mainnet.raw.ts").read()
main = RAW[RAW.index("Mainnet: {"):]

def get_str(key):
    m = re.search(key + r':\s*((?:"[^"]*"\s*\+?\s*)+)', main)
    return "".join(re.findall(r'"([^"]*)"', m.group(1))) if m else None

# registry script hex strings (find the ref UTxO script fields by key order)
def get_script(key):
    m = re.search(key + r':\s*\{(.*?)\n    \}', main, re.S)
    if not m: return None
    sm = re.search(r'script:\s*"([0-9a-f]+)"', m.group(1))
    return sm.group(1) if sm else None

scripts = {k: get_script(k) for k in ["poolSpendingValidatorRefUTxO", "orderSpendingValidatorRefUTxO", "orderMintingPolicyRefUTxO", "stakeValidatorRefUTxO"]}
script_hashes = {}
for k, hexs in scripts.items():
    if not hexs: continue
    # CBOR bytestring wrapper: 59 xxxx <payload> for >255 bytes ; could also be plain
    if hexs.startswith("59"):
        payload = hexs[6:]
    elif hexs.startswith("58"):
        payload = hexs[4:]
    else:
        payload = hexs[2:]
    raw = bytes.fromhex(payload)
    h = hashlib.blake2b(b"\x02" + raw, digest_size=28).hexdigest()  # PlutusV2 prefix
    script_hashes[k] = {"hash": h, "size": len(raw), "payload_hex": payload}

print("== registry script hashes (blake2b-224 of 0x02||script)")
print(json.dumps(script_hashes, indent=1))

onchain = {
 "021a32ee5621d4e94df1d9bef6baa284a7cc75ba51bb5fb804c6c471": 3002,
 "04ea363a127872366ef2d3186325a25a5cee8826ff8a79dc7c8fa671": 4911,
 "78bf460e558b50ffb1a56c5f0a523111831bc5a5d166b23771035b9c": 2388,
 "d0f7ccfe58aecdc393218b786b8c8b793dfccd8a8d73ab0c2b7f11f8": 302,
 "f780e15a96aa9ddeedd419404a9bb14c09a4c8deac716edeba87fe54": 12698,
}
print("\n== match check")
reg_by_hash = {v["hash"]: k for k, v in script_hashes.items()}
for h, sz in onchain.items():
    print(h[:20], "size", sz, "->", reg_by_hash.get(h, "NOT in registry scripts"))

print("\n== address decode")
addrs = {k: get_str(k) for k in ["orderAddress", "poolAddress", "oracleAddress", "treasuryAddress", "minswapAddress", "wingridersAddress"]}
for k, a in addrs.items():
    try:
        ad = Address.from_primitive(a)
        pay = ad.payment_part.payload.hex() if ad.payment_part else None
        st = ad.stake_part.payload.hex() if ad.stake_part else None
        print(k, "payment:", pay, "stake:", st)
    except Exception as e:
        print(k, "ERR", e)

json.dump({"script_hashes": script_hashes, "onchain_match": {h: reg_by_hash.get(h) for h in onchain}}, open("script_hash_verify.json", "w"), indent=1)
