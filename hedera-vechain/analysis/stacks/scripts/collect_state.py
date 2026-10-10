#!/usr/bin/env python3
"""Paced live-state collection for Arkadiko swap v2-1 audit.

Sections:
  A: token supplies/balances        B: candidate-contract balances
  C: attacker call-read simulations D: prices (DefiLlama)
  E: LP token holders               F: (separate) deploy enumeration

Rate policy: <= 45 requests/minute against api.hiro.so (observed limit 50/min).
"""
import json, os, sys, time, urllib.request, urllib.error

HERE = os.path.dirname(os.path.abspath(__file__))
EVID = os.path.join(HERE, "..", "evidence")
os.makedirs(EVID, exist_ok=True)

HIRO = "https://api.hiro.so"
SP = "SP2C2YFP12AJZB4MABJBAJ55XECVS7E4PMMZ89YZR"
SWAP = f"{SP}.arkadiko-swap-v2-1"
DAO = f"{SP}.arkadiko-dao"
LP = {t: f"{SP}.arkadiko-swap-token-{t}" for t in
      ["wstx-usda","wstx-diko","diko-usda","wstx-xbtc","xbtc-usda","wstx-welsh","wldn-usda","ldn-usda"]}
TOKEN = {
    "wstx": f"{SP}.wrapped-stx-token",
    "usda": f"{SP}.usda-token",
    "diko": f"{SP}.arkadiko-token",
    "xbtc": "SP3DX3H4FEYZJZ586MFBS25ZW3HZDMEW92260R2PR.Wrapped-Bitcoin",
    "welsh": "SP3NE50GEXFG9SZGTT51P40X2CKYSZ5CC4ZTZ7A2G.welshcorgicoin-token",
    "wldn": "SP3MBWGMCVC9KZ5DTAYFMG1D0AEJCR7NENTM3FTK5.wrapped-lydian-token",
    "ldn": "SP3MBWGMCVC9KZ5DTAYFMG1D0AEJCR7NENTM3FTK5.lydian-token",
}

sys.path.insert(0, HERE)
from clarity import call_read, c32check_encode  # noqa: E402

LAST = [0.0]
def pace(dt=None):
    dt = float(os.environ.get("PACE", "2.7")) if dt is None else dt
    d = time.time() - LAST[0]
    if d < dt:
        time.sleep(dt - d)
    LAST[0] = time.time()

def hiro_get(path, out=None):
    pace()
    req = urllib.request.Request(HIRO + path, headers={"User-Agent": "research-readonly"})
    for a in range(5):
        try:
            with urllib.request.urlopen(req, timeout=60) as r:
                data = json.loads(r.read())
            if out:
                json.dump(data, open(os.path.join(EVID, out), "w"), indent=1)
            return data
        except urllib.error.HTTPError as e:
            if e.code == 429:
                time.sleep(5 + 5 * a)
                continue
            if e.code == 404:
                return {"__http404__": True}
            raise
    raise RuntimeError("rate-limited repeatedly: " + path)

def callr(contract, fn, args, sender="SP2C2YFP12AJZB4MABJBAJ55XECVS7E4PMMZ89YZR"):
    pace()
    return call_read(contract, fn, args, sender)

def ascii_list():
    return {hex(int.from_bytes(bytes.fromhex(o), "big")) for o in []}

def sec_A():
    res = {}
    res["wstx_total_supply"] = callr(TOKEN["wstx"], "get-total-supply", [])
    res["wstx_balance_swap"] = callr(TOKEN["wstx"], "get-balance", [f"principal:{SWAP}"])
    res["usda_total_supply"] = callr(TOKEN["usda"], "get-total-supply", [])
    res["diko_total_supply"] = callr(TOKEN["diko"], "get-total-supply", [])
    for t, lp in LP.items():
        res[f"lp_supply_{t}"] = callr(lp, "get-total-supply", [])
        res[f"lp_balance_swap_{t}"] = callr(lp, "get-balance", [f"principal:{SWAP}"])
    # xBTC/USDA/WELSH supplies not needed (external tokens)
    json.dump(res, open(os.path.join(EVID, "supplies.json"), "w"), indent=1)
    print("SECTION A done")
    return res

CANDIDATES = [
    "arkadiko-swap-v1-1","arkadiko-token","usda-token","wrapped-stx-token","stdiko-token","xstx-token",
    "stx-token","arkadiko-stx-token","arkadiko-xstx-token","arkadiko-xstx-v1-1","arkadiko-xstx",
    "arkadiko-freddie-v1-1","arkadiko-freddie-v1-2","arkadiko-stx-reserve-v1-1","arkadiko-sip10-reserve-v1-1",
    "arkadiko-sip10-reserve-v2-1","arkadiko-liquidator-v1-1","arkadiko-liquidator-v2-1",
    "arkadiko-auction-engine-v1-1","arkadiko-auction-engine-v2-1","arkadiko-auction-engine-v4-1",
    "arkadiko-auction-engine-v4-2","arkadiko-auction-engine-v4-3","arkadiko-auction-engine-v4-4","arkadiko-auction-engine-v4-5",
    "arkadiko-oracle-v1-1","arkadiko-oracle-v2-1","arkadiko-oracle-v2-3","arkadiko-collateral-types-v1-1","arkadiko-collateral-types-v3-1",
    "arkadiko-governance-v1-1","arkadiko-governance-v4-2","arkadiko-governance-v4-3",
    "arkadiko-stake-registry-v1-1","arkadiko-stake-registry-v2-1","arkadiko-stake-registry-v3-1",
    "arkadiko-stake-registry-tv1-1","arkadiko-stake-pool-diko-v1-1","arkadiko-stake-pool-diko-v1-2",
    "arkadiko-stake-pool-diko-v1-4","arkadiko-stake-pool-diko-v2-1","arkadiko-stake-pool-diko-slash-v1-1",
    "arkadiko-stake-pool-diko-usda-v1-1","arkadiko-stake-pool-wstx-usda-v1-1","arkadiko-stake-pool-wstx-diko-v1-1",
    "arkadiko-stake-pool-wstx-xbtc-v1-1","arkadiko-stake-pool-xbtc-usda-v1-1","arkadiko-stake-pool-xusd-usda-v1-5",
    "arkadiko-diko-guardian-v1-1","arkadiko-diko-guardian-v3-1","arkadiko-diko-init","arkadiko-diko-init-v2-1",
    "arkadiko-vault-rewards-v1-1","arkadiko-stacker-v1-1","arkadiko-stacker-v2-1","arkadiko-stacker-2-v1-1",
    "arkadiko-stacker-2-v2-1","arkadiko-stacker-2-v3-1","arkadiko-stacker-3-v1-1","arkadiko-stacker-3-v2-1","arkadiko-stacker-3-v3-1",
    "arkadiko-stacker-4-v1-1","arkadiko-stacker-payer-v1-1","arkadiko-pox-unstack-unlock-v2-4","arkadiko-pox-unstack-unlock-v2-5",
    "arkadiko-claim-yield-v2-1","arkadiko-claim-usda-yield-v2-1","arkadiko-liquidation-pool-v1-1",
    "arkadiko-liquidation-rewards-v1-1","arkadiko-liquidation-rewards-v1-2","arkadiko-liquidation-rewards-diko-v1-1",
    "arkadiko-liquidation-ui-v1-2","arkadiko-liquidation-rewards-ui-v2-3","arkadiko-sbtc-incentives",
    "arkadiko-stable-swap-rewards-v1-1","arkadiko-alex-dual-yield-v1-1","arkadiko-multi-hop-swap-v1-1",
    "diko-stdiko","arkadiko-diko-incinerator-v1","arkadiko-swap-v2-2","arkadiko-swap-v2-3",
]

def sec_B():
    path = os.path.join(EVID, "candidate-balances.json")
    out = json.load(open(path)) if os.path.exists(path) else {}
    for name in CANDIDATES:
        if name in out:
            continue
        d = hiro_get(f"/extended/v1/address/{SP}.{name}/balances")
        if d.get("__http404__"):
            out[name] = {"http404": True}
        else:
            stx = int(d.get("stx", {}).get("balance", "0"))
            toks = {k: int(v.get("balance", "0")) for k, v in (d.get("fungible_tokens") or {}).items() if int(v.get("balance", "0")) != 0}
            out[name] = {"stx": stx, "tokens": toks}
        json.dump(out, open(path, "w"), indent=1)
    print("SECTION B done:", len([k for k, v in out.items() if v.get("stx") or v.get("tokens")]))
    return out

def sec_C(attacker):
    res = {}
    path = os.path.join(EVID, "attacker-sims.json")
    if os.path.exists(path):
        res = json.load(open(path))
    def rec(key, contract, fn, args):
        if key in res:
            return
        r = callr(contract, fn, args, sender=attacker)
        res[key] = {"request": {"contract": contract, "function": fn, "args": args, "sender": attacker}, "response": r}
        print(key, "->", json.dumps(r.get("decoded", r))[:220], flush=True)
        json.dump(res, open(path, "w"), indent=1)

    # LP mint/burn gates
    rec("lp_mint_attacker", LP["wstx-usda"], "mint", [f"principal:{attacker}", "uint:1000000"])
    rec("lp_burn_attacker", LP["wstx-usda"], "burn", [f"principal:{attacker}", "uint:1000000"])
    # swap admin gates
    rec("create_pair_attacker", SWAP, "create-pair",
        [f"principal:{TOKEN['usda']}", f"principal:{TOKEN['diko']}", f"principal:{LP['diko-usda']}", "string:FAKE", "uint:1", "uint:1"])
    rec("set_fee_to_address_attacker", SWAP, "set-fee-to-address",
        [f"principal:{TOKEN['wstx']}", f"principal:{TOKEN['usda']}", f"principal:{attacker}"])
    rec("toggle_shutdown_attacker", SWAP, "toggle-swap-shutdown", [])
    rec("toggle_pair_attacker", SWAP, "toggle-pair-enabled", [f"principal:{TOKEN['wstx']}", f"principal:{TOKEN['usda']}"])
    rec("migrate_create_pair_attacker", SWAP, "migrate-create-pair",
        [f"principal:{TOKEN['usda']}", f"principal:{TOKEN['diko']}", f"principal:{LP['diko-usda']}", "string:FAKE2", "uint:1"])
    rec("migrate_add_liquidity_attacker", SWAP, "migrate-add-liquidity",
        [f"principal:{TOKEN['wstx']}", f"principal:{TOKEN['usda']}", "uint:1", "uint:1"])
    rec("attack_and_burn_attacker", SWAP, "attack-and-burn", [f"principal:{LP['wstx-usda']}", f"principal:{attacker}", "uint:1"])
    # public liquidity/swap attempts by attacker with no funds/shares
    rec("reduce_position_attacker_no_shares", SWAP, "reduce-position",
        [f"principal:{TOKEN['wstx']}", f"principal:{TOKEN['usda']}", f"principal:{LP['wstx-usda']}", "uint:100"])
    rec("add_to_position_attacker_no_funds", SWAP, "add-to-position",
        [f"principal:{TOKEN['wstx']}", f"principal:{TOKEN['usda']}", f"principal:{LP['wstx-usda']}", "uint:1000000", "uint:0"])
    rec("swap_x_for_y_attacker_no_funds", SWAP, "swap-x-for-y",
        [f"principal:{TOKEN['wstx']}", f"principal:{TOKEN['usda']}", "uint:1000000", "uint:0"])
    rec("collect_fees_attacker", SWAP, "collect-fees", [f"principal:{TOKEN['wstx']}", f"principal:{TOKEN['usda']}"])
    rec("get_position_attacker", SWAP, "get-position", [f"principal:{TOKEN['wstx']}", f"principal:{TOKEN['usda']}", f"principal:{LP['wstx-usda']}"])
    # DAO gates
    rec("dao_mint_token_attacker", DAO, "mint-token", [f"principal:{TOKEN['usda']}", "uint:1000000000", f"principal:{attacker}"])
    rec("dao_burn_token_attacker", DAO, "burn-token", [f"principal:{TOKEN['usda']}", "uint:1000000", f"principal:{SWAP}"])
    rec("dao_set_dao_owner_attacker", DAO, "set-dao-owner", [f"principal:{attacker}"])
    rec("dao_toggle_shutdown_attacker", DAO, "toggle-emergency-shutdown", [])
    rec("dao_set_contract_address_attacker", DAO, "set-contract-address",
        ["string:swap", f"principal:{SP}", f"principal:{attacker}", "bool:true", "bool:true"])
    rec("dao_request_diko_attacker", DAO, "request-diko-tokens", ["uint:1000000"])
    # token gates
    rec("wstx_mint_for_dao_attacker", TOKEN["wstx"], "mint-for-dao", ["uint:1000000", f"principal:{attacker}"])
    rec("wstx_burn_for_dao_attacker", TOKEN["wstx"], "burn-for-dao", ["uint:1", f"principal:{SWAP}"])
    rec("usda_mint_for_dao_attacker", TOKEN["usda"], "mint-for-dao", ["uint:1000000", f"principal:{attacker}"])
    rec("diko_mint_for_dao_attacker", TOKEN["diko"], "mint-for-dao", ["uint:1000000", f"principal:{attacker}"])
    json.dump(res, open(os.path.join(EVID, "attacker-sims.json"), "w"), indent=1)
    print("SECTION C done")
    return res

def sec_D():
    ids = ",".join([
        "coingecko:blockstack",
        "stacks:SP2C2YFP12AJZB4MABJBAJ55XECVS7E4PMMZ89YZR.usda-token",
        "stacks:SP2C2YFP12AJZB4MABJBAJ55XECVS7E4PMMZ89YZR.arkadiko-token",
        "coingecko:arkadiko",
        "stacks:SP3DX3H4FEYZJZ586MFBS25ZW3HZDMEW92260R2PR.Wrapped-Bitcoin",
        "coingecko:wrapped-bitcoin",
        "stacks:SP3NE50GEXFG9SZGTT51P40X2CKYSZ5CC4ZTZ7A2G.welshcorgicoin-token",
        "stacks:SP3MBWGMCVC9KZ5DTAYFMG1D0AEJCR7NENTM3FTK5.lydian-token",
        "stacks:SP3MBWGMCVC9KZ5DTAYFMG1D0AEJCR7NENTM3FTK5.wrapped-lydian-token",
    ])
    req = urllib.request.Request(f"https://coins.llama.fi/prices/current/{ids}",
                                 headers={"User-Agent": "research-readonly"})
    d = json.loads(urllib.request.urlopen(req, timeout=60).read())
    json.dump(d, open(os.path.join(EVID, "prices-llama.json"), "w"), indent=1)
    print("SECTION D done")
    return d

def sec_E():
    path = os.path.join(EVID, "lp-holders.json")
    out = json.load(open(path)) if os.path.exists(path) else {}
    for t, lp in LP.items():
        if t in out:
            continue
        ident = f"{lp}::{t}"
        d = hiro_get(f"/extended/v1/tokens/{ident}/holders?limit=20")
        out[t] = d
        json.dump(out, open(path, "w"), indent=1)
    print("SECTION E done")
    return out

def main():
    section = sys.argv[1] if len(sys.argv) > 1 else "all"
    # generate a syntactically valid fresh attacker principal (version 22, deterministic hash160)
    attacker = c32check_encode(22, bytes(range(20)))
    print("attacker:", attacker)
    if section in ("all", "A") and not os.path.exists(os.path.join(EVID, "supplies.json")): sec_A()
    if section in ("all", "B"): sec_B()
    if section in ("all", "C"): sec_C(attacker)
    if section in ("all", "D") and not os.path.exists(os.path.join(EVID, "prices-llama.json")): sec_D()
    if section in ("all", "E"): sec_E()

if __name__ == "__main__":
    main()
