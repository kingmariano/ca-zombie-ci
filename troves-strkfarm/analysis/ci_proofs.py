#!/usr/bin/env python3
"""C2-51 Troves/STRKFarm retired vaults — consolidated read-only proof suite.

Runs against keyless public Starknet RPCs (no keys, no transactions, no signing).
Writes proofs.json and PROOFS.md into the folder passed as argv[1] (default: ../ci-out).

Evidence produced:
  * live state: balances, class hashes, owner, pause for all 6 retired vaults
  * zkLend-recovery batch views (batches 0..3) and per-address positions
  * static access probes (starknet_call with caller=0)
  * simulations from unprivileged senders (starknet_simulateTransactions, SKIP_VALIDATE):
      - non-holder extraction attempts -> no token transfer
      - receiver-basis test -> caller-based claims (no third-party payout)
      - exact-amount self-claim (transfer equals stored position)
      - double-claim -> 'Zklend::Already claimed'
      - owner-gated / paused / dead functions
"""
import hashlib
import json
import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from rpc import block_number, call, felt, rpc, selector  # noqa: E402

CARTRIDGE = "https://api.cartridge.gg/x/starknet/mainnet"

VAULTS = {
    "AutoCompounding_STRK": "0x00541681b9ad63dff1b35f79c78d8477f64857de29a27902f7298f7b620838ea",
    "AutoCompounding_USDC": "0x016912b22d5696e95ffde888ede4bd69fbbc60c5f873082857a47c543172694f",
    "Sensei_STRK": "0x020d5fc4c9df4f943ebb36078e703369c04176ed00accf290e8295b659d2cea6",
    "Sensei_USDC": "0x04937b58e05a3a2477402d1f74e66686f58a61a5070fcc6f694fb9a0b3bae422",
    "Sensei_ETH": "0x9d23d9b1fa0db8c9d75a1df924c3820e594fc4ab1475695889286f3f6df250",
    "Sensei_ETH_XL": "0x9140757f8fb5748379be582be39d6daf704cc3a0408882c0d57981a885eed9",
}
TOKENS = {
    "STRK": "0x04718f5a0fc34cc1af16a1cdee98ffb20c31f5cd61d6ab07201858f4287c938d",
    "USDC_bridged": "0x053c91253bc9682c04929ca02ed00b3e423f6710d2ee7e0d5ebb06f3ecf368a8",
    "ETH": "0x049d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7",
    "zSTRK": "0x06d8fa671ef84f791b7f601fa79fea8f6ceb70b5fa84189e3159d532162efc21",
    "zUSDC": "0x047ad51726d891f972e74e4ad858a261b43869f7126ce7436ee0b2529a98f486",
    "zETH": "0x1b5bd713e72fdc5d63ffd83762f81297f6175a5e0a4771cdadbc1dd5fe72cb1",
    "zETH_XL": "0x057146f6409deb4c9fa12866915dd952aa07c1eb2752e451d7f3b042086bdeb8",
}
AC_OWNER = "0x3495dd1e4838aa06666aac236036d86e81a6553e222fc02e70c2cbc0062e8d0"
S_OWNER = "0x55d39827894c40f04fe3a314ad013bf9bc5220f7eb6cd8863212dcba6c0e16e"
ATTACKER = "0x0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcd"
STRK = TOKENS["STRK"]
USDC = TOKENS["USDC_bridged"]
ETH = TOKENS["ETH"]

TRANSFER = "0x" + format(int(selector("transfer"), 16), "064x")


def norm(s):
    return "0x" + format(int(s, 16), "064x") if s else ""


def u256(v):
    return [hex(v & ((1 << 128) - 1)), hex(v >> 128)]


def u256val(vals):
    if isinstance(vals, list) and len(vals) == 2:
        return int(vals[0], 16) + (int(vals[1], 16) << 128)
    return None


def try_call(to, entry, calldata=()):
    try:
        return {"ok": True, "result": call(to, selector(entry), calldata)}
    except Exception as e:  # noqa: BLE001
        return {"ok": False, "error": str(e)[:300]}


# ---------------- simulations ----------------
def enc_route(token_from, token_to, exchange, percent=10000, extra=None):
    extra = extra or []
    return [felt(token_from), felt(token_to), felt(exchange), hex(percent), hex(len(extra))] + [felt(x) for x in extra]


def enc_swap(token_from, from_amount, token_to, to_amount, to_min, beneficiary, fee_bps, fee_recipient, routes):
    cd = [felt(token_from)] + u256(from_amount) + [felt(token_to)] + u256(to_amount) + u256(to_min)
    cd += [felt(beneficiary), hex(fee_bps), felt(fee_recipient), hex(len(routes))]
    for r in routes:
        cd += r
    return cd


def enc_claim(cid, claimee, amount):
    return [hex(cid), felt(claimee), hex(amount)]


def enc_claim_context(recipient, share, withdrawable, proof):
    cd = [felt(recipient), hex(share), hex(len(withdrawable))]
    for token, amount in withdrawable:
        cd += [felt(token), hex(amount)]
    cd += [hex(len(proof))] + [felt(p) for p in proof]
    return cd


def pick_fresh_sender(exclude):
    blk = rpc("starknet_getBlockWithTxs", ["latest"], endpoint=CARTRIDGE)
    for t in blk.get("transactions", []):
        s = t.get("sender_address")
        if t.get("type") == "INVOKE" and s and felt(s) not in exclude:
            return s
    raise RuntimeError("no fresh sender")


def simulate(sender, calls, tries=3):
    calldata = [hex(len(calls))]
    for to, entry, args in calls:
        calldata += [felt(to), selector(entry), hex(len(args))] + [
            felt(a) if isinstance(a, str) and a.startswith("0x") else hex(a) for a in args
        ]
    last = None
    for _ in range(tries):
        try:
            nonce = rpc("starknet_getNonce", ["latest", felt(sender)], endpoint=CARTRIDGE)
            tx = {
                "type": "INVOKE", "version": "0x1", "sender_address": felt(sender),
                "calldata": calldata, "signature": [], "nonce": nonce, "max_fee": "0x0",
            }
            r = rpc(
                "starknet_simulateTransactions",
                {"block_id": "latest", "transactions": [tx], "simulation_flags": ["SKIP_VALIDATE", "SKIP_FEE_CHARGE"]},
                endpoint=CARTRIDGE,
            )
            return {"ok": True, "response": r}
        except Exception as e:  # noqa: BLE001
            last = str(e)[:400]
            time.sleep(1.5)
    return {"ok": False, "error": last}


def analyze(simres):
    if not simres.get("ok"):
        return {"status": "SIM_ERROR", "error": simres.get("error")}
    sim = simres["response"][0]
    trace = sim.get("transaction_trace", {})
    ex = trace.get("execute_invocation", {})
    if ex.get("revert_reason"):
        return {"status": "REVERTED", "revert": str(ex["revert_reason"])[:900]}
    lines = []

    def walk(node, d=0):
        if not isinstance(node, dict):
            return
        lines.append({"depth": d, "selector": norm(node.get("entry_point_selector", "")),
                      "contract": node.get("contract_address", ""), "calldata": node.get("calldata", [])})
        for c in node.get("calls", []) or []:
            walk(c, d + 1)

    walk(ex)
    transfers = []
    for l in lines:
        if l["selector"] == TRANSFER and len(l["calldata"]) >= 3:
            transfers.append({"token": l["contract"], "to": l["calldata"][0],
                              "amount": int(l["calldata"][1], 16) + (int(l["calldata"][2], 16) << 128)})
    return {"status": "SUCCESS", "n_calls": len(lines), "transfers": transfers}


def main():
    outdir = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "ci-out")
    os.makedirs(outdir, exist_ok=True)
    res = {"finding": "C2-51", "chain": "starknet", "block_start": block_number()}

    # ---- state ----
    state = {}
    for name, addr in VAULTS.items():
        v = {"address": felt(addr)}
        try:
            v["class_hash"] = rpc("starknet_getClassHashAt", ["latest", felt(addr)])
        except Exception as e:  # noqa: BLE001
            v["class_hash_error"] = str(e)[:120]
        v["owner"] = try_call(addr, "owner")
        v["is_paused"] = try_call(addr, "is_paused")
        v["balances"] = {}
        for tname, taddr in TOKENS.items():
            r = try_call(taddr, "balanceOf", [felt(addr)])
            if r.get("ok"):
                v["balances"][tname] = u256val(r["result"])
            else:
                v["balances"][tname] = r
        state[name] = v
    res["state"] = state

    # ---- claims ----
    claims = {}
    for name, addr in VAULTS.items():
        row = {"batches": {}, "positions": {}}
        for b in range(0, 4):
            r = try_call(addr, "get_zklend_amount", [hex(b), "0x0"])
            row["batches"][b] = r
        for pname, paddr in [("AC_OWNER", AC_OWNER), ("S_OWNER", S_OWNER), ("ATTACKER", ATTACKER)]:
            row["positions"][pname] = try_call(addr, "zklend_position", [felt(paddr), "0x1", "0x0"])
        claims[name] = row
    res["claims"] = claims

    # ---- static access probes (caller = 0x0) ----
    static = {}
    for name, addr in VAULTS.items():
        probes = {
            "withdraw_zklend(1,attacker)": ("withdraw_zklend", [hex(1), hex(0), felt(ATTACKER)]),
            "claim_zklend(1,USDC,1)": ("claim_zklend", [hex(1), hex(0), felt(USDC), hex(1), hex(0)]),
            "upgrade(0x1)": ("upgrade", [hex(1)]),
        }
        if name.startswith("Sensei"):
            probes["set_batch_amount(1,USDC,1)"] = ("set_batch_amount", [hex(1), hex(0), felt(USDC), hex(1), hex(0)])
            probes["transfer(0,1,attacker)"] = ("transfer", [felt("0x0"), hex(1), hex(0), felt(ATTACKER)])
            probes["unpause()"] = ("unpause", [])
        if name.startswith("Auto"):
            probes["register_zklend(forged)"] = ("register_zklend", enc_claim_context(ATTACKER, 10**18, [(USDC, 10**12)], []))
        static[name] = {k: try_call(addr, e, cd) for k, (e, cd) in probes.items()}
    res["static_probes"] = static

    # ---- simulations ----
    swap_bad = enc_swap(STRK, 10**18, USDC, 0, 0, ATTACKER, 0, "0x0", [])
    sims = {}
    exclude = {felt(AC_OWNER), felt(S_OWNER), felt(ATTACKER)}
    try:
        fresh = pick_fresh_sender(exclude)
    except Exception:  # noqa: BLE001
        fresh = S_OWNER
    res["sim_senders"] = {"fresh_random": fresh, "AC_OWNER": AC_OWNER, "S_OWNER": S_OWNER}

    plan = [
        ("nonholder_AC_STRK_withdraw_zklend", VAULTS["AutoCompounding_STRK"], S_OWNER,
         [("withdraw_zklend", [hex(1), hex(0), felt(ATTACKER)])]),
        ("nonholder_S_STRK_withdraw_zklend", VAULTS["Sensei_STRK"], fresh,
         [("withdraw_zklend", [hex(1), hex(0), felt(ATTACKER)])]),
        ("receiver_basis_S_STRK_random_caller_AC_owner_receiver", VAULTS["Sensei_STRK"], fresh,
         [("withdraw_zklend", [hex(1), hex(0), felt(AC_OWNER)])]),
        ("single_claim_S_STRK_AC_owner", VAULTS["Sensei_STRK"], AC_OWNER,
         [("withdraw_zklend", [hex(1), hex(0), felt(AC_OWNER)])]),
        ("double_claim_S_STRK_AC_owner", VAULTS["Sensei_STRK"], AC_OWNER,
         [("withdraw_zklend", [hex(1), hex(0), felt(AC_OWNER)])] * 2),
        ("single_claim_S_USDC_AC_owner", VAULTS["Sensei_USDC"], AC_OWNER,
         [("withdraw_zklend", [hex(1), hex(0), felt(AC_OWNER)])]),
        ("claim_zklend_S_USDC_AC_owner", VAULTS["Sensei_USDC"], AC_OWNER,
         [("claim_zklend", [hex(1), hex(0), felt(USDC), hex(1), hex(0)])]),
        ("set_batch_amount_S_USDC_AC_owner", VAULTS["Sensei_USDC"], AC_OWNER,
         [("set_batch_amount", [hex(1), hex(0), felt(USDC), hex(1), hex(0)])]),
        ("transfer_S_USDC_AC_owner", VAULTS["Sensei_USDC"], AC_OWNER,
         [("transfer", [felt("0x0"), hex(1), hex(0), felt(ATTACKER)])]),
        ("swap_S_USDC_AC_owner", VAULTS["Sensei_USDC"], AC_OWNER,
         [("swap", [felt(USDC), felt(USDC), *swap_bad])]),
        ("unwind_dapp2_S_USDC_AC_owner", VAULTS["Sensei_USDC"], AC_OWNER,
         [("unwind_dapp2", [*u256(10000), *swap_bad])]),
        ("withdraw_S_USDC_AC_owner", VAULTS["Sensei_USDC"], AC_OWNER,
         [("withdraw", [hex(1), hex(0), felt(ATTACKER), hex(0)])]),
        ("rebalance_S_USDC_AC_owner", VAULTS["Sensei_USDC"], AC_OWNER,
         [("rebalance", [hex(1), hex(0), hex(0)])]),
        ("unpause_S_USDC_AC_owner", VAULTS["Sensei_USDC"], AC_OWNER,
         [("unpause", [])]),
        ("register_zklend_forged_S_USDC_AC_owner", VAULTS["Sensei_USDC"], AC_OWNER,
         [("register_zklend", enc_claim_context(ATTACKER, 10**18, [(USDC, 10**12)], []))]),
        ("harvest_S_USDC_AC_owner", VAULTS["Sensei_USDC"], AC_OWNER,
         [("harvest", [felt(AC_OWNER), *enc_claim(0, VAULTS["Sensei_USDC"], 0), hex(0), felt(AC_OWNER), *enc_claim(0, VAULTS["Sensei_USDC"], 0), hex(0), *swap_bad])]),
        ("harvest_AC_STRK_S_owner", VAULTS["AutoCompounding_STRK"], S_OWNER,
         [("harvest", [*enc_claim(0, VAULTS["AutoCompounding_STRK"], 0), hex(0), *swap_bad])]),
        ("claim_zklend_AC_STRK_S_owner", VAULTS["AutoCompounding_STRK"], S_OWNER,
         [("claim_zklend", [hex(1), hex(0), felt(USDC), hex(1), hex(0)])]),
    ]
    for label, vault, sender, calls in plan:
        sims[label] = analyze(simulate(sender, [(vault, e, a) for e, a in calls]))
    res["sims"] = sims

    # ---- prices ----
    try:
        import urllib.request
        req = urllib.request.Request(
            "https://coins.llama.fi/prices/current/coingecko:ethereum,coingecko:starknet,coingecko:usd-coin",
            headers={"User-Agent": "research; read-only"},
        )
        with urllib.request.urlopen(req, timeout=20) as r:
            res["prices"] = json.loads(r.read())
    except Exception as e:  # noqa: BLE001
        res["prices"] = {"error": str(e)[:200]}

    res["block_end"] = block_number()
    with open(os.path.join(outdir, "proofs.json"), "w") as fh:
        json.dump(res, fh, indent=1)

    # ---- human-readable summary ----
    lines = ["# C2-51 proof suite output", ""]
    lines.append(f"Starknet blocks: {res['block_start']} .. {res['block_end']}")
    lines.append("")
    lines.append("## Live balances (raw units)")
    for n, v in state.items():
        lines.append(f"- {n}: class={v.get('class_hash')} owner={v.get('owner',{}).get('result')} paused={v.get('is_paused',{}).get('result')}")
        for t, b in v["balances"].items():
            if isinstance(b, int) and b:
                lines.append(f"    - {t}: {b}")
    lines.append("")
    lines.append("## Claim batches (token, amount raw)")
    for n, v in claims.items():
        for b, r in v["batches"].items():
            if r.get("ok") and r["result"] and r["result"][0] != "0x0":
                lines.append(f"- {n} batch {b}: token={r['result'][0]} amount={u256val(r['result'][1:3])}")
    lines.append("")
    lines.append("## Simulations")
    for k, v in sims.items():
        if v.get("status") == "SUCCESS":
            trf = "; ".join(f"{t['token'][:12]}->{t['to'][:12]} amount={t['amount']}" for t in v.get("transfers", [])) or "none"
            lines.append(f"- {k}: SUCCESS transfers=[{trf}] calls={v.get('n_calls')}")
        elif v.get("status") == "REVERTED":
            lines.append(f"- {k}: REVERTED {v['revert'].splitlines()[-1][:160]}")
        else:
            lines.append(f"- {k}: {v.get('status')} {str(v.get('error'))[:120]}")
    with open(os.path.join(outdir, "PROOFS.md"), "w") as fh:
        fh.write("\n".join(lines) + "\n")

    print(json.dumps({"proofs": os.path.join(outdir, "proofs.json"),
                      "sha256": hashlib.sha256(open(os.path.join(outdir, "proofs.json"), "rb").read()).hexdigest(),
                      "block_start": res["block_start"], "block_end": res["block_end"]}, indent=1))


if __name__ == "__main__":
    main()
