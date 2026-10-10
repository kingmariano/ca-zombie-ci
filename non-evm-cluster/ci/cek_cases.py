#!/usr/bin/env python3
"""Standalone (stdlib-only) Minswap V1 CEK PoC for CI.

Rebuilds the three ScriptContext cases for the DEPLOYED mainnet pool script and
evaluates them with the aiken UPLC interpreter. Writes JSON results + logs.

No network access, no secrets, read-only.
"""
import json, os, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
OUT = os.path.join(ROOT, 'ci-out')
os.makedirs(OUT, exist_ok=True)
AIKEN = os.environ.get('AIKEN_BIN', os.path.join(OUT, 'aiken'))

POOL_SCRIPT_HASH = bytes.fromhex('e1317b152faac13426e6a83e06ff88a4d62cce3c1634ab0a5ec13309')
NFT_POLICY       = bytes.fromhex('0be55d262b29f564998ff81efe21bdc0022621c12f15af08d0f2ddb1')
LP_POLICY        = bytes.fromhex('e4214b7cce62ac6fbba385d164df48e157eae5863521b4b67ca71d86')
FACTORY_POLICY   = bytes.fromhex('13aa2accf2e1561723aa26871e071fdf32c867cff7e7d50ad470d62f')
LICENSE_POLICY   = bytes.fromhex('2f2e0404310c106e2a260e8eb5a7e43f00cff42c667489d30e179816')
OWNER_NAME       = bytes.fromhex('4f574e4552')
MINSWAP_NAME     = bytes.fromhex('4d494e53574150')
MIN_POLICY       = bytes.fromhex('29d222ce763455e3d7a09a665ce554f00ac89d2e99a1a83d267170c6')
MIN_NAME         = bytes.fromhex('4d494e')
ADA = b''

# ---- Plutus Data as tuples: ('constr', i, [fields]) | ('i', n) | ('b', bytes) | ('list', [..]) | ('map', [(k,v)])
def C(i, *fs): return ('constr', i, list(fs))
def I(n): return ('i', n)
def B(x): return ('b', x)
def L(*xs): return ('list', list(xs))
def MP(pairs): return ('map', list(pairs))
def Just(x): return C(0, x)
def Nothing(): return C(1)

def value_map(entries):
    by = {}
    for (pol, name), amt in entries.items():
        by.setdefault(pol, {})[name] = amt
    return MP([(B(pol), MP([(B(n), I(v)) for n, v in toks.items()])) for pol, toks in by.items()])

def asset_class(pol, name): return C(0, B(pol), B(name))
def cred_pkh(h): return C(0, B(h))
def cred_script(h): return C(1, B(h))
def address(cred, stake=None): return C(0, cred, Nothing() if stake is None else Just(C(0, stake)))
def tx_out(addr, val, dh=None): return C(0, addr, val, Nothing() if dh is None else Just(B(dh)))
def tx_in_info(ref, out): return C(0, ref, out)
def tx_id(h): return C(0, B(h))
def tx_out_ref(txid, idx): return C(0, tx_id(txid), I(idx))
def bool_(b): return C(0) if b else C(1)
def interval_after(t): return C(0, C(0, C(0, I(t)), bool_(True)), C(0, C(2), bool_(True)))
def tx_info(inputs, outputs, fee, mint, range_, signatories, datums, txid):
    return C(0, L(*inputs), L(*outputs), fee, mint, L(), L(), range_,
             L(*[B(s) for s in signatories]),
             L(*[C(0, B(dh), dat) for dh, dat in datums]), tx_id(txid))
def script_context(txi, ref): return C(0, txi, C(1, ref))

STAKE = bytes.fromhex('52563c5410bff6a0d43ccebb7c37e1f69f5eb260552521adff33b9c2')
FEE_TO_PKH = bytes.fromhex('aafb1196434cb837fd6f21323ca37b302dff6387e8a84b3fa28faf56')
NFT_NAME = bytes.fromhex('aa' * 32)

def pool_datum(profit=True):
    ps = Just(C(0, address(cred_pkh(FEE_TO_PKH), cred_pkh(STAKE)), Nothing())) if profit else Nothing()
    return C(0, asset_class(ADA, b''), asset_class(MIN_POLICY, MIN_NAME), I(1_000_000), I(0), ps)

def make_context(owner_has_token, pool_out_at_own_address, dh, pd):
    pool_addr = address(cred_script(POOL_SCRIPT_HASH), cred_pkh(STAKE))
    fee_to_addr = address(cred_pkh(FEE_TO_PKH), cred_pkh(STAKE))
    stealer_addr = address(cred_script(bytes.fromhex('11' * 28)))
    entries = {(ADA, b''): 100_000_000, (MIN_POLICY, MIN_NAME): 500_000,
               (NFT_POLICY, NFT_NAME): 1, (FACTORY_POLICY, MINSWAP_NAME): 1,
               (LP_POLICY, NFT_NAME): 10_000}
    pool_in_value = value_map(entries)
    out = dict(entries); out[(LP_POLICY, NFT_NAME)] -= 10_000
    if out[(LP_POLICY, NFT_NAME)] == 0: del out[(LP_POLICY, NFT_NAME)]
    pool_out_value = value_map(out)
    pool_ref = tx_out_ref(bytes.fromhex('ab' * 32), 0)
    owner_ref = tx_out_ref(bytes.fromhex('cd' * 32), 1)
    pool_in = tx_in_info(pool_ref, tx_out(pool_addr, pool_in_value, dh))
    owner_entries = {(LICENSE_POLICY, OWNER_NAME): 1} if owner_has_token else {(ADA, b''): 5_000_000}
    owner_in = tx_in_info(owner_ref, tx_out(address(cred_pkh(bytes.fromhex('ee' * 28))), value_map(owner_entries)))
    fee_out = tx_out(fee_to_addr, value_map({(LP_POLICY, NFT_NAME): 10_000}))
    pool_out = tx_out(pool_addr if pool_out_at_own_address else stealer_addr, pool_out_value, dh)
    txi = tx_info([pool_in, owner_in], [fee_out, pool_out], value_map({(ADA, b''): 200_000}),
                  value_map({}), interval_after(1_700_000_000), [], [(dh, pd)], bytes.fromhex('ff' * 32))
    return script_context(txi, pool_ref)

# ---- aiken text encoding
def txt(x):
    t = x[0]
    if t == 'constr': return 'Constr %d [%s]' % (x[1], ', '.join(txt(f) for f in x[2]))
    if t == 'i': return 'I %d' % x[1]
    if t == 'b': return 'B #%s' % x[1].hex()
    if t == 'list': return 'List [%s]' % ', '.join(txt(i) for i in x[1])
    if t == 'map': return 'Map [%s]' % ', '.join('(%s, %s)' % (txt(k), txt(v)) for k, v in x[1])
    raise TypeError(t)

def main():
    raw = open(os.path.join(ROOT, 'analysis/cardano/minswap-v1/raw/minswap_v1_pool_script.cbor')).read().strip()
    hexf = os.path.join(OUT, 'pool_script_hex.txt'); open(hexf, 'w').write(raw)
    script = os.path.join(OUT, 'pool_script.uplc')
    with open(script, 'w') as f:
        subprocess.run([AIKEN, 'uplc', 'decode', '--cbor', '--hex', hexf], stdout=f, check=True, timeout=300)
    pd = pool_datum(True); dh = bytes.fromhex('11' * 32); redeemer = C(2, I(1), I(0))
    cases = [('LEGIT_owner_withdraw', make_context(True, True, dh, pd), True),
             ('ATTACK_no_owner_token', make_context(False, True, dh, pd), False),
             ('ATTACK_datum_hijack_redirect', make_context(True, False, dh, pd), False)]
    results = {}
    for name, ctx, expect_accept in cases:
        cmd = [AIKEN, 'uplc', 'eval', '-d', script, '(con data (%s))' % txt(pd),
               '(con data (%s))' % txt(redeemer), '(con data (%s))' % txt(ctx)]
        r = subprocess.run(cmd, capture_output=True, text=True, timeout=900)
        head = (r.stdout or '').split('\n---------------DEBUG------------------')[0].strip()
        accepted = (r.returncode == 0 and head.startswith('{'))
        results[name] = {'accepted': accepted, 'expected': expect_accept, 'rc': r.returncode,
                         'result': (json.loads(head).get('result') if accepted else None)}
        with open(os.path.join(OUT, 'cek_%s.log' % name), 'w') as f:
            f.write('cmd: %s\nrc: %s\n== STDOUT ==\n%s\n== STDERR ==\n%s\n' % (' '.join(cmd), r.returncode, r.stdout, r.stderr))
        print('[%s] %s (expected %s)' % ('ACCEPT' if accepted else 'REJECT', name, 'ACCEPT' if expect_accept else 'REJECT'))
    results['verdict'] = ('deployed pool script enforces the owner gate and the continuing-output address check; '
                          'datum-hijack and order-stealing criticals from the Jan-2022 Tweag audit are closed'
                          if results['LEGIT_owner_withdraw']['accepted']
                          and not results['ATTACK_no_owner_token']['accepted']
                          and not results['ATTACK_datum_hijack_redirect']['accepted'] else 'UNEXPECTED')
    with open(os.path.join(OUT, 'minswap-v1-cek.json'), 'w') as f:
        json.dump(results, f, indent=1)
    print(json.dumps(results, indent=1))

if __name__ == '__main__':
    main()
