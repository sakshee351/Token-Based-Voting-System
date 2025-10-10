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
  
  const address = awaiconst { ethers } = require("hardhat");

async function main() {
  console.log("🚀 Deploying Token-Based Voting System...");

  // Compile & get contract factory
  const Project = await ethers.getContractFactory("Project");

  // Initial supply of 1 million tokens (18 decimals)
  const initialSupply = ethers.parseEther("1000000");

  // Deploy the contract
  const votingSystem = await Project.deploy(
    "Governance Token", // Token Name
    "GOV",              // Token Symbol
    initialSupply       // Initial Supply
  );

  console.log("⏳ Waiting for deployment...");
  await votingSystem.waitForDeployment();

  const address = await votingSystem.getAddress();
  console.log(`✅ Project contract deployed to: ${address}`);

  // Optional: wait for confirmations (useful before verify)
  console.log("⏳ Waiting for 5 block confirmations...");
  await votingSystem.deploymentTransaction().wait(5);

  console.log("🎉 Deployment completed successfully!");
  console.log("\nTo verify the contract on Etherscan, run:");
  console.log(
    `npx hardhat verify --network <yourNetwork> ${address} "Governance Token" "GOV" ${initialSupply}`
  );
}

// Run the deployment script
main().catch((error) => {
  console.error("❌ Deployment failed:", error);
  process.exit(1);
});t votingSystem.getAddress();
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
