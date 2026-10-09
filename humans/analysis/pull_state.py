#!/usr/bin/env python3
"""
C2-30 Humans governance-capture — live state pull (read-only, public endpoints only).

Pulls from public LCD/RPC of humans_1089-1:
  - latest height/time, staking pool, supply, community pool
  - gov params (ABCI, v1beta1 legacy handler) + genesis cross-check
  - module accounts and their balances (distribution/gov/mint/fee_collector/...)
  - validators (bonded/unbonding/unbonded) with tokens/commission
  - gov proposals + tallies + votes
  - IBC channels/connections (for HEART market discovery), ICA host params, wasm check

Saves raw JSON into analysis/raw/. No secrets, no transactions.
"""
import base64, json, os, subprocess, sys, hashlib, time

HERE = os.path.dirname(os.path.abspath(__file__))
RAW = os.path.join(HERE, "raw")
os.makedirs(RAW, exist_ok=True)

UA = "Mozilla/5.0 (X11; Linux x86_64) research"
LCD = "https://api.humans.nodestake.org"
LCD2 = "https://humans-api.noders.services"
RPC = "https://humans-rpc.noders.services"

def curl(url, timeout=40, post=None):
    cmd = ["curl", "-s", "--max-time", str(timeout), "-A", UA]
    if post:
        cmd += ["-X", "POST", "-H", "Content-Type: application/json", "-d", json.dumps(post)]
    cmd.append(url)
    for _ in range(3):
        out = subprocess.run(cmd, capture_output=True, text=True).stdout
        if out.strip():
            return out
        time.sleep(2)
    return out

def jget(path, base=None):
    out = curl((base or LCD) + path)
    try:
        return json.loads(out)
    except Exception:
        return {"_error": out[:300], "_path": path}

def save(name, obj):
    with open(os.path.join(RAW, name), "w") as f:
        json.dump(obj, f, indent=1)
    print("saved", name)

def abci(path, data_hex=""):
    payload = {"jsonrpc": "2.0", "id": 1, "method": "abci_query",
               "params": {"path": path, "data": data_hex, "prove": False}}
    out = curl(RPC, post=payload)
    try:
        d = json.loads(out)
        return d["result"]["response"]
    except Exception:
        return {"_error": out[:300]}

# ---------------- bech32 for module addresses ----------------
CHARSET = "qpzry9x8gf2tvdw0s3jn54khce6mua7l"

def bech32_polymod(values):
    gen = [0x3b6a57b2, 0x26508e6d, 0x1ea119fa, 0x3d4233dd, 0x2a1462b3]
    chk = 1
    for v in values:
        b = chk >> 25
        chk = ((chk & 0x1ffffff) << 5) ^ v
        for i in range(5):
            if (b >> i) & 1:
                chk ^= gen[i]
    return chk

def bech32_hrp_expand(hrp):
    return [ord(x) >> 5 for x in hrp] + [0] + [ord(x) & 31 for x in hrp]

def bech32_encode(hrp, data):
    values = bech32_hrp_expand(hrp) + data
    polymod = bech32_polymod(values + [0, 0, 0, 0, 0, 0]) ^ 1
    checksum = [(polymod >> 5 * (5 - i)) & 31 for i in range(6)]
    return hrp + "1" + "".join(CHARSET[d] for d in data + checksum)

def convertbits(data, frombits, tobits, pad=True):
    acc = 0; bits = 0; ret = []
    maxv = (1 << tobits) - 1
    for value in data:
        acc = (acc << frombits) | value
        bits += frombits
        while bits >= tobits:
            bits -= tobits
            ret.append((acc >> bits) & maxv)
    if pad and bits:
        ret.append((acc << (tobits - bits)) & maxv)
    return ret

def module_address(name):
    h = hashlib.sha256(name.encode()).digest()[:20]
    return bech32_encode("human", convertbits(list(h), 8, 5))

def main():
    state = {}
    # 1. latest block
    blocks = jget("/cosmos/base/tendermint/v1beta1/blocks/latest")
    try:
        state["height"] = int(blocks["block"]["header"]["height"])
        state["time"] = blocks["block"]["header"]["time"]
    except Exception:
        state["height"] = None
    print("height", state.get("height"), state.get("time"))

    # 2. staking pool + params
    state["staking_pool"] = jget("/cosmos/staking/v1beta1/pool").get("pool")
    state["staking_params"] = jget("/cosmos/staking/v1beta1/params").get("params")
    state["distribution_params"] = jget("/cosmos/distribution/v1beta1/params").get("params")
    state["mint_params"] = jget("/cosmos/mint/v1beta1/params").get("params")
    state["mint_inflation"] = jget("/cosmos/mint/v1beta1/inflation")
    state["mint_annual_provisions"] = jget("/cosmos/mint/v1beta1/annual_provisions")
    state["slashing_params"] = jget("/cosmos/slashing/v1beta1/params").get("params")

    # 3. supply
    state["supply_all"] = jget("/cosmos/bank/v1beta1/supply?pagination.limit=200").get("supply")
    state["supply_aheart"] = jget("/cosmos/bank/v1beta1/supply/by_denom?denom=aheart")

    # 4. community pool accounting
    state["community_pool"] = jget("/cosmos/distribution/v1beta1/community_pool").get("pool")

    # 5. module accounts + balances
    mods = jget("/cosmos/auth/v1beta1/module_accounts?pagination.limit=200")
    state["module_accounts"] = mods.get("accounts")
    mod_balances = {}
    names = []
    for a in state["module_accounts"] or []:
        nm = a.get("name")
        addr = (a.get("@type", ""), a.get("base_account", {}).get("address"))
        names.append((nm, addr[1]))
    # always include computed core module addrs
    computed = {n: module_address(n) for n in
                ["distribution", "gov", "mint", "fee_collector", "bonded_tokens_pool",
                 "not_bonded_tokens_pool", "transfer", "ibc", "evm", "feemarket",
                 "interchainaccounts", "icahost", "icacontroller"]}
    state["computed_module_addrs"] = computed
    for nm, addr in (names + list(computed.items())):
        if not addr:
            continue
        if addr in mod_balances:
            continue
        b = jget(f"/cosmos/bank/v1beta1/balances/{addr}?pagination.limit=200")
        mod_balances[addr] = {"name": nm, "balances": b.get("balances"), "error": b.get("_error")}
    state["module_balances"] = mod_balances
    save("module_balances.json", mod_balances)

    # 6. validators (all statuses)
    for st in ["BOND_STATUS_BONDED", "BOND_STATUS_UNBONDING", "BOND_STATUS_UNBONDED"]:
        d = jget(f"/cosmos/staking/v1beta1/validators?status={st}&pagination.limit=300")
        state["validators_" + st.split("_")[-1].lower()] = d.get("validators")
    # delegations count for bonded validators
    tot_dels = {}
    for v in (state.get("validators_bonded") or [])[:60]:
        d = jget(f"/cosmos/staking/v1beta1/validators/{v['operator_address']}/delegations?pagination.limit=1")
        tot_dels[v["operator_address"]] = d.get("pagination", {}).get("total")
    state["validator_delegator_counts"] = tot_dels

    # 7. gov params via ABCI (v1beta1 legacy) + genesis cross-check
    def abci_params(pt):
        data = "0a" + format(len(pt), "02x") + pt.encode().hex()
        r = abci("/cosmos.gov.v1beta1.Query/Params", data)
        val = r.get("value")
        return {"code": r.get("code"), "height": r.get("height"),
                "b64": val, "hex": base64.b64decode(val).hex() if val else None}
    state["gov_params_abci"] = {pt: abci_params(pt) for pt in ["tallying", "voting", "deposit"]}
    state["gov_params_genesis"] = None
    try:
        g = json.load(open(os.path.join(RAW, "humans_genesis.json")))
        state["gov_params_genesis"] = g["app_state"]["gov"]
    except Exception:
        pass

    # 8. proposals + tallies + votes (v1beta1 and v1)
    props = jget("/cosmos/gov/v1beta1/proposals?pagination.limit=200")
    state["proposals"] = props.get("proposals")
    state["proposal_tallies"] = {}
    state["proposal_votes"] = {}
    for p in state["proposals"] or []:
        pid = p["proposal_id"]
        state["proposal_tallies"][pid] = jget(f"/cosmos/gov/v1beta1/proposals/{pid}/tally")
        v = jget(f"/cosmos/gov/v1/proposals/{pid}/votes?pagination.limit=400")
        state["proposal_votes"][pid] = v.get("votes", v)

    # 9. IBC channels/connections (market discovery)
    state["ibc_channels"] = jget("/ibc/core/channel/v1/channels?pagination.limit=500").get("channels")
    state["ibc_connections"] = jget("/ibc/core/connection/v1/connections?pagination.limit=500").get("connections")
    state["ica_host_params"] = jget("/ibc/apps/interchain_accounts/host/v1/params")

    # 10. wasm module check (expected absent)
    state["wasm_codes"] = jget("/cosmwasm/wasm/v1/codes?pagination.limit=10")

    # 11. authz grants involving gov module (any standing authorities)
    gov_addr = computed["gov"]
    state["authz_granter_gov"] = jget(f"/cosmos/authz/v1beta1/grants/granter/{gov_addr}?pagination.limit=200")
    state["authz_granter_gov_module"] = jget(f"/cosmos/authz/v1beta1/grants/granter/{module_address('gov')}?pagination.limit=200")

    # 12. community pool historical spend events: last txs to distribution module
    #     (checked separately via tx search)

    save("state.json", state)
    print("DONE. height:", state.get("height"))

if __name__ == "__main__":
    main()
