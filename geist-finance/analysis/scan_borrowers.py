#!/usr/bin/env python3
"""Geist Finance (Fantom): enumerate current borrowers (debt-token holders) + health factors.
Read-only. Uses $FANTOM_RPC_URL (CI) or public fallback. Writes ci-out/borrowers.json.
"""
import json, os, sys, time, urllib.request

RPC_ENV = os.environ.get("FANTOM_RPC_URL") or ""
PUBLIC_RPCS = [
    "https://rpcapi.fantom.network",
    "https://rpc.ftm.tools",
    "https://fantom.drpc.org",
    "https://1rpc.io/ftm",
    "https://fantom-rpc.publicnode.com",
]
CANDIDATE_RPCS = ([RPC_ENV] if RPC_ENV else []) + PUBLIC_RPCS
RPC = None          # chosen at runtime
USING_KEY = False

def _try_rpc(url):
    body = json.dumps({"jsonrpc": "2.0", "id": 1, "method": "eth_blockNumber", "params": []}).encode()
    req = urllib.request.Request(url, data=body, headers={
        "Content-Type": "application/json",
        "User-Agent": "Mozilla/5.0 (X11; Linux x86_64) research/read-only"})
    with urllib.request.urlopen(req, timeout=20) as r:
        d = json.loads(r.read())
    if "result" not in d:
        raise RuntimeError("no result")
    return int(d["result"], 16)

def choose_rpc():
    global RPC, USING_KEY
    for url in CANDIDATE_RPCS:
        try:
            blk = _try_rpc(url)
            RPC = url
            USING_KEY = (url == RPC_ENV)
            print(f"# rpc ok: {'<keyed env>' if USING_KEY else url} head={blk}", file=sys.stderr)
            return blk
        except Exception as e:
            print(f"# rpc failed: {'<keyed env>' if url == RPC_ENV else url} ({str(e)[:80]})", file=sys.stderr)
    raise RuntimeError("no working fantom RPC")

POOL = "0x9fad24f572045c7869117160a571b2e50b10d068"
MULTICALL3 = "0xcA11bde05977b3631167028862bE2a173976CA11"
TRANSFER_TOPIC = "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef"

RESERVES = [
    ("DAI",  "0x8d11ec38a3eb5e956b052f67da8bdc9bef8abf3e", "0xd25aa085ef6a304c6861750f16a3fa0d03d25ddb"),
    ("ETH",  "0x74b23882a30290451a17c44f4f05243b6b58c76d", "0xbdce00a99a4b7e99f7a6af7d44724f77d471f923"),
    ("WFTM", "0x21be370d5312f44cb42ce377bc9b8a0cef1a4c83", "0x53d01d351fa001db3c893388e43e3c630a8764f5"),
    ("BTC",  "0x321162cd933e2be498cd2267a90534a804051b11", "0x4318d7ad332a0fee9db6d2b9b4b021fda865abdb"),
    ("fUSDT","0x049d68029688eabf473097a2fc38ef61633a3c7a", "0x816ed5ee0c7b011024be3fb5b6166f59a7cbe0e4"),
    ("USDC", "0x04068da6c83afcfa0e13ba15a6696662335d5b75", "0x3eef981640064d63bb7ead4c6e3c0457e5c2934d"),
    ("CRV",  "0x1e4f97b9f9f913c46f1632781732927b9019c68b", "0x811a951d15f4dd33e9aa8d6f7aff6d1433fe644a"),
    ("MIM",  "0x82f0b8b456c1a451378467398982d4834b6829c1", "0xe6f5b2d4de014d8fa4c45b744921ffdf13f15d4a"),
    ("LINK", "0xb3654dc3d10ea7645f8319668e8f54d2574fbdc8", "0xfc8f690b285a013a86b7a71c0af70bc57302e7e4"),
]

def rpc(method, params, retries=6):
    body = json.dumps({"jsonrpc": "2.0", "id": 1, "method": method, "params": params}).encode()
    for a in range(retries):
        try:
            req = urllib.request.Request(RPC, data=body, headers={
                "Content-Type": "application/json",
                "User-Agent": "Mozilla/5.0 (X11; Linux x86_64) research/read-only"})
            with urllib.request.urlopen(req, timeout=90) as r:
                d = json.loads(r.read())
            if "error" in d:
                raise RuntimeError(str(d["error"])[:200])
            return d["result"]
        except Exception as e:
            if a == retries - 1:
                raise
            time.sleep(1.0 + 1.5 * a)

def get_logs(addr, from_blk, to_blk, topics=None):
    q = {"address": addr, "fromBlock": hex(from_blk), "toBlock": hex(to_blk)}
    if topics: q["topics"] = topics
    return rpc("eth_getLogs", [q])

def encode_balanceof(addr):
    return "0x70a08231" + addr[2:].rjust(64, "0")

def multicall_balanceof(tok, addrs):
    """returns dict addr -> balance (int) for calls that succeeded"""
    out = {}
    CH = 150
    for i in range(0, len(addrs), CH):
        part = addrs[i:i+CH]
        tuples = []
        for tgt in part:
            cd = bytes.fromhex(encode_balanceof(tgt)[2:])
            tup = (bytes.fromhex(tok[2:].rjust(64, "0"))
                   + (1).to_bytes(32, "big") + (96).to_bytes(32, "big")
                   + len(cd).to_bytes(32, "big") + cd + b"\x00" * ((32 - len(cd) % 32) % 32))
            tuples.append(tup)
        n = len(part)
        offsets = b""
        pos = 32 * n
        for tup in tuples:
            offsets += pos.to_bytes(32, "big")
            pos += len(tup)
        arr = n.to_bytes(32, "big") + offsets + b"".join(tuples)
        data = "0x82ad56cb" + (32).to_bytes(32, "big").hex() + arr.hex()
        res = rpc("eth_call", [{"to": MULTICALL3, "data": data}, "latest"])
        raw = bytes.fromhex(res[2:])
        off = int.from_bytes(raw[0:32], "big")
        n = int.from_bytes(raw[off:off+32], "big")
        p = off + 32 + 32 * n          # elements start after [len][offsets...]
        for j in range(n):
            succ = int.from_bytes(raw[p:p+32], "big") == 1
            rdoff = int.from_bytes(raw[p+32:p+64], "big")
            rlen = int.from_bytes(raw[p+rdoff:p+rdoff+32], "big")
            rd = raw[p+rdoff+32:p+rdoff+32+rlen]
            if succ and len(rd) == 32:
                out[part[j]] = int.from_bytes(rd, "big")
            p += 64 + 32 + ((rlen + 31) // 32) * 32
        time.sleep(0.1)
    return out

def scan_transfers(addr, start, head):
    addrs = set(); n_logs = 0
    chunk = 2_000_000
    blk = start
    while blk <= head:
        end = min(blk + chunk - 1, head)
        try:
            logs = get_logs(addr, blk, end, [TRANSFER_TOPIC])
        except Exception:
            if chunk > 100_000:
                chunk //= 2
                continue
            raise
        for lg in logs:
            for t in lg["topics"][1:3]:
                a = "0x" + t[-40:]
                if a != "0x" + "0" * 40:
                    addrs.add(a.lower())
        n_logs += len(logs)
        blk = end + 1
    return addrs, n_logs

def multicall_balances_multi(tokens, addrs):
    """One eth_call per chunk: for each address, balanceOf on every token.
    Returns {addr: {token: balance}} for successful calls with balance > 0."""
    out = {}
    CH = 60                      # 60 addrs x 9 tokens = 540 sub-calls per request
    for i in range(0, len(addrs), CH):
        part = addrs[i:i+CH]
        tuples = []
        keys = []
        for tgt in part:
            for tok in tokens:
                cd = bytes.fromhex(encode_balanceof(tgt)[2:])
                tup = (bytes.fromhex(tok[2:].rjust(64, "0"))
                       + (1).to_bytes(32, "big") + (96).to_bytes(32, "big")
                       + len(cd).to_bytes(32, "big") + cd + b"\x00" * ((32 - len(cd) % 32) % 32))
                tuples.append(tup)
                keys.append((tgt, tok))
        n = len(tuples)
        offsets = b""
        pos = 32 * n
        for tup in tuples:
            offsets += pos.to_bytes(32, "big")
            pos += len(tup)
        arr = n.to_bytes(32, "big") + offsets + b"".join(tuples)
        data = "0x82ad56cb" + (32).to_bytes(32, "big").hex() + arr.hex()
        res = rpc("eth_call", [{"to": MULTICALL3, "data": data}, "latest"])
        raw = bytes.fromhex(res[2:])
        off = int.from_bytes(raw[0:32], "big")
        m = int.from_bytes(raw[off:off+32], "big")
        p = off + 32 + 32 * m
        for j in range(m):
            succ = int.from_bytes(raw[p:p+32], "big") == 1
            rdoff = int.from_bytes(raw[p+32:p+64], "big")
            rlen = int.from_bytes(raw[p+rdoff:p+rdoff+32], "big")
            rd = raw[p+rdoff+32:p+rdoff+32+rlen]
            if succ and len(rd) == 32:
                v = int.from_bytes(rd, "big")
                if v > 0:
                    tgt, tok = keys[j]
                    out.setdefault(tgt, {})[tok] = v
            p += 64 + 32 + ((rlen + 31) // 32) * 32
        time.sleep(0.05)
    return out

def main():
    head = choose_rpc()
    print(f"# head={head}", file=sys.stderr)
    result = {"rpc": "<keyed env>" if USING_KEY else RPC, "head": head, "pool": POOL,
              "scan": {}, "borrowers": [], "n_candidates": 0}

    def save():
        os.makedirs("ci-out", exist_ok=True)
        with open("ci-out/borrowers.json", "w") as f:
            json.dump(result, f, indent=1)
        # simple text file for the Foundry test: address,hf sorted ascending
        try:
            rows = sorted(result["borrowers"], key=lambda b: int(b.get("healthFactor", 2**256 - 1)))
            with open("ci-out/borrowers.txt", "w") as f:
                for b in rows:
                    if "healthFactor" in b:
                        f.write(b["address"] + "," + b["healthFactor"] + "\n")
        except Exception as e:
            print("# borrowers.txt write failed: " + str(e), file=sys.stderr)

    # deploy block of pool: coarse scan for first log
    dep = 20_000_000
    for start in range(20_000_000, 60_000_000, 2_000_000):
        try:
            logs = get_logs(POOL, start, start + 1_999_999)
        except Exception:
            continue
        if logs:
            dep = start
            break
    result["pool_first_log_range_start"] = dep
    print(f"# pool first-log range start={dep}", file=sys.stderr)

    candidates = set()
    for (sym, asset, vdebt) in RESERVES:
        try:
            addrs, n = scan_transfers(vdebt, dep, head)
            result["scan"][sym] = {"logs": n, "addresses": len(addrs)}
            candidates |= addrs
            print(f"# {sym}: {n} transfer logs, {len(addrs)} addrs (cum {len(candidates)})", file=sys.stderr)
        except Exception as e:
            result["scan"][sym] = {"error": str(e)[:200]}
            print(f"# {sym} FAILED {e}", file=sys.stderr)
    result["n_candidates"] = len(candidates)
    cands = sorted(candidates)
    save()

    # debt balances: one pass, all tokens per address
    debt_balances = {}
    token_list = [r[2] for r in RESERVES]
    sym_by_token = {r[2]: r[0] for r in RESERVES}
    multi = multicall_balances_multi(token_list, cands)
    for c, per_tok in multi.items():
        for tok, v in per_tok.items():
            debt_balances.setdefault(c, {})[sym_by_token[tok]] = v
    print(f"# balances done: {len(debt_balances)} live debtors", file=sys.stderr)
    result["n_live_debtors"] = len(debt_balances)
    save()

    # health factors
    for c in sorted(debt_balances.keys()):
        try:
            res = rpc("eth_call", [{"to": POOL, "data": "0xbf92857c" + c[2:].rjust(64, "0")}, "latest"])
            b = bytes.fromhex(res[2:])
            vals = [int.from_bytes(b[i*32:(i+1)*32], "big") for i in range(6)]
            result["borrowers"].append({
                "address": c, "totalCollateralETH": str(vals[0]), "totalDebtETH": str(vals[1]),
                "availableBorrowsETH": str(vals[2]), "currentLiquidationThreshold": str(vals[3]),
                "ltv": str(vals[4]), "healthFactor": str(vals[5]), "debt": debt_balances[c]})
        except Exception as e:
            result["borrowers"].append({"address": c, "error": str(e)[:150], "debt": debt_balances[c]})
        if len(result["borrowers"]) % 50 == 0:
            save()
        time.sleep(0.02)

    save()
    print(f"# live debtors: {len(result['borrowers'])}", file=sys.stderr)
    print(json.dumps({k: v for k, v in result.items() if k not in ("borrowers",)}, indent=1))

if __name__ == "__main__":
    main()
