import { ethers } from "hardhat";

async function main() {
  const OAO_PROXY_BASE = "0x742291E3009710702f3C1748911C0E9d9ca1eb61a"; 

  console.log("Deploying SwarmTruth to Base...");
  const SwarmTruth = await ethers.getContractFactory("SwarmTruth");
  const contract = await SwarmTruth.deploy(OAO_PROXY_BASE);

  await contract.waitForDeployment();
  console.log("SwarmTruth deployed to:", await contract.getAddress());
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
