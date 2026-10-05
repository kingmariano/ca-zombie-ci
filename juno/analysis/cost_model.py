#!/usr/bin/env python3
"""
C2-07 Juno governance capture - cost model.
Inputs: raw JSON pulls in analysis/raw/ and analysis/*.json (2026-10-05).
Output: analysis/cost_model.json + stdout summary.
All amounts in JUNO (6 decimals) unless noted. USD at DefiLlama prices 2026-10-05.
"""
import json, math, os

HERE = os.path.dirname(os.path.abspath(__file__))
RAW = os.path.join(HERE, 'raw')

def load(p):
    with open(os.path.join(HERE, p)) as f: return json.load(f)
def loadraw(p):
    with open(os.path.join(RAW, p)) as f: return json.load(f)

# ---------- prices (DefiLlama, 2026-10-05 ~15:55 UTC) ----------
PRICES = loadraw('prices_llama_full.json')['coins']
P = {k.split(':')[1]: v['price'] for k, v in PRICES.items()}
P['dai'] = 1.0
P['neta'] = 1.059          # coingecko simple price 2026-10-05
P['wynd'] = 0.00214188     # coingecko simple price 2026-10-05

# ---------- gov params (grpcurl cosmos.gov.v1.Query/Params, juno-grpc.publicnode.com) ----------
gp = loadraw('gov_params_grpc.json')['params']
QUORUM = float(gp['quorum']); THRESHOLD = float(gp['threshold']); VETO = float(gp['vetoThreshold'])
VOTING_S = int(gp['votingPeriod'][:-1]); MIN_DEP = int(gp['minDeposit'][0]['amount'])/1e6
EXP_MIN_DEP = int(gp['expeditedMinDeposit'][0]['amount'])/1e6
MIN_INIT_RATIO = float(gp['minInitialDepositRatio'])
EXP_THRESHOLD = float(gp['expeditedThreshold'])

# ---------- chain state ----------
pool = loadraw('staking_pool_grpc.json')['pool']
T0 = int(pool['bondedTokens'])/1e6                    # bonded JUNO
supply = int(loadraw('supply_ujuno_grpc.json')['amount']['amount'])/1e6
cp_raw = loadraw('community_pool_grpc.json')['pool']  # DecCoins (x1e18)
cp = {c['denom']: int(c['amount'])/1e18 for c in cp_raw}
CP_JUNO = cp['ujuno']/1e6  # token units (ujuno 6dp)

# CP valuation: map denom -> (token amount, usd) using known decimals
CP_MAP = {
    'ujuno': (1e6, P['juno-network']),
    'ibc/4A482FA914A4B9B05801ED81C33713899F322B24F76A06F4B8FE872485EA22FF': (1e6, P['usd-coin']),   # uusdc noble ch-224
    'ibc/EAC38D55372F38F1AFD68DF7FE9EF762DCF69F26520643CF3F9D292A738D8034': (1e6, P['usd-coin']),   # uusdc axelar ch-71 (dust)
    'ibc/171E8F6687D290D378678310F9F15D367DCD245BF06184532B703A92054A8A4F': (1e18, 1.0),            # dai-wei ch-71
    'ibc/C4CFF46FD6DE35CA4CF4CE031E643C8FDC9BA4B99AE598E9B0ED98FE3A2319F9': (1e6, P['cosmos']),     # uatom
    'ibc/8F865D9760B482FF6254EDFEC1FF2F1273B9AB6873A7DE484F89639795D73D75': (1e6, P['terra-luna-2']),# uluna
    'ibc/D836B191CDAE8EDACDEBE7B64B504C5E06CC17C6A072DAF278F9A96DF66F6241': (1e6, 0.0),             # uhuahua ~0
}
cp_value = {}
for d, amt in cp.items():
    if d in CP_MAP:
        dec, usd = CP_MAP[d]
        tok = amt/dec
        cp_value[d] = {'tokens': tok, 'usd': tok*usd}
    else:
        cp_value[d] = {'tokens': amt, 'usd': 0.0}   # thiol/terp/sas/reece: unpriced dust
CP_TOTAL_USD = sum(v['usd'] for v in cp_value.values())
CP_HARD_USD = CP_TOTAL_USD - cp_value['ujuno']['usd']   # non-JUNO, directly liquid

# ---------- live proposal 379 tally (h 42,396,945) ----------
LIVE_YES_379 = 23457597665145/1e6   # observed routine turnout, all Yes

# ---------- liquidity venues (constant-product approx; CL approximated by reserves) ----------
# (name, x=JUNO reserve, y=other reserve in token units, price of other in USD, fee)
VENUES = [
    ('osmosis:498 JUNO/ATOM',  1191615.24, 6069.613721,  P['cosmos'],        0.003),
    ('osmosis:497 JUNO/OSMO',   572319.04, 143161.876,   P['osmosis'],       0.003),
    ('osmosis:CL1097 JUNO/OSMO',546400.39, 104564.990635,P['osmosis'],       0.003),  # CL approx by reserves
    ('wynd:JUNO/ATOM',         1372607.73, 7061.303555,  P['cosmos'],        0.003),
    ('wynd:JUNO/USDC',          641398.48, 5845.976334,  P['usd-coin'],      0.003),
    ('wynd:JUNO/OSMO',          228355.49, 57155.561131, P['osmosis'],       0.003),
    ('wynd:JUNO/NETA',          103019.43, 881.970017,   P['neta'],          0.003),
    ('wynd:JUNO/WYND',           51468.86, 1418455.96,   P['wynd'],          0.003),
    ('loop:JUNO/ATOM',             455.34, 2.357341,     P['cosmos'],        0.003),
    ('loop:JUNO/USDC',             819.31, 7.481679,     P['usd-coin'],      0.003),
    ('whitewhale:JUNO/USDC',      6994.95, 63.529004,    P['usd-coin'],      0.003),
    ('whitewhale:JUNO/ATOM',        74.88, 1.396726,     P['cosmos'],        0.003),
]
pools = []
for name, x, y, py, fee in VENUES:
    pools.append(dict(name=name, x=x, y=y, py=py, k=x*y, usd_y=y*py, fee=fee))
TOTAL_MKT_JUNO = sum(p['x'] for p in pools)
TOTAL_MKT_JUNO_ALL_VENUES = 4_773_329  # child-verified all venues incl. illiquid-counter pairs (Loop/WhiteWhale full)
TOTAL_COUNTERPART_USD = sum(p['usd_y'] for p in pools)

def buy_cost(target_juno):
    """min USD cost to buy target_juno across pools (fees incl). returns (cost_usd, final marginal USD, bought)."""
    # bisection on final marginal price m (USD per JUNO); buy from pool i while p_i < m
    # buying JUNO: x decreases, y increases -> payment = yf - y = sqrt(k*m/py) - y
    def cost_at(m):
        tot = 0.0; spent = 0.0
        for p in pools:
            if m <= p['y']*p['py']/p['x']: continue
            xf = math.sqrt(p['k']*p['py']/m)          # final JUNO reserve
            if xf >= p['x']: continue
            dx = p['x'] - xf
            dy = math.sqrt(p['k']*m/p['py']) - p['y'] # payment in other-token units (>=0)
            tot += dx; spent += dy*p['py']*(1+p['fee'])
        return tot, spent
    lo, hi = 0.0001, 10000.0
    for _ in range(300):
        mid = (lo+hi)/2
        got, _ = cost_at(mid)
        if got < target_juno: lo = mid
        else: hi = mid
    got, spent = cost_at(hi)
    return spent, hi, got

def sell_proceeds(target_juno):
    """max USD proceeds from selling target_juno across pools (fees incl)."""
    def out_at(m):
        tot = 0.0; got = 0.0
        for p in pools:
            if m >= p['y']*p['py']/p['x']: continue   # pool marginal below m -> don't sell
            xf = math.sqrt(p['k']*p['py']/m)
            dx = xf - p['x']
            dy = p['y'] - math.sqrt(p['k']*m/p['py'])
            tot += dx; got += dy*p['py']*(1-p['fee'])
        return tot, got
    lo, hi = 1e-7, 1.0
    for _ in range(200):
        mid = (lo+hi)/2
        sold, _ = out_at(mid)
        if sold < target_juno: hi = mid
        else: lo = mid
    sold, got = out_at(lo)
    return got, lo, sold

# ---------- quorum / majority thresholds ----------
B_solo = T0 * QUORUM / (1 - QUORUM)          # attacker-only turnout meets quorum
B_maj_live = LIVE_YES_379                    # beat observed live defender turnout (all-Yes routine)
B_maj_all = T0                               # beat every bonded token voting No

# ---------- buy cost curve (on-market acquisition) ----------
buy_curve = []
for tgt in [500_000, 1_000_000, 2_000_000, 3_000_000, 4_000_000, 4_700_000]:
    cost, marg, got = buy_cost(tgt)
    buy_curve.append(dict(target_juno=tgt, cost_usd=cost, avg_price=cost/max(got,1), marginal_usd=marg, bought_juno=got))

# ---------- scenarios ----------
scen = []
for label, B, p_otc in [
    ('solo-quorum 14.85M @ OTC 0.001', B_solo, 0.001),
    ('solo-quorum 14.85M @ OTC 0.0025', B_solo, 0.0025),
    ('solo-quorum 14.85M @ OTC 0.005', B_solo, 0.005),
    ('solo-quorum 14.85M @ spot', B_solo, P['juno-network']),
    ('beat live turnout 23.46M @ OTC 0.001', B_maj_live, 0.001),
    ('beat live turnout 23.46M @ OTC 0.0025', B_maj_live, 0.0025),
    ('beat live turnout 23.46M @ OTC 0.005', B_maj_live, 0.005),
    ('beat live turnout 23.46M @ spot', B_maj_live, P['juno-network']),
    ('beat all bonded 29.61M @ OTC 0.001', B_maj_all, 0.001),
    ('beat all bonded 29.61M @ OTC 0.0025', B_maj_all, 0.0025),
    ('beat all bonded 29.61M @ spot', B_maj_all, P['juno-network']),
    ('social-engineering CP spend (deposit only)', 0, 0.0),
]:
    if label.startswith('social'):
        acq = MIN_DEP * P['juno-network']; acq_note = '5,000 JUNO deposit (returned on pass)'
    else:
        acq = B * p_otc; acq_note = f'OTC @ ${p_otc}'
    proceeds_juno, marg_sell, sold = sell_proceeds(min(CP_JUNO, 30e6))
    hard = CP_HARD_USD
    net = hard + proceeds_juno - acq
    scen.append(dict(label=label, B_juno=B, acquisition_usd=acq, acq_note=acq_note,
                     cp_hard_usd=hard, cp_juno_sale_usd=proceeds_juno,
                     net_usd=net, can_pass=(B >= B_solo or label.startswith('social'))))

out = dict(
    generated_utc='2026-10-05',
    prices=P,
    gov_params=dict(quorum=QUORUM, threshold=THRESHOLD, veto=VETO, voting_days=VOTING_S/86400,
                    min_deposit_juno=MIN_DEP, expedited_min_deposit_juno=EXP_MIN_DEP,
                    min_initial_deposit_ratio=MIN_INIT_RATIO, expedited_threshold=EXP_THRESHOLD),
    state=dict(bonded_juno=T0, supply_juno=supply, cp_juno=CP_JUNO,
               live_turnout_379_juno=LIVE_YES_379),
    thresholds=dict(solo_quorum_juno=B_solo, beat_live_turnout_juno=B_maj_live, beat_all_bonded_juno=B_maj_all,
                    solo_quorum_usd_at_spot=B_solo*P['juno-network'],
                    beat_live_turnout_usd_at_spot=B_maj_live*P['juno-network']),
    liquidity=dict(total_market_juno=TOTAL_MKT_JUNO, total_market_juno_all_venues=TOTAL_MKT_JUNO_ALL_VENUES,
                   total_counterpart_usd=TOTAL_COUNTERPART_USD,
                   pools=[{k: v for k, v in p.items() if k != 'k'} for p in pools]),
    buy_curve=buy_curve,
    cp_valuation=cp_value, cp_total_usd=CP_TOTAL_USD, cp_hard_usd=CP_HARD_USD,
    scenarios=scen,
)
with open(os.path.join(HERE, 'cost_model.json'), 'w') as f: json.dump(out, f, indent=1)

print(f"JUNO price ${P['juno-network']:.6f} | bonded {T0:,.0f} | supply {supply:,.0f} | CP {CP_JUNO:,.0f} JUNO (${cp_value['ujuno']['usd']:,.0f}) + hard ${CP_HARD_USD:,.0f}")
print(f"quorum {QUORUM} | threshold {THRESHOLD} | veto {VETO} | vote {VOTING_S/86400:.0f}d | min_dep {MIN_DEP:,.0f} JUNO")
print(f"solo-quorum stake B = {B_solo:,.0f} JUNO (${B_solo*P['juno-network']:,.0f}) | beat live turnout {B_maj_live:,.0f} | beat all bonded {B_maj_all:,.0f}")
print(f"total JUNO in DEX pools = {TOTAL_MKT_JUNO:,.0f} JUNO | counterpart drain value = ${TOTAL_COUNTERPART_USD:,.0f}")
print("buy curve (on-market):")
for b in buy_curve:
    print(f"  buy {b['target_juno']:>10,.0f} JUNO -> cost ${b['cost_usd']:>12,.0f} (avg ${b['avg_price']:.5f})")
for s in scen:
    print(f"  {s['label']:42s} B={s['B_juno']:>12,.0f} acq=${s['acquisition_usd']:>11,.0f} sale=${s['cp_juno_sale_usd']:>9,.0f} net=${s['net_usd']:>11,.0f}")
