'use strict';
// Minimal Solana helpers: base58, PDA finder (ed25519 on-curve check), discriminator.
const crypto = require('crypto');

const B58 = '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';
function b58encode(buf) {
  let n = 0n;
  for (const b of buf) n = n * 256n + BigInt(b);
  let s = '';
  while (n > 0n) { s = B58[Number(n % 58n)] + s; n /= 58n; }
  for (const b of buf) { if (b === 0) s = '1' + s; else break; }
  return s;
}
function b58decode(s) {
  let n = 0n;
  for (const c of s) {
    const i = B58.indexOf(c);
    if (i < 0) throw new Error('bad b58 char ' + c);
    n = n * 58n + BigInt(i);
  }
  const bytes = [];
  while (n > 0n) { bytes.unshift(Number(n % 256n)); n /= 256n; }
  for (const c of s) { if (c === '1') bytes.unshift(0); else break; }
  return Buffer.from(bytes);
}
// --- ed25519 point decompression (on-curve check) ---
const P = 2n ** 255n - 19n;
const D = 37095705934669439343138083508754565189542113879843219016388785533085940283555n;
const I = 19681161376707505956807079304988542015446066515923890162744021073123829784752n; // sqrt(-1)
function mod(a, m) { return ((a % m) + m) % m; }
function powmod(b, e, m) { let r = 1n; b = mod(b, m); while (e > 0n) { if (e & 1n) r = mod(r * b, m); b = mod(b * b, m); e >>= 1n; } return r; }
function isOnCurve(buf) {
  if (buf.length !== 32) return false;
  const y = Buffer.from(buf); y[31] &= 0x7f;
  let yb = 0n; for (let i = 31; i >= 0; i--) yb = (yb << 8n) | BigInt(y[i]);
  if (yb >= P) return false;
  const y2 = mod(yb * yb, P);
  const u = mod(y2 - 1n, P), v = mod(D * y2 + 1n, P);
  // x^2 = u/v ; check sqrt exists: (u/v)^((p-1)/2) == 1
  const v3 = mod(v * v % P * v, P);
  const v7 = mod(v3 * v3 % P * v, P);
  const uv3 = mod(u * v3, P), uv7 = mod(u * v7, P);
  const x = mod(uv3 * powmod(uv7, (P - 5n) / 8n, P), P);
  const x2 = mod(x * x, P);
  if (x2 === mod(u * mod(v, P) === 0n ? 0n : powmod(v, P - 2n, P), P)) return true;
  // standard: check x^2 == u/v or x^2 == u/v * -1 (x = x*sqrt(-1))
  const xI = mod(x * I, P);
  const xI2 = mod(xI * xI, P);
  const invv = powmod(v, P - 2n, P);
  const uv = mod(u * invv, P);
  return x2 === uv || xI2 === uv;
}
function sha256(buf) { return crypto.createHash('sha256').update(buf).digest(); }
function findProgramAddress(seeds, programId) {
  const pid = typeof programId === 'string' ? b58decode(programId) : programId;
  for (let nonce = 255; nonce >= 0; nonce--) {
    const b = Buffer.concat([...seeds.map(s => typeof s === 'string' ? Buffer.from(s, 'utf8') : Buffer.from(s)), Buffer.from([nonce]), pid, Buffer.from('ProgramDerivedAddress')]);
    const h = sha256(b);
    if (!isOnCurve(h)) return { address: b58encode(h), bump: nonce };
  }
  throw new Error('no PDA found');
}
function anchorDisc(name) { return sha256(Buffer.from('global:' + name, 'utf8')).subarray(0, 8); }
module.exports = { b58encode, b58decode, findProgramAddress, anchorDisc, sha256, isOnCurve };

if (require.main === module) {
  const [,, cmd, ...args] = process.argv;
  if (cmd === 'pda') {
    // usage: node solana_helpers.js pda <jsonseeds> <programId>
    const seeds = JSON.parse(args[0]).map(s => s === null ? Buffer.alloc(0) : s);
    console.log(JSON.stringify(findProgramAddress(seeds, args[1])));
  } else if (cmd === 'disc') {
    for (const n of args) console.log(n, anchorDisc(n).toString('hex'));
  }
}
