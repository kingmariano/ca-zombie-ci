#!/usr/bin/env python3
"""Minimal Solana transaction builder + simulateTransaction harness (read-only; nothing is sent)."""
import base64, json, sys
sys.path.insert(0, "/home/heisenberg/CA/armada/analysis")
from solrpc import rpc, b58decode, b58encode, redact


def shortvec(n: int) -> bytes:
    out = bytearray()
    while True:
        b = n & 0x7F
        n >>= 7
        if n == 0:
            out.append(b)
            return bytes(out)
        out.append(b | 0x80)


def build_message(payer: str, instructions, extra_signers=()):
    """instructions: list of dicts {program_id, accounts:[(pubkey, is_signer, is_writable)], data: bytes}"""
    signers = [payer] + [s for s in extra_signers if s != payer]
    writable_signed, readonly_signed, writable_unsigned, readonly_unsigned = [], [], [], []
    meta = {}  # pubkey -> [is_signer, is_writable]

    def add(pk, signer, writable):
        if pk in meta:
            meta[pk][0] |= signer
            meta[pk][1] |= writable
        else:
            meta[pk] = [signer, writable]

    add(payer, True, True)
    for s in extra_signers:
        add(s, True, False)
    for ix in instructions:
        add(ix["program_id"], False, False)
        for (pk, sg, wr) in ix["accounts"]:
            add(pk, sg, wr)
    ordered = [payer] + [s for s in signers if s != payer]
    rest_w, rest_r = [], []
    for pk, (sg, wr) in meta.items():
        if pk in ordered:
            continue
        (rest_w if wr else rest_r).append(pk)
    keys = ordered + rest_w + rest_r
    num_signed = len(ordered)
    num_ro_signed = 0
    num_ro_unsigned = len(rest_r)
    header = bytes([num_signed, num_ro_signed, num_ro_unsigned])
    idx = {k: i for i, k in enumerate(keys)}
    msg = bytearray(header)
    msg += shortvec(len(keys))
    for k in keys:
        msg += b58decode(k)
    msg += b"\x00" * 32  # placeholder blockhash (replaceRecentBlockhash=true)
    msg += shortvec(len(instructions))
    for ix in instructions:
        accs = []
        for (pk, sg, wr) in ix["accounts"]:
            accs.append(idx[pk])
        msg += bytes([idx[ix["program_id"]]])
        msg += shortvec(len(accs)) + bytes(accs)
        msg += shortvec(len(ix["data"])) + ix["data"]
    return bytes(msg), keys


def simulate(instructions, payer, extra_signers=(), return_accounts=None, inner=True, sig_verify=False):
    msg, keys = build_message(payer, instructions, extra_signers)
    n_sig = 1 + len([s for s in extra_signers if s != payer])
    tx = shortvec(n_sig) + b"\x00" * (64 * n_sig) + msg
    cfg = {"encoding": "base64", "sigVerify": bool(sig_verify), "replaceRecentBlockhash": True,
           "commitment": "processed"}
    if inner:
        cfg["innerInstructions"] = True
    if return_accounts:
        cfg["accounts"] = {"encoding": "base64", "addresses": return_accounts}
    res = rpc("simulateTransaction", [base64.b64encode(tx).decode(), cfg], timeout=90)
    return res


def summarize(res, keys=None):
    if not res:
        return {"error": "null result"}
    v = res.get("value") or {}
    out = {"err": v.get("err"), "unitsConsumed": v.get("unitsConsumed")}
    logs = v.get("logs") or []
    out["logs_tail"] = [l for l in logs[-40:]]
    if v.get("accounts"):
        out["post_accounts"] = [({"pubkey": a.get("pubkey"), "lamports": a.get("lamports"),
                                 "len": (len(base64.b64decode(a["data"][0])) if a.get("data") else None)}
                                if a else None) for a in v["accounts"]]
    return out


if __name__ == "__main__":
    # sanity: transfer 0 lamports from payer to itself via System program
    SYSTEM = "11111111111111111111111111111111"
    payer = sys.argv[1] if len(sys.argv) > 1 else "2xFbZtJjR3szsVXrjVwU35uA9uk35xujNufdUzPFsqFL"
    data = (2).to_bytes(4, "little") + (0).to_bytes(8, "little")  # Transfer {lamports:0}
    ix = {"program_id": SYSTEM, "accounts": [(payer, True, True), (payer, False, True)], "data": data}
    r = simulate([ix], payer)
    print(json.dumps(summarize(r), indent=1)[:1500])
