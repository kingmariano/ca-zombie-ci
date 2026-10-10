const { Cell } = require('@ton/core');
function hx(s){return s.toString('hex')}
function addr(sl){ const tag=sl.loadUint(2); if(tag!==2) return `tag=${tag}`; const anyc=sl.loadUint(1); const wc=sl.loadInt(8); const a=sl.loadBuffer(32); return `${wc}:${a.toString('hex')} (anyc=${anyc})`; }
function coins(sl){ const len=sl.loadUint(4); let v=0n; for(let i=0;i<len;i++) v=(v<<8n)|BigInt(sl.loadUint(8)); return v; }
const bodies = {
  swap_external: "te6cckEBBAEAjwACa2HuVC067C2U21WegjD0JAgBc0+5wyhjasCISpjTCx0bgj/YuA7Dvagrxw33yWnCLepBvS88xAECAIeAC+Csn2vsCPB7auBjnDns0VEamprbTbybZEVpckGt+wAAIgFiJ1MpagSULOM+0icmUdbrKy2HFEvrIFFijf2bhsQ7/QIJaPohWg4DAwAILhz6gkXaE2E=",
  payout_from_pool: "te6cckEBAwEAgwACZK1OtvU67C2U21WegkHBrJaYAXNPucMoY2rAiEqY0wsdG4I/2LgOw72oK8cN98lpwi3rAQIAiYAL4Kyfa+wI8Htq4GOcOezRURqamttNvJtkRWlyQa37AABAEAsROplLUCShZxn2kTkyjrdZWWw4ol9ZAosUb+zcNiHf6AAILhz6gjnpTMU=",
  payout: "te6cckEBAgEAFgABGUdPhs867C2U21WegsABAAguHPqC7qVRkw=="
};
for (const [name,b64] of Object.entries(bodies)) {
  const c=Cell.fromBoc(Buffer.from(b64,'base64'))[0]; const s=c.beginParse();
  console.log(`\n=== ${name} bits=${c.bits.length} refs=${c.refs.length}`);
  console.log('op=0x'+s.loadUintBig(32).toString(16));
  console.log('qid='+s.loadUintBig(64).toString());
  if (name==='payout') { const m=s.loadUint(1); console.log('hasRef(maybe)='+m); console.log('restbits='+s.remainingBits+' hex='+hx(s.loadBuffer(s.remainingBits/8))); continue; }
  console.log('amount='+coins(s).toString());
  console.log('addr='+addr(s));
  const rem=s.remainingBits, remRefs=s.remainingRefs;
  console.log('remaining bits='+rem+' refs='+remRefs);
  console.log('rest hex='+hx(s.loadBuffer(Math.floor(rem/8))));
}
