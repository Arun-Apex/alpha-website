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
