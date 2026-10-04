#!/usr/bin/env python3
"""Read-only enumeration of Alpaca PositionManager positions on BSC.

Usage: python3 enumerate_positions.py <block>
Writes positions_raw.json + positions_summary.json in the current directory.
No transactions are signed or sent; only eth_call via JSON-RPC.
"""
import json, os, sys, urllib.request

ENV = "/home/heisenberg/CA/.env"
KEY = os.environ.get("NODEREAL_API_KEY")
if not KEY and os.path.exists(ENV):
    for line in open(ENV):
        line = line.strip()
        if line.startswith("NODEREAL_API_KEY="):
            KEY = line.split("=", 1)[1].strip().strip('"').strip("'")
if not KEY:
    sys.exit("NODEREAL_API_KEY not available")
RPC = f"https://bsc-mainnet.nodereal.io/v1/{KEY}"

BLOCK = int(sys.argv[1]) if len(sys.argv) > 1 else None
if BLOCK is None:
    req = {"jsonrpc": "2.0", "id": 1, "method": "eth_blockNumber", "params": []}
    BLOCK = int(json.load(urllib.request.urlopen(urllib.request.Request(
        RPC, json.dumps(req).encode(), {"Content-Type": "application/json"})))["result"], 16)

PM = "0xABA0b03eaA3684EB84b51984add918290B41Ee19"
GP = "0x878ef0130340B8375de06287A47A6C9c2bd26618"
BK = "0xD0AEcee1520B5F9925D952405F9A06Dcd8fd6e6C"

def rpc_batch(calls, idbase=0):
    """calls: list of (to, data). Returns list of results (hex str or None)."""
    out = []
    for i in range(0, len(calls), 50):
        chunk = calls[i:i+50]
        payload = [{"jsonrpc": "2.0", "id": idbase + i + j, "method": "eth_call",
                    "params": [{"to": to, "data": data}, hex(BLOCK)]}
                   for j, (to, data) in enumerate(chunk)]
        req = urllib.request.Request(RPC, json.dumps(payload).encode(),
                                     {"Content-Type": "application/json"})
        resp = json.load(urllib.request.urlopen(req))
        byid = {r["id"]: r for r in resp}
        for j in range(len(chunk)):
            r = byid.get(idbase + i + j, {})
            out.append(r.get("result"))
    return out

def enc_u256(v):
    return hex(v)[2:].rjust(64, "0")

def enc_addr(a):
    return a.lower().replace("0x", "").rjust(64, "0")

def dec_u256(h):
    return int(h, 16)

def dec_addr(h):
    return "0x" + h[-40:]

# --- 1. find lastPositionId ---
SEL_LAST = "0x58354502"
res = rpc_batch([(PM, SEL_LAST)])
last_id = dec_u256(res[0])
print(f"block={BLOCK} lastPositionId={last_id}")

# --- 2. enumerate positions via GetPositions.getPositionWithSafetyBuffer ---
SEL_GP = "0x833175d2"
calls = []
for start in range(1, last_id + 1, 100):
    data = SEL_GP + enc_addr(PM) + enc_u256(start) + enc_u256(100)
    calls.append((GP, data))
raw = rpc_batch(calls)
positions = {}
for start, r in zip(range(1, last_id + 1, 100), raw):
    if not r:
        continue
    body = bytes.fromhex(r[2:])
    # (address[], uint256[], uint256[]) offsets
    offs = [int.from_bytes(body[i*32:(i+1)*32], "big") for i in range(3)]
    def read_arr(o):
        n = int.from_bytes(body[o:o+32], "big")
        return body[o+32:o+32+n*32]
    arr_pos = read_arr(offs[0])
    arr_debt = read_arr(offs[1])
    arr_buf = read_arr(offs[2])
    for i in range(len(arr_debt)//32):
        pid = start + i
        paddr = dec_addr(arr_pos[i*32:(i+1)*32].hex())
        d = int.from_bytes(arr_debt[i*32:(i+1)*32], "big")
        b = int.from_bytes(arr_buf[i*32:(i+1)*32], "big")
        positions[pid] = {"position": paddr, "debtShare": str(d), "safetyBuffer": str(b)}

# --- 3. get pool id per position ---
SEL_POOLS = "0x6dbe4ef2"
ids = sorted(positions)
pool_calls = [(PM, SEL_POOLS + enc_u256(pid)) for pid in ids]
pool_raw = rpc_batch(pool_calls)
for pid, r in zip(ids, pool_raw):
    positions[pid]["poolId"] = r if r else None

# --- 4. get collateral per position ---
SEL_BKPOS = "0x29d88594"
bk_calls = []
for pid in ids:
    pool = positions[pid]["poolId"] or ("0x" + "00"*32)
    data = SEL_BKPOS + pool[2:].rjust(64, "0") + positions[pid]["position"][2:].rjust(64, "0")
    bk_calls.append((BK, data))
bk_raw = rpc_batch(bk_calls)
for pid, r in zip(ids, bk_raw):
    if r and len(r) >= 130:
        positions[pid]["lockedCollateral"] = str(int(r[2:66], 16))
        positions[pid]["debtShareBK"] = str(int(r[66:130], 16))
    else:
        positions[pid]["lockedCollateral"] = None
        positions[pid]["debtShareBK"] = None

with open("positions_raw.json", "w") as f:
    json.dump({"block": BLOCK, "lastPositionId": last_id, "positions": positions}, f, indent=1)

live = [p for p in positions.values()
        if (p.get("debtShareBK") and int(p["debtShareBK"]) > 0)
        or (p.get("lockedCollateral") and int(p["lockedCollateral"]) > 0)]
summary = {
    "block": BLOCK,
    "lastPositionId": last_id,
    "totalPositions": len(positions),
    "withDebt": sum(1 for p in positions.values() if p.get("debtShareBK") and int(p["debtShareBK"]) > 0),
    "withCollateral": sum(1 for p in positions.values() if p.get("lockedCollateral") and int(p["lockedCollateral"]) > 0),
    "nonEmpty": len(live),
    "nonEmptyPositions": live,
}
with open("positions_summary.json", "w") as f:
    json.dump(summary, f, indent=1)
print(json.dumps({k: v for k, v in summary.items() if k != "nonEmptyPositions"}, indent=1))
for p in live:
    print(p)
