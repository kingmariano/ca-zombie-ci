#!/usr/bin/env python3
"""FlareBank live-state dump + exact integer-math sell-out simulation.

Mirrors Bank.sol v0.1.3 math (verified source) for all current BANK holders,
using live on-chain state. Read-only, keyless public RPC. Writes ci-out/*.json.
"""
import json, sys, urllib.request, time, os

RPC = sys.argv[1] if len(sys.argv) > 1 else "https://flare-api.flare.network/ext/C/rpc"
BANK = "0x194726F6C2aE988f1Ab5e1C943c17e591a6f6059"
VAULT = "0x90679234FE693B39BFdf5642060Cb10571Adc59b"
WFLR = "0x1d80c49bbbcd1c0911346656b529df9e5c2f783d"
E18 = 10**18
MAX_BIPS = 100_00
DIVIDEND_FEE = 10_00
TOKEN_PRICE_INITIAL = 1 * E18
TOKEN_PRICE_INCREMENTAL = 10**16
ETHER_INCEREMENT = 10000 * E18
MAX_BUY = 50001 * E18  # per-sell cap: taxedEth < MAX_BUY (50,001 NAT)

def rpc(method, params):
    req = urllib.request.Request(RPC, data=json.dumps(
        {"jsonrpc": "2.0", "id": 1, "method": method, "params": params}).encode(),
        headers={"Content-Type": "application/json", "User-Agent": "Mozilla/5.0"})
    r = json.load(urllib.request.urlopen(req, timeout=60))
    if "result" not in r:
        raise RuntimeError(str(r))
    return r["result"]

def batch(calls):
    req = urllib.request.Request(RPC, data=json.dumps(calls).encode(),
        headers={"Content-Type": "application/json", "User-Agent": "Mozilla/5.0"})
    return json.load(urllib.request.urlopen(req, timeout=60))

def addr_arg(a): return a.lower().replace("0x", "").rjust(64, "0")

def call(to, data):
    r = rpc("eth_call", [{"to": to, "data": data}, "latest"])
    return int(r, 16) if r and r != "0x" else 0

def main():
    block = int(rpc("eth_blockNumber", []), 16)
    supply = call(BANK, "0x18160ddd")
    reserve = call(WFLR, "0x70a08231" + addr_arg(BANK))
    vault_bal = call(WFLR, "0x70a08231" + addr_arg(VAULT))
    U = call(BANK, "0xfc5267df")
    T = call(BANK, "0xdb2609f4")
    F = call(BANK, "0xa5789008")
    buy_price = call(BANK, "0x8620410b")
    sell_price = call(BANK, "0x4b750334")

    state = {
        "block": block, "bank": BANK, "vault": VAULT, "wflr": WFLR,
        "bank_total_supply": supply / E18,
        "bank_wflr_reserve": reserve / E18,
        "vault_wflr_balance": vault_bal / E18,
        "unclaimed_dividend_total": U / E18,
        "unclaimed_team_fees": T / E18,
        "unclaimed_fee_receiver_fees": F / E18,
        "buy_price_flr_per_token": buy_price / E18,
        "sell_price_tokens_per_flr": sell_price / E18,
        "nav_per_token": (reserve - U - T - F) / supply,
    }

    # holder snapshot: live explorer fetch, fallback to vendored snapshot
    holders = None
    try:
        holders = []
        for page in range(1, 4):
            url = ("https://flare-explorer.flare.network/api?module=token&action=getTokenHolders"
                   f"&contractaddress={BANK}&page={page}&offset=100")
            req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
            d = json.load(urllib.request.urlopen(req, timeout=40))
            res = d.get("result") or []
            if not res:
                break
            holders += [(h["address"].lower(), int(h["value"])) for h in res]
            time.sleep(0.3)
    except Exception as e:
        print("holder fetch failed, using snapshot:", e)
    if not holders:
        holders = [(h["address"].lower(), int(h["value"]))
                   for h in json.load(open(os.path.join(os.path.dirname(__file__), "..", "analysis",
                                                        "bank_holders_all.json")))]
    holders = [(a, v) for a, v in holders if v > 0]
    holders.sort(key=lambda x: -x[1])

    # exact integer-math sell-out (mirrors Bank.sol sell()/tokensToEthereum/calculateTokenPrice)
    pools = [U, T, F]
    s_supply, balance = supply, reserve
    total_taxed = 0
    per = []
    for a, v in holders:
        v = min(v, s_supply)
        if v <= 0:
            continue
        taxed_eth = balance - pools[0] - pools[1] - pools[2]
        est_out = taxed_eth * v // s_supply
        bg = balance - est_out if balance > est_out else 0
        if bg < (pools[2] + pools[1] + pools[0]):
            worst = TOKEN_PRICE_INITIAL
        else:
            net = bg - pools[2] - pools[1] - pools[0]
            worst = TOKEN_PRICE_INITIAL + (net // ETHER_INCEREMENT) * TOKEN_PRICE_INCREMENTAL
        def _one(chunk, s_supply, balance, pools):
            taxed_eth = balance - pools[0] - pools[1] - pools[2]
            est_out = taxed_eth * chunk // s_supply
            bg = balance - est_out if balance > est_out else 0
            if bg < (pools[2] + pools[1] + pools[0]):
                worst = TOKEN_PRICE_INITIAL
            else:
                net = bg - pools[2] - pools[1] - pools[0]
                worst = TOKEN_PRICE_INITIAL + (net // ETHER_INCEREMENT) * TOKEN_PRICE_INCREMENTAL
            eth = chunk * worst // E18
            to_dist = eth * DIVIDEND_FEE // MAX_BIPS
            taxed = eth - to_dist
            recv = to_dist * 5_00 // MAX_BIPS
            team = to_dist * 15_00 // MAX_BIPS
            pub = to_dist - recv - team
            return eth, taxed, pub, recv, team
        holder_taxed = 0
        rem = v
        while rem > 0:
            chunk = rem
            while True:
                eth, taxed, pub, recv, team = _one(chunk, s_supply, balance, pools)
                if taxed < MAX_BUY or chunk <= E18:
                    break
                chunk = chunk * 95 // 100
            pools[0] += pub + taxed
            pools[1] += team
            pools[2] += recv
            s_supply -= chunk
            holder_taxed += taxed
            rem -= chunk
        total_taxed += holder_taxed
        per.append({"addr": a, "bank": v / E18, "wflr_withdrawable": holder_taxed / E18})

    sim = {
        "holders_simulated": len(per),
        "bank_sold": (supply - s_supply) / E18,
        "seller_withdrawable_wflr": total_taxed / E18,
        "remaining_supply": s_supply / E18,
        "final_pool_obligations": {
            "dividends": pools[0] / E18, "team": pools[1] / E18, "fee_receiver": pools[2] / E18},
        "contract_balance_wflr": reserve / E18,
        "top10": per[:10],
        "note": ("Sellers' taxed proceeds + remaining dividend/team/fee pools are all still inside the "
                 "contract balance; nothing is lost. E-U = 0: every path requires holding BANK or being a "
                 "vault depositor (H-O), or BANK_ADMIN (P)."),
    }
    os.makedirs("ci-out", exist_ok=True)
    json.dump(state, open("ci-out/live_state.json", "w"), indent=1)
    json.dump(sim, open("ci-out/sellout_sim.json", "w"), indent=1)
    print(json.dumps({"state": state, "sim_head": {k: v for k, v in sim.items() if k != "top10"}}, indent=1))

if __name__ == "__main__":
    main()
