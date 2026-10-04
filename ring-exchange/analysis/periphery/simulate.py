#!/usr/bin/env python3
# Read-only eth_call simulations (eth_call via cast; NO transactions sent).
import subprocess, json
from eth_abi import encode as abi_encode
from eth_utils import keccak

RPC = "https://rpc.hyperliquid.xyz/evm"
UR = "0xE65081EFa5ad4A196B1Df768716c337e6AB140E9"
FEWE = "0x068B60ECbC934b0a0dde20FdFf0dE925b97B971F"
ROUTER = "0x701D1d675415efA2d2429fB122ccC6dD4FCcA959"
FACTORY = "0x6B65ed7315274eB9EF06A48132EB04D808700b86"
FWWETH = "0x9e1148bC3665a9f7C35F313d89c0432c34928AEf"
FWUETH = "0x0C47cbbEDE5d8c6f9614cF770C26c3315205C397"
WHYPE = "0x5555555555555555555555555555555555555555"
UETH = "0xBe6727B535545C67d5cAa73dEa54865B92CF7907"
ATTACKER = "0x00000000000000000000000000000000DeaDBeef"
ATTACKER2 = "0x1111111111111111111111111111111111111111"  # random unrelated EOA (no balances)
MAX = 2**256 - 1
CONTRACT_BALANCE = 1 << 255
ETH = "0x0000000000000000000000000000000000000000"

def exec_calldata(cmds: bytes, inputs: list[bytes], deadline=2**32-1):
    return bytes.fromhex("3593564c") + abi_encode(["bytes", "bytes[]", "uint256"], [cmds, inputs, deadline])

def cast_call(to, data, frm=ATTACKER):
    if isinstance(data, (bytes, bytearray)):
        data = "0x" + bytes(data).hex()
    p = subprocess.run(["cast", "call", to, data, "--from", frm, "--rpc-url", RPC],
                       capture_output=True, text=True)
    out = (p.stdout.strip() or p.stderr.strip()).replace("\n", " ")
    return ("OK  " if p.returncode == 0 else "ERR ") + out[:160]

results = []
def add(name, desc, to, data, frm=ATTACKER):
    r = cast_call(to, data, frm)
    results.append({"case": name, "desc": desc, "to": to, "from": frm, "call": data.hex() if isinstance(data, bytes) else data, "result": r})
    print(f"{name:44s} {r}")

# A) SWEEP WHYPE min=0 -> no-op success (0 balance)
add("A_SWEEP_WHYPE_min0", "SWEEP router's WHYPE balance (0) to attacker, min 0", UR, exec_calldata(bytes([0x04]), [abi_encode(["(address,address,uint256)"], [(WHYPE, ATTACKER, 0)])]))
# B) SWEEP WHYPE min=1 -> revert InsufficientToken
add("B_SWEEP_WHYPE_min1", "same but amountMinimum=1 must revert", UR, exec_calldata(bytes([0x04]), [abi_encode(["(address,address,uint256)"], [(WHYPE, ATTACKER, 1)])]))
# C) SWEEP native min=0
add("C_SWEEP_ETH_min0", "SWEEP router native (0) to attacker", UR, exec_calldata(bytes([0x04]), [abi_encode(["(address,address,uint256)"], [(ETH, ATTACKER, 0)])]))
# D) WRAP_FEW_TOKEN WHYPE amount=1 -> revert InsufficientToken
add("D_WRAPFEW_1", "wrap 1 wei router WHYPE (balance 0)", UR, exec_calldata(bytes([0x27]), [abi_encode(["(address,address,uint256)"], [(WHYPE, ATTACKER, 1)])]))
# E) WRAP_FEW_TOKEN WHYPE amount=CONTRACT_BALANCE -> no-op success
add("E_WRAPFEW_MAX", "wrap CONTRACT_BALANCE (resolves to 0)", UR, exec_calldata(bytes([0x27]), [abi_encode(["(address,address,uint256)"], [(WHYPE, ATTACKER, CONTRACT_BALANCE)])]))
# F) UNWRAP_FEW_TOKEN fwWHYPE -> no-op success
add("F_UNWRAPFEW_FWW", "unwrap router fwWHYPE balance (0)", UR, exec_calldata(bytes([0x28]), [abi_encode(["(address,address,uint256)"], [(FWWETH, ATTACKER, 0)])]))
# G) PERMIT2_TRANSFER_FROM: attacker as caller, from=attacker (msgSender)
add("G_P2TF_SELF", "PERMIT2_TRANSFER_FROM from=msgSender (self, no allowance)", UR, exec_calldata(bytes([0x02]), [abi_encode(["(address,address,uint160)"], [(WHYPE, ATTACKER, 1)])]))
# H) PERMIT2_TRANSFER_FROM_BATCH with forged from=other -> expect FromAddressIsNotOwner
batch = [(ATTACKER2, ATTACKER, 1, WHYPE)]  # (from, to, amount, token)
batch_elem = abi_encode(["(address,address,uint160,address)"], batch)
batch_raw = abi_encode(["uint256"], [1]) + batch_elem  # packed length + structs as Dispatcher expects
add("H_P2BATCH_FORGED", "PERMIT2_TRANSFER_FROM_BATCH forged from!=msgSender", UR,
    exec_calldata(bytes([0x0d]), [batch_raw]))
# I) FewETHWrapper.unwrapFWWETHToETH(1, attacker) from bare EOA
add("I_FEWE_UNWRAP", "FewETHWrapper.unwrapFWWETHToETH(1) without fw balance", FEWE, "0x" + abi_encode(["uint256", "address"], [1, ATTACKER]).hex())
# J) FewETHWrapper.wrapETHToFWWETH via eth_call with 0 value
add("J_FEWE_WRAP0", "FewETHWrapper.wrapETHToFWWETH value=0", FEWE, "0x" + abi_encode(["address"], [ATTACKER]).hex())
# K) Ring SwapV2Router swapExactTokensForTokens without tokens
path = [FWWETH, FWUETH]
add("K_ROUTER_SWAP_NOFUNDS", "SwapV2Router.swapExactTokensForTokens no fw balance", ROUTER,
    "0x" + abi_encode(["uint256", "uint256", "address[]", "address", "uint256"], [1, 0, path, ATTACKER, 2**32-1]).hex())
# L) FewFactory.createToken(WHYPE) already exists -> revert
add("L_FACTORY_CREATE_DUP", "FewFactory.createToken(existing WHYPE)", FACTORY, "0x" + abi_encode(["address"], [WHYPE]).hex())
# M) command 0x23 FEW_V2_SWAP_EXACT_IN from bare EOA (no permit2/funds)
add("M_FEWV2_NOFUNDS", "FEW_V2_SWAP_EXACT_IN payerIsUser=true no allowance", UR,
    exec_calldata(bytes([0x23]), [abi_encode(["(address,uint256,uint256,address[],bool)"], [(ATTACKER, 1, 0, path, True)])]))
# N) command 0x23 with payerIsUser=false (router balance 0)
add("N_FEWV2_ROUTERBAL", "FEW_V2_SWAP_EXACT_IN payerIsUser=false (router 0)", UR,
    exec_calldata(bytes([0x23]), [abi_encode(["(address,uint256,uint256,address[],bool)"], [(ATTACKER, 1, 0, path, False)])]))

json.dump(results, open("sim_results.json", "w"), indent=1)
print("\nsaved sim_results.json")
