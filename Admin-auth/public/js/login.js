// Admin-auth/public/js/login.js
// For /admin deployment:
// - UI served at:   /admin/...
// - API served at:  /admin/api/...
// - Uses access token in sessionStorage and refresh token in httpOnly cookie.

(function () {
  const API_BASE = "/admin/api";

  const form = document.getElementById("loginForm");
  const usernameEl = document.getElementById("username");
  const passwordEl = document.getElementById("password");
  const rememberEl = document.getElementById("remember");
  const errorBox = document.getElementById("errorBox");
  const loginBtn = document.getElementById("loginBtn");

  const roleLabel = document.getElementById("selectedRoleLabel");
  const changeRoleBtn = document.getElementById("changeRoleBtn");

  const pwToggle = document.getElementById("pwToggle");
  const helpLink = document.getElementById("helpLink");

  const selectedGroupKey = localStorage.getItem("selectedGroupKey") || "";
  const selectedGroupNameTh = localStorage.getItem("selectedGroupNameTh") || "";
  const selectedGroupNameEn = localStorage.getItem("selectedGroupNameEn") || "";

  // Render selected role (from selector page)
  const thText = selectedGroupNameTh ? selectedGroupNameTh : (selectedGroupKey || "-");
  const enText = selectedGroupNameEn ? selectedGroupNameEn : (selectedGroupKey || "-");

  roleLabel.innerHTML = `
    <div class="th">กำลังเข้าสู่: ${escapeHtml(thText)}</div>
    <div class="en">Signing in as: ${escapeHtml(enText)}</div>
  `;

  // Back to role selection page (index.html) under /admin
  changeRoleBtn.addEventListener("click", () => {
    window.location.href = "./index.html";
  });

  pwToggle.addEventListener("click", () => {
    const isPw = passwordEl.type === "password";
    passwordEl.type = isPw ? "text" : "password";
    pwToggle.textContent = isPw ? "Hide" : "Show";
    passwordEl.focus();
  });

  helpLink.addEventListener("click", (e) => {
    e.preventDefault();
    alert("Please contact admin / โปรดติดต่อแอดมิน");
  });

  // Remember username only (safe)
  const savedUser = localStorage.getItem("rememberUsername");
  if (savedUser) usernameEl.value = savedUser;

  form.addEventListener("submit", async (e) => {
    e.preventDefault();
    hideError();

    const username = usernameEl.value.trim();
    const password = passwordEl.value;
    const remember = !!rememberEl.checked;

    if (!username || !password) {
      showError("กรุณากรอกชื่อผู้ใช้งานและรหัสผ่าน\nPlease enter username and password.");
      return;
    }

    setLoading(true);

    try {
      const res = await fetch(`${API_BASE}/auth/login`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        credentials: "include", // allow refresh cookie set/read
        body: JSON.stringify({
          username,
          password,
          // optional: server can validate user must belong to selected group
          selectedGroupKey: selectedGroupKey || null,
        }),
      });

      const data = await safeJson(res);

      if (!res.ok) {
        const msg = data && data.message ? data.message : "เข้าสู่ระบบไม่สำเร็จ\nLogin failed.";
        showError(msg);
        setLoading(false);
        return;
      }

      // Save access token (sessionStorage clears on tab close)
      if (data && data.accessToken) {
        sessionStorage.setItem("accessToken", data.accessToken);
      }

      // Remember username (optional)
      if (remember) localStorage.setItem("rememberUsername", username);
      else localStorage.removeItem("rememberUsername");

      // Optional: enforce selected group match on client too
      if (
        selectedGroupKey &&
        data.user &&
        data.user.groupKey &&
        data.user.groupKey !== selectedGroupKey
      ) {
        showError("บัญชีนี้ไม่อยู่ในกลุ่มที่เลือก\nThis account is not in the selected role.");
        setLoading(false);
        return;
      }

      // Redirect to server-provided default route or fallback (within /admin)
      // NOTE: if backend still returns "/app/" you should change backend groups defaultRoute to "/admin/app.html"
      const next = data && data.defaultRoute ? data.defaultRoute : "/admin/app.html";
      window.location.href = next;
    } catch (err) {
      showError("เกิดข้อผิดพลาดในการเชื่อมต่อ\nNetwork error.");
      setLoading(false);
    }
  });

  function setLoading(isLoading) {
    loginBtn.disabled = isLoading;
    if (isLoading) {
      loginBtn.dataset.oldHtml = loginBtn.innerHTML;
      loginBtn.innerHTML =
        `<span class="th">กำลังเข้าสู่ระบบ...</span>` +
        `<span class="en">Signing in...</span>`;
    } else if (loginBtn.dataset.oldHtml) {
      loginBtn.innerHTML = loginBtn.dataset.oldHtml;
      delete loginBtn.dataset.oldHtml;
    }
  }

  function showError(msg) {
    errorBox.hidden = false;
    errorBox.textContent = msg;
  }

  function hideError() {
    errorBox.hidden = true;
    errorBox.textContent = "";
  }

  async function safeJson(res) {
    try {
      return await res.json();
    } catch {
      return null;
    }
  }

  function escapeHtml(str) {
    return String(str).replace(/[&<>"']/g, (m) => ({
      "&": "&amp;",
      "<": "&lt;",
      ">": "&gt;",
      '"': "&quot;",
      "'": "&#039;",
    }[m]));
  }
})();