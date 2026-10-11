#!/usr/bin/env python3
"""Round-3 probe: validate exact live-query shapes for each chain. Read-only."""
import json, base64, hashlib, urllib.request, urllib.error, sys

def post(url, body, timeout=25, headers=None):
    data = json.dumps(body).encode() if not isinstance(body, (bytes, str)) else (body.encode() if isinstance(body, str) else body)
    req = urllib.request.Request(url, data=data, headers={"Content-Type": "application/json", "User-Agent": "Mozilla/5.0", **(headers or {})})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return json.loads(r.read().decode())

def get(url, timeout=25):
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return r.read().decode()

def keccak_selector(name):
    from Crypto.Hash import keccak
    k = keccak.new(digest_bits=256); k.update(name.encode())
    return hex(int.from_bytes(k.digest(), "big") & ((1 << 250) - 1))

def show(tag, val, n=260):
    s = json.dumps(val) if not isinstance(val, str) else val
    print(f"[{tag}] {s[:n]}")

# 1) Starknet: jediswap factory get_all_pairs
try:
    sel = keccak_selector("get_all_pairs")
    show("starknet.get_all_pairs.selector", sel)
    r = post("https://api.cartridge.gg/x/starknet/mainnet", {"jsonrpc":"2.0","id":1,"method":"starknet_call","params":{"request":{"contract_address":"0xdad44c139a476c7a17fc8141e6db680e9abc9f56fe249a105094c44382c2fd","entry_point_selector":sel,"calldata":[]},"block_id":"latest"}})
    show("starknet.jediswap.pairs", r)
except Exception as e:
    print("[starknet.jediswap] ERROR", e)

# 2) Sui: dynamic fields of bluemove accounts (publicnode JSON-RPC)
for acct, tag in [("0x3f2d9f724f4a1ce5e71676448dc452be9a6243dac9c5b975a588c8c867066e92","bluemove-amm"),
                  ("0x5a7eca40df453efe6bb1feae99e5b8fc072d1252cbd1979eb187d625dc9b47c9","bluemove-stable")]:
    try:
        r = post("https://sui-rpc.publicnode.com", {"jsonrpc":"2.0","id":1,"method":"suix_getDynamicFields","params":[acct, None, 5]})
        show(f"sui.{tag}.dynfields", r)
    except Exception as e:
        print(f"[sui.{tag}] ERROR", e)

# 3) Injective LCD: dojoswap factory pairs query
try:
    q = base64.b64encode(json.dumps({"pairs":{"limit":3}}).encode()).decode()
    r = get(f"https://injective-rest.publicnode.com/cosmwasm/wasm/v1/contract/inj1pc2vxcmnyzawnwkf03n2ggvt997avtuwagqngk/smart/{q}")
    show("injective.dojoswap.pairs", r)
except Exception as e:
    print("[injective.dojoswap] ERROR", e)

# 4) Osmosis + Neutron LCD: margined vault info/total_assets
for lcd, vault, tag in [
    ("https://lcd.osmosis.zone", "osmo16s3sxs5886p42kteunp6370pken2n5ukzszz0trkr39epqtawn2qk4r9l5", "osmo.stOSMO"),
    ("https://neutron-api.polkachu.com", "neutron1puedrclm6rn33x3zv66xg6m23qcdagayqua6jj2wqzvfznlqef8qe53wr2", "neutron.ATOMFund"),
]:
    for q in [{"info":{}},{"total_assets":{}}]:
        try:
            b = base64.b64encode(json.dumps(q).encode()).decode()
            r = get(f"{lcd}/cosmwasm/wasm/v1/contract/{vault}/smart/{b}")
            show(f"{tag}.{list(q)[0]}", r)
        except Exception as e:
            print(f"[{tag}.{list(q)[0]}] ERROR", e)

# 5) Radix: entity details for LSU component
try:
    r = post("https://mainnet.radixdlt.com/state/entity/details", {"addresses":["component_rdx1cppy08xgra5tv5melsjtj79c0ngvrlmzl8hhs7vwtzknp9xxs63mfp"],"opt_ins":{"explicit_metadata":["name"]}})
    items = r.get("items",[])
    show("radix.lsu.component", {"n_items":len(items), "fungibles":items[0].get("fungible_resources",{}).get("items",[])[:6] if items else None})
except Exception as e:
    print("[radix.lsu] ERROR", e)

# 6) Koios: Lenfi script address info
try:
    r = post("https://api.koios.rest/api/v1/address_info", {"_addresses":["addr1zytwe3qhc0kf5k8yaur60cnhcxjg9zvfdnftp0rfu2czprtfjcnq9fczt4qkxgec2hz6x7f38vnj8xuxywk4x4qgzh9sgzwepc"]})
    show("koios.lenfi.addr", r)
except Exception as e:
    print("[koios.lenfi] ERROR", e)

# 7) Ergo: ErgoDEX owner address balance
try:
    addr = "5vSUZRZbdVbnk4sJWjg2uhL94VZWRg4iatK9VgMChufzUgdihgvhR8yWSUEJKszzV7Vmi6K8hCyKTNhUaiP8p5ko6YEU9yfHpjVuXdQ4i5p4cRCzch6ZiqWrNukYjv7Vs5jvBwqg5hcEJ8u1eerr537YLWUoxxi1M4vQxuaCihzPKMt8NDXP4WcbN6mfNxxLZeGBvsHVvVmina5THaECosCWozKJFBnscjhpr3AJsdaL8evXAvPfEjGhVMoTKXAb2ZGGRmR8g1eZshaHmgTg2imSiaoXU5eiF3HvBnDuawaCtt674ikZ3oZdekqswcVPGMwqqUKVsGY4QuFeQoGwRkMqEYTdV2UDMMsfrjrBYQYKUBFMwsQGMNBL1VoY78aotXzdeqJCBVKbQdD3ZZWvukhSe4xrz8tcF3PoxpysDLt89boMqZJtGEHTV9UBTBEac6sDyQP693qT3nKaErN8TCXrJBUmHPqKozAg9bwxTqMYkpmb9iVKLSoJxG7MjAj72SRbcqQfNCVTztSwN3cRxSrVtz4p87jNFbVtFzhPg7UqDwNFTaasySCqM"
    r = get("https://api.ergoplatform.com/api/v1/addresses/" + addr + "/balance/total")
    show("ergo.ergodex.balance", r)
except Exception as e:
    print("[ergo.ergodex] ERROR", e)

# 8) Hedera: eth_getBalance + activePool call
try:
    r = post("https://mainnet.hashio.io/api", {"jsonrpc":"2.0","id":1,"method":"eth_getBalance","params":["0x00000000000000000000000000000000005c9f66","latest"]})
    show("hedera.trove.balance", r)
    # activePool() selector = keccak("activePool()")[:4]
    from Crypto.Hash import keccak as K
    k=K.new(digest_bits=256); k.update(b"activePool()"); sel="0x"+k.digest()[:4].hex()
    r2 = post("https://mainnet.hashio.io/api", {"jsonrpc":"2.0","id":1,"method":"eth_call","params":[{"to":"0x00000000000000000000000000000000005c9f66","data":sel},"latest"]})
    show("hedera.trove.activePool", r2)
    if r2.get("result") and len(r2["result"])>=42:
        ap = "0x"+r2["result"][-40:]
        r3 = post("https://mainnet.hashio.io/api", {"jsonrpc":"2.0","id":1,"method":"eth_getBalance","params":[ap,"latest"]})
        show("hedera.trove.activePoolBal", {"activePool":ap, "bal":r3})
except Exception as e:
    print("[hedera] ERROR", e)

# 9) Filecoin: SFT pool eth_getBalance + StateGetActor
try:
    r = post("https://api.node.glif.io/rpc/v1", {"jsonrpc":"2.0","id":1,"method":"eth_getBalance","params":["0x147122D1EBdA76E4910ccdC53aEb6a58605Eb58E","latest"]})
    show("filecoin.sft.pool", r)
    r2 = get("https://ww8.sftproject.io/api/c/api/v1/public/dashboard/info")
    show("filecoin.sft.api", r2)
except Exception as e:
    print("[filecoin.sft] ERROR", e)

# 10) ICON: icx_call getAllReserveData
try:
    r = post("https://ctz.solidwallet.io/api/v3", {"jsonrpc":"2.0","id":1,"method":"icx_call","params":{"to":"cx5f9a6ca11b2b761a469965cedab40ada9e503cb5","dataType":"call","data":{"method":"getAllReserveData","params":{}}}})
    s = json.dumps(r)
    show("icon.omm.reserves", s[:400])
except Exception as e:
    print("[icon.omm] ERROR", e)

# 11) Oasis: fountain comptroller getAllMarkets
try:
    from Crypto.Hash import keccak as K
    k=K.new(digest_bits=256); k.update(b"getAllMarkets()"); sel="0x"+k.digest()[:4].hex()
    r = post("https://emerald.oasis.dev", {"jsonrpc":"2.0","id":1,"method":"eth_call","params":[{"to":"0xA7684aE7e07Dac91113900342b3ef25B9Fd1D841","data":sel},"latest"]})
    show("oasis.fountain.markets", r)
except Exception as e:
    print("[oasis.fountain] ERROR", e)

# 12) Solana: getTokenAccountsByOwner for jet + 01
for owner, tag in [("7gpj9cpzBBW9Ci1yMwWz7iGbQYpm5fZmadNQyrYsqch8","jet-v1"), ("HjHSNe8hhvZ8hKCRrhKg1DGiGPd9NYQbUjT1SQRDo4kZ","01")]:
    try:
        r = post("https://solana-rpc.publicnode.com", {"jsonrpc":"2.0","id":1,"method":"getTokenAccountsByOwner","params":[owner,{"programId":"TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA"},{"encoding":"jsonParsed"}]})
        res = r.get("result",{}).get("value",[])
        show(f"solana.{tag}.tokenaccts", {"count":len(res), "first": res[0] if res else None})
    except Exception as e:
        print(f"[solana.{tag}] ERROR", e)

# 13) Acala: system_account storage via state_getStorage (account storage key)
try:
    import binascii
    # storage key: twox128("System") ++ twox128("Account") ++ blake2_128_concat(pubkey)
    # use known account hex instead: 23M5ttkp... -> need ss58 decode; skip here, test system_chain + a basic state call
    r = post("https://acala-rpc-0.aca-api.network", {"jsonrpc":"2.0","id":1,"method":"state_getRuntimeVersion","params":[]})
    show("acala.runtime", {"specName": r.get("result",{}).get("specName"), "specVersion": r.get("result",{}).get("specVersion")})
except Exception as e:
    print("[acala] ERROR", e)
