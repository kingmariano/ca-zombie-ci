import json,os,sys,urllib.request,time
UA="Mozilla/5.0 (X11; Linux x86_64) Firefox/128.0"
addrs=sys.argv[1:]
for a in addrs:
    f='raw/src/%s.sourcify.json'%a.lower()
    if os.path.exists(f): print('cached',a); continue
    url='https://sourcify.dev/server/v2/contract/1/%s?fields=sources,metadata,compilation'%a
    try:
        req=urllib.request.Request(url,headers={"User-Agent":UA})
        d=json.loads(urllib.request.urlopen(req,timeout=45).read().decode())
        json.dump(d,open(f,'w'))
        srcs=d.get('sources',{}) or {}
        print('OK',a,'match=',d.get('match'),'files=',list(srcs.keys())[:6])
    except Exception as e:
        print('FAIL',a,repr(e)[:150])
    time.sleep(0.4)
