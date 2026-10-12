#!/usr/bin/env python3
"""
ErgoDEX (Ergo) Phase-2 deep-dive — chain-native verification suite (READ-ONLY).

Runs against public endpoints only (no keys, no transactions):
  - explorer: https://api.ergoplatform.com/api/v1
  - public Ergo node: https://node.ergo.watch  (script compile + executeWithContext)

Produces ci-out/state.json, ci-out/eval_results.json, ci-out/arb.json, ci-out/summary.json
"""
import json, hashlib, math, os, re, sys, time, urllib.request

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "ci-out")
OUT = os.path.normpath(OUT)
os.makedirs(OUT, exist_ok=True)

EXPLORER = "https://api.ergoplatform.com/api/v1"
NODE = "https://node.ergo.watch"
N2T = "5vSUZRZbdVbnk4sJWjg2uhL94VZWRg4iatK9VgMChufzUgdihgvhR8yWSUEJKszzV7Vmi6K8hCyKTNhUaiP8p5ko6YEU9yfHpjVuXdQ4i5p4cRCzch6ZiqWrNukYjv7Vs5jvBwqg5hcEJ8u1eerr537YLWUoxxi1M4vQxuaCihzPKMt8NDXP4WcbN6mfNxxLZeGBvsHVvVmina5THaECosCWozKJFBnscjhpr3AJsdaL8evXAvPfEjGhVMoTKXAb2ZGGRmR8g1eZshaHmgTg2imSiaoXU5eiF3HvBnDuawaCtt674ikZ3oZdekqswcVPGMwqqUKVsGY4QuFeQoGwRkMqEYTdV2UDMMsfrjrBYQYKUBFMwsQGMNBL1VoY78aotXzdeqJCBVKbQdD3ZZWvukhSe4xrz8tcF3PoxpysDLt89boMqZJtGEHTV9UBTBEac6sDyQP693qT3nKaErN8TCXrJBUmHPqKozAg9bwxTqMYkpmb9iVKLSoJxG7MjAj72SRbcqQfNCVTztSwN3cRxSrVtz4p87jNFbVtFzhPg7UqDwNFTaasySCqM"
T2T = open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "analysis", "t2t_address.txt")).read().strip()

ALPH = '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz'
G = "0279be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798"
P2PK = "0008cd" + G
Z32 = "00" * 32
POOL_SRC = open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "analysis", "contracts", "Pool_backend_n2t.sc")).read()


def get(url, timeout=60, tries=3):
    last = None
    for _ in range(tries):
        try:
            req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0 (read-only research)'})
            with urllib.request.urlopen(req, timeout=timeout) as r:
                return json.loads(r.read().decode())
        except Exception as e:  # noqa
            last = e
            time.sleep(2)
    raise last


def b58encode(b):
    n = int.from_bytes(b, 'big')
    s = ''
    while n > 0:
        n, r = divmod(n, 58)
        s = ALPH[r] + s
    return '1' * (len(b) - len(b.lstrip(b'\x00'))) + s


def p2s_address(tree_hex):
    body = b'\x03' + bytes.fromhex(tree_hex)
    return b58encode(body + hashlib.blake2b(body, digest_size=32).digest()[:4])


def fetch_all_boxes(addr):
    """The address is actively traded, so boxes are recreated while paginating.
    Sweep in both directions (asc/desc by creationHeight) several times and take the union."""
    seen = {}
    for _pass in range(3):
        before = len(seen)
        for direction in ("asc", "desc"):
            offset = 0
            while True:
                r = get(f"{EXPLORER}/boxes/unspent/byAddress/{addr}?limit=100&offset={offset}"
                        f"&sortBy=creationHeight&sortDirection={direction}")
                for b in r['items']:
                    seen[b['boxId']] = b
                offset += 100
                if offset >= r['total'] or not r['items']:
                    break
                time.sleep(0.3)
        if len(seen) == before:  # stable
            break
        time.sleep(1.0)
    return list(seen.values())


# ---------------- context building for node /script/executeWithContext ----------------

def header(h):
    return {"id": Z32, "version": 2, "parentId": Z32, "adProofsRoot": Z32,
            "stateRoot": {"digest": "00" * 33, "treeFlags": 0, "keyLength": 32, "valueLength": None},
            "transactionsRoot": Z32, "timestamp": 1791762995019, "nBits": 1171875, "height": h,
            "extensionRoot": Z32, "minerPk": G, "powOnetimePk": G, "powNonce": "0000000000000000",
            "powDistance": 1, "votes": "000000", "unparsedBytes": "00"}


HEADERS = [header(1892569 - i) for i in range(10)]
PREHEADER = {"version": 2, "parentId": Z32, "timestamp": 1791762995019, "nBits": 1171875,
             "height": 1892569, "minerPk": G, "votes": "000000"}


def candidate(value, tree, assets=None, regs=None, creation=1892569):
    return {"value": value, "ergoTree": tree, "assets": assets or [],
            "creationHeight": creation, "additionalRegisters": regs or {}}


def make_ctx(self_box, other_boxes, outputs):
    inputs = [{"boxId": b["boxId"], "spendingProof": {"proofBytes": "", "extension": {}}}
              for b in [self_box] + other_boxes]
    return {"lastBlockUtxoRoot": {"digest": "00" * 33, "treeFlags": 0, "keyLength": 32, "valueLength": None},
            "headers": HEADERS, "preHeader": PREHEADER, "dataBoxes": [],
            "boxesToSpend": [self_box] + other_boxes,
            "spendingTransaction": {"inputs": inputs, "dataInputs": [], "outputs": outputs},
            "selfIndex": 0, "extension": {}, "validationSettings": "00000000",
            "costLimit": 1000000, "initCost": 0, "scriptVersion": 1}


def run_script(ctx, label):
    body = {"script": POOL_SRC, "namedConstants": {}, "treeVersion": 1, "context": ctx}
    req = urllib.request.Request(NODE + "/script/executeWithContext", data=json.dumps(body).encode(),
                                 headers={"Content-Type": "application/json",
                                          "User-Agent": "Mozilla/5.0 (read-only research)"})
    try:
        with urllib.request.urlopen(req, timeout=60) as r:
            res = json.loads(r.read().decode())
        cond = (res.get("value") or {}).get("condition")
        return {"label": label, "result": cond, "cost": res.get("cost"), "raw": res}
    except urllib.error.HTTPError as e:
        return {"label": label, "result": "ERROR", "detail": e.read().decode()[:200]}
    except Exception as e:  # noqa
        return {"label": label, "result": "ERROR", "detail": str(e)[:200]}


def node_box(boxid):
    return get(f"{NODE}/utxo/byId/{boxid}")


# ---------------- main ----------------

def main():
    info = get(f"{EXPLORER}/info")
    height = info['height']
    state = {"height": height, "generated_at_utc": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())}

    # --- live state: n2t + t2t ---
    for label, addr in (("n2t", N2T), ("t2t", T2T)):
        bal = get(f"{EXPLORER}/addresses/{addr}/balance/total")
        boxes = fetch_all_boxes(addr)
        state[label] = {
            "address": addr,
            "nanoErgs": bal['confirmed']['nanoErgs'],
            "token_entries": len(bal['confirmed']['tokens']),
            "unspent_boxes": len(boxes),
            "sum_box_values": sum(b['value'] for b in boxes),
        }
        with open(os.path.join(OUT, f"boxes_{label}.json"), "w") as f:
            json.dump(boxes, f)

    # classification + stuck boxes
    n2t_boxes = json.load(open(os.path.join(OUT, "boxes_n2t.json")))
    pools, anomalies = [], []
    for b in n2t_boxes:
        toks = b.get('assets') or []
        r4 = (b.get('additionalRegisters') or {}).get('R4', {}).get('renderedValue')
        if len(toks) == 3 and toks[0]['amount'] == 1 and r4 is not None:
            pools.append(b)
        else:
            anomalies.append(b)
    state["n2t_pools"] = len(pools)
    state["n2t_anomalies"] = len(anomalies)
    state["n2t_anomaly_erg"] = sum(b['value'] for b in anomalies) / 1e9
    with open(os.path.join(OUT, "anomalies.json"), "w") as f:
        json.dump([{"boxId": b['boxId'], "value": b['value'],
                    "assets": [{"tokenId": a['tokenId'], "amount": a['amount']} for a in (b.get('assets') or [])],
                    "regs": b.get('additionalRegisters')} for b in anomalies], f, indent=1)

    # --- evaluation suite on a live pool box ---
    pool = None
    for b in sorted(pools, key=lambda x: -x['value']):
        try:
            pool = node_box(b['boxId'])
            break
        except Exception:
            continue
    NFT = pool["assets"][0]["tokenId"]
    LP = pool["assets"][1]
    Y = pool["assets"][2]
    V0, L0, Y0 = pool["value"], LP["amount"], Y["amount"]
    S0 = 0x7fffffffffffffff - L0
    FEE = int(pool["additionalRegisters"]["R4"], 16) if False else int(pool["additionalRegisters"]["R4"][4:], 16) if False else None
    # R4 serialized as hex of SInt: decode zigzag VLQ
    def decode_int_const(hexstr):
        b = bytes.fromhex(hexstr)
        assert b[0] == 4
        n = 0
        shift = 0
        for byte in b[1:]:
            n |= (byte & 0x7f) << shift
            if not (byte & 0x80):
                break
            shift += 7
        return (n >> 1) ^ -(n & 1)
    FEE = decode_int_const(pool["additionalRegisters"]["R4"])
    state["eval_pool"] = {"boxId": pool["boxId"], "value": V0, "supplyLP": S0, "y": Y0, "fee": FEE}

    def succ(value, lp_amount, y_amount):
        return candidate(value, pool["ergoTree"],
                         [{"tokenId": NFT, "amount": 1},
                          {"tokenId": LP["tokenId"], "amount": lp_amount},
                          {"tokenId": Y["tokenId"], "amount": y_amount}],
                         {"R4": pool["additionalRegisters"]["R4"]})

    attacker = {"boxId": "11" * 32, "value": 1000000, "ergoTree": P2PK, "assets": [],
                "creationHeight": height, "additionalRegisters": {}, "transactionId": Z32, "index": 0}
    lpbox = {"boxId": "22" * 32, "value": 1000000, "ergoTree": P2PK,
             "assets": [{"tokenId": LP["tokenId"], "amount": 1000000}],
             "creationHeight": height, "additionalRegisters": {}, "transactionId": Z32, "index": 0}
    results = []
    dX = 1000000
    fairY = (Y0 * dX * FEE) // (V0 * 1000 + dX * FEE)
    results.append(run_script(make_ctx(pool, [attacker], [succ(V0 + dX, L0, Y0 - fairY),
                                                         candidate(1000000, P2PK, [{"tokenId": Y["tokenId"], "amount": fairY}])]),
                              "fair_swap_expect_true"))
    results.append(run_script(make_ctx(pool, [attacker], [succ(V0 + dX, L0, Y0 - fairY - 1),
                                                         candidate(1000000, P2PK, [{"tokenId": Y["tokenId"], "amount": fairY + 1}])]),
                              "unfair_swap_expect_false"))
    results.append(run_script(make_ctx(pool, [attacker], [succ(V0 + 1, L0, 1),
                                                         candidate(1000000, P2PK, [{"tokenId": Y["tokenId"], "amount": Y0 - 1}])]),
                              "drain_swap_expect_false"))
    results.append(run_script(make_ctx(pool, [attacker], [succ(V0 - 1000000, L0, Y0 - 1000),
                                                         candidate(1000000, P2PK, [{"tokenId": Y["tokenId"], "amount": 1000}])]),
                              "remove_both_expect_false"))
    selfLP = 1000000
    rx = (selfLP * V0) // S0
    ry = (selfLP * Y0) // S0
    results.append(run_script(make_ctx(pool, [lpbox], [succ(V0 - rx, L0 + selfLP, Y0 - ry),
                                                       candidate(1000000, P2PK, [{"tokenId": Y["tokenId"], "amount": ry}])]),
                              "fair_redeem_expect_true"))
    results.append(run_script(make_ctx(pool, [lpbox], [succ(V0 - rx - 1, L0 + selfLP, Y0 - ry),
                                                       candidate(1000000, P2PK, [{"tokenId": Y["tokenId"], "amount": ry}])]),
                              "over_redeem_x_expect_false"))
    results.append(run_script(make_ctx(pool, [lpbox], [succ(V0 - rx, L0 + selfLP, Y0 - ry - 1),
                                                       candidate(1000000, P2PK, [{"tokenId": Y["tokenId"], "amount": ry + 1}])]),
                              "over_redeem_y_expect_false"))
    dx2, dy2 = 1000000, 1000000000
    lpout = min((dx2 * S0) // V0, (dy2 * S0) // Y0)
    results.append(run_script(make_ctx(pool, [attacker], [succ(V0 + dx2, L0 - lpout, Y0 + dy2),
                                                         candidate(1000000, P2PK, [{"tokenId": LP["tokenId"], "amount": lpout}])]),
                              "fair_deposit_expect_true"))
    results.append(run_script(make_ctx(pool, [attacker], [succ(V0 + dx2, L0 - lpout - 1, Y0 + dy2),
                                                         candidate(1000000, P2PK, [{"tokenId": LP["tokenId"], "amount": lpout + 1}])]),
                              "over_mint_lp_expect_false"))
    results.append(run_script(make_ctx(pool, [attacker], [succ(V0, L0 - 1000000, Y0),
                                                         candidate(1000000, P2PK, [{"tokenId": LP["tokenId"], "amount": 1000000}])]),
                              "free_lp_expect_false"))
    # anomalous boxes: expect ERROR (unspendable)
    for a in anomalies[:4]:
        try:
            ab = node_box(a['boxId'])
        except Exception:
            continue
        succ_a = candidate(ab['value'], ab['ergoTree'],
                           [{"tokenId": t['tokenId'], "amount": t['amount']} for t in (ab.get('assets') or [])],
                           ab.get('additionalRegisters') or {})
        results.append(run_script(make_ctx(ab, [attacker], [succ_a, candidate(1000000, P2PK)]),
                                  f"anomaly_{a['boxId'][:10]}_expect_unspendable"))
    with open(os.path.join(OUT, "eval_results.json"), "w") as f:
        json.dump({"pool": pool["boxId"], "height": height, "results": results}, f, indent=1)

    # --- valuation ---
    prices = {}
    toks = get(f"{EXPLORER}/addresses/{N2T}/balance/total")['confirmed']['tokens']
    keys = ["ergo:" + t['tokenId'] for t in toks] + ["coingecko:ergo"]
    for i in range(0, len(keys), 30):
        try:
            r = get("https://coins.llama.fi/prices/current/" + ",".join(keys[i:i + 30]))
            prices.update(r.get('coins', {}))
        except Exception:
            pass
        time.sleep(0.2)
    p_erg = prices.get('coingecko:ergo', {}).get('price')
    token_usd = 0.0
    for t in toks:
        dec = t.get('decimals') or 0
        whole = t['amount'] / (10 ** dec) if dec else t['amount']
        p = prices.get("ergo:" + t['tokenId'], {}).get('price')
        if p:
            token_usd += whole * p
    erg_usd = state['n2t']['nanoErgs'] / 1e9 * (p_erg or 0)
    val = {"erg_price_usd": p_erg, "erg_usd": round(erg_usd, 2), "tokens_usd": round(token_usd, 2),
           "total_usd": round(erg_usd + token_usd, 2), "at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())}
    state["valuation_n2t"] = val

    # --- fee-aware arb table over priced pools ---
    bal_map = {t['tokenId']: t for t in toks}
    arb_rows = []
    for b in pools:
        fee = decode_int_const((b.get('additionalRegisters') or {}).get('R4', {}).get('serializedValue', '0400'))
        y = (b.get('assets') or [])[2]
        dec = bal_map.get(y['tokenId'], {}).get('decimals') or 0
        Y0b = y['amount'] / (10 ** dec) if dec else y['amount']
        py = prices.get("ergo:" + y['tokenId'], {}).get('price')
        if not py or not p_erg or Y0b <= 0 or b['value'] <= 0:
            continue
        m = py / p_erg * 1e9
        f = fee / 1000.0
        best1 = 0.0
        for i in range(1, 200):
            dY = Y0b * i / 200.0
            if dY >= Y0b:
                break
            dX = dY * b['value'] * 1000.0 / (fee * (Y0b - dY))
            best1 = max(best1, (dY * m - dX) / 1e9 * p_erg)
        arb_rows.append({"box": b['boxId'], "fee": fee, "usd": round(best1, 2)})
    arb_total = sum(r['usd'] for r in arb_rows)
    with open(os.path.join(OUT, "arb.json"), "w") as f:
        json.dump({"priced_pools": len(arb_rows), "total_buy_y_with_x_usd": round(arb_total, 2),
                   "rows": sorted(arb_rows, key=lambda r: -r['usd'])[:50]}, f, indent=1)

    summary = {"height": height, "n2t_usd": val['total_usd'], "n2t_pools": len(pools),
               "n2t_anomalies": len(anomalies), "arb_profit_usd": round(arb_total, 2),
               "eval": [{"label": r['label'], "result": r['result']} for r in results]}
    with open(os.path.join(OUT, "summary.json"), "w") as f:
        json.dump(summary, f, indent=1)
    with open(os.path.join(OUT, "state.json"), "w") as f:
        json.dump(state, f, indent=1)
    print(json.dumps(summary, indent=1))
    print("\nEval detail:")
    for r in results:
        print(f"  {r['label']:44} -> {r['result']}  {r.get('detail','')[:80]}")


if __name__ == "__main__":
    main()
