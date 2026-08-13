import { spawnSync } from "node:child_process";

const scripts = [
  "test:workspace",
  "test:health",
  "test:auto-health",
  "test:sleep",
  "test:workout",
  "test:motion",
  "test:habit",
  "build",
];

const npmExecPath = process.env.npm_execpath;
const command = npmExecPath
  ? process.execPath
  : process.platform === "win32"
    ? "npm.cmd"
    : "npm";
const prefix = npmExecPath ? [npmExecPath] : [];

for (const script of scripts) {
  console.log(`\n=== npm run ${script} ===`);
  const result = spawnSync(command, [...prefix, "run", script], {
    cwd: process.cwd(),
    env: process.env,
    stdio: "inherit",
    shell: !npmExecPath && process.platform === "win32",
  });

  if (result.error) {
    console.error(`Could not start npm run ${script}: ${result.error.message}`);
    process.exit(1);
  }

  if (result.status !== 0) {
    process.exit(result.status ?? 1);
  }
}

console.log("\nArchive verification passed.");
