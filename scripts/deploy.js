const { ethers } = require("hardhat");

async function main() {
  console.log("Deploying Token-Based Voting System...");

  // Deploy the token with voting capabilities
  const Project = await ethers.getContractFactory("Project");
  
  // Initial supply of 1 million tokens (with 18 decimals)
  const initialSupply = ethers.parseEther("1000000");
  
  const votingSystem = await Project.deploy(
    "Governance Token", // Token Name
    "GOV",              // Token Symbol
    initialSupply       // Initial supply
  );

  await votingSystem.waitForDeployment();
  
  const address = await votingSystem.getAddress();
  console.log(`Project contract deployed to: ${address}`);
  
  console.log("Deployment completed successfully!");
  
  console.log("Waiting for block confirmations...");
  await votingSystem.deploymentTransaction().wait(5);
  
  console.log("You can now verify the contract on Etherscan with:");
  console.log(`npx hardhat verify --network coreTestnet2 ${address} "Governance Token" "GOV" ${initialSupply}`);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
