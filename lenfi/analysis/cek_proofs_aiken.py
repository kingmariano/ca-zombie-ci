#!/usr/bin/env python3
"""Lenfi V1 (ex-Aada) — read-only CEK evaluation of DEPLOYED scripts with the aiken CEK machine.

Independent implementation (aiken `uplc eval`) of the proofs in cek_proofs.py.
Uses only the on-chain script bytes (analysis/script_*.hex) and hand-built ScriptContexts.
No chain interaction, no transactions.
"""
import json, sys, os, subprocess, hashlib
sys.setrecursionlimit(300000)
import uplc.ast as A
import uplc

HERE = os.path.dirname(os.path.abspath(__file__))
AIKEN = os.environ.get("AIKEN_BIN", "aiken")
LENDER_CS = bytes.fromhex("42f0e3706d2e0a0761db8da21387aadabe609a7cf328d249ebc2eeff")
BORROWER_CS = bytes.fromhex("21ca2902ad0406bc2ce361ad91157b3542544d86d4e3d3e3c43f1763")
INTEREST_SH = "92862d28096bed36fb01d36dc4c77214f64630d60bc990db9876f250"
LIQUIDATION_SH = "b1259b98f6e4776985fc5a9333717d8c9f1e62744fed8240640461d7"
STAKE_KEYHASH = "69962602a7025d4163233855c5a379313b27239b8623ad53540815cb"


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
    return MP({B(pol): MP({B(n): I(v) for n, v in toks.items()}) for pol, toks in by_pol.items()})


def tx_id(h): return C(0, B(h))
def tx_out_ref(txid, idx): return C(0, tx_id(txid), I(idx))
def cred_pkh(h): return C(0, B(h))
def cred_script(h): return C(1, B(h))
def address(cred, stake=None): return C(0, cred, Nothing() if stake is None else Just(C(0, stake)))
def tx_out(addr, val, datum_hash=None): return C(0, addr, val, Nothing() if datum_hash is None else Just(B(datum_hash)))
def tx_in_info(ref, out): return C(0, ref, out)
def interval_always(): return C(0, C(0, C(0), bool_(True)), C(0, C(2), bool_(True)))
def tx_info(inputs, outputs, fee, mint, range_, signatories, datums, txid):
    return C(0, L(*inputs), L(*outputs), fee, mint, L(), L(), range_,
             L(*[B(s) for s in signatories]),
             L(*[C(0, B(dh), dat) for dh, dat in datums]), tx_id(txid))
def spend_ctx(txinfo, ref): return C(0, txinfo, C(1, ref))
def mint_ctx(txinfo, cs): return C(0, txinfo, C(0, B(cs)))

ADA = b""
ATTACKER_PKH = bytes.fromhex("aa" * 28)
ATTACKER_ADDR = address(cred_pkh(ATTACKER_PKH))

RESULTS = []


def run_aiken(script_hexfile, args):
    """args: list of PlutusData terms. Returns (ok, detail)."""
    arg_strings = [uplc.dumps(a) for a in args]
    cmd = [AIKEN, "uplc", "eval", "-c", script_hexfile] + arg_strings
    try:
        p = subprocess.run(cmd, capture_output=True, text=True, timeout=600)
    except subprocess.TimeoutExpired:
        return False, "aiken eval timeout"
    if p.returncode == 0:
        try:
            out = json.loads(p.stdout)
            res = out.get("result", "")
            return True, f"result={res[:80]} cpu={out.get('cpu')} mem={out.get('mem')}"
        except Exception:
            return True, p.stdout[:120]
    err = (p.stderr or p.stdout).strip().replace("\n", " ")[:200]
    return False, err


def case(name, expect, script, args):
    ok, detail = run_aiken(f"{HERE}/script_{script}.hex", args)
    verdict = "ACCEPT" if ok else "REJECT"
    passed = verdict == expect
    RESULTS.append({"case": name, "expect": expect, "got": verdict, "pass": passed, "detail": detail})
    print(f'[{"PASS" if passed else "FAIL"}] {name}: expected {expect}, got {verdict} ({detail[:100]})')
    return passed


def sha_tn(txid_hex, idx):
    return hashlib.sha256(bytes([idx]) + bytes.fromhex(txid_hex)).digest()


# ============ 1. lender NFT policy: name binding + open burn ============
INPUT_TXID = "11" * 32
OTHER_TXID = "22" * 32
input_ref = tx_out_ref(bytes.fromhex(INPUT_TXID), 0)
input_utxo = tx_in_info(input_ref, tx_out(ATTACKER_ADDR, value_map({(ADA, b""): 2_000_000})))


def nft_case(name, expect, tn, amount, mint_entries):
    mint = value_map(mint_entries)
    ti = tx_info([input_utxo], [tx_out(ATTACKER_ADDR, value_map({(ADA, b""): 2_000_000}))],
                 value_map({(ADA, b""): 200_000}), mint, interval_always(), [], [], bytes.fromhex(OTHER_TXID))
    ctx = mint_ctx(ti, LENDER_CS)
    redeemer = tx_out_ref(bytes.fromhex(INPUT_TXID), 0)
    return case(name, expect, "lender_nft_policy", [redeemer, ctx])

name_ok = sha_tn(INPUT_TXID, 0)
name_bad = bytes.fromhex("99" * 32)
nft_case("A1 lender NFT mint +1, name=sha256(ref) of consumed input", "ACCEPT",
         name_ok, 1, {(LENDER_CS, name_ok): 1})
nft_case("A2 lender NFT mint +1, name NOT bound to any consumed input", "REJECT",
         name_bad, 1, {(LENDER_CS, name_bad): 1})
nft_case("A3 lender NFT burn -1, arbitrary name (unrestricted burn branch)", "ACCEPT",
         name_bad, -1, {(LENDER_CS, name_bad): -1})

# ============ 2. interest validator ============
INT_TXID = "33" * 32
int_ref = tx_out_ref(bytes.fromhex(INT_TXID), 0)
INTEREST_ADDR = address(cred_script(bytes.fromhex(INTEREST_SH)), stake=cred_pkh(bytes.fromhex(STAKE_KEYHASH)))
int_utxo_in = tx_in_info(int_ref, tx_out(INTEREST_ADDR, value_map({(ADA, b""): 50_000_000_000}),
                                         datum_hash=bytes.fromhex("44" * 32)))


def interest_case(name, expect, mint_entries, outputs):
    datum = B(bytes.fromhex("55" * 32))
    redeemer = I(0)
    ti = tx_info([int_utxo_in], outputs, value_map({(ADA, b""): 200_000}), value_map(mint_entries),
                 interval_always(), [], [], bytes.fromhex("66" * 32))
    return case(name, expect, "interest_v1", [datum, redeemer, spend_ctx(ti, int_ref)])

interest_case("B1 interest spend + exact lender-NFT burn -1, ALL value to attacker addr", "ACCEPT",
              {(LENDER_CS, bytes.fromhex("55" * 32)): -1},
              [tx_out(ATTACKER_ADDR, value_map({(ADA, b""): 49_990_000_000}))])
interest_case("B2 interest spend, no NFT burn", "REJECT", {},
              [tx_out(ATTACKER_ADDR, value_map({(ADA, b""): 49_990_000_000}))])
interest_case("B3 interest spend, burn of different token name", "REJECT",
              {(LENDER_CS, bytes.fromhex("77" * 32)): -1},
              [tx_out(ATTACKER_ADDR, value_map({(ADA, b""): 49_990_000_000}))])
interest_case("B4 interest spend, burn of right name wrong policy", "REJECT",
              {(BORROWER_CS, bytes.fromhex("55" * 32)): -1},
              [tx_out(ATTACKER_ADDR, value_map({(ADA, b""): 49_990_000_000}))])

# ============ 3. liquidation validator ============
LIQ_TXID = "88" * 32
liq_ref = tx_out_ref(bytes.fromhex(LIQ_TXID), 0)
LIQ_ADDR = address(cred_script(bytes.fromhex(LIQUIDATION_SH)), stake=cred_pkh(bytes.fromhex(STAKE_KEYHASH)))
liq_utxo_in = tx_in_info(liq_ref, tx_out(LIQ_ADDR, value_map({(ADA, b""): 2_000_000}), datum_hash=bytes.fromhex("99" * 32)))


def liq_case(name, expect, mint_entries):
    datum = B(bytes.fromhex("ab" * 32))
    ti = tx_info([liq_utxo_in], [tx_out(ATTACKER_ADDR, value_map({(ADA, b""): 1_800_000}))],
                 value_map({(ADA, b""): 200_000}), value_map(mint_entries), interval_always(), [], [],
                 bytes.fromhex("cc" * 32))
    return case(name, expect, "liquidation_v1", [datum, I(0), spend_ctx(ti, liq_ref)])

liq_case("C1 liquidation spend + exact borrower-NFT burn -1", "ACCEPT",
         {(BORROWER_CS, bytes.fromhex("ab" * 32)): -1})
liq_case("C2 liquidation spend, no burn", "REJECT", {})
liq_case("C3 liquidation spend, wrong name burn", "REJECT",
         {(BORROWER_CS, bytes.fromhex("cd" * 32)): -1})

# ============ 4. borrower NFT policy (same shape as lender) ============
def bnft_case(name, expect, tn, amount, mint_entries):
    mint = value_map(mint_entries)
    ti = tx_info([input_utxo], [tx_out(ATTACKER_ADDR, value_map({(ADA, b""): 2_000_000}))],
                 value_map({(ADA, b""): 200_000}), mint, interval_always(), [], [], bytes.fromhex(OTHER_TXID))
    ctx = mint_ctx(ti, BORROWER_CS)
    redeemer = tx_out_ref(bytes.fromhex(INPUT_TXID), 0)
    return case(name, expect, "borrower_nft_policy", [redeemer, ctx])

bnft_case("D1 borrower NFT mint +1, name NOT bound to consumed input", "REJECT",
          name_bad, 1, {(BORROWER_CS, name_bad): 1})
bnft_case("D2 borrower NFT burn -1 arbitrary name", "ACCEPT",
          name_bad, -1, {(BORROWER_CS, name_bad): -1})

summary = {"method": "aiken uplc eval (independent CEK machine) on deployed on-chain script bytes",
           "cases": RESULTS, "passed": sum(1 for r in RESULTS if r["pass"]), "total": len(RESULTS),
           "all_pass": all(r["pass"] for r in RESULTS)}
outdir = f"{HERE}/../ci-out"
os.makedirs(outdir, exist_ok=True)
json.dump(summary, open(f"{outdir}/cek_proofs_aiken.json", "w"), indent=1)
print(json.dumps({k: summary[k] for k in ("passed", "total", "all_pass")}, indent=1))
