#!/usr/bin/env python3
"""Enumerate all Stakehouse accounts/knots (85) and their claimable state. Read-only."""
import rpc, subprocess, json, sys

def sel(s): return subprocess.run(["cast","sig",s],capture_output=True,text=True).stdout.strip()

AM="0xDd6E67942a9566A70446f7400a21240C5f71377C"
SLOTREG="0xC01DC3c7F83B12CFdF6C0AAa09c880EB45c48569"
SR="0x64f4fCFb8377DEaABF334eD42aC113E6813a55d0"
FW="0x8F6839b0AcD8d7c7d2f01C1C7ECCa982Ca354333"

def enc_uint(i): return hex(i)[2:].rjust(64,'0')
def enc_addr(a): return a[2:].lower().rjust(64,'0')
def enc_bytes(b):
    # bytes as hex string without 0x, length multiple of 32
    h=b[2:] if b.startswith('0x') else b
    ln=len(h)//2
    return enc_uint(ln)+h.ljust(((ln+31)//32)*32*2,'0')

def dec_address(slot): return "0x"+slot[-40:]

n = int(rpc.call(AM, sel("numberOfAccounts()")),16)
print("numberOfAccounts:", n, file=sys.stderr)

accounts=[]
# batch getAccount(i) in chunks
for start in range(0, n, 10):
    calls=[("eth_call",[{"to":AM,"data":sel("getAccount(uint256)")+enc_uint(i)},"latest"]) for i in range(start,min(start+10,n))]
    res=rpc.batch(calls)
    for i,out in zip(range(start,min(start+10,n)),res):
        if not out or out=="0x":
            accounts.append({"i":i,"error":"empty"}); continue
        raw=out[2:]
        # return (tuple): word0 = offset to tuple (0x20); tuple head: [address, bytes-offset, depositBlock]
        tup=int(raw[0:64],16)*2
        a="0x"+raw[tup+24:tup+64]
        boff=int(raw[tup+64:tup+128],16)*2   # relative to tuple start
        depblock=int(raw[tup+128:tup+192],16)
        blen=int(raw[tup+boff:tup+boff+64],16)
        bkey="0x"+raw[tup+boff+64:tup+boff+64+blen*2]
        accounts.append({"i":i,"addr":a,"bls":bkey,"depositBlock":depblock})
json.dump(accounts, open("accounts_raw.json","w"), indent=1)
print("accounts decoded:", len([a for a in accounts if 'bls' in a]), file=sys.stderr)

# now batch per-account queries
def q(name, calls):
    out={}
    for start in range(0,len(calls),10):
        chunk=calls[start:start+10]
        res=rpc.batch([("eth_call",[{"to":c[1],"data":c[2]},"latest"]) for c in chunk])
        for c,r in zip(chunk,res):
            out[c[0]]=r
    return out

calls=[]
for a in accounts:
    if 'bls' not in a: continue
    i=a["i"]; key=a["bls"]; addr=a["addr"]
    calls.append((f"lifecycle:{i}", AM, sel("blsPublicKeyToLifecycleStatus(bytes)")+enc_uint(0x20)+enc_bytes(key)))
    calls.append((f"claimed:{i}", AM, sel("claimedTokens(bytes)")+enc_uint(0x20)+enc_bytes(key)))
    calls.append((f"userWithdrawn:{i}", SLOTREG, sel("userWithdrawn(address,bytes)")+enc_addr(addr)+enc_uint(0x40)+enc_bytes(key)))
    calls.append((f"enabled:{i}", SLOTREG, sel("isUserEnabledForKnotWithdrawal(address,bytes)")+enc_addr(addr)+enc_uint(0x40)+enc_bytes(key)))
    calls.append((f"totReportedNotWithdrawn:{i}", SR, sel("totalReportedETHNotWithdrawn(bytes)")+enc_uint(0x20)+enc_bytes(key)))
    calls.append((f"totSent:{i}", SR, sel("totalETHSentToBlsPublicKey(bytes)")+enc_uint(0x20)+enc_bytes(key)))

res=q("all", calls)
out={}
for k,v in res.items():
    name,idx=k.split(":"); idx=int(idx)
    out.setdefault(idx,{})[name]=v
json.dump(out, open("accounts_state.json","w"), indent=1)
print("state queries done:", len(out), file=sys.stderr)
# summary print
print(f"{'i':>3} {'lifecycle':>9} {'claimed':>7} {'enabled':>7} {'withdrawn':>9} {'reportedNotWithdrawn(ETH)':>26} {'totalSent(ETH)':>14} addr")
for a in accounts:
    if 'bls' not in a: continue
    i=a["i"]; st=out.get(i,{})
    def g(k):
        v=st.get(k)
        if v is None or v=="0x": return None
        return int(v,16)
    lc=g("lifecycle"); cl=g("claimed"); en=g("enabled"); wd=g("userWithdrawn")
    rn=g("totReportedNotWithdrawn"); ts=g("totSent")
    print(f"{i:>3} {str(lc):>9} {str(cl):>7} {str(en):>7} {str(wd):>9} {(rn/1e18 if rn is not None else -1):>26.6f} {(ts/1e18 if ts is not None else -1):>14.6f} {a['addr']}")
