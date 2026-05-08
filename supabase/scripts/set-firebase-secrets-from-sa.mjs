#!/usr/bin/env node
/**
 * Builds a one-shot .env file from a Google service account JSON and runs:
 *   supabase secrets set --env-file <tmpfile>
 *
 * Usage (from repo root, linked Supabase project):
 *   node supabase/scripts/set-firebase-secrets-from-sa.mjs /path/to/serviceAccount.json
 *
 * The JSON is the standard key from Firebase console:
 * Project settings → Service accounts → Generate new private key
 *
 * Requires: supabase CLI on PATH, `supabase link` already done for the target project.
 */

import {
  readFileSync,
  mkdtempSync,
  writeFileSync,
  rmSync,
} from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { spawnSync } from "node:child_process";

const jsonPath = process.argv[2];
if (!jsonPath) {
  console.error(
    "Usage: node supabase/scripts/set-firebase-secrets-from-sa.mjs <serviceAccount.json>",
  );
  process.exit(1);
}

let parsed;
try {
  parsed = JSON.parse(readFileSync(jsonPath, "utf8"));
} catch (e) {
  console.error("Failed to read or parse JSON:", e.message);
  process.exit(1);
}

const projectId = parsed.project_id;
const clientEmail = parsed.client_email;
const privateKey = parsed.private_key;

if (
  typeof projectId !== "string" ||
  typeof clientEmail !== "string" ||
  typeof privateKey !== "string"
) {
  console.error(
    "JSON must include string fields: project_id, client_email, private_key",
  );
  process.exit(1);
}

// JSON.stringify quoting is compatible with supabase secrets --env-file parsing.
const lines = [
  `FIREBASE_PROJECT_ID=${JSON.stringify(projectId)}`,
  `FIREBASE_CLIENT_EMAIL=${JSON.stringify(clientEmail)}`,
  `FIREBASE_PRIVATE_KEY=${JSON.stringify(privateKey)}`,
];

const dir = mkdtempSync(join(tmpdir(), "flap-fb-secrets-"));
const envFile = join(dir, "firebase.env");
writeFileSync(envFile, `${lines.join("\n")}\n`, "utf8");

const result = spawnSync(
  "supabase",
  ["secrets", "set", "--env-file", envFile],
  { stdio: "inherit" },
);

try {
  rmSync(dir, { recursive: true, force: true });
} catch {
  /* ignore */
}

if (result.error) {
  console.error(result.error.message);
  process.exit(1);
}
process.exit(result.status ?? 1);
