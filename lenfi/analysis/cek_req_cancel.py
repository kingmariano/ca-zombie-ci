#!/usr/bin/env python3
"""CEK proof (aiken) of the Request validator funding window.

Deployed request_v1 script (0a5abd03...) params: lenderNftCs=42f0e370, borrowersNftCs=21ca2902,
collateralSc = script 2d75e5cf + stake key 69962602. Live request 7ce85454ef41#2 (exp 2023-09-13).

Cases:
 R1 funding with tx range entirely BEFORE requestExpiration -> expect ACCEPT
 R2 funding with tx range after expiry -> expect REJECT
"""
import json, sys, os, subprocess, hashlib
sys.setrecursionlimit(300000)
import uplc, uplc.ast as A

HERE = os.path.dirname(os.path.abspath(__file__))
AIKEN = os.environ.get("AIKEN_BIN", "aiken")
LENDER_CS = bytes.fromhex("42f0e3706d2e0a0761db8da21387aadabe609a7cf328d249ebc2eeff")
COLL_SCRIPT = bytes.fromhex("2d75e5cf11622d5f68e2b2ef5be50f0027bb7d485e98c881e665676c")
STAKE_KEY = bytes.fromhex("69962602a7025d4163233855c5a379313b27239b8623ad53540815cb")
REQ_SCRIPT = bytes.fromhex("0a5abd03628e0308b63abe546c0d3bd8969faaf46b98d082808b8059")


def C(i, *fs): return A.PlutusConstr(i, list(fs))
def B(x): return A.PlutusByteString(x)
def I(n): return A.PlutusInteger(n)
def L(*xs): return A.PlutusList(list(xs))
def MP(d): return A.PlutusMap(d)
def Just(x): return C(0, x)
def Nothing(): return C(1)
def bool_(b): return C(0) if b else C(1)
def value_map(entries):
    by = {}
    for (pol, name), amt in entries.items():
        by.setdefault(pol, {})[name] = amt
    return MP({B(p): MP({B(n): I(v) for n, v in t.items()}) for p, t in by.items()})
def tx_id(h): return C(0, B(h))
def tx_out_ref(txid, idx): return C(0, tx_id(txid), I(idx))
def cred_pkh(h): return C(0, B(h))
def cred_script(h): return C(1, B(h))
def address(cred, stake=None): return C(0, cred, Nothing() if stake is None else Just(C(0, stake)))
def tx_out(addr, val, datum_hash=None): return C(0, addr, val, Nothing() if datum_hash is None else Just(B(datum_hash)))
def tx_in_info(ref, out): return C(0, ref, out)
def iv_between(a, b): return C(0, C(0, C(1, I(a)), bool_(True)), C(0, C(1, I(b)), bool_(True)))
def tx_info(inputs, outputs, fee, mint, range_, signatories, datums, txid):
    return C(0, L(*inputs), L(*outputs), fee, mint, L(), L(), range_,
             L(*[B(s) for s in signatories]),
             L(*[C(0, B(dh), dat) for dh, dat in datums]), tx_id(txid))
def spend_ctx(txinfo, ref): return C(0, txinfo, C(1, ref))
def run(label, script_hex, args):
    cmd = [AIKEN, "uplc", "eval", "-c", script_hex] + [uplc.dumps(x) for x in args]
    p = subprocess.run(cmd, capture_output=True, text=True, timeout=1800)
    ok = p.returncode == 0
    out = (p.stdout or p.stderr).replace("\n", " | ")[:200]
    print(f"--- {label}: {'ACCEPT' if ok else 'REJECT'}  {out[:140]}")
    return ok



rows = json.load(open(f"{HERE}/live_utxos_classified.json"))
live = [r for r in rows if r["tx"].startswith("7ce85454ef41") and r["ix"] == 2][0]
LD = live["loan"]
REQ_ADDR = address(cred_script(REQ_SCRIPT), stake=cred_pkh(STAKE_KEY))
req_ref = tx_out_ref(bytes.fromhex(live["tx"]), live["ix"])
req_datum = C(0, B(bytes.fromhex(LD["borrowersNftTn"])), addr_data(LD["borrowersAddress"]),
              ac(LD["loan_asset"]), I(LD["loanAmnt"]), ac(LD["interest_asset"]), I(LD["interestAmnt"]),
              ac(LD["collateral_asset"]), I(LD["collateralAmnt"]), I(LD["loanDuration_ms"]),
              B(bytes.fromhex(LD["liquidateNft_cs"])), I(LD["collateralFactor"]), I(LD["liquidationCommission"]),
              I(LD["requestExpiration_ms"]), B(bytes.fromhex(LD["lenderNftTn"])), I(LD["lendDate_ms"] or 0))
print("datum fields:", len(req_datum.fields), "borrowersNftTn len", len(LD["borrowersNftTn"])//2)
DH = bytes.fromhex("c1"*32)
req_utxo = tx_in_info(req_ref, tx_out(REQ_ADDR, value_map({(b"",b""): int(live["ada"]*1e6)}), datum_hash=DH))
mint = value_map({(BORROWER_CS, bytes.fromhex(LD["borrowersNftTn"])): -1})
ti = tx_info([req_utxo], [tx_out(address(cred_pkh(bytes.fromhex("aa"*28))), value_map({(b"",b""): 2_000_000}))],
             value_map({(b"",b""): 200_000}), mint, iv_between(1_600_000_000_000, 1_900_000_000_000), [], [(DH, req_datum)], bytes.fromhex("dd"*32))
run("CANCEL branch (burn borrower NFT)", f"{HERE}/script_request_v1.hex", [req_datum, B(bytes.fromhex(LD["borrowersNftTn"])), spend_ctx(ti, req_ref)])
