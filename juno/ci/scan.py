#!/usr/bin/env python3
"""
C2-07 Juno governance capture — CI heavy pull / evidence generator.
Read-only: public Juno LCD/RPC + public Osmosis LCD + public gRPC (gov params via grpcurl).
Outputs JSON evidence into ci-out/.
"""
import urllib.request, urllib.error, urllib.parse, json, base64, time, subprocess, math, hashlib, os, sys
from concurrent.futures import ThreadPoolExecutor, as_completed

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'ci-out')
OUT = os.path.abspath(OUT)
os.makedirs(OUT, exist_ok=True)

LCDS = [
    'https://juno-api.polkachu.com',
    'https://juno-rest.publicnode.com',
    'https://lcd-juno.keplr.app',
    'https://juno.api.m.stavr.tech',
    'https://api.juno.validatus.com',
    'https://juno.api.pocket.network',
]
OSM_LCD = 'https://lcd.osmosis.zone'
GRPC = '/tmp/grpcurl' if os.path.exists('/tmp/grpcurl') else '/tmp/opencode/grpcurl'
GRPC_TARGET = 'juno-grpc.publicnode.com:443'
GOV_ADDR = 'juno10d07y265gmmuvt4z0w9aw880jnsr700jvss730'
JUNO_DENOM_OSMO = 'ibc/46B44899322F3CD854D2D46DEEF881958467CDD4B3B10086DA49296BBED94BED'
WYND_FACTORY = 'juno16adshp473hd9sruwztdqrtsfckgtd69glqm6sqk0hc4q40c296qsxl3u3s'

_rot = [0]
def _next_lcd():
    _rot[0] = (_rot[0] + 1) % len(LCDS)
    return LCDS[_rot[0]]

def http_json(url, tries=4, timeout=25):
    last = None
    for i in range(tries):
        try:
            req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0 (research; read-only)'})
            with urllib.request.urlopen(req, timeout=timeout) as r:
                return json.loads(r.read().decode())
        except Exception as e:
            last = e
            time.sleep(0.4 * (i + 1))
    return None

def rest(path, base=None, tries=4):
    if base is None: base = _next_lcd()
    return http_json(base + path, tries=tries)

def save(name, obj):
    with open(os.path.join(OUT, name), 'w') as f:
        json.dump(obj, f, indent=1, default=str)
    print(f"[saved] {name} ({os.path.getsize(os.path.join(OUT, name))} bytes)", flush=True)

def grpcurl(method, payload, target=GRPC_TARGET):
    try:
        p = subprocess.run([GRPC, '-max-time', '25', '-insecure', '-d', json.dumps(payload), target, method],
                           capture_output=True, text=True, timeout=40)
        return json.loads(p.stdout)
    except Exception as e:
        print(f"[grpc] {method} failed: {e}", flush=True)
        return None

T0_WALL = time.time()

# ---------------------------------------------------------------- 1. snapshot
def snapshot():
    print("[1] snapshot", flush=True)
    st = {}
    b = rest('/cosmos/base/tendermint/v1beta1/blocks/latest')
    if b: st['block'] = {'height': b['block']['header']['height'], 'time': b['block']['header']['time']}
    st['staking_pool'] = rest('/cosmos/staking/v1beta1/pool')
    st['supply_ujuno'] = rest('/cosmos/bank/v1beta1/supply/by_denom?denom=ujuno')
    st['community_pool'] = rest('/cosmos/distribution/v1beta1/community_pool')
    st['community_pool_grpc'] = grpcurl('cosmos.distribution.v1beta1.Query/CommunityPool', {})
    st['wasm_params'] = rest('/cosmwasm/wasm/v1/codes/params')
    st['validators'] = rest('/cosmos/staking/v1beta1/validators?status=BOND_STATUS_BONDED&pagination.limit=100')
    st['gov_params_grpc'] = grpcurl('cosmos.gov.v1.Query/Params', {})
    st['proposals'] = {}
    for pid in [378, 379]:
        st['proposals'][str(pid)] = {
            'tally': rest(f'/cosmos/gov/v1/proposals/{pid}/tally'),
            'info': rest(f'/cosmos/gov/v1/proposals/{pid}'),
            'votes': rest(f'/cosmos/gov/v1/proposals/{pid}/votes?pagination.limit=200'),
        }
    st['prices'] = http_json('https://coins.llama.fi/prices/current/coingecko:juno-network,coingecko:cosmos,coingecko:osmosis,coingecko:usd-coin,coingecko:ethereum,coingecko:chainlink,coingecko:terra-luna-2')
    save('state.json', st)
    return st

# ---------------------------------------------------------------- 2. wasm codes
def all_codes():
    print("[2] wasm codes", flush=True)
    codes = {}; key = ''
    for i in range(60):
        u = f'/cosmwasm/wasm/v1/code?pagination.limit=1000'
        if key: u += '&pagination.key=' + urllib.parse.quote(key, safe='')
        d = rest(u)
        if not d: break
        for c in d.get('code_infos', []): codes[int(c['code_id'])] = c
        nk = d.get('pagination', {}).get('next_key')
        if not nk: break
        key = nk
    save('codes.json', {'count': len(codes), 'max_id': max(codes) if codes else 0,
                        'ids': sorted(codes)[:50] + ['...'] + sorted(codes)[-10:]})
    return sorted(codes)

# ---------------------------------------------------------------- 3. contracts per code
def contracts_by_code(code_ids, deadline_s=1800):
    print(f"[3] enumerate contracts for {len(code_ids)} codes (deadline {deadline_s}s)", flush=True)
    addrs = set(); done = [0]
    t0 = time.time()
    def one(cid):
        out = []
        key = ''
        for _ in range(40):
            u = f'/cosmwasm/wasm/v1/code/{cid}/contracts?pagination.limit=200'
            if key: u += '&pagination.key=' + urllib.parse.quote(key, safe='')
            d = rest(u, tries=2)
            if not d: break
            out += d.get('contracts', [])
            nk = d.get('pagination', {}).get('next_key')
            if not nk: break
            key = nk
        return out
    with ThreadPoolExecutor(max_workers=16) as ex:
        futs = {ex.submit(one, c): c for c in code_ids}
        for f in as_completed(futs):
            done[0] += 1
            try: addrs.update(f.result() or [])
            except Exception: pass
            if done[0] % 500 == 0:
                print(f"    codes scanned {done[0]}/{len(code_ids)} contracts={len(addrs)} t={time.time()-t0:.0f}s", flush=True)
            if time.time() - t0 > deadline_s:
                print("    deadline hit; cancelling remaining", flush=True)
                for ff in futs: ff.cancel()
                break
    save('contracts_all.json', {'count': len(addrs), 'contracts': sorted(addrs)})
    return sorted(addrs)

# ---------------------------------------------------------------- 4. contract info + balances
def _session():
    import requests
    s = requests.Session()
    s.mount('https://', requests.adapters.HTTPAdapter(pool_connections=4, pool_maxsize=4, max_retries=0))
    s.headers.update({'User-Agent': 'Mozilla/5.0 (research; read-only)'})
    return s

def scan_contracts(addrs, deadline_s=1500):
    """Phase A: ContractInfo for every contract (find admin==gov). Phase B: balances (deadline-bound)."""
    import threading, requests
    print(f"[4] scan {len(addrs)} contracts: phase A info, phase B balances", flush=True)
    tls = threading.local()
    EPS = ['https://juno-api.polkachu.com', 'https://juno-rest.publicnode.com', 'https://juno.api.m.stavr.tech']

    def get(path, tries=2):
        if not hasattr(tls, 's'): tls.s = _session()
        for i in range(tries):
            base = EPS[(abs(hash(threading.current_thread().name)) + i) % len(EPS)]
            try:
                r = tls.s.get(base + path, timeout=8)
                if r.status_code == 200: return r.json()
                if r.status_code == 404: return None
                if r.status_code == 429: time.sleep(1.0)
            except Exception:
                try: tls.s.close()
                except Exception: pass
                tls.s = _session()
        return None

    # ---- phase A: info for all
    infos = {}; gov_admin = []; t0 = time.time(); done = [0]
    def info_one(a): return a, get(f'/cosmwasm/wasm/v1/contract/{a}')
    with ThreadPoolExecutor(max_workers=64) as ex:
        futs = {ex.submit(info_one, a): a for a in addrs}
        for f in as_completed(futs):
            done[0] += 1
            try:
                a, d = f.result()
                ci = (d or {}).get('contract_info', {})
                infos[a] = {'admin': ci.get('admin'), 'label': ci.get('label'), 'code_id': ci.get('code_id')}
                if ci.get('admin') == GOV_ADDR: gov_admin.append(a)
            except Exception: pass
            if done[0] % 5000 == 0:
                print(f"    phase A {done[0]}/{len(addrs)} gov_admin={len(gov_admin)} t={time.time()-t0:.0f}s", flush=True)
            if time.time() - t0 > deadline_s:
                print("    phase A deadline hit", flush=True)
                for ff in futs: ff.cancel()
                break
    save('contracts_info.json', {'scanned': done[0], 'total': len(addrs),
                                 'gov_admin_count': len(gov_admin), 'gov_admin': gov_admin})
    # ---- phase B: balances (gov_admin first, then all; deadline-bound)
    order = gov_admin + [a for a in addrs if a not in set(gov_admin)]
    bals = {}; t1 = time.time(); done2 = [0]
    def bal_one(a): return a, get(f'/cosmos/bank/v1beta1/balances/{a}')
    with ThreadPoolExecutor(max_workers=64) as ex:
        futs = {ex.submit(bal_one, a): a for a in order}
        for f in as_completed(futs):
            done2[0] += 1
            try:
                a, d = f.result()
                b = {c['denom']: int(c['amount']) for c in (d or {}).get('balances', [])}
                if b: bals[a] = b
            except Exception: pass
            if done2[0] % 5000 == 0:
                print(f"    phase B {done2[0]}/{len(order)} t={time.time()-t1:.0f}s", flush=True)
            if time.time() - t1 > deadline_s:
                print("    phase B deadline hit", flush=True)
                for ff in futs: ff.cancel()
                break
    gov_admin_full = [{'contract': a, 'info': infos.get(a), 'balances': bals.get(a, {})} for a in gov_admin]
    top = [{'contract': a, 'ujuno': b.get('ujuno', 0) / 1e6, 'admin': (infos.get(a) or {}).get('admin'),
            'label': (infos.get(a) or {}).get('label')} for a, b in bals.items() if b.get('ujuno')]
    top.sort(key=lambda r: -r['ujuno'])
    save('contracts_gov_admin.json', {'gov_addr': GOV_ADDR, 'count': len(gov_admin), 'contracts': gov_admin_full})
    save('contracts_top_juno.json', {'scanned_infos': done[0], 'scanned_balances': done2[0],
                                     'count_gt0': len(top), 'top': top[:200]})
    return infos

# ---------------------------------------------------------------- 5. liquidity
def liquidity():
    print("[5] liquidity (Osmosis + WYND)", flush=True)
    # Osmosis gamm
    pools = []; key = ''
    for _ in range(6):
        u = f'{OSM_LCD}/osmosis/gamm/v1beta1/pools?pagination.limit=1000'
        if key: u += '&pagination.key=' + urllib.parse.quote(key, safe='')
        d = http_json(u)
        if not d: break
        pools += d.get('pools', [])
        nk = d.get('pagination', {}).get('next_key')
        if not nk: break
        key = nk
    gamm = []
    for p in pools:
        for a in p.get('pool_assets') or []:
            if a['token']['denom'] == JUNO_DENOM_OSMO:
                other = [x for x in p['pool_assets'] if x['token']['denom'] != JUNO_DENOM_OSMO]
                gamm.append({'id': p['id'], 'juno': int(a['token']['amount']) / 1e6,
                             'other': [(x['token']['denom'], int(x['token']['amount']), x.get('weight')) for x in other]})
    # CL pools
    cl = []; key = ''
    for _ in range(4):
        u = f'{OSM_LCD}/osmosis/concentratedliquidity/v1beta1/pools?pagination.limit=1000'
        if key: u += '&pagination.key=' + urllib.parse.quote(key, safe='')
        d = http_json(u)
        if not d: break
        cl += d.get('pools', [])
        nk = d.get('pagination', {}).get('next_key')
        if not nk: break
        key = nk
    clj = [p for p in cl if p.get('token0') == JUNO_DENOM_OSMO or p.get('token1') == JUNO_DENOM_OSMO]
    cl_bal = []
    for p in clj:
        b = http_json(f'{OSM_LCD}/cosmos/bank/v1beta1/balances/{p["address"]}')
        jb = 0
        for c in (b or {}).get('balances', []):
            if c['denom'] == JUNO_DENOM_OSMO: jb = int(c['amount']) / 1e6
        cl_bal.append({'id': p['id'], 'address': p['address'], 'juno': jb})
    # terraswap-style factories on juno-1 (WYND, Loop, White Whale)
    FACTORIES = {
        'wynd': 'juno16adshp473hd9sruwztdqrtsfckgtd69glqm6sqk0hc4q40c296qsxl3u3s',
        'loop': 'juno1p4dmvjtdf3qw9394k7zl65eg8g5ehzvdxnvm9hd3ju7a7aslrmdqaspeak',
        'whitewhale': 'juno14m9rd2trjytvxvu4ldmqvru50ffxsafs8kequmfky7jh97uyqrxqs5xrnx',
    }
    dex = {}
    for name, fac in FACTORIES.items():
        rows = []
        q = base64.b64encode(json.dumps({"pairs": {"limit": 100}}).encode()).decode()
        pr = http_json(f'https://juno-api.polkachu.com/cosmwasm/wasm/v1/contract/{fac}/smart/{q}')
        for p in ((pr or {}).get('data', {}) or {}).get('pairs', []):
            q2 = base64.b64encode(json.dumps({"pool": {}}).encode()).decode()
            pd = http_json(f'https://juno-api.polkachu.com/cosmwasm/wasm/v1/contract/{p["contract_addr"]}/smart/{q2}')
            assets = ((pd or {}).get('data', {}) or {}).get('assets', [])
            juno = 0; other = []
            for a in assets:
                info = a['info']
                t = info.get('token')
                den = info.get('native') or ('token:' + (t if isinstance(t, str) else json.dumps(t, sort_keys=True)))
                if den == 'ujuno': juno = int(a['amount']) / 1e6
                else: other.append((den, int(a['amount'])))
            if juno > 0:
                rows.append({'pair': p['contract_addr'], 'juno': juno, 'other': other})
        dex[name] = {'factory': fac, 'juno_pairs': len(rows), 'total_juno': sum(r['juno'] for r in rows), 'pairs': rows}
    out = {'osmosis_gamm_juno_pools': gamm,
           'osmosis_gamm_total_juno': sum(g['juno'] for g in gamm),
           'osmosis_cl_juno_pools': cl_bal,
           'osmosis_cl_total_juno': sum(c['juno'] for c in cl_bal),
           'juno_dex': dex}
    out['total_juno_in_pools'] = out['osmosis_gamm_total_juno'] + out['osmosis_cl_total_juno'] + sum(v['total_juno'] for v in dex.values())
    save('liquidity.json', out)
    return out

# ---------------------------------------------------------------- 6. bridged supply
def bridged():
    print("[6] bridged asset supply", flush=True)
    sup = {}; key = ''
    for _ in range(30):
        u = f'/cosmos/bank/v1beta1/supply?pagination.limit=1000'
        if key: u += '&pagination.key=' + urllib.parse.quote(key, safe='')
        d = rest(u)
        if not d: break
        for c in d.get('supply', []): sup[c['denom']] = int(c['amount'])
        nk = d.get('pagination', {}).get('next_key')
        if not nk: break
        key = nk
    dn = grpcurl('ibc.applications.transfer.v1.Query/Denoms', {'pagination': {'limit': 1000}})
    h2b = {}
    for den in ((dn or {}).get('denoms') or []):
        base = den['base']; trace = den.get('trace', [])
        path = '/'.join([f"{t['portId']}/{t['channelId']}" for t in trace] + [base])
        h2b['ibc/' + hashlib.sha256(path.encode()).hexdigest().upper()] = base
    prices = {'uusdc': 1.0, 'uusdt': 1.0, 'dai-wei': 1.0, 'uatom': 1.7867, 'weth-wei': 2687.27,
              'clink': 13.77, 'link-wei': 13.77, 'uosmo': 0.0361, 'ujuno': 0.00893, 'uluna': 0.051}
    totals = {}
    for denom, amt in sup.items():
        base = h2b.get(denom)
        if base in prices:
            dec = 18 if base.endswith('-wei') or base in ('dai-wei', 'weth-wei', 'clink', 'link-wei') else 6
            usd = (amt / 10**dec) * prices[base]
            totals[base] = totals.get(base, 0) + usd
    save('bridged_supply.json', {'n_denoms': len(sup), 'n_ibc': sum(1 for d in sup if d.startswith('ibc/')),
                                 'matched_traces': len(h2b), 'known_base_usd_totals': totals,
                                 'total_known_usd': sum(totals.values())})
    return totals

# ---------------------------------------------------------------- 7. cost model recompute
def cost_model(st, liq):
    print("[7] cost model", flush=True)
    gp = (st.get('gov_params_grpc') or {}).get('params', {})
    q = float(gp.get('quorum', '0.334')); thr = float(gp.get('threshold', '0.5'))
    pool = st['staking_pool']['pool']
    T0 = int(pool.get('bondedTokens', pool.get('bonded_tokens'))) / 1e6
    cpg = (st.get('community_pool_grpc') or {}).get('pool')
    if cpg:
        cp_raw = {c['denom']: int(c['amount']) / 1e18 for c in cpg}   # DecCoins (x1e18)
        cp_juno = cp_raw.get('ujuno', 0) / 1e6                        # ujuno has 6 decimals
    else:
        cp_juno = float(next(c['amount'] for c in st['community_pool']['pool'] if c['denom'] == 'ujuno')) / 1e6
    px = {}
    for k, v in ((st.get('prices') or {}).get('coins') or {}).items():
        px[v['symbol'].lower()] = v['price']
    live_yes = int(st['proposals']['379']['tally']['tally']['yes_count']) / 1e6
    B_solo = T0 * q / (1 - q)
    out = {'bonded_juno': T0, 'cp_juno': cp_juno, 'quorum': q, 'threshold': thr,
           'live_turnout_379': live_yes,
           'B_solo_quorum_juno': B_solo, 'B_beat_live_turnout_juno': live_yes, 'B_beat_all_bonded_juno': T0,
           'usd_at_spot': {'solo': B_solo * px.get('juno', 0), 'live': live_yes * px.get('juno', 0), 'all': T0 * px.get('juno', 0)},
           'prices': px,
           'total_juno_in_pools': liq.get('total_juno_in_pools'),
           'prices_note': 'prices from DefiLlama at CI run time'}
    # per-pool curves for the major pools (evidence; local analysis has the full equalized-marginal model)
    def curve(x, y, py, buys, sells, fee=0.003):
        o = {'buys': {}, 'sells': {}}
        for N in buys:
            o['buys'][N] = None if N >= x else round(y * N / (x - N) * py * (1 + fee), 2)
        for N in sells:
            o['sells'][N] = round(y * N / (x + N) * py * (1 - fee), 2)
        return o
    juno_px = px.get('juno', 0.008934); atom_px = px.get('cosmos', 1.7867); osmo_px = px.get('osmosis', 0.03606)
    curves = {
        'wynd_juno_atom': curve(1372607.73, 7061.303555, atom_px, [500000, 1000000], [1000000, 5000000, 20490612]),
        'wynd_juno_usdc': curve(641398.48, 5845.976334, 1.0, [500000], [1000000, 5000000, 20490612]),
        'osmosis_gamm_498': curve(1191615.24, 6069.613721, atom_px, [500000, 1000000], [1000000, 5000000, 20490612]),
        'osmosis_gamm_497': curve(572319.04, 143161.876, osmo_px, [500000], [1000000, 5000000, 20490612]),
        'osmosis_cl_1097_approx': curve(546400.39, 104564.990635, osmo_px, [500000], [1000000, 5000000, 20490612]),
    }
    out['per_pool_curves_usd'] = curves
    save('cost_model.json', out)
    return out

if __name__ == '__main__':
    t0 = time.time()
    st = snapshot()
    codes = all_codes()
    addrs = contracts_by_code(codes)
    scan_contracts(addrs)
    liq = liquidity()
    br = bridged()
    cm = cost_model(st, liq)
    print(f"[done] total runtime {time.time()-t0:.0f}s", flush=True)
    print(f"bonded={cm['bonded_juno']:,.0f} CP_juno={cm['cp_juno']:,.0f} solo_quorum_B={cm['B_solo_quorum_juno']:,.0f} "
          f"live_turnout={cm['live_turnout_379']:,.0f} juno_in_pools={cm['total_juno_in_pools']:,.0f}", flush=True)
