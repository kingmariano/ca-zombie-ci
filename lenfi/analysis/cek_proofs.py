#!/usr/bin/env python3
"""Lenfi V1 (ex-Aada) — read-only CEK evaluation of DEPLOYED scripts.

Proves, without any chain interaction beyond reading the script bytes:
 1. lender/borrower NFT policy (42f0e370 / 21ca2902): a token name can only be minted if it equals
    sha256(txOutRefIdx || txid) of a UTxO consumed in the same tx  -> names cannot be forged.
 2. interest validator (92862d28): spend is accepted iff the tx's mint field is exactly one burn
    (-1) of (lenderNftCs, datum lenderNftTn); no output/payout checks at all.
 3. liquidation validator (b1259b98): same shape for the borrower NFT.

All constants are mainnet-deployed ones extracted from the on-chain scripts.
"""
import json, sys, hashlib, os
sys.setrecursionlimit(300000)

from uplc import unflatten
from uplc.tools import eval as uplc_eval
import uplc.ast as A

HERE = os.path.dirname(os.path.abspath(__file__))
LENDER_CS = bytes.fromhex("42f0e3706d2e0a0761db8da21387aadabe609a7cf328d249ebc2eeff")
BORROWER_CS = bytes.fromhex("21ca2902ad0406bc2ce361ad91157b3542544d86d4e3d3e3c43f1763")

# ---------------------------------------------------------------- Plutus Data helpers
def C(i, *fs): return A.PlutusConstr(i, list(fs))
def B(x): return A.PlutusByteString(x)
def I(n): return A.PlutusInteger(n)
def L(*xs): return A.PlutusList(list(xs))
def MP(d): return A.PlutusMap(d)
def Just(x): return C(0, x)
def Nothing(): return C(1)
def bool_(b): return C(0) if b else C(1)

def value_map(entries):
    by_pol = {}
    for (pol, name), amt in entries.items():
        by_pol.setdefault(pol, {})[name] = amt
    m = {}
    for pol, toks in by_pol.items():
        m[B(pol)] = MP({B(n): I(v) for n, v in toks.items()})
    return MP(m)

def tx_id(h): return C(0, B(h))
def tx_out_ref(txid, idx): return C(0, tx_id(txid), I(idx))
def cred_pkh(h): return C(0, B(h))
def cred_script(h): return C(1, B(h))
def address(cred, stake=None):
    return C(0, cred, Nothing() if stake is None else Just(C(0, stake)))
def tx_out(addr, val, datum_hash=None):
    return C(0, addr, val, Nothing() if datum_hash is None else Just(B(datum_hash)))
def tx_in_info(ref, out): return C(0, ref, out)
def interval_always():
    # Extended a: NegInf = Constr 0 [], Finite a = Constr 1 [a], PosInf = Constr 2 []
    return C(0, C(0, C(0), bool_(True)), C(0, C(2), bool_(True)))
def interval_from(t):
    return C(0, C(0, C(1, I(t)), bool_(True)), C(0, C(2), bool_(True)))

def tx_info(inputs, outputs, fee, mint, range_, signatories, datums, txid):
    return C(0, L(*inputs), L(*outputs), fee, mint, L(), L(),
             range_, L(*[B(s) for s in signatories]),
             L(*[C(0, B(dh), dat) for dh, dat in datums]),
             tx_id(txid))

def spend_ctx(txinfo, ref): return C(0, txinfo, C(1, ref))
def mint_ctx(txinfo): return C(0, txinfo, C(0, B(LENDER_CS)))  # only used for the lender policy (cs unused)

ADA = b""
ATTACKER_PKH = bytes.fromhex("aa" * 28)
ATTACKER_ADDR = address(cred_pkh(ATTACKER_PKH))

def load(name):
    return unflatten(bytes.fromhex(open(f"{HERE}/script_{name}.hex").read().strip()))

def _is_true(v):
    # PlutusTx Bool validators return data True = Constr 0 []
    return isinstance(v, A.PlutusConstr) and v.constructor == 0 and len(v.fields) == 0

def run(name, args):
    prog = load(name)
    try:
        res = uplc_eval(prog, *args)
        inner = getattr(res, "result", res)
        if isinstance(inner, BaseException) or isinstance(inner, A.Error):
            return False, f"{type(inner).__name__}: {str(inner)[:120]}"
        if isinstance(inner, A.BuiltinUnit):
            return True, "unit"
        if _is_true(inner):
            return True, "True (Constr 0 [])"
        return False, f"unexpected result: {type(inner).__name__} {repr(inner)[:80]}"
    except BaseException as e:
        return False, f"{type(e).__name__}: {str(e)[:160]}"

def sha_tn(txid_hex, idx):
    return hashlib.sha256(bytes([idx]) + bytes.fromhex(txid_hex)).digest()

RESULTS = []

def case(name, expect, fn):
    ok, detail = fn()
    verdict = "ACCEPT" if ok else "REJECT"
    passed = (verdict == expect)
    RESULTS.append({"case": name, "expect": expect, "got": verdict, "pass": passed, "detail": detail})
    print(f'[{"PASS" if passed else "FAIL"}] {name}: expected {expect}, got {verdict}  ({detail[:90]})')

# ---------------------------------------------------------------- 1. NFT policy
INPUT_TXID = "11" * 32
OTHER_TXID = "22" * 32
input_ref = tx_out_ref(bytes.fromhex(INPUT_TXID), 0)
input_utxo = tx_in_info(input_ref, tx_out(ATTACKER_ADDR, value_map({(ADA, b""): 2_000_000})))

def nft_case(name, expect, tn, amount, inputs, mint_entries):
    mint = value_map(mint_entries)
    ti = tx_info(inputs, [tx_out(ATTACKER_ADDR, value_map({(ADA, b""): 2_000_000}))],
                 value_map({(ADA, b""): 200_000}), mint, interval_always(), [], [], txid=bytes.fromhex(OTHER_TXID))
    ctx = mint_ctx(ti)
    redeemer = tx_out_ref(bytes.fromhex(INPUT_TXID), 0)   # redeemer = the referenced UTxO
    case(name, expect, lambda: run("lender_nft_policy", [redeemer, ctx]))

# A1: mint +1 with correct name (sha256(idx||txid) of consumed input) -> ACCEPT
name_ok = sha_tn(INPUT_TXID, 0)
nft_case("A1 lender NFT mint +1, name=sha256(ref) of consumed input", "ACCEPT",
         name_ok, 1, [input_utxo], {(LENDER_CS, name_ok): 1})
# A2: mint +1 with an arbitrary (victim-like) name -> REJECT
name_bad = bytes.fromhex("99" * 32)
nft_case("A2 lender NFT mint +1, name NOT bound to any consumed input", "REJECT",
         name_bad, 1, [input_utxo], {(LENDER_CS, name_bad): 1})
# A3: burn -1 arbitrary name -> ACCEPT (validator has unrestricted burn branch)
nft_case("A3 lender NFT burn -1, arbitrary name, no matching input", "ACCEPT",
         name_bad, -1, [input_utxo], {(LENDER_CS, name_bad): -1})

# ---------------------------------------------------------------- 2. Interest validator
INT_TXID = "33" * 32
int_ref = tx_out_ref(bytes.fromhex(INT_TXID), 0)
INTEREST_ADDR = address(cred_script(bytes.fromhex("92862d28096bed36fb01d36dc4c77214f64630d60bc990db9876f250")),
                        stake=cred_pkh(bytes.fromhex("69962602a7025d4163233855c5a379313b27239b8623ad53540815cb")))
int_utxo_in = tx_in_info(int_ref, tx_out(INTEREST_ADDR, value_map({(ADA, b""): 50_000_000_000}), datum_hash=bytes.fromhex("44" * 32)))
def interest_case(name, expect, mint_entries, outputs):
    datum = B(bytes.fromhex("55" * 32))       # lenderNftTn
    redeemer = I(0)
    ti = tx_info([int_utxo_in], outputs, value_map({(ADA, b""): 200_000}), value_map(mint_entries),
                 interval_always(), [], [], txid=bytes.fromhex("66" * 32))
    ctx = spend_ctx(ti, int_ref)
    case(name, expect, lambda: run("interest_v1", [datum, redeemer, ctx]))

# B1: exact burn of the datum's lender NFT; full value routed to attacker -> ACCEPT
mint_ok = {(LENDER_CS, bytes.fromhex("55" * 32)): -1}
interest_case("B1 interest spend + exact lender-NFT burn -1, ALL value to attacker addr", "ACCEPT",
              mint_ok, [tx_out(ATTACKER_ADDR, value_map({(ADA, b""): 49_990_000_000}))])
# B2: no burn -> REJECT
interest_case("B2 interest spend, no NFT burn", "REJECT",
              {}, [tx_out(ATTACKER_ADDR, value_map({(ADA, b""): 49_990_000_000}))])
# B3: burn of a DIFFERENT name -> REJECT
interest_case("B3 interest spend, burn of different token name", "REJECT",
              {(LENDER_CS, bytes.fromhex("77" * 32)): -1}, [tx_out(ATTACKER_ADDR, value_map({(ADA, b""): 49_990_000_000}))])
# B4: burn of the right name but wrong policy -> REJECT
interest_case("B4 interest spend, burn of right name wrong policy", "REJECT",
              {(BORROWER_CS, bytes.fromhex("55" * 32)): -1}, [tx_out(ATTACKER_ADDR, value_map({(ADA, b""): 49_990_000_000}))])

# ---------------------------------------------------------------- 3. Liquidation validator
LIQ_TXID = "88" * 32
liq_ref = tx_out_ref(bytes.fromhex(LIQ_TXID), 0)
LIQ_ADDR = address(cred_script(bytes.fromhex("b1259b98f6e4776985fc5a9333717d8c9f1e62744fed8240640461d7")),
                   stake=cred_pkh(bytes.fromhex("69962602a7025d4163233855c5a379313b27239b8623ad53540815cb")))
liq_utxo_in = tx_in_info(liq_ref, tx_out(LIQ_ADDR, value_map({(ADA, b""): 2_000_000}), datum_hash=bytes.fromhex("99" * 32)))
def liq_case(name, expect, mint_entries):
    datum = B(bytes.fromhex("ab" * 32))       # borrowerNftTn
    ti = tx_info([liq_utxo_in], [tx_out(ATTACKER_ADDR, value_map({(ADA, b""): 1_800_000}))],
                 value_map({(ADA, b""): 200_000}), value_map(mint_entries), interval_always(), [], [],
                 txid=bytes.fromhex("cc" * 32))
    ctx = spend_ctx(ti, liq_ref)
    case(name, expect, lambda: run("liquidation_v1", [datum, I(0), ctx]))

liq_case("C1 liquidation spend + exact borrower-NFT burn -1", "ACCEPT",
         {(BORROWER_CS, bytes.fromhex("ab" * 32)): -1})
liq_case("C2 liquidation spend, no burn", "REJECT", {})
liq_case("C3 liquidation spend, wrong name burn", "REJECT",
         {(BORROWER_CS, bytes.fromhex("cd" * 32)): -1})

# ---------------------------------------------------------------- summary
summary = {"cases": RESULTS,
           "all_pass": all(r["pass"] for r in RESULTS),
           "passed": sum(1 for r in RESULTS if r["pass"]), "total": len(RESULTS)}
outdir = f"{HERE}/../ci-out"
os.makedirs(outdir, exist_ok=True)
json.dump(summary, open(f"{outdir}/cek_proofs.json", "w"), indent=1)
print(json.dumps({k: summary[k] for k in ("all_pass", "passed", "total")}, indent=1))
