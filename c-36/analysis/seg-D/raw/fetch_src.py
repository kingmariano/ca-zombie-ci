import json, time, urllib.request, os, sys

addrs = json.load(open('../../seg_D_addrs.json'))
# children: tokens/implementations/related
children = [
 "0xaaaf91d9b90df800df4f55c205fd6989c977e73a",  # TKN token
 "0xae7ab96520de3a18e5e111b5eaab095312d7fe84",  # stETH
 "0x707f9118e33a9b8998bea41dd0d46f38bb963fc8",  # bETH
 "0x3cbb7f5d7499af626026e96a2f05df806f2200dc",  # PandaDAO related
 "0x0314b6cc36ea9b48f34a350828ce98f17b76bc44",  # Rook related
 "0xa86e412109f77c45a3bc1c5870b880492fb86a14",  # Tokemak related
 "0x4d5f5ff50cc7fdbdc995d837ed467f6e99ca5d03",  # Celer related
 "0xceda8318522d348f1d1aca48b24629b8fbf09020",  # Set related
 "0x427a506ff6e15bd1b7e4e93da52c8ec95f6af127",  # Euler related
 "0x8bb71811bb40cb29613beb28f03182c0d7f400c9",  # Euler related
 "0xb0895da7ea0081b652c43dbe848fea6791ea2888",  # Nomad owner/beacon?
 "0x9522368481c84250fd4b2a4ea03fb875024d9956",  # MM owner
 "0xaeb5bcdb55e6abc2450595df27f993b82f375756",  # MM admin
 "0x71fdb72c1f1e2ed8cad11cf616c93bfb3cb055d5",  # PledgeDeposit related
 "0x79eb80d95da726f628b630839c256602a2acaf2e",  # QDT owner
]
alladdrs = addrs + children
outdir = 'src'
for a in alladdrs:
    fn = os.path.join(outdir, a.lower()+'.json')
    if os.path.exists(fn) and os.path.getsize(fn) > 50:
        continue
    url = 'https://eth.blockscout.com/api/v2/smart-contracts/'+a
    req = urllib.request.Request(url, headers={'User-Agent':'Mozilla/5.0 (X11; Linux x86_64) c36-analysis'})
    for attempt in range(4):
        try:
            with urllib.request.urlopen(req, timeout=30) as r:
                data = json.loads(r.read().decode())
            json.dump(data, open(fn,'w'))
            print(a, data.get('name'), 'verified=', data.get('is_verified'), flush=True)
            break
        except Exception as e:
            print('retry', a, e, flush=True)
            time.sleep(2+attempt*2)
    time.sleep(0.4)
