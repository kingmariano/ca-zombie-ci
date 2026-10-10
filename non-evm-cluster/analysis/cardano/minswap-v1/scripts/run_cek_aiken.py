#!/usr/bin/env python3
"""Run the 3 Minswap V1 pool-script CEK cases with aiken's Rust UPLC evaluator.

Emits aiken data-constant text for datum/redeemer/context, then shells out to
`aiken uplc eval` on the DEPLOYED mainnet pool script (raw CBOR from Koios).
Read-only: no chain interaction, no transactions.

Result semantics:
  LEGIT   (owner token present, pool output at own address) -> expect ACCEPT
  NOOWNER (no OWNER token input)                            -> expect REJECT
  HIJACK  (pool output redirected to foreign address)       -> expect REJECT
"""
import os, subprocess, sys, json
sys.setrecursionlimit(200000)
sys.path.insert(0, os.path.dirname(__file__))
import poc_cek_eval as P
import uplc.ast as A

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, '..', 'out_cek')
AIKEN = os.environ.get('AIKEN_BIN', '/tmp/opencode/aiken-x86_64-unknown-linux-musl/aiken')

def txt(x):
    if isinstance(x, A.PlutusConstr):
        return 'Constr %d [%s]' % (x.constructor, ', '.join(txt(f) for f in x.fields))
    if isinstance(x, A.PlutusInteger):
        return 'I %d' % x.value
    if isinstance(x, A.PlutusByteString):
        return 'B #%s' % x.value.hex()
    if isinstance(x, A.PlutusList):
        return 'List [%s]' % ', '.join(txt(i) for i in x.value)
    if isinstance(x, A.PlutusMap):
        return 'Map [%s]' % ', '.join('(%s, %s)' % (txt(k), txt(v)) for k, v in x.value.items())
    raise TypeError(type(x))

def run(name, datum, redeemer, ctx):
    script = os.path.join(OUT, 'pool_script.uplc')
    if not os.path.exists(script):
        # decode the raw CBOR script to text UPLC using aiken
        hexf = os.path.join(OUT, 'pool_script_hex.txt')
        with open(os.path.join(OUT, 'pool_script.cbor'), 'rb') as f:
            open(hexf, 'w').write(f.read().hex())
        with open(script, 'w') as f:
            subprocess.run([AIKEN, 'uplc', 'decode', '--cbor', '--hex', hexf],
                           stdout=f, check=True, timeout=300)
    cmd = [AIKEN, 'uplc', 'eval', '-d', script,
           '(con data (%s))' % txt(datum), '(con data (%s))' % txt(redeemer),
           '(con data (%s))' % txt(ctx)]
    try:
        r = subprocess.run(cmd, capture_output=True, text=True, timeout=900)
        with open(os.path.join(OUT, f'cek_{name.split()[0].lower()}.log'), 'w') as f:
            f.write(f'cmd: {" ".join(cmd)}\nrc: {r.returncode}\n== STDOUT ==\n{r.stdout}\n== STDERR ==\n{r.stderr}\n')
        out = (r.stdout or '').strip()
        head = out.split('\n---------------DEBUG------------------')[0]
        if r.returncode == 0 and head.startswith('{'):
            j = json.loads(head)
            res = j.get('result', '')
            # the validator returning any value (not an error) = accepted
            ok = not res.strip().startswith('(error')
            print(f'[{"ACCEPT" if ok else "REJECT"}] {name}: result={res[:100]} cpu={j.get("cpu")} mem={j.get("mem")}')
            return ok
        print(f'[REJECT] {name}: rc={r.returncode} (validator errored)')
        return False
    except Exception as e:
        print(f'[ERROR] {name}: {e}')
        return None

def main():
    pd = P.pool_datum(True)
    dh = bytes.fromhex('11'*32)
    redeemer = P.C(2, P.I(1), P.I(0))
    r1 = run('LEGIT owner withdraw (expect ACCEPT)', pd, redeemer, P.make_context(True, True, dh, pd))
    r2 = run('ATTACK no owner token (expect REJECT)', pd, redeemer, P.make_context(False, True, dh, pd))
    r3 = run('ATTACK datum-hijack redirect (expect REJECT)', pd, redeemer, P.make_context(True, False, dh, pd))
    verdict = {'legit_accept': r1, 'noowner_reject': (r2 is False), 'hijack_reject': (r3 is False)}
    print(json.dumps(verdict))
    with open(os.path.join(OUT, 'cek_results.json'), 'w') as f:
        json.dump(verdict, f, indent=1)

if __name__ == '__main__':
    main()
