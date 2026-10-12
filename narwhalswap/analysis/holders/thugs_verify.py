#!/usr/bin/env python3
"""Robust NAR holder verification v2 - multi-endpoint, pending != zero, resumable."""
import json, os, sys, time, random
sys.path.insert(0, '/home/heisenberg/CA/narwhalswap/analysis')
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bsc

HERE = os.path.dirname(os.path.abspath(__file__))
NAR = '0xe10e9822a5de22f8761919310dda35cd997d63c0'
ZERO = '0x' + '0' * 40
EXTRA_RPCS = [
    "https://bsc-rpc.publicnode.com", "https://1rpc.io/bnb",
    "https://bsc-dataseed.bnbchain.org", "https://bsc-dataseed1.defibit.io",
    "https://bsc-dataseed1.ninicoin.io", "https://bsc-dataseed2.bnbchain.org",
    "https://bsc-dataseed3.bnbchain.org", "https://bsc-dataseed4.bnbchain.org",
    "https://bsc.publicnode.com", "https://rpc.4everland.org",
]
UA = {'User-Agent': 'Mozilla/5.0', 'Content-Type': 'application/json'}

def rpc_multi(method, params, tries=14):
    urls = EXTRA_RPCS
    for att in range(tries):
        url = urls[att % len(urls)]
        try:
            body = json.dumps({"jsonrpc": "2.0", "id": 1, "method": method, "params": params}).encode()
            import urllib.request
            req = urllib.request.Request(url, data=body, headers=UA)
            with urllib.request.urlopen(req, timeout=20) as r:
                d = json.loads(r.read().decode())
            if 'result' in d:
                return d['result']
            # node-level error -> try next endpoint
        except Exception:
            pass
        time.sleep(min(0.4 + 0.3 * att, 3.0))
    return None

def main():
    blk = rpc_multi('eth_blockNumber', [])
    blk = int(blk, 16) if blk else None
    if blk is None:
        print('no RPC available', flush=True); return
    out = os.path.join(HERE, 'verified_THUGS.json')
    state = {'block': blk, 'balances': {}, 'code_len': {}}
    if os.path.exists(out):
        try:
            s = json.load(open(out))
            if s.get('block') == blk:
                state = s
        except Exception:
            pass
    # candidate lists
    cands = set()
    try:
        np_ = json.load(open(os.path.join(HERE, 'thugs_recon_netpos.json')))
        cands |= set(np_['netpos'].keys())
    except Exception as e:
        print('recon load err', e, flush=True)
    try:
        pages = json.load(open(os.path.join(HERE, 'raw_goldrush', 'holders_THUGS.json')))
        for pg in pages:
            for it in (pg.get('data') or {}).get('items') or []:
                cands.add(it['address'].lower())
    except Exception as e:
        print('gr load err', e, flush=True)
    knowns = ['0x' + '7' * 40, '0x000000000000000000000000000000000000dead',
              '0xe10e9822a5de22f8761919310dda35cd997d63c0',
              '0x40ff83ac2890dd5469f5eca2c17dcaf10ee09957',
              '0x586acb4be6cc93aa5c399888b255c7e864ea508e', '0xfd98d6dedc7ed8556ba61dc7902799c9815a5722',
              '0x71c1b6302c7f9c49ee3e675224b22cde34ab5ac7', '0x4d710603238427ae805b980bab8261624f5260c7',
              '0xb752f0cb591ecfb1c5058a93e1332f066bf38473', '0xcda85d0b4579ae31c1c2100141a6a59caca0b2d0',
              '0xa9d5f138ba6b6ce6ed0ed2e335e76b7d2a237621', '0x7f8a46ec48442d9ebf28fbc1144a83f8bc53f7e9',
              '0xb104ae8b7da105ca79cba208b9a41c1d63fff2c5', '0x507bdd06aca5facd19aa4b77037d3b9d48be2fb9']
    farms = ["0x186be2a9f0e9c92b880bbd3ec1f35f422f0d8835", "0x1d227f7e283d653a60f94d2350cab7a49bb85c6f",
             "0x268a2c1acbeee3b74616b9fe3f07c1bf80841e5d", "0x3dfb186e8ce513f321232098dd551e22886c1051",
             "0x6da9ee0c0571b63e38950d1e12e835d5343f601b", "0xaaa6ddb2022541c44e488ea2b3f32c8c8726c107",
             "0xb6c9b20253a4bdc65d1fdc6f4ae04f57f6523915", "0xbb38f7551025a433f36590be85271110212655de",
             "0xbe85812237741d75f81aebf1d9af52d544542168", "0xc3a471421bb1364d74b8f384cd73fe34d2ce1773",
             "0xc75f626121fca17719d16fe8ea5fb601062301d1", "0xcd0678f92dd0d2cca7aa3818bf7805101635e215",
             "0xcf889a0902859662c17dc895abb7af49ee28a013", "0xe6e0646bd4fcd37ec7258d21295dd4cdc347f57a"]
    cands |= set(knowns) | set(farms)
    cands.discard(ZERO)
    # order: knowns/farms first (critical), then rest
    crit = [a for a in (knowns + farms) if a in cands]
    critset = set(crit)
    rest = [a for a in sorted(cands) if a not in critset]
    order = crit + rest
    todo = [a for a in order if state['balances'].get(a) is None]
    print(f"block {blk} cands {len(order)} todo {len(todo)}", flush=True)

    # PHASE 1 balances
    CH = 25
    for i in range(0, len(todo), CH):
        part = todo[i:i+CH]
        data = bsc.SEL['balanceOf']
        payload = [{"jsonrpc": "2.0", "id": j, "method": "eth_call",
                    "params": [{"to": NAR, "data": data + bsc.word(a)}, hex(blk)]} for j, a in enumerate(part)]
        got = None
        for att in range(3):
            for url in EXTRA_RPCS:
                try:
                    import urllib.request
                    req = urllib.request.Request(url, data=json.dumps(payload).encode(), headers=UA)
                    with urllib.request.urlopen(req, timeout=25) as r:
                        resp = json.loads(r.read().decode())
                    if isinstance(resp, list):
                        got = [None] * len(part)
                        for item in resp:
                            j = item.get('id')
                            if isinstance(j, int) and 0 <= j < len(part):
                                got[j] = item.get('result')
                        break
                except Exception:
                    continue
            if got is not None:
                break
            time.sleep(1.5)
        if got is None:
            got = [None] * len(part)
        for a, r in zip(part, got):
            if r is not None:
                state['balances'][a] = int(r, 16) if r != '0x' else 0
        if (i // CH) % 20 == 0:
            json.dump(state, open(out, 'w'))
            print(f"  bal progress {i+len(part)}/{len(todo)} saved {sum(1 for v in state['balances'].values() if v is not None)}", flush=True)
    json.dump(state, open(out, 'w'))
    nz = {a: v for a, v in state['balances'].items() if v}
    print(f"PHASE1 done: {len(state['balances'])} resolved, {len(nz)} nonzero", flush=True)

    # PHASE 2 code for holders >= 1 NAR (or critical)
    th = 10**18
    need = [a for a in order if (state['balances'].get(a) or 0) >= th or a in critset]
    need = [a for a in need if state['code_len'].get(a) is None]
    print(f"PHASE2 code for {len(need)}", flush=True)
    for i in range(0, len(need), 20):
        part = need[i:i+20]
        for a in part:
            r = rpc_multi('eth_getCode', [a, hex(blk)], tries=6)
            if r is not None:
                state['code_len'][a] = (len(r) - 2) // 2 if r else 0
        if (i // 20) % 10 == 0:
            json.dump(state, open(out, 'w'))
    json.dump(state, open(out, 'w'))
    unresolved = [a for a in order if state['balances'].get(a) is None]
    print(f"DONE_THUGS unresolved={len(unresolved)}", flush=True)

if __name__ == '__main__':
    main()
