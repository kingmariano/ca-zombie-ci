"""Check balances of common Starknet tokens held by the mySwapLegacy contract + admin gate probe."""
from starknet_lib import rpc, call, call_sel, sel, norm, block_number, u256, hexint

LEGACY = 0x010884171baf1914edc28d7afb619b40a4051cfae78a094a55d230f19e944a28

TOKENS = {
    "ETH":  "0x049d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7",
    "USDC": "0x053c91253bc9682c04929ca02ed00b3e423f6710d2ee7e0d5ebb06f3ecf368a8",
    "USDT": "0x068f5c6a61780768455de69077e07e89787839bf8166decfbf92b645209c0fb8",
    "DAI":  "0x00da114221cb83fa859dbdb4c44beeaa0bb37c7537ad5ae66fe5e0efd20e6eb3",
    "WBTC": "0x03fe2b97c1fd336e750087d68b9b867997fd64a2661ff3ca5a7c771641e8e7ac",
    "STRK": "0x04718f5a0fc34cc1af16a1cdee98ffb20c31f5cd61d6ab07201858f4287c938d",
    "wstETH": "0x042b8f0484674ca266ac5d08e4ac6a3fe65bd3129795def2dca5c34ecc5f96d2",
    "LORDS": "0x0124aeb495b947201f5fac96fd1138e326ad86195b98df6dec9009158a533b49",
    "UNI": "0x070a76fd48ca0ef910631754d77dd822147fe98a569b826ec85e3fc3c13330",
}

bn = block_number()
print("block", bn)
for name, t in TOKENS.items():
    try:
        r = call(t, "balanceOf", [LEGACY])
        bal = u256(r)
        print(f"{name:7s} {bal} raw")
    except Exception as e:
        print(f"{name:7s} ERR {e}")

print()
print("assert_admin from zero caller:")
try:
    r = call(LEGACY, "assert_admin")
    print("  returned", r)
except Exception as e:
    print("  reverted:", str(e)[:200])
