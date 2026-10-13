import json, urllib.request
from Crypto.Hash import keccak
RPC="https://rpc.hyperliquid.xyz/evm"
def _rpc(method, params):
    req=urllib.request.Request(RPC,data=json.dumps({"jsonrpc":"2.0","id":1,"method":method,"params":params}).encode(),headers={"Content-Type":"application/json"})
    with urllib.request.urlopen(req,timeout=30) as r: d=json.load(r)
    if 'error' in d: raise RuntimeError(str(d['error'])[:100])
    return d['result']
def enc(sig,*args):
    sel=keccak.new(digest_bits=256,data=sig.encode()).hexdigest()[:8]
    data='0x'+sel
    for a in args:
        data += (a[2:].rjust(64,'0') if isinstance(a,str) and a.startswith('0x') else format(int(a),'064x'))
    return data
def call(to,sig,*args):
    return _rpc('eth_call',[{"to":to,"data":enc(sig,*args)},"latest"])
def u(r): return int(r,16) if isinstance(r,str) and r.startswith('0x') else None
