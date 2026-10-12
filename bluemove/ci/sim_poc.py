#!/usr/bin/env python3
"""BlueMove Phase-2 CI: devInspect-style simulations via public Sui GraphQL simulateTransaction.

Read-only: nothing is signed or executed. Proves:
  s1  vmid  router::swap_exact_input_      -> version gate abort 25 (escrow package disabled)
  s2  v12   router::add_liquidity_returns  -> version gate abort 25
  s3  V1    router::swap_exact_input        -> balance::split abort 2 (legacy store empty)
  s4  V1    router::add_liquidity (mint)    -> mint impossible on EM pools (underflow/reserve guard)
  s5  V1    router::swap_exact_input on SUITRUMP faucet pool -> expected SUCCESS (residual dead-meme faucet)
  s6  parent attack recipe (V1 swap -> v12 add -> v12 remove) -> gate abort
Writes ci-out/sim_results.json + raw request/response pairs.
"""
import base64, json, os, time, urllib.request

GQL = "https://graphql.mainnet.sui.io/graphql"
UA = {"User-Agent": "Mozilla/5.0 (research; bluemove-phase2)", "Content-Type": "application/json"}
OUT = os.environ.get("OUT_DIR", "ci-out") + "/sim"
os.makedirs(OUT, exist_ok=True)

SENDER = "0x0feb54a725aa357ff2f5bc6bb023c05b310285bd861275a30521f339a434ebb3"
DEX_INFO = "0x3f2d9f724f4a1ce5e71676448dc452be9a6243dac9c5b975a588c8c867066e92"
DEX_INFO_INITIAL_SHARED_VERSION = 1587827
SUI = "0x0000000000000000000000000000000000000000000000000000000000000002"
V1 = "0xb24b6789e088b876afabca733bed2299fbc9e2d6369be4d1acfa17d8145454d9"
VMID = "0x08cd33481587d4c4612865b164796d937df13747d8c763b8a178c87e3244498f"
V12 = "0x35f3190a41b98da22c997c9266143523816d73a902123dde6f60fac2e0f656d7"
PAULY = "0xe7131700f8b336a011ff2d0e3403eb719ae9d5c15fc71bf371e4990eccf013a7::pauly::PAULY"
SUITRUMP = "0xcf7153e281bb3e53ccf8a1e8e218779c1ed7a57ac90e58495271ac57d2d23af4::suitrump::SUITRUMP"
SUI_T = f"{SUI}::sui::SUI"

Q = """query Sim($tx: JSON!, $checks: Boolean, $gasSelect: Boolean) {
  simulateTransaction(transaction: $tx, checksEnabled: $checks, doGasSelection: $gasSelect) {
    effects { digest status
      executionError { message abortCode identifier module { name } function { name } }
      effectsJson }
    outputs { returnValues { value { json bcs type { repr } } } }
  }
}"""

def b64(b): return base64.b64encode(b).decode()

class B:
    def __init__(self):
        self.inputs = [{"kind": "SHARED", "objectId": DEX_INFO,
                        "version": str(DEX_INFO_INITIAL_SHARED_VERSION),
                        "mutable": True, "mutability": "MUTABLE"}]
        self.commands = []
    def u64(self, v):
        self.inputs.append({"kind": "PURE", "pure": b64(v.to_bytes(8, "little"))})
        return {"kind": "INPUT", "input": len(self.inputs) - 1}
    def address(self, a):
        h = a[2:] if a.startswith("0x") else a
        self.inputs.append({"kind": "PURE", "pure": b64(bytes.fromhex(h.rjust(64, "0")))})
        return {"kind": "INPUT", "input": len(self.inputs) - 1}
    def split(self, amounts, coin=None):
        self.commands.append({"splitCoins": {"coin": coin or {"kind": "GAS"},
                                             "amounts": [self.u64(a) for a in amounts]}})
    def move(self, pkg, module, fn, targs, args):
        self.commands.append({"moveCall": {"package": pkg, "module": module, "function": fn,
                                           "typeArguments": targs, "arguments": args}})
    def transfer(self, objs, addr):
        self.commands.append({"transferObjects": {"objects": objs, "address": addr}})
    def build(self):
        return {"sender": SENDER, "kind": {"kind": "PROGRAMMABLE_TRANSACTION",
                "programmableTransaction": {"inputs": self.inputs, "commands": self.commands}}}

def sim(name, tx):
    body = json.dumps({"query": Q, "variables": {"tx": tx, "checks": True, "gasSelect": True}}).encode()
    last_err = None
    for attempt in range(8):
        try:
            req = urllib.request.Request(GQL, data=body, headers=UA)
            with urllib.request.urlopen(req, timeout=120) as r:
                d = json.loads(r.read())
            open(f"{OUT}/{name}.request.json", "w").write(json.dumps({"tx": tx}, indent=1))
            open(f"{OUT}/{name}.response.json", "w").write(json.dumps(d, indent=1))
            if d.get("errors"):
                return {"name": name, "ok": False, "gql_errors": str(d["errors"])[:300]}
            res = d["data"]["simulateTransaction"]
            eff = res.get("effects") or {}
            err = eff.get("executionError") or {}
            ej = eff.get("effectsJson")
            if isinstance(ej, str):
                try: ej = json.loads(ej)
                except Exception: ej = None
            oc = []
            for c in ((ej or {}).get("objectChanges") or []):
                if c.get("objectType", "").endswith("::sui::SUI") or True:
                    oc.append(c)
            return {"name": name, "ok": True, "status": eff.get("status"), "digest": eff.get("digest"),
                    "abortCode": err.get("abortCode"), "error": (err.get("message") or None),
                    "error_function": ((err.get("function") or {}).get("name")),
                    "error_module": ((err.get("module") or {}).get("name")),
                    "objectChanges": oc[:25],
                    "returnValues": ((res.get("outputs") or {}).get("returnValues") or [])[:4]}
        except Exception as e:
            last_err = f"{type(e).__name__}: {str(e)[:200]}"
            time.sleep(2.0 * (attempt + 1))
    return {"name": name, "ok": False, "err": last_err or "request failed"}

def main():
    results = []
    # s1 vmid gate
    b = B(); s = b.address(SENDER)
    b.split([10_000])
    b.move(VMID, "router", "swap_exact_input_", [SUI_T, PAULY], [b.u64(10_000), {"kind": "RESULT", "result": 0}, b.u64(0), {"kind": "INPUT", "input": 0}])
    b.transfer([{"kind": "RESULT", "result": 1}], s)
    results.append(sim("s1_vmid_swap_gate", b.build()))
    # s2 v12 add_liquidity_returns gate
    b = B(); s = b.address(SENDER)
    b.split([10_000_000])
    b.move(SUI, "coin", "zero", [PAULY], [])
    b.move(V12, "router", "add_liquidity_returns", [SUI_T, PAULY],
           [b.u64(10_000_000), {"kind": "RESULT", "result": 0}, b.u64(0), {"kind": "RESULT", "result": 1},
            b.u64(0), b.u64(0), {"kind": "INPUT", "input": 0}])
    b.transfer([{"kind": "RESULT", "result": 2, "subresult": 0}, {"kind": "RESULT", "result": 2, "subresult": 1},
                {"kind": "RESULT", "result": 2, "subresult": 2}], s)
    results.append(sim("s2_v12_add_returns_gate", b.build()))
    # s3 V1 swap on EM pool (legacy store empty)
    b = B()
    b.split([1_000])
    b.move(V1, "router", "swap_exact_input", [SUI_T, PAULY],
           [b.u64(1_000), {"kind": "RESULT", "result": 0}, b.u64(0), {"kind": "INPUT", "input": 0}])
    results.append(sim("s3_v1_swap_empty_store", b.build()))
    # s4 V1 add_liquidity (mint) on EM pool
    b = B(); s = b.address(SENDER)
    b.split([10_000_000])
    b.move(SUI, "coin", "zero", [PAULY], [])
    b.move(V1, "router", "add_liquidity", [SUI_T, PAULY],
           [b.u64(10_000_000), {"kind": "RESULT", "result": 0}, b.u64(0), {"kind": "RESULT", "result": 1},
            b.u64(0), b.u64(0), {"kind": "INPUT", "input": 0}])
    results.append(sim("s4_v1_mint_em_pool", b.build()))
    # s5 V1 swap on SUITRUMP faucet pool (expected SUCCESS - dead-meme faucet residual)
    b = B()
    b.split([100_000_000])
    b.move(V1, "router", "swap_exact_input", [SUI_T, SUITRUMP],
           [b.u64(100_000_000), {"kind": "RESULT", "result": 0}, b.u64(0), {"kind": "INPUT", "input": 0}])
    results.append(sim("s5_v1_swap_suitrump_faucet", b.build()))
    # s6 escrow-version roundtrip (add_liquidity_returns -> remove_liquidity, v12 only)
    b = B(); s = b.address(SENDER)
    b.split([10_000_000])
    b.move(SUI, "coin", "zero", [PAULY], [])
    b.move(V12, "router", "add_liquidity_returns", [SUI_T, PAULY],
           [b.u64(10_000_000), {"kind": "RESULT", "result": 0}, b.u64(0), {"kind": "RESULT", "result": 1},
            b.u64(0), b.u64(0), {"kind": "INPUT", "input": 0}])
    lp = {"kind": "RESULT", "result": 2, "subresult": 2}
    b.move(SUI, "coin", "value", [f"{V1}::swap::LSP<{SUI_T},{PAULY}>"], [lp])
    b.move(V12, "router", "remove_liquidity", [SUI_T, PAULY],
           [{"kind": "RESULT", "result": 3}, lp, b.u64(0), b.u64(0), {"kind": "INPUT", "input": 0}])
    b.transfer([{"kind": "RESULT", "result": 2, "subresult": 0}, {"kind": "RESULT", "result": 2, "subresult": 1}], s)
    results.append(sim("s6_v12_roundtrip_gate", b.build()))

    summary = {"generated_at_utc": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
               "note": "read-only simulations; nothing signed/sent",
               "results": results}
    with open(f"{OUT}/sim_results.json", "w") as f:
        json.dump(summary, f, indent=1)
    for r in results:
        print(json.dumps(r)[:400], flush=True)

if __name__ == "__main__":
    main()
