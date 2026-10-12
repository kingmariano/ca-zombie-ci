#!/usr/bin/env python3
"""Read CDP depositor positions via the contract's own Multicall.aggregate (batched eth_call).
Usage: python3 read_positions.py <rpc_url_file_or_env>"""
import json, os, sys, subprocess, urllib.request, time

BASE = '/home/heisenberg/CA/cat-in-a-box'
ev = json.load(open(os.environ.get('EV_FILE','/tmp/opencode/cdp_events.json')))
CDP = os.environ.get('CDP_ADDR','0x7f0a0c7149a46bf943ccd412da687144b49c6014')

def sel(sig):
    return subprocess.check_output(['cast', 'keccak', sig]).decode().strip()[:10]

def enc_addr(a):
    return a.lower().replace('0x', '').rjust(64, '0')

def enc_uint(v):
    return format(v, 'x').rjust(64, '0')

DEP_SEL = sel('deposited(address)')
DEBT_SEL = sel('debt(address)')
FLAG_SEL = sel('enableRepaying(address)')
LASTP_SEL = sel('lastPoints(address)')

def inner(s, addr):
    return s + enc_addr(addr)

def build_aggregate(calls):
    # OZ Multicall.multicall(bytes[]) — delegatecalls each payload on this contract
    head = enc_uint(0x20)
    n = len(calls)
    arr = enc_uint(n)
    elems = []
    for (target, data) in calls:
        b = bytes.fromhex(data[2:])
        el = enc_uint(len(b)) + b.hex().ljust(((len(b)+31)//32)*64, '0')
        elems.append(el)
    offs = []
    cur = 32 * n
    for el in elems:
        offs.append(enc_uint(cur))
        cur += len(el) // 2
    body = ''.join(offs) + ''.join(elems)
    return '0x' + sel('multicall(bytes[])')[2:] + head + arr + body

def rpc_call(url, to, data, block, tries=4):
    payload = json.dumps({"jsonrpc":"2.0","id":1,"method":"eth_call","params":[{"to":to,"data":data}, hex(block)]}).encode()
    last = None
    for i in range(tries):
        try:
            req = urllib.request.Request(url, data=payload, headers={'Content-Type':'application/json','User-Agent':'Mozilla/5.0'})
            with urllib.request.urlopen(req, timeout=60) as r:
                j = json.load(r)
            if 'error' in j:
                raise RuntimeError(j['error'])
            return j['result']
        except Exception as e:
            last = e
            time.sleep(1.5 * (i + 1))
    raise last

def parse_bytes_array(res):
    b = bytes.fromhex(res[2:])
    def word(i): return int.from_bytes(b[i*32:(i+1)*32], 'big')
    off = word(0)
    n = int.from_bytes(b[off:off+32], 'big')
    out = []
    for i in range(n):
        eo = off + 32 + 32*i
        elem_off = off + 32 + word(eo//32)  # relative to array content start
        ln = int.from_bytes(b[elem_off:elem_off+32], 'big')
        data = b[elem_off+32: elem_off+32+ln]
        out.append(data)
    return out

def main():
    rpc = sys.argv[1] if len(sys.argv) > 1 else os.environ['RPC']
    block = int(open(f'{BASE}/analysis/latest_block.txt').read().strip())
    addrs = sorted(set(ev['dep']['addrs']) | set(ev['mint']['addrs']) | set(ev['wd']['addrs']) | set(ev['repay']['addrs']) | set(ev['sp']['addrs']) | set(ev['flag']['addrs']) | set(ev['liq']['addrs']))
    print(f'depositors/actors: {len(addrs)}', file=sys.stderr)
    results = {}
    B = 50
    for i in range(0, len(addrs), B):
        chunk = addrs[i:i+B]
        calls = []
        for a in chunk:
            calls.append((CDP, inner(DEP_SEL, a)))
            calls.append((CDP, inner(DEBT_SEL, a)))
            calls.append((CDP, inner(FLAG_SEL, a)))
        data = build_aggregate(calls)
        res = rpc_call(rpc, CDP, data, block)
        outs = parse_bytes_array(res)
        assert len(outs) == len(calls), (len(outs), len(calls))
        for j, a in enumerate(chunk):
            dep = int.from_bytes(outs[3*j], 'big')
            debt = int.from_bytes(outs[3*j+1], 'big')
            flag = int.from_bytes(outs[3*j+2], 'big')
            results[a] = {'deposited': dep, 'debt': debt, 'enableRepaying': bool(flag)}
        time.sleep(0.2)
    tot_dep = sum(v['deposited'] for v in results.values())
    tot_debt = sum(v['debt'] for v in results.values())
    print(f'sum deposited={tot_dep/1e18:.6f}  sum debt={tot_debt/1e18:.6f}', file=sys.stderr)
    active = {a: v for a, v in results.items() if v['deposited'] or v['debt']}
    print(f'active positions: {len(active)}', file=sys.stderr)
    out = {'block': block, 'contract': CDP, 'positions': results, 'sum_deposited': tot_dep, 'sum_debt': tot_debt}
    fn = os.environ.get('OUT_FILE', f'{BASE}/analysis/cdp_positions.json')
    json.dump(out, open(fn, 'w'), indent=1)
    for a, v in sorted(results.items(), key=lambda x: -(x[1]['deposited'])):
        if v['deposited'] or v['debt']:
            print(f"{a} deposited={v['deposited']/1e18:.6f} debt={v['debt']/1e18:.6f} repayFlag={v['enableRepaying']}")

if __name__ == '__main__':
    main()
