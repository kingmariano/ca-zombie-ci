#!/usr/bin/env python3
"""Verify batch-vs-individual eth_call discrepancy (pool 35 lpSupply) and re-check
critical balances individually. Public RPC only."""
import json
import time
import urllib.request

RPC = "https://mainnet.aurora.dev"
MC = "0x35CC71888DBb9FfB777337324a4A60fdBAA19DDE"
AZFD = "0x19185181EA1F59e1CAB83efd6BeeF6A9730603ee"
BRL = "0x12c87331f086c3C926248f964f8702C0842Fd77F"


def rpc(method, params):
    payload = {"jsonrpc": "2.0", "id": 1, "method": method, "params": params}
    req = urllib.request.Request(RPC, data=json.dumps(payload).encode(),
                                 headers={"Content-Type": "application/json", "User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(req, timeout=40) as r:
        return json.load(r)


def enc(a):
    return a.lower().replace("0x", "").rjust(64, "0")


def bal_of(token, holder):
    return rpc("eth_call", [{"to": token, "data": "0x70a08231" + enc(holder)}, "latest"])


print("=== individual AZFD.balanceOf(MC):", bal_of(AZFD, MC))

# now reproduce the batch exactly as mc_pools.py did (single chunk of 36)
pools = [
 (0, "0x12c87331f086c3C926248f964f8702C0842Fd77F"), (1, "0xc57eCc341aE4df32442Cf80F34f41Dc1782fE067"),
 (2, "0xEc538fAfaFcBB625C394c35b11252cef732368cd"), (3, "0x480A68bA97d70495e80e11e05D59f6C659749F27"),
 (4, "0xF3DE9dc38f62608179c45fE8943a0cA34Ba9CEfc"), (5, "0xe11A3f2BAB372d88D133b64487D1772847Eec4eA"),
 (6, "0xcb8584360Dc7A4eAC4878b48fB857AA794E46Fa8"), (7, "0x388D5EE199aC8dAD049B161b57487271Cd787941"),
 (8, "0x729dB9dB6d3cA82EF7e4c886C352749758BaD0eb"), (9, "0x314ab6AaeE15424ea8De07e2007646EcF3772357"),
 (10, "0x1C393468D95ADF8960E64939bCDd6eE602DE221C"), (11, "0x8F6e13B3D28B09535EB82BE539c1E4802B0c25B7"),
 (12, "0x8298B8C863c2213B9698A08de009cC0aB0F87FEe"), (13, "0x5BdAC608cd38C5C8738f5bE20813194A3150d4Ff"),
 (14, "0xEfCF518CA36DC3362F539965807b42A77DC26Be0"), (15, "0xDB0363ee28a5B40BDc2f4701e399c63E00f91Aa8"),
 (16, "0x84567E7511E0d97DE676d236AEa7aE688221799e"), (17, "0x892F67459b59ab867e2d73C7F2B696fDC6f69F34"),
 (18, "0x615f1240Ab636F7019c9816F1bE7119e73d78b88"), (19, "0x59a85DCB1f4Aa85232BAb95462de20993e48c620"),
 (20, "0x2eE60b9b898550a439622468C6AD65fBE726b7E0"), (21, "0xc6Fdc87759a8B56B8126a6f6864395A74Dc5Fb94"),
 (22, "0xb9636D074C3e8550449feba3be63fe95a582e876"), (23, "0xE24c7F50A9F514Db6Ccf151ff9a9411DE2110740"),
 (24, "0x2bB19e2F40FC2F8b6f9cC7d6066c51B05079a6b8"), (25, "0xD422A8EA35Acf115F41B5D941dC60507ED4F3792"),
 (26, "0x4f49eb288927293b4374F4a55ea668BC1c4cf310"), (27, "0xce3600a4d1Dd0acAC11C7EB827036597B9Ab91a7"),
 (28, "0x3866b969D2A3d1125A92244C2F8206E942f791F5"), (29, "0x43F43d76278C07f75c8be5d967165F7C148A0Be7"),
 (30, "0x4953b4EC9286e3fe600762Cd03edcC6A1034a543"), (31, "0xAfa14B4c0d8aF86cad6Ad5cbce9113685239346c"),
 (32, "0x4d48f0572fe4aE1C792137132aaDdfB852f7d3c1"), (33, "0xC51C887ac06A8fc3eA5036B581Ea19A619A89896"),
 (34, "0x24663dE1FE6972120f64Bea2882570A1E41354B3"), (35, "0x19185181EA1F59e1CAB83efd6BeeF6A9730603ee"),
]
payload = [{"jsonrpc": "2.0", "id": j, "method": "eth_call",
            "params": [{"to": lp, "data": "0x70a08231" + enc(MC)}, "latest"]} for j, (pid, lp) in enumerate(pools)]
req = urllib.request.Request(RPC, data=json.dumps(payload).encode(),
                             headers={"Content-Type": "application/json", "User-Agent": "Mozilla/5.0"})
with urllib.request.urlopen(req, timeout=60) as r:
    out = json.load(r)
print("=== batch of 36 -> id/results:")
by_id = {it.get("id"): it.get("result") for it in out}
for j, (pid, lp) in enumerate(pools):
    v = by_id.get(j)
    print(f"  id {j:>2} pid {pid:>2} -> {None if not v or v=='0x' else int(v[2:66],16)}")
