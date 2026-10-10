#!/usr/bin/env python3
"""C2-55 / Minswap V1 — read-only CEK evaluation of the DEPLOYED pool validator.

Purpose: prove, without touching mainnet, whether the deployed Minswap V1 pool
script (hash e1317b15...) enforces:
  (a) the owner gate on WithdrawLiquidityShare (post-audit fix), and
  (b) the address check on the continuing pool output (post-audit fix).

Method: reconstruct the Plutus V1 ScriptContext for (i) a legitimate
WithdrawLiquidityShare by the OWNER token holder, (ii) the same call by an
unprivileged attacker (no OWNER token), (iii) the datum-hijack redirect of the
pool output to a foreign "stealer" address. Evaluate the on-chain script with
the UPLC CEK machine (uplc python package). No chain interaction beyond the
read-only fetch of the script itself (already saved in raw/).

All constants used here are the DEPLOYED mainnet ones (from the on-chain
script and chain state):
  pool script hash : e1317b152faac13426e6a83e06ff88a4d62cce3c1634ab0a5ec13309
  pool NFT policy  : 0be55d262b29f564998ff81efe21bdc0022621c12f15af08d0f2ddb1
  LP policy        : e4214b7cce62ac6fbba385d164df48e157eae5863521b4b67ca71d86
  factory policy   : 13aa2accf2e1561723aa26871e071fdf32c867cff7e7d50ad470d62f
  license policy   : 2f2e0404310c106e2a260e8eb5a7e43f00cff42c667489d30e179816
  owner token name : "OWNER" (4f574e4552)
"""
import json, sys, hashlib
sys.setrecursionlimit(200000)

from uplc import unflatten
from uplc.tools import eval as uplc_eval
import uplc.ast as A

HERE = __file__.rsplit('/', 1)[0]

POOL_SCRIPT_HASH = bytes.fromhex('e1317b152faac13426e6a83e06ff88a4d62cce3c1634ab0a5ec13309')
NFT_POLICY       = bytes.fromhex('0be55d262b29f564998ff81efe21bdc0022621c12f15af08d0f2ddb1')
LP_POLICY        = bytes.fromhex('e4214b7cce62ac6fbba385d164df48e157eae5863521b4b67ca71d86')
FACTORY_POLICY   = bytes.fromhex('13aa2accf2e1561723aa26871e071fdf32c867cff7e7d50ad470d62f')
LICENSE_POLICY   = bytes.fromhex('2f2e0404310c106e2a260e8eb5a7e43f00cff42c667489d30e179816')
OWNER_NAME       = bytes.fromhex('4f574e4552')          # "OWNER"
MINSWAP_NAME     = bytes.fromhex('4d494e53574150')      # "MINSWAP"
ADA              = b''
MIN_POLICY       = bytes.fromhex('29d222ce763455e3d7a09a665ce554f00ac89d2e99a1a83d267170c6')
MIN_NAME         = bytes.fromhex('4d494e')

# ---------------------------------------------------------------- Plutus Data
def C(i, *fs):   return A.PlutusConstr(i, list(fs))
def B(x):        return A.PlutusByteString(x)
def I(n):        return A.PlutusInteger(n)
def L(*xs):      return A.PlutusList(list(xs))
def MP(d):       return A.PlutusMap(d)
def Just(x):     return C(0, x)
def Nothing():   return C(1)

def value_map(entries):
    """entries: {(policy_bytes, name_bytes): amount} -> PlutusMap Value"""
    by_pol = {}
    for (pol, name), amt in entries.items():
        by_pol.setdefault(pol, {})[name] = amt
    m = {}
    for pol, toks in by_pol.items():
        m[B(pol)] = MP({B(n): I(v) for n, v in toks.items()})
    return MP(m)

def asset_class(pol, name): return C(0, B(pol), B(name))
def tx_id(h):     return C(0, B(h))
def tx_out_ref(txid, idx): return C(0, tx_id(txid), I(idx))
def cred_pkh(h):  return C(0, B(h))            # Credential.PubKeyCredential (PubKeyHash = bytes)
def cred_script(h): return C(1, B(h))          # Credential.ScriptCredential (ValidatorHash = bytes)
def address(cred, stake=None):
    # StakingCredential.StakingHash = Constr 0 [Credential]
    return C(0, cred, Nothing() if stake is None else Just(C(0, stake)))
def tx_out(addr, val, datum_hash=None):
    return C(0, addr, val, Nothing() if datum_hash is None else Just(B(datum_hash)))
def tx_in_info(ref, out): return C(0, ref, out)
def interval_always():
    # Interval (LowerBound NegInf True) (UpperBound PosInf True)
    return C(0, C(0, C(1), True if False else C(0)), C(0, C(2), C(0)))
    # Extended: NegInf=Constr 1, PosInf=Constr 2, Finite x=Constr 0 [x]
    # LowerBound=Constr 0 [Extended, Bool]; Bool encoded as Constr 0/1
def bool_(b): return C(0) if b else C(1)
def interval_after(t):
    # lower bound = Finite t closed; upper = PosInf
    return C(0, C(0, C(0, I(t)), bool_(True)), C(0, C(2), bool_(True)))

def tx_info(inputs, outputs, fee, mint, range_, signatories, datums, txid):
    return C(0, L(*inputs), L(*outputs), fee, mint, L(), L(),
             range_, L(*[B(s) for s in signatories]),
             L(*[C(0, B(dh), dat) for dh, dat in datums]),
             tx_id(txid))

def script_context(txinfo, purpose_spending_ref):
    return C(0, txinfo, C(1, purpose_spending_ref))   # ScriptPurpose.Spending = Constr 1

# ---------------------------------------------------------------- contexts
def make_context(owner_has_token, pool_out_at_own_address, pool_out_datum_hash, pool_datum):
    """Build a WithdrawLiquidityShare context.

    Inputs:  [0] pool UTxO (script address), [1] owner/attacker UTxO
    Outputs: [0] feeTo output (receives LP share), [1] continuing pool output
    """
    pool_addr = address(cred_script(POOL_SCRIPT_HASH),
                        stake=cred_pkh(bytes.fromhex('52563c5410bff6a0d43ccebb7c37e1f69f5eb260552521adff33b9c2')))
    fee_to_addr = address(cred_pkh(bytes.fromhex('aafb1196434cb837fd6f21323ca37b302dff6387e8a84b3fa28faf56')),
                          stake=cred_pkh(bytes.fromhex('52563c5410bff6a0d43ccebb7c37e1f69f5eb260552521adff33b9c2')))
    stealer_addr = address(cred_script(bytes.fromhex('11'*28)))

    nft_name = bytes.fromhex('aa'*32)
    pool_value_entries = {
        (ADA, b''): 100_000_000,
        (MIN_POLICY, MIN_NAME): 500_000,
        (NFT_POLICY, nft_name): 1,
        (FACTORY_POLICY, MINSWAP_NAME): 1,
        (LP_POLICY, nft_name): 10_000,        # liquidity share held by pool (profit sharing)
    }
    pool_in_value = value_map(pool_value_entries)

    lp_share = 10_000
    out_entries = dict(pool_value_entries)
    out_entries[(LP_POLICY, nft_name)] -= lp_share
    if out_entries[(LP_POLICY, nft_name)] == 0:
        del out_entries[(LP_POLICY, nft_name)]   # Plutus Value drops zero-quantity assets
    pool_out_value = value_map(out_entries)

    pool_ref = tx_out_ref(bytes.fromhex('ab'*32), 0)
    owner_ref = tx_out_ref(bytes.fromhex('cd'*32), 1)

    pool_in = tx_in_info(pool_ref, tx_out(pool_addr, pool_in_value, datum_hash=pool_out_datum_hash))
    owner_entries = {(LICENSE_POLICY, OWNER_NAME): 1} if owner_has_token else {(ADA, b''): 5_000_000}
    owner_in = tx_in_info(owner_ref, tx_out(address(cred_pkh(bytes.fromhex('ee'*28))),
                                           value_map(owner_entries)))

    fee_to_out = tx_out(fee_to_addr, value_map({(LP_POLICY, nft_name): lp_share}))
    pool_out_addr = pool_addr if pool_out_at_own_address else stealer_addr
    pool_out = tx_out(pool_out_addr, pool_out_value, datum_hash=pool_out_datum_hash)

    datums = [(pool_out_datum_hash, pool_datum)]
    txinfo = tx_info([pool_in, owner_in], [fee_to_out, pool_out],
                     fee=value_map({(ADA, b''): 200_000}), mint=value_map({}),
                     range_=interval_after(1_700_000_000), signatories=[],
                     datums=datums, txid=bytes.fromhex('ff'*32))
    return script_context(txinfo, pool_ref)

def pool_datum(profit_sharing=True):
    fee_to_addr = address(cred_pkh(bytes.fromhex('aafb1196434cb837fd6f21323ca37b302dff6387e8a84b3fa28faf56')),
                          stake=cred_pkh(bytes.fromhex('52563c5410bff6a0d43ccebb7c37e1f69f5eb260552521adff33b9c2')))
    ps = Just(C(0, fee_to_addr, Nothing())) if profit_sharing else Nothing()
    return C(0, asset_class(ADA, b''), asset_class(MIN_POLICY, MIN_NAME),
             I(1_000_000), I(0), ps)

# ---------------------------------------------------------------- run
def load_script():
    raw = bytes.fromhex(open(f'{HERE}/../raw/minswap_v1_pool_script.cbor').read())
    return unflatten(raw)

def run_case(name, datum, redeemer, ctx):
    prog = load_script()
    try:
        res = uplc_eval(prog, datum, redeemer, ctx)
        inner = getattr(res, 'result', res)
        if isinstance(inner, RuntimeError) or isinstance(inner, A.Error):
            ok = False
            detail = f'{type(inner).__name__}: {str(inner)[:160]}'
        else:
            ok = True
            detail = repr(inner)[:160]
    except Exception as e:
        ok = False
        detail = f'{type(e).__name__}: {str(e)[:200]}'
    print(f'[{"ACCEPT" if ok else "REJECT"}] {name}: {detail}')
    return ok

def main():
    pd = pool_datum(True)
    dh = bytes.fromhex('11'*32)
    redeemer = C(2, I(1), I(0))     # WithdrawLiquidityShare ownerIndex=1 feeToIndex=0

    # 1. legitimate owner withdrawal
    ctx_legit = make_context(True, True, dh, pd)
    r1 = run_case('LEGIT owner withdraw (expect ACCEPT)', pd, redeemer, ctx_legit)

    # 2. attacker without OWNER token, pool output still at own address
    ctx_att = make_context(False, True, dh, pd)
    r2 = run_case('ATTACK no owner token (expect REJECT)', pd, redeemer, ctx_att)

    # 3. datum-hijack: pool output redirected to foreign stealer address
    ctx_hij = make_context(True, False, dh, pd)
    r3 = run_case('ATTACK datum-hijack redirect (expect REJECT)', pd, redeemer, ctx_hij)

    print(json.dumps({'legit_accept': r1, 'no_owner_reject': not r2,
                      'hijack_reject': not r3}, indent=1))

if __name__ == '__main__':
    main()
