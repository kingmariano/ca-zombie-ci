#!/usr/bin/env bash
# H-34 Oku Trade — custom CI job.
# Verifies that the deployed OkuRouter bytecode is exactly the repo-HEAD compilation
# (Hardhat: solc 0.8.27, viaIR, optimizer 1000, hardhat-deploy literal content metadata),
# and captures live-state evidence. Never fails the workflow (best effort).
set -uo pipefail

FOLDER="$(cd "$(dirname "$0")/.." && pwd)"
cd "$FOLDER"
mkdir -p ci-out
OUT="$FOLDER/ci-out/bytecode-verification.txt"

echo "=== H-34 Oku Trade CI custom job — $(date -u +%FT%TZ) ===" | tee "$OUT"
echo "folder: $FOLDER" | tee -a "$OUT"

# ---------------------------------------------------------------- #
# 1) Compile the audited OkuRouter repo at HEAD                    #
# ---------------------------------------------------------------- #
cd "$FOLDER/analysis/oku-router"
echo "[1] npm ci ..." | tee -a "$OUT"
npm ci --no-audit --no-fund > /tmp/npm-ci.log 2>&1
NPM_RC=$?
if [ $NPM_RC -ne 0 ]; then
  echo "npm ci FAILED rc=$NPM_RC (tail):" | tee -a "$OUT"
  tail -20 /tmp/npm-ci.log | tee -a "$OUT"
else
  echo "npm ci OK" | tee -a "$OUT"
fi

echo "[2] npx hardhat compile ..." | tee -a "$OUT"
npx hardhat compile > /tmp/hh-compile.log 2>&1
HH_RC=$?
if [ $HH_RC -ne 0 ]; then
  echo "hardhat compile FAILED rc=$HH_RC (tail):" | tee -a "$OUT"
  tail -30 /tmp/hh-compile.log | tee -a "$OUT"
else
  echo "hardhat compile OK" | tee -a "$OUT"
fi

# ---------------------------------------------------------------- #
# 2) Byte-compare compiled init code vs the Scroll deployment tx   #
# ---------------------------------------------------------------- #
if [ -f artifacts/contracts/OkuRouter.sol/OkuRouter.json ] && [ -f "$FOLDER/analysis/scroll_router_creation_input.hex" ]; then
  echo "[3] comparing compiled initcode vs on-chain creation input ..." | tee -a "$OUT"
  node - <<'EOF' | tee -a "$OUT"
const fs = require("fs");
const { ethers } = require("ethers");

const artifact = JSON.parse(fs.readFileSync("artifacts/contracts/OkuRouter.sol/OkuRouter.json", "utf8"));
const creation = artifact.bytecode; // 0x + creation code
const chainInput = fs.readFileSync("../scroll_router_creation_input.hex", "utf8").trim().replace(/\s+/g, "");

// Safe Singleton Factory input = salt(32 bytes) ++ initcode
const salt = "0x" + chainInput.slice(2, 66);
const chainInit = "0x" + chainInput.slice(66);

// Constructor args used at deploy time (name, version, owner EOA, canonical Permit2)
const args = ethers.AbiCoder.defaultAbiCoder().encode(
  ["string", "string", "address", "address"],
  ["Oku Router", "2.0", "0x3CB68a6762041aA05E762814A8791CA9d98E79A0", "0x000000000022D473030F116dDEE9F6B43aC78BA3"]
);
const expectedInit = (creation + args.slice(2)).toLowerCase();

console.log("artifact creation code bytes:", (creation.length - 2) / 2);
console.log("on-chain initcode bytes    :", (chainInit.length - 2) / 2);
console.log("salt                       :", salt);
console.log("keccak256(initcode)        :", ethers.keccak256(chainInit));
const match = expectedInit === chainInit.toLowerCase();
console.log("REPO-HEAD BYTECODE MATCHES ON-CHAIN INITCODE:", match ? "PASS" : "FAIL");
if (!match) {
  // find first difference
  const a = expectedInit, b = chainInit.toLowerCase();
  let i = 0;
  while (i < Math.min(a.length, b.length) && a[i] === b[i]) i++;
  console.log("first diff at byte offset:", Math.floor(i / 2), "expected:", a.slice(i, i + 40), "chain:", b.slice(i, i + 40));
}
const factory = "0x914d7Fec6aaC8cd542e72Bca78B30650d45643d7";
const predicted = ethers.getCreate2Address(factory, salt, ethers.keccak256(chainInit));
console.log("predicted CREATE2 address  :", predicted);
console.log("deployed Scroll router     : 0xb1f3a7B816B0681188F54dFa400991B93ADf00ed");
console.log("CREATE2 ADDRESS MATCH      :", predicted.toLowerCase() === "0xb1f3a7b816b0681188f54dfa400991b93adf00ed" ? "PASS" : "FAIL");
EOF
else
  echo "[3] SKIPPED: artifact or creation input missing" | tee -a "$OUT"
fi

# ---------------------------------------------------------------- #
# 3) Live-state evidence at pinned blocks (best effort)            #
# ---------------------------------------------------------------- #
cd "$FOLDER"
{
  echo "[4] live-state evidence (read-only, pinned blocks)"
  echo "-- Sonic LOR batchCount / positions / native"
  cast call --rpc-url "${SONIC_RPC_URL:-https://sonic-rpc.publicnode.com}" \
    0x1b35fbA9357fD9bda7ed0429C8BbAbe1e8CC88fc "batchCount()(uint128)" || true
  cast call --rpc-url "${SONIC_RPC_URL:-https://sonic-rpc.publicnode.com}" \
    0x743E03cceB4af2efA3CC76838f6E8B50B63F184c "balanceOf(address)(uint256)" \
    0x1b35fbA9357fD9bda7ed0429C8BbAbe1e8CC88fc || true
  echo "-- Linea OkuRouter validSigners(address(0)) / paused / version"
  cast call --rpc-url "${LINEA_RPC_URL:-https://rpc.linea.build}" \
    0xb1f3a7B816B0681188F54dFa400991B93ADf00ed "validSigners(address)(bool)" \
    0x0000000000000000000000000000000000000000 || true
  cast call --rpc-url "${LINEA_RPC_URL:-https://rpc.linea.build}" \
    0xb1f3a7B816B0681188F54dFa400991B93ADf00ed "version()(string)" || true
  echo "-- Scroll OkuRouter swapTargets(openocean) / LOR batchCount"
  cast call --rpc-url "${SCROLL_RPC_URL:-https://rpc.scroll.io}" \
    0xb1f3a7B816B0681188F54dFa400991B93ADf00ed "swapTargets(address)(bool)" \
    0x6352a56caadC4F1E25CD6c75970Fa768A3304e64 || true
  cast call --rpc-url "${SCROLL_RPC_URL:-https://rpc.scroll.io}" \
    0xeC3E5eeC51D8C3D4f03DABB84B4Db313a739f377 "batchCount()(uint128)" || true
} | tee -a "$OUT"

echo "=== done ===" | tee -a "$OUT"
exit 0
