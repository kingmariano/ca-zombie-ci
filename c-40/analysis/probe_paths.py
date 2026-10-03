#!/usr/bin/env python3
"""Probe market entrypoints via starknet_call (read-only simulation, caller=0).
Interpretation: if a call reverts with a pause error before any balance/auth error, the path is pause-gated."""
import sys, json; sys.path.insert(0, '.')
from sn import call, sn_keccak

CM = "0x073f6addc9339de9822cab4dac8c9431779c09077f02ba7bc36904ea342dd9eb"
NSTR_IB = "0x2589fc11f60f21af6a1dda3aeb7a44305c552928af122f2834d1c3b1a7aa626"
NSTR_DEBT = "0x3e0576565c1b51fcac3b402eb002447f21e97abb5da7011c0a2e0b465136814"
NSTR_NOSTRA = "0x2b674ffda238279de5550d6f996bf717228d316555f07a77ef0a082d925b782"
USDC_IB = "0x002fc2d4b41cc1f03d185e6681cbd40cced61915d4891517a042658d61cba3b1"
USDC_DEBT = "0x063d69ae657bd2f40337c39bf35a870ac27ddf91e6623c2f52529db4c1619a51"

def show(label, r):
    if "result" in r:
        print(f"{label}: OK result={r['result']}")
    else:
        e = r.get("error", {})
        data = e.get("data", {})
        rev = data.get("revert_error", "") if isinstance(data, dict) else str(data)
        msg = ""
        try:
            b = bytes.fromhex(rev[2:])
            msg = b.decode('ascii', 'replace')
        except Exception:
            pass
        print(f"{label}: REVERT {e.get('message')} {rev} | {msg}")

RAND = 0x1234567890abcdef1234567890abcdef12345678
AMT = 1000  # u256 low, high

print("--- CDP manager liquidate (paused check?) ---")
# liquidate(user, debt_tokens_transfer: Span<TokenTransferItem>, collateral_tokens_transfer: Span<TokenTransferItem>)
# calldata: user, span_len_debt, (token, amount_low, amount_high)..., span_len_coll, ...
show("liquidate(rnd, [], [])", call(CM, "liquidate", [hex(RAND), "0x0", "0x0"]))

print("--- supply side ---")
show("NSTR_IB.deposit(rnd, 1000)", call(NSTR_IB, "deposit", [hex(RAND), hex(AMT), "0x0"]))
show("NSTR_IB.withdraw(rnd, rnd, 1000)", call(NSTR_IB, "withdraw", [hex(RAND), hex(RAND), hex(AMT), "0x0"]))
show("NSTR_NOSTRA.deposit(rnd, 1000)", call(NSTR_NOSTRA, "deposit", [hex(RAND), hex(AMT), "0x0"]))
show("NSTR_NOSTRA.withdraw(rnd, rnd, 1000)", call(NSTR_NOSTRA, "withdraw", [hex(RAND), hex(RAND), hex(AMT), "0x0"]))
show("USDC_IB.deposit(rnd, 1000)", call(USDC_IB, "deposit", [hex(RAND), hex(AMT), "0x0"]))
show("USDC_IB.withdraw(rnd, rnd, 1000)", call(USDC_IB, "withdraw", [hex(RAND), hex(RAND), hex(AMT), "0x0"]))

print("--- debt side ---")
show("NSTR_DEBT.borrow(rnd, 1000)", call(NSTR_DEBT, "borrow", [hex(RAND), hex(AMT), "0x0"]))
show("NSTR_DEBT.repay(rnd, 1000)", call(NSTR_DEBT, "repay", [hex(RAND), hex(AMT), "0x0"]))
show("USDC_DEBT.borrow(rnd, 1000)", call(USDC_DEBT, "borrow", [hex(RAND), hex(AMT), "0x0"]))
show("USDC_DEBT.repay(rnd, 1000)", call(USDC_DEBT, "repay", [hex(RAND), hex(AMT), "0x0"]))

print("--- admin-ish / misc ---")
show("CM.pause()", call(CM, "pause"))
show("CM.unpause()", call(CM, "unpause"))
show("CM.grant_role(0, rnd)", call(CM, "grant_role", ["0x0", hex(RAND)]))
show("CM.upgrade(0x1)", call(CM, "upgrade", ["0x1"]))
show("NSTR_IB.mint(rnd,1000)", call(NSTR_IB, "mint", [hex(RAND), hex(AMT), "0x0"]))
show("NSTR_IB.burn(rnd,rnd,1000)", call(NSTR_IB, "burn", [hex(RAND), hex(RAND), hex(AMT), "0x0"]))
show("NSTR_DEBT.mint(rnd,1000)", call(NSTR_DEBT, "mint", [hex(RAND), hex(AMT), "0x0"]))
show("NSTR_DEBT.burn(rnd,1000)", call(NSTR_DEBT, "burn", [hex(RAND), hex(AMT), "0x0"]))
