#!/usr/bin/env python3
"""CI state dump (dependency-free): Cover Protocol live state at the pinned block -> ci-out/cover_state.{json,txt}
Reads RPC from CI env (NODEREAL_ETH_RPC_URL / BLOCKPI_RPC_URL / RPC_URL / FORK_RPC_URL).
Never prints or writes any URL/secret.
"""
import json, os, time, urllib.request

def _clean(u):
    return (u or '').strip().strip('"').strip("'").strip()


CANDIDATES = [_clean(os.environ.get(k)) for k in
              ('NODEREAL_ETH_RPC_URL', 'BLOCKPI_RPC_URL', 'RPC_URL', 'FORK_RPC_URL')]
CANDIDATES = [u for u in CANDIDATES if u]


def _probe(u):
    try:
        body = json.dumps({"jsonrpc": "2.0", "id": 1, "method": "eth_blockNumber", "params": []}).encode()
        req = urllib.request.Request(u, data=body, headers={'Content-Type': 'application/json', 'User-Agent': 'Mozilla/5.0'})
        r = json.loads(urllib.request.urlopen(req, timeout=20).read())
        return 'result' in r
    except Exception:
        return False


RPC = None
for i, u in enumerate(CANDIDATES):
    if _probe(u):
        RPC = u
        print(f'[dump] using RPC candidate #{i}')
        break
assert RPC, 'no working RPC in env'
BLOCK = 26_171_719
FACTORY = '0xedfc81bf63527337cd2193925f9c0cf2d537acca'
DAI = '0x6b175474e89094c44da98b954eedeac495271d0f'
YDAI = '0x16de59092dae5ccf4a1e6439d611fd0653f0bd01'


def rpc_batch(calls, retries=4):
    out = []
    for i in range(0, len(calls), 10):
        chunk = calls[i:i+10]
        payload = [{"jsonrpc": "2.0", "id": j, "method": m, "params": p} for j, (m, p) in enumerate(chunk)]
        body = json.dumps(payload).encode()
        for attempt in range(retries):
            try:
                req = urllib.request.Request(RPC, data=body, headers={'Content-Type': 'application/json', 'User-Agent': 'Mozilla/5.0'})
                resp = json.loads(urllib.request.urlopen(req, timeout=90).read())
                byid = {r['id']: r for r in resp}
                out.extend([byid[j].get('result') for j in range(len(chunk))])
                break
            except Exception:
                if attempt == retries - 1:
                    raise
                time.sleep(2 * (attempt + 1))
    return out


def call(to, data):
    return rpc_batch([("eth_call", [{"to": to, "data": data}, hex(BLOCK)])])[0]


def words(h):
    b = bytes.fromhex(h[2:])
    return [b[i:i+32] for i in range(0, len(b), 32)]


def wi(w):
    return int.from_bytes(w, 'big')


def wa(w):
    return '0x' + w[12:].hex()


def wstr(h, off):
    b = bytes.fromhex(h[2:])
    ln = int.from_bytes(b[off:off+32], 'big')
    return b[off+32:off+32+ln].decode('utf-8', 'replace')


def dyn_addrs(h, off):
    b = bytes.fromhex(h[2:])
    ln = int.from_bytes(b[off:off+32], 'big')
    return ['0x' + b[off+32+i*32+12:off+32+i*32+32].hex() for i in range(ln)]


def dyn_u48s(h, off):
    b = bytes.fromhex(h[2:])
    ln = int.from_bytes(b[off:off+32], 'big')
    return [int.from_bytes(b[off+32+i*32:off+32+i*32+32], 'big') for i in range(ln)]


def main():
    out = {'block': BLOCK, 'factory': FACTORY}
    w = words(call(FACTORY, '0xea7579d1'))
    off = wi(w[0])
    protos = dyn_addrs(call(FACTORY, '0xea7579d1'), off)
    out['protocols'] = []
    covers = []
    for p in protos:
        h = call(p, '0x8080425b')  # getProtocolDetails()
        w = words(h)
        name = w[0].rstrip(b'\x00').decode('utf-8', 'replace')
        active = wi(w[1]) == 1
        nonce = wi(w[2])
        cols = dyn_addrs(h, wi(w[5]))
        exps = dyn_u48s(h, wi(w[6]))
        all_covers = dyn_addrs(h, wi(w[7]))
        claims = []
        clen = wi(words(call(p, '0xaa23fddc'))[0])  # claimsLength()
        for i in range(clen):
            cw = words(call(p, '0x3d040c6c' + hex(i)[2:].rjust(64, '0')))
            claims.append({'payoutNumerator': wi(cw[0]) & 0xffff, 'payoutDenominator': wi(cw[1]) & 0xffff,
                           'incidentTimestamp': wi(cw[2]), 'claimEnactedTimestamp': wi(cw[3])})
        out['protocols'].append({'address': p, 'name': name, 'active': active, 'claimNonce': nonce,
                                 'collaterals': [c.lower() for c in cols], 'expirationTimestamps': exps,
                                 'allCovers': [c.lower() for c in all_covers], 'claims': claims})
        covers += all_covers
    cinfo = []
    for c in covers:
        h = call(c, '0x25153b7b')  # getCoverDetails()
        w = words(h)
        cinfo.append({'cover': c.lower(), 'name': wstr(h, wi(w[0])), 'expirationTimestamp': wi(w[1]),
                      'collateral': wa(w[2]), 'claimNonce': wi(w[3]), 'claimCovToken': wa(w[4]),
                      'noclaimCovToken': wa(w[5])})
    calls = []
    for cv in cinfo:
        calls.append(("eth_call", [{"to": cv['collateral'], "data": '0x70a08231' + cv['cover'][2:].rjust(64, '0')}, hex(BLOCK)]))
        calls.append(("eth_call", [{"to": cv['claimCovToken'], "data": '0x18160ddd'}, hex(BLOCK)]))
        calls.append(("eth_call", [{"to": cv['noclaimCovToken'], "data": '0x18160ddd'}, hex(BLOCK)]))
    res = rpc_batch(calls)
    tot = {DAI: 0, YDAI: 0}
    out['covers'] = []
    for i, cv in enumerate(cinfo):
        cv['collateralBalance'] = int(res[i*3], 16) if res[i*3] and res[i*3] != '0x' else 0
        cv['claimSupply'] = int(res[i*3+1], 16) if res[i*3+1] and res[i*3+1] != '0x' else 0
        cv['noclaimSupply'] = int(res[i*3+2], 16) if res[i*3+2] and res[i*3+2] != '0x' else 0
        tot[cv['collateral']] = tot.get(cv['collateral'], 0) + cv['collateralBalance']
        out['covers'].append(cv)
    out['totals'] = dict(tot)
    out['summary'] = {'n_protocols': len(out['protocols']), 'n_covers': len(out['covers']),
                      'dai_total': tot.get(DAI, 0) / 1e18, 'ydai_total': tot.get(YDAI, 0) / 1e18,
                      'redeemFee': '10/10000'}
    os.makedirs('ci-out', exist_ok=True)
    json.dump(out, open('ci-out/cover_state.json', 'w'), indent=1)
    lines = [f"Cover Protocol state @ block {BLOCK}",
             f"protocols: {out['summary']['n_protocols']}  covers: {out['summary']['n_covers']}",
             f"DAI in covers : {out['summary']['dai_total']:.6f}",
             f"yDAI in covers: {out['summary']['ydai_total']:.6f}",
             "",
             f"{'cover':46s} {'collateral':12s} {'balance':>20s} {'CLAIMsup':>20s} {'NOCLAIMsup':>20s}"]
    for cv in sorted(out['covers'], key=lambda x: -x['collateralBalance']):
        if cv['collateralBalance'] == 0 and cv['claimSupply'] == 0:
            continue
        col = 'DAI' if cv['collateral'] == DAI else 'yDAI'
        lines.append(f"{cv['name']:46s} {col:12s} {cv['collateralBalance']/1e18:>20.6f} {cv['claimSupply']/1e18:>20.6f} {cv['noclaimSupply']/1e18:>20.6f}")
    open('ci-out/cover_state.txt', 'w').write('\n'.join(lines) + '\n')
    print('\n'.join(lines[:8]))
    print('wrote ci-out/cover_state.json + ci-out/cover_state.txt')


if __name__ == '__main__':
    main()
