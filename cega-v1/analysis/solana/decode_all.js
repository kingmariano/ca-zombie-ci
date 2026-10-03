'use strict';
// Decode Cega V1 Solana program accounts using the public IDL layouts.
const fs = require('fs');
const path = require('path');
const { b58encode } = require('./solana_helpers.js');
const D = __dirname;
const raw = JSON.parse(fs.readFileSync(path.join(D, 'all_accounts.json'), 'utf8'));
if (!raw.result) { console.error('no result', JSON.stringify(raw).slice(0, 300)); process.exit(1); }

const PK = (b) => b58encode(Buffer.from(b));
const U64 = (b, o) => Number(b.readBigUInt64LE(o));
const I64 = (b, o) => Number(b.readBigInt64LE(o));
const U32 = (b, o) => b.readUInt32LE(o);
const U8 = (b, o) => b[o];
const BOOL = (b, o) => b[o] !== 0;
const NAME = (b, o) => Buffer.from(b.subarray(o, o + 32)).toString('utf8').replace(/\0+$/, '').trim();

const state = []; const products = []; const vaults = []; const spis = []; const barriers = [];
const qheaders = []; const qnodes = []; const deposits = [];

for (const a of raw.result) {
  const b = Buffer.from(a.account.data[0], 'base64');
  const pk = a.pubkey; const len = b.length;
  if (len === 212) {
    state.push({
      pubkey: pk, owner: a.account.owner, lamports: a.account.lamports,
      stateNonce: U8(b, 8), productAuthorityNonce: U8(b, 9),
      programAdmin: PK(b.subarray(10, 42)), admin: PK(b.subarray(42, 74)), nextAdmin: PK(b.subarray(74, 106)),
      yieldFeePercentage: U32(b, 106), managementFeePercentage: U32(b, 110),
      feeRecipient: PK(b.subarray(114, 146)), traderAdmin: PK(b.subarray(146, 178)),
      programUsdcTokenAccount: PK(b.subarray(178, 210)),
      extraBoolOne: BOOL(b, 210), extraBoolTwo: BOOL(b, 211)
    });
  } else if (len === 285) {
    products.push({
      pubkey: pk, productName: NAME(b, 8), productNonce: U8(b, 40), productUnderlyingTokenAccountNonce: U8(b, 41),
      productCounter: U64(b, 42), underlyingMint: PK(b.subarray(50, 82)),
      productUnderlyingTokenAccount: PK(b.subarray(82, 114)),
      maxDepositLimit: U64(b, 114), underlyingAmount: U64(b, 122),
      mapleAccount: PK(b.subarray(130, 162)), depositQueueHeaderNonce: U8(b, 162),
      depositQueueHeader: PK(b.subarray(163, 195)), isActive: BOOL(b, 195),
      managementFeePercentage: U64(b, 196),
      extraPubkeyOne: PK(b.subarray(204, 236)), extraPubkeyTwo: PK(b.subarray(236, 268)),
      extraUint64Two: U64(b, 268), extraUint64Three: U64(b, 276), extraBoolOne: BOOL(b, 284),
      lamports: a.account.lamports
    });
  } else if (len === 514) {
    let o = 8;
    const productName = NAME(b, o); o += 32;
    const vaultNumber = U64(b, o); o += 8;
    const status = U8(b, o); o += 1;
    const nonces = {}; for (const n of ['vaultNonce','redeemableMintNonce','optionMintNonce','vaultUnderlyingTokenAccountNonce','vaultOptionTokenAccountNonce','vaultWithdrawQueueRedeemableTokenAccountNonce','withdrawQueueHeaderNonce','structuredProductInfoAccountNonce']) { nonces[n] = U8(b, o); o += 1; }
    const underlyingMint = PK(b.subarray(o, o+32)); o += 32;
    const redeemableMint = PK(b.subarray(o, o+32)); o += 32;
    const optionMint = PK(b.subarray(o, o+32)); o += 32;
    const vaultUnderlyingTokenAccount = PK(b.subarray(o, o+32)); o += 32;
    const vaultOptionTokenAccount = PK(b.subarray(o, o+32)); o += 32;
    const vaultWithdrawQueueRedeemableTokenAccount = PK(b.subarray(o, o+32)); o += 32;
    const underlyingAmount = U64(b, o); o += 8;
    const vaultTotalCouponPayoff = U64(b, o); o += 8;
    const knockInEvent = BOOL(b, o); o += 1;
    const knockOutEvent = BOOL(b, o); o += 1;
    const vaultFinalPayoff = U64(b, o); o += 8;
    const epochSequenceNumber = U64(b, o); o += 8;
    const startEpoch = U64(b, o); o += 8;
    const endEpoch = U64(b, o); o += 8;
    const epochCadence = U32(b, o); o += 4;
    const startDeposits = U64(b, o); o += 8;
    const endDeposits = U64(b, o); o += 8;
    const tradeDate = U64(b, o); o += 8;
    const withdrawQueueHeader = PK(b.subarray(o, o+32)); o += 32;
    const structuredProductInfoAccount = PK(b.subarray(o, o+32)); o += 32;
    vaults.push({ pubkey: pk, productName, vaultNumber, status, ...nonces, underlyingMint, redeemableMint, optionMint,
      vaultUnderlyingTokenAccount, vaultOptionTokenAccount, vaultWithdrawQueueRedeemableTokenAccount,
      underlyingAmount, vaultTotalCouponPayoff, knockInEvent, knockOutEvent, vaultFinalPayoff,
      epochSequenceNumber, startEpoch, endEpoch, epochCadence, startDeposits, endDeposits, tradeDate,
      withdrawQueueHeader, structuredProductInfoAccount });
  } else if (len === 332) {
    let o = 8;
    const nonce = U8(b, o); o += 1;
    const epochSequenceNumber = U64(b, o); o += 8;
    const numberOfPuts = U64(b, o); o += 8;
    const puts = []; for (let i = 0; i < 5; i++) { puts.push(PK(b.subarray(o, o+32))); o += 32; }
    const aprPercentage = U64(b, o); o += 8;
    const tenorInDays = U64(b, o); o += 8;
    const daysPassed = U64(b, o); o += 8;
    spis.push({ pubkey: pk, nonce, epochSequenceNumber, numberOfPuts, puts, aprPercentage, tenorInDays, daysPassed });
  } else if (len === 367) {
    let o = 8;
    const nonce = U8(b, o); o += 1;
    const optionExists = BOOL(b, o); o += 1;
    const assetName = NAME(b, o); o += 32;
    const optionNumber = U64(b, o); o += 8;
    const assetMint = PK(b.subarray(o, o+32)); o += 32;
    // IDL order (may have drifted; keep raw tails for reference)
    barriers.push({ pubkey: pk, nonce, optionExists, assetName, optionNumber, assetMint, tailHex: b.subarray(o, o+16).toString('hex'), len });
  } else if (len === 88) {
    const count = U64(b, 8), seqNum = U64(b, 16), head = PK(b.subarray(24, 56)), tail = PK(b.subarray(56, 88));
    qheaders.push({ pubkey: pk, count, seqNum, head, tail });
  } else if (len === 80) {
    const amount = U64(b, 8), nextNode = PK(b.subarray(16, 48)), userKey = PK(b.subarray(48, 80));
    qnodes.push({ pubkey: pk, amount, nextNode, userKey });
  } else if (len === 113) {
    deposits.push({ pubkey: pk, nonce: U8(b, 8), userKey: PK(b.subarray(9, 41)), product: PK(b.subarray(41, 73)), vault: PK(b.subarray(73, 105)), usdcDeposit: U64(b, 105) });
  }
}

const st = state[0] || null;
const productByPk = Object.fromEntries(products.map(p => [p.pubkey, p]));
const vaultByPk = Object.fromEntries(vaults.map(v => [v.pubkey, v]));
const qheaderByPk = Object.fromEntries(qheaders.map(q => [q.pubkey, q]));

// queue aggregates: walk deposit queue of each product and withdraw queue of each vault
function walkQueue(headerPk, nodesByPk) {
  const h = qheaderByPk[headerPk]; const out = []; let cur = h ? h.head : null; let guard = 0;
  while (cur && guard < 100000) {
    const n = nodesByPk[cur]; if (!n) break; out.push(n);
    cur = n.nextNode === '11111111111111111111111111111111' ? null : n.nextNode; guard++;
  }
  return { header: h || null, nodes: out, total: out.reduce((s, n) => s + n.amount, 0) };
}
const nodesByPk = Object.fromEntries(qnodes.map(n => [n.pubkey, n]));
const depositQueues = {};
for (const p of products) depositQueues[p.pubkey] = walkQueue(p.depositQueueHeader, nodesByPk);
const withdrawQueues = {};
for (const v of vaults) if (v.withdrawQueueHeader !== '11111111111111111111111111111111') withdrawQueues[v.pubkey] = walkQueue(v.withdrawQueueHeader, nodesByPk);

// deposit info aggregates
const depByProduct = {}; const depByVault = {}; const uniqueUsers = new Set();
for (const d of deposits) {
  uniqueUsers.add(d.userKey);
  const k = d.product; depByProduct[k] = depByProduct[k] || { count: 0, total: 0 }; depByProduct[k].count++; depByProduct[k].total += d.usdcDeposit;
  const kv = d.vault; depByVault[kv] = depByVault[kv] || { count: 0, total: 0 }; if (kv !== '11111111111111111111111111111111') { depByVault[kv].count++; depByVault[kv].total += d.usdcDeposit; }
}

const out = {
  generatedAt: new Date().toISOString(),
  program: '3HUeooitcfKX1TSCx2xEpg2W31n6Qfmizu7nnbaEWYzs',
  counts: { state: state.length, products: products.length, vaults: vaults.length, structuredProductInfo: spis.length, optionBarrier: barriers.length, queueHeaders: qheaders.length, queueNodes: qnodes.length, depositInfo: deposits.length },
  state: st,
  products, vaults, spis, barriers, qheaders, qnodes: qnodes.length <= 100 ? qnodes : qnodes.slice(0, 100),
  deposits,
  aggregates: {
    productsByCounter: products.map(p => ({ name: p.productName, counter: p.productCounter, underlyingAmount: p.underlyingAmount, isActive: p.isActive, vaults: vaults.filter(v => v.productName === p.productName).length })).sort((a,b)=>a.counter-b.counter),
    depositQueuesTotal: Object.values(depositQueues).reduce((s,q)=>s+q.total,0),
    withdrawQueuesTotal: Object.values(withdrawQueues).reduce((s,q)=>s+q.total,0),
    depositInfoTotal: deposits.reduce((s,d)=>s+d.usdcDeposit,0),
    depositInfoUniqueUsers: uniqueUsers.size,
    depByProduct, depByVault
  },
  depositQueues, withdrawQueues
};
fs.writeFileSync(path.join(D, 'decoded_state.json'), JSON.stringify(out, null, 1));

// print compact summary
console.log('STATE:', JSON.stringify(st));
console.log('\nPRODUCT TABLE:');
console.log(['name','pda','active','underlyingMint','amountRaw','amountUsdc','tokenAcct','depQueue','maxDepositLimit'].join('\t'));
for (const p of products.sort((a,b)=>a.productCounter-b.productCounter)) {
  console.log([p.productName, p.pubkey, p.isActive?1:0, p.underlyingMint, p.underlyingAmount, (p.underlyingAmount/1e6).toFixed(6), p.productUnderlyingTokenAccount, p.depositQueueHeader, p.maxDepositLimit].join('\t'));
}
console.log('\nVAULT STATUS COUNTS:', JSON.stringify(vaults.reduce((m,v)=>{m[v.status]=(m[v.status]||0)+1;return m;},{})));
console.log('VAULT UNDERLYING SUM:', (vaults.reduce((s,v)=>s+v.underlyingAmount,0)/1e6).toFixed(6));
console.log('DEPOSITINFO TOTAL:', (out.aggregates.depositInfoTotal/1e6).toFixed(6), 'unique users:', uniqueUsers.size);
console.log('DEPOSIT QUEUES TOTAL:', (out.aggregates.depositQueuesTotal/1e6).toFixed(6));
console.log('WITHDRAW QUEUES TOTAL:', (out.aggregates.withdrawQueuesTotal/1e6).toFixed(6));
console.log('QUEUE NODES:', qnodes.length, JSON.stringify(depositQueues[products[0].pubkey]?.nodes?.slice(0,12)));
