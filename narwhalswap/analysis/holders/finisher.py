#!/usr/bin/env python3
"""Finisher: (1) repair unresolved NAR balances, priority-ordered; (2) verify THUGS big holders.
Uses small batches + individual fallbacks + multi-endpoint rotation. Pending stays None (never 0)."""
import json, os, sys, time, urllib.request
sys.path.insert(0, '/home/heisenberg/CA/narwhalswap/analysis')
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bsc

HERE = os.path.dirname(os.path.abspath(__file__))
UA = {'User-Agent': 'Mozilla/5.0', 'Content-Type': 'application/json'}
RPCS = [
    "https://bsc-rpc.publicnode.com", "https://1rpc.io/bnb",
    "https://bsc-dataseed.bnbchain.org", "https://bsc-dataseed1.defibit.io",
    "https://bsc-dataseed1.ninicoin.io", "https://bsc-dataseed2.bnbchain.org",
    "https://bsc-dataseed3.bnbchain.org", "https://bsc-dataseed4.bnbchain.org",
    "https://bsc.publicnode.com", "https://rpc.4everland.org",
]
_idx = {"i": 0}

def rpc_one(method, params, tries=8):
    for att in range(tries):
        url = RPCS[_idx["i"] % len(RPCS)]
        try:
            body = json.dumps({"jsonrpc": "2.0", "id": 1, "method": method, "params": params}).encode()
            req = urllib.request.Request(url, data=body, headers=UA)
            with urllib.request.urlopen(req, timeout=20) as r:
                d = json.loads(r.read().decode())
            if 'result' in d:
                _idx["i"] += 1
                return d['result']
        except Exception:
            pass
        _idx["i"] += 1
        time.sleep(min(0.5 + 0.35 * att, 3.5))
    return None

def rpc_batch_small(method_params, tries=4):
    """method_params: list of (method, params). Returns list of results or None."""
    payload = [{"jsonrpc": "2.0", "id": j, "method": m, "params": p} for j, (m, p) in enumerate(method_params)]
    data = json.dumps(payload).encode()
    for att in range(tries):
        url = RPCS[_idx["i"] % len(RPCS)]
        try:
            req = urllib.request.Request(url, data=data, headers=UA)
            with urllib.request.urlopen(req, timeout=30) as r:
                resp = json.loads(r.read().decode())
            if isinstance(resp, list):
                out = [None] * len(method_params)
                for item in resp:
                    j = item.get('id')
                    if isinstance(j, int) and 0 <= j < len(out) and 'result' in item:
                        out[j] = item['result']
                _idx["i"] += 1
                return out
        except Exception:
            pass
        _idx["i"] += 1
        time.sleep(0.8 + att)
    return None

def repair_balances(state, order, token, label):
    unresolved = [a for a in order if state['balances'].get(a) is None]
    print(f"[{label}] unresolved {len(unresolved)}", flush=True)
    done = 0
    CH = 8
    for i in range(0, len(unresolved), CH):
        part = unresolved[i:i+CH]
        calls = [("eth_call", [{"to": token, "data": bsc.SEL['balanceOf'] + bsc.word(a)}, "latest"]) for a in part]
        got = rpc_batch_small(calls, tries=3)
        if got is None:
            got = [None] * len(part)
        for a, r in zip(part, got):
            if r is not None:
                state['balances'][a] = int(r, 16) if r != '0x' else 0
                done += 1
        # individual fallback for still-unresolved
        for a, r in zip(part, got):
            if r is None:
                rr = rpc_one("eth_call", [{"to": token, "data": bsc.SEL['balanceOf'] + bsc.word(a)}, "latest"], tries=3)
                if rr is not None:
                    state['balances'][a] = int(rr, 16) if rr != '0x' else 0
                    done += 1
        time.sleep(0.25)
        if (i // CH) % 10 == 0:
            json.dump(state, open(os.path.join(HERE, f'verified_{label}.json'), 'w'))
            print(f"[{label}] repaired {min(i+CH,len(unresolved))}/{len(unresolved)} (resolved total {done})", flush=True)
    json.dump(state, open(os.path.join(HERE, f'verified_{label}.json'), 'w'))
    left = [a for a in order if state['balances'].get(a) is None]
    print(f"[{label}] repair done. still unresolved: {len(left)}", flush=True)

def code_pass(state, order, label, threshold_wei, out_name):
    need = [a for a in order if (state['balances'].get(a) or 0) >= threshold_wei
            and state.get('code_len', {}).get(a) is None]
    print(f"[{label}] code pass for {len(need)} (thr {threshold_wei/1e18})", flush=True)
    for i in range(0, len(need), 10):
        part = need[i:i+10]
        calls = [("eth_getCode", [a, "latest"]) for a in part]
        got = rpc_batch_small(calls, tries=2)
        if got is None:
            got = [None] * len(part)
        for a, r in zip(part, got):
            if r is not None:
                state['code_len'][a] = (len(r) - 2) // 2 if r else 0
            else:
                rr = rpc_one("eth_getCode", [a, "latest"], tries=2)
                if rr is not None:
                    state['code_len'][a] = (len(rr) - 2) // 2 if rr else 0
        time.sleep(0.2)
        if (i // 10) % 20 == 0:
            json.dump(state, open(os.path.join(HERE, out_name), 'w'))
    json.dump(state, open(os.path.join(HERE, out_name), 'w'))

def load_state(path, block):
    if os.path.exists(path):
        try:
            s = json.load(open(path))
            if s.get('block') == block:
                return s
        except Exception:
            pass
    return {'block': block, 'balances': {}, 'code_len': {}}

def main():
    blk = rpc_one('eth_blockNumber', [])
    if blk is None:
        print('no rpc'); return
    blk = int(blk, 16)
    print('block', blk, flush=True)

    # ---------- NAR repair ----------
    nar = '0xa1303e6199b319a891b79685f0537d289af1fc83'
    s = load_state(os.path.join(HERE, 'verified_NAR_v2.json'), blk)
    if s['block'] != blk or not s['balances']:
        print('NAR state missing/mismatched block; start fresh', flush=True)
        s = {'block': blk, 'balances': {}, 'code_len': {}}
    # build order
    cands = set()
    np_ = json.load(open(os.path.join(HERE, 'nar_recon_netpos.json')))
    cands |= set(np_['netpos'].keys())
    pages = json.load(open(os.path.join(HERE, 'raw_goldrush', 'holders_NAR.json')))
    grv = {}
    for pg in pages:
        for it in (pg.get('data') or {}).get('items') or []:
            cands.add(it['address'].lower()); grv[it['address'].lower()] = int(it['balance'])
    crit = ['0x' + '7' * 40, '0x000000000000000000000000000000000000dead',
            '0xb6b0ba4e208ab93602be7a81f1400a7c7daad1f2', '0xa02f5f32426f76b4f7a9ee87cd6b212e4ec08960',
            '0x507bdd06aca5facd19aa4b77037d3b9d48be2fb9', '0xb104ae8b7da105ca79cba208b9a41c1d63fff2c5',
            '0xf7a36c87c3a8909949638120f23cd721bf572032', '0x6bb2a9c00f293cd4ec94d5e78db7f71aa9182e45',
            '0x0da8ebc508b294236ea0e8af36e530354a19e98c', '0x0f5667ec8eb4ea84e8ccf8777a7019def9541e05',
            '0x6658cd8591285775fd31d525fc2b0f3b1dde9b47', '0x1d227f7e283d653a60f94d2350cab7a49bb85c6f',
            '0x6da9ee0c0571b63e38950d1e12e835d5343f601b', '0x7f8a46ec48442d9ebf28fbc1144a83f8bc53f7e9',
            '0xb9fa84912ff2383a617d8b433e926adf0dd3fea1', '0x1d791eaa684a21de92618dedea7bf373e2486956',
            '0x00470220dd82d5429379c8d9f679774b0e6e651d', '0x07f1b50d5ae24ec41aa7269d65a5e23e8401542a',
            '0x40ff83ac2890dd5469f5eca2c17dcaf10ee09957', '0x5ec32c21c9a6215d239f2bd0df22d7632b4717c3',
            '0x6451571cb5bee9fd575ad98506e96f3d09c66f91', '0x1f7d08d96d2520bd9196cb857e40d2a99e31de1a']
    farms = ["0x186be2a9f0e9c92b880bbd3ec1f35f422f0d8835", "0x1d227f7e283d653a60f94d2350cab7a49bb85c6f",
             "0x268a2c1acbeee3b74616b9fe3f07c1bf80841e5d", "0x3dfb186e8ce513f321232098dd551e22886c1051",
             "0x6da9ee0c0571b63e38950d1e12e835d5343f601b", "0xaaa6ddb2022541c44e488ea2b3f32c8c8726c107",
             "0xb6c9b20253a4bdc65d1fdc6f4ae04f57f6523915", "0xbb38f7551025a433f36590be85271110212655de",
             "0xbe85812237741d75f81aebf1d9af52d544542168", "0xc3a471421bb1364d74b8f384cd73fe34d2ce1773",
             "0xc75f626121fca17719d16fe8ea5fb601062301d1", "0xcd0678f92dd0d2cca7aa3818bf7805101635e215",
             "0xcf889a0902859662c17dc895abb7af49ee28a013", "0xe6e0646bd4fcd37ec7258d21295dd4cdc347f57a"]
    cands |= set(crit) | set(farms)
    cands.discard('0x' + '0' * 40)
    # priority order
    def prio(a):
        if a in set(crit) | set(farms): return 0
        v = max(int(np_['netpos'].get(a, 0)), grv.get(a, 0))
        if v >= 1000 * 10**18: return 1
        if v >= 10 * 10**18: return 2
        return 3
    order = sorted(cands, key=lambda a: (prio(a), a))
    order_repair = [a for a in order if prio(a) <= 2]
    print(f"[NAR_v2] repair scope (prio<=2): {len(order_repair)}", flush=True)
    repair_balances(s, order_repair, nar, 'NAR_v2')
    code_pass(s, order_repair, 'NAR_v2', 100 * 10**18, 'verified_NAR_v2.json')

    # ---------- THUGS verify ----------
    thugs = '0xe10e9822a5de22f8761919310dda35cd997d63c0'
    t = load_state(os.path.join(HERE, 'verified_THUGS.json'), blk)
    if t['block'] != blk:
        t = {'block': blk, 'balances': {}, 'code_len': {}}
    tcands = set()
    tp = json.load(open(os.path.join(HERE, 'thugs_recon_netpos.json')))
    tcands |= set(tp['netpos'].keys())
    pages = json.load(open(os.path.join(HERE, 'raw_goldrush', 'holders_THUGS.json')))
    tgrv = {}
    for pg in pages:
        for it in (pg.get('data') or {}).get('items') or []:
            tcands.add(it['address'].lower()); tgrv[it['address'].lower()] = int(it['balance'])
    tknown = ['0x' + '7' * 40, '0x000000000000000000000000000000000000dead',
              '0xe10e9822a5de22f8761919310dda35cd997d63c0',
              '0x40ff83ac2890dd5469f5eca2c17dcaf10ee09957',
              '0x586acb4be6cc93aa5c399888b255c7e864ea508e', '0xfd98d6dedc7ed8556ba61dc7902799c9815a5722',
              '0x71c1b6302c7f9c49ee3e675224b22cde34ab5ac7', '0x4d710603238427ae805b980bab8261624f5260c7',
              '0xb752f0cb591ecfb1c5058a93e1332f066bf38473', '0xcda85d0b4579ae31c1c2100141a6a59caca0b2d0',
              '0x7f8a46ec48442d9ebf28fbc1144a83f8bc53f7e9', '0xb104ae8b7da105ca79cba208b9a41c1d63fff2c5',
              '0x507bdd06aca5facd19aa4b77037d3b9d48be2fb9', '0x05ff2b0db69458a0750badebc4f9e13add608c7f']
    tcands |= set(tknown)
    tcands.discard('0x' + '0' * 40)

    def tprio(a):
        if a in set(tknown): return 0
        v = max(int(tp['netpos'].get(a, 0)), tgrv.get(a, 0))
        if v >= 100 * 10**18: return 1
        if v >= 10 * 10**18: return 2
        return 3
    torder = sorted(tcands, key=lambda a: (tprio(a), a))
    torder_repair = [a for a in torder if tprio(a) <= 2]
    print(f"[THUGS] repair scope (prio<=2): {len(torder_repair)}", flush=True)
    repair_balances(t, torder_repair, thugs, 'THUGS')
    code_pass(t, torder_repair, 'THUGS', 10 * 10**18, 'verified_THUGS.json')
    print('FINISHER_DONE', flush=True)

if __name__ == '__main__':
    main()
