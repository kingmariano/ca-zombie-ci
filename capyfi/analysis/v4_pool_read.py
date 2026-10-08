#!/usr/bin/env python3
"""Read-only Uniswap v4 pool state via StateView on Ethereum mainnet."""
import json, sys, math
from web3 import Web3

RPC = "https://ethereum-rpc.publicnode.com"
STATE_VIEW = Web3.to_checksum_address("0x7fFE42C4a5DEeA5b0feC41C94C136Cf115597227")
w3 = Web3(Web3.HTTPProvider(RPC, request_kwargs={"timeout": 60}))
print("connected:", w3.is_connected(), "block:", w3.eth.block_number, file=sys.stderr)
print("stateview code len:", len(w3.eth.get_code(STATE_VIEW).hex()), file=sys.stderr)

ABI = [
    {"name":"getSlot0","outputs":[{"type":"uint160"},{"type":"int24"},{"type":"uint24"},{"type":"uint24"}],
     "inputs":[{"name":"poolId","type":"bytes32"}],"stateMutability":"view","type":"function"},
    {"name":"getLiquidity","outputs":[{"type":"uint128"}],
     "inputs":[{"name":"poolId","type":"bytes32"}],"stateMutability":"view","type":"function"},
]
sv = w3.eth.contract(address=STATE_VIEW, abi=ABI)

POOLS = {
    # name: (pool_id, currency0_addr, currency0_dec, currency1_addr, currency1_dec)
    "LAC/USDC_1pct": ("0xa8f7d3148be7c6e66462f7d5da7843c94d974e0697e1768fb9c8b695f986a45b",
                      "0x0Df3a853e4B604fC2ac0881E9Dc92db27fF7f51b", 18,
                      "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48", 6),
    "LAC/ETH_0.3pct": ("0x1047f84bc973cee6e784ac3e60438354b52f8eb0f13011a48c6fa8f8720e5844",
                       "0x0Df3a853e4B604fC2ac0881E9Dc92db27fF7f51b", 18,
                       "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2", 18),
    "RPC/USDC_0.3pct": ("0xd8442c1d563ba9b7dc1bba16430f6f999c0f8dd26914ca757d43ce88d416ebc7",
                        "0xEd025A9Fe4b30bcd68460BCA42583090c2266468", 18,
                        "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48", 6),
    "RPC/USDT_5.9pct": ("0x06d8bb83012a55c023fded213c879171f897fe29677c42aaa5a435f1b970ced3",
                        "0xEd025A9Fe4b30bcd68460BCA42583090c2266468", 18,
                        "0xdAC17F958D2ee523a2206206994597C13D831ec7", 6),
    "RPC/ETH_0.3pct": ("0x68473b6d89b8b2fbdb90da870c15805f13dcb0202b70cfc7f2f6d602a88c3bd1",
                       "0xEd025A9Fe4b30bcd68460BCA42583090c2266468", 18,
                       "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2", 18),
}
# fix currency ordering: v4 sorts by address ascending
out = {}
for name, (pid, a0, d0, a1, d1) in POOLS.items():
    a0c, a1c = Web3.to_checksum_address(a0), Web3.to_checksum_address(a1)
    if int(a0c, 16) < int(a1c, 16):
        c0, dec0, c1, dec1 = a0c, d0, a1c, d1
    else:
        c0, dec0, c1, dec1 = a1c, d1, a0c, d0
    rec = {"pool_id": pid, "currency0": c0, "dec0": dec0, "currency1": c1, "dec1": dec1}
    try:
        s0 = sv.functions.getSlot0(bytes.fromhex(pid[2:])).call()
        liq = sv.functions.getLiquidity(bytes.fromhex(pid[2:])).call()
        sqrtP = s0[0]
        rec.update({"sqrtPriceX96": str(sqrtP), "tick": s0[1], "protocolFee": s0[2], "lpFee": s0[3],
                    "liquidity": str(liq)})
        if sqrtP > 0:
            p_raw = (sqrtP / 2**96) ** 2  # currency1 raw units per currency0 raw unit
            rec["price_c1_per_c0_raw"] = p_raw
            rec["human_price_c1_per_c0"] = p_raw * 10 ** (dec0 - dec1)
            L = float(liq)
            x_virt = L / (sqrtP / 2**96)   # currency0 virtual reserve (raw)
            y_virt = L * (sqrtP / 2**96)   # currency1 virtual reserve (raw)
            rec["virt_reserve_c0_human"] = x_virt / 10**dec0
            rec["virt_reserve_c1_human"] = y_virt / 10**dec1
    except Exception as e:
        rec["error"] = str(e)[:200]
    out[name] = rec
print(json.dumps(out, indent=1, default=str))
