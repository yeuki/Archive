import { readFileSync, statSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const root = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const requiredFiles = [
  "AGENTS.md",
  "docs/PRODUCT.md",
  "docs/DESIGN_SYSTEM.md",
  "docs/ARCHITECTURE.md",
  "docs/DECISIONS.md",
  "docs/DEVELOPMENT_WORKFLOW.md",
  "docs/specs/TEMPLATE.md",
  "docs/reference/README.md",
  "docs/reference/home.png",
  "docs/reference/navigation-productivity.png",
  "docs/reference/workout.png",
  "docs/reference/workout-mode.png",
  "docs/reference/sleep.png",
  "docs/reference/settings.png",
  ".github/workflows/validate.yml",
  ".github/ISSUE_TEMPLATE/major-change.yml",
  ".github/PULL_REQUEST_TEMPLATE.md",
];
const errors = [];

for (const path of requiredFiles) {
  try {
    if (statSync(resolve(root, path)).size === 0) {
      errors.push(`${path} is empty.`);
    }
  } catch {
    errors.push(`${path} is missing.`);
  }
}

const version = readFileSync(resolve(root, "VERSION"), "utf8").trim();
const packageJson = JSON.parse(readFileSync(resolve(root, "package.json"), "utf8"));
const packageLock = JSON.parse(readFileSync(resolve(root, "package-lock.json"), "utf8"));

if (!/^\d+\.\d+\.\d+$/.test(version)) {
  errors.push(`VERSION is not semantic: ${version}`);
}
if (packageJson.version !== version) {
  errors.push(`package.json version ${packageJson.version} does not match VERSION ${version}.`);
}
if (packageLock.version !== version || packageLock.packages?.[""]?.version !== version) {
  errors.push("package-lock.json root versions do not match VERSION.");
}

const agentsBytes = statSync(resolve(root, "AGENTS.md")).size;
if (agentsBytes > 16 * 1024) {
  errors.push(`AGENTS.md is ${agentsBytes} bytes; keep it at or below 16 KiB and move detail into docs/.`);
}

const setup = readFileSync(resolve(root, "MULTI_COMPUTER_SETUP.md"), "utf8");
if (!setup.includes("https://github.com/yeuki/Archive.git")) {
  errors.push("MULTI_COMPUTER_SETUP.md does not contain the canonical repository URL.");
}
if (/github\.com\/yeuki\/archive-productivity-tracker(?:\.git)?/i.test(setup)) {
  errors.push("MULTI_COMPUTER_SETUP.md still contains the retired repository URL.");
}

if (errors.length) {
  console.error("Archive workspace verification failed:\n");
  for (const error of errors) console.error(`- ${error}`);
  process.exit(1);
}

console.log(`Workspace contract passed (Archive ${version}; AGENTS.md ${agentsBytes} bytes).`);
