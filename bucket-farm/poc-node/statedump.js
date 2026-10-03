/* Bucket Farm (Sui) — live state dump (read-only JSON-RPC). Writes JSON to stdout. */
const { SuiClient } = require('@mysten/sui/client');
const ENDPOINTS = [process.env.SUI_RPC, 'https://sui.blockpi.network/v1/rpc/public', 'https://sui-rpc.publicnode.com', 'https://sui-mainnet.nodeinfra.com'].filter(Boolean);

const FARM_V1 = '0x0db143afbc91b84a37c4bad1b9da19ca7a7b4afd0c594d618e1cb9b4bcf49a23';
const FARM_V7 = '0xf62488082fb7ad62c92d66c26b587728e987f160413b6b8aafe169d0c423098c';
const POINT_CENTER = '0xc60fb4131a47aa52ac27fe5b6f9613ffe27832c5f52d27755511039d53908217';
const ADMINCAP = '0x8b9a436268e71d35b7613c9eba09ab4776bb065134eae8cea0451af526bc340f';
const CONVERTOR = '0xa9a29be9bd67c96dabd8c8086e3e33d98fd30e91fb7f6f58dc990ae3936612b8';
const PONDS = {
  NAVI_POND: '0xad4f4f73dc19dd2e28f380f287201a549215407db46acd7543e89443954d5eba',
  NAVI_UNI_POND: '0xb6a8a27235af6004712e1b40fefcf919bf87ed2c7e5dd060f40bcfae44f13e58',
  SCALLOP_POND: '0x7b2720e50e5fa5f2ceb95c82b20495b4eaf0c18f3adfdd7de125f6fc65230dbf',
};
const POOLS = [
  ['AF_LP', '0x27551889fb011f613614e6e82f02cb4aa8c0563df0f66adb1112983eb6bbf07c'],
  ['SUI', '0xab90d38384dfaf833c57ce7802d2f87efd286ffa8dddf5474323dc2f2e20f052'],
  ['AFSUI', '0xcec648deeb201a2e9a9943805ae6b6b719ba9ebfd744b2f9c424a7f2fa3780d7'],
  ['HASUI', '0xdd23fe747d2177e82d1489d05066b8a120d5a421712a0c1198eb5555450826d1'],
  ['CERT', '0x3e7f71a129256659d6c18d77d6e5f0dcd7e624e993c97994b4a32e39c1453fdb'],
  ['KSUI', '0x532bf24a80898a3fac521c41d216d56ee068d81939d205cabb4ddfd977dd3489'],
  ['SPRING_SUI', '0x25a4b8edb9709d30f3c0078b6e4359fa3f12c766361db8ede6670736611a9ca7'],
  ['MSUI', '0x28f9d5271674dd24e9128a5c678c648f0dc58a0218cd4cbe3a68380c0c71350b'],
  ['COIN1', '0x5658fe1d89cb026e6f0cba279a34189547be588c560736b8e9501b5df0ba20f3'],
  ['COIN2', '0x5baa72165855665ee2931c5ff8715c9a942c869547f53d85cacb591491938220'],
  ['USDC', '0xf2221e1cae8a7493cafd72a834152a72ee6a90c9eedbd666ee97ab43738be3b7'],
  ['AUSD', '0x6cab0d3cc431a20d429274a21182544199db6df21593bcf6286b4fda16f4b880'],
  ['FDUSD', '0x167824936eb94620eb44e0d63c244a4fc17f334bef8dbc73d8a8fafb150ad41f'],
  ['CETUS', '0xfbb32d268ba51d3afd8c9fcaffc48b0e7c5bec3194da0642c09c4c16e7aaac3f'],
  ['NAVX', '0x1d07b16d18cc75dcb7fbc15e39a0262bcbbd1e06aa1c8cb62dfe5d8f3c664b60'],
  ['ALPHA', '0xdfffbeda682d4d9db915538d4a8580f4c30e9d7eb569403af4331e2819f6d377'],
  ['SEND', '0xeb20a9e131dff3948556232e49d0080f74dd71990e9cc405659c47ae3d26ba9a'],
  ['BLUE', '0xe2cd0560105ff1e23ed3808d483e63bb842ce0d4d517036693b835c12fa06e51'],
  ['SCA', '0xcd9d4d72995d125ce842d2a4a9c1552e39a6ae23cf4f4c4042f68ca9428eb98a'],
  ['TYPUS', '0xa8997c5fca8cfea92990979650e8c16074baa25db33161fe1828c1f4f0c00882'],
  ['DEEP', '0xe07e240fae827025882887218e8690b2850ac59e3773bce334780d3e17de9b38'],
  ['NS', '0x6781c47e118bf07b30d7cb2c9825b99c1335cae72f30e1804f8c42001b81a4a9'],
  ['BLUB', '0xe9f02d4b83e78dff3e47cfc095fca1b18788779d5a96c77e76816ca0eb49390a'],
  ['LOFI', '0x02a94dfbf720bcef33b680b65803cd5eabddf40b088eb565e3d81c58061eca40'],
  ['ETH', '0x4e791ee7a25bc8621bbb044b6bd681d309b4eb10a80971dc2ad837dfadbda2ac'],
  ['AF_LP2', '0xdb18d714705b887bc422f036171e5079efae80a329c7531bbb83d3ebbef974af'],
  ['STSUI', '0xd3ff43a8bbb0e5c820d2698198f9c54ba5c42acd538d155fc278b261fb6b04e2'],
  ['KOTO', '0x0a0300beccbcc50ce5a86d370866b4abd5eb4e9cfa43347b911c496ae86795df'],
  ['BUCK', '0xc293e829e1ab6588657c7d39b60f26a5824d9125ebc2e2e45a8011be652eb86f'],
  ['LP_TOKEN', '0x230414d0db61f59a2d769ae30d382f232c917c3bf801e1bf8b1c42298b8a5cfc'],
  ['SUI2', '0xcf18d9b855736317c7198fdec34306ab881c16b33c41fe4cb2c58bdf42132920'],
  ['ALPHAFI_LP', '0x1f9558b3aa78da8f43d944cc22f701814477f6e96b8e26a1f0fd3c38639be30b'],
  ['BTC', '0x9b9bb648245358a0af429d2d9d9a22eb4816e7f533844f67add123930ae2b3a2'],
];

let client = null;
let RPC_URL = null;
async function connect() {
  for (const url of ENDPOINTS) {
    try {
      const c = new SuiClient({ url });
      await c.getLatestCheckpointSequenceNumber();
      RPC_URL = url;
      return c;
    } catch (e) { /* next */ }
  }
  throw new Error('no working Sui RPC endpoint');
}
const rpcCall = async (method, params) => {
  const res = await fetch(RPC_URL, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ jsonrpc: '2.0', id: 1, method, params }) });
  const j = await res.json();
  if (j.error) throw new Error(method + ': ' + JSON.stringify(j.error));
  return j.result;
};
function sheetSummary(sheet) {
  const cred = {};
  for (const e of (sheet?.credits?.fields?.contents || [])) {
    const k = e.fields.key.fields.pos0.fields.name;
    cred[k] = (cred[k] || 0) + Number(e.fields.value.fields.pos0);
  }
  const debt = {};
  for (const e of (sheet?.debts?.fields?.contents || [])) {
    const k = e.fields.key.fields.pos0.fields.name;
    debt[k] = (debt[k] || 0) + Number(e.fields.value.fields.pos0);
  }
  return { credits: cred, debts: debt };
}
(async () => {
  client = await connect();
  const out = { generatedAt: new Date().toISOString(), rpc: RPC_URL };
  out.checkpoint = await rpcCall('sui_getLatestCheckpointSequenceNumber', []);
  const pc = await client.getObject({ id: POINT_CENTER, options: { showType: true, showContent: true, showOwner: true } });
  out.pointCenter = { version: pc.data.version, type: pc.data.type, owner: pc.data.owner, fields: { claimable: pc.data.content.fields.claimable, buffer: pc.data.content.fields.buffer, stake_policy: JSON.stringify(pc.data.content.fields.stake_policy), unstake_policy: JSON.stringify(pc.data.content.fields.unstake_policy), profiles: pc.data.content.fields.user_profiles.fields.size } };
  const admin = await client.getObject({ id: ADMINCAP, options: { showOwner: true, showType: true } });
  out.farmAdminCap = { owner: admin.data.owner, type: admin.data.type };
  const conv = await client.getObject({ id: CONVERTOR, options: { showContent: true, showType: true } });
  out.butConvertor = { type: conv.data.type, is_public: conv.data.content.fields.is_public, reserve_BUT_raw: conv.data.content.fields.reserve, conversion_rate: conv.data.content.fields.conversion_rate.fields.value, versions: conv.data.content.fields.versions.fields.contents };
  out.ponds = PONDS;
  out.pools = [];
  for (const [name, id] of POOLS) {
    try {
      const o = await client.getObject({ id, options: { showType: true, showContent: true, showOwner: true } });
      const f = o.data.content.fields;
      out.pools.push({ name, id, type: o.data.type, version: o.data.version, total_stake: f.total_stake ?? null, balance: f.balance, sheet: sheetSummary(f.sheet?.fields) });
    } catch (e) {
      out.pools.push({ name, id, error: String(e.message).slice(0, 120) });
    }
  }
  // DROP total supply via TreasuryCap inside PointCenter
  out.dropTotalSupply = pc.data.content.fields.cap.fields.total_supply.fields.value;
  console.log(JSON.stringify(out, null, 1));
})().catch((e) => { console.error('FATAL', e.message); process.exit(1); });
