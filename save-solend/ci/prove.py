#!/usr/bin/env python3
"""Solend v1 read-only simulation prover (pure stdlib; public RPC; no keys).

Proves on-chain, via simulateTransaction:
  1) which reserves can be refreshed today (i.e. have a live oracle per program gates)
  2) program-computed obligation health for sampled positions (refresh + refresh_obligation)

Writes results to ci-out/. Never signs or sends a transaction.
"""
import json, base64, time, urllib.request, os, sys

RPC_LIST = ["https://api.mainnet-beta.solana.com", "https://solana-rpc.publicnode.com"]
PROGRAM = "So1endDq2YkqhipRh3WViPa8hdiSpxWy6z3Z6tMCpAo"
NULLPK = "11111111111111111111111111111111"
PAYER = "5pHk2TmnqQzRF9L6egy5FfiyBgS7G9cMZ5RFaJAvghzw"
IX_REFRESH_RESERVE = 3
IX_REFRESH_OBLIGATION = 7
_rpc_i = [0]

def rpc(method, params, retries=8, timeout=240):
    body = json.dumps({"jsonrpc": "2.0", "id": 1, "method": method, "params": params}).encode()
    delay = 1.0
    for t in range(retries):
        url = RPC_LIST[_rpc_i[0] % len(RPC_LIST)]
        try:
            req = urllib.request.Request(url, data=body, headers={"Content-Type": "application/json"})
            out = json.load(urllib.request.urlopen(req, timeout=timeout))
            if "error" in out:
                raise RuntimeError(str(out["error"])[:160])
            return out["result"]
        except Exception:
            if t == retries - 1:
                raise
            _rpc_i[0] += 1
            time.sleep(delay); delay *= 1.6

ALPH = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"
def b58dec(s):
    n = 0
    for c in s:
        n = n * 58 + ALPH.index(c)
    out = n.to_bytes(32, "big") if n else b"\0" * 32
    pad = 0
    for c in s:
        if c == "1": pad += 1
        else: break
    return b"\0" * pad + out[len(out) - (32 - pad):] if pad else out

def compact_u16(n):
    out = bytearray()
    while True:
        b = n & 0x7F
        n >>= 7
        if n:
            out.append(b | 0x80)
        else:
            out.append(b)
            return bytes(out)

def build_tx(ixs, blockhash):
    """ixs: list of (program_id_str, [ (pubkey_str, is_writable, is_signer) ], data_bytes)"""
    keys = [PAYER]
    signer_set = {PAYER}
    key_index = {PAYER: 0}
    readonly_unsigned = set()
    for prog, accts, data in ixs:
        for pk, wr, sg in [(prog, False, False)] + accts:
            if pk not in key_index:
                key_index[pk] = len(keys)
                keys.append(pk)
                if sg:
                    signer_set.add(pk)
            if not wr and not sg:
                readonly_unsigned.add(pk)
    # message layout requires: signers, then writable non-signers, then readonly non-signers
    n_sig = len([k for k in keys if k in signer_set])
    writable_ns = [k for k in keys if k not in signer_set and k not in readonly_unsigned]
    readonly_ns = [k for k in keys if k not in signer_set and k in readonly_unsigned]
    ordered = [k for k in keys if k in signer_set] + writable_ns + readonly_ns
    idx = {k: i for i, k in enumerate(ordered)}
    n_ro_signed = 0
    n_ro_unsigned = len([k for k in ordered if k not in signer_set and k in readonly_unsigned])
    header = bytes([n_sig, n_ro_signed, n_ro_unsigned])
    msg = bytearray()
    msg += header
    msg += compact_u16(len(ordered))
    for k in ordered:
        msg += b58dec(k)
    msg += b58dec(blockhash)
    msg += compact_u16(len(ixs))
    for prog, accts, data in ixs:
        msg += bytes([idx[prog]])
        msg += compact_u16(len(accts))
        for pk, wr, sg in accts:
            msg += bytes([idx[pk]])
        msg += compact_u16(len(data))
        msg += data
    tx = bytearray()
    tx += compact_u16(n_sig)
    tx += b"\0" * (64 * n_sig)
    tx += msg
    return base64.b64encode(bytes(tx)).decode()

def simulate(ixs, blockhash, return_accounts):
    tx64 = build_tx(ixs, blockhash)
    params = [tx64, {"encoding": "base64", "sigVerify": False, "replaceRecentBlockhash": True,
                     "commitment": "processed",
                     "accounts": {"encoding": "base64", "addresses": return_accounts}}]
    res = rpc("simulateTransaction", params)
    return res

def refresh_ix(reserve, pyth, sb, extra):
    accts = [(reserve, True, False), (pyth, False, False), (sb, False, False)]
    if extra and extra != NULLPK:
        accts.append((extra, False, False))
    return (PROGRAM, accts, bytes([IX_REFRESH_RESERVE]))

def refresh_obl_ix(obligation, reserves):
    accts = [(obligation, True, False)] + [(r, True, False) for r in reserves]
    return (PROGRAM, accts, bytes([IX_REFRESH_OBLIGATION]))

def u(b, o, n): return int.from_bytes(b[o:o + n], "little")

def decode_reserve_prices(buf):
    return {"marketPriceWads": str(u(buf, 211, 16)), "smoothedPriceWads": str(u(buf, 453, 16)),
            "lastUpdateSlot": u(buf, 1, 8), "staleFlag": buf[9] != 0}

def decode_obl_health(buf):
    return {"borrowedValueWads": str(u(buf, 90, 16)), "allowedBorrowWads": str(u(buf, 106, 16)),
            "unhealthyWads": str(u(buf, 122, 16)), "borrowedUbWads": str(u(buf, 138, 16)),
            "superUnhealthyWads": str(u(buf, 155, 16)), "closeable": buf[187] != 0,
            "nDep": buf[202], "nBor": buf[203]}

def main():
    here = os.path.dirname(os.path.abspath(__file__))
    root = os.path.dirname(here)
    outp = os.path.join(root, "ci-out")
    os.makedirs(outp, exist_ok=True)
    reserves = json.load(open(os.path.join(root, "analysis", "reserves.json")))
    proof_obls = json.load(open(os.path.join(root, "analysis", "proof-obligations.json")))
    blockhash = rpc("getLatestBlockhash", [{"commitment": "processed"}])["value"]["blockhash"]
    slot0 = rpc("getSlot", [{"commitment": "processed"}])

    # 1) refresh_reserve simulation for every reserve
    results = []
    for i, r in enumerate(reserves):
        pyth = r["pythOracle"] if r["pythOracle"] != NULLPK else NULLPK
        sb = r["switchboardOracle"] if r["switchboardOracle"] != NULLPK else NULLPK
        extra = r.get("extraOracle")
        ix = refresh_ix(r["reserve"], pyth, sb, extra)
        try:
            sim = simulate([ix], blockhash, [r["reserve"]])
            v = sim["value"]
            rec = {"reserve": r["reserve"], "market": r["market"], "symbol": r.get("symbol"),
                   "ok": v.get("err") is None, "err": v.get("err"), "units": v.get("unitsConsumed")}
            if v.get("err") is None and v.get("accounts") and v["accounts"][0]:
                buf = base64.b64decode(v["accounts"][0]["data"][0])
                rec["post"] = decode_reserve_prices(buf)
            results.append(rec)
        except Exception as e:
            results.append({"reserve": r["reserve"], "market": r["market"], "symbol": r.get("symbol"),
                            "ok": False, "rpcError": str(e)[:200]})
        if i % 25 == 0:
            json.dump(results, open(os.path.join(outp, "refresh_sims.json"), "w"), indent=1)
        time.sleep(0.25)
    json.dump(results, open(os.path.join(outp, "refresh_sims.json"), "w"), indent=1)
    ok = sum(1 for x in results if x.get("ok"))
    fails = sum(1 for x in results if not x.get("ok"))
    print(f"[proof] refresh sims: {len(results)} total, {ok} refreshable, {fails} failed")

    # 2) refresh + refresh_obligation simulations for proof obligations -> program-computed health
    obl_results = []
    for ob in proof_obls:
        ixs = []
        for rr in ob["reserves"]:
            ixs.append(refresh_ix(rr["reserve"], rr.get("pythOracle") or NULLPK,
                                  rr.get("switchboardOracle") or NULLPK, rr.get("extraOracle")))
        ixs.append(refresh_obl_ix(ob["obligation"], [rr["reserve"] for rr in ob["reserves"]]))
        try:
            sim = simulate(ixs, blockhash, [ob["obligation"]])
            v = sim["value"]
            rec = {"obligation": ob["obligation"], "label": ob.get("label"),
                   "ok": v.get("err") is None, "err": v.get("err"),
                   "logs": (v.get("logs") or [])[-6:]}
            if v.get("err") is None and v.get("accounts") and v["accounts"][0]:
                buf = base64.b64decode(v["accounts"][0]["data"][0])
                rec["health"] = decode_obl_health(buf)
                bv = u(buf, 90, 16) / 1e18; uh = u(buf, 122, 16) / 1e18
                rec["liquidatable"] = uh > 0 and bv >= uh
                rec["borrowedUsd"] = bv; rec["unhealthyUsd"] = uh
            obl_results.append(rec)
        except Exception as e:
            obl_results.append({"obligation": ob["obligation"], "label": ob.get("label"),
                                "ok": False, "rpcError": str(e)[:200]})
        time.sleep(0.4)
    json.dump(obl_results, open(os.path.join(outp, "obligation_health.json"), "w"), indent=1)
    for r in obl_results:
        print(f"[proof] obligation {str(r.get('label'))[:28]:28} ok={r.get('ok')} liquidatable={r.get('liquidatable')} "
              f"borrowed=${r.get('borrowedUsd', 0):,.0f} unhealthy=${r.get('unhealthyUsd', 0):,.0f}")

    summary = {"slotAtRun": slot0, "refreshTotal": len(results), "refreshOk": ok, "refreshFailed": fails,
               "obligationsTested": len(obl_results),
               "obligationsLiquidatable": sum(1 for r in obl_results if r.get("liquidatable")),
               "keyChecks": {
                   "mainSolRefreshable": any(x["reserve"] == "8PbodeaosQP19SjYFx855UMqWxH2HynZLdBXmsrbac36" and x.get("ok") for x in results),
                   "scarcCoinAnyRefreshable": any(x.get("ok") and x.get("market") == "E2PfMAjUWkTZG81nWY9bm1DRi72uZkfL79RWrRxVWw6s" for x in results),
               }}
    json.dump(summary, open(os.path.join(outp, "SUMMARY.json"), "w"), indent=1)
    print("[proof] SUMMARY:", json.dumps(summary))
    # fail the CI job if the key facts we assert do not reproduce
    assert summary["refreshTotal"] >= 600, "reserve enumeration incomplete"
    assert summary["refreshOk"] > 100, "expected >100 refreshable reserves"
    assert summary["keyChecks"]["mainSolRefreshable"], "main SOL reserve must be refreshable"
    print("[proof] OK")

if __name__ == "__main__":
    main()
