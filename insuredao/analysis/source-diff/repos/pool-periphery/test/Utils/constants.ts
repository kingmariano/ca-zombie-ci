import { ethers, network } from "hardhat";
import { BigNumber } from "ethers";

const YEAR = BigNumber.from("86400").mul(365);
const WEEK = BigNumber.from("86400").mul(7);
const DAY = BigNumber.from("86400");

const SmartContractHackingCover = "0x0000000000000000000000000000000000000000000000000000000000000001";

const defaultMaxRebateRate = BigNumber.from("100000"); //10%
const governanceFeeRate = BigNumber.from("100000"); //10% of the Premium
const initialMint = BigNumber.from("100000");
const depositAmount = BigNumber.from("10000");
const insureAmount = BigNumber.from("10000");

export {
  YEAR,
  WEEK,
  DAY,
  SmartContractHackingCover,
  defaultMaxRebateRate,
  initialMint,
  depositAmount,
  insureAmount,
  governanceFeeRate,
};
