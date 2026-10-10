#!/usr/bin/env python3
"""Full Djed recon re-fetch (idempotent). Writes raw JSON + script raw bytes into cwd.
Keyless Koios only. Re-run safe."""
import json, re, sys, time, hashlib, urllib.request, datetime, os

BASE = "https://api.koios.rest/api/v1"

def koios(endpoint, body=None, query="", retries=7, timeout=120):
    url = f"{BASE}/{endpoint}{query}"
    data = json.dumps(body).encode() if body is not None else None
    for i in range(retries):
        try:
            req = urllib.request.Request(url, data=data,
                method="POST" if data else "GET",
                headers={"Content-Type": "application/json", "Accept": "application/json"})
            with urllib.request.urlopen(req, timeout=timeout) as r:
                return json.loads(r.read().decode())
        except Exception as e:
            print(f"  [retry {i+1}] {endpoint}: {e}", file=sys.stderr)
            time.sleep(2 * (i + 1))
    raise SystemExit(f"FAILED {endpoint}")

def save(name, obj):
    with open(name, "w") as f:
        json.dump(obj, f, indent=1)
    print("  saved", name, os.path.getsize(name), "bytes")

def main():
    ts = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    tip = koios("tip")
    print("tip", tip[0]["block_height"], "slot", tip[0]["abs_slot"], "time", tip[0]["block_time"])

    from pycardano import Address
    addrs = {
      "orderAddress": "addr1wypp5vhw2csaf62d78vmaa4652z20nr4hfgmkhacqnrvgug2vdyq4",
      "poolAddress": "addr1z8mcpc26j64fmhhd6sv5qj5mk9xqnfxgm6k8zmk7h2rlu4qm5kjdmrpmng059yellupyvwgay2v0lz6663swmds7hp0qhxg9gt",
      "oracleAddress": "addr1wxyc99q448xlkv4q2y3truxq7j2msr6hkqqg0wmzz9n9r6q8j7kpa",
      "treasuryAddress": "addr1w9ut73sw2k94pla354k97zjjxygcxx795hgkdv3hwyp4h8q694wcj",
      "refScriptAddress": "addr1w83l0f59hjy5wxwk83kdmk7u80rtm2ptgqlndm9ym67jg8q63k62g",
      "minswapDjedAdaPool": "addr1z84q0denmyep98ph3tmzwsmw0j7zau9ljmsqx6a4rvaau66j2c79gy9l76sdg0xwhd7r0c0kna0tycz4y5s6mlenh8pq777e2a",
      "wingridersDjedAdaPool": "addr1zxhew7fmsup08qvhdnkg8ccra88pw7q5trrncja3dlszhq6d77rk0jjxny493quf2pv32xup2ucx6hp6enfjg8gnjq0qqzlqam",
      "legacyBankForum": "addr1z8ru2k4eqtwrf95fvmgxu04pugezz7xg8l3jrrq9mhgh5agm5kjdmrpmng059yellupyvwgay2v0lz6663swmds7hp0q4jak04",
    }
    dec = {}
    all_hashes = set()
    for k, a in addrs.items():
        ad = Address.from_primitive(a)
        pay = ad.payment_part.payload.hex() if getattr(ad, "payment_part", None) else None
        st = ad.staking_part.payload.hex() if getattr(ad, "staking_part", None) else None
        dec[k] = {"addr": a, "type": str(ad.address_type), "payment_hash": pay, "stake_hash": st}
        for h in (pay, st):
            if h: all_hashes.add(h)
    for k in ["djedShenMintPolicy", "orderAssetPolicy", "oracleAssetPolicy"]:
        v = {"djedShenMintPolicy":"8db269c3ec630e06ae29f74bc39edd1f87c819f1056206e879a1cd61",
             "orderAssetPolicy":"04ea363a127872366ef2d3186325a25a5cee8826ff8a79dc7c8fa671",
             "oracleAssetPolicy":"815aca02042ba9188a2ca4f8ce7b276046e2376b4bce56391342299e"}[k]
        dec[k] = {"policy": v}; all_hashes.add(v)
    dec["_meta"] = {"queried_at": ts, "tip": tip}
    save("koios_address_decode.json", dec)

    # 1. address_info (balances + utxos + inline datum + ref scripts)
    body = {"_addresses": list(addrs.values())}
    ai = koios("address_info", body)
    save("koios_address_info.json", {"queried_at": ts, "tip": tip, "response": ai})

    # 2. address_assets (aggregated)
    aa = koios("address_assets", body)
    save("koios_address_assets.json", {"queried_at": ts, "tip": tip, "response": aa})

    # 3. script_info for all script hashes (payment/stake creds + policies + onchain ref scripts)
    onchain = ["021a32ee5621d4e94df1d9bef6baa284a7cc75ba51bb5fb804c6c471",
               "04ea363a127872366ef2d3186325a25a5cee8826ff8a79dc7c8fa671",
               "78bf460e558b50ffb1a56c5f0a523111831bc5a5d166b23771035b9c",
               "d0f7ccfe58aecdc393218b786b8c8b793dfccd8a8d73ab0c2b7f11f8",
               "f780e15a96aa9ddeedd419404a9bb14c09a4c8deac716edeba87fe54",
               "86f78376bad8a2c3520e01a03b247b3de0bc1fa27df506db4acab9af"]
    hs = sorted(all_hashes | set(onchain))
    res = koios("script_info", {"_script_hashes": hs})
    save("koios_script_info.json", {"queried_at": ts, "tip": tip, "queried": hs, "response": res})
    os.makedirs("scripts/plutus", exist_ok=True)
    for r in res:
        raw = bytes.fromhex(r["bytes"])
        p = f"scripts/plutus/{r['script_hash']}.cbor.bin"
        open(p, "wb").write(raw)
        calc2 = hashlib.blake2b(b"\x02" + raw, digest_size=28).hexdigest()
        calc1 = hashlib.blake2b(b"\x01" + raw, digest_size=28).hexdigest()
        print(f"  {r['script_hash'][:20]} {r['type']} {len(raw)}b v1={'OK' if calc1==r['script_hash'] else '-'} v2={'OK' if calc2==r['script_hash'] else '-'}")
    print("DONE")

if __name__ == "__main__":
    main()
