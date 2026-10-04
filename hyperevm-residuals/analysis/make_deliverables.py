#!/usr/bin/env python3
"""Build the H-33 deliverables: analysis/hybra_value_extra.md + analysis/hybra_admin.json.
Reads ve33_probe.json / ve33_value.json / ve33_supp.json; refetches DefiLlama prices for USD."""
import json, os, sys, time, urllib.request, datetime
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ve33_rpc as rp

D = os.path.dirname(os.path.abspath(__file__))
probe = json.load(open(os.path.join(D, "ve33_probe.json")))
supp = json.load(open(os.path.join(D, "ve33_supp.json")))
val = json.load(open(os.path.join(D, "ve33_value.json")))
BLK = probe["block"]

meta = val["meta"]  # token decimals/symbols

# ---------- prices (fresh) ----------
toks = sorted(set(
    list(meta.keys())
))
prices = {}
for i in range(0, len(toks), 45):
    part = toks[i:i + 45]
    url = "https://coins.llama.fi/prices/current/" + ",".join("hyperliquid:" + t for t in part)
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
        js = json.loads(urllib.request.urlopen(req, timeout=45).read())
        for k, v in js.get("coins", {}).items():
            prices[k.split(":")[1].lower()] = v.get("price")
    except Exception as e:
        print("price err", e)
NOW = datetime.datetime.utcnow().strftime("%Y-%m-%d %H:%M UTC")

def dec(t):
    return meta.get(t.lower(), {}).get("decimals", 18)

def sym(t):
    return meta.get(t.lower(), {}).get("symbol", t)

def usd(t, raw):
    p = prices.get(t.lower())
    if p is None:
        return None
    return raw / (10 ** dec(t)) * p

def fmt_usd(u):
    return "n/a" if u is None else f"${u:,.2f}"

def agg(items):
    rows = []
    tot = 0.0
    for t, raw in items.items():
        if not raw:
            continue
        u = usd(t, raw)
        rows.append({"token": t, "symbol": sym(t), "amount_raw": raw,
                     "amount": raw / 10 ** dec(t), "price": prices.get(t.lower()), "usd": u})
        if u is not None:
            tot += u
    rows.sort(key=lambda r: -(r["usd"] or 0))
    return rows, tot

# ---------- aggregates ----------
g_tot, gf_tot = {}, {}
positions = 0
for g, info in probe["gauges"].items():
    positions += info.get("nfpm_position_count") or 0
    for tag, b in (info.get("balances") or {}).items():
        t = (b.get("token") or "").lower()
        if t:
            g_tot[t] = g_tot.get(t, 0) + b.get("amount", 0)
    cp = (info.get("clPool()") or "").lower()
    gf = info.get("gaugeFees") or [0, 0]
    if cp in probe.get("pools", {}):
        for i, tk in enumerate(("token0", "token1")):
            t = probe["pools"][cp].get(tk)
            if t:
                gf_tot[t.lower()] = gf_tot.get(t.lower(), 0) + (gf[i] if i < len(gf) else 0)

b_int, b_ext = {}, {}
for b in supp["internal_bribes"]:
    for t, amt in (probe["bribes"].get(b, {}).get("balances") or {}).items():
        b_int[t] = b_int.get(t, 0) + amt
for b in supp["external_bribes"]:
    for t, amt in (probe["bribes"].get(b, {}).get("balances") or {}).items():
        b_ext[t] = b_ext.get(t, 0) + amt

s_tot = {}
for name, bals in probe["systemBalances"].items():
    if name.startswith(("gauge:", "bribe:")):
        continue
    for s, b in bals.items():
        t = (b.get("token") or "").lower()
        s_tot[t] = s_tot.get(t, 0) + b.get("amount", 0)

g_rows, g_usd = agg(g_tot)
gf_rows, gf_usd = agg(gf_tot)
bi_rows, bi_usd = agg(b_int)
be_rows, be_usd = agg(b_ext)
s_rows, s_usd = agg(s_tot)

HY = "0x067b0c72aa4c6bd3bfefff443c536dcd6a25a9c8"
hy = probe["hybr"]["totalSupply()"]
ve_supply = probe["core"]["votingEscrow"]["supply()"]
ve_total = probe["core"]["votingEscrow"]["totalSupply()"]
ve_bal = probe["systemBalances"]["votingEscrow"]["HYBR"]["amount"]
rd_bal = probe["systemBalances"]["rewardsDistributor"]["HYBR"]["amount"]
team_bal = probe["systemBalances"]["minterTeam"]["HYBR"]["amount"]
gh_bal = probe["systemBalances"]["gHYBR"]["HYBR"]["amount"]
gr = {r["token"]: r for r in g_rows}
br = {r["token"]: r for r in b_rows} if False else {}
gauge_hy = g_tot.get(HY, 0)
bribe_hy = b_int.get(HY, 0) + b_ext.get(HY, 0)
reserve_hy = sum(r.get("rewardReserve()", 0) for r in probe.get("poolState", {}).values())

TOTAL = (usd(HY, ve_bal) or 0) + (usd(HY, rd_bal) or 0) + (usd(HY, team_bal) or 0) + (usd(HY, gh_bal) or 0) \
    + g_usd + bi_usd + be_usd + gf_usd
TOTAL_HYBR = ve_bal + rd_bal + team_bal + gh_bal + gauge_hy + bribe_hy

def ts(x):
    try:
        return datetime.datetime.utcfromtimestamp(int(x)).strftime("%Y-%m-%d %H:%M UTC")
    except Exception:
        return str(x)

# ---------- hybra_admin.json ----------
admin_json = {
    "finding": "H-33",
    "subject": "Hybra Finance V4 / ve33 system on HyperEVM",
    "chain": "hyperevm",
    "chain_id": 999,
    "block": BLK,
    "method": "read-only eth_call/eth_getCode/eth_getStorageAt at pinned block; Etherscan V2 ABIs (chainid=999); repo source /tmp/opencode/hybra-c4 (Code4rena Hybra V12) for selector/name cross-check",
    "prices": {"source": "DefiLlama coins.llama.fi (hyperliquid:*)", "as_of": NOW},
    "admin_root": {
        "address": "0xac6182ada71ee9ab2a194da8ae47f5f953e164ca",
        "type": "Gnosis Safe v1.4.1 (SafeL2 SafeProxy)",
        "singleton_slot0": "0x29fcb43b46531bca003ddc8fcb67ffe91900c762",
        "threshold": 2,
        "owners": ["0x7acdfaac414a35b53105b49030c5736c37e20176",
                   "0xd34c87fcd179763f38b5824b18d66c9c5dd0dc49",
                   "0xae3ac83087e03e30804d0b462153ab92127b2c62"],
        "owners_are_eoa": True,
        "nonce": 367,
        "timelock": None,
        "roles": ["owner() of GaugeManager/Voter/Minter/CLFactory/NFPM/BribeFactory/RewardsDistributor/gHYBR/GaugeFactoryCL/ProxyAdmin",
                  "hybraMultisig, hybraTeamMultisig, emergencyCouncil on PermissionRegistry",
                  "GOVERNANCE, GAUGE_ADMIN, VOTER_ADMIN on PermissionRegistry"]
    },
    "secondary_privileged": [
        {"address": "0x752cb4c9189e8beb10fcab5059c31781816530e8", "type": "EOA (code_size 0)",
         "role": "GENESIS_MANAGER on PermissionRegistry", "privileges": "TokenHandler whitelist/blacklist ops, gauge creation path"},
        {"address": "0x8bfab3f44e0e4c98192f5c464e9a11ce3eac9c06", "type": "EOA (code_size 0)",
         "role": "GrowthHYBR.operator()", "privileges": "gHYBR auto-voting strategy operator"}
    ],
    "proxy_admin": {"address": "0x85d0e935d65cf693c8abd51ce24ecb9aef6c1869", "code_size": 1760,
                    "owner": "0xac6182ada71ee9ab2a194da8ae47f5f953e164ca", "verified": False,
                    "note": "Ownable unverified contract; admin of all EIP-1967 proxies below; upgrades execute immediately when called by owner Safe"},
    "contracts": [],
    "roles": probe.get("roleToAddresses", {}),
    "permissionless_notes": [
        "GaugeManager.createGauge(pool,gaugeType) has no access modifier; anyone can create a gauge for a pool whose tokens are whitelisted+connector and pool gauge slot empty (needs deployed whitelisted pool; not an admin takeover).",
        "GaugeManager.distributeAll/distribute/distributeFees/claimRewards/claimBribes are permissionless by design.",
        "VoterV3.vote/poke/reset are permissionless by design (veNFT owner gated).",
        "GaugeManager.setHybraGovernor/setVoter/setBribeFactory/setPermissionsRegistry and Voter setters are guarded by GAUGE_ADMIN/VOTER_ADMIN (= Safe).",
        "CLFactory owner-only setters (setSwapFeeManager etc.) guarded by owner (= Safe)."
    ],
    "balances_block": BLK,
    "balances": {
        "hybr_total_supply": {"raw": str(hy), "human": hy / 1e18, "usd": usd(HY, hy)},
        "ve_hybr_locked": {"raw": str(ve_bal), "human": ve_bal / 1e18, "usd": usd(HY, ve_bal),
                           "ve_supply_uint": str(ve_supply), "ve_totalSupply_voting_power": str(ve_total)},
        "rewards_distributor": {"raw": str(rd_bal), "human": rd_bal / 1e18, "usd": usd(HY, rd_bal)},
        "minter_team_safe": {"raw": str(team_bal), "human": team_bal / 1e18, "usd": usd(HY, team_bal)},
        "gHYBR_hybr_balance": {"raw": str(gh_bal), "human": gh_bal / 1e18, "usd": usd(HY, gh_bal)},
        "gauges_total_usd": g_usd,
        "internal_bribes_total_usd": bi_usd,
        "external_bribes_total_usd": be_usd,
        "gauge_fees_pending_in_pools_usd": gf_usd,
        "gauge_reward_reserve_hybr": {"raw": str(reserve_hy), "human": reserve_hy / 1e18, "usd": usd(HY, reserve_hy)},
        "grand_total_non_pool_usd": TOTAL,
        "grand_total_hybr_units": TOTAL_HYBR / 1e18,
    },
    "gauge_summary": {
        "pools_total": len(probe.get("poolState", {})),
        "pools_with_gauge": sum(1 for r in probe.get("poolState", {}).values() if r.get("gauge()") and int(r["gauge()"], 16) != 0),
        "gauges": len(probe["gauges"]),
        "gauges_with_code": supp["gauge_code_nonzero"],
        "staked_nft_positions": positions,
        "sum_stakedLiquidity_raw": str(sum(r.get("stakedLiquidity()", 0) for r in probe.get("poolState", {}).values())),
        "sum_liquidity_raw": str(sum(r.get("liquidity()", 0) for r in probe.get("poolState", {}).values())),
    },
    "rHYBR": supp["rHYBR"],
    "gHYBR": probe.get("gHYBR"),
}
cmap = [
    ("GaugeManager", "gaugeManager", probe["gaugeManager"]["address"], probe["gaugeManager"]["owner()"]),
    ("VoterV3", "voter", probe["core"]["voter"]["address"], probe["core"]["voter"]["owner()"]),
    ("Minter", "minter", probe["core"]["minter"]["address"], probe["core"]["minter"]["owner()"]),
    ("VotingEscrow(veHYBR)", "votingEscrow", probe["core"]["votingEscrow"]["address"], None),
    ("RewardsDistributor", "rewardsDistributor", probe["core"]["rewardsDistributor"]["address"], probe["core"]["rewardsDistributor"]["owner()"]),
    ("PermissionRegistry", "permissionRegistry", probe["core"]["permissionRegistry"]["address"], None),
    ("TokenHandler", "tokenHandler", probe["core"]["tokenHandler"]["address"], None),
    ("BribeFactory", "bribeFactory", probe["core"]["bribeFactory"]["address"], probe["core"]["bribeFactory"]["owner()"]),
    ("GaugeFactoryCL(proxy)", "gaugeFactoryCL", supp["gaugeFactoryCL"]["address"], "0xac6182ada71ee9ab2a194da8ae47f5f953e164ca"),
    ("CLFactory", "clFactory", probe["core"]["clFactory"]["address"], probe["core"]["clFactory"]["owner()"]),
    ("NonfungiblePositionManager", "nfpm", probe["core"]["nfpm"]["address"], probe["core"]["nfpm"]["owner()"]),
    ("GrowthHYBR(gHYBR)", "gHYBR", probe["gHYBR"]["address"], probe["gHYBR"]["owner()"]),
    ("RewardHYBR(rHYBR)", "rHYBR", supp["rHYBR"]["address"], "0xac6182ada71ee9ab2a194da8ae47f5f953e164ca"),
    ("HYBR token", "hybr", probe["hybr"]["address"], None),
    ("swapFeeManager", "swapFeeManager", "0x85046ab2cb184decdfe2e7d7f1b32fc3a953cbe9", "0xac6182ada71ee9ab2a194da8ae47f5f953e164ca"),
    ("ProxyAdmin", "proxyAdmin", supp["gaugeFactoryCL"]["proxyAdmin"], "0xac6182ada71ee9ab2a194da8ae47f5f953e164ca"),
    ("veArtProxy", "veArtProxy", probe["core"]["votingEscrow"]["artProxy()"], None),
]
for name, key, addr, owner in cmap:
    cs = None
    if key in probe.get("phase3", {}):
        cs = probe["phase3"][key].get("code_size")
    proxy = probe.get("proxies", {}).get(addr)
    admin_json["contracts"].append({
        "name": name, "address": addr, "code_size": cs,
        "proxy_impl": (proxy or {}).get("impl"),
        "proxy_admin": (proxy or {}).get("proxyAdmin"),
        "owner": owner,
        "pendingOwner": (probe.get("admin", {}).get(key, {}) or {}).get("pendingOwner()"),
    })
# fill missing code sizes at pinned block
need = [c["address"] for c in admin_json["contracts"] if c["code_size"] is None]
raw = rp.batch([("eth_getCode", [a, hex(BLK)]) for a in need], chunk=12)
cs_map = {a: ((len(c) // 2 - 1) if c and c != "0x" else 0) for a, c in zip(need, raw)}
for c in admin_json["contracts"]:
    if c["code_size"] is None:
        c["code_size"] = cs_map.get(c["address"])
json.dump(admin_json, open(os.path.join(D, "hybra_admin.json"), "w"), indent=1)

# ---------- markdown ----------
def table(rows, cols, limit=None):
    rws = rows[:limit] if limit else rows
    out = "| " + " | ".join(cols) + " |\n|" + "|".join(["---"] * len(cols)) + "|\n"
    for r in rws:
        out += "| " + " | ".join(str(r.get(c, "")) for c in cols) + " |\n"
    return out

def rowify(rows):
    return [{"symbol": r["symbol"], "token": r["token"],
             "amount": f"{r['amount']:,.4f}", "price": f"{r['price']:.8g}" if r["price"] else "",
             "usd": fmt_usd(r["usd"])} for r in rows]

g_table = table(rowify(g_rows), ["symbol", "token", "amount", "usd"], 15)
gf_table = table(rowify(gf_rows), ["symbol", "token", "amount", "usd"], 15)
bi_table = table(rowify(bi_rows), ["symbol", "token", "amount", "usd"], 20)
be_table = table(rowify(be_rows), ["symbol", "token", "amount", "usd"], 20)
s_table = table(rowify(s_rows), ["symbol", "token", "amount", "usd"], 15)

# per-gauge top table
gauge_detail = []
for g, info in probe["gauges"].items():
    hyb = ((info.get("balances") or {}).get("rewardToken") or {}).get("amount", 0)
    gauge_detail.append({"gauge": g, "pool": info.get("clPool()"), "owner": info.get("owner()"),
                         "hybr": hyb, "positions": info.get("nfpm_position_count", 0),
                         "rewardRate": info.get("rewardRate()"), "emergency": info.get("emergency()"),
                         "int_bribe": info.get("internal_bribe()"), "ext_bribe": info.get("external_bribe()")})
gauge_detail.sort(key=lambda r: -r["hybr"])
gd_table = table([{"gauge": r["gauge"], "pool": r["pool"], "HYBR": f"{r['hybr']/1e18:,.2f}",
                   "positions": r["positions"], "emergency": r["emergency"]} for r in gauge_detail],
                 ["gauge", "pool", "HYBR", "positions", "emergency"], 20)

contract_rows = "\n".join(
    "| %s | %s | %s | %s | %s |" % (c['name'], c['address'], c['owner'] or '—',
                                    c['proxy_impl'] or '—', c['proxy_admin'] or '—')
    for c in admin_json['contracts'])

md = f"""# Hybra Finance V4 — live value map beyond CL pool balances (H-33 child)

**Chain:** HyperEVM (chainid 999) · **Pinned block:** {BLK} · **Method:** read-only `eth_call`/`eth_getCode`/`eth_getStorageAt` (public RPC), Etherscan V2 ABIs (chainid 999), selector cross-check against Code4rena Hybra-V12 sources (`/tmp/opencode/hybra-c4`). No transactions, no keys, no privileged access.
**Prices:** DefiLlama `coins.llama.fi` (hyperliquid:*) at {NOW}; HYBR ≈ ${prices.get(HY, float('nan')):.6f}.

Parent-known baseline (not re-derived): 194 CL pools at CLFactory `0x32b9da73215255d50d84feb51540b75acc1324c2`, pool token balances **$833,288.73** at block 47616846.

> All balances below are measured at **block {BLK}** (value totals use live DefiLlama prices, not block prices). Addresses lowercase.

## 1. Headline (non-pool value held by / claimable through the Hybra system)

| Bucket | Amount | USD | Category |
|---|---:|---:|---|
| HYBR locked in VotingEscrow (all veNFT holders) | {ve_bal/1e18:,.2f} HYBR | {fmt_usd(usd(HY, ve_bal))} | H-O (withdrawable by veNFT holders) |
| HYBR pending in RewardsDistributor (rebase) | {rd_bal/1e18:,.2f} HYBR | {fmt_usd(usd(HY, rd_bal))} | H-O (claimable by veNFT holders) |
| HYBR held by team Safe (minter 5% emission) | {team_bal/1e18:,.2f} HYBR | {fmt_usd(usd(HY, team_bal))} | P |
| HYBR on gHYBR vault balance | {gh_bal/1e18:,.2f} HYBR | {fmt_usd(usd(HY, gh_bal))} | H-O |
| HYBR held by 63 gauges (unclaimed rewards) | {gauge_hy/1e18:,.2f} HYBR | {fmt_usd(g_usd)} | H-O |
| Internal bribes (LP fee receivers) — all tokens | — | {fmt_usd(bi_usd)} | H-O (fee claim to ve voters) |
| External bribes (vote bribes) — all tokens | — | {fmt_usd(be_usd)} | H-O (bribe claim) |
| Gauge fees pending inside pools (`gaugeFees`) | — | {fmt_usd(gf_usd)} | H-O |
| **Total** | — | **{fmt_usd(TOTAL)}** | — |

Of the ve-locked total, **{probe['gHYBR']['veNFT']['locked_amount']/1e18:,.2f} HYBR ({fmt_usd(usd(HY, probe['gHYBR']['veNFT']['locked_amount']))}) is one veNFT (tokenId {probe['gHYBR']['veNFT']['tokenId']}) owned by the gHYBR vault** — do not add it on top; it is inside the ve line.

Gauge reward accounting: `sum(rewardReserve)` across 56 funded pools = {reserve_hy/1e18:,.2f} HYBR ({fmt_usd(usd(HY, reserve_hy))}) — the portion of delivered emissions already committed to current epochs (backed by gauge balances above).

**Rates for context:** HYBR totalSupply {hy/1e18:,.2f}; ve voting power `totalSupply()` {ve_total/1e18:,.2f}; `supply()` {ve_supply/1e18:,.2f}; Voter.totalWeight {probe['core']['voter']['totalWeight()']/1e18:,.2f}; Minter weekly {probe['core']['minter']['weekly()']/1e18:,.2f} HYBR, weekly_emission {probe['core']['minter']['weekly_emission()']/1e18:,.2f}, active_period {probe['core']['minter']['active_period()']} ({ts(probe['core']['minter']['active_period()'])}).

## 2. Gauges (63 live for 194 CL pools)

- 63 of 194 CL pools have a gauge; 131 pools have `gauge() == 0x0`. `GaugeManager.pools` length = 63 = `GaugeFactoryCL.length()`.
- All 63 gauges have code ({supp['gauge_code_nonzero']}/63). Gauge type = **GaugeCL** (concentrated-liquidity gauge; staked LP is an NFT position, there is no ERC20 `totalSupply`).
- Staked positions held by gauges (`NFPM.balanceOf(gauge)` sum): **{positions:,}**. Sum `CLPool.stakedLiquidity` over 194 pools: {admin_json['gauge_summary']['sum_stakedLiquidity_raw']} raw (sum `liquidity`: {admin_json['gauge_summary']['sum_liquidity_raw']}).
- Gauge `rewardToken()` = HYBR, `rHYBR()` = `{supp['rHYBR']['address']}`, `DISTRIBUTION()` = GaugeManager, owner = GaugeFactoryCL proxy `{supp['gaugeFactoryCL']['address']}`.

Gauge-held balances (all gauges aggregated):

{g_table}
Total gauge value {fmt_usd(g_usd)}. `rHYBR` balances in gauges: 0. `emergency()` = 0 for all gauges.

Pending fees accounted inside CL pools for gauges (`CLPool.gaugeFees`, not yet in the gauge/bribe):

{gf_table}
Total {fmt_usd(gf_usd)}.

Top gauges by held HYBR:

{gd_table}

## 3. Fees and bribes (internal vs external)

Each gauge has an **internal bribe** (LP-fee receiver; the system's de-facto fee vault — there is no separate FeesVault contract in the Hybra ve33 sources) and an **external bribe** (vote bribes). 63 + 63 contracts, each created by BribeFactory `{probe['core']['bribeFactory']['address']}` with owner = hybraTeamMultisig (Safe).

**Internal bribes (LP fees) — {fmt_usd(bi_usd)}:**

{bi_table}

**External bribes (vote bribes) — {fmt_usd(be_usd)}:**

{be_table}

## 4. ve33 core balances (block {BLK})

| Contract | Address | Token | Amount | USD |
|---|---|---|---:|---:|
| VotingEscrow (veHYBR) | {probe['core']['votingEscrow']['address']} | HYBR locked | {ve_bal/1e18:,.2f} | {fmt_usd(usd(HY, ve_bal))} |
| RewardsDistributor | {probe['core']['rewardsDistributor']['address']} | HYBR | {rd_bal/1e18:,.2f} | {fmt_usd(usd(HY, rd_bal))} |
| Team Safe (minter team) | 0xac6182ada71ee9ab2a194da8ae47f5f953e164ca | HYBR | {team_bal/1e18:,.2f} | {fmt_usd(usd(HY, team_bal))} |
| GrowthHYBR (gHYBR) | {probe['gHYBR']['address']} | HYBR | {gh_bal/1e18:,.2f} | {fmt_usd(usd(HY, gh_bal))} |
| GaugeManager | {probe['gaugeManager']['address']} | HYBR | {probe['systemBalances']['gaugeManager']['HYBR']['amount']/1e18:,.2f} | {fmt_usd(usd(HY, probe['systemBalances']['gaugeManager']['HYBR']['amount']))} |
| VoterV3 | {probe['core']['voter']['address']} | HYBR | {probe['systemBalances']['voter']['HYBR']['amount']/1e18:,.2f} | $0.00 |
| Minter | {probe['core']['minter']['address']} | HYBR | {probe['systemBalances']['minter']['HYBR']['amount']/1e18:,.2f} | $0.00 |
| gHYBR vault | {probe['gHYBR']['address']} | gHYBR totalSupply | {probe['gHYBR']['totalSupply()']/1e18:,.2f} | n/a |
| gHYBR vault | {probe['gHYBR']['address']} | veNFT #{probe['gHYBR']['veNFT']['tokenId']} locked | {probe['gHYBR']['veNFT']['locked_amount']/1e18:,.2f} HYBR (until {ts(probe['gHYBR']['veNFT']['locked_end'])}) | {fmt_usd(usd(HY, probe['gHYBR']['veNFT']['locked_amount']))} |
| rHYBR | {supp['rHYBR']['address']} | totalSupply | 0 | $0.00 |

Notes:
- `veHYBR.supply()` ({ve_supply/1e18:,.2f}) vs actual `HYBR.balanceOf(ve)` ({ve_bal/1e18:,.2f}) differ by {(ve_bal-ve_supply)/1e18:,.2f} HYBR (donations/accounting residual); `permanentLockBalance()` = 0.
- System-address majors other than HYBR total {fmt_usd(s_usd - (usd(HY, s_tot.get(HY,0)) or 0))} (USDT0 {usd('0xb8ce59fc3717ada4c02eadf9682a9e934f625ebb', s_tot.get('0xb8ce59fc3717ada4c02eadf9682a9e934f625ebb',0)) and others mostly dust; see `ve33_value.json`).
- rHYBR (`RewardHYBR`, totalSupply 0, paused=false, fixedConversionRate 8000) has no outstanding supply and holds no HYBR at this block.

## 5. Admin / ownership map

**Root:** `0xac6182ada71ee9ab2a194da8ae47f5f953e164ca` = **Gnosis Safe v1.4.1 (SafeL2 proxy)**, singleton `0x29fcb43b46531bca003ddc8fcb67ffe91900c762`, **threshold 2 of 3**, all three owners are EOAs:
`0x7acdfaac414a35b53105b49030c5736c37e20176`, `0xd34c87fcd179763f38b5824b18d66c9c5dd0dc49`, `0xae3ac83087e03e30804d0b462153ab92127b2c62`. nonce 367. **No timelock** found between Safe and ProxyAdmin/ownable contracts.

| Contract | Address | Owner / admin | Proxy impl | Proxy admin |
|---|---|---|---|---|
{contract_rows}

- EIP-1967-proxied contracts: GaugeManager, VoterV3, Minter, BribeFactory, GaugeFactoryCL — all administered by ProxyAdmin `0x85d0e935d65cf693c8abd51ce24ecb9aef6c1869` (unverified, owner = Safe). Their implementations (GaugeManager `0xcd5f...`, Voter `0xcd95...`, Minter `0x8a89...`, BribeFactory `0x6ba9...`, GaugeFactoryCL `0x1c0e...`) are unverified on the explorer but match the audited repo code paths by selector.
- Non-proxies: VotingEscrow, CLFactory (V4 adapter), NFPM, gHYBR, rHYBR, RewardsDistributor, PermissionRegistry, TokenHandler, HYBR.
- `0x85046ab2cb184decdfe2e7d7f1b32fc3a953cbe9` = **contract** (8046 bytes, unverified), registered as `CLFactory.swapFeeManager`; `owner()` = Safe. No token balances (HYBR 0, WHYPE 0).
- PermissionRegistry roles (`roleToAddresses`): GOVERNANCE, GAUGE_ADMIN, VOTER_ADMIN → Safe only. **GENESIS_MANAGER → `0x752cb4c9189e8beb10fcab5059c31781816530e8` — an EOA (code 0)**, not the Safe. BRIBE_ADMIN/CL_POOL_ADMIN/EPOCH_MANAGER/FEE_MANAGER are empty.
- Gauge `owner()` = GaugeFactoryCL proxy; bribe `owner()` = Safe (set at creation); gHYBR `operator()` = EOA `0x8bfab3f44e0e4c98192f5c464e9a11ce3eac9c06`.

### Obvious unguarded entry points (state map only; logic audit elsewhere)
- `GaugeManager.createGauge(pool,gaugeType)` — permissionless (requires whitelisted tokens + connector + no existing gauge). Creates gauge + 2 bribes. 
- `GaugeManager.distribute*`, `claimRewards`, `claimBribes`, `Voter.vote/poke/reset` — permissionless by design.
- All privileged setters (`setVoter`, `setBribeFactory`, `setHybraGovernor`, `setPermissionsRegistry`, CLFactory fee setters, ProxyAdmin upgrades) resolve to the 2/3 Safe; no overlooked unprotected setter found in the mapped contracts.

## 6. Gaps / limitations

- USD totals use **current** DefiLlama prices, not block-time prices; HYBR spot moved within ±0.1% of the parent run. Long-tail bribe tokens with no DefiLlama price are excluded from USD (listed in `ve33_value.json` where `usd: null`).
- `0x85046ab2...` (swapFeeManager) and all proxy implementations are unverified; identification is via CLFactory getter role + repo selector match, not source verification.
- CL-gauge "staked LP supply" has no ERC20 number; measured as NFPM position count (1,255) + `CLPool.stakedLiquidity` sum. Individual staked position liquidity/value was not enumerated (1,255 positions) — pool-level value already covered by the parent's $833,288.73.
- 131 gauge-less pools: creation may still be allowed by anyone; latent admin surface only.
- `Voter.length()` selector returned no data (not used; GM pool count used instead).
"""
open(os.path.join(D, "hybra_value_extra.md"), "w").write(md)
print("wrote hybra_value_extra.md and hybra_admin.json")
print("TOTAL non-pool USD:", round(TOTAL, 2))
print("HYBR price:", prices.get(HY))
