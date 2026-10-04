import re, json
raw = open('facets_raw.txt').read().strip()
# format: [(0x..., [0x..., ...]), ...]
pairs = re.findall(r'\((0x[0-9a-fA-F]{40}), \[([^\]]*)\]\)', raw)
out={}
for addr, sels in pairs:
    out[addr]=[s.strip() for s in sels.split(',') if s.strip()]
json.dump(out, open('facets_live.json','w'), indent=1)
print(json.dumps({k:len(v) for k,v in out.items()}, indent=1))
