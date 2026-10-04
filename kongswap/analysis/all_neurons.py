import json, urllib.request, time
BASE="https://sns-api.internetcomputer.org/api/v2/snses/ormnc-tiaaa-aaaaq-aadyq-cai/neurons"
def get(url):
    for _ in range(4):
        try:
            with urllib.request.urlopen(url, timeout=30) as r:
                return json.load(r)
        except Exception as e:
            time.sleep(2)
    raise RuntimeError("fail "+url)
alln=[]; after=None
for page in range(60):
    url=f"{BASE}?limit=100&sort_by=id" + (f"&after={after}" if after else "")
    d=get(url)
    data=d.get('data',[])
    if not data: break
    alln.extend(data)
    after=data[-1]['id']
    if len(data)<100: break
json.dump(alln, open('sns_neurons_all.json','w'))
print("total fetched:", len(alln))
tot=sum(x['voting_power'] for x in alln)
stake=sum(x['stake_e8s'] for x in alln)
print(f"total VP: {tot} ({tot/1e15:.4f}e15)")
print(f"total stake: {stake} ({stake/1e8:,.0f} KONG)")
from collections import Counter, defaultdict
states=Counter()
for x in alln:
    ds=x['dissolve_state']
    if 'DissolveDelaySeconds' in ds: states['NotDissolving']+=1
    elif 'WhenDissolvedTimestampSeconds' in ds: states['Dissolving']+=1
    else: states['Dissolved']+=1
print("states:", dict(states))
# dissolved stake (liquid)
ds_stake=sum(x['stake_e8s'] for x in alln if 'DissolveDelaySeconds' not in x['dissolve_state'] and 'WhenDissolvedTimestampSeconds' not in x['dissolve_state'])
print(f"dissolved stake: {ds_stake/1e8:,.0f} KONG")
# top clusters
byc=defaultdict(lambda: [0,0,0])
for x in alln:
    for c in (x.get('claimers') or ['?']):
        byc[c][0]+=x['voting_power']; byc[c][1]+=x['stake_e8s']; byc[c][2]+=1
print("\n== top 15 clusters by VP ==")
for c,(vp,st,n) in sorted(byc.items(), key=lambda kv:-kv[1][0])[:15]:
    print(f"{vp/1e15:8.3f}e15  stake {st/1e8:>14,.0f}  n={n:4d}  {c}")
