const { Address, beginCell, external, storeMessage, internal, Cell } = require('@ton/core');
const { WalletContractV3R2 } = require('@ton/ton');
const fs = require('fs');
const https = require('https');
const WALLET = Address.parse('UQC5p9zhlDG1YEQlTGmFjo3BH-xcB2He1BXjhvvktOEW9Xi0'); // wallet_v3r2, balance ~1.55 TON, from public test data
const probes = JSON.parse(fs.readFileSync('probes.json','utf8'));

function httpPost(url, json){ return new Promise((res,rej)=>{ const data=Buffer.from(JSON.stringify(json)); const u=new URL(url); const req=https.request({hostname:u.hostname,path:u.pathname+u.search,method:'POST',headers:{'Content-Type':'application/json','Content-Length':data.length}},r=>{let b='';r.on('data',c=>b+=c);r.on('end',()=>{try{res({status:r.statusCode, body:JSON.parse(b)})}catch(e){res({status:r.statusCode, body:b})}})}); req.on('error',rej); req.write(data); req.end(); }); }
function httpGet(url){ return new Promise((res,rej)=>{ https.get(url,r=>{let b='';r.on('data',c=>b+=c);r.on('end',()=>{try{res(JSON.parse(b))}catch(e){res(b)}})}).on('error',rej); }); }
const sleep = ms => new Promise(r=>setTimeout(r,ms));

async function getWalletState(){
  // read data cell via toncenter
  const r = await httpGet('https://toncenter.com/api/v2/getAddressInformation?address='+encodeURIComponent(WALLET.toString()));
  const dataBoc = r.result.data;
  const d = Cell.fromBoc(Buffer.from(dataBoc,'base64'))[0].beginParse();
  const seqno = d.loadUint(32); const subwallet = d.loadUint(32); const pubkey = d.loadBuffer(32);
  return {seqno, subwallet, pubkey};
}
async function buildExternal(destAddr, bodyCell, valueNano){
  const st = await getWalletState();
  const kp = { publicKey: st.pubkey, secretKey: Buffer.alloc(64) };
  const wallet = WalletContractV3R2.create({ workchain: 0, publicKey: st.pubkey });
  // override wallet id if needed: build transfer manually to control subwallet id
  const outMsg = internal({ to: destAddr, value: BigInt(valueNano), bounce: true, body: bodyCell });
  const transfer = beginCell()
    .storeBuffer(Buffer.alloc(64))     // signature placeholder (ignored)
    .storeUint(st.subwallet, 32)
    .storeUint(Math.floor(Date.now()/1000)+600, 32)
    .storeUint(st.seqno, 32)
    .storeUint(0, 8)                   // op
    .storeRef(beginCell().storeUint(3, 8).store(require('@ton/core').storeMessage(outMsg)).endCell()) // mode 3, msg ref
    .endCell();
  const ext = external({ to: WALLET, body: transfer });
  return { boc: beginCell().store(storeMessage(ext)).endCell().toBoc().toString('hex'), seqno: st.seqno, subwallet: st.subwallet };
}

(async ()=>{
  const destMap = {
    p1_swap_overclaim:'EQDa4VOnTYlLvDJ0gZjNYm5PXfSmmtL6Vs6A_CZEtXCNICq_',
    p2_forge_payout_from_real_pool:'EQDa4VOnTYlLvDJ0gZjNYm5PXfSmmtL6Vs6A_CZEtXCNICq_',
    p3_forge_payout_fake_pool:'EQDa4VOnTYlLvDJ0gZjNYm5PXfSmmtL6Vs6A_CZEtXCNICq_',
    p4_spoof_jetton_notify_swap:'EQAYqo4u7VF0fa4DPAebk4g9lBytj2VFny7pzXR0trjtXQaO',
    p5_collect_fees_attacker:'EQA-X_yo3fzzbDbJ_0bzFWKqtRuZFIRa1sJsveZJ1YpViO3r',
    p6_configure_trade_fee:'EQA-X_yo3fzzbDbJ_0bzFWKqtRuZFIRa1sJsveZJ1YpViO3r',
    p7_configure_start_time:'EQA-X_yo3fzzbDbJ_0bzFWKqtRuZFIRa1sJsveZJ1YpViO3r',
    p8_configure_quote_provider:'EQA-X_yo3fzzbDbJ_0bzFWKqtRuZFIRa1sJsveZJ1YpViO3r',
    p9_configure_fee_collector:'EQA-X_yo3fzzbDbJ_0bzFWKqtRuZFIRa1sJsveZJ1YpViO3r',
    p10_payout_direct:'EQDa4VOnTYlLvDJ0gZjNYm5PXfSmmtL6Vs6A_CZEtXCNICq_',
  };
  const only = process.argv[2];
  for (const [name, hex] of Object.entries(probes)){
    if (only && only!==name) continue;
    try{
      const dest = Address.parse(destMap[name]);
      const bodyCell = Cell.fromBoc(Buffer.from(hex,'hex'))[0];
      // The probe BOC is a Message; extract its body: re-build internal directly instead
      const msg = bodyCell; // our probes stored full Message BOC
      // decode message to get body & value
      const cs = msg.beginParse();
      // skip fields: ihr_disabled, bounce, bounced, src, dest, value(coins), ihr_fee, fwd_fee, lt, at, body
      cs.loadBit(); cs.loadBit(); cs.loadBit();
      const src = cs.loadAddress(); const dest2 = cs.loadAddress();
      const val = cs.loadCoins();
      cs.loadCoins(); cs.loadCoins(); // fees
      cs.loadUintBig(64); cs.loadUint(32);
      const body = cs.loadRef();
      const {boc, seqno, subwallet} = await buildExternal(dest, body, val);
      const r = await httpPost('https://tonapi.io/v2/traces/emulate?ignore_signature_check=true', {boc});
      fs.writeFileSync(`/tmp/opencode/emul/${name}.json`, JSON.stringify(r.body,null,1));
      console.log(`## ${name} -> HTTP ${r.status} ${r.body.error?'ERROR: '+r.body.error:''}`);
      if (r.body.transactions){
        const txs = [];
        const walk=(t)=>{ txs.push({acct:t.account.address, end:t.end_status, op:t.in_msg?.opcode, dec:t.in_msg?.decoded_opcode, out:(t.out_msgs||[]).map(o=>({op:o.opcode,dec:o.decoded_opcode,to:o.destination,val:o.value}))}); (t.children||[]).forEach(walk); };
        walk(r.body);
        console.log(JSON.stringify(txs,null,1).slice(0,2500));
      }
    }catch(e){ console.log(`## ${name} EXC ${e.message}`); }
    await sleep(1400);
  }
})();
