// Taiga Acala L2-Phase2 - read-only state fetch via @polkadot/api (public RPC)
// Usage: node fetch_state.js  (run from /tmp/opencode/taiga-node with this file copied there or NODE_PATH set)
const { ApiPromise, WsProvider } = require('@polkadot/api');

async function main() {
  const provider = new WsProvider('wss://acala-rpc-0.aca-api.network');
  const api = await ApiPromise.create({ provider, noInitWarn: true });
  await api.isReady;
  const out = { fetched_at_utc: new Date().toISOString() };
  const hash = await api.rpc.chain.getBlockHash();
  const hdr = await api.rpc.chain.getHeader(hash);
  out.block = hdr.number.toNumber();
  out.block_hash = hash.toHex();
  out.runtime = (await api.rpc.state.getRuntimeVersion()).toHuman();
  out.chain = (await api.rpc.system.chain()).toHuman();

  const acct = '23M5ttkp2zdM8qa6LFak4BySWZDsAVByjepAfr7kt929S1U9';
  out.systemAccount = (await api.query.system.account(acct)).toHuman();

  const entries = await api.query.tokens.accounts.entries(acct);
  out.tokenAccounts = {};
  for (const [k, v] of entries) {
    out.tokenAccounts[JSON.stringify(k.args[1].toHuman())] = v.toHuman();
  }

  const cids = {
    DOT: { token: 'DOT' }, LDOT: { token: 'LDOT' }, TAP: { token: 'TAP' },
    ACA: { token: 'ACA' }, AUSD: { token: 'AUSD' },
    FA13: { foreignAsset: 13 }, PoolToken0: { stableAssetPoolToken: 0 },
  };
  out.totalIssuance = {};
  for (const [n, cid] of Object.entries(cids)) {
    try { out.totalIssuance[n] = (await api.query.tokens.totalIssuance(cid)).toHuman(); }
    catch (e) { out.totalIssuance[n] = 'ERR:' + e.message; }
  }

  try { out.poolCount = (await api.query.stableAsset.poolCount()).toHuman(); }
  catch (e) { out.poolCount = 'ERR:' + e.message; }
  const pools = await api.query.stableAsset.pools.entries();
  out.pools = pools.map(([k, v]) => ({ id: k.args[0].toHuman(), info: v.toHuman() }));

  out.homa = {};
  for (const s of ['totalStakingBonded', 'totalVoidLiquid', 'toBondPool', 'unclaimedRedemption', 'estimatedRewardRatePerEra', 'commissionRate']) {
    try { out.homa[s] = (await api.query.homa[s]()).toHuman(); } catch (e) { out.homa[s] = 'ERR:' + e.message; }
  }

  out.assetMeta = {};
  for (const [n, cid] of Object.entries(cids)) {
    try { out.assetMeta[n] = (await api.query.assetRegistry.assetMetadatas(cid)).toHuman(); } catch (e) { out.assetMeta[n] = 'ERR:' + e.message; }
  }

  try { out.sudoKey = (await api.query.sudo.key()).toHuman(); } catch (e) { out.sudoKey = 'ERR:' + e.message; }
  try { out.generalCouncilMembers = (await api.query.generalCouncil.members()).toHuman(); } catch (e) { out.generalCouncilMembers = 'ERR:' + e.message; }

  console.log(JSON.stringify(out, null, 1));
  await api.disconnect();
}
main().catch(e => { console.error('FATAL', e); process.exit(1); });
