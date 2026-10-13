import json, urllib.request, sys

RPC = "https://rpc.monad.xyz"
def rpc(method, params):
    req = urllib.request.Request(RPC, data=json.dumps({"jsonrpc":"2.0","id":1,"method":method,"params":params}).encode(), headers={"Content-Type":"application/json"})
    with urllib.request.urlopen(req, timeout=30) as r:
        d = json.load(r)
    if 'error' in d: raise RuntimeError(d['error'])
    return d['result']

def call(to, sig, args=None):
    # sig like 'governanceOnlyKick()'
    from Crypto.Hash import keccak
    sel = keccak.new(digest_bits=256, data=sig.encode()).hexdigest()[:8]
    data = '0x' + sel
    if args:
        for a in args:
            data += a[2:] if a.startswith('0x') else a
    return rpc('eth_call', [{"to": to, "data": data}, "latest"])
