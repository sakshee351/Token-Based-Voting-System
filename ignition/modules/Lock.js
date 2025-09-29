require("dotenv").config();
const { buildModule } = require("@nomicfoundation/hardhat-ignition/modules");

/**
 * Improved LockModule for Hardhat Ignition
 *
 * Features:
 * - DEFAULT values with BigInt
 * - Environment variable parsing with BigInt fallback
 * - Validation (unlockTime must be in the future; lockedAmount > 0)
 * - Optional Vault contract deploy via DEPLOY_VAULT=true
 * - Clear console logs showing resolved configuration
 */

const DEFAULT_UNLOCK = 1893456000n; // Jan 1, 2030 (seconds since epoch)
const DEFAULT_AMOUNT = 1_000_000_000n; // 1 gwei (in wei units as BigInt)

function parseBigIntEnv(varName, fallback) {
  const v = process.env[varName];
  if (!v || v === "") return fallback;
  try {
    // allow numeric string, possibly with underscores (1_000)
    const cleaned = v.replace(/_/g, "");
    return BigInt(cleaned);
  } catch (err) {
    console.warn(
      `[LockModule] Warning: invalid BigInt for ${varName} ('${v}'), using fallback.`
    );
    return fallback;
  }
}

module.exports = buildModule("LockModule", (m) => {
  // Parse parameters (use process.env if provided, else defaults)
  const unlockTime = m.getParameter(
    "unlockTime",
    parseBigIntEnv("UNLOCK_TIME", DEFAULT_UNLOCK)
  );

  const lockedAmount = m.getParameter(
    "lockedAmount",
    parseBigIntEnv("LOCKED_AMOUNT", DEFAULT_AMOUNT)
  );

  // Optional: deploy an extra Vault contract if DEPLOY_VAULT=true
  const deployVaultFlag = m.getParameter(
    "deployVault",
    (process.env.DEPLOY_VAULT || "false").toLowerCase() === "true"
  );

  // Basic validation
  const nowSec = BigInt(Math.floor(Date.now() / 1000)); // current epoch seconds
  if (typeof unlockTime === "bigint" && unlockTime <= nowSec) {
    throw new Error(
      `[LockModule] Invalid unlockTime: ${unlockTime} (must be in the future; now=${nowSec}).`
    );
  }

  if (typeof lockedAmount === "bigint" && lockedAmount <= 0n) {
    throw new Error(
      `[LockModule] Invalid lockedAmount: ${lockedAmount} (must be > 0).`
    );
  }

  // Logging configuration so it's visible when running deployments
  // (Ignition will still use the returned contract objects for deployment)
  console.log("[LockModule] Resolved configuration:");
  console.log(`  unlockTime: ${unlockTime.toString()} (epoch seconds)`);
  console.log(`  lockedAmount: ${lockedAmount.toString()} (in wei, BigInt)`);
  console.log(`  deployVault: ${deployVaultFlag}`);

  // Define the Lock contract deployment
  const lock = m.contract("Lock", [unlockTime], {
    value: lockedAmount,
  });

  // Optionally define Vault (example of multiple contracts)
  let vault;
  if (deployVaultFlag) {
    // Example: Vault constructor takes the lock contract address (replace as needed)
    // Here we pass no constructor args — modify if your Vault expects arguments.
    vault = m.contract("Vault", [], {});
  }

  // Return an object mapping names to contract deployment configs.
  // Ignition will process and deploy them.
  return {
    lock,
    ...(vault ? { vault } : {}),
  };
});