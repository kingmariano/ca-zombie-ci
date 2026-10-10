#!/usr/bin/env python3
"""
Bytecode verification for StarGate proxy implementation.

Strategy:
 1. Take the standard-JSON input Sourcify used to verify the v2 impl (0xcd2d50c1, exact match).
 2. Recompile it locally with solc 0.8.20, substitute the Clock library link-references
    with the address observed in the verified on-chain runtime bytecode -> keccak must match.
    (Toolchain validation.)
 3. Swap in the hotfixed Stargate.sol (repo commit b8b695b), recompile,
    substitute link refs with the address extracted from the LIVE runtime bytecode
    (0x987f2ebf) -> keccak must match live code. Proves the live code == hotfix source.
"""
import json, subprocess, os, sys, hashlib

BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RAW = os.path.join(BASE, 'raw')
# solc 0.8.20 binary. Download once if missing:
#   curl -s -o tools/solc-0.8.20 https://binaries.soliditylang.org/linux-amd64/solc-linux-amd64-v0.8.20+commit.a1b79de6 && chmod +x tools/solc-0.8.20
SOLC = os.path.join(BASE, 'tools', 'solc-0.8.20')

def keccak_hex(h: str) -> str:
    # use cast (local foundry) to keccak a hex string
    out = subprocess.run(['cast', 'keccak', h], capture_output=True, text=True, check=True)
    return out.stdout.strip()

def compile_std(input_obj):
    p = subprocess.run([SOLC, '--standard-json'], input=json.dumps(input_obj),
                       capture_output=True, text=True)
    if p.returncode != 0:
        print(p.stderr[:2000]); sys.exit(1)
    return json.loads(p.stdout)

def deploy_code(out, contract='contracts/Stargate.sol:Stargate'):
    c = out['contracts']
    key = [k for k in c if k.endswith('contracts/Stargate.sol')][0]
    return c[key]['Stargate']['evm']['deployedBytecode']

def fill_sources(template, srcdir):
    inp = json.loads(json.dumps(template))
    for k in list(inp['sources'].keys()):
        fn = os.path.join(srcdir, k.replace('/', '__'))
        inp['sources'][k] = {'content': open(fn).read()}
    inp['settings']['outputSelection'] = {
        '*': {'*': ['evm.deployedBytecode', 'evm.bytecode', 'metadata']}
    }
    return inp

def substitute_links(code_hex, linkrefs, onchain_hex, immutables=None):
    """Replace link placeholders + immutables in compiled code with values read from onchain code."""
    import re
    if code_hex.startswith('0x'):
        code_hex = code_hex[2:]
    code_hex = re.sub(r'__\$[0-9a-fA-F]{34}\$__', '0' * 40, code_hex)  # zero out placeholders
    code = bytearray.fromhex(code_hex)
    onchain = bytearray.fromhex(onchain_hex[2:] if onchain_hex.startswith('0x') else onchain_hex)
    for f, libs in linkrefs.items():
        for lib, positions in libs.items():
            for pos in positions:
                start, length = pos['start'], pos['length']
                addr = onchain[start:start+length]
                code[start:start+length] = addr
                print(f'  link {f}:{lib} @ {start} len {length} -> 0x{addr.hex()}')
    if immutables:
        for node, positions in immutables.items():
            for pos in positions:
                start, length = pos['start'], pos['length']
                code[start:start+length] = onchain[start:start+length]
        print(f'  filled {sum(len(p) for p in immutables.values())} immutable word(s) from onchain')
    return '0x' + code.hex()

def main():
    template = json.load(open(os.path.join(RAW, 'v2_input_template.json')))
    v2_src = os.path.join(RAW, 'v2_sources')

    # --- Step 1: toolchain validation on v2 ---
    print('== Step 1: compile v2 input, compare to verified 0xcd2d50c1 runtime ==')
    inp = fill_sources(template, v2_src)
    out = compile_std(inp)
    dc = deploy_code(out)
    s2 = json.load(open(os.path.join(RAW, 'sourcify_0xcd2d50c1.json')))
    onchain = s2['runtimeBytecode']['onchainBytecode']
    fixed = substitute_links(dc['object'], dc['linkReferences'], onchain, dc.get('immutableReferences'))
    h1, h2 = keccak_hex(fixed), keccak_hex(onchain)
    print('compiled+linked keccak:', h1)
    print('onchain v2 keccak     :', h2)
    print('MATCH' if h1 == h2 else 'MISMATCH')
    if h1 != h2:
        sys.exit(2)

    # --- Step 2: hotfixed source vs LIVE impl 0x987f2ebf ---
    print()
    print('== Step 2: hotfix source (repo b8b695b) vs live impl 0x987f2ebf ==')
    fixed_src = open(os.path.join(RAW, 'live_source', 'Stargate.sol')).read()
    # assert the fix markers are present
    assert 'F-2026-14785' in fixed_src, 'hotfix marker missing in source'
    inp['sources']['contracts/Stargate.sol'] = {'content': fixed_src}
    # all other sources identical between the two versions? keep as-is.
    out2 = compile_std(inp)
    dc2 = deploy_code(out2)
    live = open(os.path.join(RAW, 'impl_code.json.code')).read().strip()
    fixed2 = substitute_links(dc2['object'], dc2['linkReferences'], live, dc2.get('immutableReferences'))
    h3, h4 = keccak_hex(fixed2), keccak_hex(live)
    print('compiled+linked keccak:', h3)
    print('LIVE impl keccak      :', h4)
    print('MATCH' if h3 == h4 else 'MISMATCH')
    # save the linked compiled code for diffing if mismatch
    open(os.path.join(RAW, 'compiled_hotfix_linked.hex'), 'w').write(fixed2)
    return 0 if h3 == h4 else 3

if __name__ == '__main__':
    sys.exit(main())
