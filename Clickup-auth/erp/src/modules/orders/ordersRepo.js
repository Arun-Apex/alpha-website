const db = require("../../db");

async function listJobs(limit = 10) {
  const r = await db.query(
    `SELECT * FROM jobs ORDER BY created_at DESC LIMIT $1`,
    [limit]
  );
  return r.rows;
}

async function getJobById(id) {
  const r = await db.query(`SELECT * FROM jobs WHERE id=$1`, [id]);
  return r.rows[0] || null;
}

async function createJob(p) {
  const r = await db.query(
    `INSERT INTO jobs (
      job_no, quotation_no, description, artwork, due_date, location, delivery_method, priority,
      status, payment_terms, amount, deposit, balance, assignee, remark, subtask
    ) VALUES (
      $1,$2,$3,$4,$5,$6,$7,$8,
      $9,$10,$11,$12,$13,$14,$15,$16
    )
    RETURNING *`,
    [
      p.jobNo, p.quotationNo, p.description, p.artwork || null, p.dueDate,
      p.location || null, p.deliveryMethod || null, p.priority || null,
      p.status, p.paymentTerms,
      p.amount ?? null, p.deposit ?? null, p.balance ?? null,
      p.assignee || null, p.remark || null, p.subtask || null
    ]
  );
  return r.rows[0];
}

async function patchJob(id, p) {
  // only allow some fields for now
  const fields = [];
  const vals = [];
  let i = 1;

  const allow = {
    description: "description",
    artwork: "artwork",
    dueDate: "due_date",
    location: "location",
    deliveryMethod: "delivery_method",
    priority: "priority",
    status: "status",
    paymentTerms: "payment_terms",
    amount: "amount",
    deposit: "deposit",
    balance: "balance",
    assignee: "assignee",
    remark: "remark",
    subtask: "subtask"
  };

  for (const [k, col] of Object.entries(allow)) {
    if (p[k] !== undefined) {
      fields.push(`${col}=$${i++}`);
      vals.push(p[k]);
    }
  }

  if (!fields.length) return getJobById(id);

  vals.push(id);

  const r = await db.query(
    `UPDATE jobs SET ${fields.join(", ")} WHERE id=$${i} RETURNING *`,
    vals
  );
  return r.rows[0] || null;
}

module.exports = { listJobs, getJobById, createJob, patchJob };
