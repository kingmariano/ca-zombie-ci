#!/usr/bin/env python3
"""Read BRLMasterChef pool state: lpSupplies, MC token balances, pool lpToken identity."""
import json
import os
import time
import urllib.request

RPC = os.environ.get("AURORA_RPC", "https://mainnet.aurora.dev")
MC = "0x35CC71888DBb9FfB777337324a4A60fdBAA19DDE"
BRL = "0x12c87331f086c3c926248f964f8702c0842fd77f"
BASE = os.path.dirname(__file__)

SEL = {"balanceOf": "0x70a08231", "symbol": "0x95d89b41", "decimals": "0x313ce567", "totalSupply": "0x18160ddd"}


def rpc(method, params):
    payload = {"jsonrpc": "2.0", "id": 1, "method": method, "params": params}
    req = urllib.request.Request(RPC, data=json.dumps(payload).encode(),
                                 headers={"Content-Type": "application/json", "User-Agent": "Mozilla/5.0"})
    for a in range(5):
        try:
            with urllib.request.urlopen(req, timeout=40) as r:
                out = json.load(r)
            if "result" in out:
                return out["result"]
        except Exception:  # noqa: BLE001
            pass
        time.sleep(1 + 2 * a)
    return None


def call(to, data, block="latest"):
    return rpc("eth_call", [{"to": to, "data": data}, block])


def batch(calls, block="latest", chunk=50):
    res = []
    for i in range(0, len(calls), chunk):
        part = calls[i : i + chunk]
        payload = [{"jsonrpc": "2.0", "id": j, "method": "eth_call",
                    "params": [{"to": t, "data": d}, block]} for j, (t, d) in enumerate(part)]
        req = urllib.request.Request(RPC, data=json.dumps(payload).encode(),
                                     headers={"Content-Type": "application/json", "User-Agent": "Mozilla/5.0"})
        out = None
        for a in range(5):
            try:
                with urllib.request.urlopen(req, timeout=60) as r:
                    out = json.load(r)
                break
            except Exception:  # noqa: BLE001
                time.sleep(1 + 2 * a)
        by_id = {it["id"]: it.get("result") for it in out}
        res.extend(by_id.get(j) for j in range(len(part)))
        time.sleep(0.15)
    return res


def first_word(h):
    return None if not h or h == "0x" else int(h[2:66], 16)


def dec_str(h):
    if not h or h == "0x" or len(h) < 130:
        return None
    b = bytes.fromhex(h[2:])
    try:
        off = int.from_bytes(b[0:32], "big")
        ln = int.from_bytes(b[off : off + 32], "big")
        return b[off + 32 : off + 32 + ln].decode("utf-8", "replace")
    except Exception:  # noqa: BLE001
        return None


def main():
    block = int(rpc("eth_blockNumber", []), 16)
    print("block", block)
    # pools from the earlier read (hardcode for reproducibility)
    pools = [
        (0, "0x12c87331f086c3C926248f964f8702C0842Fd77F", 70),
        (1, "0xc57eCc341aE4df32442Cf80F34f41Dc1782fE067", 79),
        (2, "0xEc538fAfaFcBB625C394c35b11252cef732368cd", 65),
        (3, "0x480A68bA97d70495e80e11e05D59f6C659749F27", 106),
        (4, "0xF3DE9dc38f62608179c45fE8943a0cA34Ba9CEfc", 106),
        (5, "0xe11A3f2BAB372d88D133b64487D1772847Eec4eA", 17),
        (6, "0xcb8584360Dc7A4eAC4878b48fB857AA794E46Fa8", 18),
        (7, "0x388D5EE199aC8dAD049B161b57487271Cd787941", 5),
        (8, "0x729dB9dB6d3cA82EF7e4c886C352749758BaD0eb", 8),
        (9, "0x314ab6AaeE15424ea8De07e2007646EcF3772357", 2),
        (10, "0x1C393468D95ADF8960E64939bCDd6eE602DE221C", 1),
        (11, "0x8F6e13B3D28B09535EB82BE539c1E4802B0c25B7", 1),
        (12, "0x8298B8C863c2213B9698A08de009cC0aB0F87FEe", 1),
        (13, "0x5BdAC608cd38C5C8738f5bE20813194A3150d4Ff", 190),
        (14, "0xEfCF518CA36DC3362F539965807b42A77DC26Be0", 110),
        (15, "0xDB0363ee28a5B40BDc2f4701e399c63E00f91Aa8", 51),
        (16, "0x84567E7511E0d97DE676d236AEa7aE688221799e", 9),
        (17, "0x892F67459b59ab867e2d73C7F2B696fDC6f69F34", 0),
        (18, "0x615f1240Ab636F7019c9816F1bE7119e73d78b88", 0),
        (19, "0x59a85DCB1f4Aa85232BAb95462de20993e48c620", 0),
        (20, "0x2eE60b9b898550a439622468C6AD65fBE726b7E0", 25),
        (21, "0xc6Fdc87759a8B56B8126a6f6864395A74Dc5Fb94", 1),
        (22, "0xb9636D074C3e8550449feba3be63fe95a582e876", 1),
        (23, "0xE24c7F50A9F514Db6Ccf151ff9a9411DE2110740", 1),
        (24, "0x2bB19e2F40FC2F8b6f9cC7d6066c51B05079a6b8", 1),
        (25, "0xD422A8EA35Acf115F41B5D941dC60507ED4F3792", 2),
        (26, "0x4f49eb288927293b4374F4a55ea668BC1c4cf310", 0),
        (27, "0xce3600a4d1Dd0acAC11C7EB827036597B9Ab91a7", 0),
        (28, "0x3866b969D2A3d1125A92244C2F8206E942f791F5", 0),
        (29, "0x43F43d76278C07f75c8be5d967165F7C148A0Be7", 2),
        (30, "0x4953b4EC9286e3fe600762Cd03edcC6A1034a543", 5),
        (31, "0xAfa14B4c0d8aF86cad6Ad5cbce9113685239346c", 12),
        (32, "0x4d48f0572fe4aE1C792137132aaDdfB852f7d3c1", 6),
        (33, "0xC51C887ac06A8fc3eA5036B581Ea19A619A89896", 100),
        (34, "0x24663dE1FE6972120f64Bea2882570A1E41354B3", 5),
        (35, "0x19185181EA1F59e1CAB83efd6BeeF6A9730603ee", 100000),
    ]
    calls = []
    for pid, lp, alloc in pools:
        calls.append((lp, SEL["balanceOf"] + lp.lower().replace("0x", "").rjust(64, "0")))
    res = batch(calls, hex(block))
    out = []
    for (pid, lp, alloc), r in zip(pools, res):
        out.append({"pid": pid, "lpToken": lp, "allocPoint": alloc, "lpSupply": first_word(r)})
    json.dump(out, open(os.path.join(BASE, "mc_pools_supply.json"), "w"), indent=1)
    for o in out:
        print(f"pid {o['pid']:>2} alloc {o['allocPoint']:>6} lpSupply {o['lpSupply']} lp {o['lpToken']}")

    # identify lp tokens not in factory pairs
    scan = json.load(open(os.path.join(BASE, "pairs_scan.json")))
    pair_tokens = set()
    for p in scan["pairs"]:
        pair_tokens.add(p["token0"])
        pair_tokens.add(p["token1"])
    unknown = [o["lpToken"].lower() for o in out if o["lpToken"].lower() not in pair_tokens]
    print("lp tokens not appearing as pair tokens:", len(unknown))
    calls = []
    for t in unknown:
        calls += [(t, SEL["symbol"]), (t, SEL["decimals"]), (t, SEL["totalSupply"])]
    res = batch(calls, hex(block))
    for i, t in enumerate(unknown):
        print("  ", t, "sym", dec_str(res[i * 3]), "dec", first_word(res[i * 3 + 1]), "ts", first_word(res[i * 3 + 2]))


if __name__ == "__main__":
    main()
