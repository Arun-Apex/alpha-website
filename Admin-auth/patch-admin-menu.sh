#!/usr/bin/env bash
set -euo pipefail

PUB="$(pwd)/public"
JS="$(pwd)/public/js"
mkdir -p "$JS"

# -------------------------
# 1) Update admin-dashboard.js
#    - add Recent Jobs renderer
# -------------------------
cat > "$JS/admin-dashboard.js" <<'JS'
(async function () {
  const API_BASE = "/admin/api";

  const accessToken = sessionStorage.getItem("accessToken");
  if (!accessToken) {
    location.href = "/admin/login.html";
    return;
  }

  async function api(path, opts = {}) {
    const res = await fetch(path, {
      ...opts,
      headers: {
        "Content-Type": "application/json",
        ...(opts.headers || {}),
        Authorization: "Bearer " + (sessionStorage.getItem("accessToken") || "")
      },
      credentials: "include"
    });

    if (res.status === 401) {
      const r = await fetch(API_BASE + "/auth/refresh", { method: "POST", credentials: "include" });
      if (r.ok) {
        const j = await r.json();
        sessionStorage.setItem("accessToken", j.accessToken);
        return api(path, opts);
      }
      sessionStorage.removeItem("accessToken");
      location.href = "/admin/login.html";
      return null;
    }

    return res.json().catch(() => null);
  }

  const me = await api(API_BASE + "/me");
  if (!me?.user) {
    sessionStorage.removeItem("accessToken");
    location.href = "/admin/login.html";
    return;
  }

  const user = me.user;
  const group = me.group;

  // ===== Role protection =====
  const currentPage = location.pathname.split("/").pop();

  let expectedPage = "";
  if (user.systemRole === "owner" || user.systemRole === "superadmin") {
    expectedPage = "menu-owner.html";
  } else {
    expectedPage = `menu-${user.groupKey}.html`;
  }

  if (currentPage && expectedPage && currentPage !== expectedPage) {
    location.href = "/admin/" + expectedPage;
    return;
  }

  // ===== Header fill =====
  const name = user.displayName || user.username || "User";
  const roleEn = group?.name?.en || group?.key || user.groupKey || "User";
  const roleTh = group?.name?.th || user.groupKey || "ผู้ใช้";

  const userNameEl = document.getElementById("userName");
  const meEl = document.getElementById("me");
  const rolePillEl = document.getElementById("rolePill");
  const idPillEl = document.getElementById("idPill");

  if (userNameEl) userNameEl.textContent = name;
  if (meEl) meEl.textContent = user.username || "-";
  if (rolePillEl) rolePillEl.textContent = `${roleTh} / ${roleEn}`;
  if (idPillEl) idPillEl.textContent = `ID: ${user.id}`;

  // ===== Actions mapping =====
  const actions = window.ADMIN_MENU_ACTIONS || {};

  function bindCard(id, handler) {
    const el = document.getElementById(id);
    if (!el) return;
    el.style.cursor = "pointer";
    el.addEventListener("click", handler);
    el.addEventListener("keydown", (e) => {
      if (e.key === "Enter" || e.key === " ") { e.preventDefault(); handler(); }
    });
    el.setAttribute("tabindex", "0");
    el.setAttribute("role", "button");
  }

  if (actions.ordersUrl) bindCard("actOrders", () => location.href = actions.ordersUrl);
  if (actions.approvalsUrl) bindCard("actApprovals", () => location.href = actions.approvalsUrl);
  if (actions.manageJobsUrl) bindCard("actManageJobs", () => location.href = actions.manageJobsUrl);
  if (actions.recentUrl) bindCard("actRecent", () => location.href = actions.recentUrl);

  // Orders + plus button
  if (actions.createUrl) {
    const plus = document.getElementById("ordersPlus");
    if (plus) {
      plus.style.display = "inline-flex";
      plus.addEventListener("click", (e) => {
        e.stopPropagation();
        location.href = actions.createUrl;
      });
    }
  }

  // ===== Demo jobs (until ClickUp/orders API) =====
  // You can override per page with window.ADMIN_DEMO_PROJECTS
  const demoProjects = (window.ADMIN_DEMO_PROJECTS || [
    { job_no: "D00001", project_name: "banner1", job_type: "Backdrop", status: "pending_admin" },
    { job_no: "S0009", project_name: "banner", job_type: "Signage", status: "pending_admin" },
    { job_no: "D23568", project_name: "jobD", job_type: "Signage", status: "in_design" },
  ]);

  // ===== Recent jobs list card renderer =====
  const recentList = document.getElementById("recentList");
  if (recentList) {
    const items = demoProjects.slice(0, 4);
    recentList.innerHTML = items.map(x => `
      <div class="recentRow">
        <div class="recentLeft">
          <div class="recentNo">${esc(x.job_no || "")}</div>
          <div class="recentMeta">${esc(x.project_name || "")} • ${esc(x.job_type || "")}</div>
        </div>
        <div class="recentBadge">${esc(prettyStatus(x.status))}</div>
      </div>
    `).join("") || `<div class="smallMuted">No recent jobs</div>`;
  }

  function prettyStatus(s) {
    const map = {
      pending_admin: "PENDING ADMIN",
      in_design: "IN DESIGN",
      in_production: "IN PRODUCTION",
      shipped: "SHIPPED",
      completed: "COMPLETED",
      cancelled: "CANCELLED",
    };
    return map[s] || (s || "").toUpperCase();
  }

  // ===== Logout =====
  async function logout() {
    await fetch(API_BASE + "/auth/logout", { method: "POST", credentials: "include" }).catch(() => {});
    sessionStorage.removeItem("accessToken");
    location.href = "/admin/login.html";
  }

  const logoutBtn = document.getElementById("logoutBtn");
  if (logoutBtn) logoutBtn.addEventListener("click", logout);

  const bell = document.getElementById("bell");
  if (bell) bell.addEventListener("click", () => alert("Notifications coming soon"));

  function esc(s) {
    return String(s ?? "").replace(/[&<>"']/g, m => ({
      "&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#039;"
    }[m]));
  }
})();
JS

# -------------------------
# 2) Overwrite menu-admin.html
# -------------------------
cat > "$PUB/menu-admin.html" <<'HTML'
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width,initial-scale=1" />
  <title>Admin Dashboard</title>

  <link rel="preconnect" href="https://fonts.googleapis.com" />
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin />
  <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&family=Noto+Sans+Thai:wght@400;500;600;700&display=swap" rel="stylesheet" />

  <style>
    :root{
      --bg:#f6f8fb; --card:#fff; --text:#101828; --muted:#667085;
      --primary:#2563eb; --shadow:0 10px 30px rgba(16,24,40,.08);
    }
    *{ box-sizing:border-box }
    body{
      margin:0;
      font-family: Inter, "Noto Sans Thai", system-ui, -apple-system, Segoe UI, Roboto, Arial;
      background:var(--bg); color:var(--text)
    }
    a{ color:inherit; text-decoration:none }
    .wrap{ max-width:1100px; margin:0 auto; padding:16px 16px 40px }
    .layout{ display:block }

    .hero{
      background:
        radial-gradient(1200px 500px at 10% 0%, #dbeafe 0%, rgba(219,234,254,0) 60%),
        linear-gradient(135deg, #e9d5ff 0%, #dbeafe 45%, #c7f9f1 100%);
      border-radius:26px; padding:18px 16px; box-shadow:var(--shadow);
      position:relative; overflow:hidden;
    }
    .hero-top{ display:flex; align-items:center; gap:12px }
    .logo{
      width:38px; height:38px; border-radius:12px; background:#fff;
      display:flex; align-items:center; justify-content:center;
      box-shadow:0 6px 18px rgba(0,0,0,.08); font-weight:800; color:#111;
    }
    .brand{ font-weight:700 }
    .bell{
      margin-left:auto; width:34px; height:34px; border-radius:12px;
      background:rgba(255,255,255,.7); display:flex; align-items:center; justify-content:center;
      cursor:pointer;
    }
    .hello-card{ display:flex; gap:12px; align-items:center; margin-top:16px }
    .hello-avatar{
      width:56px;height:56px;border-radius:50%;
      background:rgba(255,255,255,.7);
      border:1px solid rgba(255,255,255,.75);
      display:flex; align-items:center; justify-content:center;
      font-weight:800;
    }
    .hello-text h2{ font-size:22px; margin:0 }
    .hello-text p{ margin:2px 0 0; color:rgba(16,24,40,.7); font-size:13px }
    .pillRow{ margin-top:10px; display:flex; gap:8px; flex-wrap:wrap }
    .pill{
      font-size:12px; font-weight:700; padding:6px 10px; border-radius:999px;
      background:rgba(255,255,255,.75); border:1px solid rgba(229,231,235,.9);
      color:#111;
    }

    .section-title{
      margin:18px 4px 10px; font-size:11px; letter-spacing:.12em;
      color:#98a2b3; font-weight:700;
    }

    .cards{
      display:grid;
      grid-template-columns:1fr 1fr;
      gap:12px;
    }

    .card{
      background:var(--card);
      border-radius:18px;
      padding:14px;
      box-shadow:0 10px 24px rgba(16,24,40,.06);
      border:1px solid rgba(229,231,235,.7);
    }
    .card h3{ margin:10px 0 4px; font-size:14px }
    .card p{ margin:0; color:var(--muted); font-size:12px; line-height:1.4 }
    .clickable{ cursor:pointer }
    .clickable:hover{ transform:translateY(-1px); transition:.12s ease; box-shadow:0 14px 28px rgba(16,24,40,.08) }

    .icon{
      width:34px;height:34px;border-radius:12px;
      display:flex; align-items:center; justify-content:center;
      background:#f2f4f7; border:1px solid #e5e7eb;
    }

    .cardHead{ display:flex; align-items:flex-start; justify-content:space-between; gap:10px }
    .cardHeadLeft{ display:flex; align-items:flex-start; gap:10px }

    .smallMuted{ color:#98a2b3; font-size:12px }

    .plusBtn{
      width:30px;height:30px;border-radius:10px;
      display:none; align-items:center; justify-content:center;
      background:#f2f4f7; border:1px solid #e5e7eb;
      color:#111; text-decoration:none; font-weight:900; cursor:pointer; flex:0 0 auto;
    }
    .plusBtn:hover{ background:#e9edf5 }

    /* Recent jobs list inside card */
    .recentList{ margin-top:10px; display:flex; flex-direction:column; gap:8px }
    .recentRow{
      display:flex; align-items:flex-start; justify-content:space-between; gap:10px;
      padding:10px;
      border-radius:14px;
      border:1px solid rgba(229,231,235,.75);
      background:#fff;
    }
    .recentNo{ font-weight:800; font-size:13px }
    .recentMeta{ font-size:12px; color:var(--muted); margin-top:2px }
    .recentBadge{
      font-size:11px; font-weight:800; padding:6px 10px; border-radius:999px;
      background:#eef2ff; color:#1e40af; white-space:nowrap;
      border:1px solid rgba(37,99,235,.15);
    }

    .account{
      background:var(--card);
      border-radius:18px;
      padding:14px;
      box-shadow:0 10px 24px rgba(16,24,40,.06);
      border:1px solid rgba(229,231,235,.7);
    }
    .btn{
      display:inline-flex; align-items:center; justify-content:center;
      padding:10px 14px; border-radius:12px;
      border:1px solid #d1d5db; background:#fff; color:var(--primary);
      font-weight:700; font-size:12px; text-decoration:none; cursor:pointer;
    }

    @media (min-width:900px){
      .wrap{ padding:26px 18px 26px }
      .layout{ display:grid; grid-template-columns:1.3fr .9fr; gap:18px }
      .hero{ padding:22px }
      .hello-text h2{ font-size:26px }
    }
  </style>
</head>

<body>
  <div class="wrap">
    <div class="layout">
      <div>
        <div class="hero">
          <div class="hero-top">
            <div class="logo">O</div>
            <div class="brand">Octopus Media</div>
            <div class="bell" id="bell" title="Notifications">🔔</div>
          </div>

          <div class="hello-card">
            <div class="hello-avatar">O</div>
            <div class="hello-text">
              <h2>Hello <span id="userName">...</span></h2>
              <p>Let's get you started.</p>
              <div class="pillRow">
                <span class="pill" id="rolePill">-</span>
                <span class="pill" id="idPill">ID: -</span>
              </div>
            </div>
          </div>
        </div>

        <div class="section-title">QUICK ACTIONS</div>
        <div class="cards">
          <!-- Approvals -->
          <div id="actApprovals" class="card clickable">
            <div class="icon">✅</div>
            <h3>Approvals</h3>
            <p>Approvals queue and requests</p>
          </div>

          <!-- Orders (+ create) -->
          <div id="actOrders" class="card clickable">
            <div class="cardHead">
              <div class="cardHeadLeft">
                <div class="icon">🚚</div>
                <div>
                  <h3 style="margin:0;">Orders</h3>
                  <p class="smallMuted" style="margin-top:4px;">Open orders and progress</p>
                </div>
              </div>
              <span id="ordersPlus" class="plusBtn" title="Create New Job">+</span>
            </div>
          </div>

          <!-- Job management -->
          <div id="actManageJobs" class="card clickable">
            <div class="icon">🗂️</div>
            <h3>Manage Jobs</h3>
            <p>Edit stages, status and assignments</p>
          </div>

          <!-- Recent jobs list card -->
          <div id="actRecent" class="card clickable">
            <div class="icon">🕘</div>
            <div class="cardHead" style="margin-top:-34px; padding-left:46px;">
              <div>
                <h3 style="margin:0;">Recent Jobs</h3>
                <p class="smallMuted" style="margin-top:4px;">Quick open recent jobs</p>
              </div>
            </div>
            <div class="recentList" id="recentList"></div>
          </div>
        </div>

        <div style="margin-top:18px;color:#98a2b3;font-size:12px;text-align:center;">
          OCTOPUS PRODUCTION SYSTEM V1.0
        </div>
      </div>

      <div>
        <div class="section-title">ACCOUNT</div>
        <div class="account">
          <h3 style="margin:0 0 6px;">Signed in</h3>
          <p id="me" class="smallMuted" style="margin:0;">Loading profile…</p>
          <div style="height:10px"></div>
          <button id="logoutBtn" class="btn" type="button">Logout</button>
        </div>
      </div>
    </div>
  </div>

  <script>
    // per page config
    window.ADMIN_MENU_ACTIONS = {
      approvalsUrl: "/admin/app.html",
      ordersUrl: "/admin/app.html",
      recentUrl: "/admin/app.html",
      manageJobsUrl: "/admin/app.html",
      createUrl: "/admin/admin-job-create.html"
    };
  </script>

  <script src="./js/admin-dashboard.js"></script>
</body>
</html>
HTML

echo "✅ Patched menu-admin.html and js/admin-dashboard.js"
echo "Now rebuild docker:"
echo "  docker compose down && docker compose up -d --build"
