#!/usr/bin/env python3
"""Robust NAR holder verification v2 - multi-endpoint, pending != zero, resumable."""
import json, os, sys, time, random
sys.path.insert(0, '/home/heisenberg/CA/narwhalswap/analysis')
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bsc

HERE = os.path.dirname(os.path.abspath(__file__))
NAR = '0xa1303e6199b319a891b79685f0537d289af1fc83'
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
    out = os.path.join(HERE, 'verified_NAR_v2.json')
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
        np_ = json.load(open(os.path.join(HERE, 'nar_recon_netpos.json')))
        cands |= set(np_['netpos'].keys())
    except Exception as e:
        print('recon load err', e, flush=True)
    try:
        pages = json.load(open(os.path.join(HERE, 'raw_goldrush', 'holders_NAR.json')))
        for pg in pages:
            for it in (pg.get('data') or {}).get('items') or []:
                cands.add(it['address'].lower())
    except Exception as e:
        print('gr load err', e, flush=True)
    knowns = ['0x' + '7' * 40, '0x000000000000000000000000000000000000dead',
              '0xb6b0ba4e208ab93602be7a81f1400a7c7daad1f2', '0xa02f5f32426f76b4f7a9ee87cd6b212e4ec08960',
              '0x00470220dd82d5429379c8d9f679774b0e6e651d', '0x507bdd06aca5facd19aa4b77037d3b9d48be2fb9',
              '0xb104ae8b7da105ca79cba208b9a41c1d63fff2c5', '0x7f8a46ec48442d9ebf28fbc1144a83f8bc53f7e9',
              '0xb9fa84912ff2383a617d8b433e926adf0dd3fea1', '0x1d791eaa684a21de92618dedea7bf373e2486956',
              '0x07f1b50d5ae24ec41aa7269d65a5e23e8401542a', '0xf7a36c87c3a8909949638120f23cd721bf572032',
              '0x6e30f1159abb9599af8926475bbd055c0bd4fca8', '0x5f88d744447ca5887ed10016e9c57bd1af4db605',
              '0x6bb2a9c00f293cd4ec94d5e78db7f71aa9182e45', '0x0da8ebc508b294236ea0e8af36e530354a19e98c',
              '0x0f5667ec8eb4ea84e8ccf8777a7019def9541e05', '0x956bcf131b69fb0c5ae38fca14af7aa0ecf07f65',
              '0xd9116827b463ab5886262a6b705c858dcb75a32a', '0x36de6d01ab563d3e0fd7661c75dce8202aa82649',
              '0x48465562007aa0e2953852ccdc98c24624e6f6a4', '0x86354ff70c25b09fef4e5d1d4fd63a12739653b0',
              '0xd2c4541b73cc7189ddda45e93d113bc59cac0e27', '0x8d1652337513b5752d9a2ef7cd0f382df2b37505',
              '0x72ac0dac4784d1b0f6f15ceb4ee918c40aada55b', '0x69e7141afe30a047f02fb7f6efa43ec9e6bd7f54']
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
    print(f"DONE_NAR_V2 unresolved={len(unresolved)}", flush=True)

if __name__ == '__main__':
    main()
