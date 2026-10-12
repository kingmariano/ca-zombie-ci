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

def sim(name, tx, checks=True):
    body = json.dumps({"query": Q, "variables": {"tx": tx, "checks": checks, "gasSelect": True}}).encode()
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
            if isinstance(ej, dict):
                for c in (ej.get("objectChanges") or ej.get("changedObjects") or []):
                    if isinstance(c, dict):
                        oc.append(c)
            outs = res.get("outputs")
            rv = []
            if isinstance(outs, dict):
                rv = outs.get("returnValues") or []
            elif isinstance(outs, list):
                rv = outs
            return {"name": name, "ok": True, "status": eff.get("status"), "digest": eff.get("digest"),
                    "abortCode": err.get("abortCode"), "error": (err.get("message") or None),
                    "error_function": ((err.get("function") or {}).get("name")),
                    "error_module": ((err.get("module") or {}).get("name")),
                    "objectChanges": oc[:25],
                    "returnValues": rv[:4]}
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

    # s7/s8: live V1-v6 mint-inflation on the desynced pool 0x99c63597... (SUI/PIGU).
    # Uses an existing PIGU coin object as input (any holder); checks disabled so the
    # object can be referenced. Read-only simulation.
    try:
        PIGU = "0xfc71274a94f5d9cd1ae6928ecfc9fa910d03eb28258fddeb9842ac3c7b4f3ae6::pigu::PIGU"
        q = """query($t: String!) { objects(first: 5, filter: {type: $t}) { nodes { address version digest asMoveObject { contents { json } } } } }"""
        def _gql(query, variables):
            b2 = json.dumps({"query": query, "variables": variables}).encode()
            for _ in range(4):
                try:
                    req = urllib.request.Request(GQL, data=b2, headers=UA)
                    with urllib.request.urlopen(req, timeout=60) as r:
                        return json.loads(r.read())["data"]
                except Exception:
                    time.sleep(2)
            raise RuntimeError("gql failed in s7/s8")
        d = _gql(q, {"t": f"0x2::coin::Coin<{PIGU}>"})
        cand = None
        for n in d["objects"]["nodes"]:
            j = (n.get("asMoveObject") or {}).get("contents", {}).get("json") or {}
            if int(j.get("balance") or 0) >= 5_400_000:
                cand = n; break
        if cand:
            def coin_ref(b, i):
                b.inputs.append({"kind": "IMMUTABLE_OR_OWNED", "objectId": cand["address"],
                                 "version": str(cand["version"]), "digest": cand["digest"]})
                return {"kind": "INPUT", "input": len(b.inputs) - 1}
            # s7: V1 mint leg
            b = B(); b.split([43_319])
            cr = coin_ref(b, 0)
            b.commands.append({"splitCoins": {"coin": cr, "amounts": [b.u64(5_277_399)]}})
            b.move(V1, "router", "add_liquidity", [SUI_T, PIGU],
                   [b.u64(43_319), {"kind": "RESULT", "result": 0}, b.u64(5_277_399), {"kind": "RESULT", "result": 1},
                    b.u64(0), b.u64(0), {"kind": "INPUT", "input": 0}])
            results.append(sim("s7_v1_mint_inflation", b.build(), checks=False))
            # s8: atomic v6 add_liquidity_returns -> v6 remove_liquidity
            V6 = "0xa00faab58ff6876dce096d5e0591200b84a14f4033319d27c48b781a37aa2ed7"
            b = B()
            sender2 = b.address(SENDER)
            b.split([43_319])
            cr2 = coin_ref(b, 0)
            b.commands.append({"splitCoins": {"coin": cr2, "amounts": [b.u64(5_277_399)]}})
            b.move(V6, "router", "add_liquidity_returns", [SUI_T, PIGU],
                   [b.u64(43_319), {"kind": "RESULT", "result": 0}, b.u64(5_277_399), {"kind": "RESULT", "result": 1},
                    b.u64(0), b.u64(0), {"kind": "INPUT", "input": 0}])
            lp2 = {"kind": "RESULT", "result": 2, "subresult": 2}
            b.move(SUI, "coin", "value", [f"{V1}::swap::LSP<{SUI_T},{PIGU}>"], [lp2])
            b.move(V6, "router", "remove_liquidity", [SUI_T, PIGU],
                   [{"kind": "RESULT", "result": 3}, lp2, b.u64(0), b.u64(0), {"kind": "INPUT", "input": 0}])
            b.transfer([{"kind": "RESULT", "result": 2, "subresult": 0}, {"kind": "RESULT", "result": 2, "subresult": 1}], sender2)
            results.append(sim("s8_v6_atomic_attack", b.build(), checks=False))
        else:
            results.append({"name": "s7_s8_skipped", "ok": False, "err": "no suitable PIGU coin found"})
    except Exception as e:
        results.append({"name": "s7_s8_skipped", "ok": False, "err": str(e)[:200]})

    summary = {"generated_at_utc": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
               "note": "read-only simulations; nothing signed/sent",
               "results": results}
    with open(f"{OUT}/sim_results.json", "w") as f:
        json.dump(summary, f, indent=1)
    for r in results:
        print(json.dumps(r)[:400], flush=True)

if __name__ == "__main__":
    main()
