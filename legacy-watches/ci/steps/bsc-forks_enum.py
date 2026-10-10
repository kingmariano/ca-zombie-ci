#!/usr/bin/env python3
"""
bsc-forks_enum.py — legacy-watches H2-09 bsc-forks enumeration (READ-ONLY).

For each configured DEX factory (Uniswap-V2 forks):
  1. enumerate all pairs (factory.allPairsLength / allPairs)
  2. read token0/token1/getReserves per pair (multicall3, fallback to plain eth_call batches)
  3. read balanceOf(pair) for both tokens -> excess = balance - reserve  (skim() opportunity)
  4. fetch token decimals + USD prices (DefiLlama coins API, keyless)
  5. emit per-protocol JSON with: excess list (raw + USD), top pairs by USD, block number

Public RPCs only; optional env overrides (never printed):
  BSC_RPC_URL / RPC_URL, ETH_RPC_URL, POLYGON_RPC_URL, CRONOS_RPC_URL, GNOSIS_RPC_URL,
  AVAX_RPC_URL, FANTOM_RPC_URL, KAVA_RPC_URL
Env knobs:
  PROTOCOLS=fstswap,bscswap,...   (default: all)
  MAX_PAIRS=0                     (0 = full scan; N>0 = sample first/last N/2 + must-include pairs)
  OUT_DIR                         (default: <legacy-watches>/ci-out)
Outputs: OUT_DIR/bsc-forks_<protocol>_<chain>.json
"""
import json, os, sys, time, urllib.request, urllib.error
from pathlib import Path

try:
    sys.set_int_max_str_digits(100000)
except Exception:
    pass

ROOT = Path(__file__).resolve().parents[2]
OUT = Path(os.environ.get("OUT_DIR", str(ROOT / "ci-out")))
OUT.mkdir(parents=True, exist_ok=True)

MULTICALL3 = "0xcA11bde05977b3631167028862bE2a173976CA11"

SEL = {
    "allPairsLength": "0x574f2ba3",
    "allPairs": "0x1e3dd18b",
    "token0": "0x0dfe1681",
    "token1": "0xd21220a7",
    "getReserves": "0x0902f1ac",
    "balanceOf": "0x70a08231",
    "decimals": "0x313ce567",
    "symbol": "0x95d89b41",
    "totalSupply": "0x18160ddd",
}

CHAINS = {
    "bsc":      {"prefix": "bsc",      "rpcs": ["BSC_RPC_URL", "RPC_URL", "https://bsc-dataseed.binance.org", "https://binance.llamarpc.com", "https://bsc.publicnode.com"]},
    "ethereum": {"prefix": "ethereum", "rpcs": ["ETH_RPC_URL", "https://ethereum-rpc.publicnode.com", "https://eth.llamarpc.com"]},
    "polygon":  {"prefix": "polygon",  "rpcs": ["POLYGON_RPC_URL", "https://polygon-bor-rpc.publicnode.com", "https://polygon-rpc.com"]},
    "cronos":   {"prefix": "cronos",   "rpcs": ["CRONOS_RPC_URL", "https://cronos-evm-rpc.publicnode.com", "https://evm.cronos.org"]},
    "xdai":     {"prefix": "xdai",     "rpcs": ["GNOSIS_RPC_URL", "https://gnosis-rpc.publicnode.com", "https://rpc.gnosischain.com"]},
    "avax":     {"prefix": "avax",     "rpcs": ["AVAX_RPC_URL", "https://avalanche-c-chain-rpc.publicnode.com", "https://api.avax.network/ext/bc/C/rpc"]},
    "fantom":   {"prefix": "fantom",   "rpcs": ["FANTOM_RPC_URL", "https://fantom-rpc.publicnode.com", "https://rpcapi.fantom.network"]},
    "kava":     {"prefix": "kava",     "rpcs": ["KAVA_RPC_URL", "https://kava-evm-rpc.publicnode.com", "https://evm.kava.io"]},
}

# factory/router/token verified on-chain where possible (see dossier README.md)
PROTOCOLS = {
    "fstswap": {
        "deployments": [{"chain": "bsc", "factory": "0x9A272d734c5a0d7d84E0a892e891a553e8066dce",
                         "router": "0x1b6c9c20693afde803b27f8782156c0f892abc2d",
                         "token": "0xc9882def23bc42d53895b8361d0b1edc7570bc6a",
                         "must_include": ["0xb4ec801aed8c92f2e69589518aaa127afb37d8c9", "0xe9d7363bd5b5c252f28ceb142ffdb01e0fb936a5"]}],
    },
    "bakeryswap": {
        "deployments": [{"chain": "bsc", "factory": "0x01bF7C66c6BD861915CdaaE475042d3c4BaE16A7",
                         "router": "0xCDe540d7eAFE93aC5fE6233Bee57E1270D3E330F",
                         "token": "0xE02dF9e3e622DeBdD69fb838bB799E3F168902c5",
                         "must_include": []}],
    },
    "bscswap": {
        "deployments": [{"chain": "bsc", "factory": "0xCe8fd65646F2a2a897755A1188C04aCe94D2B8D0",
                         "router": "0xd954551853F55deb4Ae31407c423e67B1621424A",
                         "token": "0xf388ee045cab30321db3fb69eab7dfb0c20f10ec",
                         "must_include": ["0xc5c84863d32f41ad60eb2dead2d69c9553541616"]}],
    },
    "babyswap": {
        "deployments": [{"chain": "bsc", "factory": "0x86407bEa2078ea5f5EB5A52B2caA963bC1F889Da",
                         "router": "0x325E343f1dE602396E256B67eFd1F61C3A6B38BD",
                         "token": "0x53E562b9B7E5E94b81f10e96Ee70Ad06df3D2657",
                         "must_include": ["0x2d5a828406dba813431325558fe0a994938a73e3"]}],
    },
    "kaoyaswap": {
        "deployments": [{"chain": "bsc", "factory": "0xbFB0A989e12D49A0a3874770B1C1CdDF0d9162aA",
                         "router": "0x879EAD67C92ec2bFa70fa9d157F500B7b31b64AB",
                         "token": None,
                         "must_include": []}],
    },
    "empiredex": {
        "deployments": [
            {"chain": "bsc",      "factory": "0x06530550A48F990360DFD642d2132354A144F31d", "router": "0xdADaae6cDFE4FA3c35d54811087b3bC3Cd60F348", "token": "0xc83859c413a6ba5ca1620cd876c7e33a232c1c34", "must_include": ["0xf3114cb351f38f8e8ff17f8313ff91cec4ff196f"]},
            {"chain": "cronos",   "factory": "0x06530550A48F990360DFD642d2132354A144F31d", "router": "0xdADaae6cDFE4FA3c35d54811087b3bC3Cd60F348", "token": "0xc83859c413a6ba5ca1620cd876c7e33a232c1c34", "must_include": ["0x80523212e85e7FD850c85CC804263Ad421696d87"]},
            {"chain": "ethereum", "factory": "0xd674b01E778CF43D3E6544985F893355F46A74A5", "router": "0xe7A504316BebbE540496E29798187c9ECAD6ef4F", "token": "0x2302f393690487a4Fc5927bBeF63ff113E0c479d", "must_include": ["0x163B890f4892D593945579028Ec44Ef0f20A4633"]},
            {"chain": "polygon",  "factory": "0x06530550A48F990360DFD642d2132354A144F31d", "router": "0xB2855A6dAeeBDB72B0176A479A983066ae9775A6", "token": "0xc83859c413a6ba5ca1620cd876c7e33a232c1c34", "must_include": ["0x6d0d97fe6c323e5b3248ceb356dbf74708c2d8be"]},
            {"chain": "xdai",     "factory": "0x06530550A48F990360DFD642d2132354A144F31d", "router": "0xdADaae6cDFE4FA3c35d54811087b3bC3Cd60F348", "token": "0xc83859c413a6ba5ca1620cd876c7e33a232c1c34", "must_include": ["0xF6E0EeeFb7AcB6D5557d617DA1E24873997Ab3e9"]},
            {"chain": "avax",     "factory": "0x06530550A48F990360DFD642d2132354A144F31d", "router": "0xdADaae6cDFE4FA3c35d54811087b3bC3Cd60F348", "token": "0xc83859c413a6ba5ca1620cd876c7e33a232c1c34", "must_include": ["0x80832376db4e414c88629C54923aEcB9855346C0"]},
            {"chain": "fantom",   "factory": "0x06530550A48F990360DFD642d2132354A144F31d", "router": "0xdADaae6cDFE4FA3c35d54811087b3bC3Cd60F348", "token": "0xc83859c413a6ba5ca1620cd876c7e33a232c1c34", "must_include": ["0xc12a874065b52926f89f29253744c15bc37eaf0b"]},
            {"chain": "kava",     "factory": "0x06530550A48F990360DFD642d2132354A144F31d", "router": "0xdADaae6cDFE4FA3c35d54811087b3bC3Cd60F348", "token": "0xc83859c413a6ba5ca1620cd876c7e33a232c1c34", "must_include": []},
        ],
    },
}

MAX_PAIRS = int(os.environ.get("MAX_PAIRS", "0"))
ONLY = [p.strip() for p in os.environ.get("PROTOCOLS", "").split(",") if p.strip()]
SLEEP = float(os.environ.get("SLEEP", "0.1"))

def pad(v):
    return f"{v:064x}"

def enc(selector, *args):
    d = selector
    for a in args:
        if isinstance(a, int):
            d += pad(a)
        elif isinstance(a, str):
            d += a.lower().replace("0x", "").rjust(64, "0")
        else:
            raise ValueError(a)
    return d

def dec_u(res):
    if res is None or not isinstance(res, str) or res in ("0x", ""):
        return None
    h = res[2:] if res.startswith("0x") else res
    if len(h) == 0 or len(h) > 66:
        return None
    return int(h, 16)

def dec_addr(res):
    if res is None or not isinstance(res, str) or res in ("0x", ""):
        return None
    h = res[2:] if res.startswith("0x") else res
    if len(h) != 64:
        return None
    return "0x" + h[-40:]

def dec_str(res):
    if res is None or not isinstance(res, str) or res in ("0x", ""):
        return ""
    raw = bytes.fromhex(res[2:] if res.startswith("0x") else res)
    if len(raw) >= 64:
        try:
            off = int.from_bytes(raw[:32], "big")
            ln = int.from_bytes(raw[off:off + 32], "big")
            return raw[off + 32:off + 32 + ln].decode("utf-8", "replace")
        except Exception:
            pass
    return raw.rstrip(b"\x00").decode("utf-8", "replace")

class Rpc:
    def __init__(self, chain):
        cfg = CHAINS[chain]
        self.chain = chain
        self.rpcs = []
        for r in cfg["rpcs"]:
            if r.startswith("http"):
                self.rpcs.append(r)
            else:
                v = os.environ.get(r)
                if v:
                    self.rpcs.append(v)  # env-provided, never printed/logged
        self.good = None
        self.calls = 0
        self.errors = 0

    def _post(self, url, payload, timeout=60):
        req = urllib.request.Request(url, data=json.dumps(payload).encode(),
                                     headers={"Content-Type": "application/json", "User-Agent": "h2-09-recon/1.0"})
        with urllib.request.urlopen(req, timeout=timeout) as r:
            return json.loads(r.read())

    def rpc(self, method, params, id_=1):
        order = ([self.good] if self.good else []) + [r for r in self.rpcs if r != self.good]
        last = None
        for url in order:
            try:
                d = self._post(url, {"jsonrpc": "2.0", "id": id_, "method": method, "params": params})
                if "error" in d:
                    raise RuntimeError(d["error"])
                self.good = url
                return d.get("result")
            except Exception as e:
                last = e
        self.errors += 1
        raise RuntimeError(f"rpc failed: {last}")

    def call(self, to, data, block="latest"):
        self.calls += 1
        return self.rpc("eth_call", [{"to": to, "data": data}, block])

    def eth_call_batch(self, calls, block="latest", chunk=25):
        """Fallback: JSON-RPC batch of eth_call (no multicall). calls=[(to,data)]"""
        out = []
        for i in range(0, len(calls), chunk):
            part = calls[i:i + chunk]
            payload = [{"jsonrpc": "2.0", "id": j, "method": "eth_call", "params": [{"to": t, "data": d}, block]}
                       for j, (t, d) in enumerate(part)]
            order = ([self.good] if self.good else []) + [r for r in self.rpcs if r != self.good]
            res = None
            for url in order:
                try:
                    res = self._post(url, payload)
                    self.good = url
                    break
                except Exception:
                    continue
            if res is None:
                out.extend([None] * len(part))
                continue
            by_id = {x.get("id"): x for x in res}
            for j in range(len(part)):
                x = by_id.get(j) or {}
                out.append(x.get("result") if "error" not in x else None)
            self.calls += len(part)
            time.sleep(SLEEP)
        return out

    def multicall(self, calls, block):
        """calls=[(to,data)] -> list of raw hex results (None on per-call failure)."""
        results = [None] * len(calls)
        idx = list(range(len(calls)))
        batch = 150
        i = 0
        # check multicall3 exists
        try:
            code = self.rpc("eth_getCode", [MULTICALL3, block])
            has_mc = code and code not in ("0x", "0x0")
        except Exception:
            has_mc = False
        if not has_mc:
            return self.eth_call_batch(calls, block)
        while i < len(idx):
            part = idx[i:i + batch]
            data = self._enc_agg([calls[k] for k in part])
            ok = False
            for attempt in range(3):
                try:
                    res = self.call(MULTICALL3, data, block)
                    outs = self._dec_agg(res)
                    if len(outs) != len(part):
                        raise RuntimeError("multicall length mismatch")
                    for k, o in zip(part, outs):
                        results[k] = o
                    ok = True
                    break
                except Exception:
                    time.sleep(0.4 * (attempt + 1))
            if ok:
                i += len(part)
            elif batch > 1:
                batch = max(1, batch // 3)
                continue
            else:
                # size 1 and still failing -> mark and continue
                results[part[0]] = None
                i += 1
            time.sleep(SLEEP)
        return results

    @staticmethod
    def _enc_agg(calls):
        sel = "0x252dba42"  # aggregate((address,bytes)[])
        n = len(calls)
        offs = ""; bodies = ""; off = 0x20 * n
        for a, d in calls:
            db = bytes.fromhex(d[2:])
            padded = db + b"\x00" * ((32 - len(db) % 32) % 32)
            offs += pad(off)
            bodies += pad(int(a, 16)) + pad(0x40) + pad(len(db)) + padded.hex()
            off += 0x60 + len(padded)
        return sel + pad(0x20) + pad(n) + offs + bodies

    @staticmethod
    def _dec_agg(res):
        h = res[2:]
        A = int(h[64:128], 16)
        la = A * 2
        cnt = int(h[la:la + 64], 16)
        C = la + 64
        out = []
        for i in range(cnt):
            eo = int(h[C + i * 64:C + i * 64 + 64], 16)
            sp = C + eo * 2
            ln = int(h[sp:sp + 64], 16)
            out.append(h[sp + 64:sp + 64 + ln * 2])
        return out

def fetch_prices(rpc, chain_prefix, tokens):
    """tokens: iterable of addresses -> {addr: usd_price}"""
    out = {}
    toks = [t.lower() for t in set(tokens)]
    keyed = [f"{chain_prefix}:{t}" for t in toks]
    for i in range(0, len(keyed), 25):
        part = keyed[i:i + 25]
        url = "https://coins.llama.fi/prices/current/" + ",".join(part)
        for attempt in range(2):
            try:
                with urllib.request.urlopen(urllib.request.Request(url, headers={"User-Agent": "h2-09-recon"}), timeout=45) as r:
                    d = json.loads(r.read())
                for k, v in (d.get("coins") or {}).items():
                    out[k.split(":", 1)[1].lower()] = v.get("price")
                break
            except Exception:
                time.sleep(0.5 * (attempt + 1))
        time.sleep(0.1)
    return out

def enum_deployment(proto, dep, summary):
    chain = dep["chain"]
    rpc = Rpc(chain)
    tag = f"{proto}_{chain}"
    print(f"[{tag}] factory {dep['factory']} rpcs={len(rpc.rpcs)}", flush=True)
    out = {"protocol": proto, "chain": chain, "factory": dep["factory"], "router": dep.get("router"),
           "token": dep.get("token"), "generated_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
           "block": None, "pairs_total": None, "pairs_scanned": 0, "scan_mode": "full",
           "excess": [], "top_pairs": [], "errors": [], "notes": []}
    try:
        blk = int(rpc.rpc("eth_blockNumber", []), 16)
    except Exception as e:
        out["errors"].append(f"no rpc: {e}")
        print(f"[{tag}] UNREACHABLE", flush=True)
        return out, rpc
    # public nodes are pruned; pinning old blocks causes 'missing trie node'. Read at latest
    # (block drift is bounded and every excess hit is re-verified at a single end block below).
    block = "latest"
    out["block_start"] = blk
    out["block"] = blk
    n = None
    try:
        n = dec_u(rpc.call(dep["factory"], SEL["allPairsLength"], block))
    except Exception as e:
        out["errors"].append(f"allPairsLength failed: {e}")
    if n is None:
        print(f"[{tag}] factory unreadable", flush=True)
        return out, rpc
    out["pairs_total"] = n
    print(f"[{tag}] block={blk} pairs={n}", flush=True)

    # 1) all pairs
    pairs = [None] * n
    res = rpc.multicall([(dep["factory"], enc(SEL["allPairs"], i)) for i in range(n)], block)
    for i, r in enumerate(res):
        pairs[i] = dec_addr(r)
    pairs = [p for p in pairs if p]

    # 2) sample selection
    must = [m.lower() for m in dep.get("must_include", [])]
    sel_pairs = list(pairs)
    if MAX_PAIRS > 0 and MAX_PAIRS < len(pairs):
        k = max(1, MAX_PAIRS // 2)
        sel_pairs = pairs[:k] + pairs[-k:]
        sel_pairs += [p for p in pairs if p.lower() in must and p not in sel_pairs]
        out["scan_mode"] = f"sample_first{k}_last{k}"
    out["pairs_scanned"] = len(sel_pairs)
    print(f"[{tag}] scanning {len(sel_pairs)} pairs", flush=True)

    # 3) token0/token1/getReserves
    calls = []
    for p in sel_pairs:
        calls += [(p, SEL["token0"]), (p, SEL["token1"]), (p, SEL["getReserves"])]
    res = rpc.multicall(calls, block)
    structs = []
    for j, p in enumerate(sel_pairs):
        t0 = dec_addr(res[j * 3]); t1 = dec_addr(res[j * 3 + 1]); rr = res[j * 3 + 2]
        r0 = r1 = None
        if isinstance(rr, str):
            h = rr[2:] if rr.startswith("0x") else rr  # multicall results have no 0x prefix
            if len(h) >= 128:
                r0 = int(h[0:64], 16); r1 = int(h[64:128], 16)
        structs.append({"pair": p, "token0": t0, "token1": t1, "r0": r0, "r1": r1})

    # 4) balances of pair on each token
    calls = []
    for s in structs:
        if s["token0"]:
            calls.append((s["token0"], enc(SEL["balanceOf"], s["pair"])))
        if s["token1"]:
            calls.append((s["token1"], enc(SEL["balanceOf"], s["pair"])))
    res = rpc.multicall(calls, block)
    k = 0
    for s in structs:
        if s["token0"]:
            s["b0"] = dec_u(res[k]); k += 1
        if s["token1"]:
            s["b1"] = dec_u(res[k]); k += 1

    # 5) decimals for unique tokens
    toks = set()
    for s in structs:
        if s["token0"]: toks.add(s["token0"].lower())
        if s["token1"]: toks.add(s["token1"].lower())
    toks = sorted(toks)
    dec = {}
    for i in range(0, len(toks), 100):
        part = toks[i:i + 100]
        res = rpc.multicall([(t, SEL["decimals"]) for t in part], block)
        for t, r in zip(part, res):
            d = dec_u(r)
            dec[t] = d if isinstance(d, int) and d <= 36 else None

    # 6) prices
    prices = fetch_prices(rpc, CHAINS[chain]["prefix"], toks)

    def human(tok, raw):
        if raw is None: return None
        d = dec.get(tok.lower())
        return raw / (10 ** d) if isinstance(d, int) else None

    # 7) excess list + top pairs
    excess = []
    top = []
    unpriced = 0
    underwater_all = 0.0
    underwater_pairs = 0
    for s in structs:
        s["excess0"] = None; s["excess1"] = None
        for side, tok, bal_key, res_key in (("0", "token0", "b0", "r0"), ("1", "token1", "b1", "r1")):
            tok_a = s[tok]
            if not tok_a or s.get(bal_key) is None or s.get(res_key) is None:
                continue
            ex = s[bal_key] - s[res_key]
            s["excess" + side] = ex
            if ex > 0:
                pr = prices.get(tok_a.lower())
                excess.append({
                    "pair": s["pair"], "token": tok_a, "side": side, "pair_token0": s["token0"],
                    "reserve_raw": str(s[res_key]), "balance_raw": str(s[bal_key]),
                    "excess_raw": str(ex), "excess_human": human(tok_a, ex),
                    "price_usd": pr, "excess_usd": (human(tok_a, ex) * pr) if (pr and human(tok_a, ex) is not None) else None,
                    "verified": False,
                })
        v0 = human(s["token0"], s["r0"]) if s["token0"] and s["r0"] is not None else None
        v1 = human(s["token1"], s["r1"]) if s["token1"] and s["r1"] is not None else None
        p0 = prices.get((s["token0"] or "").lower()); p1 = prices.get((s["token1"] or "").lower())
        usd = 0.0; ok = False
        if v0 is not None and p0: usd += v0 * p0; ok = True
        if v1 is not None and p1: usd += v1 * p1; ok = True
        if not ok: unpriced += 1
        # underwater = reserve > real balance (phantom reserve / already-removed tokens)
        uw = 0.0; uw_ok = False
        for res_key, ex_key, tok_key, pr in (("r0", "excess0", "token0", p0), ("r1", "excess1", "token1", p1)):
            if s.get(ex_key) is not None and s[res_key] is not None and s.get(ex_key) < 0:
                tok_addr = s.get(tok_key)
                hv = human(tok_addr, -s[ex_key]) if tok_addr else None
                if hv is not None and pr:
                    uw += hv * pr; uw_ok = True
        top.append({
            "pair": s["pair"], "token0": s["token0"], "token1": s["token1"],
            "reserve0_human": human(s["token0"], s["r0"]) if s["token0"] else None,
            "reserve1_human": human(s["token1"], s["r1"]) if s["token1"] else None,
            "tvl_usd_est": round(usd, 2) if ok else None,
            "underwater_usd_est": round(uw, 2) if uw_ok else None,
            "excess0_human": human(s["token0"], s["excess0"]) if s["token0"] and s.get("excess0") is not None else None,
            "excess1_human": human(s["token1"], s["excess1"]) if s["token1"] and s.get("excess1") is not None else None,
        })
        if uw_ok:
            underwater_all += uw
            if uw > 1000:
                underwater_pairs += 1
    top.sort(key=lambda x: (x["tvl_usd_est"] or 0), reverse=True)
    excess.sort(key=lambda x: (x["excess_usd"] or 0), reverse=True)

    # re-verify every excess candidate at one explicit end block
    if excess:
        blk_end = int(rpc.rpc("eth_blockNumber", []), 16)
        out["block"] = blk_end
        vb = hex(blk_end)
        calls = []
        for e in excess:
            calls.append((e["pair"], SEL["getReserves"]))
            calls.append((e["token"], enc(SEL["balanceOf"], e["pair"])))
        vres = rpc.multicall(calls, vb)
        kept = []
        dropped = []
        for j, e in enumerate(excess):
            rr = vres[j * 2]; bb = vres[j * 2 + 1]
            if not (isinstance(rr, str) and isinstance(bb, str)):
                e["note"] = "reverify read failed; unverified"
                kept.append(e)
                continue
            h = rr[2:] if rr.startswith("0x") else rr
            if len(h) < 128:
                e["note"] = "reverify bad return; unverified"
                kept.append(e)
                continue
            r_side = int(h[0:64], 16) if e["side"] == "0" else int(h[64:128], 16)
            bal = dec_u(bb)
            if bal is None:
                e["note"] = "reverify bad balance; unverified"
                kept.append(e)
                continue
            ex2 = bal - r_side
            e["verified"] = True
            e["reserve_raw_v"] = str(r_side); e["balance_raw_v"] = str(bal); e["excess_raw_v"] = str(ex2)
            e["excess_human"] = human(e["token"], ex2)
            e["excess_usd"] = (e["excess_human"] * e["price_usd"]) if (e["price_usd"] and e["excess_human"] is not None) else None
            if ex2 > 0:
                kept.append(e)
            else:
                e["note"] = "excess vanished on re-verify (block drift); dropped"
                dropped.append(e)
        excess = [e for e in kept]
        excess.sort(key=lambda x: (x["excess_usd"] or 0), reverse=True)
        out["excess_dropped"] = dropped
    out["excess"] = excess
    out["top_pairs"] = top[:30]
    out["unpriced_pairs"] = unpriced
    out["underwater_usd_est_all"] = round(underwater_all, 2)
    out["underwater_pairs_gt1k"] = underwater_pairs
    out["rpc_calls"] = rpc.calls
    out["rpc_errors"] = rpc.errors
    out["notes"].append(f"multicall3={'yes' if rpc.good and True else 'maybe'}; decimals_found={sum(1 for v in dec.values() if isinstance(v,int))}/{len(toks)}; prices_found={len(prices)}")
    print(f"[{tag}] done: excess_hits={len([e for e in excess if (e['excess_usd'] or 0) > 1])} "
          f"unpriced_pairs={unpriced} underwater_usd_est={round(underwater_all, 2)} rpc_calls={rpc.calls}", flush=True)
    return out, rpc

def main():
    proto_names = ONLY or list(PROTOCOLS.keys())
    total_excess_usd = 0.0
    idx = {}
    for name in proto_names:
        proto = PROTOCOLS.get(name)
        if not proto:
            print(f"unknown protocol {name}", flush=True)
            continue
        for dep in proto["deployments"]:
            try:
                out, rpc = enum_deployment(name, dep, idx)
            except Exception as e:
                out = {"protocol": name, "chain": dep["chain"], "factory": dep["factory"], "errors": [f"fatal: {e}"]}
            fn = OUT / f"bsc-forks_{name}_{dep['chain']}.json"
            fn.write_text(json.dumps(out, indent=1))
            print(f"[{name}/{dep['chain']}] wrote {fn}", flush=True)
            for e in out.get("excess", []):
                if (e.get("excess_usd") or 0) > 1:
                    total_excess_usd += e["excess_usd"]
    print(f"TOTAL excess_usd>1 across scanned: {round(total_excess_usd, 2)}", flush=True)

if __name__ == "__main__":
    main()
