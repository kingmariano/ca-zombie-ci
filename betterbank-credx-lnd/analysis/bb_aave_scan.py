#!/usr/bin/env python3
"""BetterBank Aave-fork market live-state scan (read-only, PulseChain)."""
import json, sys
sys.path.insert(0, '/home/heisenberg/CA/betterbank-credx-lnd/analysis')
from rpc import rpc, batch
from Crypto.Hash import keccak

URL = "https://rpc.pulsechain.com"
def k(sig):
    h = keccak.new(digest_bits=256); h.update(sig.encode()); return "0x" + h.hexdigest()

def sel(sig):
    return k(sig)[:10]

def dec_str(hexstr):
    try:
        b = bytes.fromhex(hexstr[2:])
        if len(b) >= 64:
            ln = int.from_bytes(b[32:64], 'big')
            return b[64:64+ln].decode('utf-8', 'replace')
    except Exception:
        pass
    return None

def dec_u(hexstr):
    if not hexstr or hexstr == '0x': return None
    return int(hexstr, 16)

BLOCK = rpc(URL, "eth_blockNumber", [])
print("block", int(BLOCK, 16))
POOL = "0xdB2c92c63e0320511a278673F0dBF8c3ACa7C5Ee"
DATA = "0x2369cf50ee0e5727bd971c0d2d172ea6f376edaa"
ACL  = "0xB2e5A4e70eBC18C26E39a802622DE06d0ff78890"
PROV = "0x21597Ae2f941b5022c6E72fd02955B7f3C87f4Cb"

out = {"block": int(BLOCK, 16), "pool": POOL}

# reserves
r = rpc(URL, "eth_call", [{"to": POOL, "data": sel("getReservesList()")}, "latest"])
b = bytes.fromhex(r[2:]); n = int.from_bytes(b[32:64], 'big')
reserves = ["0x" + b[64+i*32+12:64+i*32+32].hex() for i in range(n)]
print("reserves", n)

# aTokens
r = rpc(URL, "eth_call", [{"to": DATA, "data": sel("getAllATokens()")}, "latest"])
b = bytes.fromhex(r[2:]); n2 = int.from_bytes(b[32:64], 'big')
atokens = []
for i in range(n2):
    off = 64 + i*32
    str_off = int.from_bytes(b[off:off+32], 'big')
    tuple_start = 64 + 32*n2 + int.from_bytes(b[off:off+32], 'big')
    so = tuple_start + int.from_bytes(b[tuple_start:tuple_start+32], 'big')
    sl = int.from_bytes(b[so:so+32], 'big')
    sym = b[so+32:so+32+sl].decode()
    a = "0x" + b[tuple_start+32+12:tuple_start+64].hex()
    atokens.append({"symbol": sym, "atoken": a})
print("atokens", len(atokens), [x['symbol'] for x in atokens])

# batch: symbols/decimals/balances
calls = []
for a in reserves:
    calls.append(("eth_call", [{"to": a, "data": sel("symbol()")}, "latest"]))
    calls.append(("eth_call", [{"to": a, "data": sel("decimals()")}, "latest"]))
    calls.append(("eth_call", [{"to": a, "data": sel("balanceOf(address)") + POOL[2:].rjust(64, '0')}, "latest"]))
    calls.append(("eth_call", [{"to": a, "data": sel("totalSupply()")}, "latest"]))
res = batch(URL, calls)
rows = []
for i, a in enumerate(reserves):
    sym = dec_str(res[i*4]) or "?"
    dec = dec_u(res[i*4+1])
    bal = dec_u(res[i*4+2])
    ts = dec_u(res[i*4+3])
    rows.append({"asset": a, "symbol": sym, "decimals": dec, "pool_balance": bal, "token_totalSupply": ts})
    print(f"{sym:10s} {a} dec={dec} pool={bal} totalSupply={ts}")

# aToken balances (underlying) for pool -> totalSupply of aToken and pool's underlying balance already above
calls = []
for at in atokens:
    calls.append(("eth_call", [{"to": at['atoken'], "data": sel("totalSupply()")}, "latest"]))
    calls.append(("eth_call", [{"to": at['atoken'], "data": sel("balanceOf(address)") + POOL[2:].rjust(64,'0')}, "latest"]))
res = batch(URL, calls)
for i, at in enumerate(atokens):
    at['atoken_totalSupply'] = dec_u(res[i*2])
    at['atoken_bal_pool'] = dec_u(res[i*2+1])
    print(f"aToken {at['symbol']:10s} {at['atoken']} totalSupply={at['atoken_totalSupply']}")

# ACL roles
ROLES = {name: k(name) for name in ["POOL_ADMIN", "EMERGENCY_ADMIN", "RISK_ADMIN", "FLASH_BORROWER", "BRIDGE", "ASSET_LISTING_ADMIN"]}
ROLES["DEFAULT_ADMIN_ROLE"] = "0x" + "00"*32
HOLDERS = {
    "provider_owner": "0x96F80a880A52533FAB2b51Ae4dCA719B2FCeCbD2",
    "team": "0x1EA35487AE62322F61f4C0F639a598d9eEB2F340",
    "custom_deployer": "0xc0702ae0374f83fc3ba71ce2b30a323b09ec19da",
    "pool": POOL,
    "zero": "0x" + "00"*20,
}
calls = []
for rn, rh in ROLES.items():
    for hn, ha in HOLDERS.items():
        calls.append(("eth_call", [{"to": ACL, "data": sel("hasRole(bytes32,address)") + rh[2:] + ha[2:].rjust(64, '0')}, "latest"]))
res = batch(URL, calls)
roles_out = {}
idx = 0
for rn, rh in ROLES.items():
    roles_out[rn] = {}
    for hn, ha in HOLDERS.items():
        v = res[idx]; idx += 1
        roles_out[rn][hn] = (dec_u(v) == 1)
        if dec_u(v) == 1:
            print(f"ROLE {rn} held by {hn} {ha}")
out["reserves"] = rows
out["atokens"] = atokens
out["roles"] = roles_out
out["acl_manager"] = ACL
out["provider"] = PROV
json.dump(out, open('/home/heisenberg/CA/betterbank-credx-lnd/analysis/bb_aave_state.json', 'w'), indent=1)
print("saved")
