#!/usr/bin/env bash
set -euo pipefail

ROOT="$(pwd)"
PUB="$ROOT/public"
JS="$PUB/js"
mkdir -p "$JS"

# -----------------------------
# Shared JS for dashboard menus
# -----------------------------
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

  // ====== Role protection (ensure correct menu file) ======
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

  // ====== Header fill ======
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

  // ====== Actions mapping (per-page config) ======
  // Each menu page can set window.ADMIN_MENU_ACTIONS = { ... }
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

  if (actions.addressInfoUrl) bindCard("actAddress", () => location.href = actions.addressInfoUrl);
  if (actions.ordersUrl) bindCard("actOrders", () => location.href = actions.ordersUrl);
  if (actions.approvalsUrl) bindCard("actApprovals", () => location.href = actions.approvalsUrl);
  if (actions.createUrl) {
    const plus = document.getElementById("ordersPlus");
    if (plus) {
      plus.style.display = "inline-flex";
      plus.addEventListener("click", (e) => { e.stopPropagation(); location.href = actions.createUrl; });
    }
  }

  // ====== Active Projects (demo for now) ======
  // Later replace with ClickUp list or /admin/api/orders etc.
  const listWrap = document.getElementById("activeList");
  const emptyWrap = document.getElementById("activeEmpty");
  const container = document.getElementById("activeProjectsContainer");

  const demoProjects = (window.ADMIN_DEMO_PROJECTS || [
    { job_no: "D00001", project_name: "banner1", job_type: "Backdrop", status: "pending_admin" },
    { job_no: "S0009", project_name: "banner", job_type: "Signage", status: "pending_admin" },
  ]);

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

  function statusStepIndex(s) {
    if (s === "pending_admin") return 0;
    if (s === "in_design") return 1;
    if (s === "in_production") return 2;
    if (s === "shipped") return 3;
    if (s === "completed") return 4;
    return 0;
  }

  function renderTimeline(status) {
    const idx = statusStepIndex(status);
    const labels = ["Order", "Design", "Process", "Shipped", "Delivered"];

    const dots = labels.map((_, i) => {
      if (i < idx) return `<div class="dotMini done"></div>`;
      if (i === idx) return `<div class="dotMini on"></div>`;
      return `<div class="dotMini"></div>`;
    }).join("");

    const steps = labels.map(l => `<div class="tlStep">${l}</div>`).join("");

    return `
      <div class="tl">
        <div class="tlRow">${steps}</div>
        <div class="tlDots">${dots}</div>
      </div>
    `;
  }

  if (container && demoProjects.length) {
    if (emptyWrap) emptyWrap.style.display = "none";
    if (listWrap) listWrap.style.display = "block";

    container.innerHTML = demoProjects.slice(0, 3).map(o => `
      <div class="projectCard">
        <div class="projectTop">
          <div>
            <div class="projectNo">${esc(o.job_no || "")}</div>
            <div class="projectMeta">${esc(o.project_name || "")} • ${esc(o.job_type || "")}</div>
          </div>
          <div class="badgePill">${esc(prettyStatus(o.status))}</div>
        </div>
        ${renderTimeline(o.status)}
      </div>
    `).join("");
  } else {
    if (emptyWrap) emptyWrap.style.display = "flex";
    if (listWrap) listWrap.style.display = "none";
  }

  // ====== Logout buttons ======
  async function logout() {
    await fetch(API_BASE + "/auth/logout", { method: "POST", credentials: "include" }).catch(() => {});
    sessionStorage.removeItem("accessToken");
    location.href = "/admin/login.html";
  }

  const logoutBtn = document.getElementById("logoutBtn");
  if (logoutBtn) logoutBtn.addEventListener("click", logout);

  // Bell click (placeholder)
  const bell = document.getElementById("bell");
  if (bell) bell.addEventListener("click", () => alert("Notifications coming soon"));

  function esc(s) {
    return String(s ?? "").replace(/[&<>"']/g, m => ({
      "&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#039;"
    }[m]));
  }
})();
JS

# ---------------------------------------------------
# HTML generator: matches your screenshot layout style
# ---------------------------------------------------
make_page () {
  local file="$1"
  local pageTitle="$2"
  local actionsJS="$3"
  local quickCardsHTML="$4"
  local accountCardExtra="$5"

  cat > "$PUB/$file" <<HTML
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width,initial-scale=1" />
  <title>${pageTitle}</title>
  <link rel="preconnect" href="https://fonts.googleapis.com" />
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin />
  <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&family=Noto+Sans+Thai:wght@400;500;600;700&display=swap" rel="stylesheet" />
  <style>
    :root{
      --bg:#f6f8fb; --card:#fff; --text:#101828; --muted:#667085;
      --primary:#2563eb; --primary2:#1d4ed8; --shadow:0 10px 30px rgba(16,24,40,.08);
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
    .cards{ display:grid; grid-template-columns:1fr 1fr; gap:12px }
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

    .progress{
      background:var(--card);
      border-radius:22px;
      padding:18px;
      box-shadow:0 10px 24px rgba(16,24,40,.06);
      border:1px solid rgba(229,231,235,.7);
    }
    .progressHeader{
      display:flex; justify-content:space-between; align-items:center; margin-bottom:8px;
    }
    .progressHeader h2{ margin:0; font-size:18px }
    .btn{
      display:inline-flex; align-items:center; justify-content:center;
      padding:10px 14px; border-radius:12px;
      border:1px solid #d1d5db; background:#fff; color:var(--primary);
      font-weight:700; font-size:12px; text-decoration:none; cursor:pointer;
    }
    .center{ display:flex; flex-direction:column; align-items:center; text-align:center; gap:10px }
    .box{
      width:44px;height:44px;border-radius:16px;background:#f2f4f7;border:1px solid #e5e7eb;
      display:flex; align-items:center; justify-content:center
    }

    .projectCard{
      background:#fff; border:1px solid rgba(229,231,235,.7);
      border-radius:16px; padding:12px;
      box-shadow:0 10px 24px rgba(16,24,40,.06);
      margin-top:10px;
    }
    .projectTop{ display:flex; justify-content:space-between; gap:10px; align-items:flex-start }
    .projectNo{ font-weight:800 }
    .projectMeta{ font-size:12px; color:var(--muted); margin-top:2px }
    .badgePill{
      font-size:11px; font-weight:800; padding:6px 10px; border-radius:999px;
      background:#fef3c7; color:#92400e; white-space:nowrap;
    }
    .tl{ margin-top:10px }
    .tlRow{ display:flex; justify-content:space-between; gap:6px }
    .tlStep{ flex:1; text-align:center; font-size:10px; color:#98a2b3; font-weight:800 }
    .tlDots{ display:flex; justify-content:space-between; margin-top:6px; position:relative }
    .tlDots::before{
      content:""; position:absolute; left:8px; right:8px; top:50%;
      height:3px; background:#e5e7eb; transform:translateY(-50%); border-radius:99px;
    }
    .dotMini{
      width:14px; height:14px; border-radius:50%;
      background:#e5e7eb; position:relative; z-index:1; border:2px solid #fff;
    }
    .dotMini.on{ background:var(--primary2) }
    .dotMini.done{ background:#22c55e }

    .help{
      margin-top:14px;
      background:linear-gradient(135deg,#111827 0%, #0b1220 100%);
      color:#fff; border-radius:22px; padding:18px; box-shadow:var(--shadow);
      position:relative; overflow:hidden;
    }
    .help h3{ margin:0 0 6px }
    .help p{ margin:0 0 14px; color:rgba(255,255,255,.75); font-size:12px }
    .help .btn2{
      display:inline-flex; padding:10px 16px; border-radius:14px;
      background:rgba(37,99,235,.95); color:#fff; text-decoration:none; font-weight:700; font-size:12px;
    }
    .help::after{
      content:""; position:absolute; right:-30px; bottom:-30px;
      width:140px; height:140px; border-radius:50%; background:rgba(255,255,255,.06);
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
          ${quickCardsHTML}
        </div>

        <div class="section-title">CURRENT PROGRESS</div>
        <div class="progress">
          <div class="center" id="activeEmpty">
            <div class="box">📄</div>
            <h2 style="margin:0;">No Active Projects</h2>
            <p style="margin:0;color:var(--muted);font-size:12px;max-width:260px;">
              Your production progress will appear here once jobs are created.
            </p>
          </div>

          <div id="activeList" style="display:none;">
            <div class="progressHeader">
              <h2>Active Projects</h2>
              <a class="btn" href="${actionsJS%%;*}">View All</a>
            </div>
            <div id="activeProjectsContainer"></div>
          </div>
        </div>

        <div class="help">
          <h3>Need assistance?</h3>
          <p>Your dedicated agent is available 24/7</p>
          <a class="btn2" href="#" onclick="alert('Chat coming soon');return false;">Start Chat</a>
        </div>
      </div>

      <div>
        <div class="section-title">ACCOUNT</div>
        <div class="card">
          <h3>Signed in</h3>
          <p id="me" class="smallMuted">Loading profile…</p>
          <div style="height:10px"></div>
          <button id="logoutBtn" class="btn" type="button">Logout</button>
          ${accountCardExtra}
        </div>
      </div>
    </div>
  </div>

  <script>
    // per page config
    ${actionsJS}
  </script>
  <script src="./js/admin-dashboard.js"></script>
</body>
</html>
HTML
}

# -----------------------------
# Quick cards (re-usable blocks)
# -----------------------------
CARD_APPROVALS='
<div id="actApprovals" class="card clickable">
  <div class="icon">📍</div>
  <h3>Approvals</h3>
  <p>Approvals page</p>
</div>'

CARD_ORDERS='
<div id="actOrders" class="card clickable">
  <div class="cardHead">
    <div class="cardHeadLeft">
      <div class="icon">🚚</div>
      <div>
        <h3 style="margin:0;">Orders</h3>
        <p class="smallMuted" style="margin-top:4px;">Order details</p>
      </div>
    </div>
    <span id="ordersPlus" class="plusBtn" title="Create New">+</span>
  </div>
</div>'

CARD_USERS='
<a class="card" href="/admin/admin-users.html">
  <div class="icon">🛡️</div>
  <h3>Users</h3>
  <p>Manage accounts & roles</p>
</a>'

CARD_SETTINGS='
<div class="card clickable" onclick="alert('Settings coming soon')">
  <div class="icon">⚙️</div>
  <h3>Settings</h3>
  <p>System settings</p>
</div>'

# -----------------------------
# Pages
# -----------------------------
# Owner: approvals + orders + users + settings
make_page \
  "menu-owner.html" \
  "Owner Dashboard" \
  'window.ADMIN_MENU_ACTIONS = {
     approvalsUrl: "/admin/app.html",
     ordersUrl: "/admin/app.html",
     createUrl: "/admin/admin-job-create.html",
     addressInfoUrl: "/admin/admin-users.html"
   };' \
  "${CARD_APPROVALS}${CARD_ORDERS}" \
  '<div style="height:10px"></div><a class="btn" href="/admin/admin-users.html">User Management</a>'

# Admin: approvals + orders (+ create)
make_page \
  "menu-admin.html" \
  "Admin Dashboard" \
  'window.ADMIN_MENU_ACTIONS = {
     approvalsUrl: "/admin/app.html",
     ordersUrl: "/admin/app.html",
     createUrl: "/admin/admin-job-create.html"
   };' \
  "${CARD_APPROVALS}${CARD_ORDERS}" \
  ""

# Supervisor: approvals + orders (+ create)
make_page \
  "menu-supervisor.html" \
  "Supervisor Dashboard" \
  'window.ADMIN_MENU_ACTIONS = {
     approvalsUrl: "/admin/app.html",
     ordersUrl: "/admin/app.html",
     createUrl: "/admin/admin-job-create.html"
   };' \
  "${CARD_APPROVALS}${CARD_ORDERS}" \
  ""

# Graphic: approvals + orders (no create)
make_page \
  "menu-graphic.html" \
  "Graphic Dashboard" \
  'window.ADMIN_MENU_ACTIONS = {
     approvalsUrl: "/admin/app.html",
     ordersUrl: "/admin/app.html"
   };' \
  "${CARD_APPROVALS}${CARD_ORDERS}" \
  ""

# Print: approvals + orders (no create)
make_page \
  "menu-print.html" \
  "Print Dashboard" \
  'window.ADMIN_MENU_ACTIONS = {
     approvalsUrl: "/admin/app.html",
     ordersUrl: "/admin/app.html"
   };' \
  "${CARD_APPROVALS}${CARD_ORDERS}" \
  ""

# Install: approvals + orders (no create)
make_page \
  "menu-install.html" \
  "Install Dashboard" \
  'window.ADMIN_MENU_ACTIONS = {
     approvalsUrl: "/admin/app.html",
     ordersUrl: "/admin/app.html"
   };' \
  "${CARD_APPROVALS}${CARD_ORDERS}" \
  ""

echo "✅ Updated menu pages created (screenshot-matching layout)."
echo "Next: rebuild so docker image includes them:"
echo "  docker compose down && docker compose up -d --build"
