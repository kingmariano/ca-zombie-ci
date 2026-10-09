#!/usr/bin/env python3
"""Fetch all oracle accounts referenced by Solend v1 reserves + classify/parse."""
import json, base64, time, urllib.request

RPC = "https://api.mainnet-beta.solana.com"

def rpc(method, params, retries=6):
    body = json.dumps({"jsonrpc": "2.0", "id": 1, "method": method, "params": params}).encode()
    delay = 1.0
    for i in range(retries):
        try:
            req = urllib.request.Request(RPC, data=body, headers={"Content-Type": "application/json"})
            with urllib.request.urlopen(req, timeout=90) as r:
                out = json.load(r)
            if "error" in out:
                raise RuntimeError(str(out["error"])[:300])
            return out["result"]
        except Exception:
            if i == retries - 1:
                raise
            time.sleep(delay); delay *= 1.7

def chunk(lst, n):
    for i in range(0, len(lst), n):
        yield lst[i:i + n]

def parse_pyth_price(data: bytes):
    if len(data) < 240:
        return {"err": "too_short", "len": len(data)}
    import struct
    d = {}
    d["magic"] = int.from_bytes(data[0:4], "little")
    d["ver"] = int.from_bytes(data[4:8], "little")
    d["type"] = int.from_bytes(data[8:12], "little")
    d["size"] = int.from_bytes(data[12:16], "little")
    d["ptype"] = int.from_bytes(data[16:20], "little")
    d["expo"] = int.from_bytes(data[20:24], "little", signed=True)
    d["num"] = int.from_bytes(data[24:28], "little")
    d["num_qt"] = int.from_bytes(data[28:32], "little")
    d["last_slot"] = int.from_bytes(data[32:40], "little")
    d["valid_slot"] = int.from_bytes(data[40:48], "little")
    d["timestamp"] = int.from_bytes(data[96:104], "little", signed=True)
    d["min_pub"] = data[104]
    d["flags"] = data[107]
    d["feed_index"] = int.from_bytes(data[108:112], "little")
    d["agg_price"] = int.from_bytes(data[208:216], "little", signed=True)
    d["agg_conf"] = int.from_bytes(data[216:224], "little")
    d["agg_status"] = int.from_bytes(data[224:228], "little")
    d["agg_corp_act"] = int.from_bytes(data[228:232], "little")
    d["agg_pub_slot"] = int.from_bytes(data[232:240], "little")
    d["price_usd"] = d["agg_price"] * (10 ** d["expo"])
    return d

def main():
    st = json.load(open("/tmp/opencode/solend_state.json"))
    cfgs = {r["address"]: r for r in st["configRows"]}
    accounts = {}
    for addr, r in st["reserves"].items():
        c = cfgs[addr]
        for k, v in (("pyth", r.get("pythOracle")), ("sb", r.get("switchboardOracle")),
                     ("cfgPyth", c.get("pythOracleCfg")), ("cfgSb", c.get("switchboardOracleCfg")),
                     ("extra", c.get("extraOracleCfg"))):
            if not v:
                continue
            if v.startswith("nu111") or v == "11111111111111111111111111111111":
                continue
            accounts[v] = True
    addrs = list(accounts.keys())
    print("distinct oracle accounts to fetch:", len(addrs))
    out = {}
    for i, batch in enumerate(chunk(addrs, 100)):
        res = rpc("getMultipleAccounts", [batch, {"encoding": "base64", "commitment": "confirmed"}])
        for a, acc in zip(batch, res["value"]):
            if acc is None:
                out[a] = {"exists": False}
            else:
                data = base64.b64decode(acc["data"][0])
                rec = {"exists": True, "owner": acc["owner"], "lamports": acc["lamports"], "len": len(data)}
                if acc["owner"] == "FsJ3A3u2vn5cTVofAjvy6y5kwABJAqYWpe4975bi2epH":
                    rec["pyth"] = parse_pyth_price(data)
                out[a] = rec
        print(f"oracle batch {i} done ({len(batch)})")
    slot = rpc("getSlot", [{"commitment": "confirmed"}])
    bt = rpc("getBlockTime", [slot])
    json.dump({"slot": slot, "blockTime": bt, "fetchedAt": int(time.time()), "oracles": out},
              open("/tmp/opencode/solend_oracles.json", "w"), indent=1)
    print("slot", slot, "blockTime", bt, "now", int(time.time()))

if __name__ == "__main__":
    main()
