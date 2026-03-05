const express = require("express");
const bcrypt = require("bcrypt");

const { requireAuth } = require("../middleware/auth");
const { requireSystemRole } = require("../middleware/roles");

const User = require("../models/User");
const UserGroup = require("../models/UserGroup");

const router = express.Router();

router.use(requireAuth(), requireSystemRole(["owner", "superadmin"]));

router.get("/", async (req, res) => {
  const users = await User.find({}).sort({ createdAt: -1 }).lean();
  res.json(users.map(u => ({
    id: u._id,
    username: u.username,
    displayName: u.displayName,
    email: u.email,
    systemRole: u.systemRole,
    groupKey: u.groupKey,
    status: u.status,
    lastLoginAt: u.lastLoginAt,
    createdAt: u.createdAt
  })));
});

router.post("/", async (req, res) => {
  const { username, displayName, email, password, systemRole, groupKey, status } = req.body || {};
  if (!username || !password || !groupKey) return res.status(400).json({ message: "Missing fields" });

  const g = await UserGroup.findOne({ key: groupKey }).lean();
  if (!g) return res.status(400).json({ message: "Invalid user group" });

  const passwordHash = await bcrypt.hash(password, 10);

  const created = await User.create({
    username: String(username).toLowerCase().trim(),
    displayName: displayName || "",
    email: email || "",
    passwordHash,
    systemRole: systemRole || "user",
    groupKey,
    status: status || "active"
  });

  res.json({ ok: true, id: created._id });
});

router.patch("/:id", async (req, res) => {
  const { id } = req.params;
  const patch = {};
  const allowed = ["displayName", "email", "systemRole", "groupKey", "status"];
  for (const k of allowed) if (k in (req.body || {})) patch[k] = req.body[k];

  if (patch.groupKey) {
    const g = await UserGroup.findOne({ key: patch.groupKey }).lean();
    if (!g) return res.status(400).json({ message: "Invalid user group" });
  }

  // Prevent superadmin from demoting owner (basic safety)
  if (req.user.systemRole !== "owner") {
    const target = await User.findById(id).lean();
    if (target?.systemRole === "owner") {
      return res.status(403).json({ message: "Only owner can modify owner account" });
    }
  }

  await User.updateOne({ _id: id }, { $set: patch });
  res.json({ ok: true });
});

router.post("/:id/reset-password", async (req, res) => {
  const { id } = req.params;
  const { newPassword } = req.body || {};
  if (!newPassword || String(newPassword).length < 6) {
    return res.status(400).json({ message: "Password must be at least 6 characters" });
  }

  if (req.user.systemRole !== "owner") {
    const target = await User.findById(id).lean();
    if (target?.systemRole === "owner") {
      return res.status(403).json({ message: "Only owner can reset owner password" });
    }
  }

  const passwordHash = await bcrypt.hash(String(newPassword), 10);
  await User.updateOne({ _id: id }, { $set: { passwordHash } });
  res.json({ ok: true });
});

router.delete("/:id", async (req, res) => {
  const { id } = req.params;

  if (req.user.systemRole !== "owner") {
    const target = await User.findById(id).lean();
    if (target?.systemRole === "owner") {
      return res.status(403).json({ message: "Only owner can delete owner account" });
    }
  }

  await User.deleteOne({ _id: id });
  res.json({ ok: true });
});

module.exports = router;