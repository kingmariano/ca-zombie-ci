#!/usr/bin/env python3
"""Resolve live role holders per chain from RoleGranted/RoleRevoked logs + hasRole.

Writes raw/roles_<chain>.json
"""
import json
import os
import sys

from rpc import Rpc

BASE = os.path.dirname(os.path.abspath(__file__))
RAW = os.path.join(BASE, "raw")

RPC = {
    "base": "https://base-rpc.publicnode.com",
    "arb": "https://arb1.arbitrum.io/rpc",
    "mantle": "https://rpc.mantle.xyz",
    "blast": "https://blast-rpc.publicnode.com",
}
DIAMOND = {
    "base": "0x91Cf2D8Ed503EC52768999aA6D8DBeA6e52dbe43",
    "arb": "0x8F06459f184553e5d04F07F868720BDaCAB39395",
    "mantle": "0x2Ecc7da3Cc98d341F987C85c3D9FC198570838B5",
    "blast": "0x3d17f073cCb9c3764F105550B0BCF9550477D266",
}

ROLE_NAMES = [
    "DEFAULT_ADMIN_ROLE", "ADMIN_ROLE", "CONTROLLER_ROLE", "PAUSER_ROLE",
    "UNPAUSER_ROLE", "SETTER_ROLE", "MUON_SETTER_ROLE", "SUSPENDED_ROLE",
    "LIQUIDATOR_ROLE", "EMERGENCY_ROLE", "MASTER_ROLE", "VIEW_ROLE",
    "WITHDRAWER_ROLE", "OWNER_ROLE", "OPERATOR_ROLE",
    "AFFILIATE_MANAGER_ROLE", "BALANCE_SETTLER_ROLE", "BRIDGE_MANAGER_ROLE",
    "CLEARING_HOUSE_ROLE", "COOLDOWN_ADMIN_ROLE", "DISPUTE_ROLE",
    "EMERGENCY_ADMIN_ROLE", "FEE_ADMIN_ROLE", "FORCE_CLOSE_GAP_RATIO_ADMIN_ROLE",
    "INSTANT_LAYER_ROLE", "INTEGRATION_ADMIN_ROLE", "MIGRATION_ROLE",
    "PARTYB_LIQUIDATOR_ROLE", "PARTY_B_MANAGER_ROLE", "PROTOCOL_CONFIG_ROLE",
    "PROVIDER_ADMIN_ROLE", "SIGNER_ADMIN_ROLE", "SOFT_LIQUIDATOR_ROLE",
    "SUSPENDED_FUNDS_WITHDRAWER_ROLE", "SUSPENDER_ROLE", "SYMBOL_MANAGER_ROLE",
    "UNSUSPENDER_ROLE", "VIRTUAL_DEPOSITOR_ROLE", "WITHDRAW_FORCE_CANCEL_ROLE",
    "WITHDRAW_SPEED_UP_ROLE",
]

CANDIDATES = [
    "0x9BC9CA7e6A8F013f40617c4585508A988DB7C1c7",
    "0x319F10D14B5B7195a1693f4f5C015370C4324Fa6",
    "0x67736569B61BdB7F1A756EF069aB5B9590668E4c",
]


def run(chain):
    r = Rpc(RPC[chain])
    diamond = DIAMOND[chain]
    block = r.block_number()
    bh = hex(block)
    out = {"chain": chain, "block": block, "diamond": diamond}

    # hash each role name
    res = r.batch_call([("getRoleHash", [n], diamond) for n in ROLE_NAMES], bh)
    name_to_hash = {}
    for n, v in zip(ROLE_NAMES, res):
        v = v[0] if v else None
        if v:
            name_to_hash[n] = "0x" + v.hex()
    out["name_to_hash"] = name_to_hash

    # brute-force map any log role hash that is keccak of a listed name (even if getRoleHash missing)
    import eth_utils
    hash_to_name = {h: n for n, h in name_to_hash.items()}
    for n in ROLE_NAMES:
        h = "0x" + eth_utils.keccak(text=n).hex()
        hash_to_name.setdefault(h, n)
    out["hash_to_name"] = hash_to_name

    agg_path = os.path.join(RAW, f"agg_{chain}.json")
    log_pairs = []
    if os.path.exists(agg_path):
        agg = json.load(open(agg_path))
        for role, users in agg.get("roles", {}).items():
            for u, st in users.items():
                log_pairs.append((role, u, st.get("grant_block"), st.get("revoke_block")))
    out["log_role_events"] = [
        {"role_hash": rh, "role": hash_to_name.get(rh, rh), "user": u,
         "grant": g, "revoke": rv} for rh, u, g, rv in log_pairs
    ]

    # live check: unique (hash, user)
    pairs = sorted(set((rh, u) for rh, u, _, _ in log_pairs))
    res = r.batch_call([("hasRole", [u, bytes.fromhex(rh[2:])], diamond) for rh, u in pairs], bh)
    live = []
    for (rh, u), v in zip(pairs, res):
        if v and v[0]:
            g = next((x[2] for x in log_pairs if x[0] == rh and x[1] == u), None)
            rv = next((x[3] for x in log_pairs if x[0] == rh and x[1] == u), None)
            live.append({"role": hash_to_name.get(rh, rh), "role_hash": rh, "user": u,
                         "grant_block": g, "revoke_block": rv})
    out["live_role_holders"] = live

    # candidate admins vs all role names
    res = r.batch_call([("hasRole", [c, bytes.fromhex(h[2:])], diamond)
                        for c in CANDIDATES for h in name_to_hash.values()], bh)
    i = 0
    cand_roles = {}
    for c in CANDIDATES:
        for n in name_to_hash:
            v = res[i]; i += 1
            if v and v[0]:
                cand_roles.setdefault(c, []).append(n)
    out["candidate_roles"] = cand_roles

    with open(os.path.join(RAW, f"roles_{chain}.json"), "w") as f:
        json.dump(out, f, indent=1)
    print(f"[{chain}] block {block}: {len(live)} live role grants")
    for lv in live:
        print(f"   {lv['role']:<32} {lv['user']} grant={lv['grant_block']} revoke_seen={lv['revoke_block']}")
    for c, rl in cand_roles.items():
        print(f"   CAND {c}: {rl}")


if __name__ == "__main__":
    for c in sys.argv[1:] or RPC:
        run(c)
