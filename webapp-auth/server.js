import express from "express";
import session from "express-session";
import crypto from "crypto";
import pg from "pg";
import path from "path";

import jobsRoute from "./routes/jobs.js";

const { Pool } = pg;

const app = express();
app.set("trust proxy", 1);
app.use(express.json({ limit: "2mb" }));

/* ================= ENV ================= */
const {
  PORT = "3001",

  APP_BASE_URL,
  LINE_CHANNEL_ID,
  LINE_CHANNEL_SECRET,
  SESSION_SECRET,
  AFTER_LOGIN_PATH = "/app/",

  DB_HOST,
  DB_PORT = "5432",
  DB_NAME,
  DB_USER,
  DB_PASSWORD,
} = process.env;

if (!APP_BASE_URL || !LINE_CHANNEL_ID || !LINE_CHANNEL_SECRET || !SESSION_SECRET) {
  console.error("Missing env vars: APP_BASE_URL, LINE_CHANNEL_ID, LINE_CHANNEL_SECRET, SESSION_SECRET");
  process.exit(1);
}
if (!DB_HOST || !DB_NAME || !DB_USER || !DB_PASSWORD) {
  console.error("Missing DB env vars: DB_HOST, DB_NAME, DB_USER, DB_PASSWORD");
  process.exit(1);
}

/* ================= DB ================= */
const pool = new Pool({
  host: DB_HOST,
  port: Number(DB_PORT),
  database: DB_NAME,
  user: DB_USER,
  password: DB_PASSWORD,
  max: 10,
  idleTimeoutMillis: 30_000,
});
app.set("pgPool", pool);

/* ================= SESSION ================= */
app.use(
  session({
    name: "oms.sid",
    secret: SESSION_SECRET,
    resave: false,
    saveUninitialized: false,
    cookie: {
      httpOnly: true,
      secure: true, // HTTPS behind nginx
      sameSite: "lax",
      maxAge: 7 * 24 * 60 * 60 * 1000,
    },
  })
);

// Make a single consistent auth object for all routes
app.use((req, _res, next) => {
  req.user = req.session?.user || null;
  next();
});

// Serve internal uploads (staff-only UI should link to these)
// NOTE: access control is not enforced here; if you want locked downloads later,
// we can switch to a signed download endpoint instead.
app.use("/uploads", express.static(path.join(process.cwd(), "uploads")));

/* ================= HELPERS ================= */
const randState = () => crypto.randomBytes(16).toString("hex");

function requireAuth(req, res, next) {
  if (!req.session?.user?.id) return res.status(401).json({ ok: false, error: "not_authenticated" });
  next();
}

async function assertOrderBelongsToUser(orderId, userId) {
  const r = await pool.query("SELECT id FROM orders WHERE id = $1 AND user_id = $2", [orderId, userId]);
  return r.rows.length > 0;
}

async function upsertUserFromLineProfile(profile) {
  const { userId, displayName, pictureUrl } = profile;

  // Upsert user
  const r = await pool.query(
    `
    INSERT INTO users (line_user_id, display_name, picture_url, role, customer_status)
    VALUES ($1, $2, $3, 'customer', 'lead')
    ON CONFLICT (line_user_id)
    DO UPDATE SET
      display_name = EXCLUDED.display_name,
      picture_url  = EXCLUDED.picture_url,
      updated_at   = now()
    RETURNING id, role, customer_status, display_name, picture_url, customer_code;
    `,
    [userId, displayName || null, pictureUrl || null]
  );

  let user = r.rows[0];

  // Ensure customer_code exists (covers old users + first login)
  if (!user.customer_code) {
    const code = "CUS-" + String(user.id).padStart(6, "0");
    const u2 = await pool.query(
      `
      UPDATE users
      SET customer_code = $2
      WHERE id = $1 AND customer_code IS NULL
      RETURNING id, role, customer_status, display_name, picture_url, customer_code;
      `,
      [user.id, code]
    );
    if (u2.rows[0]) user = u2.rows[0];
  }

  return user;
}

async function isProfileComplete(userId) {
  const r = await pool.query(
    `SELECT
       COALESCE(full_name,'') <> '' AS full_name_ok,
       COALESCE(phone,'') <> '' AS phone_ok,
       COALESCE(ship_street,'') <> '' AS ship_street_ok,
       COALESCE(ship_city,'') <> '' AS ship_city_ok,
       COALESCE(ship_province,'') <> '' AS ship_province_ok,
       COALESCE(ship_postal_code,'') <> '' AS ship_postal_ok
     FROM customer_profiles
     WHERE user_id = $1`,
    [userId]
  );

  if (!r.rows.length) return false;
  const row = r.rows[0];
  return (
    row.full_name_ok &&
    row.phone_ok &&
    row.ship_street_ok &&
    row.ship_city_ok &&
    row.ship_province_ok &&
    row.ship_postal_ok
  );
}

/* ================= ROUTES ================= */
app.get("/health", async (_req, res) => {
  try {
    await pool.query("SELECT 1");
    res.json({ ok: true });
  } catch {
    res.status(500).json({ ok: false });
  }
});

/* ================= LINE AUTH ================= */
app.get("/auth/line/login", (req, res) => {
  const state = randState();
  req.session.lineState = state;

  const redirectUri = `${APP_BASE_URL}/auth/line/callback`;

  const url = new URL("https://access.line.me/oauth2/v2.1/authorize");
  url.searchParams.set("response_type", "code");
  url.searchParams.set("client_id", LINE_CHANNEL_ID);
  url.searchParams.set("redirect_uri", redirectUri);
  url.searchParams.set("state", state);
  url.searchParams.set("scope", "profile openid");

  res.redirect(url.toString());
});

app.get("/auth/line/callback", async (req, res) => {
  try {
    const { code, state } = req.query;

    if (!code || !state || state !== req.session.lineState) {
      return res.status(400).send("Invalid state.");
    }

    const tokenRes = await fetch("https://api.line.me/oauth2/v2.1/token", {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams({
        grant_type: "authorization_code",
        code: String(code),
        redirect_uri: `${APP_BASE_URL}/auth/line/callback`,
        client_id: LINE_CHANNEL_ID,
        client_secret: LINE_CHANNEL_SECRET,
      }),
    });

    if (!tokenRes.ok) {
      const errText = await tokenRes.text();
      console.error("Token exchange failed:", errText);
      return res.status(500).send(errText);
    }

    const tokenJson = await tokenRes.json();

    const profileRes = await fetch("https://api.line.me/v2/profile", {
      headers: { Authorization: `Bearer ${tokenJson.access_token}` },
    });

    if (!profileRes.ok) {
      const errText = await profileRes.text();
      console.error("Profile fetch failed:", errText);
      return res.status(500).send(errText);
    }

    const profile = await profileRes.json();
    const dbUser = await upsertUserFromLineProfile(profile);

    req.session.user = {
      id: dbUser.id,
      role: dbUser.role,
      customer_status: dbUser.customer_status,
      customer_code: dbUser.customer_code,
      lineUserId: profile.userId,
      display_name: dbUser.display_name,
      picture_url: dbUser.picture_url,
    };

    delete req.session.lineState;

    // ✅ always /app/
    return req.session.save(() => res.redirect(AFTER_LOGIN_PATH));
  } catch (err) {
    console.error("CALLBACK ERROR:", err);
    return res.status(500).send("Internal error during login.");
  }
});

app.get("/auth/check", (req, res) => {
  if (req.session?.user?.id) return res.sendStatus(200);
  return res.sendStatus(401);
});

app.post("/auth/logout", (req, res) => {
  req.session.destroy(() => res.json({ ok: true }));
});

/* ================= USER API ================= */
app.get("/api/me", requireAuth, async (req, res) => {
  const r = await pool.query(
    `SELECT id, customer_code, display_name, picture_url, role, customer_status
     FROM users WHERE id = $1`,
    [req.session.user.id]
  );
  if (!r.rows.length) return res.status(401).json({ ok: false });
  res.json({ ok: true, user: r.rows[0] });
});

/* ================= NOTIFICATIONS (BELL) ================= */
app.get("/api/notifications/unread-count", requireAuth, async (req, res) => {
  try {
    const q = `
      SELECT count(*)::int AS count
      FROM order_activity a
      JOIN orders o ON o.id = a.order_id
      JOIN users u ON u.id = $1
      WHERE o.user_id = $1
        AND a.created_at > u.last_seen_activity_at
        AND a.actor_role <> 'customer'
    `;
    const r = await pool.query(q, [req.session.user.id]);
    res.json({ ok: true, count: r.rows[0]?.count ?? 0 });
  } catch (e) {
    console.error("GET /api/notifications/unread-count error:", e);
    res.status(500).json({ ok: false });
  }
});

app.post("/api/notifications/mark-read", requireAuth, async (req, res) => {
  try {
    await pool.query(`UPDATE users SET last_seen_activity_at = now() WHERE id = $1`, [req.session.user.id]);
    res.json({ ok: true });
  } catch (e) {
    console.error("POST /api/notifications/mark-read error:", e);
    res.status(500).json({ ok: false });
  }
});

app.get("/api/notifications/recent", requireAuth, async (req, res) => {
  try {
    const q = `
      SELECT a.id, a.kind, a.message, a.status_from, a.status_to, a.created_at,
             o.job_no, o.project_name
      FROM order_activity a
      JOIN orders o ON o.id = a.order_id
      WHERE o.user_id = $1
        AND a.actor_role <> 'customer'
      ORDER BY a.created_at DESC
      LIMIT 10
    `;
    const r = await pool.query(q, [req.session.user.id]);
    res.json({ ok: true, items: r.rows });
  } catch (e) {
    console.error("GET /api/notifications/recent error:", e);
    res.status(500).json({ ok: false });
  }
});

/* ================= CUSTOMER PROFILE APIs ================= */
app.get("/api/customer/profile/status", requireAuth, async (req, res) => {
  const complete = await isProfileComplete(req.session.user.id);
  res.json({ ok: true, complete });
});

app.get("/api/customer/profile", requireAuth, async (req, res) => {
  const r = await pool.query(`SELECT * FROM customer_profiles WHERE user_id = $1`, [req.session.user.id]);
  res.json({ ok: true, profile: r.rows[0] || null });
});

app.post("/api/customer/profile", requireAuth, async (req, res) => {
  const p = req.body || {};

  const payload = {
    full_name: (p.full_name || "").trim(),
    email: (p.email || "").trim(),
    phone: (p.phone || "").trim(),

    ship_street: (p.ship_street || "").trim(),
    ship_city: (p.ship_city || "").trim(),
    ship_province: (p.ship_province || "").trim(),
    ship_postal_code: (p.ship_postal_code || "").trim(),
    ship_recipient_phone: (p.ship_recipient_phone || "").trim(),

    bill_same_as_ship: p.bill_same_as_ship !== false,

    bill_street: (p.bill_street || "").trim(),
    bill_city: (p.bill_city || "").trim(),
    bill_province: (p.bill_province || "").trim(),
    bill_postal_code: (p.bill_postal_code || "").trim(),
  };

  if (payload.bill_same_as_ship) {
    payload.bill_street = "";
    payload.bill_city = "";
    payload.bill_province = "";
    payload.bill_postal_code = "";
  }

  await pool.query(
    `INSERT INTO customer_profiles (
       user_id, full_name, email, phone,
       ship_street, ship_city, ship_province, ship_postal_code, ship_recipient_phone,
       bill_same_as_ship, bill_street, bill_city, bill_province, bill_postal_code
     )
     VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14)
     ON CONFLICT (user_id) DO UPDATE SET
       full_name=EXCLUDED.full_name,
       email=EXCLUDED.email,
       phone=EXCLUDED.phone,
       ship_street=EXCLUDED.ship_street,
       ship_city=EXCLUDED.ship_city,
       ship_province=EXCLUDED.ship_province,
       ship_postal_code=EXCLUDED.ship_postal_code,
       ship_recipient_phone=EXCLUDED.ship_recipient_phone,
       bill_same_as_ship=EXCLUDED.bill_same_as_ship,
       bill_street=EXCLUDED.bill_street,
       bill_city=EXCLUDED.bill_city,
       bill_province=EXCLUDED.bill_province,
       bill_postal_code=EXCLUDED.bill_postal_code,
       updated_at=now()`,
    [
      req.session.user.id,
      payload.full_name,
      payload.email,
      payload.phone,
      payload.ship_street,
      payload.ship_city,
      payload.ship_province,
      payload.ship_postal_code,
      payload.ship_recipient_phone,
      payload.bill_same_as_ship,
      payload.bill_street,
      payload.bill_city,
      payload.bill_province,
      payload.bill_postal_code,
    ]
  );

  res.json({ ok: true });
});

/* ================= ORDERS APIs ================= */

// ✅ Customer cannot create orders anymore
app.post("/api/orders", requireAuth, async (_req, res) => {
  return res.status(403).json({ ok: false, error: "customers_cannot_create_orders" });
});

// List my orders
app.get("/api/orders", requireAuth, async (req, res) => {
  const r = await pool.query(
    `SELECT id, job_no, project_name, job_type, status, created_at, required_completion_date,
            installation_required, delivery_only, urgent_production, is_locked
     FROM orders
     WHERE user_id = $1
     ORDER BY id DESC`,
    [req.session.user.id]
  );
  res.json({ ok: true, orders: r.rows });
});

// Order details
app.get("/api/orders/:id", requireAuth, async (req, res) => {
  const id = Number(req.params.id);
  if (!Number.isFinite(id)) return res.status(400).json({ ok: false });

  const r = await pool.query(
    `SELECT id, job_no, project_name, job_type, description, status, created_at, required_completion_date,
            installation_required, delivery_only, urgent_production, is_locked, location_url
     FROM orders
     WHERE id = $1 AND user_id = $2`,
    [id, req.session.user.id]
  );

  if (!r.rows.length) return res.status(404).json({ ok: false });
  res.json({ ok: true, order: r.rows[0] });
});

// admin customer search
app.get("/api/admin/customers", async (req, res) => {
  try {
    const q = String(req.query.q || "").trim().toLowerCase();
    const limit = Math.min(Number(req.query.limit || 20), 50);

    const r = await pool.query(
      `
      SELECT id, customer_code, display_name, picture_url, updated_at
      FROM users
      WHERE role = 'customer'
        AND (
          $1 = '' OR
          LOWER(display_name) LIKE $2 OR
          LOWER(customer_code) LIKE $2
        )
      ORDER BY updated_at DESC NULLS LAST, id DESC
      LIMIT $3
      `,
      [q, `%${q}%`, limit]
    );

    res.json({ ok: true, customers: r.rows });
  } catch (e) {
    res.status(500).json({ ok: false, message: String(e?.message || e) });
  }
});

// Admin Dashboard Preview (Latest Jobs)
app.get("/api/admin/orders/recent", async (req, res) => {
  try {
    const limit = Math.min(Number(req.query.limit || 10), 50);

    const colRes = await pool.query(`
      SELECT column_name
      FROM information_schema.columns
      WHERE table_schema='public'
      AND table_name='orders'
    `);

    const cols = new Set(colRes.rows.map(r => r.column_name));
    const selectParts = ["o.id"];

    if (cols.has("job_no")) selectParts.push("o.job_no");
    if (cols.has("job_number")) selectParts.push("o.job_number");
    if (cols.has("order_no")) selectParts.push("o.order_no");

    if (cols.has("job_type")) selectParts.push("o.job_type");
    if (cols.has("type")) selectParts.push("o.type");

    if (cols.has("title")) selectParts.push("o.title");
    if (cols.has("name")) selectParts.push("o.name");

    if (cols.has("status")) selectParts.push("o.status");
    if (cols.has("due_date")) selectParts.push("o.due_date");
    if (cols.has("updated_at")) selectParts.push("o.updated_at");
    if (cols.has("created_at")) selectParts.push("o.created_at");

    if (cols.has("customer_id")) selectParts.push("o.customer_id");

    const joinUsers = cols.has("customer_id")
      ? "LEFT JOIN users u ON u.id = o.customer_id"
      : "LEFT JOIN users u ON 1=0";

    const orderBy = cols.has("updated_at")
      ? "o.updated_at DESC"
      : cols.has("created_at")
      ? "o.created_at DESC"
      : "o.id DESC";

    const sql = `
      SELECT
        ${selectParts.join(", ")},
        u.customer_code,
        u.display_name AS customer_name
      FROM orders o
      ${joinUsers}
      ORDER BY ${orderBy}
      LIMIT $1
    `;

    const r = await pool.query(sql, [limit]);

    res.json({ ok: true, jobs: r.rows });
  } catch (e) {
    console.error("Recent jobs error:", e);
    res.status(500).json({ ok: false, message: String(e?.message || e) });
  }
});

/* ================= ORDER COMMENTS (existing) ================= */

app.get("/api/orders/:id/comments", requireAuth, async (req, res) => {
  try {
    const orderId = Number(req.params.id);
    if (!Number.isFinite(orderId)) return res.status(400).json({ ok: false });

    const okOwner = await assertOrderBelongsToUser(orderId, req.session.user.id);
    if (!okOwner) return res.sendStatus(404);

    const r = await pool.query(
      `
      SELECT c.id, c.body, c.created_at,
             u.display_name, u.picture_url
      FROM order_comments c
      JOIN users u ON u.id = c.user_id
      WHERE c.order_id = $1
      ORDER BY c.created_at ASC
      `,
      [orderId]
    );

    res.json({ ok: true, comments: r.rows });
  } catch (e) {
    console.error("GET /api/orders/:id/comments error:", e);
    res.status(500).json({ ok: false });
  }
});

app.post("/api/orders/:id/comments", requireAuth, async (req, res) => {
  try {
    const orderId = Number(req.params.id);
    if (!Number.isFinite(orderId)) return res.status(400).json({ ok: false });

    const okOwner = await assertOrderBelongsToUser(orderId, req.session.user.id);
    if (!okOwner) return res.sendStatus(404);

    const body = String(req.body?.body || "").trim();
    if (!body) return res.status(400).json({ ok: false, error: "empty" });
    if (body.length > 2000) return res.status(400).json({ ok: false, error: "too_long" });

    const r = await pool.query(
      `
      INSERT INTO order_comments (order_id, user_id, body)
      VALUES ($1, $2, $3)
      RETURNING id, body, created_at
      `,
      [orderId, req.session.user.id, body]
    );

    try {
      await pool.query(
        `
        INSERT INTO order_activity (order_id, kind, actor_role, message)
        VALUES ($1, 'comment', 'customer', $2)
        `,
        [orderId, body]
      );
    } catch (e2) {
      console.warn("order_activity insert skipped:", e2?.message || e2);
    }

    res.json({ ok: true, comment: r.rows[0] });
  } catch (e) {
    console.error("POST /api/orders/:id/comments error:", e);
    res.status(500).json({ ok: false });
  }
});

/* ================= NEW JOB APIs (shared job details + internal memo) ================= */
app.use(jobsRoute);

/* ================= START ================= */
app.listen(Number(PORT), () => console.log(`oms_auth on :${PORT}`));