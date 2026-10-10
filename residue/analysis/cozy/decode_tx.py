#!/usr/bin/env python3
"""Decode Cozy incident tx receipts via public RPC (read-only)."""
import json
import subprocess
import sys

RPC = "https://optimism.drpc.org"
T = "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef"
APPROVAL = "0x8c5be1e5ebec7d5bd14f71427d1e84f3dd0314c0f7b2291e5b200ac8c7c3b925"
SIGS = {
    "0x017276d5bd86f915a420b9dbfc6846a71ea124a03d4210744d6b357a9e096cde": ("Purchase", ["caller", "receiver"], ["protection", "ptokens", "cost"], "ptoken"),
    "0x1c4cf45fd8377e37263c721a037674fcd4b3d2da8c1b174a5e2710fe495f6483": ("Claim", ["receiver", "owner"], ["caller", "protection", "ptokens"], "ptoken"),
    "0x75a52e5862fbac02d68f1ab985e211c011bc73e3d3412d39ef418861d2941e69": ("DecayAccrued", ["ptoken"], ["newActiveProtection"], None),
    "0xc5b99830e443f75cbdc716ec2003a9e4b9f54276d493e40dc85d861de9c8159f": ("SetStateUpdated", [], ["state"], None),
    "0x92ea33dd9d98420e788c4100ad569fc129198068d768824a9b11fcd03e1b2581": ("MarketStateUpdated", ["marketId", "trigger"], ["state"], None),
    "0x436f488b92b5d832b5a5dbfde3f9c97f235d72db6f6648bade2e2c2c6f83525a": ("FeesAccrued", [], ["reserveFees", "backstopFees", "setOwnerFees"], None),
    "0xdcbc1c05240f31ff3ad067ef1ee35ce4997762752e3a095284754544f4c709d7": ("Deposit", ["caller", "owner"], ["assets", "shares"], None),
    "0xfaa636932e03461ba33f10c7eec82eb448427d90ca245af9dda4b405aef79845": ("FeesDripped", [], ["a", "b"], None),
    "0xaf3add10310b906b0f5d9e6a2f6f6b7e6b6d6f6e6f7e7d7c7b7a7978777675747": ("Sell", ["caller", "receiver"], ["protection", "ptokens", "refund"], "ptoken"),
    "0x215abfcd108b85fb0f0d0e0d0e0d0e0d0e0d0e0d0e0d0e0d0e0d0e0d0e0d0e0d0": ("Redeem", [], [], None),
    "0x4e7b84a1f0a2f0a2f0a2f0a2f0a2f0a2f0a2f0a2f0a2f0a2f0a2f0a2f0a2f0a2": ("X", [], [], None),
}


def sig(s):
    out = subprocess.run(["cast", "keccak", s], capture_output=True, text=True)
    return out.stdout.strip()


EXTRA = {
    sig("ProposePrice(address,address,bytes32,uint256,bytes,int256,uint256)"): ("UMA:ProposePrice", ["requester", "proposer"], ["identifier", "timestamp", "ancillaryData", "proposedPrice", "expirationTimestamp"], None),
    sig("Settle(address,address,address,bytes32,uint256,bytes,int256,uint256)"): ("UMA:Settle", ["requester", "proposer", "disputer"], ["identifier", "timestamp", "ancillaryData", "price", "payout"], None),
    sig("RequestPrice(address,bytes32,uint256,bytes,address,uint256,uint256)"): ("UMA:RequestPrice", ["requester"], ["identifier", "timestamp", "ancillaryData", "currency", "reward", "finalFee"], None),
    sig("FeesDripped(uint128,uint128)"): ("FeesDripped", [], ["a", "b"], None),
    sig("FeesAccrued(uint128,uint128,uint128)"): ("FeesAccrued", [], ["reserveFees", "backstopFees", "setOwnerFees"], None),
}
SIGS.update(EXTRA)


def rpc(method, params):
    out = subprocess.run(
        ["curl", "-s", "-m", "60", "-X", "POST", RPC, "-H", "Content-Type: application/json",
         "-d", json.dumps({"jsonrpc": "2.0", "id": 1, "method": method, "params": params})],
        capture_output=True, text=True, timeout=90)
    return json.loads(out.stdout)["result"]


def dec_addr(w):
    return "0x" + w[-40:]


def decode_tx(txhash, show_transfers=True):
    r = rpc("eth_getTransactionReceipt", [txhash])
    print(f"=== TX {txhash} block {int(r['blockNumber'],16)} status {r['status']} logs={len(r['logs'])}")
    for lg in r["logs"]:
        addr = lg["address"]
        t0 = lg["topics"][0]
        if t0 == T and show_transfers:
            frm, to = dec_addr(lg["topics"][1]), dec_addr(lg["topics"][2])
            val = int(lg["data"], 16)
            print(f"  Transfer {addr} from={frm} to={to} value={val}")
            continue
        if t0 == APPROVAL and show_transfers:
            o, s = dec_addr(lg["topics"][1]), dec_addr(lg["topics"][2])
            print(f"  Approval {addr} owner={o} spender={s} value={int(lg['data'],16)}")
            continue
        info = SIGS.get(t0)
        if not info:
            print(f"  EVENT unknown topic0={t0} addr={addr} topics={len(lg['topics'])} data={lg['data'][:130]}")
            continue
        name, indexed, data_names, extra = info
        parts = [f"{name} by {addr}"]
        for i, n in enumerate(indexed):
            if len(lg["topics"]) > i + 1:
                parts.append(f"{n}={dec_addr(lg['topics'][i+1])}")
            else:
                parts.append(f"{n}=??")
        if data_names:
            data = lg["data"][2:]
            words = [data[i:i+64] for i in range(0, len(data), 64)]
            for n, w in zip(data_names, words):
                if n in ("ancillaryData",):
                    parts.append(f"{n}=<{len(w)//2*1} bytes>")
                else:
                    parts.append(f"{n}={int(w,16)}")
        if extra == "ptoken" and len(lg["topics"]) > 3:
            parts.append(f"ptoken={dec_addr(lg['topics'][3])}")
        print("  " + " ".join(parts))


if __name__ == "__main__":
    for tx in sys.argv[1:]:
        decode_tx(tx)
