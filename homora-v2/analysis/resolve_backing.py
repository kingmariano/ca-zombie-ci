#!/usr/bin/env python3
"""Resolve Homora collateral wrappers: underlying, rate, bank-held shares, and wrapper backing.

For each unique (wrapper, collId) in a scan JSON:
 - wrapper.getUnderlyingToken(id), getUnderlyingRate(id)
 - wrapper.balanceOf(bank, id)  (total bank-held shares for that id)
 - wrapper.chef() / wrapper.staking() / wrapper.gauge()
 - chef.userInfo(pid, wrapper).amount ; staking.balanceOf(wrapper)
 - wrapper's own balance of the underlying token
 - underlying metadata: token0/token1/getReserves/totalSupply/symbol/decimals (LP) or symbol/decimals

Read-only. Usage: resolve_backing.py <scan.json> <rpc> <out.json>
"""
import json
import sys
import time
import requests
from eth_abi import encode, decode
from eth_utils import keccak, to_checksum_address

MULTICALL3 = "0xcA11bde05977b3631167028862bE2a173976CA11"


def sel(sig):
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

    def batch(self, calls, chunk=40, retries=5):
        out = []
        for i in range(0, len(calls), chunk):
            part = calls[i:i + chunk]
            payload = []
            for to, data in part:
                self.id += 1
                payload.append({"jsonrpc": "2.0", "id": self.id, "method": "eth_call",
                                "params": [{"to": to, "data": "0x" + data.hex()}, "latest"]})
            ok = False
            for attempt in range(retries):
                try:
                    r = self.s.post(self.url, json=payload, timeout=120)
                    res = r.json()
                    if isinstance(res, dict):
                        res = [res]
                    res = sorted(res, key=lambda x: x.get("id", 0))
                    out.extend([x.get("result") for x in res])
                    ok = True
                    break
                except Exception:
                    time.sleep(2.0 * (attempt + 1))
            if not ok:
                # fallback: individual calls
                for to, data in part:
                    got = None
                    for attempt in range(3):
                        try:
                            r = self.s.post(self.url, json={"jsonrpc": "2.0", "id": 1, "method": "eth_call",
                                                            "params": [{"to": to, "data": "0x" + data.hex()}, "latest"]}, timeout=60)
                            got = r.json().get("result")
                            break
                        except Exception:
                            time.sleep(1.5 * (attempt + 1))
                    out.append(got)
        return out

    def call(self, to, data):
        return self.batch([(to, data)], chunk=1)[0]

    def block(self):
        r = self.s.post(self.url, json={"jsonrpc": "2.0", "id": 1, "method": "eth_blockNumber", "params": []}, timeout=30)
        return int(r.json()["result"], 16)


def mc(rpc, calls, chunk=40):
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


def dec(types, raw):
    if raw is None:
        return None
    if isinstance(raw, str):
        if raw == "0x" or len(raw) < 34:
            return None
        raw = bytes.fromhex(raw[2:])
    if len(raw) < 32:
        return None
    try:
        return decode(types, raw)
    except Exception:
        return None


def main(scan_path, rpc_url, out_path):
    scan = json.load(open(scan_path))
    rpc = Rpc(rpc_url)
    bank = scan["bank"]
    pairs = {}
    for pid, p in scan["positions"].items():
        if p and p.get("collSize") not in (None, "0") and p.get("collToken"):
            pairs.setdefault((p["collToken"], p["collId"]), []).append(pid)
    keys = list(pairs.keys())
    res = {"chain": scan["chain"], "bank": bank, "block": rpc.block(), "ids": {}, "wrappers": {}}

    # 1. underlying + rate + bank balance per id
    calls = []
    for (w, i) in keys:
        calls.append((w, sel("getUnderlyingToken(uint256)(address)") + encode(["uint256"], [int(i)])))
        calls.append((w, sel("getUnderlyingRate(uint256)(uint256)") + encode(["uint256"], [int(i)])))
        calls.append((w, sel("balanceOf(address,uint256)(uint256)") + encode(["address", "uint256"], [bank, int(i)])))
    raws = mc(rpc, calls, chunk=40)
    for idx, (w, i) in enumerate(keys):
        u = dec(["address"], raws[3 * idx])
        r = dec(["uint256"], raws[3 * idx + 1])
        b = dec(["uint256"], raws[3 * idx + 2])
        res["ids"][f"{w}:{i}"] = {
            "wrapper": w, "id": i,
            "underlying": to_checksum_address(u[0]) if u else None,
            "rate": str(r[0]) if r else None,
            "bankShares": str(b[0]) if b else None,
            "positions": pairs[(w, i)],
        }

    # 2. wrapper backing hooks
    wrappers = sorted({w for w, _ in keys})
    calls = []
    for w in wrappers:
        calls.append((w, sel("chef()(address)")))
        calls.append((w, sel("staking()(address)")))
        calls.append((w, sel("gauge()(address)")))
    raws = mc(rpc, calls, chunk=40)
    for idx, w in enumerate(wrappers):
        c = dec(["address"], raws[3 * idx])
        s = dec(["address"], raws[3 * idx + 1])
        g = dec(["address"], raws[3 * idx + 2])
        res["wrappers"][w] = {
            "chef": to_checksum_address(c[0]) if c and int(c[0], 16) else None,
            "staking": to_checksum_address(s[0]) if s and int(s[0], 16) else None,
            "gauge": to_checksum_address(g[0]) if g and int(g[0], 16) else None,
        }

    # 3. chef userInfo per (chef,pid)
    chef_pids = {}
    for k, v in res["ids"].items():
        w = v["wrapper"]
        chef = res["wrappers"][w].get("chef")
        if chef:
            pid = int(v["id"]) >> 240
            v["chefPid"] = pid
            chef_pids.setdefault((chef, pid), []).append(k)
    calls = []
    order = []
    for (chef, pid) in chef_pids:
        calls.append((chef, sel("userInfo(uint256,address)(uint256,uint256)") + encode(["uint256", "address"], [pid, wrappers[0]])))
        order.append((chef, pid))
    # userInfo must be per wrapper; rebuild correctly
    calls = []
    order = []
    for k, v in res["ids"].items():
        chef = res["wrappers"][v["wrapper"]].get("chef")
        if chef:
            calls.append((chef, sel("userInfo(uint256,address)(uint256,uint256)") + encode(["uint256", "address"], [v["chefPid"], v["wrapper"]])))
            order.append(k)
    raws = mc(rpc, calls, chunk=40)
    for idx, k in enumerate(order):
        d = dec(["uint256", "uint256"], raws[idx])
        res["ids"][k]["stakedAmount"] = str(d[0]) if d else None

    # 4. staking/gauge balanceOf(wrapper) per wrapper
    calls = []
    order = []
    for w in wrappers:
        st = res["wrappers"][w].get("staking") or res["wrappers"][w].get("gauge")
        if st:
            calls.append((st, sel("balanceOf(address)(uint256)") + encode(["address"], [w])))
            order.append(w)
    raws = mc(rpc, calls, chunk=40)
    for idx, w in enumerate(order):
        d = dec(["uint256"], raws[idx])
        res["wrappers"][w]["stakedBalance"] = str(d[0]) if d else None

    # 5. underlying metadata + LP reserves; also wrapper's balance of underlying
    unders = sorted({v["underlying"] for v in res["ids"].values() if v["underlying"]})
    calls = []
    for u in unders:
        calls.append((u, sel("token0()(address)")))
        calls.append((u, sel("token1()(address)")))
        calls.append((u, sel("getReserves()(uint112,uint112,uint32)")))
        calls.append((u, sel("totalSupply()(uint256)")))
        calls.append((u, sel("symbol()(string)")))
        calls.append((u, sel("decimals()(uint8)")))
    raws = mc(rpc, calls, chunk=40)
    res["underlying"] = {}
    for idx, u in enumerate(unders):
        t0 = dec(["address"], raws[6 * idx])
        t1 = dec(["address"], raws[6 * idx + 1])
        rr = dec(["uint112", "uint112", "uint32"], raws[6 * idx + 2])
        ts = dec(["uint256"], raws[6 * idx + 3])
        sym = dec(["string"], raws[6 * idx + 4])
        dcs = dec(["uint8"], raws[6 * idx + 5])
        res["underlying"][u] = {
            "token0": to_checksum_address(t0[0]) if t0 else None,
            "token1": to_checksum_address(t1[0]) if t1 else None,
            "reserve0": str(rr[0]) if rr else None,
            "reserve1": str(rr[1]) if rr else None,
            "totalSupply": str(ts[0]) if ts else None,
            "symbol": sym[0] if sym else None,
            "decimals": dcs[0] if dcs else None,
        }
    toks = sorted({v[k] for v in res["underlying"].values() for k in ("token0", "token1") if v.get(k)})
    calls = []
    for t in toks:
        calls.append((t, sel("symbol()(string)")))
        calls.append((t, sel("decimals()(uint8)")))
    raws = mc(rpc, calls, chunk=40)
    res["tokens"] = {}
    for idx, t in enumerate(toks):
        sym = dec(["string"], raws[2 * idx])
        dcs = dec(["uint8"], raws[2 * idx + 1])
        res["tokens"][t] = {"symbol": sym[0] if sym else None, "decimals": dcs[0] if dcs else None}

    json.dump(res, open(out_path, "w"), indent=1)
    ok_ids = sum(1 for v in res["ids"].values() if v["underlying"])
    print(f"{scan['chain']}: {len(keys)} ids, {ok_ids} with underlying -> {out_path} (block {res['block']})")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2], sys.argv[3])
