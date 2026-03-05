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
