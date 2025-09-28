require("dotenv").config();
const { buildModule } = require("@nomicfoundation/hardhat-ignition/modules");

const DEFAULT_UNLOCK = 1893456000n; // Jan 1, 2030 (BigInt)
const DEFAULT_AMOUNT = 1_000_000_000n; // 1 gwei

module.exports = buildModule("LockModule", (m) => {
  const unlockTime = m.getParameter(
    "unlockTime",
    process.env.UNLOCK_TIME ? BigInt(process.env.UNLOCK_TIME) : DEFAULT_UNLOCK
  );

  const lockedAmount = m.getParameter(
    "lockedAmount",
    process.env.LOCKED_AMOUNT ? BigInt(process.env.LOCKED_AMOUNT) : DEFAULT_AMOUNT
  );

  const lock = m.contract("Lock", [unlockTime], {
    value: lockedAmount,
  });

  return { lock };
});