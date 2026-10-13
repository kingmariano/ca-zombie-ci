import json, urllib.request
from concurrent.futures import ThreadPoolExecutor
from Crypto.Hash import keccak

RPC="https://rpc.monad.xyz"
def _rpc(method, params):
    req=urllib.request.Request(RPC,data=json.dumps({"jsonrpc":"2.0","id":1,"method":method,"params":params}).encode(),headers={"Content-Type":"application/json"})
    with urllib.request.urlopen(req,timeout=40) as r: d=json.load(r)
    if 'error' in d: raise RuntimeError(str(d['error'])[:120])
    return d['result']

def enc(sig,*args):
    sel=keccak.new(digest_bits=256,data=sig.encode()).hexdigest()[:8]
    data='0x'+sel
    for a in args:
        data += a[2:].rjust(64,'0') if a.startswith('0x') else format(a,'064x')
    return data

def call(to,sig,*args):
    return _rpc('eth_call',[{"to":to,"data":enc(sig,*args)},"latest"])

def batch(calls, workers=12):
    """calls: list of (label,to,sig,args) -> dict label->raw result or 'ERR:...'"""
    out={}
    def one(c):
        label,to,sig,args=c
        try: return label,_rpc('eth_call',[{"to":to,"data":enc(sig,*args)},"latest"])
        except Exception as e: return label,f'ERR:{e}'
    with ThreadPoolExecutor(max_workers=workers) as ex:
        for label,res in ex.map(one,calls): out[label]=res
    return out

def u(res): 
    return int(res,16) if isinstance(res,str) and res.startswith('0x') else None
def words(h):
    h=h[2:]; return [int(h[i:i+64],16) for i in range(0,len(h),64)]
def addr_of(r,idx): return '0x'+r[2+64*idx+24:2+64*idx+64]
