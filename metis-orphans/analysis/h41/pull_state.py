#!/usr/bin/env python3
"""Pull full reserve/oracle/holder/borrower state at pinned block 23238719 (read-only)."""
import json, sys, time
import requests
from eth_abi import decode as abi_decode
from rpc import rpc_batch, call, enc_addr, selector

BLOCK = hex(23238719)
POOL = "0x90df02551bB792286e8D4f13E0e357b4Bf1D6a57"
ATOKEN = "0x7314Ef2CA509490f65F52CC8FC9E0675C66390b8"
VDEBT = "0x0110174183e13D5Ea59D7512226c5D5A47bA2c40"
ORACLE = "0x38D36e85E47eA6ff0d18B0adF12E5fC8984A6f8e"
RESERVES = {
    "mDAI":  "0x4c078361FC9BbB78DF910800A991C7c3DD2F6ce0",
    "METIS": "0xDeadDeAddeAddEAddeadDEaDDEAdDeaDDeAD0000",
    "mUSDC": "0xEA32A96608495e54156Ae48931A7c20f0dcc1a21",
    "mUSDT": "0xbB06DCA3AE6887fAbF931640f67cab3e3a16F4dC",
    "WETH":  "0x420000000000000000000000000000000000000A",
}
ATOKENS = {
    "mDAI":  "0x85ABAdDcae06efee2CB5F75f33b6471759eFDE24",
    "METIS": ATOKEN,
    "mUSDC": "0x885C8AEC5867571582545F894A5906971dB9bf27",
    "mUSDT": "0xd9fa75D14c26720d5ce7eE2530793a823e8f07b9",
    "WETH":  "0x8acAe35059C9aE27709028fF6689386a44c09f3a",
}
VDEBTS = {
    "mDAI":  "0x13Bd89aF338f3c7eAE9a75852fC2F1ca28B4DDbF",
    "METIS": VDEBT,
    "mUSDC": "0x571171a7EF1e3c8c83d47EF1a50E225E9c351380",
    "mUSDT": "0x6B45DcE8aF4fE5Ab3bFCF030d8fB57718eAB54e5",
    "WETH":  "0x8Bb19e3DD277a73D4A95EE434F14cE4B92898421",
}
SDEBT = "0xf1cd706E177F3AEa620c722Dc436B5a2066E4C68"

out = {"block": 23238719}

def save():
    json.dump(out, open("raw/state_pull.json", "w"), indent=1)

# ---------- 1. reserve state ----------
reserve_state = {}
for name, asset in RESERVES.items():
    calls = [
        call(ATOKENS[name], "totalSupply()"),
        call(ATOKENS[name], "balanceOf(address)", enc_addr(POOL)),
        call(VDEBTS[name], "totalSupply()"),
        call(VDEBTS[name], "balanceOf(address)", enc_addr(POOL)),
        call(SDEBT, "totalSupply()"),
        call(asset, "decimals()"),
        call(asset, "balanceOf(address)", enc_addr(ATOKENS[name])),
    ]
    r = rpc_batch(calls)
    reserve_state[name] = {
        "asset": asset, "aToken": ATOKENS[name], "vDebt": VDEBTS[name],
        "aToken_totalSupply": int(r[0], 16) if r[0] and r[0] != "0x" else None,
        "aToken_bal_pool": int(r[1], 16) if r[1] and r[1] != "0x" else None,
        "vDebt_totalSupply": int(r[2], 16) if r[2] and r[2] != "0x" else None,
        "vDebt_bal_pool": int(r[3], 16) if r[3] and r[3] != "0x" else None,
        "sDebt_totalSupply": int(r[4], 16) if r[4] and r[4] != "0x" else None,
        "decimals": int(r[5], 16) if r[5] and r[5] != "0x" else None,
        "underlying_bal_atoken": int(r[6], 16) if r[6] and r[6] != "0x" else None,
    }
    print("reserve", name, reserve_state[name])
out["reserve_state"] = reserve_state
save()

# ---------- 2. oracle ----------
calls = [call(ORACLE, "BASE_CURRENCY()"), call(ORACLE, "BASE_CURRENCY_UNIT()")]
for name, asset in RESERVES.items():
    calls.append(call(ORACLE, "getAssetPrice(address)", enc_addr(asset)))
    calls.append(call(ORACLE, "getSourceOfAsset(address)", enc_addr(asset)))
r = rpc_batch(calls)
oracle = {
    "base_currency": int(r[0], 16) if r[0] and r[0] != "0x" else None,
    "base_currency_unit": int(r[1], 16) if r[1] and r[1] != "0x" else None,
    "prices": {}, "sources": {},
}
i = 2
for name in RESERVES:
    p = r[i]; s = r[i+1]; i += 2
    oracle["prices"][name] = int(p, 16) if p and p != "0x" else None
    oracle["sources"][name] = "0x" + s[-40:] if s and s != "0x" else None
out["oracle"] = oracle
print("oracle", oracle)
save()

# ---------- 3. pool misc ----------
calls = [
    call(POOL, "FLASHLOAN_PREMIUM_TOTAL()"),
    call(POOL, "MAX_STABLE_RATE_BORROW_SIZE_PERCENT()"),
    call(POOL, "BRIDGE_PROTOCOL_FEE()"),
]
r = rpc_batch(calls)
out["pool_misc"] = {
    "flashloan_premium_total": int(r[0], 16) if r[0] and r[0] != "0x" else None,
    "max_stable_rate_borrow_size_pct": int(r[1], 16) if r[1] and r[1] != "0x" else None,
    "bridge_protocol_fee": int(r[2], 16) if r[2] and r[2] != "0x" else None,
}
print("pool_misc", out["pool_misc"])
save()

# ---------- 4. verify all aToken holders on-chain ----------
holders = json.load(open("raw/holders_atoken_full.json"))["items"]
addrs = [it["address"]["hash"] for it in holders]
calls = [call(ATOKEN, "balanceOf(address)", enc_addr(a)) for a in addrs]
bal = rpc_batch(calls, batch_size=120)
verified = []
for a, b in zip(addrs, bal):
    verified.append((a, int(b, 16) if b and b != "0x" else None))
tot = sum(v for _, v in verified if v is not None)
nonzero = sum(1 for _, v in verified if v)
out["atoken_holders_verified"] = {
    "list_size": len(verified),
    "onchain_sum": str(tot),
    "nonzero": nonzero,
    "zero": len(verified) - nonzero,
    "top": [{"addr": a, "balance": str(v), "bs_is_contract": next(it["address"].get("is_contract") for it in holders if it["address"]["hash"] == a)}
            for a, v in verified[:30]],
}
print("atoken holders verified:", out["atoken_holders_verified"]["list_size"], "nonzero", nonzero, "sum", tot/1e18)
save()

# ---------- 5. vDebt holders on-chain + account data ----------
vd_holders = json.load(open("raw/holders_vdebt_full.json"))["items"]
vaddrs = [it["address"]["hash"] for it in vd_holders]
calls = [call(VDEBT, "balanceOf(address)", enc_addr(a)) for a in vaddrs]
vb = rpc_batch(calls, batch_size=120)
borrowers = []
for a, b in zip(vaddrs, vb):
    borrowers.append({"addr": a, "vdebt": int(b, 16) if b and b != "0x" else None})
tot_v = sum(x["vdebt"] for x in borrowers if x["vdebt"])
print("vdebt holders:", len(borrowers), "onchain sum", tot_v/1e18)
save()

# account data for each borrower
calls = [call(POOL, "getUserAccountData(address)", enc_addr(x["addr"])) for x in borrowers]
ad = rpc_batch(calls, batch_size=60)
for x, r1 in zip(borrowers, ad):
    if r1 and r1 != "0x":
        vals = abi_decode(["uint256"]*6, bytes.fromhex(r1[2:] if r1.startswith("0x") else r1))
        x["account"] = {
            "totalCollateralBase": str(vals[0]), "totalDebtBase": str(vals[1]),
            "availableBorrowsBase": str(vals[2]), "currentLiquidationThreshold": str(vals[3]),
            "ltv": str(vals[4]), "healthFactor": str(vals[5]),
        }
    else:
        x["account"] = None
out["borrowers"] = borrowers
for x in borrowers[:10]:
    print("borrower", x["addr"], x["vdebt"]/1e18 if x["vdebt"] else None, x["account"])
save()

# METIS user reserve data for each borrower
calls = [call(POOL, "getUserReserveData(address,address)", enc_addr(RESERVES["METIS"]) + enc_addr(x["addr"])) for x in borrowers]
ur = rpc_batch(calls, batch_size=60)
for x, r1 in zip(borrowers, ur):
    if r1 and r1 != "0x":
        vals = abi_decode(["uint256"]*8 + ["uint40", "bool"], bytes.fromhex(r1[2:]))
        x["metis_user"] = {
            "currentATokenBalance": str(vals[0]), "currentStableDebt": str(vals[1]),
            "currentVariableDebt": str(vals[2]), "scaledVariableDebt": str(vals[4]),
            "usageAsCollateral": vals[9],
        }
    else:
        x["metis_user"] = None
out["borrowers"] = borrowers
save()
print("done")
