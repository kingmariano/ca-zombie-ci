"""Multi-chain Hundred-class attack scan + oracle staleness check for WePiggy markets."""
import json, math, sys, urllib.request

def llama_prices(chain, addrs):
    if not addrs:
        return {}
    q = ",".join(f"{chain}:{a}" for a in addrs)
    url = f"https://coins.llama.fi/prices/current/{q}"
    with urllib.request.urlopen(url, timeout=30) as r:
        d = json.load(r)
    out = {}
    for k, v in d.get("coins", {}).items():
        out[k.split(":")[-1].lower()] = v["price"]
    return out

DEC = {
    "pETH": 18, "pDAI": 18, "pUSDT": 6, "pUSDC": 6, "pWBTC": 8, "pUNI": 18,
    "pYFII": 18, "pLRC": 18, "pxLON": 18, "pRAI": 18,
}

def load_eth():
    d = json.load(open("/home/heisenberg/CA/wepiggy/analysis/eth-markets.json"))
    addrs = [m["underlying"] for m in d["markets"] if m["underlying"]]
    px = llama_prices("ethereum", addrs)
    mks = []
    for m in d["markets"]:
        dec = DEC.get(m["symbol"], 18)
        # oracle price mantissa is USD * 1e(36-dec)
        op = m["oraclePrice"]
        if m["underlying"] is None:
            real = px.get("0x0000000000000000000000000000000000000000") or px.get("0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee")
        else:
            real = px.get(m["underlying"].lower())
        oracle_usd = op / 10 ** (36 - dec) if op else None
        supply_und = (m["totalSupply"] * m["exchangeRateStored"] / 1e18) / 10 ** dec if m["totalSupply"] else 0
        cash_und = (m["cash"] or 0) / 10 ** dec
        usd = real if real else oracle_usd
        mks.append(dict(chain="ethereum", symbol=m["symbol"], cToken=m["cToken"], T_raw=m["totalSupply"],
                        cf=(m["collateralFactorMantissa"] or 0) / 1e18,
                        cash_usd=cash_und * (usd or 0), V_usd=supply_und * (usd or 0),
                        oracle_usd=oracle_usd, real_usd=real,
                        mint_paused=m["mintGuardianPaused"], borrow_paused=m["borrowGuardianPaused"]))
    return mks, d

def load_child(path, chain, symbol_dec=None):
    d = json.load(open(path))
    mks = []
    for m in d["markets"]:
        # children provided supply_usd/cash_usd in op/bsc; arb needs compute
        if "supply_usd" in m:
            V = m["supply_usd"] or 0; C = m["cash_usd"] or 0; pu = m.get("price_usd")
        else:
            dec = (symbol_dec or {}).get(m["symbol"], 18)
            op = m["oraclePrice"]
            pu = op / 10 ** (36 - dec) if op else None
            V = (m["totalSupply"] * m["exchangeRateStored"] / 1e18) / 10 ** dec * (pu or 0)
            C = (m["cash"] or 0) / 10 ** dec * (pu or 0)
        mks.append(dict(chain=chain, symbol=m["symbol"], cToken=m["cToken"], T_raw=m["totalSupply"],
                        cf=(m["collateralFactorMantissa"] or 0) / 1e18, cash_usd=C, V_usd=V,
                        oracle_usd=pu, real_usd=None,
                        mint_paused=(m.get("pTokenMintGuardianPaused") if m.get("pTokenMintGuardianPaused") is not None else m.get("mintGuardianPaused")),
                        borrow_paused=(m.get("pTokenBorrowGuardianPaused") if m.get("pTokenBorrowGuardianPaused") is not None else m.get("borrowGuardianPaused"))))
    return mks, d

def sim_one(V, T, cash, cf, B, D, X):
    if T <= 0 or V <= 0 or cf <= 0 or B <= 0:
        return None
    r0 = V / T
    t = D / r0
    S = T + t
    rate2 = (V + D + X) / S
    if cf * t * rate2 < B * (1 - 1e-9):
        return None
    k = max(1, math.ceil(B / (cf * rate2)))
    if k > t:
        return None
    r = t - k
    R = min(cash + D + X, (r + 1) * rate2)
    return R + B - D - X, R, B, k

def scan(m, gridD, gridX):
    # other markets' borrowable cash (listed, borrow open)
    Bmax = sum(o["cash_usd"] for o in ALL if o is not m and not o["borrow_paused"] and o["cf"] >= 0 and o["cash_usd"] > 0)
    # borrowing is not gated on the borrowed market's CF; only listed+pause. all our mks are listed.
    Bmax = sum(o["cash_usd"] for o in ALL if o is not m and not o["borrow_paused"])
    best = None
    for D in gridD:
        for X in gridX:
            out = sim_one(m["V_usd"], m["T_raw"], m["cash_usd"], m["cf"], Bmax, D, X)
            if out is None:
                continue
            if best is None or out[0] > best[0]:
                best = (out[0], D, X, out[1], Bmax, out[3])
    return best, Bmax

if __name__ == "__main__":
    eth, eth_raw = load_eth()
    arb, _ = load_child("/home/heisenberg/CA/wepiggy/analysis/arb-markets.json", "arbitrum",
                        {"pETH":18,"pWBTC":8,"pUSDC":6,"pUSDT":6,"pLINK":18,"pDAI":18})
    op, _ = load_child("/home/heisenberg/CA/wepiggy/analysis/op-markets.json", "optimism")
    bsc, _ = load_child("/home/heisenberg/CA/wepiggy/analysis/bsc-markets.json", "bsc")
    ALL = eth + arb + op + bsc
    print("=== oracle staleness (ETH) ===")
    for m in eth:
        if m["real_usd"]:
            div = (m["oracle_usd"] / m["real_usd"] - 1) * 100
            print(f"  {m['symbol']:8s} oracle=${m['oracle_usd']:.4f} real=${m['real_usd']:.4f} div={div:+.2f}%")
        else:
            print(f"  {m['symbol']:8s} oracle=${m['oracle_usd']} real=N/A")
    gridD = [0, 1e2, 1e3, 1e4, 1e5, 1e6, 1e7, 1e8]
    gridX = [0, 1e2, 1e3, 1e4, 1e5, 1e6, 1e7, 1e8, 1e9, 1e10]
    print("\n=== Hundred-class scan (net USD; positive = extractable) ===")
    for m in ALL:
        best, Bmax = scan(m, gridD, gridX)
        r0 = m["V_usd"] / m["T_raw"] if m["T_raw"] else 0
        line = f"{m['chain']:8s} {m['symbol']:8s} T={m['T_raw']:.3e} V=${m['V_usd']:.0f} cash=${m['cash_usd']:.0f} cf={m['cf']:.2f} r0={r0:.3e}$/raw Bmax=${Bmax:.0f}"
        if best:
            line += f" -> best net=${best[0]:.2f} (D=${best[1]:.0f} X=${best[2]:.0f} R=${best[3]:.0f} k={best[5]})"
        else:
            line += " -> INFEASIBLE"
        print(line)
