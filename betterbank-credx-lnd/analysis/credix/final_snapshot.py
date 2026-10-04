#!/usr/bin/env python3
"""FINAL pinned-block verification snapshot of all headline claims."""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from rpcx import rpc, batch, dec_u  # noqa

HERE = os.path.dirname(os.path.abspath(__file__))
RAW = os.path.join(HERE, "raw")

# token addresses
T = {
    "wS": "0x039e2fB66102314Ce7b64Ce5Ce3E5183bc94aD38",
    "USDC": "0x29219dd400f2Bf60E5a23d13Be72B486D4038894",
    "scUSD": "0xd3DCe716f3eF535C5Ff8d041c1A41C3bd89b97aE",
    "WETH": "0x50c42dEAcD8Fc9773493ED674b675bE577f2634b",
    "stS": "0xE5DA20F15420aD15DE0fa650600aFc998bbE3955",
    "acUSDC": "0xEc26D07B5c0a99D3690375A2CC229E5b943e7726",
    "acscUSD": "0xa175EE511de429275d26Ac5420fAbeb60C67C372",
    "acwS": "0x95cAF53667D912F3491173fd4712450dFcf4c89f",
    "acwETH": "0x7151f90076b54961771dfdaaf600e5b8b87cee20",
    "acstS": "0x83e2613b74b2697c85416a9a1fbb043f8056990b",
    "aciUSDC": "0xacd8c3e8fd67142a677b35aabe3f21e3779b58c7",
    "aciscUSD": "0xb1eebda7f7ec7bd53d1f2d12b414129f89f24aaf",
    "aciYT-scUSD": "0xe192d8700fbdc8aae23b5881c3ef55b90de69373",
    "YT-scUSD": "0xd2901D474b351bC6eE7b119f9c920863B0F781b2",
}
POOLS = {"A": "0x0850A9759165B25832E2cAa3dB3f2d04dc583D4E",
         "B": "0x56eb1bcB2aA011517fD7bf32641E79Bd8471770e",
         "C": "0x12144c9b3fdCc1E40083280C3FE28BB568814A91"}
PROVIDERS = {"A": "0x4b139f6E816934D580D9305Ca0f115145f698973",
             "B": "0x282eDE6BbD2d224D454C995e66f08569A5508e9a",
             "C": "0x3BC884500E670e184eF1421a6980455fd3FA3739"}
ACLS = {"A": "0x1637b78Dd5541F0dB2f3d04EeD39De37Df71BD08",
        "B": "0x8f0431F6Adb3e81D282d0508c16e2817DC95095b",
        "C": "0x3f8547e4b349e65853d058bc81b7ffbe3b8f12d4"}
TREASURY = "0x5dc4dd7969944300083994c60e2ce67b4b81457c"
ATTACKER = "0xF321683831Be16eeD74dfA58b02a37483cEC662e"
SAFE = "0xD3E02C92f59a0ba5601464299D658d3a0a7cf96F"
ADMIN = "0x0dd010513F7abB8F9c628dC164a24D953BCA09Cf"
ROLES = {
    "DEFAULT_ADMIN": "0x" + "00" * 32,
    "POOL_ADMIN": "0x12ad05bde78c5ab75238ce885307f96ecd482bb402ef831f99e7018a0f169b7b",
    "EMERGENCY_ADMIN": "0x5c91514091af31f62f596a314af7d5be40146b2f2355969392f055e12e0982fb",
    "RISK_ADMIN": "0x8aa855a911518ecfbe5bc3088c8f3dda7badf130faaf8ace33fdc33828e18167",
    "BRIDGE": "0x08fb31c3e81624356c3314088aa971b73bcc82d22bc3e3b184b4593077ae3278",
    "ASSET_LISTING_ADMIN": "0x19c860a63258efbd0ecb7d55c626237bf5c2044c26c073390b74f0c13c857433",
    "FLASH_BORROWER": "0x939b8dfb57ecef2aea54a93a15e86768b9d4089f1ba61c245e6ec980695f4ca4",
}


def pad_a(a):
    return a[2:].lower().rjust(64, "0")


def main():
    block = int(rpc("eth_blockNumber", []), 16)
    out = {"block": block, "block_hex": hex(block)}
    calls, meta = [], []

    # 1) underlying held by aToken contracts (real liquidity)
    held = {
        "B": [("USDC", "acUSDC"), ("scUSD", "acscUSD"), ("wS", "acwS"), ("WETH", "acwETH"), ("stS", "acstS")],
        "C": [("USDC", "aciUSDC"), ("scUSD", "aciscUSD"), ("YT-scUSD", "aciYT-scUSD")],
    }
    for m, pairs in held.items():
        for asset, atok in pairs:
            calls.append(("eth_call", [{"to": T[asset], "data": "0x70a08231" + pad_a(T[atok])}, hex(block)]))
            meta.append(("held_by_aToken", m, asset, atok))
    # market A aToken-held ac tokens and their own underlyings
    for asset, atok in (("USDC", "aUSDC_A"),):
        pass
    A_TOKENS = {
        "aUSDC_A": "0x64d0071044ef8f98b8e5ecfcb4a6c12cb8bc1ec0",
        "ascUSD_A": "0x9154f0a385eef5d48cef78d9fea19995a92718a9",
        "awS_A": "0x61bc5ce0639aa0a24ab7ea8b574d4b0d6b619833",
        "asiacUSDC": "0x0eee208934e66a6e44517e627a2475fc891b3a38",
        "asiacscUSD": "0x1acd539e2a76cf876889dd8119c1d873821551a1",
        "asiacwS": "0xed01f103c284253d0824c0125f673f11c14d2ea4",
    }
    for asset in ("USDC", "scUSD", "wS"):
        atok = {"USDC": "aUSDC_A", "scUSD": "ascUSD_A", "wS": "awS_A"}[asset]
        calls.append(("eth_call", [{"to": T[asset], "data": "0x70a08231" + pad_a(A_TOKENS[atok])}, hex(block)]))
        meta.append(("held_by_aToken", "A", asset, atok))
    for asset in ("acUSDC", "acscUSD", "acwS"):
        atok = {"acUSDC": "asiacUSDC", "acscUSD": "asiacscUSD", "acwS": "asiacwS"}[asset]
        calls.append(("eth_call", [{"to": T[asset], "data": "0x70a08231" + pad_a(A_TOKENS[atok])}, hex(block)]))
        meta.append(("held_by_aToken", "A", asset, atok))

    # 2) attacker token balances (aTokens + vTokens + underlyings)
    ATK_TOKENS = {
        "acUSDC": "0xEc26D07B5c0a99D3690375A2CC229E5b943e7726",
        "acscUSD": "0xa175EE511de429275d26Ac5420fAbeb60C67C372",
        "acwS": "0x95cAF53667D912F3491173fd4712450dFcf4c89f",
        "acwETH": "0x7151f90076b54961771dfdaaf600e5b8b87cee20",
        "acstS": "0x83e2613b74b2697c85416a9a1fbb043f8056990b",
        "asiacUSDC": "0x0eee208934e66a6e44517e627a2475fc891b3a38",
        "asiacscUSD": "0x1acd539e2a76cf876889dd8119c1d873821551a1",
        "asiacwS": "0xed01f103c284253d0824c0125f673f11c14d2ea4",
        "variableDebtcUSDC": "0xab85e40450683198a6d4865638a7f5e55e5a3fbf",
        "variableDebtcscUSD": "0x2060839b79391e66d2c7e7afe46c8ee4a5c4f627",
        "variableDebtcwS": "0x3822698e0160b38ffacfd91f8a14bc6ea8a4227b",
        "variableDebtcwETH": "0xc0e9224f045d6465d5826a5920f467cfa8690fad",
        "variableDebtcstS": "0xb1296336c2a6e20c0240a21fce0ec3228214a550",
        "variableDebtsiUSDC": "0x5394bf08f963ca6a41447445c0c0a5267b10ee86",
        "variableDebtsiscUSD": "0x099d6e81771e21d4f3d43ae40a71c7e429164753",
        "variableDebtsiwS": "0x5ac446749c76c9450d4a605e9123b372da1bdb9a",
    }
    for name, tok in ATK_TOKENS.items():
        calls.append(("eth_call", [{"to": tok, "data": "0x70a08231" + pad_a(ATTACKER)}, hex(block)]))
        meta.append(("attacker_balance", None, name, tok))
    for name in ("USDC", "scUSD", "wS", "WETH", "stS"):
        calls.append(("eth_call", [{"to": T[name], "data": "0x70a08231" + pad_a(ATTACKER)}, hex(block)]))
        meta.append(("attacker_balance", None, name, name))

    # 3) roles on all ACLs for attacker/admin/safe/zero
    for m, acl in ACLS.items():
        for rname, rh in ROLES.items():
            for sname, s in (("attacker", ATTACKER), ("admin", ADMIN), ("safe", SAFE),
                             ("zero", "0x0000000000000000000000000000000000000000")):
                calls.append(("eth_call", [{"to": acl, "data": "0x91d14854" + rh[2:] + pad_a(s)}, hex(block)]))
                meta.append(("role", m, rname, sname))

    # 4) treasury balances
    for name in ("acUSDC", "acscUSD", "acwS", "acwETH", "acstS", "USDC", "scUSD", "wS"):
        calls.append(("eth_call", [{"to": T[name], "data": "0x70a08231" + pad_a(TREASURY)}, hex(block)]))
        meta.append(("treasury_balance", None, name, name))

    # 5) native balances
    for name, a in (("poolA", POOLS["A"]), ("poolB", POOLS["B"]), ("poolC", POOLS["C"]),
                    ("providerA", PROVIDERS["A"]), ("providerB", PROVIDERS["B"]), ("providerC", PROVIDERS["C"]),
                    ("treasury", TREASURY), ("attacker", ATTACKER), ("safe", SAFE), ("admin", ADMIN)):
        calls.append(("eth_getBalance", [a, hex(block)]))
        meta.append(("native", None, name, a))

    # 6) rescueTokens probe (pool B) from attacker / random / safe
    for who in (ATTACKER, "0x0000000000000000000000000000000000000001", SAFE):
        data = "0xcea9d26f" + pad_a(T["USDC"]) + pad_a(who) + "0" * 64
        calls.append(("eth_call", [{"from": who, "to": POOLS["B"], "data": data}, hex(block)]))
        meta.append(("rescue_probe_B", None, f"from_{who[:10]}", "rescue"))

    results = []
    CH = 60
    for i in range(0, len(calls), CH):
        res = batch(calls[i:i + CH], timeout=180)
        results.extend(res)
        print(f"chunk {i}/{len(calls)}", flush=True)
    out["results"] = []
    for (kind, m, a, b), v in zip(meta, results):
        out["results"].append({"kind": kind, "market": m, "name": a, "addr": b,
                               "value": dec_u(v) if isinstance(v, str) and kind != "rescue_probe_B"
                               else (v if isinstance(v, str) else v)})
    json.dump(out, open(os.path.join(RAW, "final_snapshot.json"), "w"), indent=1)
    # summary print
    for r in out["results"]:
        if r["kind"] == "role":
            if r["value"] is True or (isinstance(r["value"], int) and r["value"] == 1):
                print("ROLE", r["market"], r["name"], "->", r["name"] if False else r["addr"])
        elif r["kind"] == "held_by_aToken" and isinstance(r["value"], int) and r["value"]:
            print("HELD", r["market"], r["name"], r["addr"], r["value"])
        elif r["kind"] == "attacker_balance" and isinstance(r["value"], int) and r["value"]:
            print("ATK", r["name"], r["value"])
        elif r["kind"] == "treasury_balance" and isinstance(r["value"], int) and r["value"]:
            print("TREAS", r["name"], r["value"])
        elif r["kind"] == "native" and isinstance(r["value"], int) and r["value"]:
            print("NATIVE", r["name"], r["value"])
        elif r["kind"] == "rescue_probe_B":
            print("RESCUE", r["name"], r["value"])


if __name__ == "__main__":
    main()
