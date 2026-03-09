const express = require("express");
const { getAccessToken } = require("../services/flowaccount/flowClient");
const { validateFlowConfig } = require("../services/flowaccount/flowConfig");
const { listContacts } = require("../services/flowaccount/flowContactsService");

const router = express.Router();

let requireAuth = () => (req, res, next) => next();
try {
  ({ requireAuth } = require("../middleware/auth"));
} catch (_) {
}

//router.get("/health", requireAuth(), async (req, res) => {
	router.get("/health", async (req, res) => {
  try {
    const check = validateFlowConfig();

    res.json({
      ok: true,
      configured: check.ok,
      missing: check.missing,
      baseUrl: check.config.apiBaseUrl,
      scope: check.config.scope,
      grantType: check.config.grantType,
    });
  } catch (e) {
    res.status(500).json({
      ok: false,
      message: e.message || "flowaccount_health_failed",
    });
  }
});

//router.post("/token/test", requireAuth(), async (req, res) => {
	
	router.post("/token/test", async (req, res) => {
  try {
    const token = await getAccessToken();

    res.json({
      ok: true,
      hasToken: Boolean(token.accessToken),
      tokenPreview: token.accessToken ? `${token.accessToken.slice(0, 10)}...` : null,
      raw: token.raw || null,
    });
  } catch (e) {
    res.status(e.statusCode || 500).json({
      ok: false,
      message: e.message || "flowaccount_token_failed",
      details: e.details || null,
    });
  }
});

//router.get("/contacts", requireAuth(), async (req, res) => {
router.get("/contacts", async (req, res) => {
  try {
    const currentPage = Number(req.query.page || 1);
    const pageSize = Number(req.query.pageSize || 20);

    const data = await listContacts(currentPage, pageSize);

    res.json({
      ok: true,
      data,
    });
  } catch (e) {
    res.status(e.statusCode || e.status || 500).json({
      ok: false,
      message: e.message || "flowaccount_contacts_failed",
      details:
        e.body ||
        e.response?.body ||
        e.response ||
        e.stack ||
        String(e),
    });
  }
});
module.exports = router;
