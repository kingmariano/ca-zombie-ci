#!/usr/bin/env python3
"""Bisect CEK evaluation of debt_request_v2: (a) Cancel branch with exact lender-NFT burn,
(b) TakeLoan branch with a constructed context. Prints which trace/error appears."""
import json, sys, os, subprocess, hashlib
sys.setrecursionlimit(300000)
import uplc, uplc.ast as A

HERE = os.path.dirname(os.path.abspath(__file__))
AIKEN = os.environ.get("AIKEN_BIN", "aiken")
BORROWER_CS = bytes.fromhex("21ca2902ad0406bc2ce361ad91157b3542544d86d4e3d3e3c43f1763")
LENDER_CS = bytes.fromhex("42f0e3706d2e0a0761db8da21387aadabe609a7cf328d249ebc2eeff")
COLL_SCRIPT = bytes.fromhex("31e7527a2972e83de4e4a77750a8acf8225b8247e86d4c400d4a2651")
STAKE_KEY = bytes.fromhex("69962602a7025d4163233855c5a379313b27239b8623ad53540815cb")
DR_SCRIPT = bytes.fromhex("34c3e3c66dd2bfcfc2b538c596fa976d3e9be6d5c549d9da8ec28777")


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
def iv_from(t): return C(0, C(0, C(0, I(t)), bool_(True)), C(0, C(2), bool_(True)))
def tx_info(inputs, outputs, fee, mint, range_, signatories, datums, txid):
    return C(0, L(*inputs), L(*outputs), fee, mint, L(), L(), range_,
             L(*[B(s) for s in signatories]),
             L(*[C(0, B(dh), dat) for dh, dat in datums]), tx_id(txid))
def spend_ctx(txinfo, ref): return C(0, txinfo, C(1, ref))


live = [r for r in json.load(open(f"{HERE}/live_utxos_classified.json"))
        if r["tx"].startswith("b3af08003e51") and r["ix"] == 1][0]
Lv = live["loan"]
def ac(pair): return C(0, B(bytes.fromhex(pair[0])), B(bytes.fromhex(pair[1])))
def addr_data(s):
    parts = s.split("+")
    def cred(x):
        kind, h = x.split(":")
        return cred_pkh(bytes.fromhex(h)) if kind == "pkh" else cred_script(bytes.fromhex(h))
    return address(cred(parts[0]), stake=cred(parts[1])) if len(parts) == 2 else address(cred(parts[0]))

borrowers_addr = addr_data(Lv["borrowersAddress"])
DR_ADDR = address(cred_script(DR_SCRIPT), stake=cred_pkh(STAKE_KEY))
DR_REF = tx_out_ref(bytes.fromhex(live["tx"]), 1)
DR_VALUE = value_map({(b"", b""): int(live["ada"] * 1e6),
                      (bytes.fromhex("279c909f348e533da5808898f87f9a14bb2c3dfbbacccd631d927a3f"),
                       bytes.fromhex("534e454b")): 100_000})
DH = bytes.fromhex("d1" * 32)
dr_utxo = tx_in_info(DR_REF, tx_out(DR_ADDR, DR_VALUE, datum_hash=DH))
dr_datum = C(0, B(bytes.fromhex(Lv["borrowersNftTn"])), borrowers_addr,
             ac(Lv["loan_asset"]), I(Lv["loanAmnt"]), ac(Lv["interest_asset"]), I(Lv["interestAmnt"]),
             ac(Lv["collateral_asset"]), I(Lv["collateralAmnt"]), I(Lv["loanDuration_ms"]),
             B(bytes.fromhex(Lv["liquidateNft_cs"] or "")), I(Lv["collateralFactor"]),
             I(Lv["liquidationCommission"]), I(Lv["requestExpiration_ms"]),
             B(bytes.fromhex(Lv["lenderNftTn"])), I(Lv["lendDate_ms"] or 0))

TAKER = address(cred_pkh(bytes.fromhex("aa" * 28)))
taker_ref = tx_out_ref(bytes.fromhex("ee" * 32), 0)
taker_in = tx_in_info(taker_ref, tx_out(TAKER, value_map({(b"", b""): 300_000_000})))
borrower_tn = hashlib.sha256(bytes([0]) + bytes.fromhex("ee" * 32)).digest()
COLL_ADDR = address(cred_script(COLL_SCRIPT), stake=cred_pkh(STAKE_KEY))


def run(label, datum, redeemer, tin, expect_accept=None):
    ctx = spend_ctx(tin, DR_REF)
    args = [uplc.dumps(x) for x in (datum, redeemer, ctx)]
    cmd = [AIKEN, "uplc", "eval", "-c", f"{HERE}/script_debt_request_v2.hex"] + args
    p = subprocess.run(cmd, capture_output=True, text=True, timeout=1800)
    out = (p.stdout or p.stderr)
    print(f"--- {label}: rc={p.returncode} {'ACCEPT' if p.returncode==0 else 'REJECT'}")
    print("    " + out.replace("\n", " | ")[:400])
    return p.returncode == 0


# (a) Cancel branch: burn exactly (LENDER_CS, lenderNftTn)
mint_ok = value_map({(LENDER_CS, bytes.fromhex(Lv["lenderNftTn"])): -1})
tin_cancel = tx_info([dr_utxo, taker_in], [tx_out(TAKER, value_map({(b"", b""): 5_000_000}))],
                     value_map({(b"", b""): 200_000}), mint_ok, iv_from(1_800_000_000_000), [], [(DH, dr_datum)],
                     bytes.fromhex("ab" * 32))
run("(a) Cancel + exact lender-NFT burn -1", dr_datum, C(1), tin_cancel)

# (a2) Cancel with wrong burn -> REJECT
mint_bad = value_map({(LENDER_CS, bytes.fromhex("11" * 32)): -1})
tin_cancel2 = tx_info([dr_utxo, taker_in], [tx_out(TAKER, value_map({(b"", b""): 5_000_000}))],
                      value_map({(b"", b""): 200_000}), mint_bad, iv_from(1_800_000_000_000), [], [(DH, dr_datum)],
                      bytes.fromhex("ab" * 32))
run("(a2) Cancel + wrong burn", dr_datum, C(1), tin_cancel2)

# (b) TakeLoan: collateral output needs >= 250 ADA + matching expected datum
LOWER = 1_700_000_000_000
coll_datum = C(0, B(borrower_tn), borrowers_addr,
               ac(Lv["loan_asset"]), I(Lv["loanAmnt"]), ac(Lv["interest_asset"]), I(Lv["interestAmnt"]),
               ac(Lv["collateral_asset"]), I(250_000_000), I(Lv["loanDuration_ms"]),
               B(bytes.fromhex(Lv["liquidateNft_cs"] or "")), I(Lv["collateralFactor"]),
               I(Lv["liquidationCommission"]), I(Lv["requestExpiration_ms"]),
               B(bytes.fromhex(Lv["lenderNftTn"])), I(LOWER))
COLL_DH = bytes.fromhex("d2" * 32)
coll_out = tx_out(COLL_ADDR, value_map({(b"", b""): 250_000_000}), datum_hash=COLL_DH)
taker_out = tx_out(TAKER, value_map({(b"", b""): 10_000_000,
                                     (bytes.fromhex("279c909f348e533da5808898f87f9a14bb2c3dfbbacccd631d927a3f"),
                                      bytes.fromhex("534e454b")): 100_000}))
mint_take = value_map({(BORROWER_CS, borrower_tn): 1})
tin_take = tx_info([dr_utxo, taker_in], [coll_out, taker_out], value_map({(b"", b""): 200_000}), mint_take,
                   iv_from(LOWER), [], [(DH, dr_datum), (COLL_DH, coll_datum)], bytes.fromhex("ac" * 32))
run("(b) TakeLoan (baseline)", dr_datum, C(0, B(borrower_tn)), tin_take)


# (c) TakeLoan with interval ENTIRELY BEFORE expiry: [1.60e12, 1.690e12]
def iv_between(a, b): return C(0, C(0, C(0, I(a)), bool_(True)), C(0, C(0, I(b)), bool_(True)))
tin_take_c = tx_info([dr_utxo, taker_in], [coll_out, taker_out], value_map({(b"", b""): 200_000}), mint_take,
                     iv_between(1_600_000_000_000, 1_690_000_000_000), [], [(DH, dr_datum), (COLL_DH, coll_datum)], bytes.fromhex("ad" * 32))
run("(c) TakeLoan with interval entirely BEFORE requestExpiration", dr_datum, C(0, B(borrower_tn)), tin_take_c)

# (d) TakeLoan with interval AFTER expiry but finite upper bound
tin_take_d = tx_info([dr_utxo, taker_in], [coll_out, taker_out], value_map({(b"", b""): 200_000}), mint_take,
                     iv_between(1_700_000_000_000, 1_900_000_000_000), [], [(DH, dr_datum), (COLL_DH, coll_datum)], bytes.fromhex("ae" * 32))
run("(d) TakeLoan with interval AFTER requestExpiration", dr_datum, C(0, B(borrower_tn)), tin_take_d)
