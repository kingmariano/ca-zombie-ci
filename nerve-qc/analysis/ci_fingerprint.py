#!/usr/bin/env python3
"""CI-side fresh fingerprint of all Nerve pools (read-only, no secrets printed).
Uses BSC_RPC_URL if set, else publicnode."""
import json, urllib.request, os, hashlib, subprocess

RPC = os.environ.get("BSC_RPC_URL") or "https://bsc-rpc.publicnode.com"

def rpc(m, p):
    payload = json.dumps({"jsonrpc":"2.0","id":1,"method":m,"params":p})
    try:
        req = urllib.request.Request(RPC, data=payload.encode(),
                                     headers={"Content-Type":"application/json", "User-Agent":"research/1.0"})
        r = json.load(urllib.request.urlopen(req, timeout=45))
    except Exception:
        # fallback transport (some hosts block python-urllib from CI IPs)
        out = subprocess.run(["curl","-s","-m","45","-A","foundry","-H","Content-Type: application/json",
                              "--data", payload, RPC], capture_output=True, text=True)
        r = json.loads(out.stdout)
    if "error" in r: raise RuntimeError(str(r["error"])[:100])
    return r.get("result")

def u256(x): return hex(int(x))[2:].rjust(64,"0")
def pad(a): return a.lower().replace("0x","").rjust(64,"0")
def readaddr(w):
    if not isinstance(w,str) or len(w)<66: return None
    a="0x"+w[2:][24:64]
    return None if int(a,16)==0 else a
def ci(to,data):
    r=rpc("eth_call",[{"to":to,"data":data},"latest"])
    return int(r,16) if r and r!="0x" else None

POOLS = {
 "POOL3":"0x1B3771a66ee31180906972580adE9b81AFc5fCDc",
 "BTCPOOL":"0x6C341938bB75dDe823FAAfe7f446925c66E6270c",
 "ETHPOOL":"0x146CD24dCc9f4EB224DFd010c5Bf2b0D25aFA9C0",
 "USTMETA":"0x2dcCe1586b1664f41C72206900e404Ec3cA130e0",
 "FUSDTMETA":"0xd0fBF0A224563D5fFc8A57e4fdA6Ae080EbCf3D3",
 "NRVMETA":"0x96b849a73db2cc769b4Abe770aAb141aAC9014d6",
 "EXTRA0":"0x97B9054122eF8888590934F0eC8E10580232E85d",
 "EXTRA1":"0xC80Cc653392f4734201331E39a66aA8a483D29BD",
 "EXTRA2":"0xCa9d9C7800b7d1D3A1988A7d93927424a1BBEA7f",
 "EXTRA3":"0xb1669A60a7Db67AA84e5fAF2AE3123AA99237459",
 "EXTRA4":"0xF100326c19996eaf2d8E93A503725F643e36099C",
 "EXTRA5":"0x0144E7d25644C7ca6038F4AFBfcD3b1A119Ab3cE",
 "EXTRA6":"0xbC7477e46A95758dE5012744f7A350A4E0d03484",
 "EXTRA7":"0x0eafAa7eD9866c1f08aC21dd0ef3395E910f7114",
 "NEW1":"0x877A8437e76443cFCaCD05D21C3793070637d82f",
 "NEW2":"0xCB922e4A5370020ACf2D0E29754e0a995Dec5B27",
 "NEW3":"0xf873Ec132F38eFb86bd071234b4316878b48Fa97",
}

def main():
    blk = int(rpc("eth_blockNumber", []), 16)
    print(f"# RPC={RPC.split('?')[0]} block={blk}")
    total_lp_side = 0
    for name, a in POOLS.items():
        code = rpc("eth_getCode", [a, "latest"])
        clen = len(code)//2-1 if isinstance(code,str) and code.startswith("0x") else 0
        impl = None
        if clen == 45 and code.startswith("0x363d3d373d3d3d363d73"):
            impl = "0x"+code[2+20:2+60]
        paused = ci(a,"0x5c975abb")
        owner = readaddr(rpc("eth_call",[{"to":a,"data":"0x8da5cb5b"},"latest"]))
        i0 = ci(a,"0x91ceb3eb"+u256(0)) or 0
        i1 = ci(a,"0x91ceb3eb"+u256(1)) or 0
        a0 = ci(a,"0xef0a712f"+u256(0)) or 0
        a1 = ci(a,"0xef0a712f"+u256(1)) or 0
        extra = ""
        if impl and not paused and i0 > 0:
            out = ci(a,"0xa95b089f"+u256(0)+u256(1)+u256(i0)) or 0
            total_lp_side += out
            extra = f" maxLP3out={out}"
        print(f"{name:10s} {a} codelen={clen} impl={impl or 'self'} paused={paused} owner={owner} i0={i0} i1={i1} a0={a0} a1={a1}{extra}")
    print(f"TOTAL LP3-side bound (wei): {total_lp_side}")

if __name__ == "__main__":
    main()
