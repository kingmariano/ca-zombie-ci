#!/usr/bin/env python3
"""Cover Protocol (Ethereum) — full live-state enumeration at pinned latest block.
Read-only. RPC URL read from .env at runtime; never written to outputs.
Outputs: analysis/state.json
"""
import json, os, sys, time, urllib.request
import eth_abi

ENV = {}
for line in open('/home/heisenberg/CA/.env'):
    line = line.strip()
    if '=' in line and not line.startswith('#'):
        k, v = line.split('=', 1)
        ENV[k] = v.strip().strip('"').strip("'")

RPC = ENV.get('NODEREAL_ETH_RPC_URL') or ENV.get('BLOCKPI_RPC_URL') or ENV.get('RPC_URL')
assert RPC

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

def enc_addr(a):
    return a.lower().replace('0x', '').rjust(64, '0')

def enc_uint(n):
    return hex(n)[2:].rjust(64, '0')

def call(to, data, block):
    r = rpc_batch([("eth_call", [{"to": to, "data": data}, hex(block)])])[0]
    if r is None:
        raise RuntimeError('call failed')
    return r

def dec_uint(h):
    return None if (h is None or h == '0x') else int(h, 16)

def dec_addr(h):
    return None if (h is None or h == '0x') else '0x' + h[-40:].lower()

def dec_bytes32_str(h):
    if not h or h == '0x':
        return ''
    return bytes.fromhex(h[2:]).rstrip(b'\x00').decode('utf-8', 'replace')

FACTORY = '0xedfc81bf63527337cd2193925f9c0cf2d537acca'
PROXY_ADMIN_SLOT = '0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103'
PROXY_IMPL_SLOT = '0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc'

def main():
    block = int(rpc_batch([("eth_blockNumber", [])])[0], 16)
    print('latest block', block, flush=True)
    st = {'block': block, 'factory': FACTORY}

    # ---- factory scalar reads ----
    scalars = {
        'owner': '0x8da5cb5b', 'governance': '0x5aa6e675', 'treasury': '0x61d027b3',
        'claimManager': '0xa9a36dcd', 'protocolImplementation': '0x06f38491',
        'coverImplementation': '0x64bb44dc', 'coverERC20Implementation': '0xa6624cb6',
        'redeemFeeNumerator': '0x0db60f37', 'redeemFeeDenominator': '0xc12e90e9',
    }
    addrs = {'owner', 'governance', 'treasury', 'claimManager', 'protocolImplementation', 'coverImplementation', 'coverERC20Implementation'}
    for k, sel in scalars.items():
        r = call(FACTORY, sel, block)
        st[k] = dec_addr(r) if k in addrs else dec_uint(r)
    print('factory:', json.dumps(st, indent=1), flush=True)

    # ---- protocol list ----
    raw = call(FACTORY, '0xea7579d1', block)
    (proto_addrs,) = eth_abi.decode(['address[]'], bytes.fromhex(raw[2:]))
    st['protocols'] = []
    print(f'{len(proto_addrs)} protocols', flush=True)

    # per-protocol details
    detail_types = ['bytes32', 'bool', 'uint256', 'uint256', 'uint256', 'address[]', 'uint48[]', 'address[]', 'address[]']
    for p in proto_addrs:
        raw = call(p, '0x8080425b', block)  # getProtocolDetails()
        name, active, claimNonce, crd, nrd, collaterals, exps, allCovers, activeCovers = eth_abi.decode(detail_types, bytes.fromhex(raw[2:]))
        # claimsLength + claimDetails(i)
        raw = call(p, '0xaa23fddc', block)
        claims_len = dec_uint(raw)
        claims = []
        for i in range(claims_len or 0):
            raw = call(p, '0x3d040c6c' + eth_abi.encode(['uint256'], [i]).hex(), block)
            num, den, its, cets = eth_abi.decode(['uint16', 'uint16', 'uint48', 'uint48'], bytes.fromhex(raw[2:]))
            claims.append({'i': i, 'payoutNumerator': num, 'payoutDenominator': den, 'incidentTimestamp': its, 'claimEnactedTimestamp': cets})
        # collateral status
        rec = {
            'protocol': p, 'name': name.decode('utf-8', 'replace').rstrip('\x00'), 'active': active,
            'claimNonce': claimNonce, 'claimRedeemDelay': crd, 'noclaimRedeemDelay': nrd,
            'collaterals': collaterals, 'expirationTimestamps': list(exps),
            'allCovers': allCovers, 'activeCovers': activeCovers, 'claims': claims,
        }
        st['protocols'].append(rec)
        print(f"  {rec['name']:24s} {p} active={active} nonce={claimNonce} covers={len(allCovers)} claims={claims_len}", flush=True)

    # ---- per-cover reads ----
    covers = []
    for pr in st['protocols']:
        for c in pr['allCovers']:
            raw = call(c, '0x25153b7b', block)  # getCoverDetails()
            cname, cexp, ccol, cnonce, cct, nct = eth_abi.decode(['string', 'uint48', 'address', 'uint256', 'address', 'address'], bytes.fromhex(raw[2:]))
            rec = {'cover': c, 'protocol': pr['protocol'], 'protocolName': pr['name'], 'name': cname,
                   'expirationTimestamp': cexp, 'collateral': ccol.lower(), 'claimNonce': cnonce,
                   'claimCovToken': cct.lower(), 'noclaimCovToken': nct.lower()}
            covers.append(rec)
    print(f'{len(covers)} covers', flush=True)

    # batch the per-cover token reads
    calls = []
    for cv in covers:
        calls.append(("eth_call", [{"to": cv['collateral'], "data": '0x70a08231' + enc_addr(cv['cover'])}, hex(block)]))
        calls.append(("eth_call", [{"to": cv['claimCovToken'], "data": '0x18160ddd'}, hex(block)]))
        calls.append(("eth_call", [{"to": cv['noclaimCovToken'], "data": '0x18160ddd'}, hex(block)]))
        calls.append(("eth_call", [{"to": cv['claimCovToken'], "data": '0x70a08231' + enc_addr(cv['cover'])}, hex(block)]))
        calls.append(("eth_call", [{"to": cv['noclaimCovToken'], "data": '0x70a08231' + enc_addr(cv['cover'])}, hex(block)]))
        calls.append(("eth_call", [{"to": cv['collateral'], "data": '0x18160ddd'}, hex(block)]))
    res = rpc_batch(calls)
    for i, cv in enumerate(covers):
        cv['collateralBalance'] = dec_uint(res[i*6+0])
        cv['claimSupply'] = dec_uint(res[i*6+1])
        cv['noclaimSupply'] = dec_uint(res[i*6+2])
        cv['claimHeldByCover'] = dec_uint(res[i*6+3])
        cv['noclaimHeldByCover'] = dec_uint(res[i*6+4])
        cv['collateralTotalSupply'] = dec_uint(res[i*6+5])
    st['covers'] = covers

    # ---- proxy admin/impl slots for covers + protocols ----
    for cv in covers:
        a = rpc_batch([("eth_getStorageAt", [cv['cover'], PROXY_ADMIN_SLOT, hex(block)])])[0]
        m = rpc_batch([("eth_getStorageAt", [cv['cover'], PROXY_IMPL_SLOT, hex(block)])])[0]
        cv['proxyAdmin'] = dec_addr(a)
        cv['proxyImpl'] = dec_addr(m)
    for pr in st['protocols']:
        a = rpc_batch([("eth_getStorageAt", [pr['protocol'], PROXY_ADMIN_SLOT, hex(block)])])[0]
        m = rpc_batch([("eth_getStorageAt", [pr['protocol'], PROXY_IMPL_SLOT, hex(block)])])[0]
        pr['proxyAdmin'] = dec_addr(a)
        pr['proxyImpl'] = dec_addr(m)

    # ---- ClaimManagement state ----
    cm = st['claimManager']
    cm_state = {'address': cm}
    cm_sels = {'auditor': '0x3ec045a6', 'governance': '0x5aa6e675', 'treasury': '0x61d027b3',
               'feeCurrency': '0xb0aa6808', 'protocolFactory': '0xf489048a', 'owner': '0x8da5cb5b',
               'allowPartialClaim': '0xd3b0a76d', 'maxClaimDecisionWindow': '0x8997d6c5',
               'baseClaimFee': '0x44fd6bbb', 'forceClaimFee': '0x0debcbf0', 'feeMultiplier': '0xe5a70ef7'}
    for k, sel in cm_sels.items():
        r = call(cm, sel, block)
        cm_state[k] = dec_addr(r) if k in ('auditor', 'governance', 'treasury', 'feeCurrency', 'protocolFactory', 'owner') else dec_uint(r)
    cm_state['isAuditorVoting'] = bool(dec_uint(call(cm, '0x70443045', block)))
    if cm_state.get('feeCurrency'):
        cm_state['feeCurrencyBalance'] = dec_uint(call(cm_state['feeCurrency'], '0x70a08231' + enc_addr(cm), block))
    st['claimManagement'] = cm_state
    print('claimManagement:', json.dumps(cm_state, indent=1), flush=True)

    # ---- protocol collateral status maps (for collaterals listed) ----
    out_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'state.json')
    json.dump(st, open(out_path, 'w'), indent=1)
    print('wrote', out_path, flush=True)

if __name__ == '__main__':
    main()
