// Admin-auth/routes/admin.oms.js  (FULL REPLACEMENT - CommonJS)
const express = require("express");
const { Pool } = require("pg");

const router = express.Router();
const { requireAuth } = require("../middleware/auth");

// --------------------------------------------------
// DB
// --------------------------------------------------
const pool = new Pool({
  host: process.env.OMS_DB_HOST || "n8n_postgres",
  port: Number(process.env.OMS_DB_PORT || 5432),
  database: process.env.OMS_DB_NAME || "oms",
  user: process.env.OMS_DB_USER || "n8n",
  password: process.env.OMS_DB_PASSWORD || "Octopus@1919",
  max: 10,
  idleTimeoutMillis: 30000,
});

// --------------------------------------------------
// AUTH + ROLE HELPERS
// --------------------------------------------------
function isStaff(role) {
  const r = String(role || "").toLowerCase();
  return [
    "admin",
    "owner",
    "superadmin",
    "user",
    "team",
    "staff",
    "supervisor",
    "operator",
  ].includes(r);
}

function canEditComments(role) {
  const r = String(role || "").toLowerCase();
  return r === "owner" || r === "superadmin";
}


function requireStaff(req, res, next) {
  if (!req.user?.id) {
    return res.status(401).json({ ok: false, error: "not_authenticated" });
  }
  if (!isStaff(req.user.role)) {
    return res.status(403).json({ ok: false, error: "staff_only" });
  }
  next();
}

// --------------------------------------------------
// JOB NORMALIZER
// --------------------------------------------------
function normalizeJobRow(ojson, ujson) {
  const jobDescription = ojson.job_description || ojson.description || "";

  return {
    id: ojson.id,
    job_no: ojson.job_no || `#${ojson.id}`,
    project_name: ojson.project_name || "-",
    job_type: ojson.job_type || "-",
    status: ojson.status || "unknown",
    created_at: ojson.created_at || null,
    updated_at: ojson.updated_at || null,
    due_date: ojson.required_completion_date || null,
    location_url: ojson.location_url || null,

    // raw db fields (keep)
    description: ojson.description || null,
    job_description: ojson.job_description || null,

    // UI-friendly
    jobDescription,

    customer: ujson
      ? {
          id: ujson.id ?? null,
          customer_code: ujson.customer_code || null,
          display_name: ujson.display_name || null,
        }
      : null,
  };
}

// --------------------------------------------------
// Resolve jobKey -> job row (id OR job_no)
// --------------------------------------------------
async function resolveJobByKey(jobKey) {
  const key = String(jobKey || "").trim();

  // 1) numeric id
  if (/^\d+$/.test(key)) {
    const r = await pool.query(
      `
      SELECT to_jsonb(o) AS ojson,
             to_jsonb(u) AS ujson
      FROM orders o
      LEFT JOIN users u ON u.id = o.customer_id
      WHERE o.id=$1
      LIMIT 1
      `,
      [Number(key)]
    );
    if (r.rows.length) return r.rows[0];
  }

  // 2) job_no
  {
    const r = await pool.query(
      `
      SELECT to_jsonb(o) AS ojson,
             to_jsonb(u) AS ujson
      FROM orders o
      LEFT JOIN users u ON u.id = o.customer_id
      WHERE o.job_no=$1
      LIMIT 1
      `,
      [key]
    );
    if (r.rows.length) return r.rows[0];
  }

  return null;
}

// --------------------------------------------------
// RECENT ORDERS
// --------------------------------------------------
router.get("/orders/recent", requireAuth(), async (req, res) => {
  try {
    const limit = Math.min(Number(req.query.limit || 10), 50);

    const r = await pool.query(
      `
      SELECT to_jsonb(o) AS ojson,
             to_jsonb(u) AS ujson
      FROM orders o
      LEFT JOIN users u ON u.id = o.customer_id
      ORDER BY o.updated_at DESC NULLS LAST,
               o.created_at DESC NULLS LAST,
               o.id DESC
      LIMIT $1
      `,
      [limit]
    );

    const jobs = r.rows.map((row) => normalizeJobRow(row.ojson, row.ujson));

    res.json({ ok: true, jobs });
  } catch (e) {
    res.status(500).json({ ok: false, message: e.message });
  }
});

// --------------------------------------------------
// JOB DETAIL (by numeric id)
// --------------------------------------------------
router.get("/jobs/:id", requireAuth(), async (req, res) => {
  try {
    const id = Number(req.params.id);
    if (!id) return res.status(400).json({ ok: false, message: "bad_id" });

    const r = await pool.query(
      `
      SELECT to_jsonb(o) AS ojson,
             to_jsonb(u) AS ujson
      FROM orders o
      LEFT JOIN users u ON u.id = o.customer_id
      WHERE o.id=$1
      LIMIT 1
      `,
      [id]
    );

    if (!r.rows.length) {
      return res.status(404).json({ ok: false, message: "not_found" });
    }

    const job = normalizeJobRow(r.rows[0].ojson, r.rows[0].ujson);

    res.json({
      ok: true,
      job,
      perms: {
        isStaff: isStaff(req.user?.role),
        canEditComments: canEditComments(req.user?.role),
      },
    });
  } catch (e) {
    res.status(500).json({ ok: false, message: e.message });
  }
});

// --------------------------------------------------
// COMMENTS
// - staff view: includes internal
// - non-staff: hides internal
// --------------------------------------------------
router.get("/jobs/:id/comments", requireAuth(), async (req, res) => {
  try {
    const id = Number(req.params.id);
    if (!id) return res.status(400).json({ ok: false, message: "bad_id" });

    const staff = isStaff(req.user?.role);

    const r = await pool.query(
      `
      SELECT jc.*, u.display_name, u.picture_url
      FROM job_comments jc
      LEFT JOIN users u ON u.id = jc.author_user_id
      WHERE jc.job_id=$1
      ${staff ? "" : "AND jc.is_internal=false"}
      ORDER BY jc.created_at ASC NULLS LAST, jc.id ASC
      `,
      [id]
    );

    res.json({
      ok: true,
      comments: r.rows.map((c) => ({
        id: c.id,
        job_id: c.job_id,
        text: c.body,
        is_internal: c.is_internal,
        created_at: c.created_at,
        user: {
          id: c.author_user_id,
          display_name: c.author_name || c.display_name || "-",
          picture_url: c.picture_url || null,
          role: c.author_role || null,
        },
      })),
    });
  } catch (e) {
    res.status(500).json({ ok: false, message: e.message });
  }
});

// --------------------------------------------------
// CREATE COMMENT
// - staff can set internal
// - non-staff forced public
// expects body: { text, is_internal? }
// --------------------------------------------------
router.post("/jobs/:id/comments", requireAuth(), async (req, res) => {
  try {
    const id = Number(req.params.id);
    if (!id) return res.status(400).json({ ok: false, message: "bad_id" });

    const text = String(req.body?.text || "").trim();
    if (!text) return res.status(400).json({ ok: false, message: "empty_text" });

    const staff = isStaff(req.user?.role);
    const is_internal = staff && req.body?.is_internal === true;

    const ins = await pool.query(
      `
      INSERT INTO job_comments
      (job_id, is_internal, author_user_id, author_role, author_name, body)
      VALUES ($1,$2,$3,$4,$5,$6)
      RETURNING id, is_internal, created_at
      `,
      [
        id,
        is_internal,
        req.user?.id || null,
        req.user?.role || "staff",
        req.user?.display_name || req.user?.username || "staff",
        text,
      ]
    );

    res.json({
      ok: true,
      id: ins.rows[0]?.id || null,
      is_internal: ins.rows[0]?.is_internal || false,
      created_at: ins.rows[0]?.created_at || null,
    });
  } catch (e) {
    res.status(500).json({ ok: false, message: e.message });
  }
});

// --------------------------------------------------
// INTERNAL MEMO (staff only)
// supports jobKey = numeric id OR job_no (D000005/S0009)
// expects body: { body: "..." }
// always forces is_internal=true
// --------------------------------------------------
router.post("/jobs/:jobKey/internal", requireStaff, async (req, res) => {
  try {
    const { jobKey } = req.params;
    const body = String(req.body?.body || "").trim();
    if (!body) {
      return res.status(400).json({ ok: false, message: "body_required" });
    }

    const row = await resolveJobByKey(jobKey);
    if (!row) return res.status(404).json({ ok: false, message: "job_not_found" });

    const job = normalizeJobRow(row.ojson, row.ujson);

    const ins = await pool.query(
      `
      INSERT INTO job_comments
      (job_id, is_internal, author_user_id, author_role, author_name, body)
      VALUES ($1,true,$2,$3,$4,$5)
      RETURNING id, created_at
      `,
      [
        job.id,
        req.user?.id || null,
        req.user?.role || "staff",
        req.user?.display_name || req.user?.username || "staff",
        body,
      ]
    );

    res.json({
      ok: true,
      id: ins.rows[0]?.id || null,
      created_at: ins.rows[0]?.created_at || null,
    });
  } catch (err) {
    console.error("internal memo error", err);
    res.status(500).json({ ok: false, message: "internal_proxy_error" });
  }
});

// --------------------------------------------------
// LOCATION UPDATE
// --------------------------------------------------
router.post("/jobs/:id/location", requireAuth(), async (req, res) => {
  try {
    const id = Number(req.params.id);
    const url = String(req.body?.location_url || "").trim();
    if (!id || !url) {
      return res.status(400).json({ ok: false, message: "bad_request" });
    }

    await pool.query(
      `UPDATE orders SET location_url=$1, updated_at=NOW() WHERE id=$2`,
      [url, id]
    );

    res.json({ ok: true });
  } catch (e) {
    res.status(500).json({ ok: false, message: e.message });
  }
});

module.exports = router;