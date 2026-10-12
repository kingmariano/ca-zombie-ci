#!/usr/bin/env python3
"""Full NAR holder verification: candidates from events recon + GoldRush list + knowns.
Phase 1: batched balanceOf (resumable, saves incrementally). Phase 2: getCode for holders >= threshold.
"""
import json, os, sys, time
sys.path.insert(0, '/home/heisenberg/CA/narwhalswap/analysis')
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bsc

HERE = os.path.dirname(os.path.abspath(__file__))
NAR = '0xa1303e6199b319a891b79685f0537d289af1fc83'
TF = '0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef'
ZERO = '0x' + '0' * 40

def build_candidates():
    cands = set()
    try:
        np = json.load(open(os.path.join(HERE, 'nar_recon_netpos.json')))
        cands |= set(np['netpos'].keys())
    except Exception as e:
        print('nar_recon load err', e)
    try:
        pages = json.load(open(os.path.join(HERE, 'raw_goldrush', 'holders_NAR.json')))
        for pg in pages:
            for it in (pg.get('data') or {}).get('items') or []:
                cands.add(it['address'].lower())
    except Exception as e:
        print('goldrush load err', e)
    # known protocol addresses
    knowns = ['0x' + '7' * 40, '0x000000000000000000000000000000000000dead',
              '0xb6b0ba4e208ab93602be7a81f1400a7c7daad1f2', '0xa02f5f32426f76b4f7a9ee87cd6b212e4ec08960',
              '0x00470220dd82d5429379c8d9f679774b0e6e651d', '0x507bdd06aca5facd19aa4b77037d3b9d48be2fb9',
              '0xb104ae8b7da105ca79cba208b9a41c1d63fff2c5', '0x7f8a46ec48442d9ebf28fbc1144a83f8bc53f7e9',
              '0xb9fa84912ff2383a617d8b433e926adf0dd3fea1', '0x1d791eaa684a21de92618dedea7bf373e2486956',
              '0x07f1b50d5ae24ec41aa7269d65a5e23e8401542a',
              '0xf7a36c87c3a8909949638120f23cd721bf572032',
              '0x6e30f1159abb9599af8926475bbd055c0bd4fca8', '0x5f88d744447ca5887ed10016e9c57bd1af4db605']
    farms = ["0x186be2a9f0e9c92b880bbd3ec1f35f422f0d8835", "0x1d227f7e283d653a60f94d2350cab7a49bb85c6f",
             "0x268a2c1acbeee3b74616b9fe3f07c1bf80841e5d", "0x3dfb186e8ce513f321232098dd551e22886c1051",
             "0x6da9ee0c0571b63e38950d1e12e835d5343f601b", "0xaaa6ddb2022541c44e488ea2b3f32c8c8726c107",
             "0xb6c9b20253a4bdc65d1fdc6f4ae04f57f6523915", "0xbb38f7551025a433f36590be85271110212655de",
             "0xbe85812237741d75f81aebf1d9af52d544542168", "0xc3a471421bb1364d74b8f384cd73fe34d2ce1773",
             "0xc75f626121fca17719d16fe8ea5fb601062301d1", "0xcd0678f92dd0d2cca7aa3818bf7805101635e215",
             "0xcf889a0902859662c17dc895abb7af49ee28a013", "0xe6e0646bd4fcd37ec7258d21295dd4cdc347f57a"]
    cands |= set(farms) | set(knowns)
    cands.discard(ZERO)
    return sorted(cands)

def main():
    blk = bsc.block_number()
    outfile = os.path.join(HERE, 'verified_NAR.json')
    state = {'block': blk, 'balances': {}, 'code_len': {}}
    if os.path.exists(outfile):
        try:
            state = json.load(open(outfile))
            if state.get('block') != blk:
                print('block changed - starting fresh', state.get('block'), '->', blk)
                state = {'block': blk, 'balances': {}, 'code_len': {}}
        except Exception:
            pass
    cands = build_candidates()
    todo = [a for a in cands if a not in state['balances']]
    print(f"block {blk}, candidates {len(cands)}, todo {len(todo)}", flush=True)
    CH = 40
    for i in range(0, len(todo), CH):
        part = todo[i:i+CH]
        calls = [("eth_call", [{"to": NAR, "data": bsc.SEL['balanceOf'] + bsc.word(a)}, hex(blk)]) for a in part]
        got = None
        for att in range(4):
            try:
                got = bsc.rpc_batch(calls)
                break
            except Exception:
                time.sleep(1 + att)
        if got is None:
            for a in part:  # individual fallback
                r = None
                for att2 in range(4):
                    try:
                        r = bsc.rpc("eth_call", [{"to": NAR, "data": bsc.SEL['balanceOf'] + bsc.word(a)}, hex(blk)])
                        break
                    except Exception:
                        time.sleep(0.8)
                got.append(r) if False else None
                state['balances'][a] = int(r, 16) if r and r != '0x' else 0
        else:
            for a, r in zip(part, got):
                state['balances'][a] = int(r, 16) if r and r != '0x' else 0
        if (i // CH) % 10 == 0:
            json.dump(state, open(outfile, 'w'))
            print(f"  progress {i+len(part)}/{len(todo)}", flush=True)
        time.sleep(0.1)
    json.dump(state, open(outfile, 'w'))
    nz = {a: v for a, v in state['balances'].items() if v > 0}
    print(f"balance pass done: {len(nz)} nonzero, sum {sum(nz.values())/1e18:,.6f}", flush=True)
    # phase 2: code for holders >= 1e18 raw? threshold: >= 1 NAR
    th = 10**18
    big = [a for a, v in nz.items() if v >= th and state['code_len'].get(a) is None]
    print(f"code checks for {len(big)} holders >= 1 NAR", flush=True)
    for i in range(0, len(big), 40):
        part = big[i:i+40]
        calls = [("eth_getCode", [a, hex(blk)]) for a in part]
        got = None
        for att in range(4):
            try:
                got = bsc.rpc_batch(calls)
                break
            except Exception:
                time.sleep(1 + att)
        if got is None:
            for a in part:
                r = None
                for att2 in range(4):
                    try:
                        r = bsc.rpc("eth_getCode", [a, hex(blk)])
                        break
                    except Exception:
                        time.sleep(0.8)
                state['code_len'][a] = (len(r) - 2) // 2 if r else 0
        else:
            for a, r in zip(part, got):
                state['code_len'][a] = (len(r) - 2) // 2 if r else 0
        if (i // 40) % 10 == 0:
            json.dump(state, open(outfile, 'w'))
        time.sleep(0.1)
    json.dump(state, open(outfile, 'w'))
    print('DONE_NAR_VERIFY', flush=True)

if __name__ == '__main__':
    main()
