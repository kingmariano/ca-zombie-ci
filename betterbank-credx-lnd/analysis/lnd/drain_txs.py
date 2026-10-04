#!/usr/bin/env python3
"""Decode all 7 drain txs: args + Transfer logs. Save raw JSON."""
import json, sys
sys.path.insert(0,'.')
from lib import rpc, SONIC

TXS = {
 "0xd52f317b548bd0f67d32d35404d046e4e60f5af23dac8a502495a8714780bffe":"USDC-batch1",
 "0x0e192c6a1d4cad8feac85b2c5bdc5242a4ae336a5dd24ab2378d88f758e62dfa":"WETH-batch1",
 "0xf1b399290f027b46b517036cc65700fa61e123ff23af27dc7d009e3a72bb5034":"wS-batch1",
 "0xf9c1afaf46425c922deac9ce677a4352adf305952cde79bda73c3cb1c7c73fb0":"stS-batch1",
 "0xbf7e41329a2752a3d74a53762d94c6ab4f51da7a990b0363288af4afc17b098a":"scETH-batch1",
 "0x7db4384b3cee04f5fbd6504acc5465877df173bdac7a1a875771bd9ef76362cd":"wS-batch2",
 "0x713a3ad33f5b70260f6be8ea45d382dc36a8809eebd33ecaea51787d13ce53cf":"wS-batch3",
}
TRANSFER = "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef"
out = {}
for h,label in TXS.items():
    e = {}
    try:
        tx = rpc(SONIC,"eth_getTransactionByHash",[h])
        e["tx"] = tx
    except Exception as ex: e["tx"]="ERR "+str(ex)
    try:
        rc = rpc(SONIC,"eth_getTransactionReceipt",[h])
        e["receipt_status"]=rc.get("status"); e["blockNumber"]=int(rc.get("blockNumber","0x0"),16)
        logs=[]
        for l in rc.get("logs",[]):
            d={"address":l["address"],"topics":l["topics"],"data":l["data"]}
            if l["topics"] and l["topics"][0].lower()==TRANSFER and len(l["topics"])>=3:
                d["decoded"]={"from":"0x"+l["topics"][1][-40:],"to":"0x"+l["topics"][2][-40:],"value":int(l["data"],16)}
            logs.append(d)
        e["logs"]=logs
    except Exception as ex: e["receipt"]="ERR "+str(ex)
    if "tx" in e and isinstance(e["tx"],dict):
        inp=e["tx"]["input"]
        e["selector"]=inp[:10]; e["arg_target"]="0x"+inp[10:74][-40:]; e["arg_amount"]=int(inp[74:138],16)
    out[label]=e
with open("raw/sonic_drain_txs.json","w") as f: json.dump(out,f,indent=2)
for label,e in out.items():
    tg=e.get("arg_target"); am=e.get("arg_amount")
    print(f"{label}: block={e.get('blockNumber')} target={tg} amount={am}")
    for l in e.get("logs",[]):
        if "decoded" in l:
            print("   Transfer", l["address"], l["decoded"])
