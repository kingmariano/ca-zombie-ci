#!/usr/bin/env python3
import base64, hashlib, json, urllib.request, sys

ADDR = "LGWHT7EDRGXQMRTLQDL54WKQU2FYRMNTGF6QXVDMZRCXHBUOLR3BSIJQBY"
IDX = "https://mainnet-idx.algonode.cloud"

def b32_nopad(b):
    import base64 as b64
    s = b64.b32encode(b).decode().rstrip("=")
    return s

# fetch a tx from LGWHT with lsig
url = f"{IDX}/v2/accounts/{ADDR}/transactions?sig-type=lsig&limit=1"
with urllib.request.urlopen(url, timeout=30) as r:
    data = json.load(r)
tx = data["transactions"][0]
lsig = tx["signature"]["logicsig"]
logic_b64 = lsig["logic"]
args = lsig["args"]
prog = base64.b64decode(logic_b64)
print("txid:", tx["id"])
print("round:", tx["confirmed-round"])
print("args:", [base64.b64decode(a).decode('utf-8','replace') for a in args])
print("program_len:", len(prog))
print("program_b64:", logic_b64)

# address check: sha512_256("Program" + program), then base32 nopad
h = hashlib.new("sha512_256")
h.update(b"Program" + prog)
digest = h.digest()
computed = b32_nopad(digest)
print("computed_addr:", computed)
print("matches:", computed == ADDR)

# also compute the checksum form: address = base32(pubkey)[:58] + checksum
def checksum_addr(pk):
    chk = hashlib.new("sha512_256", pk).digest()[-4:]
    combo = pk + chk
    s = b32_nopad(combo)
    return s

print("checksum_addr:", checksum_addr(digest))

with open("lsig_program.bin", "wb") as f:
    f.write(prog)
with open("lsig_raw.json", "w") as f:
    json.dump({"txid": tx["id"], "round": tx["confirmed-round"], "args": args, "logic_b64": logic_b64, "logic_hex": prog.hex(), "computed_addr": computed, "matches": computed == ADDR, "checksum_addr": checksum_addr(digest)}, f, indent=1)

# disassemble
body = json.dumps({"bytecode": base64.b64encode(prog).decode()}).encode()
req = urllib.request.Request("https://mainnet-api.algonode.cloud/v2/teal/disassemble", data=body, headers={"Content-Type": "application/json"}, method="POST")
with urllib.request.urlopen(req, timeout=30) as r:
    dis = json.load(r)
print("---DISASM---")
print(dis.get("result", dis))
with open("lsig_disasm.txt", "w") as f:
    f.write(dis.get("result", str(dis)))
