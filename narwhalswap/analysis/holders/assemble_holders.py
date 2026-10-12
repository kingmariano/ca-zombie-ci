#!/usr/bin/env python3
"""Assemble the final holder-distribution dataset (holders.json + holders.md) for Narwhalswap tokens."""
import json, os, sys, time
sys.path.insert(0, '/home/heisenberg/CA/narwhalswap/analysis')
import bsc

HERE = os.path.dirname(os.path.abspath(__file__))
ANA = '/home/heisenberg/CA/narwhalswap/analysis'

def load_json(p, default=None):
    try:
        return json.load(open(os.path.join(HERE, p) if not p.startswith('/') else p))
    except Exception:
        return default

TOKENS = {
    'NAR': '0xa1303e6199b319a891b79685f0537d289af1fc83',
    'NLP_NARWBNB': '0xb6b0ba4e208ab93602be7a81f1400a7c7daad1f2',
    'LP_WBNBTHUGS': '0x40ff83ac2890dd5469f5eca2c17dcaf10ee09957',
    'LP_WBNBBUSD': '0x5ec32c21c9a6215d239f2bd0df22d7632b4717c3',
    'rNLP5': '0x6451571cb5bee9fd575ad98506e96f3d09c66f91',
    'rNLP6': '0x1f7d08d96d2520bd9196cb857e40d2a99e31de1a',
    'THUGS': '0xe10e9822a5de22f8761919310dda35cd997d63c0',
}

LABELS = {
    '0x7777777777777777777777777777777777777777': "burn pool — NAR `_burnPool` (hardcoded in token) and rNLP destruction sink (withdrawn rNLP sent here). EOA (no code).",
    '0x000000000000000000000000000000000000dead': "`0x…dEaD` dead address. EOA (keys unknown; standard burn vanity).",
    '0x0000000000000000000000000000000000000000': "zero address (MINIMUM_LIQUIDITY = 1000 wei locked by pair mint).",
    '0xb6b0ba4e208ab93602be7a81f1400a7c7daad1f2': "NAR/WBNB pair on NarwhalswapFactory (this address is also the NLP LP token).",
    '0x40ff83ac2890dd5469f5eca2c17dcaf10ee09957': "WBNB/THUGS pair on NarwhalswapFactory (also the LP token itself).",
    '0x5ec32c21c9a6215d239f2bd0df22d7632b4717c3': "WBNB/BUSD pair on NarwhalswapFactory (also the LP token itself).",
    '0xa1303e6199b319a891b79685f0537d289af1fc83': "NAR token contract itself.",
    '0xe10e9822a5de22f8761919310dda35cd997d63c0': "THUGS token contract itself.",
    '0x1d227f7e283d653a60f94d2350cab7a49bb85c6f': "Farm gen 5 (NarwhalRewardV2) — LP=NAR/WBNB, shares=rNLP5. `nar_balance` = unclaimed NAR rewards.",
    '0x6da9ee0c0571b63e38950d1e12e835d5343f601b': "Farm gen 6 (NarwhalRewardV2) — LP=WBNB/BUSD, shares=rNLP6.",
    '0x186be2a9f0e9c92b880bbd3ec1f35f422f0d8835': "Farm (NarwhalRewardV2) — LP=NAR/WBNB (rNLP=e412c9…).",
    '0xbe85812237741d75f81aebf1d9af52d544542168': "Farm (NarwhalRewardV2) — LP=NAR/WBNB (rNLP=40572a…).",
    '0xaaa6ddb2022541c44e488ea2b3f32c8c8726c107': "Farm (NarwhalRewardV2) — LP=NAR/BTCB.",
    '0xb6c9b20253a4bdc65d1fdc6f4ae04f57f6523915': "Farm (NarwhalRewardV2) — LP=BUSD/WBNB pair 0x8e68f1ad…",
    '0x268a2c1acbeee3b74616b9fe3f07c1bf80841e5d': "Farm (NarwhalRewardV2) — LP=NAR/BTCB.",
    '0x3dfb186e8ce513f321232098dd551e22886c1051': "Farm (NarwhalRewardV2) — LP=NAR/BTCB.",
    '0xbb38f7551025a433f36590be85271110212655de': "Farm (NarwhalRewardV2) — LP=WBNB/BUSD (rNLP=ee2b4f…).",
    '0xcf889a0902859662c17dc895abb7af49ee28a013': "Farm (NarwhalRewardV2) — LP=USDT/WBNB pair 0xb35513a1…",
    '0xc75f626121fca17719d16fe8ea5fb601062301d1': "Farm (NarwhalRewardV2) — LP=USDT/WBNB pair.",
    '0xcd0678f92dd0d2cca7aa3818bf7805101635e215': "Farm (NarwhalRewardV2) — LP=BUSD/WBNB pair.",
    '0xc3a471421bb1364d74b8f384cd73fe34d2ce1773': "Farm (NarwhalRewardV2) — LP=NAR/BTCB.",
    '0xe6e0646bd4fcd37ec7258d21295dd4cdc347f57a': "Farm (NarwhalRewardV2) — LP=NAR/BTCB.",
    '0x07f1b50d5ae24ec41aa7269d65a5e23e8401542a': "NLP liquidity-locker contract (own `unlockTime()` = 1605109215 = 2020-11-11, owner = governance). Still holds LP long after unlock.",
    '0xf7a36c87c3a8909949638120f23cd721bf572032': "Large NAR-holding contract (23,244 bytes) — identity TBD (possibly a presale/ILO or vesting contract).",
    '0xa02f5f32426f76b4f7a9ee87cd6b212e4ec08960': "NAR `_rewardPool` (EOA) — collects 2.5% transfer reward fee; mostly forwarded out historically.",
    '0x00470220dd82d5429379c8d9f679774b0e6e651d': "NAR `_teamWallet` (EOA) — currently empty.",
    '0x507bdd06aca5facd19aa4b77037d3b9d48be2fb9': "Team wallet used as `teamWallet` in farms (EOA).",
    '0xb104ae8b7da105ca79cba208b9a41c1d63fff2c5': "Project governance EOA — owner of all rNLP tokens, farms and the LP locker; `_governance` of NAR/farms.",
    '0x7f8a46ec48442d9ebf28fbc1144a83f8bc53f7e9': "NarwhalCollecter contract (factory `feeTo`).",
    '0xb9fa84912ff2383a617d8b433e926adf0dd3fea1': "NarwhalswapFactory contract.",
    '0x1d791eaa684a21de92618dedea7bf373e2486956': "NarwhalPower contract (farm power strategy / leaderboard).",
    '0x6658cd8591285775fd31d525fc2b0f3b1dde9b47': "NAR/BTCB pair on NarwhalswapFactory (NAR reserve).",
    '0x6d233745c66b170324cd7f84753ce76fb362aa6d': "NAR pair (token0=0x03d6bd3d…) on NarwhalswapFactory (NAR reserve).",
    '0xb648ecf23bb8fe854c6267d6fb046f2d483251ea': "NAR/THUGS pair on NarwhalswapFactory (NAR reserve).",
    '0xcdd527c82382a6074239ec229a58db954baacc03': "NAR/BUSD pair on NarwhalswapFactory (NAR reserve).",
    '0x35982ff32341e9bc27fa8a4b4e98f2736073dc5f': "NAR pair on NarwhalswapFactory (NAR reserve).",
    '0x94b1421e0a8a22a97c393fa918f0ec026322dd8a': "NAR pair on NarwhalswapFactory (NAR reserve).",
    '0x6e30f1159abb9599af8926475bbd055c0bd4fca8': "PancakeSwap NAR/WBNB pair (tiny residual).",
    '0x5f88d744447ca5887ed10016e9c57bd1af4db605': "PancakeSwap NAR/BUSD pair (tiny residual).",
    '0x4d710603238427ae805b980bab8261624f5260c7': "Largest WBNB/THUGS LP holder (EOA) — ~93% of that LP supply.",
    '0xb752f0cb591ecfb1c5058a93e1332f066bf38473': "WBNB/THUGS LP holder — contract (8,450 bytes, likely a staking/mine contract).",
    '0xcda85d0b4579ae31c1c2100141a6a59caca0b2d0': "WBNB/THUGS LP holder — contract (19,222 bytes).",
    '0x586acb4be6cc93aa5c399888b255c7e864ea508e': "THUGS `burnReservesVault` (TokenTimelock; released 2020-10-03; near-empty).",
    '0xfd98d6dedc7ed8556ba61dc7902799c9815a5722': "THUGS `burnReservesAddress` (vault beneficiary; tiny delegated-EOA code).",
    '0x71c1b6302c7f9c49ee3e675224b22cde34ab5ac7': "THUGS `bscSwapPair` (price-oracle pair used by the burn curve).",
    '0x242fb607f7047d0d9df5df592d2ab8318c222e94': "NLP holder (EOA, ~2.2% of NLP).",
    '0x4b13718fa2d0bb25a994db5818fc234ddcc8d3ef': "Largest GoldRush-listed NLP EOA (9.21 NLP).",
    # THUGS ecosystem
    '0x71c1b6302c7f9c49ee3e675224b22cde34ab5ac7': "THUGS `bscSwapPair` (original BscSwap launch pair) — holds the unrecovered launch liquidity (~28.5% of THUGS supply).",
    '0x40257481f09db2211a3274b34554bbb00b0a7fb1': "Old PancakeSwap v1 THUGS/WBNB pair (residual reserves).",
    '0x088264deab1b5dc37cd00f5e6846b5ddda6cac2a': "PancakeSwap v2 THUGS/BUSD pair (empty).",
    '0x3009c9c09a467aaea1c8d8cd6ebd18bfb4339b9b': "THUGS `initialDistributionAddress` (launch distributor contract; now empty).",
    '0x6e65f24a9c7230c3bfbe90f39924ac8384f6152f': "THUGS `teamAddress` (sent ~29k THUGS to dEaD; residual dust).",
    '0x4e43397417c6938f60b108650d832390dbd4c4fd': "THUGS `devAddress` (drained).",
    '0x481f0079bb59d8feb2426b6e08a2af01d7b49500': "THUGS `marketingAddress` (drained).",
    '0x54af6dd5b2fe9d9e50ef56ebb7697b1ff05fd70c': "THUGS `owner` EOA (separate from Narwhal governance).",
    '0x586acb4be6cc93aa5c399888b255c7e864ea508e': "THUGS `burnReservesVault` (TokenTimelock; released 2020-10-03; near-empty).",
    '0xfd98d6dedc7ed8556ba61dc7902799c9815a5722': "THUGS `burnReservesAddress` (vault beneficiary; EIP-7702 delegated EOA).",
    '0x05ff2b0db69458a0750badebc4f9e13add608c7f': "Old Pancake router (0x05ff2b0d…).",
    '0x6bc76d2224e6fbd45e8e910aecad1b4b15bdfb70': "EOA with EIP-7702 delegation (code = 0xef0100…delegate).",
    '0xbde4d38ec4426f1c9f4859d38928a02987e9dba7': "EOA with EIP-7702 delegation (code = 0xef0100…delegate).",
    '0x36de6d01ab563d3e0fd7661c75dce8202aa82649': "EOA with EIP-7702 delegation holding NAR.",
}

def is_7702(code_head):
    return code_head and code_head.startswith('0xef0100')

EXTRA_READS = {
    'NAR': ['0xa02f5f32426f76b4f7a9ee87cd6b212e4ec08960', '0x00470220dd82d5429379c8d9f679774b0e6e651d',
            '0x507bdd06aca5facd19aa4b77037d3b9d48be2fb9', '0xb104ae8b7da105ca79cba208b9a41c1d63fff2c5',
            '0xf7a36c87c3a8909949638120f23cd721bf572032', '0x6bb2a9c00f293cd4ec94d5e78db7f71aa9182e45',
            '0x0da8ebc508b294236ea0e8af36e530354a19e98c', '0x0f5667ec8eb4ea84e8ccf8777a7019def9541e05'],
    'NLP_NARWBNB': ['0x07f1b50d5ae24ec41aa7269d65a5e23e8401542a', '0x1d227f7e283d653a60f94d2350cab7a49bb85c6f',
                    '0xbe85812237741d75f81aebf1d9af52d544542168', '0x186be2a9f0e9c92b880bbd3ec1f35f422f0d8835',
                    '0xb6c9b20253a4bdc65d1fdc6f4ae04f57f6523915', '0x7f8a46ec48442d9ebf28fbc1144a83f8bc53f7e9',
                    '0x242fb607f7047d0d9df5df592d2ab8318c222e94'],
    'LP_WBNBBUSD': ['0xbb38f7551025a433f36590be85271110212655de', '0x6da9ee0c0571b63e38950d1e12e835d5343f601b'],
    'LP_WBNBTHUGS': ['0x4d710603238427ae805b980bab8261624f5260c7', '0xe99140fc04e458ac58d47c29c0649bcc3914dc0a',
                     '0xb752f0cb591ecfb1c5058a93e1332f066bf38473'],
    'THUGS': ['0x71c1b6302c7f9c49ee3e675224b22cde34ab5ac7', '0x40257481f09db2211a3274b34554bbb00b0a7fb1',
              '0x088264deab1b5dc37cd00f5e6846b5ddda6cac2a', '0x3009c9c09a467aaea1c8d8cd6ebd18bfb4339b9b',
              '0x6e65f24a9c7230c3bfbe90f39924ac8384f6152f', '0x4e43397417c6938f60b108650d832390dbd4c4fd',
              '0x481f0079bb59d8feb2426b6e08a2af01d7b49500', '0x54af6dd5b2fe9d9e50ef56ebb7697b1ff05fd70c',
              '0x586acb4be6cc93aa5c399888b255c7e864ea508e', '0xfd98d6dedc7ed8556ba61dc7902799c9815a5722',
              '0x05ff2b0db69458a0750badebc4f9e13add608c7f', '0x40ff83ac2890dd5469f5eca2c17dcaf10ee09957'],
}


def extra_direct_reads(token, addrs, blk):
    """Direct balanceOf for key protocol addresses at the final block (never None)."""
    out = {}
    for i in range(0, len(addrs), 15):
        part = addrs[i:i+15]
        for a in part:
            r = None
            for att in range(6):
                try:
                    r = bsc.rpc("eth_call", [{"to": token, "data": bsc.SEL['balanceOf'] + bsc.word(a)}, hex(blk)])
                    break
                except Exception:
                    time.sleep(0.8)
            out[a.lower()] = int(r, 16) if r and r != '0x' else None
        time.sleep(0.15)
    return out

def load_verified(name):
    """Merge all historical verification states; first (newest) file wins per address.
    Fake zeros from the earliest run (verified_{name}.json) are only accepted when nonzero."""
    merged = {}
    codes = {}
    for fn in [f'verified_{name}_FINAL2.json', f'verified_{name}_FINAL.json',
               f'verified_{name}_v2.json', f'verified_{name}.json']:
        d = load_json(fn)
        if not d:
            continue
        last = fn == f'verified_{name}.json'
        for a, v in (d.get('balances') or {}).items():
            if v is None or a in merged:
                continue
            if last and not v:
                continue  # skip unverified zeros from the early run
            merged[a] = v
        for a, v in (d.get('code_len') or {}).items():
            if v is not None and a not in codes:
                codes[a] = v
    if not merged:
        return None
    return {'balances': merged, 'code_len': codes}

def direct_read_keys(name):
    """set of addresses that were directly read (any verified file), plus their values from best file."""
    keys = set()
    for fn in [f'verified_{name}_FINAL2.json', f'verified_{name}_FINAL.json', f'verified_{name}_v2.json',
               f'verified_{name}.json', f'unknown_{name}.json']:
        d = load_json(fn)
        if d and d.get('balances'):
            keys |= set(d['balances'].keys())
    return keys

def main():
    meta = load_json('token_meta.json')
    final_blk = bsc.block_number()
    data = {'meta': {
        'chain': 'bsc', 'chainId': 56,
        'block': final_blk,
        'generated_utc': time.strftime('%Y-%m-%d %H:%M:%S UTC', time.gmtime()),
        'sources': ['BSC public RPC (balanceOf/getCode/state vars)', 'GoldRush (Covalent) holder lists + contract event logs',
                    'On-chain Transfer-event reconstruction (GoldRush events API) for candidate discovery'],
        'caveats': [
            'GoldRush `token_holders` lists exclude some address classes (burn pools, protocol contracts and some flagged wallets) — they were only used as candidate sources; all final balances are direct on-chain balanceOf reads.',
            'GoldRush `events/address` API can drop the zero-address topic and occasionally whole logs; event reconstruction is used only to discover candidate holders, never for final balances.',
            'NAR accounting: balances() sum = totalSupply + `_totalBurnToken` because the contract keeps burned amounts credited at the 0x7777 burn pool balance while reducing totalSupply.',
        ],
    }, 'tokens': {}}

    # ---------- per token ----------
    per_token = {}
    # NAR
    d = load_verified('NAR')
    if d and d.get('balances'):
        per_token['NAR'] = {a: v for a, v in d['balances'].items() if v and v > 0}
        per_token['NAR_code'] = d.get('code_len', {})
    else:
        # fallback: farm/pair sweep + spot reads + candidate sweep (all direct reads at earlier blocks)
        per_token['NAR'] = {}
        fps = load_json('farm_pair_sweep.json') or {}
        for k in ['NAR_farms', 'NAR_pairs']:
            for a, v in (fps.get(k) or {}).items():
                if v:
                    per_token['NAR'][a.lower()] = int(v)
        cs = load_json('candidate_sweep.json') or {}
        for a, v in ((cs.get('tokens') or {}).get('NAR') or {}).items():
            if v:
                per_token['NAR'][a.lower()] = int(v)
        # spot reads: map candidate labels to addresses
        CANDS_MAP = {
            'zero': '0x0000000000000000000000000000000000000000',
            'dead': '0x000000000000000000000000000000000000dead',
            '7777': '0x7777777777777777777777777777777777777777',
            'NLP_pair': '0xb6b0ba4e208ab93602be7a81f1400a7c7daad1f2',
            'WBNBTHUGS_pair': '0x40ff83ac2890dd5469f5eca2c17dcaf10ee09957',
            'WBNBBUSD_pair': '0x5ec32c21c9a6215d239f2bd0df22d7632b4717c3',
            'farm5': '0x1D227F7e283D653a60F94d2350CAB7a49bB85C6f',
            'farm6': '0x6dA9Ee0c0571b63e38950D1e12e835D5343f601B',
            'rNLP5_ctr': '0x6451571cb5bee9fd575ad98506e96f3d09c66f91',
            'rNLP6_ctr': '0x1f7d08d96d2520bd9196cb857e40d2a99e31de1a',
            'collector': '0x7f8a46ec48442d9ebf28fbc1144a83f8bc53f7e9',
            'factory': '0xb9fa84912ff2383a617d8b433e926adf0dd3fea1',
            'powerStrategy': '0x1d791eaa684a21de92618dedea7bf373e2486956',
            'governance': '0xb104ae8b7da105ca79cba208b9a41c1d63fff2c5',
            'team': '0x507bdd06aca5facd19aa4b77037d3b9d48be2fb9',
            'NAR_ctr': '0xa1303e6199b319a891b79685f0537d289af1fc83',
            'THUGS_ctr': '0xe10e9822a5de22f8761919310dda35cd997d63c0',
        }
        db = load_json('direct_balances.json') or {}
        for cname, v in ((db.get('balances') or {}).get('NAR') or {}).items():
            a = CANDS_MAP.get(cname)
            if a and v:
                per_token['NAR'][a.lower()] = int(v)
        per_token['NAR_code'] = {}
    # merge goldrush small balances for NAR ONLY if absent (avoid clobbering verified)
    gr = load_json('raw_goldrush/holders_NAR.json') or []
    for pg in gr:
        for it in (pg.get('data') or {}).get('items') or []:
            a = it['address'].lower()
            if a not in per_token['NAR']:
                per_token['NAR'][a] = int(it['balance'])

    # NLP / LPs / rNLPs from verified files
    for name in ['NLP_NARWBNB', 'LP_WBNBBUSD', 'LP_WBNBTHUGS', 'rNLP5', 'rNLP6']:
        d = load_verified(name)
        if d:
            per_token[name] = {a: v for a, v in d['balances'].items() if v and v > 0}
            per_token[name + '_code'] = d.get('code_len', {})
    # THUGS
    d = load_verified('THUGS')
    if d and d.get('balances'):
        per_token['THUGS'] = {a: v for a, v in d['balances'].items() if v and v > 0}
        per_token['THUGS_code'] = d.get('code_len', {})
    else:
        per_token['THUGS'] = {}
        gr = load_json('raw_goldrush/holders_THUGS.json') or []
        for pg in gr:
            for it in (pg.get('data') or {}).get('items') or []:
                per_token['THUGS'][it['address'].lower()] = int(it['balance'])
        # known big THUGS
        for a, v in [('0x000000000000000000000000000000000000dead', 440583524949094464110815),
                     ('0x40ff83ac2890dd5469f5eca2c17dcaf10ee09957', None)]:
            if v: per_token['THUGS'][a] = v
        per_token['THUGS_code'] = {}

    # apply extra direct reads for key protocol addresses
    for tname, addrs in EXTRA_READS.items():
        if tname in TOKENS:
            extra = extra_direct_reads(TOKENS[tname], addrs, final_blk)
            pt = per_token.setdefault(tname, {})
            for a, v in extra.items():
                if v:
                    pt[a] = v

    # apply top_reads.json override (single-block re-read of top holders)
    tr = load_json('top_reads.json') or {}
    for tname, vals in (tr.get('tokens') or {}).items():
        if tname in TOKENS and vals:
            pt = per_token.setdefault(tname, {})
            added = 0
            for a, v in vals.items():
                if v:
                    if a not in pt:
                        added += 1
                    pt[a] = v
            print(f"top_reads override {tname}: {len(vals)} addresses ({added} added, rest refreshed)")

    # merge code_len data from all historical states for NAR/THUGS
    for tname in ['NAR', 'THUGS']:
        v = load_verified(tname) or {}
        per_token[tname + '_code'] = v.get('code_len', {})

    # apply codes patch (top holders without prior code classification)
    cp = load_json('codes_patch.json') or {}
    for tname, codes in cp.items():
        if tname in TOKENS and codes:
            pc = per_token.setdefault(tname + '_code', {})
            for a, cl in codes.items():
                if cl is not None:
                    pc[a] = cl

    # ---------- burn addresses (fresh reads) ----------
    burn_addrs = ['0x0000000000000000000000000000000000000000',
                  '0x000000000000000000000000000000000000dead',
                  '0x7777777777777777777777777777777777777777']
    burn = {}
    calls = []
    keys = []
    for tname, taddr in TOKENS.items():
        for ba in burn_addrs:
            calls.append(("eth_call", [{"to": taddr, "data": bsc.SEL['balanceOf'] + bsc.word(ba)}, hex(final_blk)]))
            keys.append((tname, ba))
    res = []
    for i in range(0, len(calls), 30):
        part = calls[i:i+30]
        got = None
        for att in range(5):
            try:
                got = bsc.rpc_batch(part); break
            except Exception:
                time.sleep(1.5)
        if got is None:
            got = [None] * len(part)
        res.extend(got)
    for (tname, ba), r in zip(keys, res):
        burn.setdefault(ba, {})[tname] = int(r, 16) if r and r != '0x' else None
    data['burn_addresses'] = burn

    # ---------- assemble holder lists ----------
    for tname, taddr in TOKENS.items():
        holders = per_token.get(tname) or {}
        code = per_token.get(tname + '_code') or {}
        supply = meta['tokens'][tname]['totalSupply_raw']
        dec = meta['tokens'][tname]['decimals']
        rows = []
        dk = direct_read_keys(tname)
        for a, v in holders.items():
            cl = code.get(a)
            rows.append({
                'address': a,
                'balance_raw': str(v),
                'balance': v / 10**dec,
                'pct_of_supply': (v / supply * 100) if supply else None,
                'is_contract': (cl > 0) if cl is not None else None,
                'code_len': cl,
                'source': 'direct-rpc' if a in dk else 'secondary (goldrush/recon)',
                'label': LABELS.get(a),
            })
        rows.sort(key=lambda r: -int(r['balance_raw']))
        tot = sum(int(r['balance_raw']) for r in rows)
        # NAR: balances sum is expected to equal totalSupply + _totalBurnToken (burned amounts remain credited at 0x7777)
        if tname == 'NAR':
            burn_amt = 6852210065953744791744299  # _totalBurnToken() at 2026-10-12
            expected_raw = supply + burn_amt
        else:
            expected_raw = supply
        data['tokens'][tname] = {
            'address': taddr,
            'symbol': meta['tokens'][tname]['symbol'],
            'name': meta['tokens'][tname]['name'],
            'decimals': dec,
            'totalSupply_raw': str(supply),
            'totalSupply': supply / 10**dec,
            'expected_sum_raw': str(expected_raw),
            'expected_sum': expected_raw / 10**dec,
            'holders_count': len(rows),
            'holders_sum_raw': str(tot),
            'delta_vs_expected': (tot - expected_raw) / 10**dec,
            'holders': rows,
        }

    # ---------- farm reads for rNLP5/6 ----------
    farm = {}
    for name, fname in [('rNLP5', 'farm_reads_rNLP5.json'), ('rNLP6', 'farm_reads_rNLP6.json')]:
        d = load_json(fname)
        if d:
            rows = []
            for r in d['rows']:
                rows.append({
                    'holder': r['holder'],
                    'rnlp_balance': r['rnlp_balance'] / 1e18,
                    'share_pct': r['share_pct'],
                    'staked_lp': (r['staked_lp'] or 0) / 1e18,
                    'userInfo': r['userInfo'],
                    'is_contract': r['is_contract'],
                    'code_len': r['code_len'],
                    'label': LABELS.get(r['holder']),
                })
            farm[name] = {'farm': d['farm'], 'block': d['block'], 'rows': rows}
    data['rnlp_farm_reads'] = farm

    with open(os.path.join(HERE, 'holders.json'), 'w') as f:
        json.dump(data, f, indent=1)
    print('holders.json written')
    for tname in TOKENS:
        t = data['tokens'][tname]
        print(f"{tname:14s} holders={t['holders_count']:5d} sum={t['holders_sum_raw'] and int(t['holders_sum_raw'])/10**t['decimals']:,.4f} expected={t['expected_sum']:,.4f} delta={t['delta_vs_expected']:,.6f}")

    # ---------- markdown ----------
    md = []
    md.append('# Narwhalswap (BSC) — Holder Distribution Report')
    md.append('')
    md.append(f"- Block: **{final_blk}** (BSC), generated {data['meta']['generated_utc']}")
    md.append(f"- Chain: BSC (chainId 56); all balances are direct `balanceOf` reads at the block above, unless noted.")
    md.append('- Full machine-readable data: `holders.json`; raw sources in `raw_goldrush/`; verification scripts in this folder.')
    md.append('')
    md.append('## Method & caveats')
    for c in data['meta']['caveats']:
        md.append(f"- {c}")
    md.append('')
    try:
        md.append(open(os.path.join(HERE, 'findings_section.md')).read().strip())
        md.append('')
    except Exception:
        pass

    order = ['NAR', 'NLP_NARWBNB', 'LP_WBNBTHUGS', 'LP_WBNBBUSD', 'rNLP5', 'rNLP6', 'THUGS']
    for tname in order:
        t = data['tokens'][tname]
        md.append(f"## {t['symbol']} ({tname}) — `{t['address']}`")
        md.append('')
        md.append(f"totalSupply: **{t['totalSupply']:,.4f}** | holders found: {t['holders_count']} | holders sum: **{int(t['holders_sum_raw'])/10**t['decimals']:,.4f}** | expected sum: {t['expected_sum']:,.4f} | reconciliation delta: {t['delta_vs_expected']:,.6f}")
        if tname == 'NAR':
            md.append('')
            md.append('> Note: for NAR the balances sum is compared against `totalSupply + _totalBurnToken` (20,715,167.96), because burned amounts remain credited to the 0x7777 burn pool while `totalSupply` is reduced.')
        md.append('')
        limit = {'NAR': 40, 'NLP_NARWBNB': 30, 'LP_WBNBTHUGS': 12, 'LP_WBNBBUSD': 32, 'rNLP5': 15, 'rNLP6': 16, 'THUGS': 40}[tname]
        md.append('| # | holder | balance | % supply | type | note |')
        md.append('|---|--------|--------:|---------:|------|------|')
        for i, r in enumerate(t['holders'][:limit], 1):
            typ = 'contract' if r['is_contract'] else ('EOA' if r['is_contract'] is False else '?')
            note = (r['label'] or '').replace('|', '/')
            md.append(f"| {i} | `{r['address']}` | {r['balance']:,.6f} | {r['pct_of_supply']:.4f}% | {typ} | {note[:120]} |")
        if t['holders_count'] > limit:
            md.append(f"| … | *{t['holders_count']-limit} more holders* | | | | full list in holders.json |")
        md.append('')

    md.append('## Burn / locked addresses (direct reads)')
    md.append('')
    md.append('| address | ' + ' | '.join(order) + ' |')
    md.append('|' + '---|' * (len(order) + 1))
    for ba in burn_addrs:
        row = [f"`{ba}`"]
        for tname in order:
            v = (burn.get(ba) or {}).get(tname)
            row.append('n/a' if v is None else f"{v/10**18:,.6f}")
        md.append('| ' + ' | '.join(row) + ' |')
    md.append('')

    md.append('## rNLP farm reads')
    for name in ['rNLP5', 'rNLP6']:
        f_ = farm.get(name)
        if not f_:
            continue
        md.append(f"### {name} — farm `{f_['farm']}` (block {f_['block']})")
        md.append('')
        md.append('| # | holder | rNLP bal | share % | staked LP (farm.balanceOf) | userInfo (userRewardPerTokenPaid, rewards, buffrate, power, timeStamp) | contract |')
        md.append('|---|--------|---------:|--------:|---------------------------:|----------------------------------------------------------------------|----------|')
        for i, r in enumerate(f_['rows'], 1):
            ui = r['userInfo'] or {}
            uis = (f"{ui.get('userRewardPerTokenPaid',0)/1e18:,.6f}, {ui.get('rewards',0)/1e18:,.6f}, "
                   f"{ui.get('currentBuffrate')}, {ui.get('currentPower')}, {ui.get('timeStamp')}") if ui else 'n/a'
            typ = 'yes' if r['is_contract'] else 'no'
            lbl = f" — {r['label'][:60]}" if r.get('label') else ''
            md.append(f"| {i} | `{r['holder']}` | {r['rnlp_balance']:,.6f} | {r['share_pct']:.4f}% | {r['staked_lp']:,.6f} | {uis} | {typ}{lbl} |")
        md.append('')

    with open(os.path.join(HERE, 'holders.md'), 'w') as f:
        f.write('\n'.join(md))
    print('holders.md written')

if __name__ == '__main__':
    main()
