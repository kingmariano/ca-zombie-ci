const { Cell, Address } = require('@ton/core');
const fs = require('fs');
const j=JSON.parse(fs.readFileSync('/tmp/opencode/utonic/minter_data.json','utf8'));
const root=Cell.fromBoc(Buffer.from(j.stack[6].cell,'hex'))[0];
function unary(s){let r=0;while(s.loadBit())r++;return r;}
const out={};
function readValue(s){ const tag=s.loadUint(2); let addr='none'; if(tag===2){ s.loadUint(1); const wc=s.loadInt(8); const h=s.loadBuffer(32); addr=new Address(wc,h).toString(); } const type=s.loadUint(32); return {addr,type}; }
function parseNode(cell, n, prefix, depth){
  if (depth>60) return;
  const s=cell.beginParse();
  let l=0, pp=prefix;
  const lb0=s.loadBit()?1:0;
  if(lb0===0){ l=unary(s); for(let i=0;i<l;i++) pp+= s.loadBit()?'1':'0'; }
  else { const lb1=s.loadBit()?1:0;
    if(lb1===0){ l=s.loadUint(Math.ceil(Math.log2(n+1))); for(let i=0;i<l;i++) pp+= s.loadBit()?'1':'0'; }
    else { const v=s.loadBit()?'1':'0'; l=s.loadUint(Math.ceil(Math.log2(n+1))); for(let i=0;i<l;i++) pp+=v; } }
  const rem = n - l;
  if (rem === 0) { const id=parseInt(pp,2); out[id]={...readValue(s), kind:'leaf'}; return; }
  if (s.remainingRefs>=2){
    const left=s.loadRef(); const right=s.loadRef();
    if (s.remainingBits>0){ // hmn_both
      const id=parseInt(pp,2); out[id]={...readValue(s), kind:'both'};
    }
    parseNode(left, rem-1, pp+'0', depth+1);
    parseNode(right, rem-1, pp+'1', depth+1);
  } else {
    // odd node with 1 ref (possible in some dicts) - try single ref descent
    if (s.remainingRefs===1){ const only=s.loadRef(); out['SINGLE_'+pp]= {kind:'single'}; parseNode(only, rem-1, pp+'0', depth+1); }
    else console.log('odd node depth',depth,'refs',s.remainingRefs,'rem',rem);
  }
}
parseNode(root, 32, '', 0);
const sorted=Object.keys(out).sort((a,b)=>Number(a)-Number(b));
for (const k of sorted) console.log(k, JSON.stringify(out[k]));
fs.writeFileSync('/tmp/opencode/utonic/proxy_whitelist.json', JSON.stringify(out,null,1));
console.log('entries:', sorted.length);
