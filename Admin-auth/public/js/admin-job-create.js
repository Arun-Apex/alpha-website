(function () {
  const API_BASE = "/admin/api";

  const form = document.getElementById("jobForm");
  const msgBox = document.getElementById("msgBox");
  const btnSubmit = document.getElementById("btnSubmit");

  const btnBack = document.getElementById("btnBack");
  const btnMenu = document.getElementById("btnMenu");
  const btnCancel = document.getElementById("btnCancel");

  // auth check
  const accessToken = sessionStorage.getItem("accessToken");
  if (!accessToken) {
    location.href = "/admin/login.html";
    return;
  }

  btnBack.addEventListener("click", () => history.length > 1 ? history.back() : (location.href = "/admin/menu-admin.html"));
  btnMenu.addEventListener("click", () => location.href = "/admin/menu-admin.html");
  btnCancel.addEventListener("click", () => location.href = "/admin/menu-admin.html");

  form.addEventListener("submit", async (e) => {
    e.preventDefault();
    hideMsg();
    setLoading(true);

    const payload = readForm();

    // basic validation
    const missing = [];
    if (!payload.jobNo) missing.push("Job No");
    if (!payload.quotationNo) missing.push("Quotation No");
    if (!payload.description) missing.push("Description");
    if (!payload.dueDate) missing.push("Due date");
    if (!payload.status) missing.push("Status");
    if (!payload.paymentTerms) missing.push("Payment Terms");

    if (missing.length) {
      showMsg("กรุณากรอกข้อมูลให้ครบ: " + missing.join(", ") + "\nPlease fill: " + missing.join(", "), "error");
      setLoading(false);
      return;
    }

    try {
      const res = await fetch(API_BASE + "/orders", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: "Bearer " + (sessionStorage.getItem("accessToken") || "")
        },
        credentials: "include",
        body: JSON.stringify(payload)
      });

      // 401 -> try refresh then retry once
      if (res.status === 401) {
        const r = await fetch(API_BASE + "/auth/refresh", { method: "POST", credentials: "include" });
        if (r.ok) {
          const j = await r.json();
          sessionStorage.setItem("accessToken", j.accessToken);
          return form.dispatchEvent(new Event("submit", { cancelable: true, bubbles: true }));
        }
      }

      const data = await res.json().catch(() => null);

      if (!res.ok) {
        showMsg((data && data.message) ? data.message : "Create failed", "error");
        setLoading(false);
        return;
      }

      showMsg("✅ สร้างงานสำเร็จ / Job created successfully", "ok");

      // go to orders
      setTimeout(() => {
        location.href = "/admin/app.html";
      }, 650);

    } catch (err) {
      showMsg("เกิดข้อผิดพลาดในการเชื่อมต่อ\nNetwork error", "error");
      setLoading(false);
    }
  });

  function readForm() {
    // NOTE: keys are “safe” — backend can map/ignore extra fields.
    const v = (id) => (document.getElementById(id)?.value || "").trim();

    return {
      jobNo: v("jobNo"),
      quotationNo: v("quotationNo"),
      description: v("description"),
      artwork: v("artwork"),
      dueDate: v("dueDate"),
      location: v("location"),
      deliveryMethod: v("deliveryMethod"),
      priority: v("priority"),
      status: v("status"),
      paymentTerms: v("paymentTerms"),
      amount: numOrNull(v("amount")),
      deposit: numOrNull(v("deposit")),
      balance: numOrNull(v("balance")),
      assignee: v("assignee"),
      remark: v("remark"),
      subtask: v("subtask")
    };
  }

  function numOrNull(x) {
    if (!x) return null;
    const n = Number(String(x).replace(/,/g, ""));
    return Number.isFinite(n) ? n : null;
  }

  function setLoading(loading) {
    btnSubmit.disabled = loading;
    btnSubmit.textContent = loading ? "Submitting…" : "Submit";
  }

  function showMsg(text, kind) {
    msgBox.hidden = false;
    msgBox.className = (kind === "ok") ? "ok" : "error";
    msgBox.textContent = text;
  }

  function hideMsg() {
    msgBox.hidden = true;
    msgBox.textContent = "";
  }
})();
