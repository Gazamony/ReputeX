import { expect } from "chai";
import { ethers } from "hardhat";
import { LaunchpadToken } from "../typechain-types";

describe("LaunchpadToken", function () {
  let token: LaunchpadToken;
  let owner: any;
  let addr1: any;
  let addr2: any;

  beforeEach(async function () {
    [owner, addr1, addr2] = await ethers.getSigners();

    const LaunchpadToken = await ethers.getContractFactory("LaunchpadToken");
    token = await LaunchpadToken.deploy(
      "LaunchpadToken",
      "LAUNCH",
      ethers.parseEther("200000000"),
      ethers.parseEther("200000000"),
      owner.address
    );
    await token.waitForDeployment();
  });

  describe("Deployment", function () {
    it("Should set the right owner", async function () {
      expect(await token.owner()).to.equal(owner.address);
    });

    it("Should assign the total supply of tokens to the owner", async function () {
      const ownerBalance = await token.balanceOf(owner.address);
      expect(await token.totalSupply()).to.equal(ownerBalance);
    });

    it("Should have correct name and symbol", async function () {
      expect(await token.name()).to.equal("LaunchpadToken");
      expect(await token.symbol()).to.equal("LAUNCH");
    });
  });

  describe("Transfers", function () {
    it("Should transfer tokens between accounts", async function () {
      const amount = ethers.parseEther("50");
      await token.transfer(addr1.address, amount);
      expect(await token.balanceOf(addr1.address)).to.equal(amount);
    });

    it("Should fail if sender doesn't have enough tokens", async function () {
      const amount = ethers.parseEther("1000000000");
      await expect(
        token.connect(addr1).transfer(owner.address, amount)
      ).to.be.revertedWithCustomError(token, "ERC20InsufficientBalance");
    });
  });

  describe("Minting", function () {
    it("Should allow owner to mint tokens", async function () {
      const amount = ethers.parseEther("1000");
      await token.mint(addr1.address, amount);
      expect(await token.balanceOf(addr1.address)).to.equal(amount);
    });

    it("Should not allow non-owner to mint tokens", async function () {
      const amount = ethers.parseEther("1000");
      await expect(
        token.connect(addr1).mint(addr2.address, amount)
      ).to.be.revertedWithCustomError(token, "OwnableUnauthorizedAccount");
    });
  });
});
