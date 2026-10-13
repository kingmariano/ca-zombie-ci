/* eslint-disable node/no-missing-import */
import { ethers, run } from "hardhat";

function delay(ms: number) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function main() {
  const USDC_ADDRESS = "0x7F5c764cBc14f9669B88837ca1490cCa17c31607";
  const OwnershipAddress = "0x7dF2501C62b56f8dd5F1644bfC4300A517CE22BC";
  const VaultAddress = "0x54F23d2fdC1E17D349B1Eb14d869fa4deD6A6D2b";
  const defaultMaxRebateRate = "100000";

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
