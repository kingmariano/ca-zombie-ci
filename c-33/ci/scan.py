#!/usr/bin/env python3
"""C-33 scanner: Compound-v2 fork empty-market / exchange-rate-donation exposure.

Read-only JSON-RPC scan (stdlib only, batched). For every comptroller in
analysis/targets.json:
  * getAllMarkets()
  * per market: underlying, getCash, totalSupply, totalBorrows, totalReserves,
    exchangeRateStored, reserveFactorMantissa, decimals/symbol,
    underlying.balanceOf(market)
  * comptroller.markets(market) -> isListed, collateralFactorMantissa
  * comptroller.mintGuardianPaused/borrowGuardianPaused
  * comptroller.oracle().getUnderlyingPrice(market)
  * optional borrowCaps/supplyCaps
Then:
  * fills prices via DefiLlama coins API
  * classifies markets:
      - direct_drain : totalSupply>0 tiny && cash>0 && per-call zero-burn pull material
      - empty_borrow_attack : totalSupply==0 (or <=2 wei) && listed && CF>0 &&
                              mint/borrow unpaused && oracle readable
  * aggregates per protocol+chain: borrowable cash = value an attacker could
    take by donating into a vulnerable market and borrowing everything.

Writes cy-out equivalent: ci-out/scan.json, ci-out/markets.csv,
ci-out/candidates.json, ci-out/scan_summary.json.
"""
import json, os, sys, time, math, re, urllib.request, urllib.error, urllib.parse
from concurrent.futures import ThreadPoolExecutor, as_completed

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
ANALYSIS = os.path.join(ROOT, "analysis")
OUT = os.path.join(ROOT, "ci-out")
os.makedirs(OUT, exist_ok=True)

# ---------------------------------------------------------------- selectors
S = {
    "getAllMarkets": "0xb0772d0b",
    "markets": "0x8e8f294b",
    "mintGuardianPaused_addr": "0x731f0c2b",
    "borrowGuardianPaused_addr": "0x6d154ea5",
    "mintGuardianPaused": "0x5dce0515",       # fallback no-arg (some forks)
    "borrowGuardianPaused": "0x9530f644",     # fallback no-arg (some forks)
    "getCash": "0x3b1d21a2",
    "totalSupply": "0x18160ddd",
    "totalBorrows": "0x47bd3718",
    "totalReserves": "0x8f840ddd",
    "exchangeRateStored": "0x182df0f5",
    "reserveFactorMantissa": "0x173b9904",
    "underlying": "0x6f307dc3",
    "decimals": "0x313ce567",
    "symbol": "0x95d89b41",
    "name": "0x06fdde03",
    "accrualBlockNumber": "0x6c540baf",
    "admin": "0xf851a440",
    "oracle": "0x7dc0d1d0",
    "priceOracle": "0x2630c12f",
    "getUnderlyingPrice": "0xfc57d4df",
    "borrowCaps": "0x4a584432",
    "supplyCaps": "0x02c3bcbb",
    "supplyCap": "0x05d79c14",   # some forks name it supplyCap(address)
    "borrowCap": "0xcb208443",
    "paused": "0x5c975abb",
    "closeFactor": "0xe8755446",
    "liquidationIncentive": "0x4ada90af",
}
BAL = "0x70a08231"
ZERO_ADDR = "0x0000000000000000000000000000000000000000"
EEE = "0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee"
NATIVE = {  # wrapped-native for pricing CEther-style markets
    "ethereum": "0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2",
    "bsc": "0xbb4cdb9cbd36b01bd1cbaebf2de08d9173bc095c",
    "avax": "0xb31f66aa3c1e785363f0875a1b74e27b85fd66c7",
    "polygon": "0x0d500b1d8e8ef31e21c99d1db9a6444d3adf1270",
    "fantom": "0x21be370d5312f44cb42ce377bc9b8a0cef1a4c83",
    "sonic": "0x039e2fb66102314ce7b64ce5ce3e5183bc94ad38",
    "arbitrum": "0x82af49447d8a07e3bd95bd0d56f35241523fbab1",
    "optimism": "0x4200000000000000000000000000000000000006",
    "base": "0x4200000000000000000000000000000000000006",
    "cronos": "0x5c7f8a570d578ed84e63fdfa7b1ee72deae1ae23",
    "moonbeam": "0xacc15dc74880c9944775448304b263d191c6077f",
    "moonriver": "0x98878b06940ae243284ca214f92bb71a2b032b8a",
    "zksync": "0x5aea5775959fbc2557cc8789bc1bf90a239d9a91",
    "linea": "0xe5d7c2a44ffddf6b295a15c148167daaaf5cf34f",
    "scroll": "0x5300000000000000000000000000000000000004",
    "mantle": "0xdeaddeaddeaddeaddeaddeaddeaddeaddead1111",
    "mode": "0x4200000000000000000000000000000000000006",
    "metis": "0x75cb093e4d61d2a2e65d8e0bbb01de8d89b53481",
    "kava": "0xc86c7c0efbd6a49b35e8714c5f59d99de09a225b",
    "flare": "0x1d80c49bbbcd1c0911346656b529df9e5c2f783d",
    "fuse": "0x0be9e53fd7edac9f859882afdda116645287c629",
    "rsk": "0x542fda317318ebf1d3deaf76e0b632741a7e677d",
    "taiko": "0xa51894664a773981c6c112c43ce576f315d5b1b6",
    "blast": "0x4300000000000000000000000000000000000004",
    "core": "0x40375c92d9faf44d2f9db9bd9ba41a3317a2404f",
    "sei": "0xe30fedd158a2e3b13e9badaeabafc5516e95e8c7",
    "klaytn": "0x19aac5f612f524b754ca7e7c41cbfa2e981a4432",  # WKAIA-ish (best effort)
    "gnosis": "0x6a023ccd1ff6f2045c3309768ead9e68f978f6e1",
    "opbnb": "0x4200000000000000000000000000000000000006",
    "unichain": "0x4200000000000000000000000000000000000006",
    "berachain": "0x6969696969696969696969696969696969696969",
    "manta": "0x0f0bdb8357e065a3e601da91ba4ce915081890d8",
    "bob": "0x4200000000000000000000000000000000000006",
    "ink": "0x4200000000000000000000000000000000000006",
    "soneium": "0x4200000000000000000000000000000000000006",
    "morph": "0x5300000000000000000000000000000000000011",
    "lisk": "0x4200000000000000000000000000000000000006",
}
# DefiLlama coins chain keys
LLAMA_CHAIN = {
    "ethereum": "ethereum", "bsc": "bsc", "arbitrum": "arbitrum", "polygon": "polygon",
    "base": "base", "optimism": "optimism", "fantom": "fantom", "cronos": "cronos",
    "moonriver": "moonriver", "sonic": "sonic", "avax": "avax", "moonbeam": "moonbeam",
    "aurora": "aurora", "zksync": "era", "linea": "linea", "scroll": "scroll",
    "mantle": "mantle", "mode": "mode", "metis": "metis", "kava": "kava", "flare": "flare",
    "fuse": "fuse", "rsk": "rsk", "taiko": "taiko", "blast": "blast", "core": "core",
    "sei": "sei", "klaytn": "klaytn", "harmony": "harmony", "telos": "telos",
    "iotex": "iotex", "evmos": "evmos", "oasis": "oasis", "conflux": "conflux",
    "gnosis": "xdai", "polygon_zkevm": "polygon_zkevm", "opbnb": "op_bnb",
    "manta": "manta", "bob": "bob", "bsquared": "bsquared", "hemi": "hemi",
    "zklink": "zklink", "unichain": "unichain", "berachain": "berachain", "ink": "ink",
    "morph": "morph", "soneium": "soneium", "boba": "boba", "wemix": "wemix",
    "canto": "canto", "lisk": "lisk", "worldchain": "worldchain", "zircuit": "zircuit",
    "bitlayer": "bitlayer", "telos": "telos", "ronin": "ronin", "etc": "ethereum-classic",
    "shimmer": "shimmer", "meter": "meter", "kcc": "kcc", "zilliqa": "zilliqa",
    "bittorrent": "bittorrent", "okc": "okexchain", "apechain": "apechain",
    "xdc": "xdc", "kroma": "kroma", "astar_zkevm": "astar-zkevm", "monad": "monad",
    "plasma": "plasma", "megaeth": "megaeth", "merlin": "merlin", "goat": "goat",
    "rei": "rei", "elastos": "elastos", "neon": "neon", "nibiru": "nibiru",
    "sty": "sty", "qie": "qie", "jbc": "jbc", "lac": "lac", "wan": "wanchain",
    "robinhood": "robinhood",
}
# chain -> RPC endpoints (env var first)
ENV_RPC = {
    "ethereum": ["RPC_URL", "BLOCKPI_RPC_URL", "NODEREAL_ETH_RPC_URL"],
    "arbitrum": ["ARB_RPC_URL"], "bsc": ["BSC_RPC_URL"], "base": ["BASE_RPC_URL"],
    "optimism": ["OP_RPC_URL"], "polygon": ["POLYGON_RPC_URL"],
    "fantom": ["FANTOM_RPC_URL"], "cronos": ["CRONOS_RPC_URL"],
    "moonriver": ["MOONRIVER_RPC_URL"], "gnosis": ["GNOSIS_RPC_URL"],
    "sonic": ["SONIC_RPC_URL"],
}
RPCS = {
    "ethereum": ["https://ethereum-rpc.publicnode.com", "https://eth.drpc.org", "https://1rpc.io/eth", "https://eth.llamarpc.com"],
    "bsc": ["https://bsc-dataseed.binance.org", "https://bsc-rpc.publicnode.com", "https://bsc.drpc.org", "https://1rpc.io/bnb"],
    "arbitrum": ["https://arb1.arbitrum.io/rpc", "https://arbitrum-one-rpc.publicnode.com", "https://arbitrum.drpc.org", "https://1rpc.io/arb"],
    "polygon": ["https://polygon-rpc.com", "https://polygon.drpc.org", "https://polygon-bor-rpc.publicnode.com", "https://1rpc.io/matic", "https://rpc.ankr.com/polygon"],
    "base": ["https://mainnet.base.org", "https://base-rpc.publicnode.com", "https://base.drpc.org", "https://1rpc.io/base"],
    "optimism": ["https://mainnet.optimism.io", "https://optimism-rpc.publicnode.com", "https://optimism.drpc.org", "https://1rpc.io/op"],
    "fantom": ["https://rpcapi.fantom.network", "https://fantom-rpc.publicnode.com", "https://rpc.ftm.tools"],
    "cronos": ["https://evm.cronos.org", "https://cronos-evm-rpc.publicnode.com", "https://cronos.blockpi.network/v1/rpc/public"],
    "moonriver": ["https://rpc.api.moonriver.moonbeam.network", "https://moonriver-rpc.publicnode.com", "https://moonriver.api.onfinality.io/public"],
    "sonic": ["https://rpc.soniclabs.com", "https://sonic-rpc.publicnode.com", "https://sonic.drpc.org"],
    "avax": ["https://api.avax.network/ext/bc/C/rpc", "https://avalanche-c-chain-rpc.publicnode.com", "https://avax.drpc.org", "https://1rpc.io/avax/c"],
    "moonbeam": ["https://rpc.api.moonbeam.network", "https://moonbeam-rpc.publicnode.com", "https://moonbeam.api.onfinality.io/public"],
    "aurora": ["https://mainnet.aurora.dev", "https://aurora.drpc.org", "https://1rpc.io/aurora"],
    "zksync": ["https://mainnet.era.zksync.io", "https://zksync-era-rpc.publicnode.com", "https://1rpc.io/zksync2-era"],
    "linea": ["https://rpc.linea.build", "https://linea-rpc.publicnode.com", "https://1rpc.io/linea"],
    "scroll": ["https://rpc.scroll.io", "https://scroll-rpc.publicnode.com", "https://1rpc.io/scroll"],
    "mantle": ["https://rpc.mantle.xyz", "https://mantle-rpc.publicnode.com", "https://1rpc.io/mantle"],
    "mode": ["https://mainnet.mode.network", "https://mode-rpc.publicnode.com", "https://1rpc.io/mode"],
    "metis": ["https://andromeda.metis.io/?owner=1088", "https://metis-rpc.publicnode.com", "https://1rpc.io/metis"],
    "kava": ["https://evm.kava.io", "https://kava-evm-rpc.publicnode.com", "https://kava.drpc.org"],
    "flare": ["https://flare-api.flare.network/ext/C/rpc", "https://flare-rpc.publicnode.com", "https://rpc.ankr.com/flare"],
    "fuse": ["https://rpc.fuse.io", "https://fuse-rpc.publicnode.com", "https://fuse.drpc.org"],
    "rsk": ["https://public-node.rsk.co", "https://rsk-rpc.publicnode.com", "https://rootstock.drpc.org"],
    "taiko": ["https://rpc.taiko.xyz", "https://taiko-rpc.publicnode.com", "https://rpc.ankr.com/taiko"],
    "blast": ["https://rpc.blast.io", "https://blast-rpc.publicnode.com", "https://blast.drpc.org"],
    "core": ["https://rpc.coredao.org", "https://core-rpc.publicnode.com", "https://1rpc.io/core"],
    "sei": ["https://evm-rpc.sei-apis.com", "https://sei-evm-rpc.publicnode.com", "https://1rpc.io/sei"],
    "klaytn": ["https://public-en.node.kaia.io", "https://kaia.blockpi.network/v1/rpc/public", "https://klaytn.drpc.org"],
    "harmony": ["https://api.harmony.one", "https://harmony-0-rpc.gateway.pokt.network", "https://1rpc.io/one"],
    "telos": ["https://mainnet.telos.net/evm", "https://telos-evm-rpc.publicnode.com", "https://rpc.ankr.com/telos"],
    "iotex": ["https://babel-api.mainnet.iotex.io", "https://iotex-evm-rpc.publicnode.com", "https://iotex.drpc.org"],
    "evmos": ["https://evmos-evm-rpc.publicnode.com", "https://evmos.drpc.org", "https://rpc.ankr.com/evmos"],
    "oasis": ["https://emerald.oasis.io", "https://oasis-emerald-rpc.publicnode.com", "https://1rpc.io/oasis"],
    "conflux": ["https://evm.confluxrpc.com", "https://conflux-espace-rpc.publicnode.com", "https://conflux-rpc.publicnode.com"],
    "gnosis": ["https://rpc.gnosischain.com", "https://gnosis-rpc.publicnode.com", "https://1rpc.io/gnosis"],
    "polygon_zkevm": ["https://zkevm-rpc.com", "https://polygon-zkevm-rpc.publicnode.com", "https://1rpc.io/polygon/zkevm"],
    "opbnb": ["https://opbnb-mainnet-rpc.bnbchain.org", "https://opbnb-rpc.publicnode.com", "https://1rpc.io/opbnb"],
    "manta": ["https://pacific-rpc.manta.network/http", "https://manta-pacific-rpc.publicnode.com", "https://1rpc.io/manta"],
    "bob": ["https://rpc.gobob.xyz", "https://bob-rpc.publicnode.com", "https://1rpc.io/bob"],
    "bsquared": ["https://rpc.bsquared.network", "https://b2-rpc.publicnode.com", "https://1rpc.io/bsquared"],
    "hemi": ["https://rpc.hemi.network/rpc", "https://hemi-rpc.publicnode.com", "https://1rpc.io/hemi"],
    "zklink": ["https://rpc.zklink.io", "https://zklink-nova-rpc.publicnode.com", "https://1rpc.io/zklink"],
    "unichain": ["https://mainnet.unichain.org", "https://unichain-rpc.publicnode.com", "https://1rpc.io/unichain"],
    "berachain": ["https://rpc.berachain.com", "https://berachain-rpc.publicnode.com", "https://1rpc.io/berachain"],
    "ink": ["https://rpc-gel.inkonchain.com", "https://ink-rpc.publicnode.com", "https://1rpc.io/ink"],
    "morph": ["https://rpc.morphl2.io", "https://morph-rpc.publicnode.com", "https://1rpc.io/morph"],
    "soneium": ["https://rpc.soneium.org", "https://soneium-rpc.publicnode.com", "https://1rpc.io/soneium"],
    "boba": ["https://mainnet.boba.network", "https://boba-rpc.publicnode.com", "https://1rpc.io/boba"],
    "canto": ["https://canto.slingshot.finance", "https://canto-rpc.publicnode.com", "https://1rpc.io/canto"],
    "wemix": ["https://api.wemix.com", "https://wemix-rpc.publicnode.com", "https://1rpc.io/wemix"],
    "lisk": ["https://rpc.api.lisk.com", "https://lisk-rpc.publicnode.com", "https://1rpc.io/lisk"],
    "worldchain": ["https://worldchain-mainnet.g.alchemy.com/public", "https://worldchain-rpc.publicnode.com", "https://1rpc.io/worldchain"],
    "zircuit": ["https://mainnet.zircuit.com", "https://zircuit-rpc.publicnode.com", "https://1rpc.io/zircuit"],
    "bitlayer": ["https://rpc.bitlayer.org", "https://bitlayer-rpc.publicnode.com", "https://1rpc.io/bitlayer"],
    "ronin": ["https://api.roninchain.com/rpc", "https://ronin-rpc.publicnode.com", "https://1rpc.io/ronin"],
    "etc": ["https://etc.rivet.link", "https://ethereum-classic-rpc.publicnode.com", "https://1rpc.io/etc"],
    "shimmer": ["https://json-rpc.evm.shimmer.network", "https://shimmer-evm-rpc.publicnode.com", "https://1rpc.io/shimmer"],
    "meter": ["https://rpc.meter.io", "https://meter-rpc.publicnode.com", "https://1rpc.io/meter"],
    "kcc": ["https://rpc-mainnet.kcc.network", "https://kcc-rpc.publicnode.com", "https://1rpc.io/kcc"],
    "zilliqa": ["https://api.zilliqa.com", "https://evm-rpc.zilliqa.com", "https://1rpc.io/zilliqa"],
    "bittorrent": ["https://rpc.bt.io", "https://bittorrent-rpc.publicnode.com", "https://1rpc.io/btt"],
    "okc": ["https://exchainrpc.okex.org", "https://okc-rpc.publicnode.com", "https://1rpc.io/okc"],
    "apechain": ["https://rpc.apechain.com/http", "https://apechain-rpc.publicnode.com", "https://1rpc.io/apechain"],
    "xdc": ["https://rpc.xinfin.network", "https://xdc-rpc.publicnode.com", "https://1rpc.io/xdc"],
    "kroma": ["https://api.kroma.network", "https://kroma-rpc.publicnode.com", "https://1rpc.io/kroma"],
    "astar_zkevm": ["https://rpc.astar-zkevm.gelato.digital", "https://astar-zkevm-rpc.publicnode.com", "https://1rpc.io/astar-zkevm"],
    "monad": ["https://rpc.monad.xyz", "https://monad-rpc.publicnode.com", "https://1rpc.io/monad"],
    "plasma": ["https://rpc.plasma.to", "https://plasma-rpc.publicnode.com", "https://1rpc.io/plasma"],
    "megaeth": ["https://rpc.megaeth.com", "https://megaeth-rpc.publicnode.com", "https://1rpc.io/megaeth"],
    "merlin": ["https://rpc.merlinchain.io", "https://merlin-rpc.publicnode.com", "https://1rpc.io/merlin"],
    "goat": ["https://rpc.goat.network", "https://goat-rpc.publicnode.com", "https://1rpc.io/goat"],
    "rei": ["https://rpc.rei.network", "https://rei-rpc.publicnode.com", "https://1rpc.io/rei"],
    "elastos": ["https://rpc.elastos.io", "https://elastos-rpc.publicnode.com", "https://1rpc.io/elastos"],
    "neon": ["https://neon-proxy-mainnet.solana.p2p.org", "https://neon-rpc.publicnode.com", "https://1rpc.io/neon"],
    "nibiru": ["https://evm-rpc.nibiru.fi", "https://nibiru-rpc.publicnode.com", "https://1rpc.io/nibiru"],
    "sty": ["https://rpc.sty.network", "https://1rpc.io/sty"],
    "qie": ["https://rpc1mainnet.qie.digital", "https://rpc.qie.digital", "https://1rpc.io/qie"],
    "jbc": ["https://rpc-l1.jibchain.net", "https://1rpc.io/jbc"],
    "lac": ["https://rpc.lachain.network", "https://1rpc.io/lac"],
    "robinhood": ["https://rpc.robinhoodchain.com", "https://1rpc.io/robinhood"],
    "wan": ["https://gwan-ssl.wandevs.org:56891", "https://wan-rpc.publicnode.com", "https://1rpc.io/wan"],
    "heco": ["https://http-mainnet.hecochain.com", "https://heco-rpc.publicnode.com", "https://1rpc.io/heco"],
}

TINY_WEI = 10**6      # <= 0.01 cToken (8 dec) considered near-empty
CRIT_WEI = 10**3      # <= 0.00001 cToken -> direct claim math is material
UI = 10**18

# ---------------------------------------------------------------- http utils
def http_json(url, payload, timeout=25):
    req = urllib.request.Request(url, data=json.dumps(payload).encode(),
                                 headers={"Content-Type": "application/json",
                                          "User-Agent": "c33-scan/1.0"})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return json.loads(r.read().decode())


class Chain:
    def __init__(self, name):
        self.name = name
        self.urls = []
        for ev in ENV_RPC.get(name, []):
            v = os.environ.get(ev)
            if v:
                self.urls.append(v)
        self.urls += RPCS.get(name, [])
        self.url = None
        self.block = None
        self.fails = 0
        self.dead = False

    def probe(self):
        best = None
        best_ms = None
        for u in self.urls:
            try:
                t0 = time.time()
                r = http_json(u, {"jsonrpc": "2.0", "id": 1, "method": "eth_blockNumber", "params": []}, 10)
                ms = (time.time() - t0) * 1000
                if "result" in r and (best_ms is None or ms < best_ms):
                    best, best_ms = u, ms
                    self.block = int(r["result"], 16)
            except Exception:
                continue
        if best:
            self.url = best
            return True
        return False

    def call_batch(self, calls, retries=2):
        """calls: list[(to,data)] -> list of results (str|None). Chunked, with URL rotation."""
        if not self.urls:
            return [None] * len(calls)
        if self.url is None:
            self.url = self.urls[0]
        last = None
        tries = min(len(self.urls), 2) + 1
        for _ in range(tries):
            last = self._call_batch_url(self.url, calls, retries)
            if any(x is not None for x in last) or len(self.urls) == 1:
                return last
            try:
                idx = self.urls.index(self.url)
            except ValueError:
                idx = 0
            self.url = self.urls[(idx + 1) % len(self.urls)]
            self.fails = 0
        return last if last is not None else [None] * len(calls)

    def _call_batch_url(self, url, calls, retries=2):
        out = [None] * len(calls)
        CH = 8
        for base in range(0, len(calls), CH):
            part = calls[base:base + CH]
            payload = [{"jsonrpc": "2.0", "id": i, "method": "eth_call",
                        "params": [{"to": to, "data": data}, "latest"]}
                       for i, (to, data) in enumerate(part)]
            got = False
            for attempt in range(retries + 1):
                try:
                    r = http_json(url, payload, 20)
                    if isinstance(r, dict):
                        r = [r]
                    for item in r:
                        i = item.get("id")
                        try:
                            i = int(i)
                        except Exception:
                            continue
                        if i < 0 or i >= len(part):
                            continue
                        res = item.get("result")
                        if res and res != "0x":
                            out[base + i] = res
                    got = True
                    break
                except Exception:
                    if attempt < retries:
                        time.sleep(0.8 * (attempt + 1))
                        continue
                    break
            if not got:
                # single-call fallback for this chunk
                for j, (to, data) in enumerate(part):
                    try:
                        r = http_json(url, {"jsonrpc": "2.0", "id": 1, "method": "eth_call",
                                            "params": [{"to": to, "data": data}, "latest"]}, 15)
                        if "result" in r and r["result"] and r["result"] != "0x":
                            out[base + j] = r["result"]
                    except Exception:
                        pass
        return out

    def call(self, to, data, retries=1):
        return self.call_batch([(to, data)], retries)[0]

    def code_one(self, addr):
        """Single eth_getCode; returns True/False/None (None = unreadable)."""
        if not self.url:
            return None
        try:
            r = http_json(self.url, {"jsonrpc": "2.0", "id": 1, "method": "eth_getCode",
                                     "params": [addr, "latest"]}, 15)
            res = r.get("result")
            if res is None:
                return None
            return res not in ("0x", "0x0")
        except Exception:
            return None


# ---------------------------------------------------------------- decoders
def dec_uint(h):
    if not h or h == "0x":
        return None
    try:
        # only the first 32-byte word: some RPCs return over-long/padded results
        return int(h[2:66], 16)
    except Exception:
        return None


def dec_bool(h):
    v = dec_uint(h)
    return None if v is None else (v != 0)


def clean_bool(h):
    """Only accept clean 0/1 bool words; anything else -> None (unknown)."""
    v = dec_uint(h)
    if v is None:
        return None
    return v == 1 if v in (0, 1) else None


def dec_addr(h):
    if not h or len(h) < 42:
        return None
    a = "0x" + h[-40:]
    return a.lower()


def dec_addr_list(h):
    if not h:
        return None
    raw = bytes.fromhex(h[2:])
    if len(raw) < 64:
        return None
    off = int.from_bytes(raw[0:32], "big")
    if off + 32 > len(raw):
        return None
    n = int.from_bytes(raw[off:off + 32], "big")
    if n > 300:
        return None
    out = []
    for i in range(n):
        s = off + 32 * (i + 1)
        if s + 32 > len(raw):
            break
        out.append(("0x" + raw[s + 12:s + 32].hex()).lower())
    return out


def dec_str(h):
    if not h:
        return None
    try:
        raw = bytes.fromhex(h[2:])
        if len(raw) >= 64:
            off = int.from_bytes(raw[0:32], "big")
            if off + 32 <= len(raw):
                ln = int.from_bytes(raw[off:off + 32], "big")
                if 0 < ln <= 64 and off + 32 + ln <= len(raw):
                    return raw[off + 32:off + 32 + ln].decode("utf-8", "ignore").strip("\x00")
        # bytes32 fallback
        b = raw[:32].split(b"\x00")[0]
        if 0 < len(b) <= 32:
            return b.decode("utf-8", "ignore")
    except Exception:
        pass
    return None


# ---------------------------------------------------------------- scan
def scan_target(ch: Chain, tgt):
    rec = dict(tgt)
    rec["status"] = "ok"
    rec["markets"] = []
    comp = tgt["comptroller"]
    mkts = dec_addr_list(ch.call(comp, S["getAllMarkets"]))
    if mkts is None:
        rec["status"] = "getAllMarkets_failed"
        return rec
    rec["market_count"] = len(mkts)
    oracle = dec_addr(ch.call(comp, S["oracle"])) or dec_addr(ch.call(comp, S["priceOracle"]))
    rec["oracle"] = oracle
    close_factor = dec_uint(ch.call(comp, S["closeFactor"]))
    rec["closeFactorMantissa"] = close_factor
    for m in mkts[:80]:
        mr = scan_market(ch, comp, oracle, m)
        rec["markets"].append(mr)

    # code-presence + second-read verification only for suspicious markets
    # (batched reads are unreliable on several public RPCs); cap per target
    sus_list = [mr for mr in rec["markets"]
                if mr.get("emptyBorrowAttack") or mr.get("directDrain") or
                ((mr.get("tinySupply") or mr.get("empty")) and (mr.get("cash") or 0) > 0)]
    sus_list.sort(key=lambda x: (not (x.get("emptyBorrowAttack") or x.get("directDrain")),
                                 -(x.get("cash") or 0)))
    for mr in sus_list[:6]:
        verify_market(ch, comp, oracle, mr)
        if mr.get("emptyBorrowAttack") or mr.get("directDrain"):
            hc = ch.code_one(mr["market"])
            mr["hasCode"] = hc
            if hc is not True:
                mr["emptyBorrowAttack"] = False
                mr["directDrain"] = False
                mr["no_code"] = (hc is False)
        else:
            mr["hasCode"] = None
    for mr in rec["markets"]:
        if "hasCode" not in mr:
            mr["hasCode"] = None

    # aggregates
    cash_usd = 0.0
    borrowable = 0.0
    marked = 0
    for mr in rec["markets"]:
        if mr.get("listed") and mr.get("borrowPaused") is False and mr.get("hasCode") is not False and mr.get("cashUSD") is not None:
            avail = mr["cashUSD"]
            if mr.get("borrowCap") and mr["borrowCap"] > 0:
                raw_avail = max(0, mr["borrowCap"] - (mr.get("totalBorrows") or 0))
                if mr.get("priceRaw"):
                    avail = min(avail, raw_avail * mr["priceRaw"] / 1e36)
            borrowable += max(0.0, avail)
        if mr.get("directDrain"):
            marked += 1
        if mr.get("emptyBorrowAttack"):
            marked += 1
    rec["borrowableCashUSD"] = round(borrowable, 2)
    rec["flaggedMarkets"] = marked
    return rec


def scan_market(ch, comp, oracle, m):
    r = dict(market=m, underlying=None, symbol=None, decimals=None,
             cash=None, totalSupply=None, totalBorrows=None, totalReserves=None,
             exchangeRateStored=None, reserveFactor=None, underlyingBalance=None,
             listed=None, collateralFactor=None, mintPaused=None, borrowPaused=None,
             priceRaw=None, price=None, cashUSD=None, supplyUSD=None,
             borrowCap=None, supplyCap=None, admin=None, accrualBlock=None,
             status="ok")
    calls = [(m, S["underlying"]), (m, S["getCash"]), (m, S["totalSupply"]),
             (m, S["totalBorrows"]), (m, S["totalReserves"]), (m, S["exchangeRateStored"]),
             (m, S["reserveFactorMantissa"]), (m, S["decimals"]), (m, S["symbol"]),
             (m, S["admin"]), (m, S["accrualBlockNumber"]),
             (comp, S["markets"] + m[2:].rjust(64, "0")),
             (comp, S["mintGuardianPaused_addr"] + m[2:].rjust(64, "0")),
             (comp, S["borrowGuardianPaused_addr"] + m[2:].rjust(64, "0")),
             (comp, S["borrowCaps"] + m[2:].rjust(64, "0")),
             (comp, S["supplyCaps"] + m[2:].rjust(64, "0")),
             (comp, S["mintGuardianPaused"]),
             (comp, S["borrowGuardianPaused"])]
    res = ch.call_batch(calls, retries=1)
    (u, cash, ts, tb, tr, rate, rf, cdec, sym, adm, accr, mkt, mgp, bgp, bcap, scap, mgp0, bgp0) = (res + [None] * 18)[:18]
    und = dec_addr(u)
    if und in (ZERO_ADDR, EEE, None):
        und = NATIVE.get(ch.name)
    r["underlying"] = und
    r["cash"] = dec_uint(cash)
    r["totalSupply"] = dec_uint(ts)
    r["totalBorrows"] = dec_uint(tb)
    r["totalReserves"] = dec_uint(tr)
    r["exchangeRateStored"] = dec_uint(rate)
    r["reserveFactor"] = dec_uint(rf)
    r["ctokenDecimals"] = dec_uint(cdec)
    r["decimals"] = None
    if und:
        d2 = dec_uint(ch.call(und, S["decimals"]))
        r["decimals"] = d2
    r["symbol"] = dec_str(sym)
    r["admin"] = dec_addr(adm)
    r["accrualBlock"] = dec_uint(accr)
    if mkt:
        rawm = bytes.fromhex(mkt[2:])
        r["listed"] = dec_bool("0x" + rawm[:32].hex()) if len(rawm) >= 32 else None
        r["collateralFactor"] = dec_uint("0x" + rawm[32:64].hex()) if len(rawm) >= 64 else None
    mp = clean_bool(mgp) if mgp else (clean_bool(mgp0) if mgp0 else None)
    bp = clean_bool(bgp) if bgp else (clean_bool(bgp0) if bgp0 else None)
    r["mintPaused"] = mp
    r["borrowPaused"] = bp
    r["borrowCap"] = dec_uint(bcap)
    r["supplyCap"] = dec_uint(scap)
    bal = dec_uint(ch.call(und, BAL + m[2:].rjust(64, "0"))) if und else None
    r["underlyingBalance"] = bal
    if oracle:
        p = dec_uint(ch.call(oracle, S["getUnderlyingPrice"] + m[2:].rjust(64, "0")))
        r["priceRaw"] = p
        if p and r["decimals"] is not None:
            r["price"] = p / (10 ** (36 - r["decimals"]))
    # -------- classification
    classify(r)
    return r


def classify(r):
    ts = r.get("totalSupply")
    cash = r.get("cash")
    ts_i = ts if ts is not None else 0
    cash_i = cash if cash is not None else 0
    net = cash_i + (r.get("totalBorrows") or 0) - (r.get("totalReserves") or 0)
    r["netAssets"] = net
    if r.get("price") and r.get("decimals") is not None:
        scale = 10 ** r["decimals"]
        if ts is not None:
            r["cashUSD"] = round(cash_i / scale * r["price"], 2)
        if ts_i and r.get("exchangeRateStored"):
            r["supplyUSD"] = round(ts_i * r["exchangeRateStored"] / UI / scale * r["price"], 2)
    r["cf"] = (r.get("collateralFactor") or 0) / 1e18
    free_pull = None
    if ts is not None and ts_i > 0 and net > 0:
        free_pull = min(net // ts_i, cash_i)  # transfer is bounded by available cash
        r["freePullRaw"] = free_pull
        if r.get("price") and r.get("decimals") is not None:
            r["freePullUSD"] = round(free_pull / (10 ** r["decimals"]) * r["price"], 6)
            # drain ~99% needs ~T*ln(100) zero-burn calls
            r["callsToDrain99"] = int(ts_i * 4.605) if ts_i < 10**9 else None
    r["tinySupply"] = bool(ts is not None and ts <= TINY_WEI)
    r["criticalSupply"] = bool(ts is not None and ts <= CRIT_WEI)
    r["empty"] = bool(ts is not None and ts == 0)
    # direct drain: anyone (0 cTokens) can pull free_pull per call; cash must exist
    direct = bool(ts is not None and cash is not None and ts_i > 0 and cash_i > 0 and net > 0
                  and r.get("freePullUSD") and r["freePullUSD"] > 0.01 and ts_i <= 10**7)
    r["directDrain"] = direct
    # empty-market borrow attack: the attacker must own ALL supply, so the market
    # must be empty (totalSupply == 0); T=1 dust owned by others cannot be burned.
    # M's own borrowGuardianPaused is irrelevant (borrows happen from OTHER markets).
    sc = r.get("supplyCap")
    supply_ok = (sc is None) or (sc == 0) or (ts_i < sc)
    empty_ok = bool(ts is not None and cash is not None and ts_i == 0 and r.get("listed")
                    and (r.get("cf") or 0) > 0 and r.get("mintPaused") is False
                    and (r.get("exchangeRateStored") or 0) > 0
                    and supply_ok)
    r["emptyBorrowAttack"] = empty_ok
    if empty_ok and not r.get("price"):
        r["emptyBorrowAttack"] = False
        r["emptyBorrowAttack_blocked"] = "oracle_price_unreadable_or_zero"
    return r


def verify_market(ch, comp, oracle, r):
    """Re-read a suspicious market with a second (rotated) batch; singles only for
    fields that stay null. Batches can misread on some RPCs, so we re-classify."""
    m = r["market"]
    off = m[2:].rjust(64, "0")
    # rotate to a different endpoint for an independent read when possible
    if len(ch.urls) > 1:
        try:
            idx = ch.urls.index(ch.url)
            ch.url = ch.urls[(idx + 1) % len(ch.urls)]
        except ValueError:
            pass
    calls = [(m, S["getCash"]), (m, S["totalSupply"]), (m, S["totalBorrows"]),
             (m, S["totalReserves"]), (m, S["exchangeRateStored"]),
             (comp, S["markets"] + off), (comp, S["mintGuardianPaused_addr"] + off),
             (comp, S["borrowGuardianPaused_addr"] + off)]
    res = ch.call_batch(calls, retries=1)
    vals = {
        "cash": dec_uint(res[0]),
        "totalSupply": dec_uint(res[1]),
        "totalBorrows": dec_uint(res[2]),
        "totalReserves": dec_uint(res[3]),
        "exchangeRateStored": dec_uint(res[4]),
    }
    if res[5]:
        rawm = bytes.fromhex(res[5][2:])
        if len(rawm) >= 32:
            r["listed"] = dec_bool("0x" + rawm[:32].hex())
        if len(rawm) >= 64:
            r["collateralFactor"] = dec_uint("0x" + rawm[32:64].hex())
    mp = clean_bool(res[6])
    bp = clean_bool(res[7])
    if mp is not None:
        r["mintPaused"] = mp
    if bp is not None:
        r["borrowPaused"] = bp
    for k, v in vals.items():
        if v is not None:
            r[k] = v
    if r.get("decimals") is None and r.get("underlying"):
        d = dec_uint(ch.call(r["underlying"], S["decimals"], retries=1))
        if d is not None:
            r["decimals"] = d
    if oracle:
        p = dec_uint(ch.call(oracle, S["getUnderlyingPrice"] + off, retries=1))
        if p is not None:
            r["priceRaw"] = p
            if r.get("decimals") is not None:
                r["price"] = p / (10 ** (36 - r["decimals"]))
    classify(r)
    return r


# ---------------------------------------------------------------- prices
def fill_prices(results):
    pairs = set()
    for tgt in results:
        for mr in tgt.get("markets", []):
            u = mr.get("underlying")
            chn = tgt["chain"]
            if u and chn in LLAMA_CHAIN:
                pairs.add((chn, u))
    price = {}
    plist = sorted(pairs)
    for i in range(0, len(plist), 40):
        chunk = plist[i:i + 40]
        keys = ",".join(f"{LLAMA_CHAIN[c]}:{a}" for c, a in chunk)
        try:
            r = http_json("https://coins.llama.fi/prices/current/" + urllib.parse.quote(keys, safe=":,"), {}, 25)
            for k, v in (r.get("coins") or {}).items():
                price[k.lower()] = v.get("price")
        except Exception:
            pass
        time.sleep(0.2)
    for tgt in results:
        for mr in tgt.get("markets", []):
            u = mr.get("underlying")
            if not u:
                continue
            k = f"{LLAMA_CHAIN.get(tgt['chain'], tgt['chain'])}:{u}".lower()
            p = price.get(k)
            if p and not mr.get("price"):
                mr["price"] = p
                dec = mr.get("decimals")
                scale = 10 ** dec if dec is not None else 1
                if mr.get("cash") is not None:
                    mr["cashUSD"] = round(mr["cash"] / scale * p, 2)
                if mr.get("totalSupply") and mr.get("exchangeRateStored"):
                    mr["supplyUSD"] = round(mr["totalSupply"] * mr["exchangeRateStored"] / UI / scale * p, 2)
                if mr.get("freePullRaw") is not None:
                    mr["freePullUSD"] = round(mr["freePullRaw"] / scale * p, 6)
    return len(price)


def csv_row(tgt, mr):
    return ",".join(str(x) for x in [
        tgt["protocol"], tgt["chain"], tgt["comptroller"], mr.get("market"),
        (mr.get("symbol") or "").replace(",", " "), mr.get("decimals"),
        mr.get("cash"), mr.get("totalSupply"), mr.get("totalBorrows"),
        mr.get("totalReserves"), mr.get("exchangeRateStored"),
        mr.get("cf"), mr.get("listed"), mr.get("mintPaused"), mr.get("borrowPaused"),
        mr.get("price"), mr.get("cashUSD"), mr.get("supplyUSD"),
        mr.get("empty"), mr.get("tinySupply"), mr.get("criticalSupply"),
        mr.get("directDrain"), mr.get("emptyBorrowAttack"), mr.get("freePullUSD"),
    ])


def main():
    targets = json.load(open(os.environ.get("TARGETS_FILE", os.path.join(ANALYSIS, "targets.json"))))
    tgts = targets["targets"]
    cfilt = os.environ.get("CHAIN_FILTER")
    if cfilt:
        tgts = [t for t in tgts if t["chain"] in set(cfilt.split(","))]
    by_chain = {}
    for t in tgts:
        by_chain.setdefault(t["chain"], []).append(t)

    chains = {}
    def probe_one(cn):
        ch = Chain(cn)
        ok = ch.probe()
        return cn, ch, ok

    with ThreadPoolExecutor(max_workers=12) as ex:
        futs = [ex.submit(probe_one, cn) for cn in by_chain]
        for f in as_completed(futs):
            cn, ch, ok = f.result()
            chains[cn] = ch
            print(f"[probe] {cn:16s} {'OK block=' + str(ch.block) if ok else 'NO RPC'}", flush=True)

    results = []
    chain_blocks = {}
    for cn, ch in chains.items():
        if ch.url:
            chain_blocks[cn] = ch.block

    def run_chain(cn):
        ch = chains[cn]
        out = []
        if not ch.url:
            for t in by_chain[cn]:
                r = dict(t); r["status"] = "no_rpc"; r["markets"] = []
                out.append(r)
            return out
        deadline = time.time() + float(os.environ.get("CHAIN_BUDGET_SEC", "900"))
        for t in by_chain[cn]:
            if time.time() > deadline:
                r = dict(t); r["status"] = "chain_budget_exceeded"; r["markets"] = []
                out.append(r)
                continue
            try:
                out.append(scan_target(ch, t))
            except Exception as e:
                r = dict(t); r["status"] = f"error:{type(e).__name__}"; r["markets"] = []
                out.append(r)
        return out

    with ThreadPoolExecutor(max_workers=16) as ex:
        futs = {ex.submit(run_chain, cn): cn for cn in by_chain}
        done = 0
        for f in as_completed(futs):
            cn = futs[f]
            try:
                res = f.result()
            except Exception as e:
                res = [dict(t, status=f"chain_error:{type(e).__name__}", markets=[]) for t in by_chain[cn]]
            results.extend(res)
            done += 1
            nm = sum(len(r.get("markets", [])) for r in res)
            print(f"[scan] {done}/{len(by_chain)} chains done; {cn} markets={nm}", flush=True)

    np = fill_prices(results)

    # post-price reclassification of directDrain (price may have arrived late)
    for tgt in results:
        cashusd = 0.0
        borrowable = 0.0
        flagged = 0
        for mr in tgt.get("markets", []):
            ts_i = mr.get("totalSupply") or 0
            if mr.get("freePullRaw") and mr.get("freePullUSD") and mr["freePullUSD"] > 0.01 and ts_i <= 10**7 and mr.get("hasCode") is not False:
                mr["directDrain"] = True
            if mr.get("directDrain") or mr.get("emptyBorrowAttack"):
                flagged += 1
                cashusd += mr.get("cashUSD") or 0
            if mr.get("listed") and mr.get("borrowPaused") is False and mr.get("hasCode") is not False and mr.get("cashUSD") is not None:
                avail = mr["cashUSD"]
                if mr.get("borrowCap") and mr["borrowCap"] > 0 and mr.get("price"):
                    raw_avail = max(0, mr["borrowCap"] - (mr.get("totalBorrows") or 0))
                    avail = min(avail, raw_avail * mr["price"])
                borrowable += max(0.0, avail)
        tgt["borrowableCashUSD"] = round(borrowable, 2)
        tgt["flaggedMarkets"] = flagged

    cand = []
    for tgt in results:
        bad = []
        for mr in tgt.get("markets", []):
            if mr.get("directDrain") or mr.get("emptyBorrowAttack") or (mr.get("criticalSupply") and mr.get("hasCode") is not False):
                bad.append(mr)
        if bad or (tgt.get("emptyBorrowAttack")):
            cand.append(dict(protocol=tgt["protocol"], chain=tgt["chain"],
                             comptroller=tgt["comptroller"], status=tgt["status"],
                             borrowableCashUSD=tgt.get("borrowableCashUSD"),
                             flagged=[dict(market=m.get("market"), symbol=m.get("symbol"),
                                           hasCode=m.get("hasCode"),
                                           totalSupply=m.get("totalSupply"), cash=m.get("cash"),
                                           cashUSD=m.get("cashUSD"), cf=m.get("cf"),
                                           listed=m.get("listed"), mintPaused=m.get("mintPaused"),
                                           borrowPaused=m.get("borrowPaused"),
                                           empty=m.get("empty"), tiny=m.get("tinySupply"),
                                           directDrain=m.get("directDrain"),
                                           emptyBorrowAttack=m.get("emptyBorrowAttack"),
                                           freePullUSD=m.get("freePullUSD"),
                                           callsToDrain99=m.get("callsToDrain99"),
                                           note=m.get("emptyBorrowAttack_blocked")) for m in bad]))

    # exposure summary
    exposure = []
    for c in cand:
        markets = c["flagged"]
        empty_ready = any(m["emptyBorrowAttack"] for m in markets)
        drain = sum(m.get("cashUSD") or 0 for m in markets if m.get("directDrain"))
        c["mode"] = ("empty_market_borrow" if empty_ready else "") + ("+direct_drain" if drain else "") or "near_empty_only"
        c["directDrainUSD"] = round(drain, 2)
        c["potentialUSD"] = round(drain + (c["borrowableCashUSD"] or 0) if empty_ready else drain, 2)
        exposure.append(c)
    exposure.sort(key=lambda x: -(x["potentialUSD"] or 0))

    summary = dict(
        generated=time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        targets=len(tgts), protocols=len(set(t["protocol"] for t in tgts)),
        chains_scanned=len([c for c in chains if chains[c].url]),
        chains_no_rpc=sorted([c for c in chains if not chains[c].url]),
        chain_blocks=chain_blocks,
        status_counts={},
        markets_total=sum(len(r.get("markets", [])) for r in results),
        empty_markets=sum(1 for r in results for m in r.get("markets", []) if m.get("empty")),
        tiny_markets=sum(1 for r in results for m in r.get("markets", []) if m.get("tinySupply")),
        empty_borrow_attack_markets=sum(1 for r in results for m in r.get("markets", []) if m.get("emptyBorrowAttack")),
        direct_drain_markets=sum(1 for r in results for m in r.get("markets", []) if m.get("directDrain")),
        exposure=exposure,
    )
    from collections import Counter
    sc = Counter(r["status"] for r in results)
    summary["status_counts"] = dict(sc)

    json.dump(dict(summary=summary, results=results), open(os.path.join(OUT, "scan.json"), "w"), indent=1)
    json.dump(summary, open(os.path.join(OUT, "scan_summary.json"), "w"), indent=1)
    json.dump(cand, open(os.path.join(OUT, "candidates.json"), "w"), indent=1)
    with open(os.path.join(OUT, "markets.csv"), "w") as f:
        f.write("protocol,chain,comptroller,market,symbol,decimals,cash,totalSupply,totalBorrows,"
                "totalReserves,exchangeRateStored,cf,listed,mintPaused,borrowPaused,price,cashUSD,"
                "supplyUSD,empty,tinySupply,criticalSupply,directDrain,emptyBorrowAttack,freePullUSD\n")
        for tgt in results:
            for mr in tgt.get("markets", []):
                f.write(csv_row(tgt, mr) + "\n")
    print(json.dumps(summary, indent=1)[:6000])
    return 0


if __name__ == "__main__":
    sys.exit(main())
