#!/usr/bin/env python3
"""Emit CBOR-encoded Data args for the Minswap V1 pool-script CEK evaluation (aiken).

Writes to out_cek/: pool_script.cbor (binary), datum.cbor, redeemer.cbor,
ctx_legit.cbor, ctx_noowner.cbor, ctx_hijack.cbor.
Contexts mirror poc_cek_eval.py exactly (legit owner withdraw, attacker without
OWNER token, datum-hijack redirect to a foreign address).
"""
import sys, os, cbor2
sys.setrecursionlimit(200000)
sys.path.insert(0, os.path.dirname(__file__))
import poc_cek_eval as P
import uplc.ast as A

OUT = os.path.join(os.path.dirname(__file__), '..', 'out_cek')
os.makedirs(OUT, exist_ok=True)

def dump_data(x, path):
    with open(path, 'wb') as f:
        f.write(cbor2.dumps(x, default=A.default_encoder))

def main():
    pd = P.pool_datum(True)
    dh = bytes.fromhex('11'*32)
    redeemer = P.C(2, P.I(1), P.I(0))
    dump_data(pd, f'{OUT}/datum.cbor')
    dump_data(redeemer, f'{OUT}/redeemer.cbor')
    dump_data(P.make_context(True,  True,  dh, pd), f'{OUT}/ctx_legit.cbor')
    dump_data(P.make_context(False, True,  dh, pd), f'{OUT}/ctx_noowner.cbor')
    dump_data(P.make_context(True,  False, dh, pd), f'{OUT}/ctx_hijack.cbor')
    # script: single-CBOR-wrapped flat (raw Koios bytes) -> binary file
    raw = bytes.fromhex(open(f'{os.path.dirname(__file__)}/../raw/minswap_v1_pool_script.cbor').read())
    open(f'{OUT}/pool_script.cbor', 'wb').write(raw)
    print('wrote', sorted(os.listdir(OUT)))

if __name__ == '__main__':
    main()
