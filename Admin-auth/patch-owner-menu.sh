#!/usr/bin/env bash
set -euo pipefail

PUB="$(pwd)/public"

# overwrite ONLY menu-owner.html with the correct layout:
cat > "$PUB/menu-owner.html" <<'HTML'
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width,initial-scale=1" />
  <title>Owner Dashboard</title>

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
      .cards{ grid-template-columns:1fr 1fr; } /* keep 2 columns like screenshot */
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
            <p>Approvals page</p>
          </div>

          <!-- Orders -->
          <div id="actOrders" class="card clickable">
            <div class="cardHead">
              <div class="cardHeadLeft">
                <div class="icon">🚚</div>
                <div>
                  <h3 style="margin:0;">Orders</h3>
                  <p class="smallMuted" style="margin-top:4px;">Order details</p>
                </div>
              </div>
            </div>
          </div>

          <!-- Manage Jobs -->
          <div id="actManageJobs" class="card clickable">
            <div class="icon">🗂️</div>
            <h3>Manage Jobs</h3>
            <p>Manage jobs, stages and status</p>
          </div>

          <!-- Manage Users -->
          <div id="actManageUsers" class="card clickable">
            <div class="icon">🛡️</div>
            <h3>Manage Users</h3>
            <p>Create, edit and switch roles</p>
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
    // per page config for admin-dashboard.js
    window.ADMIN_MENU_ACTIONS = {
      approvalsUrl: "/admin/app.html",
      ordersUrl: "/admin/app.html",
      manageJobsUrl: "/admin/app.html",
      manageUsersUrl: "/admin/admin-users.html"
    };
  </script>

  <script src="./js/admin-dashboard.js"></script>

  <script>
    // extra bindings for owner-only actions
    (function(){
      const a = window.ADMIN_MENU_ACTIONS || {};
      const go = (u)=>{ if(u) location.href=u; };

      const mj = document.getElementById("actManageJobs");
      const mu = document.getElementById("actManageUsers");

      if (mj) mj.addEventListener("click", ()=>go(a.manageJobsUrl));
      if (mu) mu.addEventListener("click", ()=>go(a.manageUsersUrl));
    })();
  </script>
</body>
</html>
HTML

echo "✅ Updated public/menu-owner.html"

echo "Now rebuild docker so container serves the new file:"
echo "  docker compose down && docker compose up -d --build"
