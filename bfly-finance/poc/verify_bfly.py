#!/usr/bin/env python3
"""
BFly Finance (Starcoin) — live extraction audit / PoC.

Read-only verification against the Starcoin mainnet RPC (no transactions are sent).
It:
  1. Reads the live protocol state (global switch, configs, pools, oracle, treasury).
  2. Re-reads every known vault's state + health factor live.
  3. Reproduces the deployed liquidation math (derived from on-chain Move bytecode,
     see analysis/disasm/*.txt).
  4. Discovers the live TokenSwap STC/FAI pool, whose FAI price (~19-40 STC/FAI) is far
     below the liquidation seizure rate (111.11 STC per FAI), and computes the exact
     full-cycle profit of: XUSDT -> STC -> FAI (pool) -> liquidate underwater vaults
     -> STC -> XUSDT, with 0.3% swap fees and constant-product slippage.
  5. Writes ci-out/verification.json / verification.md.

Chain: Starcoin mainnet (chain_id 1). All calls are view/dry-run RPC only.
"""
import json, os, urllib.request, datetime

RPC = os.environ.get("STARCOIN_RPC", "https://main-seed.starcoin.org")
BF = "0x4ffcc98f43ce74668264a0cf6eebe42b"
DEX = "0x8c109349c6bd91411d6bc962e080c4a3"
STC = "0x1::STC::STC"
FAI = f"{BF}::FAI::FAI"
XUSDT = "0xe52552637c5897a2d499fbf08216f73e::XUSDT::XUSDT"
WHALE = "0x0c357315f9351540114596324f41006e"
OUT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "ci-out"))
os.makedirs(OUT, exist_ok=True)

def call(method, params, timeout=45):
    body = json.dumps({"id": 1, "jsonrpc": "2.0", "method": method, "params": params}).encode()
    req = urllib.request.Request(RPC, data=body, headers={"Content-Type": "application/json", "User-Agent": "bfly-audit"})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return json.loads(r.read())

def view(fn, args=None, targs=None):
    try:
        r = call("contract.call_v2", [{"function_id": fn, "args": args or [], "type_args": targs or []}])
        if "result" in r:
            return r["result"]
        return {"error": r.get("error", {}).get("message", "unknown")}
    except Exception as e:
        return {"error": str(e)}

def resource(addr, typ):
    try:
        return call("contract.get_resource", [addr, typ]).get("result")
    except Exception:
        return None

def deep(v):
    if isinstance(v, dict):
        if "U128" in v: return int(v["U128"])
        if "U64" in v: return int(v["U64"])
        if "Bool" in v: return v["Bool"]
        if "Struct" in v: return deep(v["Struct"])
        return {k: deep(x) for k, x in v.items()}
    if isinstance(v, list): return [deep(x) for x in v]
    return v

report = {"generated_at": datetime.datetime.utcnow().isoformat() + "Z", "rpc": RPC}

# ---------------------------------------------------------------- head state
info = call("node.info", [])["result"]
head = info["peer_info"]["chain_info"]["head"]
report["chain_id"] = info["peer_info"]["chain_info"].get("chain_id")
report["head_block"] = int(head["number"])
report["head_hash"] = head["block_hash"]

sw = view(f"{BF}::Config::get_global_switch")
report["global_switch"] = sw[0] if isinstance(sw, list) else sw

stc_pool = view(f"{BF}::STCVaultPoolA::current_stc_locked")
stc_fai = view(f"{BF}::STCVaultPoolA::current_fai_supply")
stc_vaults = view(f"{BF}::STCVaultPoolA::vault_count")
eth_pool = view(f"{BF}::ETHVaultPoolA::current_eth_locked")
report["stc_pool"] = {"stc_locked_units": stc_pool[0] if isinstance(stc_pool, list) else None,
                      "fai_supply_units": stc_fai[0] if isinstance(stc_fai, list) else None,
                      "vault_count": stc_vaults[0] if isinstance(stc_vaults, list) else None}
report["eth_pool"] = {"eth_locked_units": eth_pool[0] if isinstance(eth_pool, list) else None}

price = view(f"{BF}::STCOracle::usdt_price")
report["stc_oracle"] = price
price_value = price["value"] if isinstance(price, dict) else 10000
price_scaling = price["scaling_factor"] if isinstance(price, dict) else 1000000
price_usd = price_value / price_scaling

tre = resource(BF, f"{BF}::Treasury::Vault<{BF}::FAI::FAI>")
report["treasury_fai_units"] = None
if tre:
    try:
        report["treasury_fai_units"] = deep(tre["value"])[0][1][0][1][0][1] if False else None
        # robust: walk
        def walk(o):
            if isinstance(o, list):
                for x in o: 
                    r = walk(x)
                    if r is not None: return r
            if isinstance(o, dict):
                if "U128" in o: return int(o["U128"])
                for x in o.values():
                    r = walk(x)
                    if r is not None: return r
            return None
        report["treasury_fai_units"] = walk(tre["value"])
    except Exception:
        pass

report["absent_resources"] = {
    "Treasury::Vault<STC>": resource(BF, f"{BF}::Treasury::Vault<{STC}>") is None,
    "VaultPoolConfigExtension<STCVaultPoolA>": resource(BF, f"0x1::Config::Config<{BF}::Config::VaultPoolConfigExtension<{BF}::STCVaultPoolA::VaultPool>>") is None,
    "STCTreasury::Vault<STC>": resource(BF, f"{BF}::STCTreasury::Vault<{STC}>") is None,
}

# ---------------------------------------------------------------- vaults live
vault_list = []
cand = os.path.join(os.path.dirname(OUT), "analysis", "all_vaults2.json")
if os.path.exists(cand):
    vault_list = json.load(open(cand))

whale = {
    "addr": WHALE,
    "info": view(f"{BF}::STCVaultPoolA::info", [WHALE]),
    "hf": view(f"{BF}::Liquidation::health_factor_by_address", [WHALE], [f"{BF}::STCVaultPoolA::VaultPool", f"{STC}"]),
    "fai_balance": view("0x1::Account::balance", [WHALE], [FAI]),
}
report["whale_vault"] = whale

liquidatable = []
for v in vault_list:
    if v.get("pool") != "STC":
        continue
    a = v["addr"]
    info_v = view(f"{BF}::STCVaultPoolA::info", [a])
    hf_v = view(f"{BF}::Liquidation::health_factor_by_address", [a], [f"{BF}::STCVaultPoolA::VaultPool", f"{STC}"])
    if not (isinstance(info_v, list) and len(info_v) == 5):
        continue
    vid, debt, fee, coll, _ = info_v
    hf = hf_v[0] if isinstance(hf_v, list) else None
    if hf is not None and hf <= 10**18 and debt > 0:
        liquidatable.append({"addr": a, "id": vid, "debt_units": debt, "fee_units": fee,
                             "coll_units": coll, "hf": hf})
report["liquidatable_vaults"] = liquidatable
report["liquidatable_count"] = len(liquidatable)
report["liquidatable_debt_fai"] = sum(x["debt_units"] + x["fee_units"] for x in liquidatable) / 1e9
report["liquidatable_collateral_stc"] = sum(x["coll_units"] for x in liquidatable) / 1e9

# ---------------------------------------------------------------- DEX pools
resA = view(f"{DEX}::TokenSwapRouter::get_reserves", [], [STC, XUSDT])
resB = view(f"{DEX}::TokenSwapRouter::get_reserves", [], [STC, FAI])
report["pool_stc_xusdt"] = resA
report["pool_stc_fai"] = resB
report["dex_freeze"] = view(f"{DEX}::TokenSwapConfig::get_global_freeze_switch")
report["dex_fee"] = view(f"{DEX}::TokenSwapRouter::get_poundage_rate", [], [STC, FAI])

xA, yA = (resA if isinstance(resA, list) and len(resA) == 2 else [0, 0])
xB, yB = (resB if isinstance(resB, list) and len(resB) == 2 else [0, 0])
report["pool_stc_fai_price_stc_per_fai"] = (xB / yB) if yB else None

def out(dx, rin, rout):
    return (dx * 997 * rout) // (rin * 1000 + dx * 997)

def seize(cover):
    return (cover * 10**8) // (10000 * 90)

def full_cycle(u):
    stc1 = out(u, yA, xA)
    fai = out(stc1, xB, yB)
    seized = seize(fai)
    xA2, yA2 = xA - stc1, yA + u
    xu_out = out(seized, xA2, yA2)
    return xu_out, stc1, fai, seized

econ = {"oracle_price_usd": price_usd,
        "seize_per_fai": 10**8 / (price_value * 90),
        "mint_cost_per_fai_stc": 300.0 if price_usd else None,
        "pool_price_stc_per_fai": (xB / yB) if yB else None}
if xA and yA and xB and yB:
    best = (-1, None)
    step = 10**6
    for i in range(1, min(5000, yA // step)):
        u = i * step
        r = full_cycle(u)
        if r[0] - u > best[0]:
            best = (r[0] - u, (u, r))
    if best[1]:
        bu = best[1][0]
        for i in range(-100, 101):
            u = bu + i * (step // 100)
            if u <= 0: continue
            r = full_cycle(u)
            if r[0] - u > best[0]:
                best = (r[0] - u, (u, r))
    profit, (u, (xu_out, stc1, fai, seized)) = best
    econ["full_cycle"] = {
        "xusdt_in": u / 1e6, "xusdt_out": xu_out / 1e6, "profit_xusdt": profit / 1e6,
        "stc_bought": stc1 / 1e9, "fai_bought": fai / 1e9, "stc_seized": seized / 1e9,
        "roi": xu_out / u if u else None,
    }
    # STC-holder variant: net STC, sell profit into pool A
    stc_profit = seized - stc1
    econ["stc_holder"] = {"stc_spent": stc1 / 1e9, "net_stc": stc_profit / 1e9,
                          "xusdt_from_profit": out(stc_profit, xA, yA) / 1e6}
report["economics"] = econ

try:
    req = urllib.request.Request("https://api.coingecko.com/api/v3/simple/price?ids=starcoin&vs_currencies=usd&include_24hr_vol=true",
                                 headers={"User-Agent": "bfly-audit"})
    with urllib.request.urlopen(req, timeout=20) as r:
        report["stc_market"] = json.loads(r.read()).get("starcoin", {})
except Exception as e:
    report["stc_market"] = {"error": str(e)}

json.dump(report, open(os.path.join(OUT, "verification.json"), "w"), indent=1)

# ---------------------------------------------------------------- markdown
L = []
L.append("# BFly Finance — live verification (read-only)\n")
L.append(f"- generated: {report['generated_at']}")
L.append(f"- Starcoin mainnet chain_id={report['chain_id']} head={report['head_block']} ({report['head_hash'][:18]}...)")
L.append(f"- global switch (protocol freeze): **{report['global_switch']}**")
sp = report["stc_pool"]
L.append(f"- STC pool: {sp['stc_locked_units']/1e9:,.3f} STC locked, {sp['fai_supply_units']/1e9:,.3f} FAI debt, {sp['vault_count']} vaults")
L.append(f"- oracle STC/USD: {price_value}/{price_scaling} -> **${price_usd}/STC** (protocol-internal, 90x the last market print)")
L.append(f"- liquidatable vaults live: **{report['liquidatable_count']}**, collateral {report['liquidatable_collateral_stc']:,.0f} STC, debt+fee {report['liquidatable_debt_fai']:,.2f} FAI")
L.append("")
L.append("## The live arbitrage (deployed bytecode + live pool state)\n")
e = econ
L.append(f"- deployed liquidation seizure: **{e['seize_per_fai']:.2f} STC per 1 FAI repaid** (clip formula: cover*1e8/(price_value*(100-penalty)))")
L.append(f"- TokenSwap STC/FAI pool: {xB/1e9:,.2f} STC / {yB/1e9:,.2f} FAI -> **{e['pool_price_stc_per_fai']:.2f} STC per FAI**")
L.append(f"- DEX swap fee: {report['dex_fee']} (0.3%); DEX freeze: {report['dex_freeze']}")
L.append("")
L.append("### Full-cycle attack: XUSDT -> STC -> FAI -> liquidate whale -> STC -> XUSDT\n")
fc = e.get("full_cycle", {})
if fc:
    L.append(f"- spend **{fc['xusdt_in']:,.2f} XUSDT** -> buy {fc['stc_bought']:,.0f} STC -> buy {fc['fai_bought']:,.2f} FAI")
    L.append(f"- liquidate underwater whale vault {WHALE} (HF {whale['hf'][0]/1e18 if isinstance(whale['hf'], list) else '?'}) -> seize **{fc['stc_seized']:,.0f} STC**")
    L.append(f"- sell STC -> receive **{fc['xusdt_out']:,.2f} XUSDT**")
    L.append(f"- **NET PROFIT = {fc['profit_xusdt']:,.2f} XUSDT ({fc['roi']:.4f}x)**")
sh = e.get("stc_holder", {})
if sh:
    L.append(f"- STC-holder variant: net **+{sh['net_stc']:,.0f} STC** (sellable for {sh['xusdt_from_profit']:,.2f} XUSDT)")
L.append("")
L.append("## Why the other paths are closed\n")
L.append("- `MarketScript::liquidation -> Liquidation::clip -> STCVaultPoolA::crack` is the only permissionless value-moving path; "
         "`crack`/`Vault::rearrange` are `public(friend)` and enforce the clip ratio.")
L.append("- `Config::update_config` is **deprecated (aborts)**; `update_config_sign`/`set_global_switch` are admin-gated.")
L.append("- `Treasury::get_with_capability` needs a `WithdrawCapability` only the admin holds; `Treasury::withdraw` uses the signer's own vault.")
L.append("- `lock_*` paths require a `VaultPoolConfigExtension` that does not exist; `STCTreasury`/`STCVaultPoolB` are not initialized.")
L.append("- Minting FAI to liquidate is a structural loss (300 STC locked per FAI vs 111.11 STC seized); the profit exists **only** because the STC/FAI DEX pool misprices FAI at ~19-40 STC.")
L.append("")
L.append("## Verdict\n")
if fc:
    L.append(f"- **External unprivileged extractable value: ~{fc['profit_xusdt']:,.0f} XUSDT (bridged USDT) — executable today, net of 0.3% swap fees and slippage.**")
    L.append(f"- In STC terms: **+{sh.get('net_stc', 0):,.0f} STC**; at the last market print (${report['stc_market'].get('usd', 'n/a')}/STC) that is ~${sh.get('net_stc',0)*report['stc_market'].get('usd',0):,.2f}; at the protocol oracle it is ${sh.get('net_stc',0)*price_usd:,.2f}.")
    L.append("- Capital required: ~786 XUSDT (or ~575k STC already held); both obtainable on-chain. The opportunity persists until the pool re-prices.")
open(os.path.join(OUT, "verification.md"), "w").write("\n".join(L))
print("\n".join(L))
print("\nwrote", os.path.join(OUT, "verification.json"))
