import json, subprocess, time, sys
lines=[l.split() for l in open('/tmp/opencode/top_native_pools.txt') if l.strip()]
out={}
for addr, apinat in lines:
    body=json.dumps({"args":[]})
    cmd=['curl','-s','-X','POST',f'https://tonapi.io/v2/blockchain/accounts/{addr}/methods/get_reserves','-H','Content-Type: application/json','-d',body]
    r=subprocess.run(cmd,capture_output=True,text=True).stdout
    try:
        j=json.loads(r)
        dec=j.get('decoded',{})
        r0=int(dec.get('reserve0') or j['stack'][0].get('num'),0) if (dec or j.get('stack')) else None
        r1=int(dec.get('reserve1') or j['stack'][1].get('num'),0) if (dec or j.get('stack')) else None
        out[addr]={'reserve0':dec.get('reserve0'), 'reserve1':dec.get('reserve1'), 'api_native':apinat, 'exit':j.get('exit_code')}
        print(addr[:20], dec.get('reserve0'), dec.get('reserve1'), 'api_nat', int(float(apinat)))
    except Exception as e:
        print(addr, 'ERR', r[:100])
    time.sleep(1.1)
json.dump(out, open('/tmp/opencode/top_pools_live.json','w'), indent=1)
