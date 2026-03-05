#!/usr/bin/env bash
set -euo pipefail

PUB="$(pwd)/public"
JS="$(pwd)/public/js"
mkdir -p "$JS"

# -------------------------
# admin-job-create.html
# -------------------------
cat > "$PUB/admin-job-create.html" <<'HTML'
<!doctype html>
<html lang="th">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width,initial-scale=1" />
  <title>Create Job • Admin</title>

  <link rel="preconnect" href="https://fonts.googleapis.com" />
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin />
  <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&family=Noto+Sans+Thai:wght@400;500;600;700&display=swap" rel="stylesheet" />

  <style>
    :root{
      --bg:#f6f8fb; --card:#fff; --text:#101828; --muted:#667085;
      --primary:#2563eb; --primary2:#1d4ed8;
      --shadow:0 10px 30px rgba(16,24,40,.08);
      --border:rgba(229,231,235,.85);
      --danger:#ef4444;
    }
    *{ box-sizing:border-box }
    body{
      margin:0;
      font-family: Inter, "Noto Sans Thai", system-ui, -apple-system, Segoe UI, Roboto, Arial;
      background:var(--bg); color:var(--text)
    }
    a{ color:inherit; text-decoration:none }
    .wrap{ max-width:1100px; margin:0 auto; padding:18px 16px 40px }

    .topbar{
      display:flex; align-items:center; gap:10px;
      margin-bottom:14px;
    }
    .logo{
      width:38px; height:38px; border-radius:12px; background:#fff;
      display:flex; align-items:center; justify-content:center;
      box-shadow:0 6px 18px rgba(0,0,0,.08); font-weight:800; color:#111;
    }
    .brand{ font-weight:800 }
    .crumb{ margin-left:auto; display:flex; gap:10px; align-items:center }
    .btn{
      display:inline-flex; align-items:center; justify-content:center;
      padding:10px 14px; border-radius:12px;
      border:1px solid #d1d5db; background:#fff; color:var(--primary);
      font-weight:800; font-size:12px; cursor:pointer;
    }
    .btnPrimary{
      background:linear-gradient(180deg, #3b82f6 0%, #2563eb 100%);
      border:1px solid rgba(37,99,235,.35);
      color:#fff;
      box-shadow:0 10px 20px rgba(37,99,235,.18);
    }
    .btn:disabled{ opacity:.6; cursor:not-allowed }

    .hero{
      background:
        radial-gradient(1200px 500px at 10% 0%, #dbeafe 0%, rgba(219,234,254,0) 60%),
        linear-gradient(135deg, #e9d5ff 0%, #dbeafe 45%, #c7f9f1 100%);
      border-radius:26px; padding:18px; box-shadow:var(--shadow);
      position:relative; overflow:hidden;
      margin-bottom:14px;
    }
    .hero h1{ margin:0; font-size:20px }
    .hero p{ margin:4px 0 0; color:rgba(16,24,40,.7); font-size:13px }

    .grid{
      display:grid;
      grid-template-columns: 1fr;
      gap:12px;
    }
    @media (min-width:920px){
      .grid{ grid-template-columns: 1.15fr .85fr; }
      .hero h1{ font-size:24px }
    }

    .card{
      background:var(--card);
      border:1px solid var(--border);
      border-radius:18px;
      box-shadow:0 10px 24px rgba(16,24,40,.06);
      padding:14px;
    }
    .cardTitle{
      display:flex; align-items:flex-end; justify-content:space-between; gap:12px;
      margin-bottom:10px;
    }
    .cardTitle h2{ margin:0; font-size:14px }
    .sub{ margin:0; font-size:12px; color:var(--muted) }

    .form{
      display:grid;
      grid-template-columns: 1fr;
      gap:12px;
    }
    .row2{
      display:grid;
      grid-template-columns: 1fr;
      gap:12px;
    }
    @media (min-width:920px){
      .row2{ grid-template-columns: 1fr 1fr; }
    }

    .field label{
      display:block;
      font-weight:800;
      font-size:12px;
      margin:0 0 6px;
    }
    .field label .en{
      display:block;
      font-weight:600;
      color:#98a2b3;
      font-size:11px;
      margin-top:2px;
    }
    input, select, textarea{
      width:100%;
      border-radius:14px;
      border:1px solid rgba(209,213,219,.9);
      padding:11px 12px;
      outline:none;
      font-size:13px;
      background:#fff;
    }
    textarea{ min-height:110px; resize:vertical }
    input:focus, select:focus, textarea:focus{
      border-color: rgba(37,99,235,.55);
      box-shadow: 0 0 0 4px rgba(37,99,235,.12);
    }
    .hint{ font-size:12px; color:#98a2b3; margin-top:6px }
    .req{ color:var(--danger); margin-left:2px }

    .drop{
      border:1px dashed rgba(148,163,184,.75);
      border-radius:14px;
      padding:14px;
      background:#fbfdff;
      color:#64748b;
      font-size:12px;
    }

    .error{
      border:1px solid rgba(239,68,68,.35);
      background: rgba(239,68,68,.08);
      color:#7f1d1d;
      border-radius:14px;
      padding:10px 12px;
      font-size:13px;
      white-space:pre-line;
    }
    .ok{
      border:1px solid rgba(34,197,94,.35);
      background: rgba(34,197,94,.08);
      color:#14532d;
      border-radius:14px;
      padding:10px 12px;
      font-size:13px;
      white-space:pre-line;
    }
    .actions{
      display:flex; gap:10px; justify-content:flex-end; margin-top:10px;
    }
  </style>
</head>

<body>
  <div class="wrap">
    <div class="topbar">
      <div class="logo">O</div>
      <div>
        <div class="brand">Octopus Media</div>
        <div class="sub">Admin • Create Job</div>
      </div>

      <div class="crumb">
        <button class="btn" id="btnBack" type="button">← Back</button>
        <button class="btn" id="btnMenu" type="button">Menu</button>
      </div>
    </div>

    <div class="hero">
      <h1>สร้างงานใหม่ / Create New Job</h1>
      <p>กรอกข้อมูลหลักก่อน แล้วเราจะเชื่อมต่อ ClickUp / FlowAccount / LINE ในขั้นต่อไป • Fill the basics now. Integrations later.</p>
    </div>

    <div class="grid">
      <!-- LEFT: main form -->
      <div class="card">
        <div class="cardTitle">
          <div>
            <h2>รายละเอียดงาน / Job Details</h2>
            <p class="sub">Fields marked * are required</p>
          </div>
        </div>

        <div id="msgBox" class="error" hidden></div>

        <form id="jobForm" class="form">
          <div class="row2">
            <div class="field">
              <label>
                เลขที่ JOB<span class="req">*</span>
                <span class="en">Job No.*</span>
              </label>
              <input id="jobNo" name="jobNo" placeholder="D23568" required />
            </div>

            <div class="field">
              <label>
                Quotation No.<span class="req">*</span>
                <span class="en">Quotation No.*</span>
              </label>
              <input id="quotationNo" name="quotationNo" placeholder="Q-2026-0001" required />
            </div>
          </div>

          <div class="field">
            <label>
              รายละเอียดงาน (รายละเอียดกว้างๆ)<span class="req">*</span>
              <span class="en">Task description*</span>
            </label>
            <textarea id="description" name="description" placeholder="เช่น: ป้ายหน้าร้าน ขนาด..., วัสดุ..., งานติดตั้ง..." required></textarea>
          </div>

          <div class="row2">
            <div class="field">
              <label>
                Artwork (ไฟล์ / ลิงก์)
                <span class="en">Artwork (file/link)</span>
              </label>
              <input id="artwork" name="artwork" placeholder="Google Drive link / file name" />
            </div>

            <div class="field">
              <label>
                Due date (วันที่ส่งมอบ)<span class="req">*</span>
                <span class="en">Due date*</span>
              </label>
              <input id="dueDate" name="dueDate" type="date" required />
            </div>
          </div>

          <div class="field">
            <label>
              Location (สถานที่ติดตั้ง/จัดส่ง)
              <span class="en">Location</span>
            </label>
            <input id="location" name="location" placeholder="Address / Google map link" />
          </div>

          <div class="row2">
            <div class="field">
              <label>
                วิธีส่งงาน
                <span class="en">Delivery method</span>
              </label>
              <select id="deliveryMethod" name="deliveryMethod">
                <option value="">Select option…</option>
                <option value="pickup">รับเอง / Pickup</option>
                <option value="courier">ขนส่ง / Courier</option>
                <option value="installation">ติดตั้งหน้างาน / On-site installation</option>
              </select>
            </div>

            <div class="field">
              <label>
                Priority (ความเร่งด่วน)
                <span class="en">Priority</span>
              </label>
              <select id="priority" name="priority">
                <option value="">Select priority…</option>
                <option value="low">Low / ต่ำ</option>
                <option value="normal">Normal / ปกติ</option>
                <option value="high">High / สูง</option>
                <option value="urgent">Urgent / ด่วนมาก</option>
              </select>
            </div>
          </div>

          <div class="row2">
            <div class="field">
              <label>
                Status<span class="req">*</span>
                <span class="en">Status*</span>
              </label>
              <select id="status" name="status" required>
                <option value="">Select option…</option>
                <option value="pending_admin">PENDING ADMIN</option>
                <option value="in_design">IN DESIGN</option>
                <option value="in_production">IN PRODUCTION</option>
                <option value="shipped">SHIPPED</option>
                <option value="completed">COMPLETED</option>
                <option value="cancelled">CANCELLED</option>
              </select>
            </div>

            <div class="field">
              <label>
                Payment Terms<span class="req">*</span>
                <span class="en">Payment Terms*</span>
              </label>
              <select id="paymentTerms" name="paymentTerms" required>
                <option value="">Select option…</option>
                <option value="deposit_50">มัดจำ 50% / 50% Deposit</option>
                <option value="deposit_70">มัดจำ 70% / 70% Deposit</option>
                <option value="full">ชำระเต็ม / Full payment</option>
                <option value="credit">เครดิต / Credit</option>
              </select>
              <div class="hint">* Payment via LINE/FlowAccount will be added later.</div>
            </div>
          </div>

          <div class="row2">
            <div class="field">
              <label>
                Amount (ยอดงาน)
                <span class="en">Amount</span>
              </label>
              <input id="amount" name="amount" inputmode="decimal" placeholder="0.00" />
            </div>
            <div class="field">
              <label>
                Deposit
                <span class="en">Deposit</span>
              </label>
              <input id="deposit" name="deposit" inputmode="decimal" placeholder="0.00" />
            </div>
          </div>

          <div class="row2">
            <div class="field">
              <label>
                Balance
                <span class="en">Balance</span>
              </label>
              <input id="balance" name="balance" inputmode="decimal" placeholder="0.00" />
            </div>
            <div class="field">
              <label>
                Assignee
                <span class="en">Assignee</span>
              </label>
              <input id="assignee" name="assignee" placeholder="username / team" />
            </div>
          </div>

          <div class="field">
            <label>
              Remark
              <span class="en">Remark</span>
            </label>
            <textarea id="remark" name="remark" placeholder="หมายเหตุ / Notes"></textarea>
          </div>

          <div class="field">
            <label>
              FORM Subtask
              <span class="en">Subtask</span>
            </label>
            <textarea id="subtask" name="subtask" placeholder="เช่น: งานเจาะ, งานประกอบ, งานติดตั้ง..."></textarea>
          </div>

          <div class="actions">
            <button class="btn" id="btnCancel" type="button">Cancel</button>
            <button class="btn btnPrimary" id="btnSubmit" type="submit">Submit</button>
          </div>
        </form>
      </div>

      <!-- RIGHT: attachments / help -->
      <div class="card">
        <div class="cardTitle">
          <div>
            <h2>ไฟล์แนบ / Attachments</h2>
            <p class="sub">Upload will be enabled later</p>
          </div>
        </div>

        <div class="drop">
          Drop your files here to upload<br/>
          (coming soon — will connect to storage)
        </div>

        <div style="height:12px"></div>

        <div class="cardTitle">
          <div>
            <h2>Tips</h2>
            <p class="sub">Recommended minimum fields</p>
          </div>
        </div>

        <ul style="margin:0; padding-left:18px; color:#667085; font-size:13px; line-height:1.6;">
          <li>Job No, Quotation No, Due date, Status, Payment Terms</li>
          <li>Use “PENDING ADMIN” as default if unsure</li>
          <li>Later: ClickUp will overwrite Status/Stages automatically</li>
        </ul>
      </div>
    </div>
  </div>

  <script src="./js/admin-job-create.js"></script>
</body>
</html>
HTML

# -------------------------
# admin-job-create.js
# -------------------------
cat > "$JS/admin-job-create.js" <<'JS'
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
JS

echo "✅ Added: public/admin-job-create.html"
echo "✅ Added: public/js/admin-job-create.js"
echo ""
echo "Now rebuild:"
echo "  docker compose down && docker compose up -d --build"
