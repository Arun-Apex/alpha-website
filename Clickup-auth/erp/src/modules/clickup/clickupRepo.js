// src/modules/clickup/clickupRepo.js
const db = require("../../db");

function pickAssignees(task) {
  const list = (task.assignees || [])
    .map(a => a.username || a.email || a.id)
    .filter(Boolean);
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

// NEW: dueFrom/dueTo added (Date objects or null)
async function listTasksFromDb({
  listId,
  limit = 50,
  q = "",
  status = "",
  dueFrom = null,
  dueTo = null,
} = {}) {
  const where = [];
  const params = [];
  let i = 1;

  if (listId) {
    where.push(`list_id=$${i++}`);
    params.push(String(listId));
  }

  if (status) {
    where.push(`status=$${i++}`);
    params.push(String(status));
  }

  // NEW: due date range filter (uses due_date_ms)
  // If any due filter is present, require due_date_ms not null
  const dueFromMs = dueFrom instanceof Date && !isNaN(dueFrom.getTime()) ? dueFrom.getTime() : null;
  const dueToMs = dueTo instanceof Date && !isNaN(dueTo.getTime()) ? dueTo.getTime() : null;

  if (dueFromMs || dueToMs) {
    where.push(`due_date_ms IS NOT NULL`);
    if (dueFromMs) {
      where.push(`due_date_ms >= $${i++}`);
      params.push(dueFromMs);
    }
    if (dueToMs) {
      where.push(`due_date_ms <= $${i++}`);
      params.push(dueToMs);
    }
  }

  // Search: name, task_id, and (optional) custom_id from raw json
  if (q) {
    where.push(`(
      name ILIKE $${i++}
      OR task_id ILIKE $${i++}
      OR COALESCE(raw->>'custom_id','') ILIKE $${i++}
    )`);
    const like = `%${q}%`;
    params.push(like, like, like);
  }

  params.push(Math.min(Number(limit || 50), 200));

  const sql =
    `SELECT
        task_id,
        list_id,
        name,
        status,
        status_type,
        assignees,
        due_date_ms,
        created_ms,
        updated_ms,
        url,
        synced_at,
        (raw->'status'->>'color') AS status_color,
        (raw->>'custom_id') AS custom_id
     FROM clickup_tasks
     ${where.length ? "WHERE " + where.join(" AND ") : ""}
     ORDER BY updated_ms DESC NULLS LAST, created_ms DESC NULLS LAST
     LIMIT $${i}`;

  const r = await db.query(sql, params);

  // Normalize keys to what UI expects
  return r.rows.map(x => ({
    taskId: x.task_id,
    listId: x.list_id,
    name: x.name,
    status: x.status,
    statusType: x.status_type,
    assignees: x.assignees,
    dueDateMs: x.due_date_ms,
    createdMs: x.created_ms,
    updatedMs: x.updated_ms,
    url: x.url,
    syncedAt: x.synced_at,
    statusColor: x.status_color || null,

    // NEW: helps UI determine JOB D vs JOB S if you use custom id prefixes (Dxxxx/Sxxxx)
    customId: x.custom_id || null
  }));
}

module.exports = { upsertTasks, listTasksFromDb };