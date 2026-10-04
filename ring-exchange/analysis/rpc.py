#!/usr/bin/env python3
"""Tiny JSON-RPC batch helper for HyperEVM (read-only). Usage: import and call."""
import json, time, urllib.request

RPC = "https://rpc.hyperliquid.xyz/evm"

def _post(payload, retries=6):
    last = None
    for i in range(retries):
        try:
            req = urllib.request.Request(
                RPC, data=json.dumps(payload).encode(),
                headers={"Content-Type": "application/json", "User-Agent": "research/1.0"})
            with urllib.request.urlopen(req, timeout=60) as r:
                last = json.loads(r.read())
            if isinstance(last, dict) and "error" in last:
                raise RuntimeError(f"rpc error: {last['error']}")
            return last
        except Exception as e:
            last = e
            if i == retries - 1:
                raise
            time.sleep(2.0 * (i + 1))
    raise RuntimeError(str(last))

def batch_calls(calls, block="latest"):
    """calls: list of (to, data) -> list of results (hex or error)."""
    out = []
    for i in range(0, len(calls), 10):
        chunk = calls[i:i+10]
        payload = []
        for j, (to, data) in enumerate(chunk):
            p = {"jsonrpc": "2.0", "id": j, "method": "eth_call",
                 "params": [{"to": to, "data": data}, hex(block) if isinstance(block, int) else block]}
            payload.append(p)
        res = _post(payload)
        by_id = {r.get("id"): r for r in res}
        for j in range(len(chunk)):
            r = by_id.get(j, {})
            if "error" in r:
                # retry individually
                single = {"jsonrpc": "2.0", "id": 0, "method": "eth_call",
                          "params": [{"to": chunk[j][0], "data": chunk[j][1]},
                                     hex(block) if isinstance(block, int) else block]}
                try:
                    rr = _post(single)
                    out.append(rr.get("result"))
                except Exception:
                    out.append({"error": r["error"]})
                time.sleep(0.4)
            else:
                out.append(r.get("result"))
        time.sleep(0.25)
    return out

def get_balance(addrs, block="latest"):
    out = []
    for i in range(0, len(addrs), 10):
        payload = [{"jsonrpc": "2.0", "id": j, "method": "eth_getBalance",
                    "params": [a, hex(block) if isinstance(block, int) else block]}
                   for j, a in enumerate(addrs[i:i+10])]
        res = _post(payload)
        by_id = {r.get("id"): r for r in res}
        for j in range(len(addrs[i:i+10])):
            out.append(by_id.get(j, {}).get("result"))
        time.sleep(0.25)
    return out

def get_storage(addrs_slots, block="latest"):
    out = []
    payload = [{"jsonrpc": "2.0", "id": j, "method": "eth_getStorageAt",
                "params": [a, s, hex(block) if isinstance(block, int) else block]}
               for j, (a, s) in enumerate(addrs_slots)]
    res = _post(payload)
    by_id = {r.get("id"): r for r in res}
    for j in range(len(addrs_slots)):
        out.append(by_id.get(j, {}).get("result"))
    return out

def sel(sig):
    """4-byte selector for a signature like 'balanceOf(address)'."""
    import hashlib
    return "0x" + hashlib.sha3_256(sig.encode()).hexdigest()[:8]  # placeholder; use keccak below

def keccak_sel(sig):
    # minimal keccak-256 (Ethereum) implementation
    def keccak256(data: bytes) -> bytes:
        # Keccak-f[1600] implementation
        RC = [0x0000000000000001,0x0000000000008082,0x800000000000808A,0x8000000080008000,
              0x000000000000808B,0x0000000080000001,0x8000000080008081,0x8000000000008009,
              0x000000000000008A,0x0000000000000088,0x0000000080008009,0x000000008000000A,
              0x000000008000808B,0x800000000000008B,0x8000000000008089,0x8000000000008003,
              0x8000000000008002,0x8000000000000080,0x000000000000800A,0x800000008000000A,
              0x8000000080008081,0x8000000000008080,0x0000000080000001,0x8000000080008008]
        R = [[0,36,3,41,18],[1,44,10,45,2],[62,6,43,15,61],[28,55,25,21,56],[27,20,39,8,14]]
        def rol(x,n): return ((x<<n)|(x>>(64-n)))&0xFFFFFFFFFFFFFFFF
        rate=136
        data=bytearray(data)
        data.append(0x01)
        while len(data)%rate!=0: data.append(0)
        data[-1]^=0x80
        S=[[0]*5 for _ in range(5)]
        for off in range(0,len(data),rate):
            blk=data[off:off+rate]
            for i in range(rate//8):
                x,y=i%5,i//5
                S[x][y]^=int.from_bytes(blk[i*8:i*8+8],'little')
            for rnd in range(24):
                C=[S[x][0]^S[x][1]^S[x][2]^S[x][3]^S[x][4] for x in range(5)]
                D=[C[(x-1)%5]^rol(C[(x+1)%5],1) for x in range(5)]
                for x in range(5):
                    for y in range(5): S[x][y]^=D[x]
                B=[[0]*5 for _ in range(5)]
                for x in range(5):
                    for y in range(5):
                        B[y][(2*x+3*y)%5]=rol(S[x][y],R[x][y])
                for x in range(5):
                    for y in range(5):
                        S[x][y]=B[x][y]^((~B[(x+1)%5][y])&B[(x+2)%5][y])
                S[0][0]^=RC[rnd]
        out=b""
        for i in range(4):
            x,y=i%5,i//5
            out+=S[x][y].to_bytes(8,'little')
        return out
    return "0x"+keccak256(sig.encode()).hex()[:8]

if __name__ == "__main__":
    # smoke test
    w = "0x9e1148bC3665a9f7C35F313d89c0432c34928AEf"
    data = keccak_sel("totalSupply()")
    print("sel", data)
    print(batch_calls([(w, data)])[0])
