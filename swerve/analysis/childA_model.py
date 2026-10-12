#!/usr/bin/env python3
"""childA: exact integer model + adversarial search for the live Swerve pool.

Pool: 0x329239599afB305DA0A2eC69c58F8a6697F9F88d (delegates to Curve sUSD pool code
0xA5407eAE9Ba41422680e2e00537571bcC53efBfD, Vyper 0.1.0b17).

Vyper semantics modelled: checked uint256 arithmetic (overflow/underflow revert),
truncating DIV, div-by-zero revert, 255-iteration caps in get_D/get_y.
READ-ONLY: state inputs via batched eth_call JSON-RPC.
"""
import subprocess, json, urllib.request, time, itertools, sys

RPC = "https://ethereum-rpc.publicnode.com"
BN  = 26173859
P   = "0x329239599afB305DA0A2eC69c58F8a6697F9F88d"
LP  = "0x77c6e4a580c0dce4e5c7a17d0bc077188a83a059"
U256 = 1 << 256
N = 4
FEE_DEN = 10**10
PRECISION = 10**18
PM = [1, 10**12, 10**12, 1]

class Rev(Exception): pass

def check(x, op=""):
    if x < 0 or x >= U256: raise Rev(f"overflow:{op}")
    return x
def add(a,b): return check(a+b,"add")
def sub(a,b):
    if a < b: raise Rev("underflow")
    return a-b
def mul(a,b): return check(a*b,"mul")
def div(a,b):
    if b == 0: raise Rev("div0")
    return a//b

# ---------- batched JSON-RPC (via curl: python urllib is CDN-blocked) ----------
def rpc_batch(reqs, tries=4):
    """reqs: list of (method, params). returns list of results (or {'error':...})."""
    out = []
    for chunk in [reqs[i:i+40] for i in range(0, len(reqs), 40)]:
        payload = json.dumps([{"jsonrpc":"2.0","id":i,"method":m,"params":p} for i,(m,p) in enumerate(chunk)])
        for attempt in range(tries):
            r = subprocess.run(["curl","-s","-X","POST",RPC,"-H","content-type: application/json",
                                "-H","user-agent: curl/8.5.0","--data-binary",payload],
                               capture_output=True,text=True,timeout=90)
            try:
                data = json.loads(r.stdout)
                if isinstance(data, list) and len(data)==len(chunk): break
                raise ValueError(f"bad response: {r.stdout[:120]}")
            except Exception as e:
                if attempt==tries-1: raise
                time.sleep(1.0*(attempt+1))
        for d in sorted(data, key=lambda x: x["id"]):
            out.append(d.get("result") if "result" in d else {"error": d.get("error")})
    return out

def enc_call(to, data):
    return ("eth_call", [{"to": to, "data": data}, "latest"])

def selector(sig):
    r = subprocess.run(["cast","sig",sig],capture_output=True,text=True)
    return r.stdout.strip()

def enc_u256(x): return hex(x)[2:].rjust(64,"0")
def enc_i128(x): return hex(x & (2**128-1))[2:].rjust(64,"0")

def get_dy_calldata(i,j,dx):
    return selector("get_dy(int128,int128,uint256)") + enc_i128(i) + enc_i128(j) + enc_u256(dx)

# ---------- state ----------
def one_call(sig, args=()):
    cd = selector(sig)
    for a in args:
        cd += enc_u256(int(a))
    r = rpc_batch([enc_call(P, cd)])[0]
    if isinstance(r, dict): raise RuntimeError(str(r)[:200])
    return int(r,16)

A = one_call("A()")
FEE = one_call("fee()")
ADMIN_FEE = one_call("admin_fee()")
BAL = [one_call("balances(int128)",(i,)) for i in range(4)]
SUPPLY = one_call("totalSupply()") if False else None
# LP totalSupply via direct call
r = rpc_batch([enc_call(LP, selector("totalSupply()"))])[0]
SUPPLY = int(r,16)
VP = one_call("get_virtual_price()")
RATES = [PM[i]*PRECISION for i in range(N)]

def xp(bal): return [div(mul(RATES[i],bal[i]),PRECISION) for i in range(N)]

# ---------- pool math ----------
def get_D(xpv):
    S = 0
    for x in xpv: S = add(S,x)
    if S == 0: return 0, 0
    Dprev = 0; D = S; Ann = mul(A,N); it = 0
    for _ in range(255):
        it += 1
        D_P = D
        for x in xpv:
            D_P = div(mul(D_P,D), add(mul(x,N),1))
        Dprev = D
        D = div(mul(add(mul(Ann,S),mul(D_P,N)),D), add(mul(sub(Ann,1),D), mul(add(N,1),D_P)))
        if D > Dprev:
            if sub(D,Dprev) <= 1: break
        else:
            if sub(Dprev,D) <= 1: break
    return D, it

def get_D_mem(bal):
    return get_D(xp(bal))[0]

def get_y(i,j,x,xpv,cap=255):
    assert (i != j) and (0 <= i < N) and (0 <= j < N)
    D,_ = get_D(xpv)
    c = D; S_ = 0; Ann = mul(A,N)
    for k in range(N):
        if k == i: xx = x
        elif k != j: xx = xpv[k]
        else: continue
        S_ = add(S_,xx)
        c = div(mul(c,D), mul(xx,N))
    c = div(mul(c,D), mul(Ann,N))
    b = add(S_, div(D,Ann))
    y_prev = 0; y = D; it = 0
    for _ in range(cap):
        it += 1
        y_prev = y
        y = div(add(mul(y,y),c), sub(add(mul(2,y),b),D))
        if y > y_prev:
            if sub(y,y_prev) <= 1: break
        else:
            if sub(y_prev,y) <= 1: break
    return y, it

def get_dy(state,i,j,dx):
    xpv = xp(state)
    x = add(xpv[i], div(mul(dx,RATES[i]),PRECISION))
    y,_ = get_y(i,j,x,xpv)
    dy = div(mul(sub(xpv[j],y),PRECISION),RATES[j])
    return sub(dy, div(mul(FEE,dy),FEE_DEN))

def exchange(state,i,j,dx):
    xpv = xp(state)
    x = add(xpv[i], div(mul(dx,RATES[i]),PRECISION))
    y,it = get_y(i,j,x,xpv)
    dy = sub(xpv[j],y)
    dy_fee = div(mul(dy,FEE),FEE_DEN)
    dy_admin = div(mul(dy_fee,ADMIN_FEE),FEE_DEN)
    b = list(state)
    b[i] = div(mul(x,PRECISION),RATES[i])
    b[j] = div(mul(add(y,sub(dy_fee,dy_admin)),PRECISION),RATES[j])
    _dy = div(mul(sub(dy,dy_fee),PRECISION),RATES[j])
    return _dy, b, it

def calc_token_amount(state, amounts, deposit):
    D0 = get_D_mem(state)
    b2 = list(state)
    for i in range(N):
        b2[i] = add(b2[i],amounts[i]) if deposit else sub(b2[i],amounts[i])
    D1 = get_D_mem(b2)
    diff = sub(D1,D0) if deposit else sub(D0,D1)
    return div(mul(diff,SUPPLY),D0)

def add_liquidity(state, amounts, ts):
    fees = [0]*N
    _fee = div(mul(FEE,N), mul(4,sub(N,1)))
    old = list(state); new = list(old)
    D0 = 0
    if ts > 0: D0 = get_D_mem(old)
    for i in range(N):
        if ts == 0 and amounts[i] == 0: raise Rev("zero first")
        new[i] = add(old[i],amounts[i])
    D1 = get_D_mem(new)
    if not (D1 > D0): raise Rev("D1<=D0")
    D2 = D1
    st = list(state)
    if ts > 0:
        for i in range(N):
            ideal = div(mul(D1,old[i]),D0)
            diff = sub(ideal,new[i]) if ideal > new[i] else sub(new[i],ideal)
            fees[i] = div(mul(_fee,diff),FEE_DEN)
            st[i] = sub(new[i], div(mul(fees[i],ADMIN_FEE),FEE_DEN))
            new[i] = sub(new[i],fees[i])
        D2 = get_D_mem(new)
    else:
        st = new
    mint = D1 if ts == 0 else div(mul(ts,sub(D2,D0)),D0)
    return mint, st, fees, D1, D2

def remove_liquidity(state, amount, ts):
    st = list(state); amounts=[]
    for i in range(N):
        v = div(mul(st[i],amount),ts)
        st[i] = sub(st[i],v)
        amounts.append(v)
    return amounts, st

def remove_liquidity_imbalance(state, amounts, ts):
    _fee = div(mul(FEE,N), mul(4,sub(N,1)))
    old = list(state); new = list(old)
    D0 = get_D_mem(old)
    for i in range(N): new[i] = sub(new[i],amounts[i])
    D1 = get_D_mem(new)
    fees=[0]*N; st=list(state)
    for i in range(N):
        ideal = div(mul(D1,old[i]),D0)
        diff = sub(ideal,new[i]) if ideal > new[i] else sub(new[i],ideal)
        fees[i] = div(mul(_fee,diff),FEE_DEN)
        st[i] = sub(new[i], div(mul(fees[i],ADMIN_FEE),FEE_DEN))
        new[i] = sub(new[i],fees[i])
    D2 = get_D_mem(new)
    token_amount = div(mul(sub(D0,D2),ts),D0)
    if token_amount == 0: raise Rev("token_amount=0")
    return token_amount, st, fees, D0, D1, D2

# ---------- validation ----------
def validate():
    decs=[18,6,6,18]
    grids={i:([1,10**6,10**12,10**15,10**18,10**20,10**21,10**22,3*10**22] if decs[i]==18 else [1,1000,10**6,10**9,10**12,10**14,3*10**14]) for i in range(4)}
    reqs=[]; keys=[]
    for i in range(4):
        for j in range(4):
            if i==j: continue
            for dx in grids[i]:
                reqs.append(enc_call(P, get_dy_calldata(i,j,dx))); keys.append((i,j,dx))
    res = rpc_batch(reqs)
    mism=0; rpc_err=0
    for (i,j,dx), r in zip(keys,res):
        if isinstance(r, dict):
            if "execution reverted" in json.dumps(r): live="REVERT"
            else: rpc_err+=1; print(f"  RPCERR i={i} j={j} dx={dx}: {json.dumps(r)[:120]}"); continue
        else:
            live=int(r,16)
        try: mine=get_dy(BAL,i,j,dx)
        except Rev as e: mine=f"REVERT:{e}"
        if str(live)!=str(mine):
            mism+=1; print(f"  MISMATCH i={i} j={j} dx={dx}: live={live} model={mine}")
    print(f"get_dy validation: {len(keys)-mism-rpc_err}/{len(keys)} matches ({rpc_err} rpc errors)")
    return mism+rpc_err

# ---------- adversarial searches ----------
def search_zero_dx_walk():
    print("== dust walk: repeat zero-dx swaps (200 rounds, random-ish rotation) ==")
    st = list(BAL)
    total_gain = [0]*4
    positives = 0
    for r in range(200):
        for i in range(4):
            for j in range(4):
                if i==j: continue
                try:
                    d, st2, _ = exchange(st,i,j,0)
                except Rev:
                    continue
                if d > 0:
                    positives += 1
                    total_gain[j] += d
                    st = st2
    print(f"  positive zero-dx payouts: {positives}, cumulative raw gain per coin: {total_gain}")

def search_roundtrips():
    decs=[18,6,6,18]
    print("== 2-swap roundtrips (i->j->i), correct decimal grids ==")
    worst=(None,-10**40)
    for i in range(4):
        for j in range(4):
            if i==j: continue
            base = [10**k for k in range(0, 24)]
            for dx in base:
                try:
                    d1,s1,it1 = exchange(BAL,i,j,dx)
                    if d1 == 0: continue
                    d2,s2,it2 = exchange(s1,j,i,d1)
                except Rev:
                    continue
                profit = d2 - dx
                if profit > worst[1]: worst=((i,j,dx,d1,d2),profit)
    print("  best-for-attacker roundtrip profit (raw units of input coin):", worst[1], "at", worst[0])
    return worst

def search_roundtrips3():
    print("== 3-swap roundtrips (i->j->k->i) ==")
    best=(None,-10**40)
    for i,j,k in itertools.permutations(range(4),3):
        for dx in [10**c for c in range(0,23)]:
            try:
                d1,s1,_ = exchange(BAL,i,j,dx)
                if d1==0:
                    # zero-dx continuation: check step-by-step
                    d2,s2,_ = exchange(s1,j,k,0)
                    if d2==0: continue
                else:
                    d2,s2,_ = exchange(s1,j,k,d1)
                if d2==0: continue
                d3,s3,_ = exchange(s2,k,i,d2)
            except Rev:
                continue
            profit = d3-dx
            if profit > best[1]: best=((i,j,k,dx,d1,d2,d3),profit)
    print("  best:", best[1], "at", best[0])
    return best

def search_zero_dx():
    print("== dx=0 payouts (free tokens if >0) ==")
    tot=0
    for i in range(4):
        for j in range(4):
            if i==j: continue
            try:
                d,s,_=exchange(BAL,i,j,0)
            except Rev as e:
                print(f"  i={i}->j={j}: REVERT {e}"); continue
            if d>0: print(f"  i={i}->j={j}: FREE {d} raw units"); tot+=d
    print("  total free raw units per tx:", tot)

def search_convergence():
    print("== convergence stress (huge dx up to 1e24, all pairs) ==")
    worst_var=0; worst=None; noconv=0; revs=0
    for i in range(4):
        for j in range(4):
            if i==j: continue
            for e in range(0,25):
                dx=10**e
                try:
                    # same state, compute payout with cap 255 and cap 5000
                    xpv=xp(BAL)
                    x=add(xpv[i], div(mul(dx,RATES[i]),PRECISION))
                    y255,it255 = get_y(i,j,x,xpv,255)
                    y5000,it5000 = get_y(i,j,x,xpv,5000)
                except Rev:
                    revs+=1; continue
                var=abs(y255-y5000)
                if var>worst_var: worst_var=var; worst=(i,j,dx,y255,y5000,it255)
                if it255==255: noconv+=1
    print(f"  max |y255-y5000| (xp units): {worst_var} at {worst}; nonconverged(255): {noconv}; reverts: {revs}")

def search_add_remove():
    print("== add_liquidity -> immediate remove_liquidity roundtrip (fees => expect loss) ==")
    D=[10**18,10**6,10**6,10**18]
    best=(None,-10**40)
    tests=[]
    for i in range(4):
        tests.append([0]*i+[D[i]]+[0]*(3-i))                 # 1.0 token single coin
        tests.append([0]*i+[10000*D[i]]+[0]*(3-i))           # 10k tokens single coin
    tests.append([D[k] for k in range(4)])                   # balanced 1.0 each
    tests.append([10000*D[k] for k in range(4)])             # balanced 10k each
    tests.append([1000*10**18,1000*10**6,1000*10**6,1000*10**18])
    tests.append([10**18,10**6,10**6,10**18])                # tiny balanced
    for amounts in tests:
        try:
            mint, st, fees, D1, D2 = add_liquidity(BAL, amounts, SUPPLY)
            got, st2 = remove_liquidity(st, mint, SUPPLY+mint)
        except Rev as e:
            print("  add", amounts, "-> REVERT", e); continue
        net = [got[i]-amounts[i] for i in range(4)]
        usd = sum(net[i]*10**(18-[18,6,6,18][i]) for i in range(4))
        if usd > best[1]: best=(amounts,usd,mint,got,net)
        print(f"  add {amounts} mint={mint} net={net} netUSD1e18={usd}")
    print("  best net USD (1e18):", best[1])

def search_imbalance():
    print("== remove_liquidity_imbalance vs proportional exit (Route B - Route A) ==")
    decs=[18,6,6,18]
    D=[10**18,10**6,10**6,10**18]
    t = SUPPLY//1000   # attacker LP = 0.1% of supply
    prop = [div(BAL[i]*t,SUPPLY) for i in range(4)]
    prop_usd = sum(prop[i]*10**(18-decs[i]) for i in range(4))
    print(f"  attacker LP t={t}, proportional exit = {prop} (USD1e18={prop_usd})")
    best=(None,-10**40); tried=0; skipped=0
    # candidate amount vectors: fractions of balances, skewed
    fracs=[(1,1000),(1,100),(1,20),(1,10),(1,5),(1,4),(1,3),(1,2),(3,4),(9,10),(99,100)]
    cands=[]
    for i in range(4):
        for fn,fd in fracs:
            a=[0]*4; a[i]=div(BAL[i]*fn,fd); cands.append(a)
    # pairs skewed
    for i in range(4):
        for j in range(4):
            if i==j: continue
            for fn,fd in [(1,100),(1,20),(1,10)]:
                a=[0]*4; a[i]=div(BAL[i]*fn,fd); a[j]=div(BAL[j]*fn,fd); cands.append(a)
    # all-coin uniform fractions
    for fn,fd in [(1,1000),(1,100),(1,50),(1,20)]:
        cands.append([div(BAL[k]*fn,fd) for k in range(4)])
    for amt in cands:
        try:
            ta, st, fees, D0, D1, D2 = remove_liquidity_imbalance(BAL, amt, SUPPLY)
        except Rev:
            skipped+=1; continue
        if ta > t: skipped+=1; continue
        tried+=1
        # Route B: take amounts, then proportional-exit remaining LP in post state
        S2 = SUPPLY - ta
        rem = t - ta
        got = list(amt)
        for k in range(4):
            got[k] = add(got[k], div(st[k]*rem, S2)) if rem>0 else got[k]
        usd_b = sum(got[k]*10**(18-decs[k]) for k in range(4))
        # Route A: proportional exit of t from ORIGINAL state
        usd_a = prop_usd
        bonus = usd_b - usd_a
        if bonus > best[1]: best=(amt, bonus, ta, usd_a, usd_b, fees)
    print(f"  tried={tried} skipped={skipped}; best bonus USD1e18: {best[1]}")
    if best[0]: print(f"  best: amt={best[0]} ta={best[2]} usdA={best[3]} usdB={best[4]} fees={best[5]}")

def sbinary_dx(state, j, k, target_out, lo, hi):
    """largest dx in [lo,hi] with exchange(j,k,dx) output <= target_out; returns (dx,out)."""
    best=(0,0)
    while lo <= hi:
        mid=(lo+hi)//2
        try: out,_,_ = exchange(state,j,k,mid)
        except Rev: hi = mid-1; continue
        if out <= target_out:
            best=(mid,out); lo = mid+1
        else:
            hi = mid-1
    return best

def closed_cycle(amounts, verbose=False):
    m,st,_,_,_ = add_liquidity(BAL, amounts, SUPPLY)
    got, st = remove_liquidity(st, m, SUPPLY+m)
    net = [got[i]-amounts[i] for i in range(4)]
    state = st
    guard=0
    while guard < 40:
        guard+=1
        pos=[i for i in range(4) if net[i] > 0]
        neg=[i for i in range(4) if net[i] < 0]
        if not pos or not neg: break
        j=max(pos,key=lambda i:net[i]); k=min(neg,key=lambda i:net[i])
        target=-net[k]
        dx,out = sbinary_dx(state, j, k, target, 0, min(net[j], 10**30))
        if dx==0: break
        _,state,_ = exchange(state,j,k,dx)
        net[j]-=dx; net[k]+=out
    if verbose:
        print("   residual net after rebalance:", net)
    return net

def search_closed_cycles():
    print("== closed intra-pool cycles: deposit -> withdraw -> swap-rebalance ==")
    decs=[18,6,6,18]
    best=(None,-10**40)
    vectors=[]
    for k in [10,100,1000,5000,10000,20000,40000]:
        vectors.append([k*10**18,k*10**6,k*10**6,k*10**18])
    for k in [1000,10000]:
        vectors.append([k*10**18,0,0,0])
        vectors.append([0,k*10**6,0,0])
        vectors.append([0,0,k*10**6,0])
        vectors.append([0,0,0,k*10**18])
    vectors.append([10**18,10**6,10**6,10**18])
    for amt in vectors:
        try:
            res = closed_cycle(amt)
        except Rev as e:
            print("  ",amt,"REVERT",e); continue
        usd = sum(res[i]*10**(18-decs[i]) for i in range(4))
        if usd > best[1]: best=(amt,usd,res)
        print(f"  in={[a/10**decs[i] for i,a in enumerate(amt)]} residual={res} netUSD={usd/1e18:.6f}")
    print("  BEST (attacker residual value, USD):", best[1]/1e18, "at", best[0])


if __name__ == "__main__":
    print(f"block={BN} A={A} fee={FEE} admin_fee={ADMIN_FEE} supply={SUPPLY} vprice={VP}")
    print(f"balances={BAL}")
    bad = validate()
    if bad: print("VALIDATION FAILED - stopping"); sys.exit(1)
    # model sanity vs live views
    print("model vprice:", div(mul(get_D_mem(BAL),PRECISION),SUPPLY), "live:", VP)
    search_zero_dx()
    search_zero_dx_walk()
    search_roundtrips()
    search_roundtrips3()
    search_convergence()
    search_add_remove()
    search_imbalance()
