#!/usr/bin/env python3
"""eth_call probes: can an unprivileged attacker invoke claim paths? Read-only simulation via eth_call.from."""
import json, sys, os, urllib.request
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import hl_rpc as h

RPC = "https://rpc.hyperliquid.xyz/evm"
_id = [10000]

def call_from(to, data, frm, block="latest"):
    _id[0] += 1
    body = json.dumps({"jsonrpc": "2.0", "id": _id[0], "method": "eth_call",
                       "params": [{"to": to, "data": data, "from": frm}, block]}).encode()
    req = urllib.request.Request(RPC, data=body, headers={"Content-Type": "application/json", "User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(req, timeout=30) as r:
        out = json.loads(r.read())
    if "result" in out:
        return ("OK", out["result"])
    err = out.get("error", {})
    return ("ERR", json.dumps(err)[:400])

def enc(sig, args=()):
    sel = h.enc_sel(sig)
    data = sel
    for a in args:
        if isinstance(a, int):
            data += f"{a:064x}"
        elif isinstance(a, str) and a.startswith("0x"):
            data += a[2:].rjust(64, "0")
        elif isinstance(a, (list, tuple)):
            data += a[2:] if isinstance(a, str) else ""
            raise ValueError("use manual encoding")
        else:
            raise ValueError(a)
    return data

def enc_addr_array(addrs):
    # dynamic array encoding: offset + len + items
    off = 32
    out = f"{off:064x}" + f"{len(addrs):064x}"
    for a in addrs:
        out += a[2:].rjust(64, "0")
    return out

def enc_uint_array(vals):
    out = f"{32:064x}" + f"{len(vals):064x}"
    for v in vals:
        out += f"{v:064x}"
    return out

GM = "0x742caa5ba7c92ca6cfebfd0e73c21739b3b65d5e"
GAUGE = "0x382e5db8ec64e8506879b94568b41d159d64577f"
IB = "0x204008205ddbb27e8bb568729b50cf031915a75b"
VE = "0xd7ed7792f71f3920dba01c544639fd546d87f4fd"
VOTER = "0x5623f012d15eb828c12fe32e46d40adc2a9e4fa3"
STAKER = "0x4c390964936e9501fbc594d32e94907449a35a5a"
TOKENID = int("0x34c8", 16)
ATTACKER = "0x00000000000000000000000000000000deadbeef"

res = {}
def probe(name, to, data, frm):
    st, out = call_from(to, data, frm)
    res[name + "|" + ("staker" if frm == STAKER else "attacker")] = {"status": st, "out": out[:200]}
    print(f"{name} from {'STAKER' if frm==STAKER else 'ATTACKER'}: {st} {out[:180]}")

# 0. verify stake
probe("GaugeCL.earned", GAUGE, enc("earned(uint256)", (TOKENID,)), STAKER)
probe("GaugeCL.earned", GAUGE, enc("earned(uint256)", (TOKENID,)), ATTACKER)
# 1. GM.claimRewards(gauge,[tokenId],0)
data = h.enc_sel("claimRewards(address,uint256[],uint8)") + GAUGE[2:].rjust(64, "0") + f"{96:064x}" + f"{1:064x}" + f"{0:064x}" + f"{TOKENID:064x}" if False else None
# build properly: (address, uint256[], uint8)
# head: addr, offset=0x60, redeemType ; tail at 0x60: len + items
d = h.enc_sel("claimRewards(address,uint256[],uint8)")
d += GAUGE[2:].rjust(64, "0")
d += f"{0x60:064x}"
d += f"{0:064x}"
d += f"{1:064x}" + f"{TOKENID:064x}"
probe("GM.claimRewards", GM, d, STAKER)
probe("GM.claimRewards", GM, d, ATTACKER)
# 2. GM.claimBribes(bribes=[IB], tokens=[[HYBR]], tokenId)
HYBR = "0x067b0c72aa4c6bd3bfefff443c536dcd6a25a9c8"
# dynamic: address[] bribes; address[][] tokens; uint256 tokenId
# layout: [0]=off_bribes(0x60), [1]=off_tokens(0xa0), [2]=tokenId
# 0x60: len 1, IB ; 0xa0: len1, off0(0x20), len1, HYBR
d = h.enc_sel("claimBribes(address[],address[][],uint256)")
d += f"{0x60:064x}"
d += f"{0xa0:064x}"
d += f"{TOKENID:064x}"
d += f"{1:064x}" + IB[2:].rjust(64, "0")
d += f"{1:064x}" + f"{0x20:064x}"
d += f"{1:064x}" + HYBR[2:].rjust(64, "0")
probe("GM.claimBribes", GM, d, STAKER)
probe("GM.claimBribes", GM, d, ATTACKER)
# 3. GaugeCL.getReward(tokenId, attacker, 0) direct
d = h.enc_sel("getReward(uint256,address,uint8)") + f"{TOKENID:064x}" + ATTACKER[2:].rjust(64, "0") + f"{0:064x}"
probe("GaugeCL.getReward", GAUGE, d, ATTACKER)
# 4. Voter.reset(tokenId)
probe("Voter.reset", VOTER, h.enc_sel("reset(uint256)") + f"{TOKENID:064x}", ATTACKER)
# 5. GaugeCL.withdraw(tokenId,0)
probe("GaugeCL.withdraw", GAUGE, h.enc_sel("withdraw(uint256,uint8)") + f"{TOKENID:064x}" + f"{0:064x}", ATTACKER)
# 6. GaugeManager.distributeFees()
probe("GM.distributeFees", GM, h.enc_sel("distributeFees()"), ATTACKER)
# 7. Minter.update_period()
M = "0xa8265e40e4cdf6db345861f4fcb75f9cc63e149b"
probe("Minter.update_period", M, h.enc_sel("update_period()"), ATTACKER)
# 8. Minter.check()
probe("Minter.check", M, h.enc_sel("check()"), ATTACKER)
# 9. ve.checkpoint()
probe("VE.checkpoint", VE, h.enc_sel("checkpoint()"), ATTACKER)

json.dump(res, open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "probes.json"), "w"), indent=1)
print("saved probes.json")
