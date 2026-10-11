#!/usr/bin/env python3
"""DeFIL ETH inventory: batch balanceOf() reads for all protocol contracts via multicall3.
Read-only. Uses RPC from env RPC_URL (never printed/stored)."""
import json, os, sys, urllib.request, time

RPC = os.environ.get("DEFIL_RPC") or "https://ethereum-rpc.publicnode.com"
MULTICALL3 = "0xcA11bde05977b3631167028862bE2a173976CA11"

TOKENS = {
    "FILST": "0x7346aD4c8cD1886Ff6D16072bCeA5DFC0bc24Ca2",
    "DFL": "0x09ce2B746C32528B7d864A1e3979Bd97d2f095AB",
    "EFIL": "0x2a2cB9bA73289D4D068BD57D3c26165DaD5Cb628",
    "mFIL": "0x3C392C3FBE6ADA6049373478A4f8dD668Ab27b0C",
    "USDT": "0xdAC17F958D2ee523a2206206994597C13D831ec7",
    "WETH": "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2",
    "LP_FILST_USDT": "0xa2f6a219a51b4682e34a13a94c160d6c79cdca35",
    "LP_FILST_EFIL": "0x7393aa9DE6585ae2EC5e18aBfFe1eD07123d0E87",
    "LP_DFL_USDT": "0xd372a3221021Df72eDa38f77117d3A95f057e163",
    "LP_DFL_WETH": "0x4086E0dBdF6264CAAb655B6E5FaE943DDb09D203",
}

# All 62 contracts deployed by 0x3f0fe6cc (from Etherscan txlist), plus key EOAs/contracts
ADDRS = """0xfb2fd2068112c050e5c8c9759e201824d1e1adac 0x4cd7b5789d8a3379b347fcd258777d0e5c8315d5
0x09ce2b746c32528b7d864a1e3979bd97d2f095ab 0x9b1322c434584ddca16cb5d8c6d75368b3821e82
0x6e3dc6bca1c35e84262ec62e34bb2dfa788bc737 0xc7971be48085a8b7a83f1e59161173d3c132b451
0x69f8eb1727a9e0f0d37113d91ae3075c65b1bb2b 0x9d7621b157cb10fa32533f304ab0894fdbda5eb3
0xd4e1a98da92b3fa1beaa53e5fc479419a8f6b4df 0xa8af265dc79b6c45fd311e5ebffe4b5b69e33744
0x8340c3858f0c53d29e9c6669a4b625b304400443 0xecf802b10219258d7414142e16a58edf8f4a00e7
0x6795464efc9e44f6951ce5880c8bdbaf5a54b169 0xb394c6215a5577714a320a6be249dee58cea6f80
0xed919c9ceb2408ae263357c4e11e3d43adb72a7f 0xc554495c557d2ec03e141383768cee07c7f86139
0xd86519d8a0c34da2151d460baffdfcabba9cf252 0x3c2f55a3e7f4e092723cba44c1cbb859eff60bf3
0x2170c379b8bbc66bb8a77fb18136bf3250117cf6 0x6d4e7702b8eeb1758609e23522490c9e1d8bc145
0x7a21270190dcb9f9d7f9802f5b0c4ca5e83a974c 0x6b4f20b2259eebb97945b6ef549a1c44fca6cd81
0x9a9e42bc2a0f03be85985356bbe34d9c83b09c68 0xccb562cf7594bb87d88addae888bb4a12ecbd7da
0x6cc9fedc87010254a35239631353be387e228165 0xe8d21c3da81cc1ad97abf06a10f3f9952d3f3d11
0x036cf3821ea246e935feef1c29ed8ddffac1dbb0 0x3ccd01602d5fa18349ddb25f21079bd018284c8f
0xb685bfdad9da7093168ab75204bbcadf0c69c823 0x732b6ba357b6444820a34638833f4865028578ac
0x629cdff97a605885a714c6b0bb9e0b7fbded6733 0xbe8fb7db7425f9b1f67dc58ac31ddafc532dec9c
0xe67ae15cbb7f6b009f12c4c8999ca3ff4c39463d 0xb02f118013150c7f2d4f2030e15f198e1caa60eb
0x6b0c7d013cc0b461490287cc20aa9f34f950a6a6 0xb94e91ea1cf2ab3c44f48123d9e81ca5cdf6fa82
0x7346ad4c8cd1886ff6d16072bcea5dfc0bc24ca2 0xdb30f2ed6a55a7de7031c2ac4119366068049145
0xe5dbb86ea4669bc8bd3d48d1563dc27c50f8c0ea 0xca106916ca1f9c53442435036edf9b137b381c90
0x2d7a678eb9196d0de4f5467141038dbc949c97a1 0xad1ed31e70b569d78d1930537179a940dda4a9cf
0x097eb2025019ebec0faf9f8077804a10eb692f57 0x0b72c88a4f5e81d96da2ea3e8a26d0113de9d3ac
0x9cfcb73cb365ed7f38dcf3bc60d2aeafe0d502e2 0x7f5f88f761cb6408120d290835c9ae617ca79b42
0xcd429f23088b3fa4aabff61dd5f9e534793f9944 0xd89198402b55ea9dfb5b5b00a55ce032c27948bb
0xe32d18c22e25bc49bf347792f81400224cb5174c 0x4aa5f09d3f322371ce073425cf22ae098cef6e13
0x5e6468b3048d1b5a48ca6eae3953b17fe1165ed9 0x01aabbad98a7638b7f8d65e7ec42560f1afbbf0c
0x71dd9cd476c73f7c94a82e3f00a8ed29268602e1 0xc8f017593e7d0de9ea116313a255fe4647b2197b
0x9e08bd9a1e3880902688b32d563046cab74d2f2f 0xefeeb899c1a7ea13140c1c161dd3a054eda7d6f6
0x8a1e3e5815cffaf87c220a738b06c23f03543039 0x7fe1c0a5da0fcbe4a8f38662a71c6dbe2260ffd3
0x8a6023e72312ea3439041551a21c3b74021e1cbc 0x7a664ae67e68a9b2cdadd8486a7c47c972408405
0x1c7f772eabb3a3bfcb5e8f42432971f69e99103c 0x0f703af1a3f2bf8877132109a02659feead4ab9a
0x2a2cb9ba73289d4d068bd57d3c26165dad5cb628 0x3c392c3fbe6ada6049373478a4f8dd668ab27b0c
0x557edaaFD875569F0bd6AbaE1185c17fD5A30Ba0 0x3f0fe6cce8d6b52259ec7001bef898c62c4416ac""".split()

def enc_word(v):
    return "%064x" % v

def enc_addr(a):
    return enc_word(int(a, 16))

def enc_call3(target, data):
    d = bytes.fromhex(data[2:])
    out = enc_addr(target) + enc_word(1) + enc_word(0x60) + enc_word(len(d)) + d.hex()
    out += "00" * ((32 - len(d) % 32) % 32)
    return out

def rpc(method, params):
    req = urllib.request.Request(RPC, data=json.dumps({"jsonrpc": "2.0", "id": 1, "method": method, "params": params}).encode(),
                                 headers={"Content-Type": "application/json", "User-Agent": "Mozilla/5.0"})
    for attempt in range(3):
        try:
            with urllib.request.urlopen(req, timeout=30) as r:
                return json.loads(r.read())
        except Exception as e:
            if attempt == 2:
                raise
            time.sleep(2)

def main():
    block = int(rpc("eth_blockNumber", [])["result"], 16)
    print("latest block:", block)

    calls = []
    meta = []
    for a in ADDRS:
        for tname, taddr in TOKENS.items():
            data = "0x70a08231" + enc_addr(a)  # balanceOf(address)
            calls.append(enc_call3(taddr, data))
            meta.append((a, tname))

    out = {}
    CHUNK = 300
    for i in range(0, len(calls), CHUNK):
        chunk = calls[i:i+CHUNK]
        payload = "0x82ad56cb" + enc_word(0x20) + enc_word(len(chunk))
        offsets = []
        body = ""
        base = 32 * len(chunk)
        for c in chunk:
            offsets.append(base + len(body) // 2)
            body += c
        payload += "".join(enc_word(o) for o in offsets) + body
        res = rpc("eth_call", [{"to": MULTICALL3, "data": payload}, hex(block)])
        if "error" in res:
            print("RPC error:", res["error"])
            sys.exit(1)
        raw = res["result"][2:]
        # decode Result[]: (bool success, bytes returnData)[]
        off = int(raw[0:64], 16) // 32
        n = int(raw[64*off:64*off+64], 16)
        base2 = 64*off + 64
        for j in range(n):
            el_off = int(raw[base2+64*j:base2+64*j+64], 16) // 32
            el = base2 + 64*el_off
            success = int(raw[el:el+64], 16)
            data_off = int(raw[el+64:el+128], 16) // 32
            dstart = el + 64*data_off
            dlen = int(raw[dstart:dstart+64], 16)
            dbytes = raw[dstart+64:dstart+64+2*dlen] if dlen else ""
            a, tname = meta[i+j]
            if success and dlen == 32:
                val = int(dbytes, 16)
                if val:
                    out.setdefault(a, {})[tname] = str(val)
    # human readable
    for a, toks in out.items():
        print(a)
        for t, v in toks.items():
            print("   %-14s %s" % (t, v))
    with open(os.path.join(os.path.dirname(__file__), "eth_inventory.json"), "w") as f:
        json.dump({"block": block, "multicall3": MULTICALL3, "balances": out}, f, indent=1)
    print("wrote eth_inventory.json at block", block)

if __name__ == "__main__":
    main()
