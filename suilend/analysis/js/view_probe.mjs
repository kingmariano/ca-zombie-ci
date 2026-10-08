// Cross-version view divergence probe for Suilend obligations (READ-ONLY devInspect).
import { SuiClient } from '@mysten/sui/client';
import { Transaction } from '@mysten/sui/transactions';
import { readFileSync } from 'fs';

const ENDPOINTS = ['https://sui.publicnode.com', 'https://mainnet.sui.rpcpool.com'];
const MAIN_POOL = '0xf95b06141ed4a174f239417323bde3f209b972f5930d8521ea38a52aff3a6ddf::suilend::MAIN_POOL';
const VERSIONS = JSON.parse(readFileSync(new URL('./versions.json', import.meta.url)));

async function makeClient() {
  let last;
  for (const url of ENDPOINTS) {
    try { const c = new SuiClient({ url }); await c.getLatestSuiSystemState(); return c; } catch (e) { last = e; }
  }
  throw last;
}

async function callView(client, sender, pkg, fn, obId, extraArgs = []) {
  const tx = new Transaction();
  tx.setSender(sender);
  tx.moveCall({
    target: `${pkg}::obligation::${fn}`,
    typeArguments: [MAIN_POOL],
    arguments: [tx.object(obId), ...extraArgs],
  });
  const res = await client.devInspectTransactionBlock({ sender, transactionBlock: tx });
  const st = res?.effects?.status?.status;
  let rv = null;
  if (res?.results?.[0]?.returnValues?.[0]) {
    const [b64, type] = res.results[0].returnValues[0];
    const buf = Buffer.from(b64, 'base64');
    if (type === 'bool') rv = buf[0] === 1;
    else if (type.includes('u64')) rv = Number(Buffer.from(buf).readBigUInt64LE(0));
    else rv = b64 + ':' + type;
  }
  return { status: st, error: res?.effects?.status?.error?.slice?.(0, 120) || res?.effects?.status?.error, rv };
}

const sender = process.argv[2] || '0xac3f4a4b7b3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f';
const obIds = JSON.parse(process.argv[3] || '[]');
const fns = (process.argv[4] || 'is_liquidatable,is_healthy').split(',');
const vers = (process.argv[5] || '10,18,20,24,25').split(',').map(Number);

const client = await makeClient();
const out = [];
for (const ob of obIds) {
  const row = { obligation: ob, results: {} };
  for (const fn of fns) {
    row.results[fn] = {};
    for (const v of vers) {
      const r = await callView(client, sender, VERSIONS[v], fn, ob);
      row.results[fn][`v${v}`] = r.error ? `ERR:${String(r.error).slice(0,90)}` : r.rv;
    }
  }
  out.push(row);
  console.log(JSON.stringify(row));
}
