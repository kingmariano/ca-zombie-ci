const { Address, beginCell, external, storeMessage, storeMessageRelaxed, internal, Cell } = require('@ton/core');
const fs = require('fs');
const https = require('https');
const WALLET = Address.parse('UQC5p9zhlDG1YEQlTGmFjo3BH-xcB2He1BXjhvvktOEW9Xi0');
const probes = JSON.parse(fs.readFileSync('probes2.json','utf8'));
function httpPost(url, json){ return new Promise((res,rej)=>{ const data=Buffer.from(JSON.stringify(json)); const u=new URL(url); const req=https.request({hostname:u.hostname,path:u.pathname+u.search,method:'POST',headers:{'Content-Type':'application/json','Content-Length':data.length}},r=>{let b='';r.on('data',c=>b+=c);r.on('end',()=>{try{res({status:r.statusCode, body:JSON.parse(b)})}catch(e){res({status:r.statusCode, body:b})}})}); req.on('error',rej); req.write(data); req.end(); }); }
function httpGet(url){ return new Promise((res,rej)=>{ https.get(url,r=>{let b='';r.on('data',c=>b+=c);r.on('end',()=>{try{res(JSON.parse(b))}catch(e){res(b)}})}).on('error',rej); }); }
const sleep = ms => new Promise(r=>setTimeout(r,ms));
async function getWalletState(){
  const r = await httpGet('https://toncenter.com/api/v2/getAddressInformation?address='+encodeURIComponent(WALLET.toString()));
  const d = Cell.fromBoc(Buffer.from(r.result.data,'base64'))[0].beginParse();
  return {seqno: d.loadUint(32), subwallet: d.loadUint(32), pubkey: d.loadBuffer(32)};
}
async function emulate(name, p){
  const st = await getWalletState();
  const dest = Address.parse(p.target);
  const body = Cell.fromBoc(Buffer.from(p.body,'hex'))[0];
  const outMsg = internal({to: dest, value: BigInt(p.value), bounce: true, body});
  const transfer = beginCell()
    .storeBuffer(Buffer.alloc(64))
    .storeUint(st.subwallet,32)
    .storeUint(Math.floor(Date.now()/1000)+600,32)
    .storeUint(st.seqno,32)
    .storeUint(3,8)
    .storeRef(beginCell().store(storeMessageRelaxed(outMsg)).endCell())
    .endCell();
  const ext = external({to: WALLET, body: transfer});
  const boc = beginCell().store(storeMessage(ext)).endCell().toBoc().toString('hex');
  const r = await httpPost('https://tonapi.io/v2/traces/emulate?ignore_signature_check=true', {boc});
  fs.writeFileSync(`/tmp/opencode/emul/${name}.json`, JSON.stringify(r.body,null,1));
  const lines = [];
  const walk=(node,d)=>{ const t=node.transaction; if(!t) return;
    const outs=(t.out_msgs||[]).map(o=>`${o.op_code}//${o.decoded_opcode||'-'}->${(o.destination&&o.destination.address)||'ext'} val=${o.value}`).join(' ; ');
    lines.push(`${d}TX ${t.account.address} ok=${t.success} aborted=${t.aborted} exit=${t.compute_phase.exit_code}${t.compute_phase.exit_code_description?('('+t.compute_phase.exit_code_description+')'):''} action=${t.action_phase?t.action_phase.result_code:'-'} IN=${t.in_msg?t.in_msg.op_code:'-'}/${t.in_msg?t.in_msg.decoded_opcode||'-':'-'} from=${t.in_msg&&t.in_msg.source?t.in_msg.source.address||'ext':'-'} OUT=[${outs}]`);
    (node.children||[]).forEach(c=>walk(c,d+'  ')); };
  walk(r.body,'');
  console.log(`\n########## ${name} HTTP ${r.status}${r.body.error?(' ERROR '+r.body.error):''}\n` + lines.join('\n'));
}
(async()=>{
  const only = process.argv[2];
  for (const [name,p] of Object.entries(probes)){ if (only && name!==only) continue; try { await emulate(name,p); } catch(e){ console.log(name,'EXC',e.message);} await sleep(1500); }
})();
