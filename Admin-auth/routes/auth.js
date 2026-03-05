const express = require("express");
const rateLimit = require("express-rate-limit");
const bcrypt = require("bcrypt");
const jwt = require("jsonwebtoken");
const crypto = require("crypto");

const User = require("../models/User");
const UserGroup = require("../models/UserGroup");
const RefreshToken = require("../models/RefreshToken");

const router = express.Router();

const loginLimiter = rateLimit({
  windowMs: 60 * 1000,
  limit: 12,
  standardHeaders: true,
  legacyHeaders: false
});

function sha256(input) {
  return crypto.createHash("sha256").update(input).digest("hex");
}

function signAccessToken(userId) {
  return jwt.sign({ sub: userId }, process.env.JWT_ACCESS_SECRET, {
    expiresIn: process.env.JWT_ACCESS_TTL || "15m"
  });
}

function signRefreshToken(userId) {
  return jwt.sign({ sub: userId, typ: "refresh" }, process.env.JWT_REFRESH_SECRET, {
    expiresIn: process.env.JWT_REFRESH_TTL || "14d"
  });
}

// ✅ Single source of truth for cookie options
function refreshCookieOptions() {
  const isProd = process.env.NODE_ENV === "production";
  return {
    httpOnly: true,
    secure: isProd,          // true on https
    sameSite: "lax",
    path: "/admin",          // ✅ IMPORTANT: usable for /admin/api/*
    maxAge: 14 * 24 * 60 * 60 * 1000
  };
}

function setRefreshCookie(res, token) {
  res.cookie("refreshToken", token, refreshCookieOptions());
}

/**
 * Menu routing rule:
 * - owner / superadmin -> /admin/menu-owner.html
 * - otherwise -> /admin/menu-{groupKey}.html
 * - fallback: /admin/menu-supervisor.html
 */
function getMenuRouteForUser(user) {
  const role = String(user.systemRole || "").toLowerCase();
  if (role === "owner" || role === "superadmin") return "/admin/menu-owner.html";

  const g = String(user.groupKey || "").toLowerCase().trim();
  const allowed = new Set(["admin", "supervisor", "graphic", "print", "install"]);
  if (allowed.has(g)) return `/admin/menu-${g}.html`;

  return "/admin/menu-supervisor.html";
}

router.post("/login", loginLimiter, async (req, res) => {
  try {
    const { username, password, selectedGroupKey } = req.body || {};
    if (!username || !password) return res.status(400).json({ message: "Missing credentials" });

    const user = await User.findOne({ username: String(username).toLowerCase().trim() });
    if (!user) {
      return res
        .status(401)
        .json({ message: "ชื่อผู้ใช้งานหรือรหัสผ่านไม่ถูกต้อง\nInvalid username or password" });
    }
    if (user.status !== "active") {
      return res.status(403).json({ message: "บัญชีถูกปิดใช้งาน\nAccount disabled" });
    }

    const ok = await bcrypt.compare(password, user.passwordHash);
    if (!ok) {
      return res
        .status(401)
        .json({ message: "ชื่อผู้ใช้งานหรือรหัสผ่านไม่ถูกต้อง\nInvalid username or password" });
    }

    // Keep strict role selection enforcement (your current behavior)
    if (selectedGroupKey && user.groupKey !== selectedGroupKey) {
      return res
        .status(403)
        .json({ message: "บัญชีนี้ไม่อยู่ในกลุ่มที่เลือก\nAccount is not in the selected group" });
    }

    const group = await UserGroup.findOne({ key: user.groupKey, active: true }).lean();

    const accessToken = signAccessToken(user._id.toString());
    const refreshToken = signRefreshToken(user._id.toString());

    // Store refresh token hash in DB (server-side sessions)
    const tokenHash = sha256(refreshToken);
    const expiresAt = new Date(Date.now() + 14 * 24 * 60 * 60 * 1000);

    await RefreshToken.create({
      userId: user._id,
      tokenHash,
      expiresAt,
      ip: req.ip || "",
      ua: req.headers["user-agent"] || ""
    });

    user.lastLoginAt = new Date();
    await user.save();

    // ✅ THIS WAS MISSING: actually set cookie on login
    setRefreshCookie(res, refreshToken);

    const defaultRoute = getMenuRouteForUser(user);

    return res.json({
      accessToken,
      user: {
        id: user._id,
        username: user.username,
        displayName: user.displayName,
        systemRole: user.systemRole,
        groupKey: user.groupKey,
        status: user.status
      },
      groupDefaultRoute: group?.defaultRoute || null,
      defaultRoute
    });
  } catch (e) {
    return res.status(500).json({ message: String(e?.message || e) });
  }
});

router.post("/refresh", async (req, res) => {
  try {
    const rt = req.cookies.refreshToken;
    if (!rt) return res.status(401).json({ message: "Unauthorized" });

    const payload = jwt.verify(rt, process.env.JWT_REFRESH_SECRET);
    if (payload.typ !== "refresh") return res.status(401).json({ message: "Unauthorized" });

    const tokenHash = sha256(rt);
    const tokenRow = await RefreshToken.findOne({ tokenHash, revokedAt: null });
    if (!tokenRow) return res.status(401).json({ message: "Unauthorized" });

    const user = await User.findById(payload.sub).lean();
    if (!user || user.status !== "active") return res.status(401).json({ message: "Unauthorized" });

    // rotate refresh token
    tokenRow.revokedAt = new Date();
    await tokenRow.save();

    const newRefreshToken = signRefreshToken(user._id.toString());
    const newHash = sha256(newRefreshToken);

    await RefreshToken.create({
      userId: user._id,
      tokenHash: newHash,
      expiresAt: new Date(Date.now() + 14 * 24 * 60 * 60 * 1000),
      ip: req.ip || "",
      ua: req.headers["user-agent"] || ""
    });

    setRefreshCookie(res, newRefreshToken);

    const accessToken = signAccessToken(user._id.toString());
    return res.json({ accessToken });
  } catch {
    return res.status(401).json({ message: "Unauthorized" });
  }
});

router.post("/logout", async (req, res) => {
  try {
    const rt = req.cookies.refreshToken;
    if (rt) {
      const tokenHash = sha256(rt);
      await RefreshToken.updateOne({ tokenHash }, { $set: { revokedAt: new Date() } }).catch(() => {});
    }

    res.clearCookie("refreshToken", refreshCookieOptions());
    return res.json({ ok: true });
  } catch (e) {
    return res.status(500).json({ ok: false, message: String(e?.message || e) });
  }
});

module.exports = router;