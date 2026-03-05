#!/usr/bin/env bash
set -euo pipefail

mkdir -p src/modules/clickup src/db/migrations public/ui

# -------------------------
# package.json (adds pg + dotenv, no extra libs)
# -------------------------
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

# -------------------------
# src/config/index.js
# -------------------------
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
  databaseUrl: must("DATABASE_URL", ""),
  clickupToken: process.env.CLICKUP_TOKEN || "",
  clickupListId: process.env.CLICKUP_LIST_ID || "",
  clickupIncludeClosed: String(process.env.CLICKUP_INCLUDE_CLOSED || "true").toLowerCase() === "true"
};
JS

# -------------------------
# src/utils/logger.js
# -------------------------
mkdir -p src/utils
cat > src/utils/logger.js <<'JS'
function log(...a){ console.log(new Date().toISOString(), ...a); }
function warn(...a){ console.warn(new Date().toISOString(), ...a); }
function error(...a){ console.error(new Date().toISOString(), ...a); }
module.exports = { log, warn, error };
JS

# -------------------------
# src/db/index.js
# -------------------------
mkdir -p src/db
cat > src/db/index.js <<'JS'
const { Pool } = require("pg");
const config = require("../config");

const pool = new Pool({ connectionString: config.databaseUrl });

async function query(text, params) {
  return pool.query(text, params);
}

async function healthcheck() {
  const r = await pool.query("SELECT 1 as ok");
  return r.rows?.[0]?.ok === 1;
}

module.exports = { pool, query, healthcheck };
JS

# -------------------------
# migrations: clickup_tasks + indexes
# -------------------------
mkdir -p src/db/migrations

cat > src/db/migrations/001_create_clickup_tables.sql <<'SQL'
CREATE TABLE IF NOT EXISTS clickup_tasks (
  task_id        TEXT PRIMARY KEY,
  list_id        TEXT NOT NULL,
  name           TEXT NOT NULL,
  status         TEXT,
  status_type    TEXT,
  assignees      TEXT,
  due_date_ms    BIGINT,
  created_ms     BIGINT,
  updated_ms     BIGINT,
  url            TEXT,
  raw            JSONB NOT NULL,
  synced_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);
SQL

cat > src/db/migrations/002_indexes.sql <<'SQL'
CREATE INDEX IF NOT EXISTS idx_clickup_tasks_list_id ON clickup_tasks(list_id);
CREATE INDEX IF NOT EXISTS idx_clickup_tasks_updated_ms ON clickup_tasks(updated_ms DESC);
CREATE INDEX IF NOT EXISTS idx_clickup_tasks_status ON clickup_tasks(status);
SQL

# -------------------------
# scripts/migrate.js
# -------------------------
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

# -------------------------
# ClickUp client (read-only)
# -------------------------
cat > src/modules/clickup/clickupClient.js <<'JS'
const config = require("../../config");

async function clickupFetch(url) {
  if (!config.clickupToken) throw new Error("CLICKUP_TOKEN not set");
  const res = await fetch(url, {
    headers: { Authorization: config.clickupToken }
  });
  const text = await res.text();
  let data = null;
  try { data = JSON.parse(text); } catch { data = { raw: text }; }
  if (!res.ok) {
    const msg = data?.err || data?.message || `ClickUp error ${res.status}`;
    throw new Error(msg);
  }
  return data;
}

// Pull tasks from a ClickUp List (pagination supported)
async function listTasks({ listId, includeClosed = true, page = 0 } = {}) {
  const lid = listId || config.clickupListId;
  if (!lid) throw new Error("CLICKUP_LIST_ID not set");

  const params = new URLSearchParams();
  params.set("page", String(page));
  params.set("include_closed", includeClosed ? "true" : "false");

  const url = `https://api.clickup.com/api/v2/list/${encodeURIComponent(lid)}/task?` + params.toString();
  return clickupFetch(url);
}

module.exports = { listTasks };
JS

# -------------------------
# Repo: upsert tasks
# -------------------------
cat > src/modules/clickup/clickupRepo.js <<'JS'
const db = require("../../db");

function pickAssignees(task) {
  const list = (task.assignees || []).map(a => a.username || a.email || a.id).filter(Boolean);
  return list.join(", ");
}

async function upsertTasks(listId, tasks) {
  if (!Array.isArray(tasks) || tasks.length === 0) return 0;

  let count = 0;
  for (const t of tasks) {
    const status = t.status?.status || t.status?.name || null;
    const statusType = t.status?.type || null;
    const dueMs = t.due_date ? Number(t.due_date) : null;
    const createdMs = t.date_created ? Number(t.date_created) : null;
    const updatedMs = t.date_updated ? Number(t.date_updated) : null;

    await db.query(
      `INSERT INTO clickup_tasks(
        task_id, list_id, name, status, status_type, assignees,
        due_date_ms, created_ms, updated_ms, url, raw, synced_at
      ) VALUES (
        $1,$2,$3,$4,$5,$6,
        $7,$8,$9,$10,$11, now()
      )
      ON CONFLICT (task_id) DO UPDATE SET
        list_id=EXCLUDED.list_id,
        name=EXCLUDED.name,
        status=EXCLUDED.status,
        status_type=EXCLUDED.status_type,
        assignees=EXCLUDED.assignees,
        due_date_ms=EXCLUDED.due_date_ms,
        created_ms=EXCLUDED.created_ms,
        updated_ms=EXCLUDED.updated_ms,
        url=EXCLUDED.url,
        raw=EXCLUDED.raw,
        synced_at=now()
      `,
      [
        String(t.id),
        String(listId),
        String(t.name || ""),
        status,
        statusType,
        pickAssignees(t),
        dueMs,
        createdMs,
        updatedMs,
        t.url || null,
        t
      ]
    );
    count++;
  }
  return count;
}

async function listTasksFromDb({ listId, limit = 50, q = "", status = "" } = {}) {
  const where = [];
  const params = [];
  let i = 1;

  if (listId) { where.push(`list_id=$${i++}`); params.push(String(listId)); }
  if (status) { where.push(`status=$${i++}`); params.push(String(status)); }
  if (q) {
    where.push(`(name ILIKE $${i++} OR task_id ILIKE $${i++})`);
    params.push(`%${q}%`, `%${q}%`);
  }

  params.push(Math.min(Number(limit || 50), 200));
  const sql =
    `SELECT task_id, list_id, name, status, status_type, assignees, due_date_ms, created_ms, updated_ms, url, synced_at
     FROM clickup_tasks
     ${where.length ? "WHERE " + where.join(" AND ") : ""}
     ORDER BY updated_ms DESC NULLS LAST, created_ms DESC NULLS LAST
     LIMIT $${i}`;

  const r = await db.query(sql, params);
  return r.rows;
}

module.exports = { upsertTasks, listTasksFromDb };
JS

# -------------------------
# Sync service
# -------------------------
cat > src/modules/clickup/clickupSyncService.js <<'JS'
const config = require("../../config");
const { listTasks } = require("./clickupClient");
const { upsertTasks } = require("./clickupRepo");
const { log } = require("../../utils/logger");

async function syncList({ listId } = {}) {
  const lid = listId || config.clickupListId;
  if (!lid) throw new Error("CLICKUP_LIST_ID not set");

  let page = 0;
  let totalUpserted = 0;

  while (true) {
    const data = await listTasks({
      listId: lid,
      includeClosed: config.clickupIncludeClosed,
      page
    });

    const tasks = data?.tasks || [];
    const up = await upsertTasks(lid, tasks);
    totalUpserted += up;

    log(`ClickUp sync page=${page} tasks=${tasks.length} upserted=${up}`);

    // ClickUp returns last_page boolean sometimes; also safe stop if tasks empty
    if (!tasks.length || data?.last_page === true) break;

    page++;
    if (page > 50) break; // safety cap
  }

  return { ok: true, listId: lid, upserted: totalUpserted };
}

module.exports = { syncList };
JS

# -------------------------
# Routes
# -------------------------
cat > src/modules/clickup/clickupRoutes.js <<'JS'
const express = require("express");
const config = require("../../config");
const { syncList } = require("./clickupSyncService");
const { listTasksFromDb } = require("./clickupRepo");

const router = express.Router();

// Trigger sync (manual test)
router.post("/clickup/sync", async (req, res) => {
  const listId = (req.body && req.body.listId) ? String(req.body.listId) : config.clickupListId;
  const result = await syncList({ listId });
  res.json(result);
});

// Read tasks from DB
router.get("/api/tasks", async (req, res) => {
  const limit = req.query.limit || 50;
  const q = (req.query.q || "").toString();
  const status = (req.query.status || "").toString();
  const listId = (req.query.listId || config.clickupListId || "").toString();

  const rows = await listTasksFromDb({ listId, limit, q, status });
  res.json(rows);
});

module.exports = router;
JS

# -------------------------
# UI: tasks viewer
# -------------------------
cat > public/ui/tasks.html <<'HTML'
<!doctype html>
<html lang="th">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width,initial-scale=1" />
  <title>ClickUp Tasks Viewer</title>
  <link rel="preconnect" href="https://fonts.googleapis.com" />
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin />
  <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;600;700&family=Noto+Sans+Thai:wght@400;600;700&display=swap" rel="stylesheet" />
  <style>
    :root{ --bg:#f6f8fb; --card:#fff; --text:#101828; --muted:#667085; --border:#e5e7eb; --shadow:0 10px 24px rgba(16,24,40,.06); }
    *{ box-sizing:border-box }
    body{ margin:0; font-family:Inter,"Noto Sans Thai",system-ui; background:var(--bg); color:var(--text) }
    .wrap{ max-width:1200px; margin:0 auto; padding:18px 16px 40px }
    .hero{ background:linear-gradient(135deg,#e9d5ff 0%,#dbeafe 45%,#c7f9f1 100%); border-radius:22px; padding:16px; box-shadow:var(--shadow); }
    h1{ margin:0; font-size:18px }
    .sub{ margin:6px 0 0; color:rgba(16,24,40,.7); font-size:13px }
    .card{ margin-top:12px; background:var(--card); border:1px solid var(--border); border-radius:18px; box-shadow:var(--shadow); padding:14px; }
    .row{ display:flex; gap:10px; flex-wrap:wrap; align-items:center }
    input, select{ border:1px solid #d1d5db; border-radius:12px; padding:10px 12px; font-size:13px; background:#fff; }
    button{ border:1px solid #d1d5db; border-radius:12px; padding:10px 12px; font-weight:800; background:#fff; cursor:pointer; }
    table{ width:100%; border-collapse:separate; border-spacing:0 10px; margin-top:10px }
    td,th{ text-align:left; font-size:13px; padding:10px 12px; }
    thead th{ font-size:12px; color:#98a2b3; letter-spacing:.08em }
    tbody tr{ background:#fff; border:1px solid var(--border); box-shadow:0 6px 14px rgba(16,24,40,.05); }
    tbody tr td:first-child{ border-top-left-radius:14px; border-bottom-left-radius:14px; }
    tbody tr td:last-child{ border-top-right-radius:14px; border-bottom-right-radius:14px; }
    .pill{ display:inline-block; padding:6px 10px; border-radius:999px; background:#eef2ff; border:1px solid rgba(37,99,235,.15); color:#1e40af; font-weight:800; font-size:11px; }
    .muted{ color:var(--muted); font-size:12px }
    .right{ text-align:right }
    .small{ font-size:12px; color:#98a2b3 }
    a{ color:#2563eb; text-decoration:none; font-weight:800 }
  </style>
</head>
<body>
  <div class="wrap">
    <div class="hero">
      <h1>ดูข้อมูลจาก ClickUp / ClickUp Data Viewer</h1>
      <div class="sub">Read-only sync → DB → view here. ไม่มีการเขียนกลับไปที่ ClickUp</div>
    </div>

    <div class="card">
      <div class="row">
        <button id="btnSync">Sync Now</button>
        <input id="q" placeholder="Search Task Name / ID" style="min-width:260px" />
        <select id="status">
          <option value="">All Status</option>
        </select>
        <select id="limit">
          <option value="20">20</option>
          <option value="50" selected>50</option>
          <option value="100">100</option>
        </select>
        <span class="small" id="info"></span>
      </div>

      <table>
        <thead>
          <tr>
            <th>Task</th>
            <th>Status</th>
            <th>Assignee</th>
            <th>Due</th>
            <th>Updated</th>
            <th class="right">Open</th>
          </tr>
        </thead>
        <tbody id="tbody"></tbody>
      </table>
    </div>
  </div>

<script>
  const API_BASE = "/erp"; // because this file is served under /erp/ui/tasks.html

  const els = {
    btnSync: document.getElementById("btnSync"),
    q: document.getElementById("q"),
    status: document.getElementById("status"),
    limit: document.getElementById("limit"),
    tbody: document.getElementById("tbody"),
    info: document.getElementById("info"),
  };

  let lastRows = [];

  function fmtMs(ms){
    if(!ms) return "-";
    const d = new Date(Number(ms));
    if(isNaN(d.getTime())) return "-";
    return d.toLocaleString();
  }

  function render(rows){
    lastRows = rows || [];
    // build status options
    const set = new Set(lastRows.map(r => r.status).filter(Boolean));
    const current = els.status.value;
    els.status.innerHTML = '<option value="">All Status</option>' + [...set].sort().map(s => `<option value="${esc(s)}">${esc(s)}</option>`).join("");
    if ([...set].includes(current)) els.status.value = current;

    const filtered = lastRows.filter(r => {
      const q = (els.q.value || "").toLowerCase().trim();
      const st = els.status.value;
      if (st && r.status !== st) return false;
      if (!q) return true;
      return (String(r.name||"").toLowerCase().includes(q) || String(r.task_id||"").toLowerCase().includes(q));
    });

    els.tbody.innerHTML = filtered.map(r => `
      <tr>
        <td>
          <div style="font-weight:800">${esc(r.name||"-")}</div>
          <div class="muted">${esc(r.task_id||"")}</div>
        </td>
        <td><span class="pill">${esc(r.status||"-")}</span></td>
        <td>${esc(r.assignees||"-")}</td>
        <td>${fmtMs(r.due_date_ms)}</td>
        <td>${fmtMs(r.updated_ms)}</td>
        <td class="right">${r.url ? `<a href="${esc(r.url)}" target="_blank" rel="noreferrer">Open</a>` : "-"}</td>
      </tr>
    `).join("") || '<tr><td colspan="6" class="muted">No data (sync first)</td></tr>';

    els.info.textContent = `Showing ${filtered.length} / ${lastRows.length}`;
  }

  async function load(){
    const limit = els.limit.value;
    const res = await fetch(API_BASE + "/api/tasks?limit=" + encodeURIComponent(limit));
    const rows = await res.json().catch(()=>[]);
    render(Array.isArray(rows) ? rows : []);
  }

  els.btnSync.addEventListener("click", async ()=>{
    els.btnSync.disabled = true;
    els.btnSync.textContent = "Syncing...";
    try{
      const r = await fetch(API_BASE + "/clickup/sync", { method:"POST", headers:{ "Content-Type":"application/json" }, body:"{}" });
      await r.json().catch(()=>null);
    }catch(e){}
    await load();
    els.btnSync.disabled = false;
    els.btnSync.textContent = "Sync Now";
  });

  els.q.addEventListener("input", ()=>render(lastRows));
  els.status.addEventListener("change", ()=>render(lastRows));
  els.limit.addEventListener("change", load);

  function esc(s){ return String(s??"").replace(/[&<>"']/g,m=>({ "&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#039;" }[m])); }

  load();
</script>
</body>
</html>
HTML

# -------------------------
# src/server.js (serve routes + static UI)
# -------------------------
cat > src/server.js <<'JS'
const express = require("express");
const config = require("./config");
const db = require("./db");
const { log, error } = require("./utils/logger");

const clickupRoutes = require("./modules/clickup/clickupRoutes");

const app = express();
app.use(express.json({ limit: "2mb" }));

// serve UI
app.use("/ui", express.static("public/ui"));

// health
app.get("/health", async (req, res) => {
  const dbOk = await db.healthcheck().catch(() => false);
  res.json({ ok: true, service: "clickup-erp", dbOk, time: new Date().toISOString() });
});

// clickup + api routes
app.use(clickupRoutes);

// error handler
app.use((err, req, res, next) => {
  error("ERR", err);
  res.status(500).json({ message: "Server error" });
});

app.listen(config.port, "0.0.0.0", () => {
  log(`clickup-erp running on :${config.port}`);
});
JS

echo "✅ ClickUp read-only sync + DB + UI added."
echo "Next:"
echo "  docker compose up -d --build"
echo "  docker compose exec erp node scripts/migrate.js"
echo "  open: https://alphadigital.media/erp/ui/tasks.html"
