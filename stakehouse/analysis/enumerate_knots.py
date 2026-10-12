#!/usr/bin/env python3
"""Enumerate all 85 Stakehouse knots with REAL BLS pubkeys from InitialsRegistered events."""
import rpc, subprocess, json

def sel(s): return subprocess.run(["cast","sig",s],capture_output=True,text=True).stdout.strip()
def enc_uint(i): return hex(i)[2:].rjust(64,'0')
def enc_addr(a): return a[2:].lower().rjust(64,'0')
def enc_bytes(b):
    h=b[2:] if b.startswith('0x') else b
    ln=len(h)//2
    return enc_uint(ln)+h.ljust(((ln+31)//32)*32*2,'0')

AM="0xDd6E67942a9566A70446f7400a21240C5f71377C"
SLOTREG="0xC01DC3c7F83B12CFdF6C0AAa09c880EB45c48569"
SR="0x64f4fCFb8377DEaABF334eD42aC113E6813a55d0"
FW="0x8F6839b0AcD8d7c7d2f01C1C7ECCa982Ca354333"

accounts=[a for a in json.load(open("accounts_raw.json")) if 'bls' in a]
initials=json.load(open("initials_keys.json"))
assert len(accounts)==len(initials)==85

def q(calls):
    out={}
    for start in range(0,len(calls),10):
        chunk=calls[start:start+10]
        res=rpc.batch([("eth_call",[{"to":c[1],"data":c[2]},"latest"]) for c in chunk])
        for c,r in zip(chunk,res):
            out[c[0]]=r
    return out

calls=[]
for a,ini in zip(accounts,initials):
    i=a["i"]; key=ini["key"]; addr=a["addr"]
    calls.append((f"lifecycle:{i}", AM, sel("blsPublicKeyToLifecycleStatus(bytes)")+enc_uint(0x20)+enc_bytes(key)))
    calls.append((f"claimed:{i}", AM, sel("claimedTokens(bytes)")+enc_uint(0x20)+enc_bytes(key)))
    calls.append((f"laststate:{i}", AM, sel("getLastKnownStateByPublicKey(bytes)")+enc_uint(0x20)+enc_bytes(key)))
    calls.append((f"userWithdrawn:{i}", SLOTREG, sel("userWithdrawn(address,bytes)")+enc_addr(addr)+enc_uint(0x40)+enc_bytes(key)))
    calls.append((f"enabled:{i}", SLOTREG, sel("isUserEnabledForKnotWithdrawal(address,bytes)")+enc_addr(addr)+enc_uint(0x40)+enc_bytes(key)))
    calls.append((f"reportedNotWithdrawn:{i}", SR, sel("totalReportedETHNotWithdrawn(bytes)")+enc_uint(0x20)+enc_bytes(key)))
    calls.append((f"totalSent:{i}", SR, sel("totalETHSentToBlsPublicKey(bytes)")+enc_uint(0x20)+enc_bytes(key)))

res=q(calls)
out={}
for k,v in res.items():
    name,idx=k.split(":"); idx=int(idx)
    out.setdefault(idx,{})[name]=v
json.dump(out, open("accounts_state.json","w"), indent=1)

# laststate decode: struct ETH2DataReport {bytes blsPublicKey, bytes withdrawalCredentials, bool slashed, uint64 activeBalance, effectiveBalance, exitEpoch, activationEpoch, withdrawalEpoch, currentCheckpointEpoch}
def dec_laststate(hexstr):
    if not hexstr or hexstr=="0x": return None
    raw=hexstr[2:]
    tup=int(raw[0:64],16)*2
    # head: [offset_bls, offset_wc, slashed, activeBalance, effBalance, exitEpoch, actEpoch, wdEpoch, chkEpoch]
    try:
        wc_off=int(raw[tup+64:tup+128],16)*2
        slashed=int(raw[tup+128:tup+192],16)
        ab=int(raw[tup+192:tup+256],16)
        eb=int(raw[tup+256:tup+320],16)
        exit_ep=int(raw[tup+320:tup+384],16)
        act_ep=int(raw[tup+384:tup+448],16)
        wd_ep=int(raw[tup+448:tup+512],16)
        chk_ep=int(raw[tup+512:tup+576],16)
        return {"slashed":slashed,"activeBalance":ab,"effectiveBalance":eb,"exitEpoch":exit_ep,"activationEpoch":act_ep,"withdrawalEpoch":wd_ep,"checkpointEpoch":chk_ep}
    except Exception as e:
        return {"err":str(e)}

print(f"{'i':>3} {'life':>4} {'clm':>4} {'en':>3} {'wd':>3} {'repNotWd(ETH)':>14} {'sent(ETH)':>11} {'slashed':>7} {'actBal':>10} {'exitEp':>7} {'withdrEp':>8}  smartWallet")
summary=[]
for a,ini in zip(accounts,initials):
    i=a["i"]; st=out.get(i,{})
    def g(k):
        v=st.get(k)
        if v is None or v=="0x": return None
        return int(v,16)
    lc=g("lifecycle"); cl=g("claimed"); en=g("enabled"); wd=g("userWithdrawn")
    rn=g("reportedNotWithdrawn"); ts=g("totalSent")
    ls=dec_laststate(st.get("laststate")) or {}
    row={"i":i,"key":ini["key"],"wallet":a["addr"],"lifecycle":lc,"claimed":cl,"enabled":en,"withdrawn":wd,
         "reportedNotWithdrawn":rn,"totalSent":ts,"laststate":ls,"depositBlock":a.get("depositBlock")}
    summary.append(row)
    print(f"{i:>3} {str(lc):>4} {str(cl):>4} {str(en):>3} {str(wd):>3} {(rn/1e18 if rn is not None else -1):>14.6f} {(ts/1e18 if ts is not None else -1):>11.6f} {str(ls.get('slashed')):>7} {str(ls.get('activeBalance')):>10} {str(ls.get('exitEpoch')):>7} {str(ls.get('withdrawalEpoch')):>8}  {a['addr']}")
json.dump(summary, open("knots_summary.json","w"), indent=1)
print("\nKNOTS with reportedNotWithdrawn>0 or enabled/withdrawn or lifecycle>=4:")
for r in summary:
    if (r["reportedNotWithdrawn"] or 0)>0 or r["enabled"] or r["withdrawn"] or (r["lifecycle"] or 0)>=4:
        print(json.dumps(r))
