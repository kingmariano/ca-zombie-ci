#!/usr/bin/env python3
"""Build Sui programmable-transaction JSON files (proto3 JSON, sui.rpc.v2.Transaction)
for the BlueMove reserve-desync simulation PoC. Read-only: these JSON files are only
fed to GraphQL simulateTransaction.

Format notes (verified against live chain txs + endpoint):
- "inputs": repeated Input. Pure values MUST be declared here:
    {"kind":"PURE","pure":"<base64 BCS>"}
    {"kind":"SHARED","objectId":"0x..","version":"<initialSharedVersion>","mutability":"MUTABLE","mutable":true}
- command arguments:
    {"kind":"INPUT","input":N} | {"kind":"GAS"} | {"kind":"RESULT","result":N} |
    {"kind":"RESULT","result":N,"subresult":j}   # j-th value of a multi-return command
- Each command that returns values yields ONE result slot (global counter). Multi-value
  returns are accessed via subresult (proved by a live mainnet tx).
Output: evidence/*.tx.json
"""
import base64
import json
import pathlib

EVID = pathlib.Path(__file__).resolve().parent.parent / "evidence"
EVID.mkdir(parents=True, exist_ok=True)

# ---------------------------------------------------------------- constants
SENDER = "0x0feb54a725aa357ff2f5bc6bb023c05b310285bd861275a30521f339a434ebb3"
DEX_INFO = "0x3f2d9f724f4a1ce5e71676448dc452be9a6243dac9c5b975a588c8c867066e92"
DEX_INFO_INITIAL_SHARED_VERSION = 1587827

SUI = "0x0000000000000000000000000000000000000000000000000000000000000002"
PAULY = "0xe7131700f8b336a011ff2d0e3403eb719ae9d5c15fc71bf371e4990eccf013a7"
V1 = "0xb24b6789e088b876afabca733bed2299fbc9e2d6369be4d1acfa17d8145454d9"
VMID = "0x08cd33481587d4c4612865b164796d937df13747d8c763b8a178c87e3244498f"
VLATEST = "0x35f3190a41b98da22c997c9266143523816d73a902123dde6f60fac2e0f656d7"

SUI_T = f"{SUI}::sui::SUI"
PAULY_T = f"{PAULY}::pauly::PAULY"
LSP_T = f"{V1}::swap::LSP<{SUI_T},{PAULY_T}>"

MIST = 1


# ---------------------------------------------------------------- encoding helpers
def b64(b: bytes) -> str:
    return base64.b64encode(b).decode()


def in_gas() -> dict:
    return {"kind": "GAS"}


def in_result(i: int, sub: int = None) -> dict:
    a = {"kind": "RESULT", "result": i}
    if sub is not None:
        a["subresult"] = sub
    return a


def in_input(i: int) -> dict:
    return {"kind": "INPUT", "input": i}


# ---------------------------------------------------------------- tx builder
class B:
    def __init__(self):
        self.inputs = [{
            "kind": "SHARED",
            "objectId": DEX_INFO,
            "version": str(DEX_INFO_INITIAL_SHARED_VERSION),
            "mutable": True,
            "mutability": "MUTABLE",
        }]
        self.commands = []

    def u64(self, v: int) -> dict:
        self.inputs.append({"kind": "PURE", "pure": b64(v.to_bytes(8, "little"))})
        return in_input(len(self.inputs) - 1)

    def address(self, a: str) -> dict:
        h = a[2:] if a.startswith("0x") else a
        self.inputs.append({"kind": "PURE", "pure": b64(bytes.fromhex(h.rjust(64, "0")))})
        return in_input(len(self.inputs) - 1)

    def split(self, amounts, coin=None) -> None:
        self.commands.append({"splitCoins": {
            "coin": coin or in_gas(),
            "amounts": [self.u64(a) for a in amounts],
        }})

    def move(self, pkg, module, function, targs, args) -> None:
        self.commands.append({"moveCall": {
            "package": pkg, "module": module, "function": function,
            "typeArguments": targs, "arguments": args,
        }})

    def transfer(self, objs, sender_addr_input) -> None:
        self.commands.append({"transferObjects": {
            "objects": objs, "address": sender_addr_input,
        }})

    def build(self) -> dict:
        return {
            "sender": SENDER,
            "kind": {
                "kind": "PROGRAMMABLE_TRANSACTION",
                "programmableTransaction": {
                    "inputs": self.inputs,
                    "commands": self.commands,
                },
            },
        }


def write(name, obj):
    p = EVID / f"{name}.tx.json"
    p.write_text(json.dumps(obj, indent=1))
    print("wrote", p)


# ---------------------------------------------------------------- test cases
# T1: V1 router::swap_exact_input (entry). (already executed -> balance::split abort)
b = B()
amt = b.u64(1 * MIST)
b.split([1 * MIST])
b.move(V1, "router", "swap_exact_input", [SUI_T, PAULY_T],
       [amt, in_result(0), b.u64(0), in_input(0)])
write("t1_v1_swap_only", b.build())

# T2: VMID router::swap_exact_input_ (vmid gate aborts)
b = B()
sender = b.address(SENDER)
amt = b.u64(10_000 * MIST)
b.split([10_000 * MIST])
b.move(VMID, "router", "swap_exact_input_", [SUI_T, PAULY_T],
       [amt, in_result(0), b.u64(0), in_input(0)])
b.transfer([in_result(1)], sender)
write("t2_vmid_swap_only", b.build())

# T3: VLATEST router::swap_exact_input_ (vlatest gate aborts)
b = B()
sender = b.address(SENDER)
amt = b.u64(10_000 * MIST)
b.split([10_000 * MIST])
b.move(VLATEST, "router", "swap_exact_input_", [SUI_T, PAULY_T],
       [amt, in_result(0), b.u64(0), in_input(0)])
b.transfer([in_result(1)], sender)
write("t3_vlatest_swap_only", b.build())

# T4: VMID add_liquidity_returns, zero PAULY (probe gate)
b = B()
sender = b.address(SENDER)
b.split([10_000_000 * MIST])                                    # result 0
b.move(SUI, "coin", "zero", [PAULY_T], [])                      # result 1
b.move(VMID, "router", "add_liquidity_returns", [SUI_T, PAULY_T],
       [b.u64(10_000_000 * MIST), in_result(0), b.u64(0), in_result(1),
        b.u64(0), b.u64(0), in_input(0)])                       # result 2 (3 values)
b.transfer([in_result(2, 0), in_result(2, 1)], sender)
write("t4_vmid_add_zero_pauly", b.build())

# T5: VLATEST add_liquidity_returns, zero PAULY (probe gate)
b = B()
sender = b.address(SENDER)
b.split([10_000_000 * MIST])
b.move(SUI, "coin", "zero", [PAULY_T], [])
b.move(VLATEST, "router", "add_liquidity_returns", [SUI_T, PAULY_T],
       [b.u64(10_000_000 * MIST), in_result(0), b.u64(0), in_result(1),
        b.u64(0), b.u64(0), in_input(0)])
b.transfer([in_result(2, 0), in_result(2, 1)], sender)
write("t5_vlatest_add_zero_pauly", b.build())

# T6: parent recipe: V1 swap -> V-latest add -> V-latest remove
b = B()
sender = b.address(SENDER)
b.split([1_000_000 * MIST])                                     # result 0
b.move(V1, "router", "swap_exact_input", [SUI_T, PAULY_T],
       [b.u64(1_000_000 * MIST), in_result(0), b.u64(0), in_input(0)])   # no result
b.split([10_000_000 * MIST])                                    # result 1
b.move(SUI, "coin", "zero", [PAULY_T], [])                      # result 2
b.move(VLATEST, "router", "add_liquidity_returns", [SUI_T, PAULY_T],
       [b.u64(10_000_000 * MIST), in_result(1), b.u64(0), in_result(2),
        b.u64(0), b.u64(0), in_input(0)])                       # result 3 (3 values)
b.move(SUI, "coin", "value", [LSP_T], [in_result(3, 2)])        # result 4
b.move(VLATEST, "router", "remove_liquidity", [SUI_T, PAULY_T],
       [in_result(4), in_result(3, 2), b.u64(0), b.u64(0), in_input(0)])
b.transfer([in_result(3, 0), in_result(3, 1)], sender)
write("t6_parent_recipe_v1_vlatest", b.build())

# T7: VMID swap -> VMID add -> VMID remove (roundtrip probe)
b = B()
sender = b.address(SENDER)
b.split([10_000_000 * MIST])                                    # result 0
b.move(VMID, "router", "swap_exact_input_", [SUI_T, PAULY_T],
       [b.u64(10_000_000 * MIST), in_result(0), b.u64(0), in_input(0)])  # result 1
b.split([10_000_000 * MIST])                                    # result 2
b.move(SUI, "coin", "value", [PAULY_T], [in_result(1)])         # result 3
b.move(VMID, "router", "add_liquidity_returns", [SUI_T, PAULY_T],
       [b.u64(10_000_000 * MIST), in_result(2), in_result(3), in_result(1),
        b.u64(0), b.u64(0), in_input(0)])                       # result 4 (3 values)
b.move(SUI, "coin", "value", [LSP_T], [in_result(4, 2)])        # result 5
b.move(VMID, "router", "remove_liquidity", [SUI_T, PAULY_T],
       [in_result(5), in_result(4, 2), b.u64(0), b.u64(0), in_input(0)])
b.transfer([in_result(4, 0), in_result(4, 1)], sender)
write("t7_vmid_roundtrip", b.build())

# T7b: VMID -> V-latest comparison roundtrip
b = B()
sender = b.address(SENDER)
b.split([10_000_000 * MIST])                                    # result 0
b.move(VLATEST, "router", "swap_exact_input_", [SUI_T, PAULY_T],
       [b.u64(10_000_000 * MIST), in_result(0), b.u64(0), in_input(0)])  # result 1
b.split([10_000_000 * MIST])                                    # result 2
b.move(SUI, "coin", "value", [PAULY_T], [in_result(1)])         # result 3
b.move(VLATEST, "router", "add_liquidity_returns", [SUI_T, PAULY_T],
       [b.u64(10_000_000 * MIST), in_result(2), in_result(3), in_result(1),
        b.u64(0), b.u64(0), in_input(0)])                       # result 4 (3 values)
b.move(SUI, "coin", "value", [LSP_T], [in_result(4, 2)])        # result 5
b.move(VLATEST, "router", "remove_liquidity", [SUI_T, PAULY_T],
       [in_result(5), in_result(4, 2), b.u64(0), b.u64(0), in_input(0)])
b.transfer([in_result(4, 0), in_result(4, 1)], sender)
write("t7b_vlatest_roundtrip", b.build())

print("done")
