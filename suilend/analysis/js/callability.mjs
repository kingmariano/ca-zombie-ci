// Callability map: devInspect create_obligation for every Suilend package version v1..v25 (READ-ONLY).
import { SuiClient } from '@mysten/sui/client';
import { Transaction } from '@mysten/sui/transactions';
import { readFileSync } from 'fs';

const MAIN_POOL = '0xf95b06141ed4a174f239417323bde3f209b972f5930d8521ea38a52aff3a6ddf::suilend::MAIN_POOL';
const MARKET = '0x84030d26d85eaa7035084a057f2f11f701b7e2e4eda87551becbc7c97505ece1';
const VERSIONS = JSON.parse(readFileSync(new URL('./versions_full.json', import.meta.url)));

async function makeClient() {
  for (const url of ['https://sui.publicnode.com', 'https://mainnet.sui.rpcpool.com']) {
    try { const c = new SuiClient({ url }); await c.getLatestSuiSystemState(); return c; } catch {}
  }
  throw new Error('no endpoint');
}

const sender = '0x7da6872f15af113ffacbe83a8c2cfb03cc0f9fb1283f9434b053e9639668155b';
const client = await makeClient();
const out = {};
for (const [v, pkg] of Object.entries(VERSIONS)) {
  const tx = new Transaction();
  tx.setSender(sender);
  tx.moveCall({
    target: `${pkg}::lending_market::create_obligation`,
    typeArguments: [MAIN_POOL],
    arguments: [tx.object(MARKET)],
  });
  try {
    const res = await client.devInspectTransactionBlock({ sender, transactionBlock: tx });
    const st = res?.effects?.status?.status;
    const m = /(\d+)\) in command/.exec(JSON.stringify(res?.effects?.status?.error || ''));
    out[v] = st === 'success' ? 'SUCCESS' : `ABORT(code=${m ? m[1] : '?'})`;
  } catch (e) {
    out[v] = `RPC_ERR: ${String(e).slice(0, 120)}`;
  }
  console.log(v, out[v]);
}
