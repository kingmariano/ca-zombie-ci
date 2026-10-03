import json,os,sys,urllib.request,time
UA="Mozilla/5.0 (X11; Linux x86_64) Firefox/128.0"
cache_f='raw/selectors_cache.json'
cache=json.load(open(cache_f)) if os.path.exists(cache_f) else {}
def resolve(sels):
    out={}
    todo=[s for s in sels if s not in cache]
    for s in todo:
        try:
            url='https://www.4byte.directory/api/v1/signatures/?hex_signature=0x%s'%s
            req=urllib.request.Request(url,headers={"User-Agent":UA})
            d=json.loads(urllib.request.urlopen(req,timeout=30).read().decode())
            names=sorted(set(r['text_signature'] for r in d.get('results',[])))
            cache[s]=names
        except Exception as e:
            cache[s]=['ERR:'+repr(e)[:60]]
        time.sleep(0.25)
    json.dump(cache,open(cache_f,'w'),indent=1)
    for s in sels:
        out[s]=cache.get(s)
    return out
if __name__=='__main__':
    sels=sys.argv[1:]
    r=resolve(sels)
    for s in sels:
        print(s, '->', r[s])
