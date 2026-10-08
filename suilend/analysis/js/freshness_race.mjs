// Poll the market's SUI reserve price timestamp; when it is refreshed in the current second,
// fire a v18 liquidate devInspect to see whether the old code executes (expected: not-liquidatable abort).
import { SuiClient } from '@mysten/sui/client';
import { Transaction } from '@mysten/sui/transactions';

const c = new SuiClient({ url: 'https://sui.publicnode.com' });
const S = '0x7da6872f15af113ffacbe83a8c2cfb03cc0f9fb1283f9434b053e9639668155b';
const MAIN = '0xf95b06141ed4a174f239417323bde3f209b972f5930d8521ea38a52aff3a6ddf::suilend::MAIN_POOL';
const MARKET = '0x84030d26d85eaa7035084a057f2f11f701b7e2e4eda87551becbc7c97505ece1';
const V18 = '0xdf48a8edf980a895be1719a74801308ebf634fb4d759017f7650d96196bd14e8';
const OBL = '0x5660f9a5feaa7d9e71790e269f86163af7db6abe3f45336a9a51c619a986dd00'; // USDT debt, SUI collateral
const USDT_COIN = '0xa3c4962ef1ccfc6605e8c66073e3037c13a2d344811af8f5c80513399f60823c';

async function reserveTs() {
  const o = await c.getObject({ id: MARKET, options: { showContent: true } });
  const f = o.data.content.fields;
  const r0 = f.reserves.find((r) => r.fields.array_index === '0').fields; // SUI
  const r19 = f.reserves.find((r) => r.fields.array_index === '19').fields; // USDT
  return { sui: Number(r0.price_last_update_timestamp_s), usdt: Number(r19.price_last_update_timestamp_s) };
}

const start = Date.now();
let attempts = 0, freshHits = 0;
while (Date.now() - start < 240000) {
  const ts = await reserveTs();
  const now = Math.floor(Date.now() / 1000);
  const suiAge = now - ts.sui, usdtAge = now - ts.usdt;
  if (suiAge <= 1 && usdtAge <= 1) {
    freshHits++;
    const tx = new Transaction();
    tx.setSender(S);
    tx.moveCall({ target: `${V18}::lending_market::liquidate`, typeArguments: [MAIN,
        '0x375f70cf2ae4c00bf37117d0c85a2c71545e6ee05c4a5c7d282cd66a4504b068::usdt::USDT', '0x2::sui::SUI'],
      arguments: [tx.object(MARKET), tx.pure.id(OBL), tx.pure.u64(19), tx.pure.u64(0), tx.object('0x6'), tx.object(USDT_COIN)] });
    const r = await c.devInspectTransactionBlock({ sender: S, transactionBlock: tx });
    const err = JSON.stringify(r.effects.status.error || '');
    console.log(new Date().toISOString(), 'FRESH suiAge=' + suiAge + ' usdtAge=' + usdtAge, r.effects.status.status, err.slice(0, 220));
    attempts++;
    if (attempts >= 3) break;
  }
  await new Promise((res) => setTimeout(res, 700));
}
console.log('done. freshHits=' + freshHits + ' attempts=' + attempts);
