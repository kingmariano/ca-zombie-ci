import json, urllib.request, time, os
selmap = json.load(open('raw/selector_map.json'))
addrs = json.load(open('../seg_B_addrs.json'))
wl = json.load(open('../worklist.json'))
wl = {k.lower(): v for k,v in wl.items()}
need = set()
for a in addrs:
    for s in wl[a.lower()]['selectors']:
        if s == 'ffffffff': continue
        if not selmap.get(s):
            need.add(s)
print("need", len(need), flush=True)
for i,s in enumerate(sorted(need)):
    try:
        req = urllib.request.Request(f"https://www.4byte.directory/api/v1/signatures/?hex_signature=0x{s}", headers={"User-Agent":"Mozilla/5.0"})
        d = json.loads(urllib.request.urlopen(req, timeout=12).read())
        names = [r['text_signature'] for r in d.get('results',[])]
        selmap[s] = names
    except Exception as e:
        selmap[s] = []
    if i % 10 == 0:
        json.dump(selmap, open('raw/selector_map.json','w'), indent=1)
        print(i, s, selmap.get(s), flush=True)
    time.sleep(0.2)
json.dump(selmap, open('raw/selector_map.json','w'), indent=1)
print("DONE", flush=True)
