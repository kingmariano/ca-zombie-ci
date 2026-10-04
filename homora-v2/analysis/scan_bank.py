#!/usr/bin/env python3
"""Read-only Homora V2 bank scanner.

Enumerates: bank params, allBanks, token balances, external cToken debt, all positions
(collateral + debts), and collateral/borrow ETH values. Writes JSON to stdout/file.

Usage: python3 scan_bank.py <chain> <rpc_url> <bank_addr> <out.json>
Read-only: only eth_call / eth_getCode / eth_blockNumber.
"""
import json
import sys
import time
import requests
from eth_abi import encode, decode
from eth_utils import keccak, to_checksum_address

MULTICALL3 = "0xcA11bde05977b3631167028862bE2a173976CA11"


def sel(sig: str) -> bytes:
    """Selector from a full signature; truncates after the balanced top-level argument list."""
    depth = 0
    base = sig
    for i, ch in enumerate(sig):
        if ch == "(":
            depth += 1
        elif ch == ")":
            depth -= 1
            if depth == 0:
                base = sig[: i + 1]
                break
    return keccak(text=base)[:4]


class Rpc:
    def __init__(self, url):
        self.url = url
        self.id = 0
        self.s = requests.Session()
        self.s.headers.update({"User-Agent": "Mozilla/5.0 research"})

    def batch(self, calls, chunk=60, retries=4):
        """calls: list of (to, data). returns list of results (None on rpc error)."""
        out = []
        for i in range(0, len(calls), chunk):
            part = calls[i:i + chunk]
            payload = []
            for to, data in part:
                self.id += 1
                payload.append({
                    "jsonrpc": "2.0", "id": self.id, "method": "eth_call",
                    "params": [{"to": to, "data": "0x" + data.hex()}, "latest"],
                })
            for attempt in range(retries):
                try:
                    r = self.s.post(self.url, json=payload, timeout=90)
                    res = r.json()
                    if isinstance(res, dict):
                        res = [res]
                    res = sorted(res, key=lambda x: x.get("id", 0))
                    out.extend([x.get("result") for x in res])
                    break
                except Exception as e:
                    if attempt == retries - 1:
                        out.extend([None] * len(part))
                    else:
                        time.sleep(1.5 * (attempt + 1))
        return out

    def call(self, to, data):
        return self.batch([(to, data)])[0]

    def block(self):
        r = self.s.post(self.url, json={"jsonrpc": "2.0", "id": 1, "method": "eth_blockNumber", "params": []}, timeout=30)
        return int(r.json()["result"], 16)


def mc_aggregate3(rpc, calls, chunk=80):
    """calls: list of (target, calldata_bytes). Returns list of decoded raw result bytes (or None)."""
    out = []
    for i in range(0, len(calls), chunk):
        part = calls[i:i + chunk]
        arr = [(to_checksum_address(t), True, d) for t, d in part]
        data = sel("aggregate3((address,bool,bytes)[])") + encode(["(address,bool,bytes)[]"], [arr])
        res = rpc.call(MULTICALL3, data)
        if res is None:
            out.extend([None] * len(part))
            continue
        try:
            dec = decode(["(bool,bytes)[]"], bytes.fromhex(res[2:]))[0]
            out.extend([bytes(b) if ok else None for ok, b in dec])
        except Exception:
            out.extend([None] * len(part))
    return out


def dec_static(types, raw):
    if raw is None or len(raw) < 32:
        return None
    try:
        return decode(types, raw)
    except Exception:
        return None


def scan(chain, rpc_url, bank, out_path):
    rpc = Rpc(rpc_url)
    block = rpc.block()
    B = to_checksum_address(bank)
    res = {"chain": chain, "bank": B, "block": block}

    # --- params ---
    params = {
        "nextPositionId": "nextPositionId()(uint256)",
        "oracle": "oracle()(address)",
        "governor": "governor()(address)",
        "worker": "worker()(address)",
        "exec": "exec()(address)",
        "bankStatus": "bankStatus()(uint256)",
        "allowContractCalls": "allowContractCalls()(bool)",
        "feeBps": "feeBps()(uint256)",
        "caster": "caster()(address)",
    }
    res["params"] = {}
    for k, sig in params.items():
        raw = rpc.call(B, sel(sig))
        d = dec_static([sig.split("(")[-1].split(")")[0]], bytes.fromhex(raw[2:])) if raw and raw != "0x" else None
        res["params"][k] = (d[0] if d else None)
        if isinstance(res["params"][k], bytes):
            res["params"][k] = to_checksum_address(res["params"][k])
    npid = res["params"]["nextPositionId"] or 0

    # --- allBanks ---
    banks = []
    i = 0
    while True:
        raw = rpc.call(B, sel("allBanks(uint256)(address)") + encode(["uint256"], [i]))
        d = dec_static(["address"], bytes.fromhex(raw[2:])) if raw and raw != "0x" else None
        if not d or int(d[0], 16) == 0:
            break
        banks.append(to_checksum_address(d[0]))
        i += 1
        if i > 300:
            break
    res["banks"] = []

    # per-token data via multicall
    token_calls = []
    for t in banks:
        token_calls.append((B, sel("getBankInfo(address)(bool,address,uint256,uint256,uint256)") + encode(["address"], [t])))
        token_calls.append((t, sel("balanceOf(address)(uint256)") + encode(["address"], [B])))
    raws = mc_aggregate3(rpc, token_calls)
    ctokens = []
    for idx, t in enumerate(banks):
        info = dec_static(["bool", "address", "uint256", "uint256", "uint256"], raws[2 * idx]) if raws[2 * idx] else None
        bal = dec_static(["uint256"], raws[2 * idx + 1]) if raws[2 * idx + 1] else None
        entry = {"token": t, "balance": str(bal[0]) if bal else None}
        if info:
            entry.update({"isListed": info[0], "cToken": to_checksum_address(info[1]),
                          "reserve": str(info[2]), "totalDebt": str(info[3]), "totalShare": str(info[4])})
            ctokens.append(to_checksum_address(info[1]))
        else:
            entry["info_error"] = True
        res["banks"].append(entry)

    # external cToken debt of the bank
    if ctokens:
        cc = [(c, sel("borrowBalanceStored(address)(uint256)") + encode(["address"], [B])) for c in ctokens]
        craws = mc_aggregate3(rpc, cc)
        for idx, c in enumerate(ctokens):
            d = dec_static(["uint256"], craws[idx]) if craws[idx] else None
            res["banks"][idx]["cTokenDebt"] = str(d[0]) if d else None

    # --- positions ---
    ids = list(range(1, npid))
    calls = [(B, sel("positions(uint256)(address,address,uint256,uint256)") + encode(["uint256"], [pid])) for pid in ids]
    praws = mc_aggregate3(rpc, calls)
    positions = {}
    with_debt = []
    with_coll = []
    for idx, pid in enumerate(ids):
        d = dec_static(["address", "address", "uint256", "uint256"], praws[idx]) if praws[idx] else None
        if not d:
            positions[pid] = None
            continue
        owner = to_checksum_address(d[0]) if int(d[0], 16) else None
        coll = to_checksum_address(d[1]) if int(d[1], 16) else None
        positions[pid] = {"owner": owner, "collToken": coll, "collId": str(d[2]), "collSize": str(d[3])}
        if int(d[3]) > 0:
            with_coll.append(pid)

    # debts for all positions (only those with owner)
    owned = [pid for pid in ids if positions[pid]]
    calls = [(B, sel("getPositionDebts(uint256)(address[],uint256[])") + encode(["uint256"], [pid])) for pid in owned]
    draw = mc_aggregate3(rpc, calls, chunk=50)
    for idx, pid in enumerate(owned):
        d = dec_static(["address[]", "uint256[]"], draw[idx]) if draw[idx] else None
        if d:
            tokens = [to_checksum_address(x) for x in d[0]]
            debts = [str(x) for x in d[1]]
            positions[pid]["debtTokens"] = tokens
            positions[pid]["debts"] = debts
            if any(int(x) > 0 for x in d[1]):
                with_debt.append(pid)

    # collateral / borrow ETH values for positions with any collateral or debt
    cand = sorted(set(with_debt) | set(with_coll))
    calls = []
    for pid in cand:
        calls.append((B, sel("getCollateralETHValue(uint256)(uint256)") + encode(["uint256"], [pid])))
        calls.append((B, sel("getBorrowETHValue(uint256)(uint256)") + encode(["uint256"], [pid])))
    vraws = mc_aggregate3(rpc, calls, chunk=60)
    for idx, pid in enumerate(cand):
        cv = dec_static(["uint256"], vraws[2 * idx]) if vraws[2 * idx] else None
        bv = dec_static(["uint256"], vraws[2 * idx + 1]) if vraws[2 * idx + 1] else None
        positions[pid]["collETH"] = str(cv[0]) if cv else None
        positions[pid]["borrowETH"] = str(bv[0]) if bv else None
        if cv is not None and bv is not None:
            positions[pid]["liquidatable"] = cv[0] < bv[0] and cv[0] > 0

    res["positions"] = positions
    res["summary"] = {
        "num_positions": len(ids),
        "positions_with_collateral": len(with_coll),
        "positions_with_debt": len(with_debt),
        "positions_candidates": len(cand),
        "liquidatable": sum(1 for pid in cand if positions[pid].get("liquidatable")),
    }
    with open(out_path, "w") as f:
        json.dump(res, f, indent=1)
    print(json.dumps(res["summary"], indent=1))
    print("params:", json.dumps(res["params"], indent=1))
    print("banks:", len(banks), "wrote", out_path)


if __name__ == "__main__":
    scan(sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4])
