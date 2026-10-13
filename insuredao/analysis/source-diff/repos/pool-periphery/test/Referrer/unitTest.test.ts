import { expect } from "chai";
import { ethers, network } from "hardhat";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { Contract, ContractFactory, constants, BigNumber, Bytes } from "ethers";
import { keccak256 } from "ethers/lib/utils";

import {
  OwnershipArtifact,
  USDCArtifact,
  PoolTemplateArtifact,
  FactoryArtifact,
  VaultArtifact,
  RegistryArtifact,
  PremiumArtifact,
  ParametersArtifact,
} from "../Utils/artifacts";

import {
  YEAR,
  WEEK,
  DAY,
  SmartContractHackingCover,
  defaultMaxRebateRate,
  initialMint,
  depositAmount,
  insureAmount,
  governanceFeeRate,
} from "../Utils/constants";
import { Address } from "cluster";

const { getSigners } = ethers;
const { AddressZero, Zero, MaxUint256 } = constants;

async function snapshot() {
  return network.provider.send("evm_snapshot", []);
}

async function restore(snapshotId: any) {
  return network.provider.send("evm_revert", [snapshotId]);
}

describe("Referral", function () {
  let gov: SignerWithAddress;
  let alice: SignerWithAddress;
  let bob: SignerWithAddress;

  let ownership: Contract;
  let usdc: Contract;
  let registry: Contract;
  let factory: Contract;
  let premium: Contract;
  let vault: Contract;
  let poolTemplate: Contract;
  let parameters: Contract;
  let referral: Contract;
  let market: Contract;

  let Ownership: ContractFactory;
  let USDC: ContractFactory;
  let PoolTemplate: ContractFactory;
  let Factory: ContractFactory;
  let Vault: ContractFactory;
  let Registry: ContractFactory;
  let PremiumModel: ContractFactory;
  let Parameters: ContractFactory;
  let Referral: ContractFactory;

  let snapshotId: BigNumber;

  before(async () => {
    [gov, alice, bob] = await getSigners();

    Ownership = await ethers.getContractFactoryFromArtifact(OwnershipArtifact);
    USDC = await ethers.getContractFactoryFromArtifact(USDCArtifact);
    PoolTemplate = await ethers.getContractFactoryFromArtifact(PoolTemplateArtifact);
    Factory = await ethers.getContractFactoryFromArtifact(FactoryArtifact);
    Vault = await ethers.getContractFactoryFromArtifact(VaultArtifact);
    Registry = await ethers.getContractFactoryFromArtifact(RegistryArtifact);
    PremiumModel = await ethers.getContractFactoryFromArtifact(PremiumArtifact);
    Parameters = await ethers.getContractFactoryFromArtifact(ParametersArtifact);
    Referral = await ethers.getContractFactory("Referral");

    ownership = await Ownership.deploy();
    usdc = await USDC.deploy();
    registry = await Registry.deploy(ownership.address);
    factory = await Factory.deploy(registry.address, ownership.address);
    premium = await PremiumModel.deploy();
    vault = await Vault.deploy(usdc.address, registry.address, AddressZero, ownership.address);
    poolTemplate = await PoolTemplate.deploy();
    parameters = await Parameters.deploy(ownership.address);
    referral = await Referral.deploy(usdc.address, ownership.address, vault.address, defaultMaxRebateRate);

    //setup
    await usdc.mint(gov.address, initialMint);
    await usdc.mint(alice.address, initialMint);

    await registry.setFactory(factory.address);
    await factory.approveTemplate(poolTemplate.address, true, false, true);
    await factory.approveReference(poolTemplate.address, 0, usdc.address, true);
    await factory.approveReference(poolTemplate.address, 1, usdc.address, true);
    await factory.approveReference(poolTemplate.address, 2, registry.address, true);
    await factory.approveReference(poolTemplate.address, 3, parameters.address, true);

    await factory.approveReference(poolTemplate.address, 4, AddressZero, true); //everyone can be initialDepositor

    //set default parameters
    await parameters.setFeeRate(AddressZero, governanceFeeRate);
    await parameters.setGrace(AddressZero, "259200");
    await parameters.setLockup(AddressZero, "604800");
    await parameters.setMinDate(AddressZero, "604800");
    await parameters.setPremiumModel(AddressZero, premium.address);
    await parameters.setWithdrawable(AddressZero, "2592000");
    await parameters.setVault(usdc.address, vault.address);

    let tx = await factory.createMarket(
      poolTemplate.address,
      "Here is metadata.",
      [0, 0], //deposit 0 USDC
      [usdc.address, usdc.address, registry.address, parameters.address]
    );
    let receipt = await tx.wait();
    const marketAddress = receipt.events[2].args[0];
    market = await PoolTemplate.attach(marketAddress);
  });

  beforeEach(async () => {
    snapshotId = await snapshot();
  });

  afterEach(async () => {
    await restore(snapshotId);
  });

  describe("constructor", () => {
    it("should set correctly", async () => {
      expect(await referral.usdc()).to.equal(usdc.address);
      expect(await referral.ownership()).to.equal(ownership.address);

      expect(await usdc.allowance(referral.address, vault.address)).to.equal(MaxUint256);
      expect(await referral.maxRebateRates(AddressZero)).to.equal(defaultMaxRebateRate);
    });

    it("should revert when zero address passed", async () => {
      await expect(
        Referral.deploy(AddressZero, ownership.address, vault.address, defaultMaxRebateRate)
      ).to.revertedWith("zero address");

      await expect(Referral.deploy(usdc.address, AddressZero, vault.address, defaultMaxRebateRate)).to.revertedWith(
        "zero address"
      );

      await expect(Referral.deploy(usdc.address, ownership.address, AddressZero, defaultMaxRebateRate)).to.revertedWith(
        "zero address"
      );

      await expect(Referral.deploy(usdc.address, ownership.address, vault.address, Zero)).to.revertedWith("zero");
    });
  });

  describe("insure", () => {
    beforeEach(async () => {
      await usdc.approve(vault.address, depositAmount);
      await market.deposit(depositAmount);

      await usdc.connect(alice).approve(referral.address, insureAmount);
    });

    it("should buy insurance with referral", async () => {
      expect(await market.balanceOf(bob.address)).to.equal(Zero);

      await referral
        .connect(alice)
        .insure(
          market.address,
          bob.address,
          defaultMaxRebateRate,
          insureAmount,
          insureAmount,
          YEAR,
          SmartContractHackingCover,
          alice.address,
          alice.address
        );

      //USDC:LP rate change due to the premium income
      expect(await market.balanceOf(bob.address)).to.not.equal(Zero);
    });

    it("should emit event", async () => {
      await expect(
        referral
          .connect(alice)
          .insure(
            market.address,
            bob.address,
            defaultMaxRebateRate,
            insureAmount,
            insureAmount,
            YEAR,
            SmartContractHackingCover,
            alice.address,
            alice.address
          )
      )
        .to.emit(referral, "Rebate")
        .withArgs(bob.address, market.address, insureAmount.div("100"));
    });

    it("revert when rebateRate is higher than maxRebateRate", async () => {
      await expect(
        referral
          .connect(alice)
          .insure(
            market.address,
            bob.address,
            defaultMaxRebateRate.add("1"),
            insureAmount,
            insureAmount,
            YEAR,
            SmartContractHackingCover,
            alice.address,
            alice.address
          )
      ).to.revertedWith("exceed max rabate rate");
    });
  });

  describe("maxRebateRate", () => {
    it("should return default maxRebaterate", async () => {
      expect(await referral.getMaxRebateRate(AddressZero)).to.equal(defaultMaxRebateRate);

      expect(await referral.getMaxRebateRate(market.address)).to.equal(defaultMaxRebateRate);
    });

    it("should set default maxRebaterate", async () => {
      const newMaxRebateRate = defaultMaxRebateRate.add("1");

      await referral.setMaxRebateRate(AddressZero, newMaxRebateRate);

      expect(await referral.getMaxRebateRate(AddressZero)).to.equal(newMaxRebateRate);
      expect(await referral.getMaxRebateRate(market.address)).to.equal(newMaxRebateRate);
    });

    it("should set maxRebaterate", async () => {
      const newMaxRebateRate = defaultMaxRebateRate.add("1");

      await referral.setMaxRebateRate(market.address, newMaxRebateRate);

      expect(await referral.getMaxRebateRate(AddressZero)).to.equal(defaultMaxRebateRate);
      expect(await referral.getMaxRebateRate(market.address)).to.equal(newMaxRebateRate);
    });

    it("should emit event", async () => {
      const newMaxRebateRate = defaultMaxRebateRate.add("1");

      await expect(referral.setMaxRebateRate(market.address, newMaxRebateRate))
        .to.emit(referral, "SetMaxRebateRate")
        .withArgs(market.address, newMaxRebateRate);
    });

    it("revert when not owner", async () => {
      const newMaxRebateRate = defaultMaxRebateRate.add("1");

      await expect(referral.connect(alice).setMaxRebateRate(market.address, newMaxRebateRate)).to.revertedWith(
        "Caller is not allowed to operate"
      );
    });
  });
});
