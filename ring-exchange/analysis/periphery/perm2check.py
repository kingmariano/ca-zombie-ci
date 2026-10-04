#!/usr/bin/env python3
# Permit2 allowance live-state for UR/ROUTER/FEWE/FACTORY + Core paused + fw token allowances.
import subprocess, json

RPC="https://rpc.hyperliquid.xyz/evm"
UR="0xE65081EFa5ad4A196B1Df768716c337e6AB140E9"
ROUTER="0x701D1d675415efA2d2429fB122ccC6dD4FCcA959"
FEWE="0x068B60ECbC934b0a0dde20FdFf0dE925b97B971F"
FACTORY="0x6B65ed7315274eB9EF06A48132EB04D808700b86"
PERMIT2="0x000000000022D473030F116dDEE9F6B43aC78BA3"
CORE="0x1cda28aD2915356EB618518b1bDD3f462aeF3803"
WHYPE="0x5555555555555555555555555555555555555555"
UETH="0xBe6727B535545C67d5cAa73dEa54865B92CF7907"
USDC="0xb88339CB7199b77E23DB6E890353E22632Ba630f"
USDT0="0xB8CE59FC3717ada4C02eaDF9682A9e934F625ebb"
USDH="0x111111a1a0667d36bD57c0A9f569b98057111111"
FWWETH="0x9e1148bC3665a9f7C35F313d89c0432c34928AEf"
FWUETH="0x0C47cbbEDE5d8c6f9614cF770C26c3315205C397"
FWUSDC="0xd2646b9B02859416D8cBc759F85f0676f6E19974"
FWUSDT0="0x7576dd9a2775bFd789616d9eA7A2af21d06782D0"
FWUSDH="0x09D21E89EF332347eb3E1E496f1265a600e364C1"

callers=["0x61e75d5c5dee4205a5bbcd9fbc40498b693197ad","0x7e03b41a3bd79de20e2b38075af02f2dcf174754",
"0x3a4825a0c8c2a16682e02b9b951780755e4461dc","0xf8248fd490ff7507e771fe97e5bf1903f7492543","0x8b97e2c7ef1735474fe281afd2aea2b48eb26cb3"]
tokens={"WHYPE":WHYPE,"UETH":UETH,"USDC":USDC,"USDT0":USDT0,"USDH":USDH,"fwWHYPE":FWWETH,"fwUETH":FWUETH,"fwUSDC":FWUSDC,"fwUSDT0":FWUSDT0,"fwUSDH":FWUSDH}
spenders={"UR":UR,"ROUTER":ROUTER,"FEWE":FEWE}

def out(cmd):
    p=subprocess.run(cmd,capture_output=True,text=True)
    return (p.stdout.strip() or p.stderr.strip()).replace("\n"," ")

res={}
for c in callers:
    for tn,ta in tokens.items():
        for sn,sa in spenders.items():
            o=out(["cast","call",PERMIT2,"allowance(address,address,address)(uint160,uint48,uint48)",c,ta,sa,"--rpc-url",RPC])
            if not o.startswith("Error"):
                parts=[x.strip() for x in o.replace(")","").split("(")[-1].split(",")]
                try:
                    amt=int(parts[0]); exp=int(parts[1])
                except Exception:
                    continue
                if amt>0:
                    res.setdefault(f"{c}|{sn}",{})[tn]={"amount":str(amt),"expiration":exp}
                    print(f"LIVE Permit2 allowance: owner={c} spender={sn} token={tn} amount={amt} exp={exp}")

print("---ERC20 direct allowances (token, owner, spender=router/UR) current values---")
checks=[(WHYPE,"0x8b97e2c7ef1735474fe281afd2aea2b48eb26cb3",UR),(UETH,"0x8b97e2c7ef1735474fe281afd2aea2b48eb26cb3",UR),
(WHYPE,"0xf951d8285473a020f1a136fd312fdb46de92f3d1",ROUTER),(UETH,"0xf951d8285473a020f1a136fd312fdb46de92f3d1",ROUTER),
(USDC,"0x274602a953847d807231d2370072f5f4e4594b44",ROUTER),(FWWETH,"0x9336d0c82299da0ab178271792954adfd6f10fd7",FEWE),
(FWWETH,"0x4f0aa5900b8292273b2f9a178d5468f8048bb9a9",FEWE),(FWWETH,"0xf8248fd490ff7507e771fe97e5bf1903f7492543",ROUTER)]
for ta,o,sp in checks:
    v=out(["cast","call",ta,"allowance(address,address)(uint256)",o,sp,"--rpc-url",RPC])
    print(f"{ta} owner={o} spender={sp}: {v}")

print("--- Core paused:", out(["cast","call",CORE,"paused()(bool)","--rpc-url",RPC]))
json.dump(res,open("permit2_live_allowances.json","w"),indent=1)
