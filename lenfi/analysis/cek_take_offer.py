#!/usr/bin/env python3
"""Chain-native proof that an unprivileged taker can spend a live debt_request_v2 offer.

Uses the DEPLOYED debt_request_v2 validator (script 34c3e3c6...) and the real live datum/value of
offer b3af08003e51#1 (loan SNEK 100,000 for >= 250 ADA collateral, expired 2023-08).
Evaluated with aiken's CEK machine (no chain interaction).
"""
import json, sys, os, subprocess
sys.setrecursionlimit(300000)
import uplc, uplc.ast as A

HERE = os.path.dirname(os.path.abspath(__file__))
AIKEN = os.environ.get("AIKEN_BIN", "aiken")
D = HERE

# params extracted from the on-chain debt_request_v2 script (uplc_constants_full.json)
BORROWER_CS = bytes.fromhex("21ca2902ad0406bc2ce361ad91157b3542544d86d4e3d3e3c43f1763")
LENDER_CS = bytes.fromhex("42f0e3706d2e0a0761db8da21387aadabe609a7cf328d249ebc2eeff")
COLLATERAL_SCRIPT = bytes.fromhex("31e7527a2972e83de4e4a77750a8acf8225b8247e86d4c400d4a2651")
STAKE_KEY = bytes.fromhex("69962602a7025d4163233855c5a379313b27239b8623ad53540815cb")


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
def interval_from(t): return C(0, C(0, C(1, I(t)), bool_(True)), C(0, C(2), bool_(True)))
def tx_info(inputs, outputs, fee, mint, range_, signatories, datums, txid):
    return C(0, L(*inputs), L(*outputs), fee, mint, L(), L(), range_,
             L(*[B(s) for s in signatories]),
             L(*[C(0, B(dh), dat) for dh, dat in datums]), tx_id(txid))
def spend_ctx(txinfo, ref): return C(0, txinfo, C(1, ref))


rows = json.load(open(f"{D}/live_utxos_classified.json"))
live = [r for r in rows if r["tx"].startswith("b3af08003e51") and r["ix"] == 1][0]
Lv = live["loan"]
print("live offer:", live["tx"][:16], "#", live["ix"], "ada", live["ada"], "assets", live["assets"])
print("datum:", json.dumps({k: (v if not isinstance(v, list) else v) for k, v in Lv.items()})[:500])

# real datum fields
def ac(pair):
    cs, tn = pair
    return C(0, B(bytes.fromhex(cs)), B(bytes.fromhex(tn)))

def address_data(s):
    # s = "pkh:...(+pkh:...)" as produced by decode_datums2
    parts = s.split("+")
    def cred(x):
        kind, h = x.split(":")
        return cred_pkh(bytes.fromhex(h)) if kind == "pkh" else cred_script(bytes.fromhex(h))
    if len(parts) == 2:
        return address(cred(parts[0]), stake=cred(parts[1]))
    return address(cred(parts[0]))

borrowers_addr = address_data(Lv["borrowersAddress"])
loan_ac = ac(Lv["loan_asset"])
coll_ac = ac(Lv["collateral_asset"])
int_ac = ac(Lv["interest_asset"])

TAKER = address(cred_pkh(bytes.fromhex("aa" * 28)))
COLL_ADDR = address(cred_script(COLLATERAL_SCRIPT), stake=cred_pkh(STAKE_KEY))

# offer UTxO (real-ish value: 100,000 SNEK + 1.32 ADA) with its real datum hash (we can choose any hash in CEK)
DR_REF = tx_out_ref(bytes.fromhex(live["tx"]), 1)
DR_VALUE = value_map({(b"", b""): int(live["ada"] * 1e6),
                      (bytes.fromhex("279c909f348e533da5808898f87f9a14bb2c3dfbbacccd631d927a3f"),
                       bytes.fromhex("534e454b")): 100_000})
DR_DATUM_HASH = bytes.fromhex("d1" * 32)
dr_utxo = tx_in_info(DR_REF, tx_out(COLL_ADDR if False else address(cred_script(bytes.fromhex("34c3e3c66dd2bfcfc2b538c596fa976d3e9be6d5c549d9da8ec28777")), stake=cred_pkh(STAKE_KEY)),
                                     DR_VALUE, datum_hash=DR_DATUM_HASH))

# taker UTxO (key address, holds 250 ADA to use as collateral + fees)
taker_ref = tx_out_ref(bytes.fromhex("ee" * 32), 0)
taker_utxo = tx_in_info(taker_ref, tx_out(TAKER, value_map({(b"", b""): 260_000_000})))

# borrower NFT to mint: name = sha256(idx || txid) of a UTxO the taker consumes (taker_ref idx 0)
import hashlib
borrower_tn = hashlib.sha256(bytes([0]) + bytes.fromhex("ee" * 32)).digest()

# expected new collateral datum (built exactly as the validator does), lendDate = lower bound of interval
LOWER = 1_700_000_000_000  # ms, > requestExpiration of b3af0800 (1691459700000) and < now
updated_collateral = 250_000_000
coll_datum = C(0,
    B(borrower_tn), borrowers_addr, loan_ac, I(Lv["loanAmnt"]), int_ac, I(Lv["interestAmnt"]),
    coll_ac, I(updated_collateral), I(Lv["loanDuration_ms"]), B(bytes.fromhex(Lv["liquidateNft_cs"])),
    I(Lv["collateralFactor"]), I(Lv["liquidationCommission"]), I(Lv["requestExpiration_ms"]),
    B(bytes.fromhex(Lv["lenderNftTn"])), I(LOWER))
COLL_DATUM_HASH = bytes.fromhex("d2" * 32)

coll_out = tx_out(COLL_ADDR, value_map({(b"", b""): updated_collateral}), datum_hash=COLL_DATUM_HASH)
# what the taker keeps: the offer's value (100k SNEK + 1.32 ADA) minus fees (kept by taker implicitly)
taker_out = tx_out(TAKER, value_map({(b"", b""): 5_000_000,
                                     (bytes.fromhex("279c909f348e533da5808898f87f9a14bb2c3dfbbacccd631d927a3f"),
                                      bytes.fromhex("534e454b")): 100_000}))

# datum for the offer (real live one)
dr_datum = C(0,
    B(bytes.fromhex(Lv["borrowersNftTn"] if Lv["borrowersNftTn"] != "ff" else "ff")),
    borrowers_addr, loan_ac, I(Lv["loanAmnt"]), int_ac, I(Lv["interestAmnt"]),
    coll_ac, I(Lv["collateralAmnt"]), I(Lv["loanDuration_ms"]),
    B(bytes.fromhex(Lv["liquidateNft_cs"] or "")), I(Lv["collateralFactor"]), I(Lv["liquidationCommission"]),
    I(Lv["requestExpiration_ms"]), B(bytes.fromhex(Lv["lenderNftTn"])), I(Lv["lendDate_ms"] or 0))

ti = tx_info([dr_utxo, taker_utxo], [coll_out, taker_out],
             value_map({(b"", b""): 200_000}),
             value_map({(BORROWER_CS, borrower_tn): 1}),
             interval_from(LOWER), [], [(DR_DATUM_HASH, dr_datum), (COLL_DATUM_HASH, coll_datum)],
             bytes.fromhex("ab" * 32))
ctx = spend_ctx(ti, DR_REF)
redeemer = C(0, B(borrower_tn))   # DebtRequestRedeemer.TakeLoan tn

arg_strings = [uplc.dumps(x) for x in (dr_datum, redeemer, ctx)]
print("arg sizes:", [len(s) for s in arg_strings])
cmd = [AIKEN, "uplc", "eval", "-c", f"{D}/script_debt_request_v2.hex"] + arg_strings
p = subprocess.run(cmd, capture_output=True, text=True, timeout=1800)
print("rc:", p.returncode)
print((p.stdout or p.stderr)[:2000])
res = {"case": "take live under-collateralized debt_request_v2 offer (b3af0800#1) as unprivileged taker",
       "expect": "ACCEPT", "got": "ACCEPT" if p.returncode == 0 else "REJECT",
       "pass": p.returncode == 0, "detail": (p.stdout or p.stderr)[:800]}
json.dump(res, open(f"{D}/../ci-out/cek_take_offer.json", "w"), indent=1)
