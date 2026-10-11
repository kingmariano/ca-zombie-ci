#!/usr/bin/env python3
"""Test Acala orml storage reads with pure-python xxhash64 + ss58 decode."""
import json, hashlib, urllib.request

# ---- pure python xxhash64 ----
M = (1<<64)-1
P1=0x9E3779B185EBCA87; P2=0xC2B2AE3D27D4EB4F; P3=0x165667B19E3779F9; P4=0x85EBCA77C2B2AE63; P5=0x27D4EB2F165667C5
def rotl(x,r): return ((x<<r)|(x>>(64-r)))&M
def xxh64(data, seed=0):
    n=len(data); i=0
    if n>=32:
        v1=(seed+P1+P2)&M; v2=(seed+P2)&M; v3=seed&M; v4=(seed-P1)&M
        while i+32<=n:
            for vi in range(4):
                k=int.from_bytes(data[i:i+8],'little'); i+=8
                if vi==0: v1=(rotl((v1+k*P2)&M,31)*P1)&M
                elif vi==1: v2=(rotl((v2+k*P2)&M,31)*P1)&M
                elif vi==2: v3=(rotl((v3+k*P2)&M,31)*P1)&M
                else: v4=(rotl((v4+k*P2)&M,31)*P1)&M
        h=(rotl(v1,1)+rotl(v2,7)+rotl(v3,12)+rotl(v4,18))&M
        for v in (v1,v2,v3,v4):
            h=((h ^ (rotl((v*P2)&M,31)*P1)&M)*P1+P4)&M
    else:
        h=(seed+P5)&M
    h=(h+n)&M
    while i+8<=n:
        k=int.from_bytes(data[i:i+8],'little'); i+=8
        h=(rotl((h ^ (rotl((k*P2)&M,31)*P1)&M),27)*P1+P4)&M
    if i+4<=n:
        k=int.from_bytes(data[i:i+4],'little'); i+=4
        h=(rotl((h ^ (k*P1)&M),23)*P2+P3)&M
    while i<n:
        h=(rotl((h ^ (data[i]*P5)&M),11)*P1)&M; i+=1
    h ^= h>>33; h=(h*P2)&M; h ^= h>>29; h=(h*P3)&M; h ^= h>>32
    return h

assert xxh64(b"",0)==0xEF46DB3751D8E999, hex(xxh64(b"",0))
assert xxh64(b"xxhash",0)==0x32DD38952C4BC720, hex(xxh64(b"xxhash",0))
print("xxhash64 self-test OK")

def twox64(b): return xxh64(b,0).to_bytes(8,'little')
def twox128(b): return twox64(b)+twox64(b)  # xxhash with seed 0 and 1
def twox128_(b): return xxh64(b,0).to_bytes(8,'little')+xxh64(b,1).to_bytes(8,'little')

B58="123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"
def b58decode(s):
    num=0
    for c in s: num=num*58+B58.index(c)
    full=num.to_bytes((num.bit_length()+7)//8,'big')
    pad=len(s)-len(s.lstrip('1'))
    return b'\x00'*pad+full

def ss58_decode(addr):
    raw=b58decode(addr)
    # 1-byte prefix (Acala=10, Karura=8), 2-byte checksum
    return raw[1:-2]

def blake2_128_concat(b): return hashlib.blake2b(b,digest_size=16).digest()+b

def rpc(url, method, params):
    req=urllib.request.Request(url, data=json.dumps({"jsonrpc":"2.0","id":1,"method":method,"params":params}).encode(), headers={"Content-Type":"application/json"})
    with urllib.request.urlopen(req, timeout=30) as r: return json.loads(r.read().decode())

ACALA="https://acala-rpc-0.aca-api.network"
acct="23M5ttkp2zdM8qa6LFak4BySWZDsAVByjepAfr7kt929S1U9"
pub=ss58_decode(acct)
print("pubkey", pub.hex(), len(pub))

# orml Tokens.Accounts
def tokens_key(pub, cid): return twox128_(b"Tokens")+twox128_(b"Accounts")+blake2_128_concat(pub)+twox64(cid)
for name, cid in [("DOT", bytes([0,2])), ("LDOT", bytes([0,3])), ("TAP", bytes([0,4]))]:
    k=tokens_key(pub,cid)
    r=rpc(ACALA,"state_getStorage",["0x"+k.hex()])
    val=r.get("result")
    if val and val!="0x":
        b=bytes.fromhex(val[2:])
        free=int.from_bytes(b[0:16],'little')
        print(f"{name}: free={free/1e10} (raw {free}) len={len(b)}")
    else:
        print(f"{name}: empty")

# native ACA: System.Account
k=twox128_(b"System")+twox128_(b"Account")+blake2_128_concat(pub)
r=rpc(ACALA,"state_getStorage",["0x"+k.hex()])
val=r.get("result")
if val and val!="0x":
    b=bytes.fromhex(val[2:])
    free=int.from_bytes(b[16:32],'little')
    print(f"ACA: free={free/1e12} (len {len(b)})")
else:
    print("ACA: empty")
print("block:", rpc(ACALA,"chain_getHeader",[]).get("result",{}).get("number"))
