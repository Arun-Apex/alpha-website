const express = require("express");
const UserGroup = require("../models/UserGroup");

const router = express.Router();

router.get("/", async (req, res) => {
  const groups = await UserGroup.find({ active: true }).sort({ sort: 1 }).lean();
  res.json(groups.map(g => ({
    key: g.key,
    name: g.name,
    description: g.description,
    icon: g.icon,
    defaultRoute: g.defaultRoute
  })));
});

module.exports = router;