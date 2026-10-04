import json, urllib.request, time
facets=json.load(open('facets_live.json'))
out={}
for addr,sels in facets.items():
    out[addr]={}
    for s in sels:
        url=f'https://www.4byte.directory/api/v1/signatures/?hex_signature={s}'
        for attempt in range(3):
            try:
                with urllib.request.urlopen(url, timeout=15) as r:
                    d=json.load(r)
                names=[x['text_signature'] for x in d.get('results',[])]
                out[addr][s]=names
                break
            except Exception as e:
                time.sleep(1.5)
        else:
            out[addr][s]=['ERROR']
        time.sleep(0.35)
json.dump(out, open('selector_names.json','w'), indent=1)
# print grouped
for addr, m in out.items():
    print('==', addr)
    for s,names in m.items():
        print(' ', s, '=>', names[:4])
