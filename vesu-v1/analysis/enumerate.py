#!/usr/bin/env python3
"""
C2-50 Vesu V1.1 — full enumeration + gate proofs (read-only).

Modes:
  events      : enumerate singleton events (CreatePool/ModifyPosition/TransferPosition/
                LiquidatePosition/MigratePosition) over the full block range, chunked.
  positions   : build candidate positions (any position that ever borrowed/received debt,
                was liquidated, or appeared in a pool) and batch-check collateralization.
  liquidations: for undercollateralized positions, compute liquidation economics using
                the live extension configs + Pragma prices (same formula as the contract).
  pools       : per-pool asset reserves/debt snapshot vs singleton balances.
  gates       : simulateTransactions gate proofs (ownership gate, extension gate,
                owner gate) from real deployed accounts with SKIP_VALIDATE.

Outputs JSON/JSONL files to $CI_OUT (default: ../ci-out when run from analysis/, else ./).
No secrets, read-only.
"""
import json
import os
import sys
import time
import argparse

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from vesu_rpc import (  # noqa: E402
    DEFAULT_RPC, call_view, erc20_balance, get_events, get_block_number, get_class_hash_at,
    hexify, rpc, selector, starknet_keccak, to_int, u256_from_felts,
)

V11 = "0x000d8d6dfec4d33bfb6895de9f3852143a17c6f92fd2a21da3d6924d34870160"
V10 = "0x2545b2e5d519fc230e9cd781046d3a64e092114f07e44771e0d719d148725ef"
EXT = "0x4e06e04b8d624d039aa1c3ca8e0aa9e21dc1ccba1d88d0d650837159e0ee054"
DEPLOY_BLOCK = 1439949

ASSETS = {
    "USDC": "0x053c91253bc9682c04929ca02ed00b3e423f6710d2ee7e0d5ebb06f3ecf368a8",
    "USDT": "0x068f5c6a61780768455de69077e07e89787839bf8166decfbf92b645209c0fb8",
    "ETH": "0x049d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7",
    "wBTC": "0x03fe2b97c1fd336e750087d68b9b867997fd64a2661ff3ca5a7c771641e8e7ac",
    "STRK": "0x04718f5a0fc34cc1af16a1cdee98ffb20c31f5cd61d6ab07201858f4287c938d",
    "wstETH": "0x0057912720381af14b0e5c87aa4718ed5e527eab60b3801ebf702ab09139e38b",
    "wstETH_legacy": "0x042b8f0484674ca266ac5d08e4ac6a3fe65bd3129795def2dca5c34ecc5f96d2",
    "xSTRK": "0x028d709c875c0ceac3dce7065bec5328186dc89fe254527084d1689910954b0a",
    "sSTRK": "0x0356f304b154d29d2a8fe22f1cb9107a9b564a733cf6b4cc47fd121ac1af90c9",
    "rUSDC": "0x02019e47a0bc54ea6b4853c6123ffc8158ea3ae2af4166928b0de6e89f06de6c",
    "EKUBO": "0x075afe6402ad5a5c20dd25e10ec3b3986acaa647b77e4ae24b0cbc9a54a27a87",
    "DOG": "0x040e81cfeb176bfdbc5047bbc55eb471cfab20a6b221f38d8fda134e1bfffca4",
}
ASSET_BY_ADDR = {int(v, 16): k for k, v in ASSETS.items()}

EVENT_TYPES = ["CreatePool", "ModifyPosition", "TransferPosition", "LiquidatePosition",
               "MigratePosition", "SetExtension"]
EVENT_TYPES_V10 = ["ModifyPosition", "TransferPosition", "LiquidatePosition"]
V10_DEPLOY_BLOCK = 654244

OUTDIR = os.environ.get("CI_OUT") or os.path.join(HERE, "..", "ci-out")
if not os.path.isabs(OUTDIR):
    OUTDIR = os.path.abspath(OUTDIR)
os.makedirs(OUTDIR, exist_ok=True)


def log(*a):
    print(*a, flush=True)


# ---------------------------------------------------------------------------
# mode: events
# ---------------------------------------------------------------------------
def mode_events(args):
    t0 = time.time()
    latest = args.to_block or get_block_number()
    window = args.window
    sels = {selector(t): t for t in EVENT_TYPES}
    out_path = os.path.join(OUTDIR, "events.jsonl")
    n = 0
    with open(out_path, "w") as f:
        for sel, name in sels.items():
            b = args.from_block
            while b <= latest:
                e = min(b + window - 1, latest)
                cont = None
                while True:
                    r = get_events(b, e, address=V11, keys=[[sel]], chunk_size=1000, continuation=cont)
                    if not isinstance(r, dict) or "events" not in r:
                        log(f"[events] {name} {b}-{e} error: {json.dumps(r)[:200]}")
                        break
                    evs = r["events"]
                    for ev in evs:
                        ev["_type"] = name
                        f.write(json.dumps(ev) + "\n")
                    n += len(evs)
                    cont = r.get("continuation_token")
                    if not cont or not evs:
                        break
                log(f"[events] {name} {b}-{e}: cumulative {n} ({time.time()-t0:.0f}s)")
                b = e + 1
    log(f"[events] wrote {n} events to {out_path}")
    return out_path


def mode_events_v10(args):
    """Enumerate events from the deprecated V1.0 singleton (positions still resident there)."""
    t0 = time.time()
    latest = args.to_block or (DEPLOY_BLOCK - 1)
    window = args.window
    sels = {selector(t): t for t in EVENT_TYPES_V10}
    out_path = os.path.join(OUTDIR, "events_v10.jsonl")
    n = 0
    with open(out_path, "w") as f:
        for sel, name in sels.items():
            b = args.from_block if args.from_block != DEPLOY_BLOCK else V10_DEPLOY_BLOCK
            while b <= latest:
                e = min(b + window - 1, latest)
                cont = None
                while True:
                    r = get_events(b, e, address=V10, keys=[[sel]], chunk_size=1000, continuation=cont)
                    if not isinstance(r, dict) or "events" not in r:
                        log(f"[events-v10] {name} {b}-{e} error: {json.dumps(r)[:200]}")
                        break
                    evs = r["events"]
                    for ev in evs:
                        ev["_type"] = name
                        f.write(json.dumps(ev) + "\n")
                    n += len(evs)
                    cont = r.get("continuation_token")
                    if not cont or not evs:
                        break
                log(f"[events-v10] {name} {b}-{e}: cumulative {n} ({time.time()-t0:.0f}s)")
                b = e + 1
    log(f"[events-v10] wrote {n} events to {out_path}")
    return out_path


def _i257(d, i):
    abs_ = to_int(d[i]) + (to_int(d[i + 1]) << 128)
    return -abs_ if to_int(d[i + 2]) else abs_


def mode_events_decode(args):
    """Decode events.jsonl (+ events_v10.jsonl if present) -> positions.jsonl candidates + pools.json."""
    src_files = [os.path.join(OUTDIR, "events.jsonl")]
    if os.path.exists(os.path.join(OUTDIR, "events_v10.jsonl")):
        src_files.append(os.path.join(OUTDIR, "events_v10.jsonl"))
    pools = {}
    candidates = set()
    liquidations = []
    n = 0
    for src in src_files:
        with open(src) as f:
            for line in f:
                n += 1
                ev = json.loads(line)
                t = ev["_type"]
                k = ev["keys"]
                d = ev["data"]
                if t == "CreatePool":
                    pools[k[1]] = {"extension": k[2], "creator": k[3], "block": ev["block_number"]}
                elif t == "ModifyPosition":
                    pool, coll, debt, user = k[1], k[2], k[3], k[4]
                    nd = _i257(d, 9) if len(d) >= 12 else 0
                    cs = _i257(d, 3) if len(d) >= 12 else 0
                    if nd > 0 or cs > 0:
                        candidates.add((pool, coll, debt, user))
                elif t == "TransferPosition":
                    # keys: sel,pool,from_coll,from_debt,to_coll,to_debt,from_user,to_user
                    pool = k[1]
                    fc, fd, tc, td, fu, tu = k[2], k[3], k[4], k[5], k[6], k[7]
                    # data: coll_delta(3), coll_shares(3), debt_delta(3), nominal_debt(3) [V1.0 has no data]
                    if len(d) >= 12:
                        nd = _i257(d, 9)
                        if nd > 0:
                            candidates.add((pool, tc, td, tu))
                        if nd != 0:
                            candidates.add((pool, fc, fd, fu))
                    else:
                        # no deltas in V1.0 event: register both sides conservatively
                        candidates.add((pool, tc, td, tu))
                        candidates.add((pool, fc, fd, fu))
                elif t == "LiquidatePosition":
                    pool, coll, debt, user, liquidator = k[1], k[2], k[3], k[4], k[5]
                    candidates.add((pool, coll, debt, user))
                    liquidations.append({"pool": pool, "coll": coll, "debt": debt, "user": user,
                                         "liquidator": liquidator, "block": ev["block_number"]})
    out_pos = os.path.join(OUTDIR, "candidates.jsonl")
    with open(out_pos, "w") as f:
        for c in sorted(candidates):
            f.write(json.dumps(list(c)) + "\n")
    with open(os.path.join(OUTDIR, "pools.json"), "w") as f:
        json.dump(pools, f, indent=2)
    with open(os.path.join(OUTDIR, "liquidations.jsonl"), "w") as f:
        for l in liquidations:
            f.write(json.dumps(l) + "\n")
    log(f"[decode] {n} events -> {len(candidates)} candidate positions, {len(pools)} pools, {len(liquidations)} liquidations")


# ---------------------------------------------------------------------------
# batched JSON-RPC
# ---------------------------------------------------------------------------
def rpc_batch(calls, url=None, retries=3, timeout=60):
    """calls: list of (method, params). Returns list of results (or {'error':...})."""
    url = url or DEFAULT_RPC
    payload = [{"jsonrpc": "2.0", "id": i, "method": m, "params": p} for i, (m, p) in enumerate(calls)]
    import urllib.request
    last = None
    for attempt in range(retries):
        try:
            req = urllib.request.Request(url, data=json.dumps(payload).encode(),
                                         headers={"Content-Type": "application/json",
                                                  "User-Agent": "Mozilla/5.0 (research; read-only)"})
            with urllib.request.urlopen(req, timeout=timeout) as resp:
                body = json.loads(resp.read().decode())
            if isinstance(body, dict):
                raise RuntimeError(str(body)[:200])
            out = [None] * len(calls)
            for item in body:
                out[item["id"]] = item.get("result", {"error": item.get("error")})
            return out
        except Exception as ex:  # noqa: BLE001
            last = ex
            time.sleep(1.5 * (attempt + 1))
    return [{"error": f"transport: {last}"}] * len(calls)


def call_params(to, func, calldata):
    return {"request": {"contract_address": hexify(to), "entry_point_selector": selector(func),
                        "calldata": [hexify(x) for x in calldata]}, "block_id": "latest"}


def mode_positions(args):
    cands = [tuple(json.loads(l)) for l in open(os.path.join(OUTDIR, "candidates.jsonl"))]
    log(f"[positions] {len(cands)} candidates")
    out_path = os.path.join(OUTDIR, "positions.jsonl")
    interesting = 0
    B = 200
    with open(out_path, "w") as f:
        for i in range(0, len(cands), B):
            chunk = cands[i:i + B]
            calls = []
            for (pool, coll, debt, user) in chunk:
                calls.append(("starknet_call", call_params(V11, "check_collateralization_unsafe",
                                                           [pool, coll, debt, user])))
            res = rpc_batch(calls)
            for (pool, coll, debt, user), r in zip(chunk, res):
                rec = {"pool": pool, "coll": coll, "debt": debt, "user": user}
                if isinstance(r, list) and len(r) >= 5:
                    collat = to_int(r[0]) == 1
                    cv = u256_from_felts(r, 1)
                    dv = u256_from_felts(r, 3)
                    rec.update({"collateralized": collat, "collateral_value": str(cv), "debt_value": str(dv)})
                    if not collat or dv > 0:
                        interesting += 1
                else:
                    rec["error"] = r if not isinstance(r, list) else r
                f.write(json.dumps(rec) + "\n")
            if (i // B) % 10 == 0:
                log(f"[positions] {i+len(chunk)}/{len(cands)} (interesting {interesting})")
    log(f"[positions] wrote {out_path}; {interesting} rows with debt or undercollateralized")


# ---------------------------------------------------------------------------
# mode: liquidations economics
# ---------------------------------------------------------------------------
SCALE = 10 ** 18


def mode_liquidations(args):
    rows = [json.loads(l) for l in open(os.path.join(OUTDIR, "positions.jsonl"))]
    under = [r for r in rows if r.get("collateralized") is False and int(r.get("debt_value", 0)) > 0]
    log(f"[liq] undercollateralized positions with debt: {len(under)}")
    out = []
    for r in under:
        pool, coll, debt, user = r["pool"], r["coll"], r["debt"], r["user"]
        # read position details + extension liquidation config + prices
        calls = [
            ("starknet_call", call_params(V11, "position_unsafe", [pool, coll, debt, user])),
            ("starknet_call", call_params(EXT, "liquidation_config", [pool, coll, debt])),
            ("starknet_call", call_params(EXT, "price", [pool, coll])),
            ("starknet_call", call_params(EXT, "price", [pool, debt])),
            ("starknet_call", call_params(V11, "asset_config_unsafe", [pool, coll])),
            ("starknet_call", call_params(V11, "asset_config_unsafe", [pool, debt])),
        ]
        res = rpc_batch(calls)
        rec = dict(r)
        rec["raw"] = res
        try:
            pos = res[0]
            liq = res[1]
            pcoll = res[2]
            pdebt = res[3]
            cfg_coll = res[4]
            cfg_debt = res[5]
            # liquidation_factor is u64 in first felt of LiquidationConfig
            lf = to_int(liq[0]) if isinstance(liq, list) and liq else 0
            if lf == 0:
                lf = SCALE
            price_coll = u256_from_felts(pcoll) if isinstance(pcoll, list) else 0
            price_debt = u256_from_felts(pdebt) if isinstance(pdebt, list) else 0
            scale_coll = u256_from_felts(cfg_coll, 10) if isinstance(cfg_coll, list) and len(cfg_coll) >= 12 else 10 ** 18
            scale_debt = u256_from_felts(cfg_debt, 10) if isinstance(cfg_debt, list) and len(cfg_debt) >= 12 else 10 ** 18
            cv = int(r["collateral_value"])          # USD18
            dv = int(r["debt_value"])                # USD18
            # Reproduce before_liquidate_position with debt_to_repay = full debt:
            #   collateral_to_receive = dv/lf capped by collateral (USD terms)
            #   if cv*lf < dv: bad debt -> liquidator pays dv - (dv - cv*lf) = cv*lf
            #   else:          liquidator pays dv (no bad debt) and receives dv/lf
            cv_after_lf = cv * lf // SCALE
            if cv_after_lf < dv:
                bad_debt_usd = dv - cv_after_lf
                pay_usd = dv - bad_debt_usd          # = cv*lf
                receive_usd = cv                     # all collateral
            else:
                bad_debt_usd = 0
                pay_usd = dv
                receive_usd = min(cv, dv * SCALE // lf)
            profit_usd = receive_usd - pay_usd
            rec.update({
                "liquidation_factor": str(lf),
                "price_coll": str(price_coll),
                "price_debt": str(price_debt),
                "scale_coll": str(scale_coll),
                "scale_debt": str(scale_debt),
                "bad_debt_usd18": str(bad_debt_usd),
                "pay_usd18": str(pay_usd),
                "receive_usd18": str(receive_usd),
                "profit_usd18": str(profit_usd),
            })
        except Exception as ex:  # noqa: BLE001
            rec["error"] = str(ex)
        out.append(rec)
        log(f"[liq] {user[:12]}.. pool {pool[:10]}.. profit_usd18={rec.get('profit_usd18')}")
    with open(os.path.join(OUTDIR, "liquidation_econ.json"), "w") as f:
        json.dump(out, f, indent=2)
    log(f"[liq] wrote liquidation_econ.json ({len(out)} rows)")


# ---------------------------------------------------------------------------
# mode: pools snapshot
# ---------------------------------------------------------------------------
def mode_pools(args):
    pools = json.load(open(os.path.join(OUTDIR, "pools.json")))
    out = {}
    for pid, meta in pools.items():
        out[pid] = {"extension": meta["extension"], "assets": {}}
        for aname, aaddr in ASSETS.items():
            calls = [("starknet_call", call_params(V11, "asset_config_unsafe", [pid, aaddr]))]
            r = rpc_batch(calls)[0]
            if isinstance(r, list) and len(r) >= 8:
                # asset_config_unsafe returns (AssetConfig, fee_shares): AssetConfig has 10 u256 fields?
                # Serde: total_collateral_shares(2), total_nominal_debt(2), reserve(2), max_utilization(2),
                # floor(2), scale(2), is_legacy(1), last_updated(1), last_rate_accumulator(2),
                # last_full_utilization_rate(2), fee_rate(2) = 20 felts; then fee_shares(2)
                cfg = {
                    "total_collateral_shares": str(u256_from_felts(r, 0)),
                    "total_nominal_debt": str(u256_from_felts(r, 2)),
                    "reserve": str(u256_from_felts(r, 4)),
                    "max_utilization": str(u256_from_felts(r, 6)),
                    "floor": str(u256_from_felts(r, 8)),
                    "scale": str(u256_from_felts(r, 10)),
                    "is_legacy": to_int(r[12]),
                    "last_updated": to_int(r[13]),
                    "last_rate_accumulator": str(u256_from_felts(r, 14)),
                    "fee_rate": str(u256_from_felts(r, 18)),
                    "fee_shares": str(u256_from_felts(r, 20)) if len(r) >= 22 else None,
                }
                if int(cfg["last_rate_accumulator"]) != 0:
                    out[pid]["assets"][aname] = cfg
    with open(os.path.join(OUTDIR, "pools_snapshot.json"), "w") as f:
        json.dump(out, f, indent=2)
    log(f"[pools] wrote pools_snapshot.json for {len(out)} pools")


# ---------------------------------------------------------------------------
# mode: gate proofs via simulateTransactions
# ---------------------------------------------------------------------------
def _invoke_calldata_oz(calls):
    """Encode __execute__ calldata for an OpenZeppelin-style account: Array<Call>."""
    out = [hexify(len(calls))]
    for (to, sel, calldata) in calls:
        out.append(hexify(to))
        out.append(hexify(sel))
        out.append(hexify(len(calldata)))
        out.extend(hexify(c) for c in calldata)
    return out


def simulate_from(sender, calls, nonce=None, flags=("SKIP_VALIDATE",)):
    if nonce is None:
        n = rpc("starknet_getNonce", {"block_id": "latest", "contract_address": hexify(sender)})
        nonce = n if isinstance(n, str) else "0x0"
    tx = {
        "type": "INVOKE", "version": "0x3", "sender_address": hexify(sender),
        "calldata": _invoke_calldata_oz(calls),
        "signature": [], "nonce": nonce,
        "resource_bounds": {
            "l1_gas": {"max_amount": "0x186a0", "max_price_per_unit": "0x110d9316ec000"},   # 100k x 3e14
            "l2_gas": {"max_amount": "0x11e1a300", "max_price_per_unit": "0x174876e800"},   # 300M x 1e11
            "l1_data_gas": {"max_amount": "0x2710", "max_price_per_unit": "0x174876e800"},  # 10k x 1e11
        },
        "tip": "0x0", "paymaster_data": [], "account_deployment_data": [],
        "nonce_data_availability_mode": "L1", "fee_data_availability_mode": "L1",
    }
    return rpc("starknet_simulateTransactions", {"block_id": "latest", "transactions": [tx],
                                                 "simulation_flags": list(flags)}, timeout=60)


def mode_gates(args):
    cfg = json.load(open(args.config)) if args.config else {}
    victim = cfg.get("victim")
    attacker = cfg["attacker"]       # deployed account used as the attacker
    pool = cfg.get("pool")
    coll = cfg.get("coll")
    debt = cfg.get("debt")
    shares = int(cfg.get("shares", 10 ** 18))
    pool_attacker = cfg.get("pool_attacker", pool)

    if cfg.get("auto"):
        rows = [json.loads(l) for l in open(os.path.join(OUTDIR, "positions.jsonl"))]
        rows = [r for r in rows if "error" not in r and int(r.get("collateral_value", 0)) > 0
                and r.get("debt", "0x0") not in ("0x0", 0, None)]
        with_debt = [r for r in rows if int(r.get("debt_value", 0)) > 0 and r.get("collateralized")]
        if with_debt:
            top = max(with_debt, key=lambda r: int(r["debt_value"]))
        else:
            top = max(rows, key=lambda r: int(r["collateral_value"]))
        victim, pool, coll, debt = top["user"], top["pool"], top["coll"], top["debt"]
        log(f"[gates] auto victim: {victim} pool {pool} coll {coll} debt {debt}")

    # pick asset with the largest extension fee position for the unwrap test
    ext_asset = coll
    best = -1
    for a in ASSETS.values():
        r = call_view(V11, "position_unsafe", [pool, a, 0, EXT])
        if isinstance(r, list) and len(r) >= 4:
            cs = u256_from_felts(r, 0)
            if cs > best:
                best = cs
                ext_asset = a
    log(f"[gates] extension asset for unwrap test: {ext_asset} shares={best}")

    out = {"_meta": {"block": get_block_number(), "attacker": attacker, "victim": victim,
                     "pool": pool, "coll": coll, "debt": debt, "ext_asset": ext_asset,
                     "ext_shares": str(best)}}

    def enc_amount(amount_type, denom, value, negative):
        return [amount_type, denom, value & ((1 << 128) - 1), value >> 128, 1 if negative else 0]

    def enc_uamount(amount_type, denom, value):
        return [amount_type, denom, value & ((1 << 128) - 1), value >> 128]

    # 1) attacker tries to withdraw victim's collateral -> expect no-delegation
    mp = [pool, coll, debt, victim,
          *enc_amount(0, 0, shares, True),   # collateral: Delta/Native/-shares
          *enc_amount(0, 0, 0, False),       # debt: zero
          0]                                  # empty data
    out["attacker_withdraw_victim"] = simulate_from(attacker, [(V11, selector("modify_position"), mp)])

    # 2) attacker tries to transfer victim's collateral to self -> expect no-delegation
    tp = [pool, coll, debt, coll, debt, victim, attacker,
          *enc_uamount(0, 0, shares),   # collateral positive (UnsignedAmount)
          *enc_uamount(0, 0, 0),        # debt zero
          0, 0]
    out["attacker_transfer_victim"] = simulate_from(attacker, [(V11, selector("transfer_position"), tp)])

    # 3) attacker calls set_extension_whitelist -> expect owner error
    out["attacker_whitelist"] = simulate_from(attacker, [
        (V11, selector("set_extension_whitelist"), [attacker, 1])])

    # 4) attacker calls retrieve_from_reserve -> caller-not-extension
    out["attacker_retrieve"] = simulate_from(attacker, [
        (V11, selector("retrieve_from_reserve"), [pool, coll, attacker, 1, 0])])

    # 5) attacker calls upgrade -> owner error
    out["attacker_upgrade"] = simulate_from(attacker, [
        (V11, selector("upgrade"), ["0x1"])])

    # 6) attacker calls liquidate_position on victim (if victim has debt)
    liq_data = [0, 0, 0, 0]  # min_collateral_to_receive=0 (u256), debt_to_repay=0 (u256)
    lp = [pool, coll, debt, victim, 0, len(liq_data), *liq_data]
    out["attacker_liquidate_victim"] = simulate_from(attacker, [(V11, selector("liquidate_position"), lp)])

    # 7) attacker modifies own position: deposit 1 unit (allowed, no ownership needed)
    mp_self = [pool_attacker, coll, debt, attacker,
               *enc_amount(0, 0, 1, False), *enc_amount(0, 0, 0, False), 0]
    out["attacker_deposit_self"] = simulate_from(attacker, [(V11, selector("modify_position"), mp_self)])

    # 8) attacker calls donate_to_reserve (permissionless, adds value; amount 0 = pure gate check)
    out["attacker_donate"] = simulate_from(attacker, [
        (V11, selector("donate_to_reserve"), [pool, coll, 0, 0])])

    # 9) attacker tries to pull fee shares out of the extension's vToken position (unwrap without vTokens)
    tp_ext = [pool, ext_asset, 0, ext_asset, 0, EXT, attacker,
              *enc_uamount(0, 0, 10 ** 16),   # 0.01 shares
              *enc_uamount(0, 0, 0),
              0, 0]
    out["attacker_unwrap_extension"] = simulate_from(attacker, [(V11, selector("transfer_position"), tp_ext)])

    # 10) positive control: permissionless self-delegation must succeed
    out["attacker_delegate_self"] = simulate_from(attacker, [
        (V11, selector("modify_delegation"), [pool, attacker, 1])])

    # 11) attacker calls extension upgrade -> expect singleton-owner gate
    out["attacker_ext_upgrade"] = simulate_from(attacker, [
        (EXT, selector("upgrade"), ["0x1"])])

    # 12) attacker calls singleton migrate_position -> expect caller-not-migrator
    out["attacker_migrate_position"] = simulate_from(attacker, [
        (V11, selector("migrate_position"), [pool, coll, debt, attacker, attacker])])

    # 13) LIVE liquidation proof: if an undercollateralized position exists, execute it in simulation
    live = {}
    try:
        rows = [json.loads(l) for l in open(os.path.join(OUTDIR, "positions.jsonl"))]
        under = [r for r in rows if r.get("collateralized") is False and int(r.get("debt_value", 0)) > 0]
        liquidator = cfg.get("liquidator")
        if under and liquidator:
            t = max(under, key=lambda r: int(r.get("collateral_value", 0)))
            pos = call_view(V11, "position", [t["pool"], t["coll"], t["debt"], t["user"]])
            debt_units = u256_from_felts(pos, 6) if isinstance(pos, list) and len(pos) >= 8 else 0
            bal = erc20_balance(t["debt"], liquidator)
            live = {"position": t, "liquidator": liquidator, "liquidator_debt_balance": str(bal),
                    "debt_units": str(debt_units)}

            def u256(v):
                return [v & ((1 << 128) - 1), v >> 128]

            sim = simulate_from(liquidator, [
                (t["debt"], selector("approve"), [V11, *u256(max(debt_units, 1))]),
                (V11, selector("liquidate_position"),
                 [t["pool"], t["coll"], t["debt"], t["user"], 0, 4, *u256(0), *u256(10 ** 30)]),
            ])
            if isinstance(sim, dict) and "error" in sim:
                live["simulation"] = "RPC_ERROR: " + json.dumps(sim["error"])[:200]
            else:
                def walk(node):
                    yield node
                    for c in node.get("calls", []) or []:
                        yield from walk(c)
                transfers = []
                bad_debt = None
                rr = None
                fee = None
                for item in sim:
                    ei = item.get("transaction_trace", {}).get("execute_invocation", {})
                    rr = ei.get("revert_reason")
                    fee = item.get("fee_estimation")
                    for node in walk(ei):
                        for e in node.get("events", []) or []:
                            ks = e.get("keys", [])
                            d = e.get("data", [])
                            if ks and ks[0] == "0x99cd8bde557814842a3121e8ddfd433a539b8c9f14bf31ebf108d12e6196e9":
                                # Cairo 0 legacy: keys=[sel, from, to], data=[amount_low, amount_high]
                                if len(ks) >= 3 and len(d) >= 2:
                                    transfers.append({"token": node.get("contract_address"),
                                                      "from": ks[1], "to": ks[2],
                                                      "amount": str(int(d[0], 16) + (int(d[1], 16) << 128))})
                                # Cairo 1: keys=[sel], data=[from, to, amount_low, amount_high]
                                elif len(d) >= 4:
                                    transfers.append({"token": node.get("contract_address"),
                                                      "from": d[0], "to": d[1],
                                                      "amount": str(int(d[2], 16) + (int(d[3], 16) << 128))})
                            if ks and ks[0] == "0x3731bef77d4371d61d696ce475c60d128c4e2c7bba44336635a540d6b180e88" and len(d) >= 14:
                                bad_debt = str(int(d[12], 16) + (int(d[13], 16) << 128))
                live.update({"revert": rr, "transfers": transfers, "bad_debt": bad_debt, "fee_estimation": fee})
        else:
            live = {"note": "no undercollateralized position found or no liquidator configured"}
    except Exception as ex:  # noqa: BLE001
        live = {"error": str(ex)}
    out["live_liquidation"] = live

    with open(os.path.join(OUTDIR, "gate_proofs.json"), "w") as f:
        json.dump(out, f, indent=2)

    def _verdict(v):
        if isinstance(v, dict) and "error" in v:
            return "RPC_ERROR: " + json.dumps(v["error"])[:160]
        if isinstance(v, list):
            for item in v:
                rr = (item.get("transaction_trace", {}).get("execute_invocation", {}) or {}).get("revert_reason")
                if rr:
                    known = ["no-delegation", "caller-not-extension", "Caller is not the owner",
                             "not-undercollateralized", "u256_sub Overflow", "extension-not-whitelisted",
                             "caller-not-migrator", "in-recovery", "in-subscription", "in-redemption",
                             "less-than-min-collateral", "transfer-failed", "dusty"]
                    for k in known:
                        if k in rr:
                            return "REVERT: " + k
                    import re
                    ms = re.findall(r'"([^"]+)"', rr)
                    return "REVERT: " + (ms[-1] if ms else rr[-160:].replace("\n", " "))
            return "SUCCESS"
        return json.dumps(v)[:120]

    for k, v in out.items():
        log(f"[gates] {k}: {_verdict(v)}")
    log(f"[gates] wrote gate_proofs.json")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("mode", choices=["events", "events-v10", "decode", "positions", "liquidations",
                                     "pools", "gates"])
    ap.add_argument("--window", type=int, default=500000)
    ap.add_argument("--from-block", type=int, default=DEPLOY_BLOCK)
    ap.add_argument("--to-block", type=int, default=0)
    ap.add_argument("--config", default=None)
    args = ap.parse_args()
    {"events": mode_events, "events-v10": mode_events_v10, "decode": mode_events_decode,
     "positions": mode_positions, "liquidations": mode_liquidations, "pools": mode_pools,
     "gates": mode_gates}[args.mode](args)


if __name__ == "__main__":
    main()
