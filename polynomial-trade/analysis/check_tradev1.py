#!/usr/bin/env python3
"""Check balances of all Polynomial Trade v1 (Optimism) contracts."""
import json, urllib.request, time

OP = "https://mainnet.optimism.io"
TOK = {
    "USDC": "0x7F5c764cBc14f9669B88837ca1490cCa17c31607",
    "WETH": "0x4200000000000000000000000000000000000006",
    "sUSD": "0x8c6f28f2F1A3C87F0f938b96d27520d9751ec8d9",
    "OP":   "0x4200000000000000000000000000000000000042",
    "USDT": "0x94b008aA00579c1307B0EF2c499aD98a8ce58e58",
}
ADDRS = {
    "Index": "0xb43c0899ECCf98BC7A0f3e2c2A211d6fc4f9b3fE",
    "AuthConnector": "0xe8F2A6B6cA9d6C342171a521bF9e22F20Ed398a8",
    "BasicConnector": "0xD34F4FAE4d5eA96f15CB26AF0e45a90EAbcd7b47",
    "SynthetixPerp-v1": "0x1Df92B3Ac9AeD27115Ae4127ed098BaEc1BD8b26",
    "SynthetixPerp-v1.2": "0x193209391242B585aE0aA6029DDD23f9eF99b779",
    "SynthetixPerp-v1.3": "0x1EdE41B8D5ff5E8CB2B143F47AaA1Fd541eaB17f",
    "SynthetixPerp-v1.4": "0x2302c92E0711Adc66C7a774a9F8aB4A0aCeDe5D3",
    "Kwenta-v1.1": "0xAA9EeC57296D00347B8A0A786aeF2D8A81d2e01C",
    "SynthetixSpot-v1": "0xee3DD0adaCE9b29b56F7176e6190C2E7bfE54594",
    "1inch-v5": "0xaDe850Bf6de778a207DC44E610fE7A45272FECE9",
    "LimitOrder-v1": "0x1c5BCD2839088D995902623E9Ed711080F23464b",
    "LimitOrder-v1.1": "0xA7a031f285187f2F8415A513a5Fc0AbD101a8775",
    "BasisTrading-v1": "0x1036c75bA376354D455B5D98E8d847c68a1B4bfe",
    "AdvancedOrders-v1": "0xEe7Ae6C285D169D09B7248572388174762b8Aafc",
    "Matcha-v1": "0xa4965dC079a6891C6F26fCd723991357d839c2d9",
    "Aave-v3-v1": "0x558c403A907D3B010C10e9aFCcF652A0B0D09338",
    "Resolver-Accounts": "0x4a0B3986cb7e23df85A64100BF222Cf69F9787Aa",
    "SynthetixPerp-proxy": "0x50fF859DE6bc8E71aCc1Dd73E5C4d15B46d04E63",
    "Boomerang": "0x1BAA02FD3744b299723f2e3ad2b7C241Bea1afA5",
    "DragonFruit": "0xfFb60DB01EcAccaf30517664F90936F3147Ba8F6",
    "BellPepper": "0x6457f43CAa86008c595b037061788068bFD5e58d",
    "Auto-BasisTrading": "0x3349de7822aa05f857e92d167B264809419DC620",
    "Auto-LimitOrders": "0xc1F7a43Db81e7DC4b3F4C6C2AcdCBdC17C41b0Dc",
    "Auto-AdvancedOrders": "0x7634E43aA3f446C8d9D5014d609355F728361075",
    "Emitter": "0x0Be3A0E2944b1C43799E2d447d1367A397c4F573",
    "GasEstimater": "0x50e6B62979Fd23FB59F542065a2cAc5Cd6499527",
    "Storage": "0x9f4e24e48D1Cd41FA87A481Ae2242372Bd32618C",
    "List": "0xd567E18FDF8aFa58953DD8B0c1b6C97adF67566B",
}

def enc(a):
    return a.lower().replace("0x", "").rjust(64, "0")

def rpc_batch(calls):
    payload = []
    for i, (m, p) in enumerate(calls):
        payload.append({"jsonrpc": "2.0", "id": i, "method": m, "params": p})
    body = json.dumps(payload).encode()
    for attempt in range(4):
        try:
            req = urllib.request.Request(OP, data=body, headers={"Content-Type": "application/json"})
            with urllib.request.urlopen(req, timeout=90) as resp:
                d = json.loads(resp.read())
            out = [None] * len(calls)
            for it in d:
                out[it["id"]] = it.get("result")
            return out
        except Exception as e:
            time.sleep(2)
    return [None] * len(calls)

print(f"{'name':22s} {'ETH':>18s} {'USDC':>14s} {'WETH':>18s} {'sUSD':>20s} {'OP':>18s} {'USDT':>14s}")
for name, a in ADDRS.items():
    calls = [("eth_getBalance", [a, "latest"])]
    for t in TOK.values():
        calls.append(("eth_call", [{"to": t, "data": "0x70a08231" + enc(a)}, "latest"]))
    # batch 7 calls is fine
    res = rpc_batch(calls)
    try:
        eth = int(res[0] or "0x0", 16)
    except Exception:
        eth = -1
    vals = []
    for i in range(len(TOK)):
        try:
            vals.append(int(res[1+i] or "0x0", 16))
        except Exception:
            vals.append(-1)
    if any(v > 0 for v in vals) or eth > 0:
        print(f"{name:22s} {eth:18d} " + " ".join(f"{v:>14d}" for v in vals))
    time.sleep(0.1)
print("done")
