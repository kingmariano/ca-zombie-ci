import json, urllib.request, urllib.parse, time, sys, os
UA={"User-Agent":"Mozilla/5.0","Accept":"application/json"}
BASE="https://base.blockscout.com"
def get(url, params=None):
    if params: url=url+"?"+urllib.parse.urlencode(params)
    for a in range(5):
        try: return json.load(urllib.request.urlopen(urllib.request.Request(url,headers=UA),timeout=60))
        except Exception as e:
            sys.stderr.write(f"retry {a} {url} {e}\n"); time.sleep(2+2*a)
    raise RuntimeError("fail "+url)
def paginate(path, max_pages=200):
    url=BASE+path; out=[]; params=None; page=0
    while page<max_pages:
        d=get(url,params)
        items=d.get("items") or []
        out+=items
        page+=1
        if not d.get("next_page_params"): break
        params=d["next_page_params"]
        time.sleep(0.25)
    return out
if __name__=="__main__":
    V=sys.argv[1]; kind=sys.argv[2]; outf=sys.argv[3]
    items=paginate(f"/api/v2/addresses/{V}/{kind}")
    json.dump(items, open(outf,"w"))
    print(kind, "items:", len(items))
