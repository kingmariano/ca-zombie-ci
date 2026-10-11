// Taiga Acala L2-Phase2 - probes #2: prices, DEX, homa ledgers, pool token holders (partial)
const { ApiPromise, WsProvider } = require('@polkadot/api');

async function main() {
  const provider = new WsProvider('wss://acala-rpc-0.aca-api.network');
  const api = await ApiPromise.create({ provider, noInitWarn: true });
  await api.isReady;
  const out = { fetched_at_utc: new Date().toISOString() };
  const hdr = await api.rpc.chain.getHeader();
  out.block = hdr.number.toNumber();

  const acct = '23M5ttkp2zdM8qa6LFak4BySWZDsAVByjepAfr7kt929S1U9';
  const feeRec = '23AdbsfTWCWtRFweQF4f3iZLcLBPwSHci9CXuMhqFirZmUZj';

  // ---- oracle prices (Acala + Aggregated) for DOT, LDOT ----
  out.oracle = {};
  for (const [prov, pid] of [['Acala', 'Acala'], ['Aggregated', 'Aggregated']]) {
    for (const cur of [{ token: 'DOT' }, { token: 'LDOT' }, { token: 'ACA' }]) {
      try {
        const v = await api.call.oracleApi.getValue(pid, cur);
        out.oracle[`${prov}:${JSON.stringify(cur)}`] = v.toHuman();
      } catch (e) { out.oracle[`${prov}:${JSON.stringify(cur)}`] = 'ERR:' + e.message; }
    }
  }

  // ---- DEX pools involving LDOT ----
  out.dexPools = {};
  const pairDefs = [
    ['DOT', 'LDOT'],
    ['LDOT', 'AUSD'],
    ['LDOT', 'ACA'],
  ];
  for (const [a, b] of pairDefs) {
    try {
      const key = { dexShare: [{ token: a }, { token: b }] };
      const v = await api.query.dex.liquidityPool(key);
      out.dexPools[`${a}/${b}`] = v.toHuman();
    } catch (e) { out.dexPools[`${a}/${b}`] = 'ERR:' + e.message; }
  }
  // DEX trading pair status
  out.dexPairStatus = {};
  for (const [a, b] of pairDefs) {
    try {
      const key = { dexShare: [{ token: a }, { token: b }] };
      const v = await api.query.dex.tradingPairStatuses(key);
      out.dexPairStatus[`${a}/${b}`] = v.toHuman();
    } catch (e) { out.dexPairStatus[`${a}/${b}`] = 'ERR:' + e.message; }
  }

  // ---- homa ledgers sum ----
  try {
    const entries = await api.query.homa.stakingLedgers.entries();
    let sumBonded = 0n, sumUnlocking = 0n, count = 0;
    out.homaLedgerSample = null;
    for (const [k, v] of entries) {
      const h = v.toHuman();
      if (!out.homaLedgerSample) out.homaLedgerSample = h;
      count++;
      try {
        const j = JSON.parse(JSON.stringify(v.toJSON()));
        const total = j.bonded !== undefined ? j.bonded : (j.total || 0);
        sumBonded += BigInt(total);
        const u = j.unlocking || [];
        for (const e of u) { sumUnlocking += BigInt(e.value !== undefined ? e.value : (e[1] || 0)); }
      } catch (e) { /* ignore */ }
    }
    out.homaLedgers = { count, sumBonded: sumBonded.toString(), sumUnlocking: sumUnlocking.toString() };
  } catch (e) { out.homaLedgers = 'ERR:' + e.message; }

  // ---- pool token balances of candidates ----
  const poolTok = { stableAssetPoolToken: 0 };
  out.poolTokenBalances = {};
  for (const [name, who] of [['palletAccount', acct], ['feeRecipient', feeRec]]) {
    try { out.poolTokenBalances[name] = (await api.query.tokens.accounts(who, poolTok)).toHuman(); }
    catch (e) { out.poolTokenBalances[name] = 'ERR:' + e.message; }
  }
  // LDOT/DOT balances of fee recipient
  out.feeRecipientTokens = {};
  for (const cid of [{ token: 'DOT' }, { token: 'LDOT' }, { token: 'TAP' }]) {
    try { out.feeRecipientTokens[JSON.stringify(cid)] = (await api.query.tokens.accounts(feeRec, cid)).toHuman(); }
    catch (e) { out.feeRecipientTokens[JSON.stringify(cid)] = 'ERR:' + e.message; }
  }

  // ---- stableAsset pool 0 raw again + pool token metadata (asset registry via AssetIds) ----
  try { out.pool0 = (await api.query.stableAsset.pools(0)).toHuman(); } catch (e) { out.pool0 = 'ERR:' + e.message; }

  // asset registry metadata for AssetIds enum (erc20, stableassetid, foreignassetid, nativeassetid)
  out.assetMeta2 = {};
  for (const [n, aid] of Object.entries({
    DOT: { nativeAssetId: { token: 'DOT' } },
    LDOT: { nativeAssetId: { token: 'LDOT' } },
    TAP: { nativeAssetId: { token: 'TAP' } },
    FA13: { foreignAssetId: 13 },
    PoolToken0: { stableAssetId: 0 },
  })) {
    try { out.assetMeta2[n] = (await api.query.assetRegistry.assetMetadatas(aid)).toHuman(); }
    catch (e) { out.assetMeta2[n] = 'ERR:' + e.message; }
  }

  // ---- Homa pallet account DOT balance ----
  // homa pallet id: grep source? try known account derivations later. Read Homa treasury account if stored.
  try { out.homaTreasuryAccount = (await api.query.homa.treasuryAccount ? 'n/a' : 'n/a'); } catch (e) {}

  // ---- Tokens.Accounts key prefix count estimate (paged, just first pages count) ----
  console.log(JSON.stringify(out, null, 1));
  await api.disconnect();
}
main().catch(e => { console.error('FATAL', e); process.exit(1); });
