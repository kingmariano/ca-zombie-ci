const { Connection, PublicKey, Transaction, TransactionInstruction, Keypair, ComputeBudgetProgram } = require("@solana/web3.js");
const fs = require("fs");
const crypto = require("crypto");
const RPC = process.env.SOL_RPC || "https://api.mainnet-beta.solana.com";
const conn = new Connection(RPC, "confirmed");

function disc(name) { return crypto.createHash("sha256").update("global:" + name).digest().slice(0, 8); }

async function simulate(ixs, watch = [], label = "") {
  const payer = { publicKey: new PublicKey(process.env.SIM_FEEPAYER || "6M1rN486dffB6d7q35qdxHLuWUFF9QtbTjLnPtEyRyJd") };
  const tx = new Transaction();
  tx.add(ComputeBudgetProgram.setComputeUnitLimit({ units: 1400000 }));
  for (const ix of ixs) tx.add(ix);
  tx.feePayer = payer.publicKey;
  tx.recentBlockhash = (await conn.getLatestBlockhash()).blockhash;
  const encoded = tx.serialize({ requireAllSignatures: false, verifySignatures: false }).toString("base64");
  const config = { encoding: "base64", sigVerify: false, replaceRecentBlockhash: true, commitment: "confirmed" };
  if (watch.length) config.accounts = { encoding: "base64", addresses: watch };
  const raw = await conn._rpcRequest("simulateTransaction", [encoded, config]);
  const res = raw.result;
  console.log("=".repeat(90));
  console.log("SIM", label, "err=", JSON.stringify(res.value.err));
  console.log("unitsConsumed=", res.value.unitsConsumed);
  for (const l of (res.value.logs || []).slice(0, 40)) console.log("   log:", l);
  if (res.value.accounts) {
    res.value.accounts.forEach((a, i) => {
      if (!a) { console.log("   post", watch[i], "MISSING"); return; }
      const raw = Buffer.from(a.data[0], "base64");
      console.log("   post", watch[i], "lamports", a.lamports, "owner", a.owner, "len", raw.length, "data", raw.toString("hex").slice(0, 80));
    });
  }
  return res;
}

function ix(programId, data, keys) {
  return new TransactionInstruction({ programId: new PublicKey(programId), data, keys: keys.map(k => ({ pubkey: new PublicKey(k.pubkey), isSigner: !!k.signer, isWritable: !!k.writable })) });
}

module.exports = { conn, disc, simulate, ix, PublicKey, Keypair, Transaction, TransactionInstruction, ComputeBudgetProgram };
