const { Cell, Address } = require('@ton/core');
const fs = require('fs');
const j = JSON.parse(fs.readFileSync('/tmp/opencode/utonic/minter_data.json','utf8'));
const st = j.stack;
function num(x){ return BigInt(x.num); }
const total_supply = num(st[0]), last_price_day = Number(num(st[1])), last_price = num(st[2]), price_inc = num(st[3]);
const adminCell = Cell.fromBoc(Buffer.from(st[4].cell,'hex'))[0];
const pendCell = Cell.fromBoc(Buffer.from(st[5].cell,'hex'))[0];
const wlCell = Cell.fromBoc(Buffer.from(st[6].cell,'hex'))[0];
function readAddr(c){ const s=c.beginParse(); const tag=s.loadUint(2); if(tag===0) return 'none'; const anyc=s.loadUint(1); const wc=s.loadInt(8); const h=s.loadBuffer(32); return wc+':'+h.toString('hex'); }
console.log('total_supply(uton raw)', total_supply.toString(), '=', Number(total_supply)/1e9);
console.log('last_price_day', last_price_day, '->', new Date(last_price_day*86400*1000).toISOString().slice(0,10));
console.log('last_price', last_price.toString(), 'price_inc', price_inc.toString());
const today = Math.floor(Date.now()/1000/86400);
console.log('today_day', today, 'days_diff', today-last_price_day);
const price = last_price + price_inc*BigInt(today-last_price_day);
console.log('computed price(raw)', price.toString(), 'TON per uTON =', Number(price)/1e9);
console.log('admin =', readAddr(adminCell), 'pending =', readAddr(pendCell));
fs.writeFileSync('/tmp/opencode/utonic/minter_parsed.json', JSON.stringify({total_supply: total_supply.toString(), last_price_day, last_price: last_price.toString(), price_inc: price_inc.toString(), price_now_raw: price.toString(), price_ton_per_uton: Number(price)/1e9, admin: readAddr(adminCell), pending_admin: readAddr(pendCell)}, null, 1));
// parse whitelist dict: HashmapE 32 -> slice
// standard hashmap parsing
function readLabel(s){
  // returns [prefixBitsLengthHint] simplified
  const b = s.loadBit();
  if (!b) { // hml_short: unary len
    let len = 0; while (s.loadBit()) len++;
    const bits = s.loadBits(len);
    return {m:0, len, skip:false};
  }
  const b2 = s.loadBit();
  if (!b2) { // hml_same
    return {m:1};
  }
  const b3 = s.loadBit();
  if (b3 === false) { // hml_long
    const len = s.loadUint(5); return {m:2, len};
  } else {
    const len = s.loadUint(9); return {m:3, len};
  }
}
// Use @ton/core Dictionary parsing with custom value loader via cell slices is not supported; manual recursive parser:
function parseHashmap(cell, keyPrefix=0n, keyBits=0, out={}){
  const s = cell.beginParse();
  // label
  const m = s.loadBit();
  let labelBits = 0n, labelLen = 0;
  if (!m) {
    let len=0; while(s.loadBit()) len++;
    labelBits = s.loadBits(len).reduce ? 0n : 0n;
    // gather bits
    const bits = s.loadBits(len); let v=0n; for (let i=0;i<len;i++){ v=(v<<1n)|BigInt(bits[i]); }
    labelBits=v; labelLen=len;
    if (s.remainingBits === 0 && s.remainingRefs === 0) return out; // empty
    if (s.remainingBits === 1){ /*hm_edge with 1 bit?*/ }
    // hm_edge: label + (n:2 bits) + left/right refs
    const n = s.loadUint(2);
    const left = s.remainingRefs>0 ? s.loadRef() : (n & 2 ? null : null);
    const right = s.remainingRefs>0 ? s.loadRef() : null;
    const fullKey = (keyPrefix << BigInt(labelLen)) | labelBits;
    const childKeyBits = keyBits + labelLen;
    if (n === 2) { // leaf: value follows in this cell after label? Actually for hml_short leaf, value is in same cell after label
      // value: address slice + uint32
      const tag = s.loadUint(2); let addr='none';
      if (tag === 2){ const anyc=s.loadUint(1); const wc=s.loadInt(8); const h=s.loadBuffer(32); addr=wc+':'+h.toString('hex'); }
      const t = s.loadUint(32);
      out[fullKey.toString()] = {addr, type: t};
      return out;
    }
    if (n === 0) { parseHashmap(left, fullKey<<1n, childKeyBits+1, out); parseHashmap(right, (fullKey<<1n)|1n, childKeyBits+1, out); }
    else if (n === 1) { parseHashmap(left, fullKey<<1n, childKeyBits+1, out); }
    else if (n === 3) { parseHashmap(left, fullKey<<1n, childKeyBits+1, out); parseHashmap(right, (fullKey<<1n)|1n, childKeyBits+1, out); }
  } else {
    console.log('label type not handled (same/long)');
  }
  return out;
}
try { const wl = parseHashmap(wlCell); console.log('whitelist entries:', Object.keys(wl).length); fs.writeFileSync('/tmp/opencode/utonic/proxy_whitelist.json', JSON.stringify(wl,null,1)); for (const [k,v] of Object.entries(wl)) console.log(' id',k, v); } catch(e){ console.log('dict parse error', e.message); }
