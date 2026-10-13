#!/usr/bin/env python3
"""Per-chain Hyphen state dump: TokenManager support flags, providers accounting,
pool balances. Public keyless RPCs only. Output: JSON to stdout."""
import json, sys, urllib.request
from eth_utils import keccak

RPCS = {"ethereum":"https://ethereum-rpc.publicnode.com","polygon":"https://polygon-bor-rpc.publicnode.com","bsc":"https://bsc-rpc.publicnode.com","optimism":"https://optimism-rpc.publicnode.com","arbitrum":"https://arbitrum-one-rpc.publicnode.com","avalanche":"https://api.avax.network/ext/bc/C/rpc"}
POOL = {"ethereum":"0x2a5c2568b10a0e826bfa892cf21ba7218310180b","polygon":"0x2a5c2568b10a0e826bfa892cf21ba7218310180b","avalanche":"0x2a5c2568b10a0e826bfa892cf21ba7218310180b","bsc":"0x94d3e62151b12a12a4976f60edc18459538faf08","optimism":"0x856cb5c3cbbe9e2e21293a644aa1f9363cee11e8","arbitrum":"0x856cb5c3cbbe9e2e21293a644aa1f9363cee11e8"}
PROV = {"ethereum":"0xebab24f13de55789ec1f3ffe99a285754e15f7b9","polygon":"0xebab24f13de55789ec1f3ffe99a285754e15f7b9","avalanche":"0xebab24f13de55789ec1f3ffe99a285754e15f7b9","bsc":"0x279ac60785a2fcb85550eb243b9a42a543171cc7","optimism":"0xb4778f5aefeb4605ed96e893417271d4a55e32ee","arbitrum":"0xb4778f5aefeb4605ed96e893417271d4a55e32ee"}
TM = {"ethereum":"0xe6dbf5861ed9828594af4c6ea6356411c3a0b168","polygon":"0x79e559ac5b499a5676e28f0074e29763f6c2a27e","bsc":"0x13a4cc0750296bb72eb0006febec306551a4f472","optimism":"0x4c5ccff7fa764ce150f07dd9ec9805a7c9260be1","arbitrum":"0x4c5ccff7fa764ce150f07dd9ec9805a7c9260be1","avalanche":"0x06c8863317f7c53aeb63ba5465569f28b3406f13"}
NATIVE = "0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE"

TOKENS = {
 "ethereum": {
   "NATIVE": NATIVE, "USDC":"0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48", "USDT":"0xdac17f958d2ee523a2206206994597c13d831ec7",
   "BICO":"0xf17e65822b568b3903685a7c9f496cf7656cc6c2", "WETH":"0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2",
   "MATIC":"0x7d1afa7b718fb893db30a3abc0cfc608aacfebb0", "crvUSD":"0xf939e0a03fb07f59a73314e73794be0e57ac1b4e"},
 "polygon": {
   "NATIVE": NATIVE, "WETH":"0x7ceb23fd6bc0add59e62ac25578270cff1b9f619", "USDCe":"0x2791bca1f2de4661ed88a30c99a7a9449aa84174",
   "USDT":"0xc2132d05d31c914a87c6611c10748aeb04b58e8f", "DAI":"0x8f3cf7ad23cd3cadbd9735aff958023239c6a063",
   "WMATIC":"0x0d500b1d8e8ef31e21c99d1db9a6444d3adf1270"},
 "bsc": {
   "NATIVE": NATIVE, "USDT":"0x55d398326f99059ff775485246999027b3197955", "ETH":"0x2170ed0880ac9a755fd29b2688956bd959f933f8",
   "USDC":"0x8ac76a51cc950d9822d68b83fe1ad97b32cd580d"},
 "optimism": {
   "NATIVE": NATIVE, "USDT":"0x94b008aa00579c1307b0ef2c499ad98a8ce58e58", "USDC":"0x7f5c764cbc14f9669b88837ca1490cca17c31607"},
 "arbitrum": {
   "NATIVE": NATIVE, "USDC":"0xff970a61a04b1ca14834a43f5de4533ebddb5cc8", "BICO":"0xa68ec98d7ca870cf1dd0b00ebbb7c4bf60a8e74d",
   "USDT":"0xfd086bc7cd5c481dcc9c85ebe478a1c0b69fcbb9"},
 "avalanche": {
   "WETHe":"0x49d5c2bdffac6ce2bfdb6640f4f80f226bc10bab", "USDCe":"0xa7d7079b0fead91f3e65f86e8915cb59c1a4c664",
   "USDTe":"0xc7198437980c041c805a1edcba50c1ce5db95118", "NATIVE": NATIVE},
}

def rpc(url, method, params):
    body = json.dumps({"jsonrpc":"2.0","id":1,"method":method,"params":params}).encode()
    req = urllib.request.Request(url, data=body, headers={"Content-Type":"application/json","User-Agent":"Mozilla/5.0"})
    return json.load(urllib.request.urlopen(req, timeout=40))["result"]

def map_slot(addr, slot):
    key = bytes.fromhex(addr[2:].rjust(64,"0"))
    return "0x"+keccak(key + slot.to_bytes(32,"big")).hex()

def call(url, to, data):
    return rpc(url, "eth_call", [{"to":to,"data":data}, "latest"])

def enc_sig(sig):
    return "0x"+keccak(sig.encode()).hex()[:8]

def main():
    out = {}
    for chain, url in RPCS.items():
        entry = {"chain":chain,"block":int(rpc(url,"eth_blockNumber",[]),16),"tokens":{}}
        pool = POOL[chain]; prov = PROV[chain]; tm = TM[chain]
        entry["pool_native_wei"] = int(rpc(url,"eth_getBalance",[pool,"latest"]),16)
        entry["prov_native_wei"] = int(rpc(url,"eth_getBalance",[prov,"latest"]),16)
        for name, tok in TOKENS[chain].items():
            t = {"addr":tok}
            # tokensInfo(token) on TokenManager -> (uint transferOverhead, bool supported, uint eq, uint max, (uint min,uint max))
            r = call(url, tm, enc_sig("tokensInfo(address)")+tok[2:].lower().rjust(64,"0"))
            if r and r != "0x":
                b = bytes.fromhex(r[2:])
                t["supported"] = bool(int.from_bytes(b[32:64],"big"))
                t["equilibriumFee"] = int.from_bytes(b[64:96],"big")
                t["maxFee"] = int.from_bytes(b[96:128],"big")
                t["transferMin"] = int.from_bytes(b[128:160],"big")
                t["transferMax"] = int.from_bytes(b[160:192],"big")
            # providers accounting
            for mname, slot in [("totalReserve",256),("totalLiquidity",257),("currentLiquidity",258),("totalLPFees",259),("totalSharesMinted",260)]:
                v = rpc(url,"eth_getStorageAt",[prov,map_slot(tok,slot),"latest"])
                t[mname] = int(v,16)
            # pool balance
            if name == "NATIVE":
                t["pool_balance"] = entry["pool_native_wei"]
                t["decimals"] = 18
            else:
                r = call(url, tok, enc_sig("balanceOf(address)")+pool[2:].rjust(64,"0"))
                t["pool_balance"] = int(r,16) if r and r!="0x" else 0
                r = call(url, tok, enc_sig("decimals()"))
                t["decimals"] = int(r,16) if r and r!="0x" else 18
            entry["tokens"][name] = t
        out[chain] = entry
    json.dump(out, sys.stdout, indent=1)

if __name__ == "__main__":
    main()
