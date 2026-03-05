// routes/jobs.js  (ESM)
import path from "path";
import fs from "fs";
import express from "express";
import multer from "multer";

const router = express.Router();

function isStaff(role) {
  const r = String(role || "").toLowerCase();
  return ["admin", "owner", "superadmin", "user", "team", "staff"].includes(r);
}
function canEditComments(role) {
  const r = String(role || "").toLowerCase();
  return r === "owner" || r === "superadmin";
}

// ---------- uploads (internal memo attachments) ----------
const UPLOAD_DIR = path.join(process.cwd(), "uploads");
if (!fs.existsSync(UPLOAD_DIR)) fs.mkdirSync(UPLOAD_DIR, { recursive: true });

const storage = multer.diskStorage({
  destination: (_req, _file, cb) => cb(null, UPLOAD_DIR),
  filename: (_req, file, cb) => {
    const safe = String(file.originalname || "file").replace(/[^\w.\-() ]+/g, "_");
    cb(null, `${Date.now()}__${safe}`);
  },
});
const upload = multer({ storage, limits: { fileSize: 25 * 1024 * 1024 } }); // 25MB

function pool(req) {
  return req.app.get("pgPool");
}

// Accept jobKey as numeric id OR job_no
async function resolveJob(req, jobKey) {
  const p = pool(req);
  const key = String(jobKey || "").trim();

  // numeric id
  if (/^\d+$/.test(key)) {
    const r = await p.query(
      `SELECT id, job_no, project_name, job_type, status,
              created_at, updated_at, user_id,
              location_url, description, job_description
       FROM orders WHERE id=$1 LIMIT 1`,
      [Number(key)]
    );
    if (r.rows[0]) return r.rows[0];
  }

  // job_no
  {
    const r = await p.query(
      `SELECT id, job_no, project_name, job_type, status,
              created_at, updated_at, user_id,
              location_url, description, job_description
       FROM orders WHERE job_no=$1 LIMIT 1`,
      [key]
    );
    if (r.rows[0]) return r.rows[0];
  }

  return null;
}

// ------------------ middleware ------------------
function requireAuth(req, res, next) {
  if (!req.user?.id) return res.status(401).json({ ok: false, error: "not_authenticated" });
  next();
}

function requireStaff(req, res, next) {
  if (!req.user?.id) return res.status(401).json({ ok: false, error: "not_authenticated" });
  if (!isStaff(req.user.role)) return res.status(403).json({ ok: false, error: "staff_only" });
  next();
}

// ------------------ APIs ------------------

// Job details
router.get("/api/jobs/:jobKey", requireAuth, async (req, res) => {
  try {
    const job = await resolveJob(req, req.params.jobKey);
    if (!job) return res.status(404).json({ ok: false, message: "job_not_found" });

    const staff = isStaff(req.user.role);

    if (!staff && job.user_id && String(job.user_id) !== String(req.user.id)) {
      return res.status(403).json({ ok: false, message: "forbidden" });
    }

    res.json({
      ok: true,
      job: {
        ...job,
        jobDescription: job.job_description || job.description || ""
      },
      perms: { isStaff: staff, canEditComments: canEditComments(req.user.role) },
    });
  } catch (e) {
    res.status(500).json({ ok: false, message: String(e?.message || e) });
  }
});

// Update location
router.patch("/api/jobs/:jobKey/location", requireAuth, async (req, res) => {
  try {
    const job = await resolveJob(req, req.params.jobKey);
    if (!job) return res.status(404).json({ ok: false, message: "job_not_found" });

    const staff = isStaff(req.user.role);
    if (!staff && job.user_id && String(job.user_id) !== String(req.user.id)) {
      return res.status(403).json({ ok: false, message: "forbidden" });
    }

    const location_url = String(req.body?.location_url || "").trim() || null;

    await pool(req).query(
      `UPDATE orders SET location_url=$1, updated_at=now() WHERE id=$2`,
      [location_url, job.id]
    );

    res.json({ ok: true });
  } catch (e) {
    res.status(500).json({ ok: false, message: String(e?.message || e) });
  }
});

// ---------------- COMMENTS ----------------

// GET comments
router.get("/api/jobs/:jobKey/comments", requireAuth, async (req, res) => {
  try {
    const job = await resolveJob(req, req.params.jobKey);
    if (!job) return res.status(404).json({ ok: false, message: "job_not_found" });

    const staff = isStaff(req.user.role);

    if (!staff && job.user_id && String(job.user_id) !== String(req.user.id)) {
      return res.status(403).json({ ok: false, message: "forbidden" });
    }

    const r = await pool(req).query(
      `SELECT id, job_id, is_internal, author_user_id,
              author_role, author_name, body,
              created_at, updated_at
       FROM job_comments
       WHERE job_id=$1
         AND ($2 = true OR is_internal = false)
       ORDER BY created_at ASC`,
      [job.id, staff]
    );

    res.json({ ok: true, comments: r.rows });
  } catch (e) {
    res.status(500).json({ ok: false, message: String(e?.message || e) });
  }
});

// CREATE comment
router.post("/api/jobs/:jobKey/comments", requireAuth, async (req, res) => {
  try {
    const job = await resolveJob(req, req.params.jobKey);
    if (!job) return res.status(404).json({ ok: false, message: "job_not_found" });

    const staff = isStaff(req.user.role);

    if (!staff && job.user_id && String(job.user_id) !== String(req.user.id)) {
      return res.status(403).json({ ok: false, message: "forbidden" });
    }

    const body = String(req.body?.body || "").trim();
    if (!body) return res.status(400).json({ ok: false, message: "body_required" });

    // 🔒 customer CANNOT create internal memo
    const is_internal = staff ? !!req.body?.is_internal : false;

    const ins = await pool(req).query(
      `INSERT INTO job_comments(job_id, is_internal, author_user_id, author_role, author_name, body)
       VALUES ($1,$2,$3,$4,$5,$6)
       RETURNING id, created_at`,
      [
        job.id,
        is_internal,
        Number(req.user.id) || null,
        String(req.user.role),
        String(req.user.display_name),
        body
      ]
    );

    res.json({ ok: true, id: ins.rows[0].id, created_at: ins.rows[0].created_at });
  } catch (e) {
    res.status(500).json({ ok: false, message: String(e?.message || e) });
  }
});

// EDIT comment (owner/superadmin only)
router.patch("/api/jobs/comments/:id", requireAuth, async (req, res) => {
  try {
    if (!canEditComments(req.user.role)) {
      return res.status(403).json({ ok: false, message: "only_owner_or_superadmin" });
    }

    const id = Number(req.params.id);
    const body = String(req.body?.body || "").trim();
    if (!id || !body) return res.status(400).json({ ok: false, message: "id_body_required" });

    await pool(req).query(
      `UPDATE job_comments SET body=$1, updated_at=now() WHERE id=$2`,
      [body, id]
    );

    res.json({ ok: true });
  } catch (e) {
    res.status(500).json({ ok: false, message: String(e?.message || e) });
  }
});

// Internal memo + attachments (staff only)
router.post("/api/jobs/:jobKey/internal", requireStaff, upload.array("files", 10), async (req, res) => {
  try {
    const job = await resolveJob(req, req.params.jobKey);
    if (!job) return res.status(404).json({ ok: false, message: "job_not_found" });

    const body = String(req.body?.body || "").trim();
    const files = req.files || [];

    if (!body && files.length === 0)
      return res.status(400).json({ ok: false, message: "body_or_files_required" });

    const ins = await pool(req).query(
      `INSERT INTO job_comments(job_id, is_internal, author_user_id, author_role, author_name, body)
       VALUES ($1,true,$2,$3,$4,$5) RETURNING id`,
      [job.id, Number(req.user.id) || null, String(req.user.role), String(req.user.display_name), body || "(attachment)"]
    );

    res.json({ ok: true, commentId: ins.rows[0].id });
  } catch (e) {
    res.status(500).json({ ok: false, message: String(e?.message || e) });
  }
});

export default router;