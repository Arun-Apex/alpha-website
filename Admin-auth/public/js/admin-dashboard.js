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
