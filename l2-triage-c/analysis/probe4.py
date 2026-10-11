#!/usr/bin/env python3
"""Round-4 probe."""
import json, base64, urllib.request, urllib.error, ssl, socket

def post(url, body, timeout=25):
    data = json.dumps(body).encode()
    req = urllib.request.Request(url, data=data, headers={"Content-Type": "application/json", "User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return json.loads(r.read().decode())

def get(url, timeout=25):
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return r.read().decode()

def show(tag, val, n=300):
    s = json.dumps(val) if not isinstance(val, str) else val
    print(f"[{tag}] {s[:n]}")

# 1) Solana token accounts: public mainnet-beta + drpc
for url in ["https://api.mainnet-beta.solana.com", "https://solana.drpc.org"]:
    for owner, tag in [("7gpj9cpzBBW9Ci1yMwWz7iGbQYpm5fZmadNQyrYsqch8","jet-v1")]:
        try:
            r = post(url, {"jsonrpc":"2.0","id":1,"method":"getTokenAccountsByOwner","params":[owner,{"programId":"TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA"},{"encoding":"jsonParsed"}]})
            res = r.get("result",{}).get("value",[])
            show(f"solana.{tag}@{url.split('//')[1][:22]}", {"count":len(res), "sample": (res[0].get("account",{}).get("data",{}).get("parsed",{}).get("info",{}) if res else None)})
        except Exception as e:
            print(f"[solana.{tag}@{url}] ERROR", e)

# 2) Osmosis smart query via publicnode
try:
    b = base64.b64encode(json.dumps({"info":{}}).encode()).decode()
    r = get(f"https://osmosis-rest.publicnode.com/cosmwasm/wasm/v1/contract/osmo16s3sxs5886p42kteunp6370pken2n5ukzszz0trkr39epqtawn2qk4r9l5/smart/{b}")
    show("osmo.stOSMO.info.pn", r)
except Exception as e:
    print("[osmo.pn] ERROR", e)

# 3) Neutron LCD alternatives
for base in ["https://lcd-neutron.keplr.app", "https://neutron-lcd.polkachu.com", "https://rest-kralum.neutron-1.neutron.org", "https://neutron-rest.publicnode.com"]:
    try:
        b = base64.b64encode(json.dumps({"info":{}}).encode()).decode()
        r = get(f"{base}/cosmwasm/wasm/v1/contract/neutron1puedrclm6rn33x3zv66xg6m23qcdagayqua6jj2wqzvfznlqef8qe53wr2/smart/{b}")
        show(f"neutron.info@{base.split('//')[1][:28]}", r)
    except Exception as e:
        print(f"[neutron@{base}] ERROR", e)

# 4) Secret LCD alternatives (node_info + wasm code listing)
for base in ["https://lcd-secret.publicnode.com", "https://secret-lcd.publicnode.com", "https://api.secretapi.io", "https://lcd.secret.network", "https://scrt-rest.polkachu.com", "https://secret-rest.lavenderfive.com", "https://rest.scrt.network"]:
    try:
        r = get(f"{base}/cosmos/base/tendermint/v1beta1/node_info")
        show(f"secret@{base.split('//')[1][:30]}", r[:120])
    except Exception as e:
        print(f"[secret@{base}] ERROR {e}")

# 5) Sui: full dynamic fields + one field object shape (bluemove AMM)
try:
    r = post("https://sui-rpc.publicnode.com", {"jsonrpc":"2.0","id":1,"method":"suix_getDynamicFields","params":["0x3f2d9f724f4a1ce5e71676448dc452be9a6243dac9c5b975a588c8c867066e92", None, 50]})
    d = r.get("result",{})
    fields = d.get("data",[])
    show("sui.bluemove.fields.count", {"count": len(fields), "hasNextPage": d.get("hasNextPage"), "first_type": fields[0].get("objectType") if fields else None})
    if fields:
        oid = fields[0]["objectId"]
        r2 = post("https://sui-rpc.publicnode.com", {"jsonrpc":"2.0","id":1,"method":"suix_getDynamicFieldObject","params":["0x3f2d9f724f4a1ce5e71676448dc452be9a6243dac9c5b975a588c8c867066e92", {"type":"0x1::string::String","value":fields[0]["name"]["value"]}]})
        res2 = r2.get("result",{}).get("data",{})
        show("sui.bluemove.field0.object", {"objectType": res2.get("objectType") or res2.get("type"), "fields_keys": list((res2.get("content",{}).get("fields") or {}).keys())[:12]})
except Exception as e:
    print("[sui.bluemove.full] ERROR", e)

# 6) Filecoin: SFT API DNS + alternatives
for host in ["ww8.sftproject.io", "sftproject.io", "www.sftproject.io", "api.sftproject.io"]:
    try:
        ip = socket.gethostbyname(host)
        print(f"[dns.sft] {host} -> {ip}")
    except Exception as e:
        print(f"[dns.sft] {host} FAIL {e}")

# 7) BCH Fulcrum (Moria): token.address.listunspent over SSL socket
def fulcrum_call(host, port, method, params):
    ctx = ssl.create_default_context(); ctx.check_hostname=False; ctx.verify_mode=ssl.CERT_NONE
    with socket.create_connection((host, port), timeout=20) as raw:
        with ctx.wrap_socket(raw, server_hostname=host) as s:
            req = json.dumps({"id":1,"method":method,"params":params}) + "\n"
            s.sendall(req.encode())
            buf = b""
            while b"\n" not in buf:
                chunk = s.recv(65536)
                if not chunk: break
                buf += chunk
            return json.loads(buf.split(b"\n")[0].decode())
try:
    r = fulcrum_call("bch.imaginary.cash", 50002, "server.version", ["probe","1.9"])
    show("bch.fulcrum.version", r)
    r2 = fulcrum_call("bch.imaginary.cash", 50002, "token.address.listunspent", ["rvtgwvmtp4hy5k9alcwc5yt69k4jnshevdwapq43w7hp8m7hwj60szuun6naf", None, "b38a33f750f84c5c169a6f23cb873e6e79605021585d4f3408789689ed87f366"])
    show("bch.moria.utxos", r2, 400)
except Exception as e:
    print("[bch.fulcrum] ERROR", e)

# 8) ErgoDEX: also fetch boxes count
try:
    r = get("https://api.ergoplatform.com/api/v1/boxes/unspent/byAddress/5vSUZRZbdVbnk4sJWjg2uhL94VZWRg4iatK9VgMChufzUgdihgvhR8yWSUEJKszzV7Vmi6K8hCyKTNhUaiP8p5ko6YEU9yfHpjVuXdQ4i5p4cRCzch6ZiqWrNukYjv7Vs5jvBwqg5hcEJ8u1eerr537YLWUoxxi1M4vQxuaCihzPKMt8NDXP4WcbN6mfNxxLZeGBvsHVvVmina5THaECosCWozKJFBnscjhpr3AJsdaL8evXAvPfEjGhVMoTKXAb2ZGGRmR8g1eZshaHmgTg2imSiaoXU5eiF3HvBnDuawaCtt674ikZ3oZdekqswcVPGMwqqUKVsGY4QuFeQoGwRkMqEYTdV2UDMMsfrjrBYQYKUBFMwsQGMNBL1VoY78aotXzdeqJCBVKbQdD3ZZWvukhSe4xrz8tcF3PoxpysDLt89boMqZJtGEHTV9UBTBEac6sDyQP693qT3nKaErN8TCXrJBUmHPqKozAg9bwxTqMYkpmb9iVKLSoJxG7MjAj72SRbcqQfNCVTztSwN3cRxSrVtz4p87jNFbVtFzhPg7UqDwNFTaasySCqM?limit=1")
    d = json.loads(r)
    show("ergo.ergodex.boxes", {"total": d.get("total"), "first": d.get("items",[{}])[0].get("boxId") if d.get("items") else None})
except Exception as e:
    print("[ergo.boxes] ERROR", e)

# 9) Hedera: defaultPool balance
try:
    from Crypto.Hash import keccak as K
    k=K.new(digest_bits=256); k.update(b"defaultPool()"); sel="0x"+k.digest()[:4].hex()
    r = post("https://mainnet.hashio.io/api", {"jsonrpc":"2.0","id":1,"method":"eth_call","params":[{"to":"0x00000000000000000000000000000000005c9f66","data":sel},"latest"]})
    dp = "0x"+r["result"][-40:] if r.get("result") and len(r["result"])>=42 else None
    show("hedera.trove.defaultPool", dp)
    if dp:
        r2 = post("https://mainnet.hashio.io/api", {"jsonrpc":"2.0","id":1,"method":"eth_getBalance","params":[dp,"latest"]})
        show("hedera.trove.defaultPoolBal", r2)
    # HLQT token balance of staking
    k2=K.new(digest_bits=256); k2.update(b"balanceOf(address)"); sel2="0x"+k2.digest()[:4].hex()
    r3 = post("https://mainnet.hashio.io/api", {"jsonrpc":"2.0","id":1,"method":"eth_call","params":[{"to":"0x00000000000000000000000000000000005c9f70","data":sel2+"00000000000000000000000000000000000000000000000000000000005c9f30"},"latest"]})
    show("hedera.hlqt.stakingBal", r3)
except Exception as e:
    print("[hedera.extra] ERROR", e)

# 10) ICON full Omm data
try:
    r = post("https://ctz.solidwallet.io/api/v3", {"jsonrpc":"2.0","id":1,"method":"icx_call","params":{"to":"cx5f9a6ca11b2b761a469965cedab40ada9e503cb5","dataType":"call","data":{"method":"getAllReserveData","params":{}}}})
    d = r.get("result",{})
    out = {}
    for sym, v in (d or {}).items():
        out[sym] = {"liq": v.get("availableLiquidity"), "liqUSD": v.get("availableLiquidityUSD"), "bor": v.get("totalBorrowsUSD")}
    show("icon.omm.all", out, 800)
except Exception as e:
    print("[icon.omm2] ERROR", e)
