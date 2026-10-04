#!/usr/bin/env python3
# Origin of UR allowances + decode of UR execute() command history (read-only).
import subprocess, json, time, urllib.request

HYP="https://rpc.hyperliquid.xyz/evm"
UR="0xE65081EFa5ad4A196B1Df768716c337e6AB140E9"
WHYPE="0x5555555555555555555555555555555555555555"
UETH="0xBe6727B535545C67d5cAa73dEa54865B92CF7907"
FWWETH="0x9e1148bC3665a9f7C35F313d89c0432c34928AEf"
FWUETH="0x0C47cbbEDE5d8c6f9614cF770C26c3315205C397"
APPR="0x8c5be1e5ebec7d5bd14f71427d1e84f3dd0314c0f7b2291e5b200ac8c7c3b925"

def rpc(method, params):
    req=urllib.request.Request(HYP, data=json.dumps({"jsonrpc":"2.0","id":1,"method":method,"params":params}).encode(),
                               headers={"Content-Type":"application/json"})
    return json.loads(urllib.request.urlopen(req, timeout=60).read())["result"]

def pad(a): return "0x"+a[2:].rjust(64,"0")

# hashes from prior txlist (newest first), excluding creation
txs = [
 ("0x53eb683dd1063a8115a040dd2f1f9b4b99ef649a9f6032689c0d7672d6666d80",39645850,"0xf8248fd490ff7507e771fe97e5bf1903f7492543"),
 ("0x89314184500ef94dab172b7e84ceb66b761801d25d33e6bfb73d7af0d476edb6",26124560,"0x61e75d5c5dee4205a5bbcd9fbc40498b693197ad"),
 ("0x57de927f9a07a1f4052744c023f98c646be6e6c1bd0333c2ea905ba3c9255a9f",26114375,"0x61e75d5c5dee4205a5bbcd9fbc40498b693197ad"),
 ("0xa9bf2949b3e2cbc714c616415a81569e8429d1be3cd0b10fcfee89ed7fa1773b",26114355,"0x61e75d5c5dee4205a5bbcd9fbc40498b693197ad"),
 ("0xcb8805d6c75511ca0f5195ae125653874d0e525259ae64de5ff8609f8795845b",25480082,"0x7e03b41a3bd79de20e2b38075af02f2dcf174754"),
 ("0x1a51da5a6ca876d8f5de2cedaa70dd4a52eb3323996c2ca5f35d40f26e00b651",25480021,"0x7e03b41a3bd79de20e2b38075af02f2dcf174754"),
 ("0x6ddf853b062f8e8b99a897aad6c70c42b49c09b3a1cd75d352ea8a1854749cf1",20229099,"0x3a4825a0c8c2a16682e02b9b951780755e4461dc"),
]
CMDS={0x00:"V3_SWAP_EXACT_IN",0x01:"V3_SWAP_EXACT_OUT",0x02:"PERMIT2_TRANSFER_FROM",0x03:"PERMIT2_PERMIT_BATCH",
0x04:"SWEEP",0x05:"TRANSFER",0x06:"PAY_PORTION",0x08:"V2_SWAP_EXACT_IN",0x09:"V2_SWAP_EXACT_OUT",
0x0a:"PERMIT2_PERMIT",0x0b:"WRAP_ETH",0x0c:"UNWRAP_WETH",0x0d:"PERMIT2_TRANSFER_FROM_BATCH",
0x0e:"BALANCE_CHECK_ERC20",0x10:"V4_SWAP",0x11:"V3_POSITION_MANAGER_PERMIT",0x12:"V3_POSITION_MANAGER_CALL",
0x13:"V4_INITIALIZE_POOL",0x14:"V4_POSITION_MANAGER_CALL",0x21:"EXECUTE_SUB_PLAN",0x23:"FEW_V2_SWAP_EXACT_IN",
0x24:"FEW_V2_SWAP_EXACT_OUT",0x27:"WRAP_FEW_TOKEN",0x28:"UNWRAP_FEW_TOKEN"}

def parse_abi_bytes_array(data, off):
    # minimal ABI reader for execute(bytes,bytes[],uint256)
    pass

def decode_execute(inp):
    h=inp[10:]  # strip 0x + execute selector
    w=lambda i:int(h[i*64:(i+1)*64],16)
    off_cmd=w(0); off_arr=w(1); deadline=w(2)
    clen=w(off_cmd//32)
    cmds=bytes.fromhex(h[(off_cmd+32)*2:(off_cmd+32+clen)*2])
    arr_len=w(off_arr//32)
    elems=[]
    for i in range(arr_len):
        rel=w(off_arr//32+1+i)
        start=off_arr+32+rel
        ln=w(start//32)
        elems.append(start+32)
        elems[-1]=(start+32,ln)
    return cmds, deadline, elems, h

out=[]
for hsh,blk,frm in txs:
    tx=rpc("eth_getTransactionByHash",[hsh])
    inp=tx["input"]
    try:
        cmds,deadline,elems,h=decode_execute(inp)
        cnames=[]
        i=0
        for c in cmds:
            base=c & 0x3f
            allow=bool(c & 0x80)
            cnames.append(f"{CMDS.get(base,hex(base))}{'(allowRevert)' if allow else ''}")
        desc={"hash":hsh,"block":blk,"from":frm,"commands":cnames,"n_inputs":len(elems),"deadline":deadline,"input_len":(len(inp)-2)//2}
        # for WRAP_FEW_TOKEN / UNWRAP / SWEEP decode first 3 words of the element
        dec=[]
        for (start,ln) in elems[:4]:
            words=[h[(start+k)*2:(start+k+32)*2] for k in range(min(3,ln//32))]
            dec.append(words)
        desc["first_word_inputs"]=dec
        out.append(desc)
    except Exception as e:
        out.append({"hash":hsh,"block":blk,"error":str(e),"input_len":(len(inp)-2)//2})
    time.sleep(0.5)

print(json.dumps(out,indent=1))
json.dump(out,open("ur_tx_decode.json","w"),indent=1)
