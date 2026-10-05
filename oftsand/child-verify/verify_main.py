#!/usr/bin/env python3
"""
Child-verification script for OFTSand / OFTAdapterForSand (C2-01).
READ-ONLY: eth_blockNumber / eth_call / eth_getBalance / eth_getCode / eth_getTransactionCount.
No signing, no sending, no state changes. Raw JSON-RPC over urllib.
"""
import json, time, urllib.request, urllib.error, sys, datetime

OFT = '0xac531Eb26Ca1d21b85126De8FB87E80E09002DcF'
ENDPOINT = '0x1a44076050125825900e736c501f859c50fE728c'
SAND = '0x3845badAde8e6dFF049820680d1F14bD3903a5d0'
SAFES = {
    'base': '0x18987794f808eE72Ae9127058F1C7d079736Ca45',
    'bsc':  '0x47032F58129341B90c83E312eE22d2e74D584B4A',
    'eth':  '0x6ec4090d0F3cB76d9f3D8c4D5BB058A225E560a1',
}
RPCS = {
    'base': ['https://base-rpc.publicnode.com', 'https://mainnet.base.org'],
    'bsc':  ['https://bsc.drpc.org', 'https://bsc-dataseed.bnbchain.org'],
    'eth':  ['https://ethereum-rpc.publicnode.com', 'https://eth.drpc.org'],
}
CHAIN_NAMES = {'base': 'Base (8453)', 'bsc': 'BNB Smart Chain (56)', 'eth': 'Ethereum (1)'}

# function selectors (from `cast sig`, cross-checked)
S = {
    'owner()': '0x8da5cb5b',
    'getAdmin()': '0x6e9960c3',
    'getEnabled()': '0x18de0afd',
    'token()': '0xfc0c546a',
    'endpoint()': '0x5e280f11',
    'peers(uint32)': '0xbb0b6a53',
    'balanceOf(address)': '0x70a08231',
    'delegates(address)': '0x587cde1e',
    'getOwners()': '0xa0e67e2b',
    'getThreshold()': '0xe75235b8',
    'isModuleEnabled(address)': '0x2d9ad53d',
    'approveAndCall(address,uint256,bytes)': '0xcae9ca51',
    'setDelegate(address)': '0xca5eb5e1',
    'VERSION()': '0xffa1ad74',
    'name()': '0x06fdde03',
    'symbol()': '0x95d89b41',
    'totalSupply()': '0x18160ddd',
}

def pad32(hexstr):
    h = hexstr.lower().replace('0x', '')
    return h.rjust(64, '0')

def addr_word(a):
    return pad32(a)

def eid_word(eid):
    return format(eid, '064x')

def raw_call(chain, method, params, retries=3):
    last = None
    for attempt in range(retries):
        for url in RPCS[chain]:
            try:
                req = urllib.request.Request(url, data=json.dumps(
                    {"jsonrpc": "2.0", "id": 1, "method": method, "params": params}).encode(),
                    headers={'Content-Type': 'application/json',
                             'User-Agent': 'Mozilla/5.0 (X11; Linux x86_64) verify/1.0'})
                with urllib.request.urlopen(req, timeout=30) as r:
                    res = json.loads(r.read())
                if 'error' in res:
                    last = RuntimeError(f"rpc error {method}: {res['error']}")
                    continue
                return res['result']
            except Exception as e:  # noqa
                last = e
                time.sleep(0.5 + attempt)
    raise last

def batch_call(chain, calls, retries=3):
    """calls: list of (method, params). Returns list of results (dicts with result or error)."""
    payload = [{"jsonrpc": "2.0", "id": i, "method": m, "params": p}
               for i, (m, p) in enumerate(calls)]
    last = None
    for attempt in range(retries):
        for url in RPCS[chain]:
            try:
                req = urllib.request.Request(url, data=json.dumps(payload).encode(),
                                             headers={'Content-Type': 'application/json',
                                                      'User-Agent': 'Mozilla/5.0 (X11; Linux x86_64) verify/1.0'})
                with urllib.request.urlopen(req, timeout=60) as r:
                    res = json.loads(r.read())
                if isinstance(res, dict) and 'error' in res:
                    last = RuntimeError(f"batch rpc error: {res['error']}")
                    continue
                res.sort(key=lambda x: x.get('id', 0))
                return res
            except Exception as e:  # noqa
                last = e
                time.sleep(0.5 + attempt)
    raise last

def eth_call_to(chain, to, data, frm=None, block='latest'):
    tx = {'to': to, 'data': data}
    if frm:
        tx['from'] = frm
    return raw_call(chain, 'eth_call', [tx, block])

def decode_addr(hexres):
    if not hexres or hexres == '0x':
        return None
    v = int(hexres, 16)
    return '0x' + format(v & ((1 << 160) - 1), '040x')

def decode_bool(hexres):
    return int(hexres, 16) != 0

def decode_uint(hexres):
    return int(hexres, 16)

def decode_string(hexres):
    b = bytes.fromhex(hexres[2:])
    if len(b) < 64:
        return None
    ln = int.from_bytes(b[32:64], 'big')
    return b[64:64 + ln].decode('utf-8', 'replace')

OUT = {}

def main():
    now = datetime.datetime.utcnow().strftime('%Y-%m-%dT%H:%M:%SZ')
    out = {'timestamp_utc': now, 'chains': {}}
    all_eids = list(range(30000, 30301)) + list(range(40100, 40161))
    print(f"[i] eids to scan: {len(all_eids)} (30000-30300, 40100-40160)")

    for chain in ['base', 'bsc', 'eth']:
        print(f"\n===== {CHAIN_NAMES[chain]} =====")
        cinfo = {'rpc': RPCS[chain], 'chain_name': CHAIN_NAMES[chain]}
        blk_hex = raw_call(chain, 'eth_blockNumber', [])
        blk = int(blk_hex, 16)
        cinfo['latest_block'] = blk
        cinfo['latest_block_hex'] = blk_hex
        print(f"latest block: {blk}")

        # --- core OFT + endpoint reads (batched) ---
        oft_calls = [
            ('owner()', eth_data := S['owner()']),
        ]
        reads = [
            ('owner()', OFT, S['owner()']),
            ('getAdmin()', OFT, S['getAdmin()']),
            ('getEnabled()', OFT, S['getEnabled()']),
            ('token()', OFT, S['token()']),
            ('endpoint()', OFT, S['endpoint()']),
            ('peers(30101)', OFT, S['peers(uint32)'] + eid_word(30101)),
            ('peers(30102)', OFT, S['peers(uint32)'] + eid_word(30102)),
            ('peers(30184)', OFT, S['peers(uint32)'] + eid_word(30184)),
            ('balanceOf(OFT)', OFT, S['balanceOf(address)'] + addr_word(OFT)),
            ('name()', OFT, S['name()']),
            ('symbol()', OFT, S['symbol()']),
            ('totalSupply()', OFT, S['totalSupply()']),
            ('delegates(OFT)', ENDPOINT, S['delegates(address)'] + addr_word(OFT)),
            ('ownerOfEndpoint? no', ENDPOINT, S['owner()']),
        ]
        results = batch_call(chain, [('eth_call', [{'to': t, 'data': d}, 'latest']) for _, t, d in reads])
        basic = {}
        for (label, _, _), res in zip(reads, results):
            if 'result' in res:
                basic[label] = res['result']
            else:
                basic[label] = {'error': res.get('error')}
        # decode
        dec = {
            'owner()': decode_addr(basic['owner()']),
            'getAdmin()': decode_addr(basic['getAdmin()']),
            'getEnabled()': decode_bool(basic['getEnabled()']),
            'token()': decode_addr(basic['token()']),
            'endpoint()': decode_addr(basic['endpoint()']),
            'peers(30101)': decode_addr(basic['peers(30101)']),
            'peers(30102)': decode_addr(basic['peers(30102)']),
            'peers(30184)': decode_addr(basic['peers(30184)']),
            'balanceOf(OFT)': decode_uint(basic['balanceOf(OFT)']),
            'name()': decode_string(basic['name()']),
            'symbol()': decode_string(basic['symbol()']),
            'totalSupply()': decode_uint(basic['totalSupply()']),
            'delegates(OFT)': decode_addr(basic['delegates(OFT)']),
            'endpoint_owner()': decode_addr(basic['ownerOfEndpoint? no']),
        }
        nat = raw_call(chain, 'eth_getBalance', [OFT, 'latest'])
        dec['native_balance_wei'] = int(nat, 16)
        dec['latest_block'] = blk
        cinfo['basic_reads_raw'] = basic
        cinfo['basic_reads_decoded'] = dec
        for k, v in dec.items():
            print(f"  {k} = {v}")

        # delegate account info
        dell = dec['delegates(OFT)']
        dele_info = {}
        if dell:
            code = raw_call(chain, 'eth_getCode', [dell, 'latest'])
            nonce = raw_call(chain, 'eth_getTransactionCount', [dell, 'latest'])
            bal = raw_call(chain, 'eth_getBalance', [dell, 'latest'])
            dele_info = {'address': dell, 'has_code': code != '0x', 'code_size_bytes': (len(code) - 2) // 2,
                         'nonce': int(nonce, 16), 'native_balance_wei': int(bal, 16)}
        cinfo['delegate_account'] = dele_info
        print(f"  delegate account info: {dele_info}")

        # --- peers scan over eid ranges ---
        peer_calls = [('eth_call', [{'to': OFT, 'data': S['peers(uint32)'] + eid_word(e)}, 'latest'])
                      for e in all_eids]
        peer_results = []
        B = 25
        for i in range(0, len(peer_calls), B):
            peer_results.extend(batch_call(chain, peer_calls[i:i + B]))
            time.sleep(0.15)
        nonzero = {}
        peer_raw = {}
        for e, res in zip(all_eids, peer_results):
            val = res.get('result')
            peer_raw[str(e)] = val
            if val is not None and val != '0x' + '0' * 64:
                a = decode_addr(val)
                if a and a != '0x' + '0' * 40:
                    nonzero[str(e)] = a
        cinfo['peer_scan'] = {'eids_scanned': len(all_eids), 'ranges': '30000-30300,40100-40160',
                              'nonzero': nonzero, 'raw': peer_raw}
        print(f"  peers scan: {len(all_eids)} eids, nonzero = {nonzero if nonzero else 'NONE'}")

        # --- Safe reads ---
        safe = SAFES[chain]
        safe_reads = [
            ('getOwners()', safe, S['getOwners()']),
            ('getThreshold()', safe, S['getThreshold()']),
            ('VERSION()', safe, S['VERSION()']),
            ('isModuleEnabled(OFT)', safe, S['isModuleEnabled(address)'] + addr_word(OFT)),
        ]
        sres = batch_call(chain, [('eth_call', [{'to': t, 'data': d}, 'latest']) for _, t, d in safe_reads])
        safe_dec = {}
        for (label, _, _), res in zip(safe_reads, sres):
            safe_dec[label + '_raw'] = res.get('result') or {'error': res.get('error')}
        # owners decode: dynamic array of addresses
        raw_owners = safe_dec['getOwners()_raw']
        owners = []
        if isinstance(raw_owners, str) and raw_owners != '0x':
            b = bytes.fromhex(raw_owners[2:])
            off = int.from_bytes(b[0:32], 'big')
            n = int.from_bytes(b[off:off + 32], 'big')
            for i in range(n):
                owners.append('0x' + b[off + 32 + i * 32: off + 64 + i * 32].hex())
        safe_dec['owners'] = owners
        safe_dec['threshold'] = decode_uint(safe_dec['getThreshold()_raw']) if isinstance(safe_dec['getThreshold()_raw'], str) else None
        safe_dec['version'] = decode_string(safe_dec['VERSION()_raw']) if isinstance(safe_dec['VERSION()_raw'], str) else None
        safe_dec['isModuleEnabled(OFT)'] = decode_bool(safe_dec['isModuleEnabled(OFT)_raw']) if isinstance(safe_dec['isModuleEnabled(OFT)_raw'], str) else None
        safe_dec['safe_address'] = safe
        safe_dec['oft_is_owner'] = OFT.lower() in [o.lower() for o in owners]
        safe_dec['delegate_is_owner'] = (dell or '').lower() in [o.lower() for o in owners]
        cinfo['safe'] = safe_dec
        print(f"  safe {safe}: threshold={safe_dec['threshold']} owners={len(owners)} version={safe_dec['version']}")
        print(f"    owners: {owners}")
        print(f"    isModuleEnabled(OFT)={safe_dec['isModuleEnabled(OFT)']}  OFT_in_owners={safe_dec['oft_is_owner']}  delegate_in_owners={safe_dec['delegate_is_owner']}")

        # extra: SAND balance of adapter (ETH only)
        if chain == 'eth':
            sandbal = eth_call_to(chain, SAND, S['balanceOf(address)'] + addr_word(OFT))
            cinfo['sand_balanceOf_adapter'] = {'raw': sandbal, 'decoded': decode_uint(sandbal)}
            print(f"  SAND.balanceOf(adapter) = {decode_uint(sandbal)} ({decode_uint(sandbal)/1e18} SAND)")

        out['chains'][chain] = cinfo

    # --- approveAndCall simulations ---
    print("\n===== approveAndCall (eth_call simulation, never broadcast) =====")
    sender = '0x1111111111111111111111111111111111111111'
    sender2 = '0x2222222222222222222222222222222222222222'
    # data = setDelegate(sender) + 32 zero bytes  -> 68 bytes exactly
    inner = S['setDelegate(address)'] + addr_word(sender) + '00' * 32
    assert len(inner) == 2 + 68 * 2
    # approveAndCall(target=ENDPOINT, amount=0, data=inner)
    offset = format(0x60, '064x')
    outer = S['approveAndCall(address,uint256,bytes)'] + addr_word(ENDPOINT) + format(0, '064x') + offset \
        + format(len(inner) // 2, '064x') + inner.ljust((len(inner) // 2 + 31) // 32 * 64, '0')
    sims = {}
    for chain in ['base', 'bsc', 'eth']:
        rec = {}
        for label, frm in [('from_1111_expected_success_on_oftsand', sender),
                           ('from_2222_control_expected_revert', sender2)]:
            try:
                r = eth_call_to(chain, OFT, outer, frm=frm)
                rec[label] = {'status': 'RETURNED', 'result': r}
            except Exception as e:
                msg = str(e)
                rec[label] = {'status': 'REVERTED/ERROR', 'error': msg[:500]}
        # re-read delegate to show eth_call does not persist
        try:
            r2 = eth_call_to(chain, ENDPOINT, S['delegates(address)'] + addr_word(OFT))
            rec['delegates_after_simulation_read'] = decode_addr(r2)
        except Exception as e:
            rec['delegates_after_simulation_read'] = {'error': str(e)[:300]}
        sims[chain] = rec
        print(f"  {chain}: {json.dumps(rec, indent=2)[:800]}")
    out['approveAndCall_simulations'] = {'calldata': outer, 'inner_bytes': inner, 'inner_len': len(inner) // 2,
                                         'endpoint': ENDPOINT, 'oft': OFT, 'results': sims,
                                         'note': 'eth_call only; state changes are NOT persisted, never broadcast'}
    with open('main-verify-raw.json', 'w') as f:
        json.dump(out, f, indent=1)
    print("\n[ok] wrote main-verify-raw.json")

if __name__ == '__main__':
    main()
