/* eslint-disable node/no-missing-import */
import { ethers, run } from "hardhat";

function delay(ms: number) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function main() {
  const USDC_ADDRESS = "{{USDC_ADDRESS}}";
  const OwnershipAddress = "{{OwnershipAddress}}";
  const VaultAddress = "{{VaultAddress}}";
  const defaultMaxRebateRate = "{{defaultMaxRebateRate}}";

  // define
  const Referral = await ethers.getContractFactory("Referral");
  const referral = await Referral.deploy(USDC_ADDRESS, OwnershipAddress, VaultAddress, defaultMaxRebateRate);
  await referral.deployed();

  console.log("Referral deployed to:", referral.address);

  await delay(30000); // wait for etherscan to register the bytecode

  try {
    await run("verify:verify", {
      address: referral.address,
      constructorArguments: [USDC_ADDRESS, OwnershipAddress, VaultAddress, defaultMaxRebateRate],
    });
  } catch (e) {
    console.log("Verify for referral is skipped reason for: ", e);
  }
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
