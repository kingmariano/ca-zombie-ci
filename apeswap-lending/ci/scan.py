#!/usr/bin/env python3
"""ApeSwap Lending (BSC) heavy recon for CI:
 1. Reconstruct participants: RPC eth_getLogs (Transfer + Borrow) where archive logs are available,
    plus GoldRush token holders + GoldRush decoded Borrow events.
 2. Merge with the vendored GoldRush holder list.
 3. Check every candidate for liquidation shortfall on-chain (comptroller).
 4. Detail shortfall accounts; compute liquidation profit bounds.
 5. Write ci-out/* and poc/inputs/candidates.json (consumed by the forge test).
Read-only: only eth_call / eth_getLogs / eth_blockNumber / GoldRush GETs.
"""
import json, os, sys, time, urllib.parse, urllib.request
from concurrent.futures import ThreadPoolExecutor

FOLDER = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))  # apeswap-lending/
CMP = '0xad48b2c9dc6709a560018c678e918253a65df86e'
TRANSFER_TOPIC = '0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef'
BORROW_TOPIC = '0x13ed6866d4e1ee6da46f845c46d7e54120883d75c5ea9a2dacc1c4ca8984ab80'
SEL_LIQ = '0x5513dd45'
SEL_SNAP = '0xc37f68e2'
SEL_ASSETS = '0xabfceffc'
SEL_PRICE = '0x62563c31'

MARKETS = [
 ('oBANANA','0xC2E840BdD02B4a1d970C87A912D8576a7e61D314','0x603c7f932ED1fc6575303D8Fb018fDCBb0f39a95'),
 ('oETH','0xaA1b1E1f251610aE10E4D553b05C662e60992EEd','0x2170Ed0880ac9A755fd29B2688956BD959F933F8'),
 ('oBUSD','0x0096B6B49D13b347033438c4a699df3Afd9d2f96','0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56'),
 ('oUSDT','0xdBFd516D42743CA3f1C555311F7846095D85F6Fd','0x55d398326f99059fF775485246999027B3197955'),
 ('oCake','0x3353f5bcfD7E4b146F2eD8F1e8D875733Cd754a7','0x0E09FaBB73Bd3Ade0a17ECC321fD13a19e81cE82'),
 ('oUSDC','0x91B66a9Ef4f4CAD7F8AF942855C37Dd53520f151','0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d'),
 ('oBNB','0x34878F6a484005AA90E7188a546Ea9E52b538F6f','0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE'),
 ('oBTCB','0x5fce5D208DC325ff602c77497dC18F8EAdac8ADA','0x7130d2A12B9BCbFAe4f2634d864A1Ee1Ce3Ead9c'),
 ('oDOT','0x92D106c39aC068EB113B3Ecb3273B23Cd19e6e26','0x7083609fCE4d1d8Dc0C979AAb8c869Ea2C873402'),
 ('oBNBx','0x3EE2bd8C244B5B3656673c2A49447e41D31F8E1e','0x1bdd3Cf7F79cfB8EdbB955f20ad99211551BA275'),
]
MAX_SCAN = 6000

def pick_rpc():
    cands = []
    for k in ('BSC_RPC_URL', 'RPC_URL'):
        v = os.environ.get(k)
        if v:
            cands.append(v)
    cands += ['https://bsc-rpc.publicnode.com', 'https://bsc-dataseed.bnbchain.org', 'https://1rpc.io/bnb', 'https://bsc.drpc.org']
    for u in cands:
        try:
            r = rpc_call(u, 'eth_blockNumber', [], timeout=15)
            if isinstance(r, str) and r.startswith('0x'):
                return u
        except Exception:
            continue
    raise RuntimeError('no working BSC RPC')

RPC = None
GR_KEY = os.environ.get('GOLD_RUSH_API_KEY') or None
if not GR_KEY and os.path.exists('/home/heisenberg/CA/.env'):
    for line in open('/home/heisenberg/CA/.env'):
        if line.startswith('GOLD_RUSH_API_KEY='):
            GR_KEY = line.strip().split('=', 1)[1]

def rpc_call(url, method, params, timeout=45):
    body = json.dumps({'jsonrpc': '2.0', 'id': 1, 'method': method, 'params': params}).encode()
    req = urllib.request.Request(url, data=body, headers={'content-type': 'application/json', 'User-Agent': 'curl/8.5.0'})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        d = json.load(r)
    if 'error' in d:
        raise RuntimeError(str(d['error'])[:200])
    return d.get('result')

def call(method, params, retries=3):
    last = None
    for a in range(retries):
        try:
            return rpc_call(RPC, method, params)
        except Exception as e:
            last = e
            time.sleep(1 + 2 * a)
    raise last

def words(h):
    h = h[2:] if h.startswith('0x') else h
    return [int(h[i:i + 64], 16) for i in range(0, len(h), 64)]

def eth_call(to, data, retries=3):
    return call('eth_call', [{'to': to, 'data': data}, 'latest'], retries)

def addr_arg(a):
    return a[2:].lower().rjust(64, '0')

def gr_get(path, **params):
    if not GR_KEY:
        return None
    params['key'] = GR_KEY
    url = f'https://api.covalenthq.com/v1/{path}/?' + urllib.parse.urlencode(params)
    req = urllib.request.Request(url, headers={'User-Agent': 'curl/8.5.0'})
    for a in range(3):
        try:
            with urllib.request.urlopen(req, timeout=60) as r:
                d = json.load(r)
            if d.get('error'):
                raise RuntimeError(str(d.get('error_message'))[:150])
            return d.get('data') or {}
        except Exception:
            if a == 2:
                return None
            time.sleep(2 * (a + 1))

def rpc_participants(tok, latest):
    """Try full-history Transfer + Borrow logs; abort market when provider caps ranges."""
    addrs = set()
    stats = {'requests': 0}
    for topic, idxs in ((TRANSFER_TOPIC, (1, 2)), (BORROW_TOPIC, (1,))):
        chunk = 5_000_000
        b = 0
        reqs = 0
        while b <= latest and reqs < 80:
            e = min(b + chunk - 1, latest)
            try:
                res = call('eth_getLogs', [{'address': tok, 'topics': [topic], 'fromBlock': hex(b), 'toBlock': hex(e)}], retries=1)
                for lg in res or []:
                    t = lg.get('topics') or []
                    for i in idxs:
                        if len(t) > i:
                            a = '0x' + t[i][-40:].lower()
                            if int(a, 16) != 0:
                                addrs.add(a)
                b = e + 1
                reqs += 1
            except Exception:
                reqs += 1
                if chunk < 50_000:
                    stats['aborted'] = True
                    break
                chunk //= 4
        stats['requests'] += reqs
        if stats.get('aborted'):
            break
    return addrs, stats

def gr_holders(tok):
    out = set()
    for p in range(5):
        d = gr_get(f'56/tokens/{tok}/token_holders', **{'page-size': 1000, 'page-number': p})
        if not d:
            break
        items = d.get('items', [])
        for i in items:
            out.add(i['address'].lower())
        if not (d.get('pagination') or {}).get('has_more'):
            break
    return out

def gr_borrowers(tok):
    out = set()
    for p in range(10):
        d = gr_get(f'56/address/{tok}/transactions_v2', **{'page-size': 100, 'page-number': p})
        if not d:
            break
        items = d.get('items', [])
        if not items:
            break
        for it in items:
            for lg in (it.get('log_events') or []):
                dec = (lg or {}).get('decoded') or {}
                if dec.get('name') == 'Borrow':
                    for prm in dec.get('params', []):
                        if prm.get('name') == 'borrower' and prm.get('value'):
                            out.add(prm['value'].lower())
        time.sleep(0.2)
    return out

def main():
    global RPC
    t0 = time.time()
    RPC = pick_rpc()
    print('RPC selected:', RPC.split('://')[0] + '://...', flush=True)
    latest = int(call('eth_blockNumber', []), 16)
    print('latest block', latest, flush=True)
    os.makedirs(f'{FOLDER}/ci-out', exist_ok=True)
    os.makedirs(f'{FOLDER}/poc/inputs', exist_ok=True)

    participants = set()
    per_market = {}
    log_stats = {}
    for sym, tok, und in MARKETS:
        a1, st = rpc_participants(tok, latest)
        a2 = gr_holders(tok)
        a3 = gr_borrowers(tok)
        per_market[sym] = {'rpc': len(a1), 'goldrush_holders': len(a2), 'goldrush_borrowers': len(a3)}
        participants |= a1 | a2 | a3
        log_stats[sym] = st
        print(f'{sym}: rpc={len(a1)} gr_holders={len(a2)} gr_borrowers={len(a3)} {st}', flush=True)

    gr_path = f'{FOLDER}/ci/inputs/holders_goldrush.json'
    gr = []
    if os.path.exists(gr_path):
        gr = json.load(open(gr_path)).get('holders', [])
    all_candidates = sorted(participants | {a.lower() for a in gr})
    print('participants:', len(participants), 'vendored:', len(gr), 'merged:', len(all_candidates), flush=True)
    scan_list = all_candidates[:MAX_SCAN]
    if len(all_candidates) > MAX_SCAN:
        print(f'WARNING: capping scan at {MAX_SCAN} candidates', flush=True)

    def check(a):
        try:
            out = eth_call(CMP, SEL_LIQ + addr_arg(a), retries=2)
            w = words(out)
            return a, {'err': w[0], 'liquidity': w[1], 'shortfall': w[2]}
        except Exception:
            return a, {'err': -1, 'error': 'revert/rate-limit'}
    results = {}
    with ThreadPoolExecutor(max_workers=8) as ex:
        for a, r in ex.map(check, scan_list):
            results[a] = r
    bad = {a: r for a, r in results.items() if r.get('shortfall')}
    errs = {a: r for a, r in results.items() if r.get('err') not in (0,)}
    print('checked', len(results), 'shortfall', len(bad), 'errors', len(errs), flush=True)

    prices = {}
    for sym, tok, und in MARKETS:
        try:
            prices[sym] = words(eth_call(CMP, SEL_PRICE + addr_arg(und)))[0]
        except Exception:
            prices[sym] = None

    def detail(a):
        rows = {}
        try:
            ai = eth_call(CMP, SEL_ASSETS + addr_arg(a))
            w = words(ai)
            off = w[0] // 32
            n = w[off]
            mks = ['0x' + ai[2 + (off + 1 + i) * 64: 2 + (off + 2 + i) * 64][24:] for i in range(n)]
            for m in mks:
                try:
                    s = words(eth_call(m, SEL_SNAP + addr_arg(a)))
                    rows[m.lower()] = {'err': s[0], 'tokens': s[1], 'borrows': s[2], 'er': s[3]}
                except Exception:
                    pass
        except Exception:
            pass
        return a, rows

    details = {}
    if bad:
        with ThreadPoolExecutor(max_workers=8) as ex:
            for a, rows in ex.map(detail, list(bad.keys())):
                details[a] = rows

    sym_by_tok = {t.lower(): s for s, t, u in MARKETS}
    total_coll = total_profit = 0.0
    detail_out = {}
    for a, rows in details.items():
        coll = debt = 0.0
        comp = {}
        for m, s in rows.items():
            sym = sym_by_tok.get(m)
            p = prices.get(sym)
            if not p or s.get('err'):
                continue
            if s['tokens'] > 0:
                v = s['tokens'] * s['er'] / 1e18 / 1e18 * (p / 1e18)
                coll += v
                comp.setdefault('coll', {})[sym] = round(v, 4)
            if s['borrows'] > 0:
                v = s['borrows'] / 1e18 * (p / 1e18)
                debt += v
                comp.setdefault('debt', {})[sym] = round(v, 4)
        max_repay = min(0.5 * debt, coll / 1.12)
        profit = 0.12 * max_repay
        total_coll += coll
        total_profit += profit
        comp.update({'collateral_usd': round(coll, 4), 'debt_usd': round(debt, 2),
                     'max_repay_usd': round(max_repay, 4), 'gross_profit_usd': round(profit, 4)})
        detail_out[a] = comp

    summary = {
        'latest_block': latest,
        'log_stats': log_stats,
        'per_market_participants': per_market,
        'candidates_scanned': len(scan_list),
        'shortfall_accounts': len(bad),
        'error_accounts': len(errs),
        'total_stored_shortfall_usd': round(sum(r['shortfall'] for r in bad.values()) / 1e18, 2),
        'total_seizeable_collateral_usd': round(total_coll, 2),
        'total_gross_liquidation_profit_usd': round(total_profit, 2),
        'prices': prices,
        'timestamp': int(time.time()),
        'elapsed_s': round(time.time() - t0, 1),
    }
    json.dump(summary, open(f'{FOLDER}/ci-out/summary.json', 'w'), indent=1)
    json.dump(detail_out, open(f'{FOLDER}/ci-out/shortfall_detail.json', 'w'), indent=1)
    json.dump({'shortfall': bad, 'errors': errs}, open(f'{FOLDER}/ci-out/liquidity_scan.json', 'w'), indent=1)
    json.dump({'per_market_participants': per_market}, open(f'{FOLDER}/ci-out/participants.json', 'w'), indent=1)
    ordered = list(bad.keys()) + [a for a in scan_list if a not in bad][:4000]
    json.dump({'holders': ordered}, open(f'{FOLDER}/poc/inputs/candidates.json', 'w'), indent=1)
    print('WROTE ci-out/summary.json; seizeable $%.2f gross profit $%.2f' % (total_coll, total_profit), flush=True)
    print(json.dumps({k: summary[k] for k in ('latest_block','candidates_scanned','shortfall_accounts','total_seizeable_collateral_usd','total_gross_liquidation_profit_usd','elapsed_s')}, indent=1))

if __name__ == '__main__':
    main()
