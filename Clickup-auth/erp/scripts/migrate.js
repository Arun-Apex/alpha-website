const fs = require("fs");
const path = require("path");
const db = require("../src/db");
const { log } = require("../src/utils/logger");

async function ensureMigrationsTable() {
  await db.query(`
    CREATE TABLE IF NOT EXISTS migrations (
      id SERIAL PRIMARY KEY,
      name TEXT UNIQUE NOT NULL,
      ran_at TIMESTAMPTZ NOT NULL DEFAULT now()
    );
  `);
}

async function hasRun(name) {
  const r = await db.query("SELECT 1 FROM migrations WHERE name=$1", [name]);
  return r.rowCount > 0;
}

async function markRun(name) {
  await db.query("INSERT INTO migrations(name) VALUES($1) ON CONFLICT DO NOTHING", [name]);
}

async function run() {
  const dir = path.join(__dirname, "..", "src", "db", "migrations");
  const files = fs.readdirSync(dir).filter(f => f.endsWith(".sql")).sort();

  await ensureMigrationsTable();

  for (const f of files) {
    if (await hasRun(f)) {
      log("skip migration:", f);
      continue;
    }
    const sql = fs.readFileSync(path.join(dir, f), "utf8");
    log("run migration:", f);
    await db.query(sql);
    await markRun(f);
  }

  log("✅ migrations complete");
  process.exit(0);
}

run().catch(err => {
  console.error(err);
  process.exit(1);
});
