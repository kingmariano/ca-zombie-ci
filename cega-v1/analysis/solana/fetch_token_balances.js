'use strict';
// Fetch real SPL balances for every token account referenced by decoded Cega state. READ-ONLY.
const fs = require('fs');
const path = require('path');
const D = __dirname;
const dec = JSON.parse(fs.readFileSync(path.join(D, 'decoded_state.json'), 'utf8'));
const SYS = '11111111111111111111111111111111';

const refs = new Map(); // pubkey -> {role, product?, vault?}
const add = (pk, meta) => { if (!pk || pk === SYS) return; refs.set(pk, Object.assign(refs.get(pk) || {}, meta)); };
add(dec.state && dec.state.programUsdcTokenAccount, { role: 'programUsdcTokenAccount' });
for (const p of dec.products) add(p.productUnderlyingTokenAccount, { role: 'productUnderlyingTokenAccount', product: p.productName, productPda: p.pubkey });
for (const v of dec.vaults) {
  add(v.vaultUnderlyingTokenAccount, { role: 'vaultUnderlyingTokenAccount', vault: v.pubkey, product: v.productName, vaultNumber: v.vaultNumber, status: v.status });
  add(v.vaultWithdrawQueueRedeemableTokenAccount, { role: 'vaultWithdrawQueueRedeemableTokenAccount', vault: v.pubkey, product: v.productName, vaultNumber: v.vaultNumber, status: v.status });
  add(v.vaultOptionTokenAccount, { role: 'vaultOptionTokenAccount', vault: v.pubkey, product: v.productName, vaultNumber: v.vaultNumber, status: v.status });
}

const keys = [...refs.keys()];
const rpc = async (method, params) => {
  const res = await fetch('https://api.mainnet-beta.solana.com', {
    method: 'POST', headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ jsonrpc: '2.0', id: 1, method, params })
  });
  return await res.json();
};
const sleep = (ms) => new Promise(r => setTimeout(r, ms));

(async () => {
  const results = {};
  for (let i = 0; i < keys.length; i += 100) {
    const batch = keys.slice(i, i + 100);
    let r = await rpc('getMultipleAccounts', [batch, { encoding: 'jsonParsed' }]);
    if (r.error) { await sleep(2000); r = await rpc('getMultipleAccounts', [batch, { encoding: 'jsonParsed' }]); }
    if (!r.result) { console.log('ERR batch', i, JSON.stringify(r).slice(0, 200)); continue; }
    r.result.value.forEach((acc, j) => { results[batch[j]] = acc; });
    await sleep(700);
    console.log('fetched', Math.min(i + 100, keys.length), '/', keys.length);
  }
  const out = {};
  for (const [pk, meta] of refs) {
    const acc = results[pk];
    if (!acc) { out[pk] = Object.assign({}, meta, { exists: false }); continue; }
    const info = acc.data && acc.data.parsed && acc.data.parsed.info;
    out[pk] = Object.assign({}, meta, {
      exists: true, owner: acc.owner,
      mint: info ? info.mint : null, tokenOwner: info ? info.owner : null,
      amount: info ? info.tokenAmount.uiAmountString : null, decimals: info ? info.tokenAmount.decimals : null,
      rawAmount: info ? info.tokenAmount.amount : null,
      state: info ? info.state : null
    });
  }
  fs.writeFileSync(path.join(D, 'token_balances.json'), JSON.stringify(out, null, 1));
  // summary
  const usdcMint = 'EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v';
  let totalUsdc = 0; const byProduct = {}; const byRole = {};
  for (const v of Object.values(out)) {
    if (!v.exists || v.mint !== usdcMint || !v.amount) continue;
    const a = Number(v.amount); totalUsdc += a;
    byProduct[v.product || '?'] = (byProduct[v.product || '?'] || 0) + a;
    byRole[v.role] = (byRole[v.role] || 0) + a;
  }
  console.log('TOTAL USDC in referenced accounts:', totalUsdc.toFixed(6));
  console.log('by role:', JSON.stringify(byRole, null, 1));
  console.log('by product:', JSON.stringify(byProduct, null, 1));
  const nonUsdc = Object.values(out).filter(v => v.exists && v.mint && v.mint !== usdcMint);
  const mints = {}; for (const v of nonUsdc) mints[v.mint] = (mints[v.mint] || 0) + 1;
  console.log('non-USDC mints (count of accounts):', JSON.stringify(mints));
})();
