#!/usr/bin/env bash
set -euo pipefail

ROOT="$(pwd)"
PUB="$ROOT/public"
CSS="$PUB/css"
JS="$PUB/js"

mkdir -p "$CSS" "$JS"

echo "Creating $CSS/menu.css"
cat > "$CSS/menu.css" <<'CSS'
:root{
  --bg:#f6f8ff;
  --card:#ffffff;
  --text:#0f172a;
  --muted:#64748b;
  --primary:#2f6bff;
  --shadow: 0 14px 40px rgba(15, 23, 42, .10);
  --shadow2: 0 8px 18px rgba(15, 23, 42, .08);
  --radius:22px;
}

*{ box-sizing:border-box; }
html,body{ height:100%; }
body{
  margin:0;
  font-family:"Noto Sans Thai", system-ui, -apple-system, Segoe UI, Roboto, Arial, sans-serif;
  color:var(--text);
  background: radial-gradient(1200px 600px at 15% 10%, rgba(47,107,255,.16), transparent 55%),
              radial-gradient(900px 600px at 85% 90%, rgba(167,139,250,.18), transparent 55%),
              var(--bg);
}

a{ color:inherit; text-decoration:none; }
button{ font-family:inherit; }

.container{
  max-width:420px;
  margin:0 auto;
  padding:18px 16px 92px;
}

.topbar{
  display:flex;
  align-items:center;
  justify-content:space-between;
  gap:10px;
  margin-top:6px;
}

.brand{
  display:flex; align-items:center; gap:10px;
}
.brand .logo{
  width:38px;height:38px;border-radius:12px;
  background:#0f172a;
  display:grid; place-items:center;
  color:#fff; font-weight:800;
  box-shadow: var(--shadow2);
}
.brand .title{
  font-weight:700;
}
.icon-btn{
  width:40px;height:40px;border-radius:14px;
  border:1px solid rgba(15,23,42,.08);
  background:rgba(255,255,255,.7);
  display:grid; place-items:center;
  box-shadow: var(--shadow2);
  cursor:pointer;
}

.heroCard{
  margin-top:14px;
  border-radius:var(--radius);
  background: linear-gradient(135deg, rgba(47,107,255,.12), rgba(34,211,238,.10));
  border:1px solid rgba(15,23,42,.06);
  box-shadow: var(--shadow);
  padding:16px;
  position:relative;
  overflow:hidden;
}
.heroCard:before{
  content:"";
  position:absolute; inset:-80px -80px auto auto;
  width:180px;height:180px;border-radius:999px;
  background:rgba(255,255,255,.55);
  filter: blur(0px);
}
.heroRow{
  display:flex; align-items:center; gap:12px;
}
.avatar{
  width:54px;height:54px;border-radius:18px;
  background:#fff;
  border:1px solid rgba(15,23,42,.08);
  box-shadow: var(--shadow2);
  overflow:hidden;
  flex:0 0 auto;
  display:grid; place-items:center;
  font-weight:800;
  color:var(--primary);
}
.avatar img{ width:100%; height:100%; object-fit:cover; }

.heroText .hello{
  font-size:22px;
  font-weight:800;
  line-height:1.15;
}
.badges{
  display:flex; align-items:center; gap:8px;
  margin-top:8px;
  flex-wrap:wrap;
}
.badge{
  padding:6px 10px;
  border-radius:999px;
  font-size:12px;
  background:rgba(255,255,255,.75);
  border:1px solid rgba(15,23,42,.08);
}
.badge.mono{ font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, "Liberation Mono", monospace; }

.sectionTitle{
  margin:16px 2px 10px;
  font-size:12px;
  font-weight:800;
  letter-spacing:.08em;
  color:#94a3b8;
}

.grid2{
  display:grid;
  grid-template-columns:1fr 1fr;
  gap:12px;
}

.actionCard{
  background:var(--card);
  border-radius:18px;
  border:1px solid rgba(15,23,42,.06);
  box-shadow: var(--shadow2);
  padding:14px;
  min-height:88px;
  position:relative;
  cursor:pointer;
  transition: transform .12s ease;
}
.actionCard:active{ transform: scale(.99); }
.actionIcon{
  width:44px;height:44px;border-radius:14px;
  display:grid; place-items:center;
  background:rgba(47,107,255,.10);
  color:var(--primary);
}
.actionTitle{
  margin-top:10px;
  font-weight:800;
}
.actionSub{
  margin-top:2px;
  font-size:12px;
  color:var(--muted);
}
.plusFab{
  position:absolute;
  top:12px; right:12px;
  width:34px;height:34px;border-radius:14px;
  background:rgba(47,107,255,.10);
  color:var(--primary);
  display:grid; place-items:center;
  border:1px solid rgba(47,107,255,.18);
}

.jobsHeader{
  display:flex; align-items:center; justify-content:space-between;
  margin:14px 2px 8px;
}
.jobsHeader .label{
  font-size:12px;font-weight:800;letter-spacing:.08em;color:#94a3b8;
}
.jobsHeader a{ font-size:12px; color:var(--primary); font-weight:700; }

.jobCard{
  background:var(--card);
  border-radius:22px;
  border:1px solid rgba(15,23,42,.06);
  box-shadow: var(--shadow);
  padding:14px;
}
.jobTop{
  display:flex; align-items:flex-start; justify-content:space-between; gap:10px;
}
.jobMeta{
  font-size:11px;
  font-weight:800;
  letter-spacing:.08em;
  color:#94a3b8;
}
.jobNo{
  font-size:20px;
  font-weight:900;
  margin-top:4px;
}
.pill{
  padding:6px 10px;border-radius:999px;
  font-size:11px;font-weight:800;
  background:rgba(251,191,36,.16);
  color:#92400e;
  border:1px solid rgba(251,191,36,.22);
  white-space:nowrap;
}
.steps{
  margin-top:14px;
  display:flex; align-items:center; gap:8px;
}
.stepDot{
  width:14px;height:14px;border-radius:999px;
  border:2px solid rgba(100,116,139,.25);
  background:#fff;
}
.stepDot.active{
  border-color: rgba(47,107,255,.55);
  background: rgba(47,107,255,.12);
}
.stepLine{
  flex:1; height:4px; border-radius:999px;
  background: rgba(100,116,139,.18);
}
.stepLine.active{ background: rgba(47,107,255,.35); }
.stepLabels{
  margin-top:10px;
  display:flex; justify-content:space-between;
  font-size:11px; color:#94a3b8;
}
.stageTitle{
  margin-top:12px;
  font-weight:900;
}
.stageDesc{
  margin-top:6px;
  font-size:12px;
  color:var(--muted);
  line-height:1.55;
}
.eta{
  margin-top:12px;
  display:flex; align-items:center; gap:10px;
  font-size:12px; color:var(--muted);
}

.navbar{
  position:fixed;
  left:0; right:0; bottom:0;
  padding:10px 12px 14px;
  background: rgba(246,248,255,.78);
  backdrop-filter: blur(14px);
  border-top:1px solid rgba(15,23,42,.06);
}
.navInner{
  max-width:420px;
  margin:0 auto;
  display:flex;
  justify-content:space-around;
  align-items:center;
}
.navItem{
  width:140px;
  display:flex; align-items:center; justify-content:center; gap:8px;
  padding:10px 12px;
  border-radius:18px;
  color:#64748b;
  font-weight:800;
  font-size:12px;
}
.navItem.active{
  color:var(--primary);
  background: rgba(47,107,255,.10);
  border:1px solid rgba(47,107,255,.14);
}
.smallLink{
  font-size:12px;
  color:var(--muted);
  text-align:center;
  margin-top:12px;
}
.smallLink a{ color:var(--primary); font-weight:800; }

.hidden{ display:none !important; }
CSS

echo "Creating $JS/menu-ui.js"
cat > "$JS/menu-ui.js" <<'JS'
// public/js/menu-ui.js
// Modern dashboard menu controller

(async function () {
  const API_BASE = "/admin/api";

  const els = {
    helloName: document.getElementById("helloName"),
    rolePill: document.getElementById("rolePill"),
    userId: document.getElementById("userId"),
    avatarImg: document.getElementById("avatarImg"),
    avatarFallback: document.getElementById("avatarFallback"),
    btnBell: document.getElementById("btnBell"),
    btnLogout: document.getElementById("btnLogout"),

    // actions
    actApprovals: document.getElementById("actApprovals"),
    actOrders: document.getElementById("actOrders"),
    actCreate: document.getElementById("actCreate"),

    // job demo
    jobNo: document.getElementById("jobNo"),
    jobPill: document.getElementById("jobPill"),
    stageTitle: document.getElementById("stageTitle"),
    stageDesc: document.getElementById("stageDesc"),
    etaText: document.getElementById("etaText"),

    // nav
    navHome: document.getElementById("navHome"),
    navOrders: document.getElementById("navOrders"),
    navLogout: document.getElementById("navLogout"),
  };

  function go(url) { location.href = url; }

  const accessToken = sessionStorage.getItem("accessToken");
  if (!accessToken) return go("/admin/login.html");

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
      return go("/admin/login.html");
    }
    return res.json().catch(() => null);
  }

  const me = await api(API_BASE + "/me");
  if (!me?.user) return go("/admin/login.html");

  const user = me.user;
  const group = me.group;

  // page protection
  const currentPage = location.pathname.split("/").pop();
  let expectedPage = "";
  if (user.systemRole === "owner" || user.systemRole === "superadmin") expectedPage = "menu-owner.html";
  else expectedPage = `menu-${user.groupKey}.html`;

  if (currentPage && expectedPage && currentPage !== expectedPage) {
    return go("/admin/" + expectedPage);
  }

  // header
  const name = user.displayName || user.username;
  els.helloName.textContent = name;
  els.rolePill.textContent = (group?.name?.en || group?.key || user.groupKey || "User");
  els.userId.textContent = String(user.id || "");

  // avatar (optional later). For now use first letter.
  if (els.avatarFallback) els.avatarFallback.textContent = (name?.trim()?.[0] || "O").toUpperCase();

  // actions routes (customize as you create pages)
  if (els.actOrders) els.actOrders.addEventListener("click", () => go("/admin/app.html"));

  // approvals placeholder for now
  if (els.actApprovals) els.actApprovals.addEventListener("click", () => alert("Approvals page coming soon"));

  // Create job only for admin/supervisor/owner
  const canCreate = (user.systemRole === "owner" || user.systemRole === "superadmin" || user.groupKey === "admin" || user.groupKey === "supervisor");
  if (els.actCreate) {
    if (!canCreate) els.actCreate.classList.add("hidden");
    else els.actCreate.addEventListener("click", () => go("/admin/admin-job-create.html"));
  }

  // bell placeholder
  if (els.btnBell) els.btnBell.addEventListener("click", () => alert("Notifications coming soon"));

  async function logout() {
    await fetch(API_BASE + "/auth/logout", { method: "POST", credentials: "include" }).catch(() => {});
    sessionStorage.removeItem("accessToken");
    go("/admin/login.html");
  }

  if (els.btnLogout) els.btnLogout.addEventListener("click", logout);
  if (els.navLogout) els.navLogout.addEventListener("click", logout);

  // Demo job card (until ClickUp)
  els.jobNo.textContent = "Job D - 23568";
  els.jobPill.textContent = "IN DESIGN";
  els.stageTitle.textContent = "Current Stage: Design & Artwork Preparation";
  els.stageDesc.textContent = "Our design team is preparing artwork and technical layout for production. You'll be notified once proof is ready for approval.";
  els.etaText.textContent = "Estimated Completion: Oct 24, 2026";

  // nav
  if (els.navHome) els.navHome.classList.add("active");
  if (els.navOrders) els.navOrders.addEventListener("click", () => go("/admin/app.html"));

})();
JS

make_page () {
  local file="$1"
  local menuTitle="$2"
  local showCreate="$3"   # "yes" or "no"
  local showUserMgmt="$4" # "yes" or "no"

  echo "Creating $PUB/$file"
  cat > "$PUB/$file" <<HTML
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width,initial-scale=1" />
  <title>${menuTitle}</title>
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=Noto+Sans+Thai:wght@400;500;600;700&display=swap" rel="stylesheet">
  <link rel="stylesheet" href="./css/menu.css" />
</head>
<body>

<div class="container">

  <div class="topbar">
    <div class="brand">
      <div class="logo">∞</div>
      <div class="title">Octopus Media</div>
    </div>

    <button class="icon-btn" id="btnBell" aria-label="Notifications">
      🔔
    </button>
  </div>

  <div class="heroCard">
    <div class="heroRow">
      <div class="avatar">
        <span id="avatarFallback">O</span>
        <img id="avatarImg" class="hidden" alt="avatar" />
      </div>

      <div class="heroText">
        <div class="hello">Hello, <span id="helloName">-</span></div>
        <div class="badges">
          <span class="badge" id="rolePill">-</span>
          <span class="badge mono">ID: <span id="userId">-</span></span>
        </div>
      </div>

      <button class="icon-btn" id="btnLogout" title="Logout">⎋</button>
    </div>
  </div>

  <div class="sectionTitle">QUICK ACTIONS</div>
  <div class="grid2">
    <div class="actionCard" id="actApprovals">
      <div class="actionIcon">📍</div>
      <div class="actionTitle">Approvals</div>
      <div class="actionSub">Approvals page</div>
    </div>

    <div class="actionCard" id="actOrders">
      <div class="actionIcon">🚚</div>
      <div class="plusFab" id="actCreate" ${showCreate=="yes" ? "" : "style=\"display:none\""}>＋</div>
      <div class="actionTitle">Orders</div>
      <div class="actionSub">Order details</div>
    </div>
  </div>

  ${showUserMgmt=="yes" ? '
  <div class="sectionTitle">ADMIN</div>
  <div class="grid2">
    <a class="actionCard" href="/admin/admin-users.html">
      <div class="actionIcon">🛡️</div>
      <div class="actionTitle">Users</div>
      <div class="actionSub">Manage accounts</div>
    </a>
    <div class="actionCard" onclick="alert('Settings coming soon')">
      <div class="actionIcon">⚙️</div>
      <div class="actionTitle">Settings</div>
      <div class="actionSub">System settings</div>
    </div>
  </div>
  ' : ''}

  <div class="jobsHeader">
    <div class="label">CURRENT JOBS</div>
    <a href="/admin/app.html">View Details</a>
  </div>

  <div class="jobCard">
    <div class="jobTop">
      <div>
        <div class="jobMeta">ACTIVE PROJECT</div>
        <div class="jobNo" id="jobNo">-</div>
      </div>
      <div class="pill" id="jobPill">-</div>
    </div>

    <div class="steps" aria-hidden="true">
      <div class="stepDot active"></div>
      <div class="stepLine active"></div>
      <div class="stepDot active"></div>
      <div class="stepLine"></div>
      <div class="stepDot"></div>
      <div class="stepLine"></div>
      <div class="stepDot"></div>
      <div class="stepLine"></div>
      <div class="stepDot"></div>
    </div>

    <div class="stepLabels">
      <span>Order</span>
      <span>Design</span>
      <span>Process</span>
      <span>Shipped</span>
      <span>Deliver</span>
    </div>

    <div class="stageTitle" id="stageTitle">-</div>
    <div class="stageDesc" id="stageDesc">-</div>

    <div class="eta">
      📅 <span id="etaText">-</span>
    </div>
  </div>

  <div class="smallLink">
    OCTOPUS PRODUCTION SYSTEM V1.0
  </div>

</div>

<div class="navbar">
  <div class="navInner">
    <div class="navItem active" id="navHome">🏠 Home</div>
    <div class="navItem" id="navOrders">📄 Orders</div>
    <div class="navItem" id="navLogout">⎋ Logout</div>
  </div>
</div>

<script src="./js/menu-ui.js"></script>
</body>
</html>
HTML
}

# Create pages per group
make_page "menu-owner.html"      "Owner Menu"      "yes" "yes"
make_page "menu-admin.html"      "Admin Menu"      "yes" "no"
make_page "menu-supervisor.html" "Supervisor Menu" "yes" "no"
make_page "menu-graphic.html"    "Graphic Menu"    "no"  "no"
make_page "menu-print.html"      "Print Menu"      "no"  "no"
make_page "menu-install.html"    "Install Menu"    "no"  "no"

echo
echo "✅ Modern menu pages generated."
echo "✅ Files:"
echo "  - $CSS/menu.css"
echo "  - $JS/menu-ui.js"
echo "  - $PUB/menu-*.html"
echo
echo "Next: rebuild container"
echo "  docker compose down && docker compose up -d --build"
