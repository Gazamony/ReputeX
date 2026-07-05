import { ethers } from "hardhat";
import * as fs from "fs";
import * as path from "path";

async function main() {
  console.log("\n=== ReputeX Token Launchpad Deployment ===\n");

  const [deployer] = await ethers.getSigners();
  console.log(`Deploying contracts with account: ${deployer.address}\n`);

  console.log("Deploying LaunchpadToken implementation...");
  const LaunchpadToken = await ethers.getContractFactory("LaunchpadToken");
  const tokenImpl = await LaunchpadToken.deploy(
    "LaunchpadToken",
    "LAUNCH",
    ethers.parseEther("200000000"),
    ethers.parseEther("200000000"),
    deployer.address
  );
  await tokenImpl.waitForDeployment();
  const tokenImplAddress = await tokenImpl.getAddress();
  console.log(`LaunchpadToken implementation deployed: ${tokenImplAddress}\n`);

  console.log("Deploying BondingCurveAMM implementation...");
  const BondingCurveAMM = await ethers.getContractFactory("BondingCurveAMM");
  const bondingCurveImpl = await BondingCurveAMM.deploy();
  await bondingCurveImpl.waitForDeployment();
  const bondingCurveImplAddress = await bondingCurveImpl.getAddress();
  console.log(`BondingCurveAMM implementation deployed: ${bondingCurveImplAddress}\n`);

  console.log("Deploying LaunchpadFactory...");
  const DEX_ROUTER = process.env.DEX_ROUTER_ADDRESS || ethers.ZeroAddress;
  const TREASURY = deployer.address;
  
  const LaunchpadFactory = await ethers.getContractFactory("LaunchpadFactory");
  const factory = await LaunchpadFactory.deploy(
    tokenImplAddress,
    bondingCurveImplAddress,
    DEX_ROUTER,
    TREASURY
  );
  await factory.waitForDeployment();
  const factoryAddress = await factory.getAddress();
  console.log(`LaunchpadFactory deployed: ${factoryAddress}\n`);

  const deploymentAddresses = {
    network: (await ethers.provider.getNetwork()).name,
    chainId: (await ethers.provider.getNetwork()).chainId,
    deployer: deployer.address,
    timestamp: new Date().toISOString(),
    contracts: {
      launchpadTokenImplementation: tokenImplAddress,
      bondingCurveAMMImplementation: bondingCurveImplAddress,
      launchpadFactory: factoryAddress,
    },
  };

  const deploymentPath = path.join(__dirname, "../deployments");
  if (!fs.existsSync(deploymentPath)) {
    fs.mkdirSync(deploymentPath, { recursive: true });
  }

  const networkName = (await ethers.provider.getNetwork()).name;
  const deploymentFile = path.join(deploymentPath, `${networkName}.json`);
  fs.writeFileSync(deploymentFile, JSON.stringify(deploymentAddresses, null, 2));

  console.log("=== Deployment Summary ===");
  console.log(JSON.stringify(deploymentAddresses, null, 2));
  console.log(`\nDeployment addresses saved to: ${deploymentFile}`);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
