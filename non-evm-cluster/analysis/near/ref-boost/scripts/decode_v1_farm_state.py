#!/usr/bin/env python3
"""Decode ref-farming.near (v1) farmer records dumped via view_state.
Layout per record (recovered from bytes): [variant byte] amount:u128,
rewards: HashMap<AccountId,u128> (u32 count, u32 len + bytes, u128),
seeds: HashMap<SeedId,u128>, then tail (user_rps checkpoint data).
"""
import base64, json, struct, sys
from collections import defaultdict

d = json.load(open(sys.argv[1] if len(sys.argv) > 1 else "dumps/ref-farming.near.state.json"))

def rd_u32(b,o): return struct.unpack_from("<I", b, o)[0], o+4
def rd_u128(b,o): return int.from_bytes(b[o:o+16], "little"), o+16
def rd_str(b,o):
    ln,o = rd_u32(b,o); return b[o:o+ln].decode("utf-8","replace"), o+ln

tot_rewards = defaultdict(int)
tot_seeds = defaultdict(int)
tot_amount = 0
farmers = {}
errors = []
for e in d["kv"]:
    k = bytes.fromhex(e["k_hex"]); v = base64.b64decode(e["v_b64"])
    if k == b"STATE":
        continue
    (ln,) = struct.unpack_from("<I", k, 1)
    acct = k[5:5+ln].decode()
    try:
        o = 0
        variant = v[o]; o += 1           # VersionedFarmer variant
        amount, o = rd_u128(v, o)
        n, o = rd_u32(v, o)
        rewards = {}
        for _ in range(n):
            t, o = rd_str(v, o); a, o = rd_u128(v, o); rewards[t] = a; tot_rewards[t] += a
        n2, o = rd_u32(v, o)
        seeds = {}
        for _ in range(n2):
            t, o = rd_str(v, o); a, o = rd_u128(v, o); seeds[t] = a; tot_seeds[t] += a
        tot_amount += amount
        farmers[acct] = {"variant": variant, "amount": amount, "rewards": rewards, "seeds": seeds, "tail_hex": v[o:].hex()}
    except Exception as ex:
        errors.append((acct, len(v), str(ex)))

out = {"block_height": d["block_height"], "farmers": len(farmers), "decode_errors": errors,
       "total_amount_yocto": tot_amount, "total_amount_near": tot_amount/1e24,
       "total_rewards": {k: str(v) for k,v in sorted(tot_rewards.items(), key=lambda x:-x[1])},
       "total_seeds": {k: str(v) for k,v in sorted(tot_seeds.items(), key=lambda x:-x[1])}}
json.dump({"summary": out, "farmers": farmers}, open("dumps/ref-farming.near.farmers_decoded.json","w"), indent=1)
print(json.dumps(out, indent=1)[:5000])
