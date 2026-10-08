// CI live probes for C2-11 (READ-ONLY devInspect). Results -> ci-out/probe_results.json
//  1) callability map v1..v25 (create_obligation)
//  2) decisive-path tests: stale-oracle gate, v25 refresh, version mixing (InvalidLinkage),
//     legacy Pyth refresh with legacy object, Pro-VAA replay to legacy Wormhole
//  3) freshness cadence observation on SUI/USDC reserves
import { SuiClient } from '@mysten/sui/client';
import { Transaction } from '@mysten/sui/transactions';
import { readFileSync, writeFileSync, mkdirSync } from 'fs';
import { dirname } from 'path';
import { fileURLToPath } from 'url';

const __dir = dirname(fileURLToPath(import.meta.url));
const OUT = `${__dir}/../../ci-out`;
mkdirSync(OUT, { recursive: true });

const ORIG = '0xf95b06141ed4a174f239417323bde3f209b972f5930d8521ea38a52aff3a6ddf';
const MAIN_POOL = `${ORIG}::suilend::MAIN_POOL`;
const MARKET = '0x84030d26d85eaa7035084a057f2f11f701b7e2e4eda87551becbc7c97505ece1';
const V18 = '0xdf48a8edf980a895be1719a74801308ebf634fb4d759017f7650d96196bd14e8';
const V22 = '0x7c82c37d363c691254e6cd05cade2c58a02284165c9eb6dd699e4b6799108d60';
const V25 = '0x59672975e15c58ffc9450f5236b6aa9fa2407d94b8081e634778aa01957d8c6f';
const P_SUI = '0x89b2add829cb6fcd017153fff428bc9faec4d06d643ecfc435af5b55a9e987f0';
const LEG_SUI = '0x801dbc2f0053d34734814b2d6df491ce7807a725fe9a01ad74a07e9c51396c37';
const USDT = '0x375f70cf2ae4c00bf37117d0c85a2c71545e6ee05c4a5c7d282cd66a4504b068::usdt::USDT';
const USDC = '0xdba34672e30cb065b1f93e3ab55318768fd6fef66c15942c9f7cb846e2f900e7::usdc::USDC';
const OBL_USDT = '0x5660f9a5feaa7d9e71790e269f86163af7db6abe3f45336a9a51c619a986dd00';
const OBL_USDC = '0xa349b17f543cceb6e197e5a0cef35adffa50ee45e1528cabbecb491e617d124c';
const SENDER = '0x7da6872f15af113ffacbe83a8c2cfb03cc0f9fb1283f9434b053e9639668155b';
const USDT_COIN = '0xa3c4962ef1ccfc6605e8c66073e3037c13a2d344811af8f5c80513399f60823c';
const USDC_COIN = '0xb2d8ce19e755ea5a7c7f3be31dff6c19fdaa782d624950ad4ddea51d84d09e2d';
const WORMHOLE_LEGACY = '0x5306f64e312b581766351c07af79c72fcb1cd25147157fdc2f8ad76de9a3fb6a';
const WORMHOLE_LEGACY_STATE = '0xaeab97f96cf9877fee2883315d459552b2b921edc16d7ceac6eab944dd88919c';

const versions = JSON.parse(readFileSync(`${OUT}/version_chain.json`, 'utf8'));
const results = { callability: {}, tests: {}, freshness: [] };

async function makeClient() {
  for (const url of ['https://sui.publicnode.com', 'https://mainnet.sui.rpcpool.com']) {
    try { const c = new SuiClient({ url }); await c.getLatestSuiSystemState(); return c; } catch {}
  }
  throw new Error('no endpoint');
}
const client = await makeClient();

function errInfo(res) {
  const e = JSON.stringify(res?.effects?.status?.error || '');
  const m = /(\d+)\) in command/.exec(e);
  const f = /function_name: Some\("(\w+)"\)/.exec(e);
  return { status: res?.effects?.status?.status, code: m ? Number(m[1]) : undefined, fn: f ? f[1] : undefined, raw: e.slice(0, 200) };
}

// ---------- 1. callability ----------
console.log('callability map...');
for (const [v, pkg] of Object.entries(versions)) {
  const tx = new Transaction(); tx.setSender(SENDER);
  tx.moveCall({ target: `${pkg}::lending_market::create_obligation`, typeArguments: [MAIN_POOL], arguments: [tx.object(MARKET)] });
  try {
    const res = await client.devInspectTransactionBlock({ sender: SENDER, transactionBlock: tx });
    results.callability[v] = res?.effects?.status?.status === 'success' ? 'SUCCESS' : `ABORT(code=${errInfo(res).code ?? '?'})`;
  } catch { results.callability[v] = 'RPC_ERR'; }
}
console.log('  v10:', results.callability['10'], 'v25:', results.callability['25']);

// ---------- 2. decisive-path tests ----------
async function runTest(name, build) {
  const tx = new Transaction(); tx.setSender(SENDER);
  try {
    build(tx);
    const res = await client.devInspectTransactionBlock({ sender: SENDER, transactionBlock: tx });
    results.tests[name] = errInfo(res);
  } catch (e) { results.tests[name] = { status: 'RPC_ERR', raw: String(e).slice(0, 200) }; }
  console.log(' test', name, '=>', JSON.stringify(results.tests[name]).slice(0, 150));
}

// A: v18 liquidate alone -> expect stale-oracle abort (code 9)
await runTest('v18_liquidate_alone_stale', (tx) => tx.moveCall({
  target: `${V18}::lending_market::liquidate`, typeArguments: [MAIN_POOL, USDT, '0x2::sui::SUI'],
  arguments: [tx.object(MARKET), tx.pure.id(OBL_USDT), tx.pure.u64(19), tx.pure.u64(0), tx.object('0x6'), tx.object(USDT_COIN)] }));

// B: v25 refresh + v25 liquidate -> executes to health gate
await runTest('v25_refresh_plus_v25_liquidate', (tx) => {
  tx.moveCall({ target: `${V25}::lending_market::refresh_reserve_price_pro_compatible`, typeArguments: [MAIN_POOL], arguments: [tx.object(MARKET), tx.pure.u64(0), tx.object('0x6'), tx.object(P_SUI)] });
  tx.moveCall({ target: `${V25}::lending_market::liquidate`, typeArguments: [MAIN_POOL, USDT, '0x2::sui::SUI'],
    arguments: [tx.object(MARKET), tx.pure.id(OBL_USDT), tx.pure.u64(19), tx.pure.u64(0), tx.object('0x6'), tx.object(USDT_COIN)] });
});

// C: v25 refresh + v18 liquidate -> expect InvalidLinkage (version mixing prohibited)
await runTest('v25_refresh_plus_v18_liquidate_mix', (tx) => {
  tx.moveCall({ target: `${V25}::lending_market::refresh_reserve_price_pro_compatible`, typeArguments: [MAIN_POOL], arguments: [tx.object(MARKET), tx.pure.u64(0), tx.object('0x6'), tx.object(P_SUI)] });
  tx.moveCall({ target: `${V18}::lending_market::liquidate`, typeArguments: [MAIN_POOL, USDT, '0x2::sui::SUI'],
    arguments: [tx.object(MARKET), tx.pure.id(OBL_USDT), tx.pure.u64(19), tx.pure.u64(0), tx.object('0x6'), tx.object(USDT_COIN)] });
});

// D: v18 refresh with legacy object -> legacy feed frozen (stale)
await runTest('v18_refresh_legacy_object', (tx) => tx.moveCall({
  target: `${V18}::lending_market::refresh_reserve_price`, typeArguments: [MAIN_POOL],
  arguments: [tx.object(MARKET), tx.pure.u64(0), tx.object('0x6'), tx.object(LEG_SUI)] }));

// E: v22 refresh with Pro object -> works (control)
await runTest('v22_refresh_pro_object', (tx) => tx.moveCall({
  target: `${V22}::lending_market::refresh_reserve_price_pro_compatible`, typeArguments: [MAIN_POOL],
  arguments: [tx.object(MARKET), tx.pure.u64(0), tx.object('0x6'), tx.object(P_SUI)] }));

// F: Pro-VAA replay to legacy Wormhole (payload from pro_update_payload.json if present)
try {
  const payload = JSON.parse(readFileSync(`${__dir}/pro_update_payload.json`, 'utf8'));
  const vaa = Uint8Array.from(Buffer.from(payload.vaa, 'hex'));
  await runTest('pro_vaa_replay_to_legacy_wormhole', (tx) => tx.moveCall({
    target: `${WORMHOLE_LEGACY}::vaa::parse_and_verify`,
    arguments: [tx.object(WORMHOLE_LEGACY_STATE), tx.pure.vector('u8', vaa), tx.object('0x6')] }));
} catch { results.tests['pro_vaa_replay_to_legacy_wormhole'] = { status: 'SKIP', raw: 'no payload' }; }

// ---------- 3. freshness cadence ----------
console.log('freshness cadence observation (60s)...');
try {
  let last = {};
  const t0 = Date.now();
  while (Date.now() - t0 < 60000) {
    const o = await client.getObject({ id: MARKET, options: { showContent: true } });
    const f = o.data.content.fields;
    for (const idx of ['0', '7']) {
      const r = f.reserves.find((x) => x.fields.array_index === idx).fields;
      const ts = Number(r.price_last_update_timestamp_s);
      if (last[idx] !== undefined && ts !== last[idx]) results.freshness.push({ idx, at: new Date().toISOString(), ts });
      last[idx] = ts;
    }
    await new Promise((r) => setTimeout(r, 1500));
  }
} catch (e) { results.freshness.push({ err: String(e).slice(0, 120) }); }
console.log(' freshness events:', results.freshness.length);

writeFileSync(`${OUT}/probe_results.json`, JSON.stringify(results, null, 1));
console.log('wrote ci-out/probe_results.json');
