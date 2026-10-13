#!/usr/bin/env python3
"""Decode EIP-1167 clone impls + token identities + legacy proxy slots."""
import json, urllib.request, os, hashlib

def rpc_raw(url, m, p):
    req = urllib.request.Request(url, data=json.dumps({"jsonrpc":"2.0","id":1,"method":m,"params":p}).encode(),
                                 headers={"Content-Type":"application/json"})
    return json.load(urllib.request.urlopen(req, timeout=45))

def pick_rpc():
    cands = []
    if os.environ.get("ANKR_API_KEY"): cands.append(f"https://rpc.ankr.com/bsc/{os.environ['ANKR_API_KEY']}")
    cands.append("https://bsc-rpc.publicnode.com")
    for u in cands:
        try:
            if rpc_raw(u,"eth_blockNumber",[]).get("result"): return u
        except Exception: pass
    raise SystemExit("no rpc")

RPC = pick_rpc()
def rpc(m,p): return rpc_raw(RPC,m,p).get("result")

EXTRA = [
 "0x97B9054122eF8888590934F0eC8E10580232E85d",
 "0xC80Cc653392f4734201331E39a66aA8a483D29BD",
 "0xCa9d9C7800b7d1D3A1988A7d93927424a1BBEA7f",
 "0xb1669A60a7Db67AA84e5fAF2AE3123AA99237459",
 "0xF100326c19996eaf2d8E93A503725F643e36099C",
 "0x0144E7d25644C7ca6038F4AFBfcD3b1A119Ab3cE",
 "0xbC7477e46A95758dE5012744f7A350A4E0d03484",
 "0x0eafAa7eD9866c1f08aC21dd0ef3395E910f7114",
]
FUNDED = ["0x2dcCe1586b1664f41C72206900e404Ec3cA130e0",
          "0xd0fBF0A224563D5fFc8A57e4fdA6Ae080EbCf3D3",
          "0x96b849a73db2cc769b4Abe770aAb141aAC9014d6"]
BASE = ["0x1B3771a66ee31180906972580adE9b81AFc5fCDc",
        "0x6C341938bB75dDe823FAAfe7f446925c66E6270c",
        "0x146CD24dCc9f4EB224DFd010c5Bf2b0D25aFA9C0"]

def code(a): return rpc("eth_getCode",[a,"latest"])

def decode_clone(c):
    # EIP-1167: 363d3d373d3d3d363d73<20b impl>5af43d82803e903d91602b57fd5bf3
    if c and c.startswith("0x363d3d373d3d3d363d73") and len(c) == 2+90:
        return "0x"+c[2+20:2+60]
    return None

def name_sym(a):
    out={}
    for sel,k in [("0x06fdde03","name"),("0x95d89b41","symbol"),("0x313ce567","decimals"),("0x18160ddd","totalSupply")]:
        r=rpc("eth_call",[{"to":a,"data":sel},"latest"])
        try:
            if r and r!="0x":
                if len(r)==66:  # uint
                    out[k]=int(r,16) if k in ("decimals","totalSupply") else r
                else:  # string
                    b=bytes.fromhex(r[2:]); 
                    off=int.from_bytes(b[:32],"big"); ln=int.from_bytes(b[off:off+32],"big")
                    out[k]=b[off+32:off+32+ln].decode("utf-8","replace")
        except Exception as e: out[k]=f"ERR {e}"
    return out

def main():
    print("== clone impls of metapools ==")
    impls={}
    for a in FUNDED+EXTRA:
        c=code(a); imp=decode_clone(c)
        impls[a]=imp
        print(f"{a} codelen={len(c)//2-1} impl={imp}")
    print("== token identities of extras ==")
    seen=set()
    for a in EXTRA:
        for i in range(2):
            t=rpc("eth_call",[{"to":a,"data":"0x82b86600"+hex(i)[2:].rjust(64,'0')},"latest"])
            if t and t!="0x":
                tok="0x"+t[2:][24:]
                if tok not in seen:
                    seen.add(tok)
                    print(f"  {a}[{i}] {tok} -> {name_sym(tok)}")
    print("== clone impl code hash (sha256 + keccak if possible) ==")
    imp=impls[FUNDED[0]]
    c=code(imp)
    print("impl",imp,"len",len(c)//2-1)
    print("sha256",hashlib.sha256(bytes.fromhex(c[2:])).hexdigest())
    # keccak
    try:
        from Crypto.Hash import keccak
        k=keccak.new(digest_bits=256); k.update(bytes.fromhex(c[2:])); print("keccak",k.hexdigest())
    except Exception:
        import subprocess
        r=subprocess.run(["cast","keccak","--data",c] if False else ["cast","keccak",c],capture_output=True,text=True)
        print("cast keccak raw:",r.stdout.strip()[:100], r.stderr[:80])
    print("== base pool structure ==")
    for a in BASE:
        c=code(a)
        print(f"{a} codelen={len(c)//2-1}")
        # legacy zeppelin slots
        for label,slot in [("zeppelinos.impl","0x7050c9e0f4ca769c69bd3a8ef740bc37934f8e2c036e5a723fd8ee048ed3f8c3"),
                           ("zeppelinos.admin","0x10d6a54a4754c8869d6886b5f5d7fbfa5b4522237ea5c60d11ec838a29877b24"),
                           ("eip1967.impl","0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc"),
                           ("eip1967.admin","0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103")]:
            r=rpc("eth_getStorageAt",[a,slot,"latest"])
            if r and r!="0x"+"0"*64: print(f"   {label} = {r}")
        # legacy admin()
        r=rpc("eth_call",[{"to":a,"data":"0xf851a440"},"latest"])
        print("   admin() raw:",r)
        r=rpc("eth_call",[{"to":a,"data":"0x3e47158c"},"latest"])
        print("   proxyAdmin() raw:",r)

if __name__=="__main__": main()
