#!/usr/bin/env python3
"""C2-25 Larix proof harness (read-only; solders-based).

Runs the decisive simulations against the LIVE deployed Larix programs:
  1. main-baseline       : SetConfig(reserve) with reserve's own market -> passes gates, stops at oracle-config validation (Custom 42)
  2. aux-baseline        : same on aux program
  3. aux-mismatch-market : different market of the same program -> REJECTED by reserve<->market check (Custom 5)
  4. aux-owner-not-signer: market owner not signer (neutral payer) -> REJECTED (Custom 12)

No transactions are signed or sent; sigVerify=false + replaceRecentBlockhash=true.
Keyless public RPC only (solana-rpc.publicnode.com, fallback api.mainnet-beta.solana.com).
"""
import json, base64, sys, os, urllib.request

from solders.pubkey import Pubkey
from solders.instruction import Instruction, AccountMeta
from solders.message import Message
from solders.transaction import Transaction
from solders.hash import Hash

RPCS = ["https://solana-rpc.publicnode.com", "https://api.mainnet-beta.solana.com"]

def rpc(method, params):
    body = json.dumps({"jsonrpc": "2.0", "id": 1, "method": method, "params": params}).encode()
    last = None
    import time
    for url in RPCS:
        for attempt in range(5):
            try:
                req = urllib.request.Request(url, data=body, headers={"content-type": "application/json"})
                with urllib.request.urlopen(req, timeout=40) as resp:
                    j = json.load(resp)
                if "result" in j: return j["result"]
                last = j
            except Exception as e:
                last = str(e)
                time.sleep(2.0 + 2.0 * attempt)
    raise RuntimeError(f"rpc {method} failed: {last}")

def simulate(instructions, payer_str):
    ixs = []
    for spec in instructions:
        metas = [AccountMeta(pubkey=Pubkey.from_string(a["pk"]), is_signer=a.get("signer", False),
                             is_writable=a.get("writable", False)) for a in spec["accounts"]]
        ixs.append(Instruction(Pubkey.from_string(spec["program"]), bytes.fromhex(spec["data"]), metas))
    msg = Message.new_with_blockhash(ixs, Pubkey.from_string(payer_str), Hash.default())
    tx = Transaction.new_unsigned(msg)
    txb = base64.b64encode(bytes(tx)).decode()
    res = rpc("simulateTransaction", [txb, {"encoding": "base64", "sigVerify": False,
                                            "replaceRecentBlockhash": True, "commitment": "confirmed"}])
    v = res.get("value") if isinstance(res, dict) else None
    return v or res

PROG_MAIN = "7Zb1bGi32pfsrBkzWdqd4dFhUXwp5Nybr1zuaEwN34hy"
PROG_AUX  = "3cKREQ3Z7ioCQ4oa23uGEuzekhQWPxKiBEZ87WfaAZ5p"
EKNZ  = "EknzKAAkFzbD1mY7ovWZVtuFptgetn5yw99LSqfE6XH9"
GWQWY = "GwqwyQqJ5kr3X7iUDQKgJ1FJYjxmCieiY5PikmMbsL1Q"
CLOCK = "SysvarC1ock11111111111111111111111111111111"
RENT  = "SysvarRent111111111111111111111111111111111"
TOKEN = "TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA"
PYTH  = "FsJ3A3u2vn5cTVofAjvy6y5kwABJAqYWpe4975bi2epH"
LOR_PROG = "GMjBguH3ceg9wAHEMdY5iZnvzY6CgBACBDvkWmjR7upS"
LOR_ID   = "GF9WfLuj8XYepJr5Dhw7aE3BqmvBPGv4x56kywZqHp6v"

def A(pk, signer=False, writable=False): return {"pk": pk, "signer": signer, "writable": writable}
TAIL = [A(CLOCK), A(RENT), A(TOKEN), A(PYTH), A(LOR_PROG), A(LOR_ID)]

CASES = [
    ("main-baseline", PROG_MAIN, "GaX5diaQz7imMTeNYs5LPAHX6Hq1vKtxjBYzLkjXipMh",
     "E4v1BBgoso9s64TQvmyownAVJbhbEPGyzA3qn4n46qj9", "7aRo8AYpnx2k2WKaYCkJgY7fgTVUeomQPkqQY3Apni2b",
     "5geyZJdffDBNoMqEbogbPvdgH9ue7NREobtW8M3C1qfe", EKNZ, True, EKNZ),
    ("aux-baseline", PROG_AUX, "6P4bZnbS8oSCsdUkK6zQCHfSAW9aREFF5F7k61rS4noP",
     "Gnt27xtC473ZT2Mw5u8wZ68Z3gULkSTb5DuxJy7eJotD", "7RhdnRymb4TqTYLM5bH7cALj86EZX2sFxH8KYUbhUmLB",
     "5enDUZdptakV39Sra9QQYBstJbLVZHHqT74CgeL2fMqV", EKNZ, True, EKNZ),
    ("aux-mismatch-market", PROG_AUX, "6P4bZnbS8oSCsdUkK6zQCHfSAW9aREFF5F7k61rS4noP",
     "Gnt27xtC473ZT2Mw5u8wZ68Z3gULkSTb5DuxJy7eJotD", "7RhdnRymb4TqTYLM5bH7cALj86EZX2sFxH8KYUbhUmLB",
     "5abm8NyiDikUaG262iEr76UE8X7M9UsmqgZW2ouNLNDZ", EKNZ, True, EKNZ),
    ("aux-owner-not-signer", PROG_AUX, "6P4bZnbS8oSCsdUkK6zQCHfSAW9aREFF5F7k61rS4noP",
     "Gnt27xtC473ZT2Mw5u8wZ68Z3gULkSTb5DuxJy7eJotD", "7RhdnRymb4TqTYLM5bH7cALj86EZX2sFxH8KYUbhUmLB",
     "5enDUZdptakV39Sra9QQYBstJbLVZHHqT74CgeL2fMqV", EKNZ, False, GWQWY),
]

def main():
    outdir = sys.argv[1] if len(sys.argv) > 1 else "ci-out"
    os.makedirs(outdir, exist_ok=True)
    results = {}
    for name, prog, reserve, p1, p2, market, owner, signer, payer in CASES:
        ixs = [
            {"program": prog, "data": "03",
             "accounts": [A(reserve, writable=True), A(p1), A(p2)]},
            {"program": prog, "data": "0e01" + "00" * 200,
             "accounts": [A(market), A(owner, signer=signer), A(reserve, writable=True)] + TAIL},
        ]
        import time
        time.sleep(3)
        v = simulate(ixs, payer)
        logs = (v or {}).get("logs") or []
        err = (v or {}).get("err")
        results[name] = {"err": err, "logs": logs, "payer": payer, "market": market, "ownerSigner": signer}
        print(f"===== {name} =====", flush=True)
        print("err:", json.dumps(err), flush=True)
        for l in logs: print(l, flush=True)
        print(flush=True)
    with open(os.path.join(outdir, "sim-results.json"), "w") as f:
        json.dump(results, f, indent=1)
    return results

if __name__ == "__main__":
    main()
