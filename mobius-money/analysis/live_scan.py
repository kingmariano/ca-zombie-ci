#!/usr/bin/env python3
"""Batch-scan Mobius gauges + their external reward contracts on Celo (read-only).

Writes analysis/gauge-claims-raw.json sections: gauge_calls, reward_contract_calls.
No keys, public RPC only.
"""
import json, time, urllib.request, sys

RPC = "https://forno.celo.org"
GAUGES = [
    "0xdAA2ab880b7f3D5697e6F85e63c28b9120AA9E07",
    "0xD38e76E17E66b562B61c149Ca0EE53CEa1145733",
    "0x1A8938a37093d34581B21bAd2AE7DC1c19150C05",
    "0xd1B3C05FE24bda6F52e704daf1ACBa8c440d8573",
    "0xe2d6095685248F38Ae9fef1b360D772b78Ea19D1",
    "0x52517feb1Fc6141d5CF6718111C7Cc0FD764fA5d",
    "0x27D9Bfa5F864862BeDC23cFab7e00b6b94488CC6",
    "0x1A648004d8AB84eE34d2D1cd2F2A7a7828D6939F",
    "0x1250D6dd3B51D20c14a8ECb10CC2dd713967767e",
    "0xCF34F4ec5DC9E09428A4f4a45475f6277694166c",
    "0x5489b2F0A1992b889F47601D71E068Fd15c63f26",
    "0x2459BDb59a3BF6Ab6C412Ac0b220e7CDA1D4ea26",
    "0xF2ae5c2D2D2eD13dd324C0942163054fc4A3D4d9",
    "0xc96AeeaFF32129da934149F6134Aa7bf291a754E",
    "0x487c30CB18AA9Ced435911E2B414e0e85D7E52bB",
    "0x127b524c74C2162Ee4BB2e42d8d2eB9050C0293E",
    "0x0A125D473cd3b1968e728DDF7d424c928C09222A",
    "0xE1f9D952EecC07cfEFa69df9fBB0cEF260957119",
    "0xE965Dd2B957448CaE3291048A9944fC2F3a693D8",
    "0x73fDa87297627Fe985bc1D40c7d68868C2624D67",
    "0x4E3E91b61c6cA47cF3664aA88Ee3f690e3E41185",
    "0xE7195E651Cc47853f0054d85c8ADFc79D532929f",
    "0xD0d57a6689188F854F996BEAE0Cb1949FDB5FF86",
    "0xCAEd243de23264Bdd8297c6eECcF320846eee18A",
    "0x107F94409746E8c8E6eFF139A100D17D9ca7FdfE",
    "0x7ed927E685d7196Ff2e7Bc48c5cB5e8af88c9332",
    "0x70AE7265545f001cb015399D672B85D8f2CaCA72",
]
CELO = "0x471EcE3750Da237f93B8E339c536989b8978a438"
MOBI = "0x73a210637f6f6b7005512677ba6b3c96bb4aa44b"

T = {
    "minter()": "0x07546172",
    "crv_token()": "0x76d8b117",
    "lp_token()": "0x82c63066",
    "controller()": "0xf77c4791",
    "voting_escrow()": "0xdfe05031",
    "admin()": "0xf851a440",
    "is_killed()": "0x9c868ac0",
    "totalSupply()": "0x18160ddd",
    "working_supply()": "0x17e28089",
    "inflation_rate()": "0x180692d0",
    "reward_contract()": "0xbf88a6ff",
    "last_claim()": "0x3488bd19",
    "period()": "0xef78d4fd",
    "integrate_checkpoint()": "0xd31f3f6d",
    "balanceOf(address)": "0x70a08231",
    "reward_tokens(uint256)": "0x54c49fe9",
    "reward_integral(address)": "0x73861fb3",
    "claimable_reward(address,address)": "0x33fd6f74",
    "reward_integral_for(address,address)": "0xf05cc058",
}
# reward contract raw selectors (identified via 4byte.directory)
RC = {
    "stakingToken()": "0x72f702f3",
    "rewardsToken()": "0xd1af0c7d",
    "periodFinish()": "0xebe2b12b",
    "lastUpdateTime()": "0xc8f33c91",
    "rewardRate()": "0x7b0a47ee",
    "rewardPerTokenStored()": "0xdf136d65",
    "rewardsDuration()": "0x386a9525",
    "totalSupply()": "0x18160ddd",
    "balanceOf(address)": "0x70a08231",
    "rewards(address)": "0x0700037d",
    "userRewardPerTokenPaid(address)": "0x8b876347",
    "getRewardForDuration()": "0x1c1f78eb",
    "owner()": "0x8da5cb5b",
    "nominatedOwner()": "0x53a47bb7",
    "rewardsDistribution()": "0x3fc6df6e",
    "rewardPerToken()": "0xcd3daf9d",
}


def batch(calls):
    """calls: list of (to, data) -> results list (raw hex)"""
    out = []
    for i in range(0, len(calls), 40):
        chunk = calls[i:i + 40]
        payload = [{"jsonrpc": "2.0", "id": j, "method": "eth_call",
                    "params": [{"to": t, "data": d}, "latest"]} for j, (t, d) in enumerate(chunk)]
        body = json.dumps(payload).encode()
        for attempt in range(5):
            try:
                req = urllib.request.Request(RPC, data=body, headers={
                    "Content-Type": "application/json", "User-Agent": "Mozilla/5.0 (research)"})
                with urllib.request.urlopen(req, timeout=90) as r:
                    res = json.loads(r.read().decode())
                break
            except Exception as e:
                print(f"retry {attempt}: {e}", file=sys.stderr)
                time.sleep(2 + attempt * 3)
        else:
            raise RuntimeError("batch failed")
        by_id = {x["id"]: x for x in res}
        for j in range(len(chunk)):
            x = by_id.get(j, {})
            out.append(x.get("result") if "error" not in x else {"error": x["error"]})
        time.sleep(0.25)
    return out


def enc_addr(a):
    return a.lower().replace("0x", "").rjust(64, "0")


def main():
    raw = {"rpc": RPC, "generated": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
           "block": None, "gauge_calls": {}, "reward_contract_calls": {}, "token_balances": {}}
    body = json.dumps({"jsonrpc": "2.0", "id": 1, "method": "eth_blockNumber", "params": []}).encode()
    req = urllib.request.Request(RPC, data=body, headers={"Content-Type": "application/json",
                                                          "User-Agent": "Mozilla/5.0 (research)"})
    with urllib.request.urlopen(req, timeout=60) as r:
        raw["block"] = int(json.loads(r.read().decode())["result"], 16)

    calls = []
    meta = []
    for g in GAUGES:
        for name, sel in T.items():
            if name in ("balanceOf(address)",):
                continue
            if name == "reward_tokens(uint256)":
                for k in range(4):
                    calls.append((g, sel + enc_addr_num(k)))
                    meta.append((g, f"reward_tokens({k})"))
            elif name == "reward_integral(address)":
                calls.append((g, sel + enc_addr(CELO)))
                meta.append((g, "reward_integral(CELO)"))
            else:
                calls.append((g, sel))
                meta.append((g, name))
    res = batch(calls)
    for (g, name), r in zip(meta, res):
        raw["gauge_calls"].setdefault(g, {})[name] = r

    # gauge token balances (CELO, MOBI)
    calls = [(CELO, T["balanceOf(address)"] + enc_addr(g)) for g in GAUGES]
    res = batch(calls)
    for g, r in zip(GAUGES, res):
        raw["token_balances"].setdefault(g, {})["CELO_gauge"] = r
    calls = [(MOBI, T["balanceOf(address)"] + enc_addr(g)) for g in GAUGES]
    res = batch(calls)
    for g, r in zip(GAUGES, res):
        raw["token_balances"].setdefault(g, {})["MOBI_gauge"] = r

    # reward contracts
    rcs = {}
    for g in GAUGES:
        rc = raw["gauge_calls"][g].get("reward_contract()")
        last = raw["gauge_calls"][g].get("last_claim()")
        if isinstance(rc, str) and rc != "0x" + "0" * 64:
            addr = "0x" + rc[-40:]
            rcs.setdefault(addr, []).append(g)
    print("reward contracts:", json.dumps(rcs, indent=1))
    for rc in rcs:
        for name, sel in RC.items():
            if name == "balanceOf(address)":
                calls = [(rc, sel + enc_addr(g)) for g in rcs[rc]]
                res = batch(calls)
                for g, r in zip(rcs[rc], res):
                    raw["reward_contract_calls"].setdefault(rc, {}).setdefault("balanceOf(gauge)", {})[g] = r
            elif name == "rewards(address)":
                calls = [(rc, sel + enc_addr(g)) for g in rcs[rc]]
                res = batch(calls)
                for g, r in zip(rcs[rc], res):
                    raw["reward_contract_calls"].setdefault(rc, {}).setdefault("rewards(gauge)", {})[g] = r
            elif name == "userRewardPerTokenPaid(address)":
                calls = [(rc, sel + enc_addr(g)) for g in rcs[rc]]
                res = batch(calls)
                for g, r in zip(rcs[rc], res):
                    raw["reward_contract_calls"].setdefault(rc, {}).setdefault("userRewardPerTokenPaid(gauge)", {})[g] = r
            else:
                res = batch([(rc, sel)])
                raw["reward_contract_calls"].setdefault(rc, {})[name] = res[0]
        # CELO balance of reward contract
        res = batch([(CELO, T["balanceOf(address)"] + enc_addr(rc))])
        raw["reward_contract_calls"][rc]["CELO_balance"] = res[0]

    with open("gauge-claims-raw.json", "w") as f:
        json.dump(raw, f, indent=1)
    print("wrote gauge-claims-raw.json at block", raw["block"])


def enc_addr_num(n):
    return hex(n)[2:].rjust(64, "0")


if __name__ == "__main__":
    main()
