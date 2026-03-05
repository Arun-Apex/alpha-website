const express = require("express");
const { requireAuth } = require("../middleware/auth");

const router = express.Router();

router.get("/", requireAuth(), async (req, res) => {
  res.json({
    user: {
      id: req.user._id,
      username: req.user.username,
      displayName: req.user.displayName,
      systemRole: req.user.systemRole,
      groupKey: req.user.groupKey,
      status: req.user.status
    },
    group: req.userGroup ? {
      key: req.userGroup.key,
      name: req.userGroup.name,
      description: req.userGroup.description,
      defaultRoute: req.userGroup.defaultRoute
    } : null,
    permissions: req.permissions
  });
});

module.exports = router;