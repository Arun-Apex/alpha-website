const jwt = require("jsonwebtoken");
const User = require("../models/User");
const UserGroup = require("../models/UserGroup");

function requireAuth() {
  return async (req, res, next) => {
    try {
      const hdr = req.headers.authorization || "";
      const token = hdr.startsWith("Bearer ") ? hdr.slice(7) : null;
      if (!token) return res.status(401).json({ message: "Unauthorized" });

      const payload = jwt.verify(token, process.env.JWT_ACCESS_SECRET);
      const user = await User.findById(payload.sub).lean();
      if (!user) return res.status(401).json({ message: "Unauthorized" });
      if (user.status !== "active") return res.status(403).json({ message: "Account disabled" });

      const group = await UserGroup.findOne({ key: user.groupKey, active: true }).lean();
      req.user = user;
      req.userGroup = group || null;
      req.permissions = group?.permissions || [];

      next();
    } catch (e) {
      return res.status(401).json({ message: "Unauthorized" });
    }
  };
}

module.exports = { requireAuth };