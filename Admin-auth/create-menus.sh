#!/usr/bin/env bash
set -euo pipefail

ROOT="$(pwd)"
PUB="$ROOT/public"
JS="$PUB/js"

mkdir -p "$JS"

echo "Creating: $JS/menu.js"
cat > "$JS/menu.js" <<'JS'
// public/js/menu.js
// Shared menu controller for all group menu pages

(async function () {
  const API_BASE = "/admin/api";

  const headerName = document.getElementById("headerName");
  const headerRole = document.getElementById("headerRole");
  const headerId = document.getElementById("headerId");
  const logoutBtn = document.getElementById("btnLogout");

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

    // refresh once if unauthorized
    if (res.status === 401) {
      const r = await fetch(API_BASE + "/auth/refresh", {
        method: "POST",
        credentials: "include"
      });

      if (r.ok) {
        const j = await r.json();
        sessionStorage.setItem("accessToken", j.accessToken);
        return api(path, opts);
      } else {
        sessionStorage.removeItem("accessToken");
        location.href = "/admin/login.html";
        return null;
      }
    }

    return res.json().catch(() => null);
  }

  const me = await api(API_BASE + "/me");
  if (!me || !me.user) {
    sessionStorage.removeItem("accessToken");
    location.href = "/admin/login.html";
    return;
  }

  const user = me.user;
  const group = me.group;

  // Header rendering
  if (headerName) headerName.textContent = user.displayName || user.username;
  if (headerRole) headerRole.textContent = `${group?.name?.th || user.groupKey} / ${group?.name?.en || ""}`;
  if (headerId) headerId.textContent = `User ID: ${user.id}`;

  // Role protection (redirect if wrong menu page)
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

  if (logoutBtn) {
    logoutBtn.addEventListener("click", async () => {
      await fetch(API_BASE + "/auth/logout", {
        method: "POST",
        credentials: "include"
      }).catch(() => {});
      sessionStorage.removeItem("accessToken");
      location.href = "/admin/login.html";
    });
  }
})();
JS

make_menu () {
  local file="$1"
  local title="$2"
  local cards="$3"

  echo "Creating: $PUB/$file"
  cat > "$PUB/$file" <<HTML
<!doctype html>
<html lang="th">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width,initial-scale=1">
  <title>${title}</title>

  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=Noto+Sans+Thai:wght@400;500;600;700&display=swap" rel="stylesheet">

  <link rel="stylesheet" href="./css/style.css">
</head>

<body>
  <main class="screen">
    <div class="bg-blob bg-blob-1"></div>
    <div class="bg-blob bg-blob-2"></div>

    <section class="hero">
      <div class="brand" style="align-items:flex-start;">
        <div class="brand-title" style="gap:6px;">
          <div id="headerName" class="brand-name">-</div>
          <div id="headerRole" class="brand-sub">-</div>
          <div id="headerId" style="font-size:12px;color:#94a3b8;">-</div>
        </div>

        <button id="btnLogout" class="role-card" style="max-width:120px; padding:10px 12px;">
          <div class="role-title">
            <span class="th">ออกจากระบบ</span>
            <span class="en">Logout</span>
          </div>
        </button>
      </div>

      <div class="cards">
${cards}
      </div>

      <footer class="footer">
        <div class="footer-line">OCTOPUS PRODUCTION SYSTEM V1.0</div>
      </footer>
    </section>
  </main>

  <script src="./js/menu.js"></script>
</body>
</html>
HTML
}

OWNER_CARDS='        <a class="role-card" href="/admin/admin-users.html">
          <div class="role-text">
            <div class="role-title">
              <span class="th">จัดการผู้ใช้งาน</span>
              <span class="en">User Management</span>
            </div>
            <div class="role-desc">
              <span class="th">สร้าง/แก้ไข/ลบผู้ใช้งาน และสิทธิ์</span>
              <span class="en">Create/edit/delete users and permissions</span>
            </div>
          </div>
          <div class="role-arrow" aria-hidden="true">›</div>
        </a>

        <a class="role-card" href="/admin/menu-admin.html">
          <div class="role-text">
            <div class="role-title">
              <span class="th">เมนูแอดมิน</span>
              <span class="en">Admin Menu</span>
            </div>
            <div class="role-desc">
              <span class="th">เข้าสู่หน้าการทำงานของแอดมิน</span>
              <span class="en">Open admin workflow menu</span>
            </div>
          </div>
          <div class="role-arrow" aria-hidden="true">›</div>
        </a>'

ADMIN_CARDS='        <a class="role-card" href="/admin/admin-job-create.html">
          <div class="role-text">
            <div class="role-title">
              <span class="th">สร้างงานใหม่</span>
              <span class="en">Create Job</span>
            </div>
            <div class="role-desc">
              <span class="th">สร้างคำสั่งงานใหม่ให้ลูกค้า</span>
              <span class="en">Create a new job/order</span>
            </div>
          </div>
          <div class="role-arrow" aria-hidden="true">›</div>
        </a>

        <a class="role-card" href="/admin/app.html">
          <div class="role-text">
            <div class="role-title">
              <span class="th">รายการงาน</span>
              <span class="en">Orders</span>
            </div>
            <div class="role-desc">
              <span class="th">ดูงานทั้งหมดและสถานะงาน</span>
              <span class="en">View all orders and statuses</span>
            </div>
          </div>
          <div class="role-arrow" aria-hidden="true">›</div>
        </a>

        <a class="role-card" href="#">
          <div class="role-text">
            <div class="role-title">
              <span class="th">อนุมัติแบบ</span>
              <span class="en">Approvals</span>
            </div>
            <div class="role-desc">
              <span class="th">ขออนุมัติ/ติดตามการอนุมัติ</span>
              <span class="en">Request/track approvals</span>
            </div>
          </div>
          <div class="role-arrow" aria-hidden="true">›</div>
        </a>'

SUPERVISOR_CARDS='        <a class="role-card" href="/admin/app.html">
          <div class="role-text">
            <div class="role-title">
              <span class="th">ดูงานทั้งหมด</span>
              <span class="en">All Orders</span>
            </div>
            <div class="role-desc">
              <span class="th">ตรวจสอบและอัปเดตสถานะงาน</span>
              <span class="en">Review and update job status</span>
            </div>
          </div>
          <div class="role-arrow" aria-hidden="true">›</div>
        </a>

        <a class="role-card" href="#">
          <div class="role-text">
            <div class="role-title">
              <span class="th">อนุมัติคำขอ</span>
              <span class="en">Approvals</span>
            </div>
            <div class="role-desc">
              <span class="th">อนุมัติแบบ / อนุมัติเปลี่ยนวันส่ง</span>
              <span class="en">Approve artwork / due date changes</span>
            </div>
          </div>
          <div class="role-arrow" aria-hidden="true">›</div>
        </a>'

GRAPHIC_CARDS='        <a class="role-card" href="/admin/app.html">
          <div class="role-text">
            <div class="role-title">
              <span class="th">งานที่ได้รับมอบหมาย</span>
              <span class="en">Assigned Jobs</span>
            </div>
            <div class="role-desc">
              <span class="th">ดูงานที่ต้องทำและอัปโหลดไฟล์</span>
              <span class="en">Worklist and uploads</span>
            </div>
          </div>
          <div class="role-arrow" aria-hidden="true">›</div>
        </a>

        <a class="role-card" href="#">
          <div class="role-text">
            <div class="role-title">
              <span class="th">รออนุมัติ</span>
              <span class="en">Pending Approvals</span>
            </div>
            <div class="role-desc">
              <span class="th">ติดตามการอนุมัติจากลูกค้า</span>
              <span class="en">Track customer approvals</span>
            </div>
          </div>
          <div class="role-arrow" aria-hidden="true">›</div>
        </a>'

PRINT_CARDS='        <a class="role-card" href="/admin/app.html">
          <div class="role-text">
            <div class="role-title">
              <span class="th">งานพิมพ์</span>
              <span class="en">Print Jobs</span>
            </div>
            <div class="role-desc">
              <span class="th">ดูงานที่ต้องพิมพ์และอัปเดตสถานะ</span>
              <span class="en">View print queue and update status</span>
            </div>
          </div>
          <div class="role-arrow" aria-hidden="true">›</div>
        </a>'

INSTALL_CARDS='        <a class="role-card" href="/admin/app.html">
          <div class="role-text">
            <div class="role-title">
              <span class="th">งานติดตั้ง</span>
              <span class="en">Installation Jobs</span>
            </div>
            <div class="role-desc">
              <span class="th">ดูงานติดตั้งและอัปเดตความคืบหน้า</span>
              <span class="en">View install tasks and update progress</span>
            </div>
          </div>
          <div class="role-arrow" aria-hidden="true">›</div>
        </a>'

make_menu "menu-owner.html"      "Owner Menu"      "$OWNER_CARDS"
make_menu "menu-admin.html"      "Admin Menu"      "$ADMIN_CARDS"
make_menu "menu-supervisor.html" "Supervisor Menu" "$SUPERVISOR_CARDS"
make_menu "menu-graphic.html"    "Graphic Menu"    "$GRAPHIC_CARDS"
make_menu "menu-print.html"      "Print Menu"      "$PRINT_CARDS"
make_menu "menu-install.html"    "Install Menu"    "$INSTALL_CARDS"

echo
echo "✅ Menu files created:"
ls -1 "$PUB"/menu-*.html
echo "✅ Created: $JS/menu.js"
echo
echo "Next: rebuild container so files are included:"
echo "  docker compose down && docker compose up -d --build"
