'use strict';
// Decode recent Cega V1 Solana transactions: instruction names via Anchor discriminators.
const fs = require('fs');
const path = require('path');
const { b58encode, b58decode, anchorDisc } = require('./solana_helpers.js');
const D = __dirname;
const RPC = 'https://api.mainnet-beta.solana.com';
const PROG = '3HUeooitcfKX1TSCx2xEpg2W31n6Qfmizu7nnbaEWYzs';

const idl = JSON.parse(fs.readFileSync(path.join(D, 'cega_vault_idl.json'), 'utf8'));
const disc2name = {};
for (const ix of idl.instructions) disc2name[anchorDisc(ix.name).toString('hex')] = ix.name;

const rpc = async (method, params) => {
  const res = await fetch(RPC, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ jsonrpc: '2.0', id: 1, method, params }) });
  return await res.json();
};
const sleep = (ms) => new Promise(r => setTimeout(r, ms));

(async () => {
  const sigFile = process.argv[2] || 'sigs_program.json';
  const outFile = process.argv[3] || 'tx_decoded.json';
  const limit = Number(process.argv[4] || 40);
  const sigs = JSON.parse(fs.readFileSync(path.join(D, sigFile), 'utf8')).result.slice(0, limit);
  const txs = [];
  for (const s of sigs) {
    let r = await rpc('getTransaction', [s.signature, { encoding: 'jsonParsed', maxSupportedTransactionVersion: 0, commitment: 'confirmed' }]);
    if (r.error) { await sleep(1500); r = await rpc('getTransaction', [s.signature, { encoding: 'jsonParsed', maxSupportedTransactionVersion: 0, commitment: 'confirmed' }]); }
    if (!r.result) { txs.push({ signature: s.signature, slot: s.slot, error: JSON.stringify(r.error || r).slice(0, 200) }); await sleep(400); continue; }
    const tx = r.result;
    const keys = tx.transaction.message.accountKeys;
    const signers = keys.filter(k => k.signer).map(k => k.pubkey);
    const ixs = [];
    const allIx = [
      ...(tx.transaction.message.instructions || []).map(i => ({ ...i, top: true })),
      ...((tx.meta && tx.meta.innerInstructions) || []).flatMap(ii => ii.instructions.map(i => ({ ...i, top: false })))
    ];
    for (const ix of allIx) {
      const pid = ix.programId || (ix.programIdIndex !== undefined ? keys[ix.programIdIndex]?.pubkey : null);
      if (pid !== PROG) continue;
      let data;
      try { data = ix.data ? (typeof ix.data === 'string' ? Buffer.from(b58decode(ix.data)).subarray(0, 8).toString('hex') : Buffer.from(ix.data).subarray(0, 8).toString('hex')) : null; } catch (e) { data = 'decode-err'; }
      const name = data ? disc2name[data] : null;
      const accounts = ix.accounts ? ix.accounts.map(a => typeof a === 'string' ? a : (keys[a]?.pubkey || String(a))) : [];
      ixs.push({ top: ix.top, name: name || ('UNKNOWN_' + data), accounts });
    }
    txs.push({
      signature: s.signature, slot: s.slot, blockTime: s.blockTime, success: !(tx.meta && tx.meta.err),
      fee: tx.meta ? tx.meta.fee : null, signers, cegaIx: ixs,
      numInstructions: (tx.transaction.message.instructions || []).length,
      logCount: tx.meta && tx.meta.logMessages ? tx.meta.logMessages.length : 0
    });
    await sleep(400);
  }
  fs.writeFileSync(path.join(D, outFile), JSON.stringify(txs, null, 1));
  // summary
  const byName = {};
  for (const t of txs) for (const ix of (t.cegaIx || [])) byName[ix.name] = (byName[ix.name] || 0) + 1;
  console.log('txs:', txs.length, 'with cega ix:', txs.filter(t => t.cegaIx && t.cegaIx.length).length);
  console.log('instruction frequency:', JSON.stringify(byName, null, 1));
  const signerCount = {};
  for (const t of txs) for (const s of (t.signers || [])) signerCount[s] = (signerCount[s] || 0) + 1;
  console.log('top signers:', JSON.stringify(Object.entries(signerCount).sort((a, b) => b[1] - a[1]).slice(0, 12), null, 1));
  console.log('recent examples:', JSON.stringify(txs.slice(0, 3).map(t => ({ slot: t.slot, sig: t.signature, success: t.success, ixs: t.cegaIx })), null, 1).slice(0, 2500));
})();
