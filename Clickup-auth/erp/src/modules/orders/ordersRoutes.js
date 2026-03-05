const express = require("express");
const repo = require("./ordersRepo");

const router = express.Router();

router.get("/orders", async (req, res) => {
  const limit = Math.min(Number(req.query.limit || 10), 50);
  const rows = await repo.listJobs(limit);
  res.json(rows);
});

router.get("/orders/:id", async (req, res) => {
  const row = await repo.getJobById(req.params.id);
  if (!row) return res.status(404).json({ message: "Not found" });
  res.json(row);
});

router.post("/orders", async (req, res) => {
  const p = req.body || {};
  if (!p.jobNo || !p.quotationNo || !p.description || !p.dueDate || !p.status || !p.paymentTerms) {
    return res.status(400).json({ message: "Missing required fields" });
  }

  try {
    const created = await repo.createJob(p);
    res.status(201).json(created);
  } catch (e) {
    if (String(e.message || "").includes("duplicate key")) {
      return res.status(409).json({ message: "Duplicate job_no" });
    }
    throw e;
  }
});

router.patch("/orders/:id", async (req, res) => {
  const updated = await repo.patchJob(req.params.id, req.body || {});
  if (!updated) return res.status(404).json({ message: "Not found" });
  res.json(updated);
});

module.exports = router;
