const { Cell, Address } = require('@ton/core');
const fs = require('fs');
const d = JSON.parse(fs.readFileSync('/tmp/opencode/utonic/proxy_datas.json','utf8'));
function addrFromSlice(s){ const tag=s.loadUint(2); if(tag===0) return 'none'; if(tag!==2) return 'tag'+tag; s.loadUint(1); const wc=s.loadInt(8); const h=s.loadBuffer(32); return new Address(wc,h).toString(); }
function coins(s){ const len=s.loadUint(4); let v=0n; for(let i=0;i<len;i++) v=(v<<8n)|BigInt(s.loadUint(8)); return v; }
const res={};
for (const [id,v] of Object.entries(d)) {
  try {
    const root=Cell.fromBoc(Buffer.from(v.data_b64,'base64'))[0];
    const rc = root.refs.length;
    const dataCell=root.refs[0].beginParse();
    const proxy_type=dataCell.loadUint(32), proxy_id=dataCell.loadUint(32);
    let extra={};
    if (rc >= 4) { // proxy_ton layout
      const wpt=dataCell.loadUint(64); const debt=coins(dataCell);
      const addrCell=root.refs[1].beginParse();
      const minter=addrFromSlice(addrCell); const receiver=addrFromSlice(addrCell);
      const adminCell=root.refs[2].beginParse();
      extra={layout:'ton', withdraw_pending_time:wpt.toString(), debt_ton:Number(debt)/1e9, minter, ton_receiver:receiver, admin:addrFromSlice(adminCell), pending:addrFromSlice(adminCell)};
    } else if (rc === 2) { // lst layout
      const lst_price=dataCell.loadUint(64); const cap=coins(dataCell);
      const addrCell=root.refs[1].beginParse();
      const minter=addrFromSlice(addrCell);
      const adminCell=addrCell.loadRef().beginParse();
      const admin=addrFromSlice(adminCell), pending=addrFromSlice(adminCell);
      const recCell=addrCell.loadRef().beginParse();
      const lst_wallet=addrFromSlice(recCell); const lst_receiver=addrFromSlice(recCell);
      extra={layout:'lst', lst_price:Number(lst_price)/1e9, capacity:Number(cap)/1e9, minter, admin, pending, lst_wallet, lst_receiver};
    }
    res[id]={proxy_type, proxy_id, ...extra, balance_ton:Number(v.balance)/1e9};
    console.log(JSON.stringify({id, proxy_type, proxy_id, ...extra, bal:Number(v.balance)/1e9}));
  } catch(e){ console.log(id,'parse error', e.message); }
}
fs.writeFileSync('/tmp/opencode/utonic/proxies_parsed.json', JSON.stringify(res,null,1));
