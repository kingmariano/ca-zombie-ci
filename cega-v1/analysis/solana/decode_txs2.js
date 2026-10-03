'use strict';
// Decode recent Cega txs using program logs for instruction names & errors.
const fs = require('fs');
const path = require('path');
const D = __dirname;
const RPC = 'https://api.mainnet-beta.solana.com';
const PROG = '3HUeooitcfKX1TSCx2xEpg2W31n6Qfmizu7nnbaEWYzs';
const rpc = async (method, params) => {
  const res = await fetch(RPC, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ jsonrpc: '2.0', id: 1, method, params }) });
  return await res.json();
};
const sleep = (ms) => new Promise(r => setTimeout(r, ms));
(async () => {
  const sigFile = process.argv[2], outFile = process.argv[3], limit = Number(process.argv[4] || 100);
  const sigs = JSON.parse(fs.readFileSync(path.join(D, sigFile), 'utf8')).result.slice(0, limit);
  const txs = [];
  for (const s of sigs) {
    let r = await rpc('getTransaction', [s.signature, { encoding: 'jsonParsed', maxSupportedTransactionVersion: 0, commitment: 'confirmed' }]);
    if (r.error || !r.result) { await sleep(1200); r = await rpc('getTransaction', [s.signature, { encoding: 'jsonParsed', maxSupportedTransactionVersion: 0, commitment: 'confirmed' }]); }
    if (!r.result) { txs.push({ signature: s.signature, slot: s.slot, error: 'fetch-failed' }); await sleep(300); continue; }
    const tx = r.result;
    const keys = tx.transaction.message.accountKeys;
    const signers = keys.filter(k => k.signer).map(k => k.pubkey);
    const logs = (tx.meta && tx.meta.logMessages) || [];
    const ixNames = logs.map(l => (l.match(/Instruction: (\w+)/) || [])[1]).filter(Boolean);
    const errLines = logs.filter(l => /AnchorError|Error Code|Error Message|custom program error|failed:/.test(l)).slice(-6);
    // top-level instructions to the Cega program
    const topIx = (tx.transaction.message.instructions || []).map(ix => {
      const pid = ix.programId || (ix.programIdIndex !== undefined ? keys[ix.programIdIndex]?.pubkey : null);
      return { pid, nAccounts: ix.accounts ? ix.accounts.length : 0, firstAccounts: (ix.accounts || []).slice(0, 3).map(a => typeof a === 'string' ? a : (keys[a]?.pubkey || String(a))), dataLen: ix.data ? String(ix.data).length : 0 };
    }).filter(i => i.pid === PROG);
    txs.push({
      signature: s.signature, slot: s.slot, blockTime: s.blockTime, success: !(tx.meta && tx.meta.err),
      signers, ixNames, errLines, topIx,
      numTopIx: (tx.transaction.message.instructions || []).length
    });
    await sleep(300);
  }
  fs.writeFileSync(path.join(D, outFile), JSON.stringify(txs, null, 1));
  const byName = {}; const bySigner = {}; const fails = {};
  for (const t of txs) {
    for (const n of t.ixNames || []) { byName[n] = byName[n] || { count: 0, fail: 0, signers: {} }; byName[n].count++; if (!t.success) byName[n].fail++; for (const s of t.signers) byName[n].signers[s] = (byName[n].signers[s] || 0) + 1; }
    for (const s of t.signers || []) bySigner[s] = (bySigner[s] || 0) + 1;
    if (!t.success) { const k = (t.errLines || []).slice(-1)[0] || 'unknown'; fails[k] = (fails[k] || 0) + 1; }
  }
  console.log('txs:', txs.length, 'success:', txs.filter(t => t.success).length);
  console.log('BY INSTRUCTION:', JSON.stringify(byName, null, 1).slice(0, 4000));
  console.log('TOP SIGNERS:', JSON.stringify(Object.entries(bySigner).sort((a, b) => b[1] - a[1]).slice(0, 15)));
  console.log('FAILURE REASONS:', JSON.stringify(fails, null, 1).slice(0, 2500));
})();
