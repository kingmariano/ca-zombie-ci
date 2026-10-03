import json, subprocess, concurrent.futures
RPC='https://ethereum-rpc.publicnode.com'
cp=json.load(open('weth_counterparties.json'))
pids={'chicken':0,'gov':2,'mystery':0,'star':0,'bdp':1}
out={}
for name,d in cp.items():
    addr=d['addr']; pid=pids[name]
    users=d['counterparties']
    def ui(u):
        r=subprocess.run(['cast','call',addr,'userInfo(uint256,address)(uint256,uint256)',str(pid),u,'--json','--rpc-url',RPC],capture_output=True,text=True)
        if r.returncode!=0: return (u,0,0)
        try:
            v=json.loads(r.stdout)
            return (u,int(v[0]),int(v[1]))
        except Exception: return (u,0,0)
    with concurrent.futures.ThreadPoolExecutor(max_workers=16) as ex:
        res=list(ex.map(ui,users))
    nz=[(u,a) for u,a,_ in res if a>0]
    tot=sum(a for _,a in nz)
    out[name]={'addr':addr,'pid':pid,'n_cp':len(users),'nz':[{'user':u,'amount':a} for u,a in nz],'sum':tot}
    print(f"{name}: cp={len(users)} nonzero={len(nz)} sum={tot/1e18:.6f} WETH", flush=True)
    for u,a in sorted(nz,key=lambda x:-x[1]): print('   ',u,a/1e18, flush=True)
json.dump(out,open('mc_userinfo.json','w'),indent=1)
print('DONE')
