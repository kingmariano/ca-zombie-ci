#!/usr/bin/env python3
"""Minimal Starknet JSON-RPC client for read-only research.

Keyless public endpoints only (no API keys in this file).
Selector computation uses pycryptodome when available, else a precomputed table
(so CI works without pip installs).
Usage: python3 sn.py <method> <params-json>
"""
import json, sys, time, urllib.request

RPCS = [
    "https://api.cartridge.gg/x/starknet/mainnet",
    "https://starknet.drpc.org",
]

# Fallback selector table (keccak256(name) & (2^250-1)) for every function used by this folder.
_SELECTORS = {
    "allPairs": "0x322330b99043a35eb61a21ff439b5d8fb60c05f689cb96da4eb9baf0ddda6a7",
    "allPairsLength": "0x39c628dd69d8a2f0773ac569310eb1e4729a6d4c626c255ee264d3f0bb265c4",
    "getTokens": "0x2a49c0f2eb847706ab729396646d9580a5808a2719ac532e8065dda134315d1",
    "getReserve0": "0x199f22212bbe478d31f89bbb77e5bd05d05fcaeee957595df139a1a3c381044",
    "getReserve1": "0xe6864f424a071ba524ff7eeabd07a91c33e103aeb05c488577d9004779ec80",
    "totalSupply": "0x80aa9fdbfaf9615e4afc7f5f722e265daca5ccc655360fa5ccacf9c267936d",
    "getStable": "0x2839d9cc5384a84fc6c6b33e76134594dca46933af2c261dc1d0d204c0d096b",
    "getFee0": "0x505d122fcc630136e61ea6e55588068110426b9c3144454b99afa1672f2a1b",
    "getFee1": "0x172eaacf9e5ed73b56a8e69d0bc969598a8fe5180df00e59b86d665f38793e1",
    "getFees": "0x217e86c9ef0764bef538e084e9a74b79db558e31e9580c42088771a72ab7520",
    "owner": "0x2016836a56b71f0d02689e69e326f4f4c1b9057164ef592671cf0d37c8040c0",
    "getPid": "0x1a9c826352e1759e8f46a0866730b5cbb76f0afd45c1630a9700257671a316",
    "getIndex0": "0x36974d9853e46941a521a7ab79df628e22f1843101333d0b3349ef80c1f4df",
    "getIndex1": "0x1eb639eb309e657f4d4a12f066cb294eab917f617ef5c8df968e745c1594455",
    "symbol": "0x216b05c387bab9ac31918a3e61672f4618601f3c598a2f3f2710f37053e1ea4",
    "decimals": "0x4c4fb1ab068f6039d5780c68dd0fa2f8742cceb3426d19667778ca7f3518a9",
    "name": "0x361458367e696363fbcc70777d07ebbd2394e89fd0adcaf147faccd1d294d60",
    "balanceOf": "0x2e4263afad30923c891518314c3c95dbe830a16874e8abc5777a9a20b54c76e",
    "getAmountOut": "0x3a48f8b5560a10a555df99cbc59b755eb8b8c140626f63111dcd1b98ba2054a",
    "getMetadata": "0x22f7a2bb4922f149ba5cf39fbe478e4e42ae98865ea754e7dd43be9c25ca849",
    "setTradeFee": "0xba535c56f128bd7d83bba68520647f8aefca16ccc1e7375966602657829f49",
    "transferOwnership": "0x14a390f291e2e1f29874769efdef47ddad94d76f77ff516fad206a385e8995f",
    "clawbackOwnership": "0x2d5d3677f880035881f83e6ea93c301754e848242918870d914ad5104a9b5d6",
    "claimFees": "0x75cbe2958efa64817f6ce221759141bd1bfa3c768db475b5a98082e6dda3e1",
    "swap": "0x15543c3708653cda9d418b4ccd3be11368e40636c10c44b18cfe756b6d88b29",
    "burn": "0x3e8cfd4725c1e28fa4a6e3e468b4fcf75367166b850ac5f04e33ec843e82c1",
    "sync": "0x2dfa381c1e19f8cb9d4357dfe42f5258bfebbd9317ae52b00c7cb954580041d",
    "skim": "0x3dd12614b076872dd4f330f78e0121959fb5511add6c672bcb20ea237c376f2",
    "renounceOwnership": "0xd5d33d590e6660853069b37a2aea67c6fdaa0268626bc760350b590490feb5",
    "claimOwnership": "0x35f49ebdb118f06ba73464cc15b97be39da445ec6545e559bf65c867b028686",
    "initialize": "0x79dc0da7c54b95f10aa182ad0a46400db63156920adb65eca2654c0945a463",
    "getTradeFee": "0x1f7473fea055a73a39e6420484eed2ca735493e645096cb15f0b92e6d8d24db",
    "Transfer": "0x99cd8bde557814842a3121e8ddfd433a539b8c9f14bf31ebf108d12e6196e9",
    "transfer": "0x83afd3f4caedc6eebf44246fe54e38c95e3179a5ec9ea81740eca5b482d12e",
    "claimFeesFor": "0x1a807763d1aaf439ebb2d46299f3ee7097271f4a6317c062e2ce43c7b7aa0c3",
    "getClaimable0": "0x2c77d99fbd1b8057bd29e11042eca56b1a02b6533f7e505503b9bfaa059f92d",
    "getClaimable1": "0x35f68397159197222b391496d27e2255bfa208f5cca6ca23f58c4905108c9a9",
    "getSupplyIndex0": "0x3c383ee1ca4c5d27a0838a0d0c98abc171a1515a07041385719144c49c3f5d7",
    "getSupplyIndex1": "0x334f99e4a89cba548a40dd7d1fcbd2c32da1f20f4ab96da7af5cb8a6b70dc0c",
    "getLastFeeUpdate": "0x22a7d97280ce142e1e313b3217b6e144a491426c2dfa93e0aa635ada12879c5",
    "getTradeDiff": "0x34dcea1df02fe76dd67e307b909a473bc867f27cb4501ccc1bf92036960e9d5",
    "allowance": "0x1e888a1026b19c8c0b57c72d63ed1737106aa10034105b980ba117bd0c29fe1",
    "approve": "0x219209e083275171774dab1df80982e9df2096516f06319c5c6d71ae0a8480c",
    "transferFrom": "0x41b033f4a31df8067c24d1e9b550a2ce75fd4a29e1147af9752174f0e6cb20",
    "increaseAllowance": "0x16cc063b8338363cf388ce7fe1df408bf10f16cd51635d392e21d852fafb683",
    "decreaseAllowance": "0x1aaf3e6107dd1349c81543ff4221a326814f77dadcc5810807b74f1a49ded4e",
}

try:
    from Crypto.Hash import keccak
    def selector(name: str) -> str:
        k = keccak.new(digest_bits=256)
        k.update(name.encode())
        return hex(int.from_bytes(k.digest(), "big") & ((1 << 250) - 1))
except ImportError:
    def selector(name: str) -> str:
        if name in _SELECTORS:
            return _SELECTORS[name]
        raise RuntimeError(f"no keccak backend and '{name}' not in fallback selector table")

def rpc(method, params, rpc_url=None):
    urls = [rpc_url] if rpc_url else RPCS
    last = None
    for url in urls:
        body = json.dumps({"jsonrpc": "2.0", "method": method, "params": params, "id": 1}).encode()
        req = urllib.request.Request(url, data=body, headers={"Content-Type": "application/json", "User-Agent": "Mozilla/5.0 research"})
        for attempt in range(3):
            try:
                with urllib.request.urlopen(req, timeout=30) as r:
                    j = json.loads(r.read())
                if "error" in j:
                    last = j["error"]
                    break  # method-level error: try next url
                return j["result"]
            except Exception as e:
                last = str(e)
                time.sleep(1)
    raise RuntimeError(f"{method} failed: {last}")

def call(addr, fn, calldata=None, block="latest", rpc_url=None):
    bid = block if isinstance(block, (dict, str)) else {"block_number": int(block)}
    return rpc("starknet_call", {
        "request": {"contract_address": hex(addr), "entry_point_selector": selector(fn),
                    "calldata": [hex(x) if isinstance(x, int) else x for x in (calldata or [])]},
        "block_id": bid,
    }, rpc_url)

def u256_from_felts(felts):
    if len(felts) == 1:
        return int(felts[0], 16) if isinstance(felts[0], str) else int(felts[0])
    lo, hi = (int(felts[0], 16), int(felts[1], 16))
    return lo + (hi << 128)

if __name__ == "__main__":
    method = sys.argv[1]
    params = json.loads(sys.argv[2]) if len(sys.argv) > 2 else []
    print(json.dumps(rpc(method, params), indent=2))
