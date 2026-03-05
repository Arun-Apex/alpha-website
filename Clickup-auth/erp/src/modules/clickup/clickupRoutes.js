const express = require("express");
const config = require("../../config");
const { syncList } = require("./clickupSyncService");
const { listTasksFromDb } = require("./clickupRepo");

const router = express.Router();

/**
 * JOB MODE -> listId mapping
 * Put these in your config:
 *   config.clickupListIdJobD
 *   config.clickupListIdJobS
 *
 * Backward compatibility:
 *   config.clickupListId still works as default.
 */
function resolveListId(req) {
  const job = String(req.query.job || req.body?.job || "").toUpperCase().trim(); // "D" or "S"
  const listIdFromReq =
    (req.query.listId || req.body?.listId || "").toString().trim();

  if (listIdFromReq) return { listId: listIdFromReq, job: job || null };

  if (job === "D" && config.clickupListIdJobD) return { listId: String(config.clickupListIdJobD), job: "D" };
  if (job === "S" && config.clickupListIdJobS) return { listId: String(config.clickupListIdJobS), job: "S" };

  // fallback (old behavior)
  return { listId: String(config.clickupListId || ""), job: job || null };
}

/**
 * Parse YYYY-MM-DD to inclusive range (local time)
 * We return ISO-ish strings or Date objects depending on your repo needs.
 */
function parseDateRange(q) {
  const dueFrom = (q.dueFrom || "").toString().trim(); // YYYY-MM-DD
  const dueTo = (q.dueTo || "").toString().trim();

  const isYmd = (s) => /^\d{4}-\d{2}-\d{2}$/.test(s);

  let from = null;
  let to = null;

  if (isYmd(dueFrom)) from = new Date(`${dueFrom}T00:00:00.000`);
  if (isYmd(dueTo)) to = new Date(`${dueTo}T23:59:59.999`);

  // invalid date safety
  if (from && isNaN(from.getTime())) from = null;
  if (to && isNaN(to.getTime())) to = null;

  return { dueFrom: from, dueTo: to };
}

// Trigger sync (manual test, read-only)
// Trigger sync (manual test, read-only)
router.post("/clickup/sync", async (req, res) => {
  try {
    const listId =
      (req.query && req.query.listId) ? String(req.query.listId) :
      (req.body && req.body.listId) ? String(req.body.listId) :
      config.clickupListId;

    if (!listId) return res.status(400).json({ message: "Missing listId" });

    const result = await syncList({ listId });
    res.json(result);
  } catch (e) {
    res.status(500).json({ message: String(e?.message || e) });
  }
});

// Read tasks from DB (now supports job + dueFrom + dueTo)
router.get("/api/tasks", async (req, res) => {
  try {
    const limitRaw = req.query.limit || 50;
    const limit = Math.max(1, Math.min(500, Number(limitRaw) || 50)); // safety clamp

    const q = (req.query.q || "").toString();
    const status = (req.query.status || "").toString();

    const { listId, job } = resolveListId(req);
    const { dueFrom, dueTo } = parseDateRange(req.query);

    // You need to update listTasksFromDb to accept dueFrom/dueTo (and optionally job)
    const rows = await listTasksFromDb({
      listId,
      limit,
      q,
      status,
      dueFrom,
      dueTo,
      job,
    });

    res.json(rows);
  } catch (e) {
    res.status(500).json({ message: String(e?.message || e) });
  }
});

module.exports = router;