const { Cell, Address } = require('@ton/core');
const fs = require('fs');
const d = JSON.parse(fs.readFileSync('/tmp/opencode/utonic/proxy_datas.json','utf8'));
function addr(s){ const tag=s.loadUint(2); if(tag===0) return 'none'; if(tag!==2) return 'tag'+tag; s.loadUint(1); const wc=s.loadInt(8); const h=s.loadBuffer(32); return new Address(wc,h).toString(); }
function coins(s){ const len=s.loadUint(4); let v=0n; for(let i=0;i<len;i++) v=(v<<8n)|BigInt(s.loadUint(8)); return v; }
const res=JSON.parse(fs.readFileSync('/tmp/opencode/utonic/proxies_parsed.json','utf8'));
for (const id of ['4','5','6','7','8','9','10','11','12']) {
  try {
    const root=Cell.fromBoc(Buffer.from(d[id].data_b64,'base64'))[0];
    const base=root.refs[0].beginParse();
    const ptype=base.loadUint(32), pid=base.loadUint(32), cap=coins(base);
    const addrCell=root.refs[1];
    const baseAddr=addrCell.refs[0].beginParse();
    const whale=addr(baseAddr), minter=addr(baseAddr);
    const recv=addrCell.refs[1].beginParse();
    const uton_receiver=addr(recv);
    const adminCell=addrCell.refs[2].beginParse();
    const admin=addr(adminCell), pending=addr(adminCell);
    res[id]={proxy_type:ptype, proxy_id:pid, layout:'whale3', capacity_ton:Number(cap)/1e9, whale, uton_receiver, minter, admin, pending, balance_ton:Number(d[id].balance)/1e9};
    console.log(JSON.stringify({id, ptype, pid, capacity:Number(cap)/1e9, whale, uton_receiver, admin}));
  } catch(e){ console.log(id,'ERR',e.message); }
}
fs.writeFileSync('/tmp/opencode/utonic/proxies_parsed.json', JSON.stringify(res,null,1));
