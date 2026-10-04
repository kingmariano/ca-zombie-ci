#!/usr/bin/env python3
"""Npm-free read-only PoC for H-29 (Francium).

Builds legacy Solana transactions by hand and calls simulateTransaction with
sigVerify:false. No transaction is ever signed with a real key or broadcast.

Cases (strategy 34eXEXyp SOL-USDC, deployed lyf-raydium program):
  CONTROL : signer = position owner, destinations = owner's USDC+wSOL ATAs
  ATTACK-A: signer = unrelated wallet, destinations = position owner's ATAs
  ATTACK-B: signer = unrelated wallet, destinations = unrelated wallet's ATAs
Expected: CONTROL reaches handler -> InvalidData 6004; ATTACK-A -> 6027
NeedUserOrAdminPermission; ATTACK-B -> 2003 ConstraintRaw on user_tkn_account_0.
"""
import json, sys, os, time, urllib.request
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from rpc import rpc_call, batch

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)

ALPH = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"
def b58enc(b):
    n = int.from_bytes(b, "big"); s = ""
    while n:
        n, r = divmod(n, 58); s = ALPH[r] + s
    pad = 0
    for c in b:
        if c == 0: pad += 1
        else: break
    return "1" * pad + s

def b58dec(s):
    n = 0
    for ch in s:
        n = n * 58 + ALPH.index(ch)
    raw = n.to_bytes((n.bit_length() + 7) // 8, "big")
    pad = 0
    for ch in s:
        if ch == "1": pad += 1
        else: break
    return b"\x00" * pad + raw

def shortvec(n):
    out = b""
    while True:
        b = n & 0x7F
        n >>= 7
        if n:
            out += bytes([b | 0x80])
        else:
            out += bytes([b]); break
    return out

RAY_PROG = "2nAAsYdXF3eTQzaeUQS3fr4o782dDg8L28mX39Wr5j8N"
TOKEN = "TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA"
AMM_AUTHORITY = "5Q544fKrFoe6tsEbD7S8EmxGTJYAKtTVhAW5Q5pge4j1"
FEE_PAYER = "6M1rN486dffB6d7q35qdxHLuWUFF9QtbTjLnPtEyRyJd"

S = {
    "strategy": "34eXEXypQiwyQhMRAMbCEJSs16SVaN3C6wzPicEcBTH1",
    "authority": "9Jbh6bcHxgxb7S1FfNjFTUQABmd2cwzHWY3gxG4A2CjD",
    "tkn0": "88NCYVzm9kXCkNFrQgACyeHRnPYWuUKx7ePC4HeTkCps",
    "tkn1": "BCMcGhuqdPZo1LxDqJg9MrDKedvoHd92e67uvtoRhrEn",
    "lp": "7CA2L9UzsA8TCYauvyEqk74cfj9xnW1m3dvEvCF8jJET",
    "ammProg": "675kPX9MHTjS2zt1qfr1NYHuzeLXfQM9H24wFSUt1Mp8",
    "ammId": "58oQChx4yWmvKdwLLZzBi4ChoCc2fqCUWBkwMihLYQo2",
    "openOrders": "HmiHHzq4Fym9e1D4qzLS6LDDM3tNsCTBPDWHTLZ763jY",
    "targetOrders": "CZza3Ej4Mc58MnxWA385itCC9jCo3L1D7zc3LKy1bZMR",
    "baseVault": "DQyrAcCrDXQ7NeoqGgDCZwBvWDcYmFCjSb9JtteuvPpz",
    "quoteVault": "HLmqeL62xR1QoZ1HKKbXRrdN1p3phKpxRMb2VVopvBBz",
    "serumProg": "srmqPvymJeFKQ4zGQed1GFppgkRHL9kaELCbyksJtPX",
    "marketId": "8BnEgHoWFysVcuFFX7QztDmzuH8r5ZFvyP3sYwn1XTh6",
    "bids": "5jWUncPNBMZJ3sTHKmMLszypVkoRK6bfEQMQUHweeQnh",
    "asks": "EaXdHx7x3mdGA38j5RSmKYSXMzAFzzUXCLNBEDXDn1d5",
    "eventQueue": "8CvwxZ9Db6XbLD46NZwwmVDZZRDy7eydFcAGkXKh9axa",
    "serumBase": "CKxTHwM9fPMRRvZmFoFnOqKNd9pQR21c5Aq9bh5h9oghX".replace("FnO", "Fo"),
    "serumQuote": "6A5NHCj1yF6urc9wZNe6Bcjj4LVszQNj5DwAWG97yzMu",
    "vaultSigner": "CTz5UMLQm2SRWHzQnU62Pi4yJqbNGjgRBHqqp6oDHfF7",
}

VICTIM = {"owner": "3CBKizNkCJ6tUNmoe3fi3WdbqxJExrQDRDyGJNUhY48T",
          "userInfo": "5GKggYWTsERBaSx3yTbUay4KmJ24Kpbe91HS6D95fuS",
          "usdc": "6MZVh4nk6evXVTpsRh8BpGHaihN88YKqcZ4dGRFbKYBb",
          "wsol": "5x5juNdvTWaaKk2FpgZaMa5iuvjjSnXkniKsFPtVN2S"}
ATTACKER = {"owner": "6joanWsSEJtQrUXeFg6vHBdJfqh2JQyYw776tgGvPp2o",
            "usdc": "HLGrJ9dT34vmkszRw3HKcBUCJSwWL2MGW9Baw99jCyhs",
            "wsol": "H1mzRoGjxv67Rb2EoYxuCSsKLMYA5FmehsLzWsUQ9Vwy"}

DATA = bytes.fromhex("6f607d39534edca0") + bytes([0])  # legacy selector + withdrawType u8


def build_tx(accounts, data, blockhash):
    """accounts: list of (pubkey, signer, writable); fee payer auto-added as first signer."""
    keys = []  # (pubkey, signer, writable)
    idx = {}
    def add(pk, signer, writable):
        if pk in idx:
            i = idx[pk]
            s, w = keys[i][1], keys[i][2]
            keys[i] = (pk, s or signer, w or writable)
        else:
            idx[pk] = len(keys); keys.append((pk, signer, writable))
    add(FEE_PAYER, True, True)
    for (pk, signer, writable) in accounts:
        add(pk, signer, writable)
    add(RAY_PROG, False, False)  # instruction program id (readonly non-signer)
    # order: signers, writable non-signers, readonly non-signers
    signers = [k for k in keys if k[1]]
    writable = [k for k in keys if not k[1] and k[2]]
    readonly = [k for k in keys if not k[1] and not k[2]]
    ordered = signers + writable + readonly
    pos = {k[0]: i for i, k in enumerate(ordered)}
    n_ro_unsigned = len(readonly)
    header = bytes([len(signers), 0, n_ro_unsigned])
    msg = header + shortvec(len(ordered)) + b"".join(b58dec(k[0]) for k in ordered)
    msg += b58dec(blockhash)
    msg += shortvec(1)
    prog_i = pos[RAY_PROG]
    acct_indices = [pos[pk] for (pk, _, _) in accounts]
    msg += bytes([prog_i]) + shortvec(len(acct_indices)) + bytes(acct_indices)
    msg += shortvec(len(data)) + data
    tx = shortvec(len(signers)) + b"\x00" * (64 * len(signers)) + msg
    return tx


def simulate(accounts, data, watch, label):
    bh = rpc_call("getLatestBlockhash", [{"commitment": "confirmed"}])["value"]["blockhash"]
    tx = build_tx(accounts, data, bh)
    import base64
    cfg = {"encoding": "base64", "sigVerify": False, "replaceRecentBlockhash": True, "commitment": "confirmed"}
    if watch:
        cfg["accounts"] = {"encoding": "base64", "addresses": watch}
    res = rpc_call("simulateTransaction", [base64.b64encode(tx).decode(), cfg])
    v = res["value"]
    print("=" * 88)
    print(f"SIM {label}\n  err={json.dumps(v.get('err'))}  units={v.get('unitsConsumed')}")
    for l in (v.get("logs") or [])[:12]:
        print("   log:", l)
    return {"label": label, "err": v.get("err"), "units": v.get("unitsConsumed"), "logs": v.get("logs")}


def main():
    cases = [
        ("CONTROL: victim signer + victim destinations", VICTIM["owner"], VICTIM["usdc"], VICTIM["wsol"]),
        ("ATTACK-A: unrelated signer + victim destinations", ATTACKER["owner"], VICTIM["usdc"], VICTIM["wsol"]),
        ("ATTACK-B: unrelated signer + unrelated destinations", ATTACKER["owner"], ATTACKER["usdc"], ATTACKER["wsol"]),
    ]
    out = []
    for label, signer, t0, t1 in cases:
        accts = [
            (signer, True, True), (VICTIM["userInfo"], False, True), (t0, False, True), (t1, False, True),
            (S["strategy"], False, True), (S["authority"], False, True), (S["tkn0"], False, True), (S["tkn1"], False, True),
            (S["lp"], False, True), (TOKEN, False, False), (S["ammProg"], False, False), (S["ammId"], False, True),
            (AMM_AUTHORITY, False, True), (S["openOrders"], False, True), (S["targetOrders"], False, True),
            (S["baseVault"], False, True), (S["quoteVault"], False, True), (S["serumProg"], False, False),
            (S["marketId"], False, True), (S["bids"], False, True), (S["asks"], False, True), (S["eventQueue"], False, True),
            (S["serumBase"], False, True), (S["serumQuote"], False, True), (S["vaultSigner"], False, True),
        ]
        out.append(simulate(accts, DATA, [S["strategy"], S["tkn0"], S["tkn1"]], label))
        time.sleep(1.2)
    os.makedirs(os.path.join(ROOT, "ci-out"), exist_ok=True)
    json.dump({"slot": rpc_call("getSlot", []), "cases": out}, open(os.path.join(ROOT, "ci-out", "sim_gate.json"), "w"), indent=1)
    print("\nWrote ci-out/sim_gate.json")


if __name__ == "__main__":
    main()
