#!/usr/bin/env bash
set -euo pipefail

# ---------- package.json (add pg + dotenv) ----------
cat > package.json <<'JSON'
{
  "name": "clickup-erp",
  "version": "1.0.0",
  "main": "src/server.js",
  "type": "commonjs",
  "scripts": {
    "start": "node src/server.js",
    "migrate": "node scripts/migrate.js"
  },
  "dependencies": {
    "dotenv": "^16.4.5",
    "express": "^4.19.2",
    "pg": "^8.11.5"
  }
}
JSON

# ---------- src/config/index.js ----------
mkdir -p src/config
cat > src/config/index.js <<'JS'
require("dotenv").config();

function must(name, fallback) {
  const v = process.env[name] ?? fallback;
  if (!v) throw new Error(`Missing env: ${name}`);
  return v;
}

module.exports = {
  env: process.env.NODE_ENV || "production",
  port: Number(process.env.PORT || 3100),
  databaseUrl: must("DATABASE_URL", "")
};
JS

# ---------- src/utils/logger.js ----------
mkdir -p src/utils
cat > src/utils/logger.js <<'JS'
function log(...a){ console.log(new Date().toISOString(), ...a); }
function warn(...a){ console.warn(new Date().toISOString(), ...a); }
function error(...a){ console.error(new Date().toISOString(), ...a); }

module.exports = { log, warn, error };
JS

# ---------- src/db/index.js ----------
mkdir -p src/db
cat > src/db/index.js <<'JS'
const { Pool } = require("pg");
const config = require("../config");

const pool = new Pool({
  connectionString: config.databaseUrl
});

async function query(text, params) {
  return pool.query(text, params);
}

async function healthcheck() {
  const r = await pool.query("SELECT 1 as ok");
  return r.rows?.[0]?.ok === 1;
}

module.exports = { pool, query, healthcheck };
JS

# ---------- migrations ----------
mkdir -p src/db/migrations

cat > src/db/migrations/001_create_clickup_tables.sql <<'SQL'
-- Jobs table (our cache / source for UI)
CREATE TABLE IF NOT EXISTS jobs (
  id              BIGSERIAL PRIMARY KEY,
  job_no          TEXT UNIQUE NOT NULL,
  quotation_no    TEXT NOT NULL,
  description     TEXT NOT NULL,
  artwork         TEXT,
  due_date        DATE NOT NULL,
  location        TEXT,
  delivery_method TEXT,
  priority        TEXT,
  status          TEXT NOT NULL,
  payment_terms   TEXT NOT NULL,
  amount          NUMERIC(12,2),
  deposit         NUMERIC(12,2),
  balance         NUMERIC(12,2),
  assignee        TEXT,
  remark          TEXT,
  subtask         TEXT,

  -- future: clickup linking
  clickup_task_id TEXT,
  clickup_list_id TEXT,

  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- simple auto-update updated_at (use trigger)
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'jobs_set_updated_at') THEN
    CREATE OR REPLACE FUNCTION set_updated_at()
    RETURNS TRIGGER AS $f$
    BEGIN
      NEW.updated_at = now();
      RETURN NEW;
    END;
    $f$ LANGUAGE plpgsql;

    CREATE TRIGGER jobs_set_updated_at
    BEFORE UPDATE ON jobs
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();
  END IF;
END $$;
SQL

cat > src/db/migrations/002_indexes.sql <<'SQL'
CREATE INDEX IF NOT EXISTS idx_jobs_due_date ON jobs(due_date);
CREATE INDEX IF NOT EXISTS idx_jobs_status ON jobs(status);
CREATE INDEX IF NOT EXISTS idx_jobs_created_at ON jobs(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_jobs_clickup_task_id ON jobs(clickup_task_id);
SQL

# ---------- scripts/migrate.js ----------
mkdir -p scripts
cat > scripts/migrate.js <<'JS'
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
JS

# ---------- src/modules/orders repo/routes ----------
mkdir -p src/modules/orders

cat > src/modules/orders/ordersRepo.js <<'JS'
const db = require("../../db");

async function listJobs(limit = 10) {
  const r = await db.query(
    `SELECT * FROM jobs ORDER BY created_at DESC LIMIT $1`,
    [limit]
  );
  return r.rows;
}

async function getJobById(id) {
  const r = await db.query(`SELECT * FROM jobs WHERE id=$1`, [id]);
  return r.rows[0] || null;
}

async function createJob(p) {
  const r = await db.query(
    `INSERT INTO jobs (
      job_no, quotation_no, description, artwork, due_date, location, delivery_method, priority,
      status, payment_terms, amount, deposit, balance, assignee, remark, subtask
    ) VALUES (
      $1,$2,$3,$4,$5,$6,$7,$8,
      $9,$10,$11,$12,$13,$14,$15,$16
    )
    RETURNING *`,
    [
      p.jobNo, p.quotationNo, p.description, p.artwork || null, p.dueDate,
      p.location || null, p.deliveryMethod || null, p.priority || null,
      p.status, p.paymentTerms,
      p.amount ?? null, p.deposit ?? null, p.balance ?? null,
      p.assignee || null, p.remark || null, p.subtask || null
    ]
  );
  return r.rows[0];
}

async function patchJob(id, p) {
  // only allow some fields for now
  const fields = [];
  const vals = [];
  let i = 1;

  const allow = {
    description: "description",
    artwork: "artwork",
    dueDate: "due_date",
    location: "location",
    deliveryMethod: "delivery_method",
    priority: "priority",
    status: "status",
    paymentTerms: "payment_terms",
    amount: "amount",
    deposit: "deposit",
    balance: "balance",
    assignee: "assignee",
    remark: "remark",
    subtask: "subtask"
  };

  for (const [k, col] of Object.entries(allow)) {
    if (p[k] !== undefined) {
      fields.push(`${col}=$${i++}`);
      vals.push(p[k]);
    }
  }

  if (!fields.length) return getJobById(id);

  vals.push(id);

  const r = await db.query(
    `UPDATE jobs SET ${fields.join(", ")} WHERE id=$${i} RETURNING *`,
    vals
  );
  return r.rows[0] || null;
}

module.exports = { listJobs, getJobById, createJob, patchJob };
JS

cat > src/modules/orders/ordersRoutes.js <<'JS'
const express = require("express");
const repo = require("./ordersRepo");

const router = express.Router();

router.get("/orders", async (req, res) => {
  const limit = Math.min(Number(req.query.limit || 10), 50);
  const rows = await repo.listJobs(limit);
  res.json(rows);
});

router.get("/orders/:id", async (req, res) => {
  const row = await repo.getJobById(req.params.id);
  if (!row) return res.status(404).json({ message: "Not found" });
  res.json(row);
});

router.post("/orders", async (req, res) => {
  const p = req.body || {};
  if (!p.jobNo || !p.quotationNo || !p.description || !p.dueDate || !p.status || !p.paymentTerms) {
    return res.status(400).json({ message: "Missing required fields" });
  }

  try {
    const created = await repo.createJob(p);
    res.status(201).json(created);
  } catch (e) {
    if (String(e.message || "").includes("duplicate key")) {
      return res.status(409).json({ message: "Duplicate job_no" });
    }
    throw e;
  }
});

router.patch("/orders/:id", async (req, res) => {
  const updated = await repo.patchJob(req.params.id, req.body || {});
  if (!updated) return res.status(404).json({ message: "Not found" });
  res.json(updated);
});

module.exports = router;
JS

# ---------- src/server.js ----------
cat > src/server.js <<'JS'
const express = require("express");
const config = require("./config");
const db = require("./db");
const { log, error } = require("./utils/logger");

const ordersRoutes = require("./modules/orders/ordersRoutes");

const app = express();
app.use(express.json({ limit: "1mb" }));

app.get("/health", async (req, res) => {
  const dbOk = await db.healthcheck().catch(() => false);
  res.json({ ok: true, service: "clickup-erp", dbOk, time: new Date().toISOString() });
});

// API
app.use(ordersRoutes);

app.use((err, req, res, next) => {
  error("ERR", err);
  res.status(500).json({ message: "Server error" });
});

app.listen(config.port, "0.0.0.0", () => {
  log(`clickup-erp running on :${config.port}`);
});
JS

echo "✅ ERP Orders API scaffolded"
echo ""
echo "Next:"
echo "  npm install (optional if using Docker build)"
echo "  docker compose up -d --build"
echo "  docker compose exec erp node scripts/migrate.js"
