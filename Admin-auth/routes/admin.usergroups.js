const express = require("express");
const { requireAuth } = require("../middleware/auth");
const { requireSystemRole } = require("../middleware/roles");
const UserGroup = require("../models/UserGroup");

const router = express.Router();
router.use(requireAuth(), requireSystemRole(["owner", "superadmin"]));

router.get("/", async (req, res) => {
  const groups = await UserGroup.find({}).sort({ sort: 1 }).lean();
  res.json(groups);
});

router.post("/", async (req, res) => {
  const body = req.body || {};
  if (!body.key || !body.name?.th || !body.name?.en) {
    return res.status(400).json({ message: "Missing fields" });
  }
  const created = await UserGroup.create(body);
  res.json({ ok: true, id: created._id });
});

router.patch("/:key", async (req, res) => {
  await UserGroup.updateOne({ key: req.params.key }, { $set: req.body || {} });
  res.json({ ok: true });
});

module.exports = router;