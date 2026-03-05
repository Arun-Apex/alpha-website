// public/js/admin-users.js
(async function () {
  const accessToken = sessionStorage.getItem("accessToken");
  if (!accessToken) location.href = "./login.html";

  // If you mount the app under /admin (recommended), all APIs are under /admin/api
  const API_BASE = "/admin/api";

  const els = {
    search: document.getElementById("search"),
    filterGroup: document.getElementById("filterGroup"),
    filterStatus: document.getElementById("filterStatus"),
    tbody: document.getElementById("tbody"),
    errorBox: document.getElementById("errorBox"),
    btnNew: document.getElementById("btnNew"),
    btnLogout: document.getElementById("btnLogout"),
    modal: document.getElementById("modal"),
    modalClose: document.getElementById("modalClose"),
    btnCancel: document.getElementById("btnCancel"),
    btnDelete: document.getElementById("btnDelete"),
    userForm: document.getElementById("userForm"),
    modalTitle: document.getElementById("modalTitle"),

    userId: document.getElementById("userId"),
    username: document.getElementById("username"),
    displayName: document.getElementById("displayName"),
    email: document.getElementById("email"),
    systemRole: document.getElementById("systemRole"),
    groupKey: document.getElementById("groupKey"),
    status: document.getElementById("status"),
    password: document.getElementById("password"),
  };

  let groups = [];
  let users = [];

  function showError(msg) {
    els.errorBox.hidden = false;
    els.errorBox.textContent = msg;
  }
  function hideError() {
    els.errorBox.hidden = true;
    els.errorBox.textContent = "";
  }

  async function api(path, opts = {}) {
    const res = await fetch(path, {
      ...opts,
      headers: {
        "Content-Type": "application/json",
        ...(opts.headers || {}),
        Authorization: `Bearer ${sessionStorage.getItem("accessToken") || ""}`,
      },
      credentials: "include",
    });

    // If access expired: try refresh once
    if (res.status === 401) {
      const r = await fetch(`${API_BASE}/auth/refresh`, {
        method: "POST",
        credentials: "include",
      });
      if (r.ok) {
        const j = await r.json();
        sessionStorage.setItem("accessToken", j.accessToken);
        return api(path, opts);
      }
    }

    const data = await res.json().catch(() => null);
    return { ok: res.ok, status: res.status, data };
  }

  function fmtDate(d) {
    if (!d) return "-";
    const x = new Date(d);
    if (isNaN(x.getTime())) return "-";
    return x.toLocaleString();
  }

  function renderGroupsSelect() {
    const opts = [`<option value="">กลุ่มทั้งหมด / All groups</option>`].concat(
      groups.map(
        (g) =>
          `<option value="${esc(g.key)}">${esc(g.name?.th || g.key)} / ${esc(
            g.name?.en || ""
          )}</option>`
      )
    );
    els.filterGroup.innerHTML = opts.join("");

    els.groupKey.innerHTML = groups
      .map(
        (g) =>
          `<option value="${esc(g.key)}">${esc(g.name?.th || g.key)} / ${esc(
            g.name?.en || ""
          )}</option>`
      )
      .join("");
  }

  function filteredUsers() {
    const q = (els.search.value || "").toLowerCase().trim();
    const g = els.filterGroup.value;
    const s = els.filterStatus.value;

    return users.filter((u) => {
      if (g && u.groupKey !== g) return false;
      if (s && u.status !== s) return false;
      if (!q) return true;
      const hay = `${u.username} ${u.displayName || ""} ${u.email || ""}`.toLowerCase();
      return hay.includes(q);
    });
  }

  function renderTable() {
    const rows = filteredUsers().map((u) => {
      const st = u.status === "active" ? "active" : "disabled";
      return `
        <tr>
          <td>${esc(u.username)}</td>
          <td>${esc(u.displayName || "-")}</td>
          <td><span class="tag">${esc(u.systemRole)}</span></td>
          <td><span class="tag">${esc(u.groupKey)}</span></td>
          <td><span class="tag ${st}">${esc(u.status)}</span></td>
          <td>${esc(fmtDate(u.lastLoginAt))}</td>
          <td>
            <div class="row-actions">
              <button class="btn-small primary" data-edit="${esc(u.id)}">Edit</button>
              <button class="btn-small" data-pass="${esc(u.id)}">Reset PW</button>
            </div>
          </td>
        </tr>
      `;
    });

    els.tbody.innerHTML =
      rows.join("") ||
      `<tr><td colspan="7" style="padding:14px;color:#64748b;">No users</td></tr>`;

    els.tbody
      .querySelectorAll("[data-edit]")
      .forEach((b) => b.addEventListener("click", () => openEdit(b.dataset.edit)));
    els.tbody
      .querySelectorAll("[data-pass]")
      .forEach((b) => b.addEventListener("click", () => openResetPw(b.dataset.pass)));
  }

  function openModal() {
    els.modal.hidden = false;
  }
  function closeModal() {
    els.modal.hidden = true;
  }

  function openNew() {
    els.modalTitle.textContent = "New User";
    els.userId.value = "";
    els.username.value = "";
    els.displayName.value = "";
    els.email.value = "";
    els.systemRole.value = "user";
    els.groupKey.value = groups[0]?.key || "admin";
    els.status.value = "active";
    els.password.value = "";
    els.btnDelete.style.visibility = "hidden";
    openModal();
  }

  function openEdit(id) {
    const u = users.find((x) => x.id === id);
    if (!u) return;
    els.modalTitle.textContent = `Edit: ${u.username}`;
    els.userId.value = u.id;
    els.username.value = u.username;
    els.displayName.value = u.displayName || "";
    els.email.value = u.email || "";
    els.systemRole.value = u.systemRole || "user";
    els.groupKey.value = u.groupKey;
    els.status.value = u.status;
    els.password.value = "";
    els.btnDelete.style.visibility = "visible";
    openModal();
  }

  async function openResetPw(id) {
    const u = users.find((x) => x.id === id);
    if (!u) return;
    const pw = prompt(`New password for ${u.username} (min 6 chars):`);
    if (!pw) return;

    const r = await api(`${API_BASE}/admin/users/${id}/reset-password`, {
      method: "POST",
      body: JSON.stringify({ newPassword: pw }),
    });
    if (!r.ok) return showError(r.data?.message || "Reset failed");
    alert("Password updated");
  }

  async function loadAll() {
    hideError();

    // Ensure user is superadmin/owner
    const me = await api(`${API_BASE}/me`, { method: "GET" });
    if (!me.ok) {
      sessionStorage.removeItem("accessToken");
      location.href = "./login.html";
      return;
    }
    if (!["owner", "superadmin"].includes(me.data?.user?.systemRole)) {
      location.href = "./app.html";
      return;
    }

    const g = await fetch(`${API_BASE}/usergroups`)
      .then((r) => r.json())
      .catch(() => []);
    groups = Array.isArray(g) ? g : [];
    renderGroupsSelect();

    const u = await api(`${API_BASE}/admin/users`, { method: "GET" });
    if (!u.ok) return showError(u.data?.message || "Cannot load users");
    users = u.data || [];
    renderTable();
  }

  // events
  els.search.addEventListener("input", renderTable);
  els.filterGroup.addEventListener("change", renderTable);
  els.filterStatus.addEventListener("change", renderTable);

  els.btnNew.addEventListener("click", openNew);
  els.modalClose.addEventListener("click", closeModal);
  els.btnCancel.addEventListener("click", closeModal);

  els.btnDelete.addEventListener("click", async () => {
    const id = els.userId.value;
    if (!id) return;
    if (!confirm("Delete this user?")) return;

    const r = await api(`${API_BASE}/admin/users/${id}`, { method: "DELETE" });
    if (!r.ok) return showError(r.data?.message || "Delete failed");
    closeModal();
    await loadAll();
  });

  els.userForm.addEventListener("submit", async (e) => {
    e.preventDefault();
    hideError();

    const id = els.userId.value.trim();
    const payload = {
      username: els.username.value.trim(),
      displayName: els.displayName.value.trim(),
      email: els.email.value.trim(),
      systemRole: els.systemRole.value,
      groupKey: els.groupKey.value,
      status: els.status.value,
    };

    // create
    if (!id) {
      if (!els.password.value || els.password.value.length < 6) {
        return showError("Password must be at least 6 characters");
      }
      payload.password = els.password.value;

      const r = await api(`${API_BASE}/admin/users`, {
        method: "POST",
        body: JSON.stringify(payload),
      });
      if (!r.ok) return showError(r.data?.message || "Create failed");
      closeModal();
      await loadAll();
      return;
    }

    // update
    const r = await api(`${API_BASE}/admin/users/${id}`, {
      method: "PATCH",
      body: JSON.stringify(payload),
    });
    if (!r.ok) return showError(r.data?.message || "Update failed");

    // optional password update
    if (els.password.value && els.password.value.length >= 6) {
      const rp = await api(`${API_BASE}/admin/users/${id}/reset-password`, {
        method: "POST",
        body: JSON.stringify({ newPassword: els.password.value }),
      });
      if (!rp.ok) return showError(rp.data?.message || "Password update failed");
    }

    closeModal();
    await loadAll();
  });

  els.btnLogout.addEventListener("click", async () => {
    await fetch(`${API_BASE}/auth/logout`, { method: "POST", credentials: "include" }).catch(
      () => {}
    );
    sessionStorage.removeItem("accessToken");
    location.href = "./login.html";
  });

  function esc(s) {
    return String(s ?? "").replace(/[&<>"']/g, (m) => ({
      "&": "&amp;",
      "<": "&lt;",
      ">": "&gt;",
      '"': "&quot;",
      "'": "&#039;",
    }[m]));
  }

  await loadAll();
})();